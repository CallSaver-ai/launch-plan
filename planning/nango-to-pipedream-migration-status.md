# Nango → Pipedream Migration Status

## What's Done ✅

### Frontend OAuth Flow
- ✅ Pipedream SDK installed in frontend
- ✅ `use-pipedream-auth.ts` hook created (replaces `use-nango-auth.ts`)
- ✅ `integrations-config.ts` updated with Pipedream fields (`appSlug`, `oauthAppId`)
- ✅ `integration-connect-dialog.tsx` uses Pipedream hook
- ✅ Square Bookings deprecated (removed from all files)
- ✅ Frontend auth headers fixed (Supabase Bearer token added)
- ✅ Disconnect button auth fixed

### Backend OAuth Connection Management
- ✅ Pipedream SDK installed in backend
- ✅ `POST /me/connect-token` endpoint (creates Pipedream tokens)
- ✅ `POST /me/integrations/connect` endpoint (records connections in DB after OAuth)
- ✅ `DELETE /me/integrations/:type` updated (uses Pipedream SDK for disconnect)
- ✅ `GET /me/integrations` updated (removed Square)
- ✅ `NangoConnection` model repurposed (stores Pipedream accountId in `connectionId`)

### Infrastructure
- ✅ Pipedream secrets added to AWS Secrets Manager
- ✅ Deploy script updated to inject Pipedream secrets
- ✅ IAM policy consolidated (wildcard for all `callsaver/staging/backend/*`)
- ✅ Pipedream OAuth apps created (Jobber: `oa_9Wiywz`, Google Calendar: `oa_K1iR9M`)

### Helper Library
- ✅ `/src/lib/pipedream-client.ts` created with `getAccessToken()` and `getAccount()` helpers

---

## What's NOT Done ❌

### Backend API Request Code (CRITICAL)

The backend still uses **Nango SDK** to fetch OAuth access tokens when making API requests. This causes the errors you're seeing:

**Google Calendar:**
- ❌ `getGoogleCalendarAccessToken()` (line 10819) calls `nango.getConnection()`
- ❌ `makeGoogleCalendarRequest()` (line 10855) uses Nango
- ❌ `getOrganizationGoogleCalendarConnection()` (line 11107) creates Nango instance
- ❌ `getLocationWithGoogleCalendarConnection()` (line 11145) creates Nango instance

**Jobber:**
- ❌ `JobberClient.getAccessToken()` (line 60 in `JobberClient.ts`) calls `nango.getConnection()`
- ❌ `JobberAdapter` constructor passes `nangoSecretKey` and `nangoConnectionId`
- ❌ `FieldServiceAdapterRegistry.buildNangoConfig()` (line 117) builds Nango config

---

## What Needs to Happen

### 1. Replace Google Calendar Nango calls with Pipedream

**File:** `/src/server.ts`

Replace:
```typescript
async function getGoogleCalendarAccessToken(nango: Nango, connectionId: string): Promise<string> {
  const connection = await nango.getConnection('google-calendar', connectionId);
  return connection.credentials.access_token;
}
```

With:
```typescript
import { getAccessToken } from './lib/pipedream-client.js';

async function getGoogleCalendarAccessToken(connectionId: string): Promise<string> {
  return await getAccessToken(connectionId);
}
```

Update all callers to remove `nango` parameter.

### 2. Replace Jobber Nango calls with Pipedream

**File:** `/src/adapters/field-service/platforms/jobber/JobberClient.ts`

Replace:
```typescript
private async getAccessToken(): Promise<string> {
  const connection = await this.nango.getConnection('jobber', this.connectionId);
  return connection.credentials.access_token;
}
```

With:
```typescript
import { getAccessToken } from '../../../lib/pipedream-client.js';

private async getAccessToken(): Promise<string> {
  return await getAccessToken(this.connectionId);
}
```

Remove `nango` from constructor and class properties.

### 3. Update FieldServiceAdapterRegistry

**File:** `/src/adapters/field-service/FieldServiceAdapterRegistry.ts`

Change `buildNangoConfig()` to just return `connectionId`:
```typescript
private async buildPipedreamConfig(
  locationId: string,
  platform: FieldServicePlatform
): Promise<AdapterFactoryConfig> {
  const connection = await this.getConnection(locationId, platform);
  return {
    platform,
    connectionId: connection.connectionId, // Pipedream accountId
  };
}
```

---

## Scopes Issue

**Google Calendar:** Missing `userinfo.email` scope
- Go to Pipedream OAuth Clients → edit Google Calendar app
- Add scope: `https://www.googleapis.com/auth/userinfo.email`

**Jobber:** No scopes configured
- The Jobber OAuth app needs proper scopes configured in Pipedream
- Check Jobber's API docs for required scopes

---

## Next Steps

1. Update `getGoogleCalendarAccessToken()` to use Pipedream helper
2. Update `JobberClient.getAccessToken()` to use Pipedream helper  
3. Remove all `nango` parameters and instances
4. Test end-to-end in staging
5. Add Google Calendar `userinfo.email` scope in Pipedream
6. Configure Jobber scopes in Pipedream
