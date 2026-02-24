# Nango Webhook Implementation: Token Refresh Failure Handling

**Date:** Feb 20, 2026  
**Issue:** Jobber OAuth tokens invalidated, no notification received  
**Root Cause:** Missing webhook handler for `operation: "refresh"` events

---

## Current State

Your Nango webhook handler (`POST /webhooks/nango`) only handles:
- ✅ `type: "auth"`, `operation: "creation"` - New connection created
- ❌ `type: "auth"`, `operation: "override"` - Connection re-authorized (NOT HANDLED)
- ❌ `type: "auth"`, `operation: "refresh"` - Token refresh **failed** (NOT HANDLED)

**This is why you didn't know Jobber invalidated your tokens.**

---

## Nango Webhook Events

### 1. Connection Created (Currently Handled)
```json
{
  "type": "auth",
  "operation": "creation",
  "connectionId": "03f05982-b202-4f84-873d-facd093547f7",
  "providerConfigKey": "jobber",
  "provider": "jobber",
  "success": true,
  "tags": {
    "end_user_id": "cmloxy8cq0006r801vqdm10xf",
    "organizationid": "cmloxxuyy0005r801wqgopda6"
  }
}
```

### 2. Connection Re-authorized (NOT Handled)
```json
{
  "type": "auth",
  "operation": "override",
  "connectionId": "03f05982-b202-4f84-873d-facd093547f7",
  "providerConfigKey": "jobber",
  "provider": "jobber",
  "success": true,
  "tags": { ... }
}
```

### 3. Token Refresh Failed (NOT HANDLED - **YOUR ISSUE**)
```json
{
  "type": "auth",
  "operation": "refresh",
  "connectionId": "03f05982-b202-4f84-873d-facd093547f7",
  "providerConfigKey": "jobber",
  "provider": "jobber",
  "success": false,
  "error": {
    "type": "invalid_credentials",
    "description": "The external API returned an error when trying to refresh the access token"
  },
  "tags": {
    "end_user_id": "cmloxy8cq0006r801vqdm10xf",
    "organizationid": "cmloxxuyy0005r801wqgopda6"
  }
}
```

---

## Solution: Enhanced Webhook Handler

### Step 1: Add Health Tracking Fields to NangoConnection

**Migration: `036_add_nango_connection_health_tracking.sql`**

```sql
-- Add health tracking fields to nango_connections table
ALTER TABLE nango_connections 
  ADD COLUMN last_refresh_attempt TIMESTAMP,
  ADD COLUMN last_refresh_success TIMESTAMP,
  ADD COLUMN consecutive_failures INTEGER DEFAULT 0,
  ADD COLUMN needs_reauth BOOLEAN DEFAULT false;

-- Add index for querying unhealthy connections
CREATE INDEX idx_nango_connections_needs_reauth 
  ON nango_connections(needs_reauth) 
  WHERE needs_reauth = true;
```

**Prisma Schema Update:**

```prisma
model NangoConnection {
  id                    String    @id @default(cuid())
  organizationId        String    @map("organization_id")
  connectionId          String    @map("connection_id")
  integrationType       String    @map("integration_type")
  providerConfigKey     String?   @map("provider_config_key")
  status                String    @default("active")
  
  // Health tracking (NEW)
  lastRefreshAttempt    DateTime? @map("last_refresh_attempt")
  lastRefreshSuccess    DateTime? @map("last_refresh_success")
  consecutiveFailures   Int       @default(0) @map("consecutive_failures")
  needsReauth           Boolean   @default(false) @map("needs_reauth")
  
  createdAt             DateTime  @default(now()) @map("created_at")
  updatedAt             DateTime  @updatedAt @map("updated_at")

  organization          Organization @relation(fields: [organizationId], references: [id], onDelete: Cascade)

  @@unique([organizationId, integrationType])
  @@map("nango_connections")
}
```

---

### Step 2: Enhanced Webhook Handler

**File: `src/server.ts` - Update Nango webhook handler**

```typescript
// POST /webhooks/nango - Enhanced handler
app.post('/webhooks/nango', async (req, res) => {
  try {
    // Verify HMAC signature
    const signature = req.headers['x-nango-hmac-sha256'];
    const body = JSON.stringify(req.body);
    const expectedSignature = crypto
      .createHmac('sha256', process.env.NANGO_SECRET_KEY!)
      .update(body)
      .digest('hex');

    if (signature !== expectedSignature) {
      console.error('[Nango Webhook] Invalid signature');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    const event = req.body;
    console.log('[Nango Webhook] Received:', JSON.stringify(event, null, 2));

    // Handle auth events
    if (event.type === 'auth') {
      const { operation, connectionId, providerConfigKey, provider, success, tags, error } = event;
      const organizationId = tags?.organizationid || tags?.organization_id;

      if (!organizationId) {
        console.error('[Nango Webhook] Missing organizationId in tags');
        return res.status(400).json({ error: 'Missing organizationId' });
      }

      // Handle different operations
      switch (operation) {
        case 'creation':
          await handleConnectionCreation(organizationId, connectionId, providerConfigKey, provider, tags);
          break;

        case 'override':
          await handleConnectionOverride(organizationId, connectionId, providerConfigKey, provider);
          break;

        case 'refresh':
          await handleTokenRefresh(organizationId, connectionId, providerConfigKey, success, error);
          break;

        default:
          console.warn(`[Nango Webhook] Unknown operation: ${operation}`);
      }
    }

    return res.json({ received: true });
  } catch (error: any) {
    console.error('[Nango Webhook] Error:', error);
    return res.status(500).json({ error: error.message });
  }
});

// Handler for connection creation (existing logic)
async function handleConnectionCreation(
  organizationId: string,
  connectionId: string,
  providerConfigKey: string,
  provider: string,
  tags: any
) {
  console.log(`[Nango] Connection created: ${provider} for org ${organizationId}`);

  // Delete any existing connections for this org (only one integration at a time)
  const existingConnections = await prisma.nangoConnection.findMany({
    where: { organizationId },
  });

  for (const conn of existingConnections) {
    console.log(`[Nango] Deleting old connection: ${conn.integrationType}`);
    
    // Clean up platform-specific data
    await cleanupAfterDisconnect(organizationId, conn.integrationType);
    
    // Delete from Nango
    try {
      const nango = new Nango({ secretKey: process.env.NANGO_SECRET_KEY! });
      await nango.deleteConnection(conn.providerConfigKey || conn.integrationType, conn.connectionId);
    } catch (err) {
      console.error(`[Nango] Failed to delete connection from Nango:`, err);
    }
    
    // Delete from local DB
    await prisma.nangoConnection.delete({ where: { id: conn.id } });
  }

  // Create new connection
  await prisma.nangoConnection.create({
    data: {
      organizationId,
      connectionId,
      integrationType: provider,
      providerConfigKey: providerConfigKey || provider,
      status: 'active',
      lastRefreshSuccess: new Date(), // Initial connection is successful
      consecutiveFailures: 0,
      needsReauth: false,
    },
  });

  console.log(`[Nango] Created connection: ${provider}`);
}

// Handler for connection override (re-authorization)
async function handleConnectionOverride(
  organizationId: string,
  connectionId: string,
  providerConfigKey: string,
  provider: string
) {
  console.log(`[Nango] Connection re-authorized: ${provider} for org ${organizationId}`);

  // Update existing connection - reset health tracking
  await prisma.nangoConnection.updateMany({
    where: {
      organizationId,
      connectionId,
    },
    data: {
      status: 'active',
      lastRefreshSuccess: new Date(),
      consecutiveFailures: 0,
      needsReauth: false,
    },
  });

  console.log(`[Nango] Connection health reset after re-authorization`);
}

// Handler for token refresh (NEW - THIS IS WHAT YOU'RE MISSING)
async function handleTokenRefresh(
  organizationId: string,
  connectionId: string,
  providerConfigKey: string,
  success: boolean,
  error?: { type: string; description: string }
) {
  const connection = await prisma.nangoConnection.findFirst({
    where: { organizationId, connectionId },
    include: { organization: { include: { members: { include: { user: true } } } } },
  });

  if (!connection) {
    console.error(`[Nango] Connection not found: ${connectionId}`);
    return;
  }

  if (success) {
    // Refresh succeeded - reset failure counter
    console.log(`[Nango] Token refresh succeeded for ${connection.integrationType}`);
    
    await prisma.nangoConnection.update({
      where: { id: connection.id },
      data: {
        lastRefreshAttempt: new Date(),
        lastRefreshSuccess: new Date(),
        consecutiveFailures: 0,
        needsReauth: false,
      },
    });
  } else {
    // Refresh failed - increment failure counter
    const consecutiveFailures = connection.consecutiveFailures + 1;
    const needsReauth = consecutiveFailures >= 3; // Mark for re-auth after 3 failures

    console.error(`[Nango] Token refresh FAILED for ${connection.integrationType}:`, error);
    console.error(`[Nango] Consecutive failures: ${consecutiveFailures}`);

    await prisma.nangoConnection.update({
      where: { id: connection.id },
      data: {
        lastRefreshAttempt: new Date(),
        consecutiveFailures,
        needsReauth,
        status: needsReauth ? 'needs_reauth' : 'active',
      },
    });

    // Send notification to organization members
    if (needsReauth) {
      await notifyIntegrationNeedsReauth(connection, error);
    }
  }
}

// Notify users that integration needs re-authentication
async function notifyIntegrationNeedsReauth(
  connection: any,
  error?: { type: string; description: string }
) {
  console.log(`[Nango] Sending re-auth notification for ${connection.integrationType}`);

  const integrationName = connection.integrationType === 'jobber' ? 'Jobber' :
                         connection.integrationType === 'google-calendar' ? 'Google Calendar' :
                         connection.integrationType;

  // Get organization members
  const members = connection.organization.members || [];
  const emails = members.map((m: any) => m.user?.email).filter(Boolean);

  if (emails.length === 0) {
    console.warn(`[Nango] No emails found for org ${connection.organizationId}`);
    return;
  }

  // Send email notification
  try {
    await sendEmail({
      to: emails,
      subject: `${integrationName} Integration Needs Reconnection`,
      html: `
        <h2>${integrationName} Integration Disconnected</h2>
        <p>Your ${integrationName} integration has been disconnected and needs to be reconnected.</p>
        <p><strong>Reason:</strong> ${error?.description || 'OAuth tokens were revoked'}</p>
        <p>This typically happens when:</p>
        <ul>
          <li>The app was disconnected in ${integrationName}</li>
          <li>Your ${integrationName} account plan changed</li>
          <li>An admin user was deactivated</li>
        </ul>
        <p><strong>What to do:</strong></p>
        <ol>
          <li>Log in to your CallSaver dashboard</li>
          <li>Go to Settings → Integrations</li>
          <li>Click "Disconnect" on ${integrationName}</li>
          <li>Click "Connect ${integrationName}" and complete the OAuth flow</li>
        </ol>
        <p>Your call history and customer data are preserved. Once reconnected, your voice agent will resume using ${integrationName}.</p>
        <p><a href="https://app.callsaver.ai/settings/integrations">Reconnect ${integrationName} →</a></p>
      `,
    });

    console.log(`[Nango] Re-auth notification sent to ${emails.length} recipients`);
  } catch (emailError) {
    console.error(`[Nango] Failed to send re-auth notification:`, emailError);
  }
}
```

---

### Step 3: Frontend - Show Re-auth Status

**File: `callsaver-frontend/src/hooks/use-integrations.ts`**

Add `needsReauth` field to integration status:

```typescript
export function useIntegrations() {
  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['integrations'],
    queryFn: async () => {
      const res = await fetch('/api/me/integrations');
      if (!res.ok) throw new Error('Failed to fetch integrations');
      return res.json();
    },
  });

  const activeIntegration = data?.connections?.[0];
  
  return {
    activeIntegration: activeIntegration ? {
      type: activeIntegration.integrationType,
      status: activeIntegration.status,
      needsReauth: activeIntegration.needsReauth, // NEW
      lastRefreshAttempt: activeIntegration.lastRefreshAttempt, // NEW
      lastRefreshSuccess: activeIntegration.lastRefreshSuccess, // NEW
    } : null,
    isLoading,
    error,
    refetch,
  };
}
```

**File: `callsaver-frontend/src/components/integration-card.tsx`**

Show warning banner when `needsReauth: true`:

```tsx
export function IntegrationCard({ integration }: { integration: Integration }) {
  const { activeIntegration } = useIntegrations();
  const isConnected = activeIntegration?.type === integration.id;
  const needsReauth = isConnected && activeIntegration?.needsReauth;

  return (
    <Card>
      <CardHeader>
        <CardTitle>{integration.name}</CardTitle>
      </CardHeader>
      <CardContent>
        {needsReauth && (
          <Alert variant="destructive" className="mb-4">
            <AlertCircle className="h-4 w-4" />
            <AlertTitle>Reconnection Required</AlertTitle>
            <AlertDescription>
              This integration has been disconnected. Please reconnect to resume functionality.
            </AlertDescription>
          </Alert>
        )}
        
        {isConnected ? (
          <div className="space-y-2">
            <Badge variant={needsReauth ? "destructive" : "success"}>
              {needsReauth ? "Needs Reconnection" : "Connected"}
            </Badge>
            <div className="flex gap-2">
              <Button variant="outline" onClick={handleDisconnect}>
                Disconnect
              </Button>
              {needsReauth && (
                <Button onClick={handleReconnect}>
                  Reconnect
                </Button>
              )}
            </div>
          </div>
        ) : (
          <Button onClick={handleConnect}>Connect</Button>
        )}
      </CardContent>
    </Card>
  );
}
```

---

### Step 4: API Endpoint - Return Health Status

**File: `src/server.ts` - Update `/me/integrations` endpoint**

```typescript
app.get('/me/integrations', requireAuth, async (req, res) => {
  const userId = req.user.id;

  const member = await prisma.organizationMember.findFirst({
    where: { userId },
    select: { organizationId: true },
  });

  if (!member) {
    return res.json({ connections: [] });
  }

  const connections = await prisma.nangoConnection.findMany({
    where: { organizationId: member.organizationId },
    select: {
      id: true,
      integrationType: true,
      status: true,
      needsReauth: true, // NEW
      lastRefreshAttempt: true, // NEW
      lastRefreshSuccess: true, // NEW
      consecutiveFailures: true, // NEW
      createdAt: true,
    },
  });

  return res.json({ connections });
});
```

---

## Testing the Fix

### 1. Test Token Refresh Failure Webhook

Send a test webhook to your local server:

```bash
curl -X POST http://localhost:3002/webhooks/nango \
  -H "Content-Type: application/json" \
  -H "X-Nango-Hmac-Sha256: $(echo -n '{"type":"auth","operation":"refresh","connectionId":"test-123","providerConfigKey":"jobber","provider":"jobber","success":false,"error":{"type":"invalid_credentials","description":"Test failure"},"tags":{"organizationid":"cmloxxuyy0005r801wqgopda6"}}' | openssl dgst -sha256 -hmac "$NANGO_SECRET_KEY" | awk '{print $2}')" \
  -d '{
    "type": "auth",
    "operation": "refresh",
    "connectionId": "test-123",
    "providerConfigKey": "jobber",
    "provider": "jobber",
    "success": false,
    "error": {
      "type": "invalid_credentials",
      "description": "Test failure"
    },
    "tags": {
      "organizationid": "cmloxxuyy0005r801wqgopda6"
    }
  }'
```

**Expected result:**
- `NangoConnection.consecutiveFailures` increments
- After 3 failures, `needsReauth` = true
- Email sent to organization members

### 2. Test Re-authentication Flow

1. Go to Settings → Integrations
2. Verify "Needs Reconnection" warning appears
3. Click "Disconnect"
4. Click "Connect Jobber"
5. Complete OAuth flow
6. Verify `needsReauth` resets to false

---

## Deployment Checklist

- [ ] Run migration `036_add_nango_connection_health_tracking.sql`
- [ ] Deploy updated webhook handler to staging
- [ ] Configure Nango webhook URL in Nango dashboard (if not already done)
- [ ] Test with simulated refresh failure webhook
- [ ] Deploy frontend changes (re-auth UI)
- [ ] Test end-to-end re-authentication flow
- [ ] Deploy to production
- [ ] Monitor Nango webhook logs for refresh events

---

## Monitoring & Alerts

### Dashboard Query - Unhealthy Connections

```sql
SELECT 
  nc.integration_type,
  nc.consecutive_failures,
  nc.last_refresh_attempt,
  nc.last_refresh_success,
  nc.needs_reauth,
  o.name as organization_name
FROM nango_connections nc
JOIN organizations o ON nc.organization_id = o.id
WHERE nc.needs_reauth = true
ORDER BY nc.last_refresh_attempt DESC;
```

### Alert Rule

Set up CloudWatch alert:
- **Metric:** Count of `nango_connections` where `needs_reauth = true`
- **Threshold:** > 5 connections need re-auth
- **Action:** Send SNS notification to ops team

---

## Summary

**Root cause:** Missing webhook handler for `operation: "refresh"` events from Nango.

**Fix:**
1. ✅ Add health tracking fields to `NangoConnection`
2. ✅ Handle `refresh` operation in webhook
3. ✅ Send email notifications after 3 consecutive failures
4. ✅ Show "Needs Reconnection" UI in frontend
5. ✅ Track refresh attempts and failures

**Effort:** ~4-6 hours  
**Impact:** Proactive notification when OAuth tokens are revoked, preventing silent failures

**Next time Jobber invalidates tokens:** You'll receive an email and see a warning in the dashboard, instead of discovering it when API calls fail.
