# Pipedream Connect Migration Plan

**Date:** Feb 21, 2026
**Status:** Planning
**Goal:** Migrate all OAuth integrations (Jobber, Google Calendar, Square Bookings, Housecall Pro) from Nango Cloud to Pipedream Connect for improved token reliability and platform maturity.

---

## Executive Summary

Nango Cloud has been unreliable for Jobber OAuth token refresh, causing `refresh_token_external_error` failures that require manual reconnection. Additionally, Nango's Proxy is blocked by Cloudflare on Jobber's API. Pipedream Connect is a more mature platform (11k GitHub stars, acquired by Workday, SOC 2 Type 2) that provides managed OAuth, a Connect Proxy, built-in account health monitoring (`healthy`/`dead` status), and automatic token refresh retry.

**Critical finding:** Pipedream's community has documented the **exact same Jobber token refresh issue** we experienced. Their team resolved it by enabling "long-lived refresh tokens" on their Jobber app configuration. This suggests Pipedream has already solved the Jobber-specific token rotation problem that Nango has not.

---

## Table of Contents

1. [Current Architecture (Nango)](#1-current-architecture-nango)
2. [Target Architecture (Pipedream Connect)](#2-target-architecture-pipedream-connect)
3. [Key Differences: Nango vs Pipedream Connect](#3-key-differences-nango-vs-pipedream-connect)
4. [Pre-Migration: Pipedream Account Setup](#4-pre-migration-pipedream-account-setup)
5. [Phase 1: Proof of Concept — Jobber Only](#5-phase-1-proof-of-concept--jobber-only)
6. [Phase 2: Migrate Google Calendar & Square Bookings](#6-phase-2-migrate-google-calendar--square-bookings)
7. [Phase 3: Add Housecall Pro](#7-phase-3-add-housecall-pro)
8. [Phase 4: Remove Nango](#8-phase-4-remove-nango)
9. [Frontend Migration (Detailed)](#9-frontend-migration-detailed)
10. [Database Migration](#10-database-migration)
11. [Risk Assessment](#11-risk-assessment)
12. [Rollback Plan](#12-rollback-plan)
13. [Open Questions](#13-open-questions)

---

## 1. Current Architecture (Nango)

### Backend Touchpoints (`callsaver-api`)

| File | Usage |
|------|-------|
| `src/adapters/field-service/platforms/jobber/JobberClient.ts` | `nango.getConnection('jobber', connectionId)` → extract `access_token` → direct axios to Jobber GraphQL |
| `src/adapters/field-service/FieldServiceAdapterRegistry.ts` | Looks up `NangoConnection` in DB to find `connectionId`, passes to JobberClient config |
| `src/server.ts` — `POST /webhooks/nango` | Handles `auth/creation` webhooks, creates/updates `NangoConnection` records |
| `src/server.ts` — `GET /me/integrations` | Queries `NangoConnection` table to list connected integrations |
| `src/server.ts` — `POST /me/integrations/:type/activate` | Updates `NangoConnection.isActive` flag |
| `src/server.ts` — `DELETE /me/integrations/:type` | Calls `nango.deleteConnection()`, deletes `NangoConnection` record |
| `src/server.ts` — Google Calendar token retrieval | `nango.getConnection('google-calendar', connectionId)` for GCal API calls |

### Frontend Touchpoints (`callsaver-frontend`)

| File | Usage | Nango Coupled? |
|------|-------|----------------|
| `src/hooks/use-nango-auth.ts` | Core hook: fetches session token, creates `Nango` instance, calls `nango.auth()` | **YES** — imports `@nangohq/frontend` |
| `src/lib/integrations-config.ts` | Config array with `provider` (Nango key) and `sessionTokenKey` per integration | Lightly — field names are Nango-specific |
| `src/components/integrations/integration-connect-dialog.tsx` | OAuth dialog with status states (idle/loading/connecting/success/error) | **YES** — imports `useNangoAuth` |
| `src/components/integrations/integration-card.tsx` | Presentational card per integration | No |
| `src/components/integrations/switch-integration-dialog.tsx` | Confirmation dialog for switching integrations | No |
| `src/components/integrations/disconnect-integration-dialog.tsx` | Confirmation dialog for disconnecting | No |
| `src/hooks/use-integrations.ts` | Fetches `GET /me/integrations` API, returns connection status | No |
| `src/pages/IntegrationsPage.tsx` | Settings page orchestrating cards + dialogs | No |
| `src/pages/OnboardingPage.tsx` | Onboarding wizard step 3 — reuses `IntegrationConnectDialog` | No |

### Database

| Model | Purpose |
|-------|---------|
| `NangoConnection` | Stores `connectionId` (Nango's ID), `integrationType`, `status`, `isActive`, `organizationId`, `providerConfigKey` |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `NANGO_SECRET_KEY` | Authenticates all Nango API calls (backend + webhook signature verification) |

---

## 2. Target Architecture (Pipedream Connect)

### How Pipedream Connect Works

```
┌─────────────────────────────────────────────────────────────┐
│  Frontend                                                    │
│  @pipedream/sdk → connectAccount({ app: 'jobber_developer_app' }) │
│       ↓ (OAuth popup via Pipedream iFrame)                   │
│       ↓                                                      │
│  Pipedream webhook → POST /webhooks/pipedream                │
│       ↓ CONNECTION_SUCCESS with account.id (apn_xxx)         │
│       ↓                                                      │
│  Backend stores account.id in IntegrationConnection table    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  API Request Flow (e.g. Jobber GraphQL)                      │
│                                                              │
│  Option A: Proxy (if Cloudflare allows)                      │
│  pdClient.proxy.post({                                       │
│    externalUserId, accountId,                                │
│    url: 'https://api.getjobber.com/api/graphql',             │
│    body: { query, variables }                                │
│  })                                                          │
│                                                              │
│  Option B: Direct (if Cloudflare blocks proxy)               │
│  account = pdClient.accounts.retrieve(accountId,             │
│    { include_credentials: true })                            │
│  access_token = account.credentials.oauth_access_token       │
│  axios.post('https://api.getjobber.com/api/graphql', ...)    │
│                                                              │
│  Option C: Google Calendar (proxy likely works)              │
│  pdClient.proxy.post({                                       │
│    externalUserId, accountId,                                │
│    url: 'https://www.googleapis.com/calendar/v3/...',        │
│    body: { ... }                                             │
│  })                                                          │
└─────────────────────────────────────────────────────────────┘
```

### Key Pipedream Concepts

| Concept | Nango Equivalent | Description |
|---------|------------------|-------------|
| **External User ID** | `endUser.endUserId` | Your user/org ID — identifies who the connection belongs to |
| **Account** (`apn_xxx`) | `connectionId` | The connected account record in Pipedream |
| **App slug** | `providerConfigKey` | e.g. `jobber_developer_app`, `google_calendar`, `squareup` |
| **Connect Token** | N/A (Nango uses frontend SDK + secret key) | Short-lived token for frontend OAuth flow |
| **Project** | N/A | Container for all your Connect resources |
| **Environment** | N/A | `development` or `production` |
| `healthy` / `dead` | No equivalent | Built-in account health monitoring |
| `last_refreshed_at` | No equivalent | Built-in refresh tracking |

---

## 3. Key Differences: Nango vs Pipedream Connect

| Feature | Nango Cloud | Pipedream Connect |
|---------|-------------|-------------------|
| **Token refresh** | Automatic, but unreliable for Jobber | Automatic, with built-in retry + health status |
| **Jobber support** | `jobber` provider | `jobber_developer_app` (custom OAuth) — **has known fix for token refresh** |
| **Proxy** | Blocked by Cloudflare on Jobber | **Must test** — may also be blocked |
| **Credential retrieval** | `getConnection()` returns `access_token` | `retrieve(accountId, { include_credentials: true })` — **requires custom OAuth client** |
| **Account health** | No built-in monitoring | `healthy` / `dead` flags + `last_refreshed_at` |
| **Webhooks** | `auth/creation`, `auth/refresh` (failed), `auth/override` | `CONNECTION_SUCCESS`, `CONNECTION_ERROR` |
| **Frontend SDK** | `@nangohq/frontend` | `@pipedream/sdk` (same package for frontend + backend) |
| **Backend SDK** | `@nangohq/node` | `@pipedream/sdk` |
| **Rate limits** | Undocumented | 1,000 proxy requests / 5 min / project |
| **Pricing** | Free tier + paid | Free in development, paid in production |
| **Security** | SOC 2 Type 2 | SOC 2 Type 2, HIPAA BAA available |

---

## 4. Pre-Migration: Pipedream Account Setup

### 4.1 Create Pipedream Account & Project

1. ✅ Sign up at [pipedream.com](https://pipedream.com)
2. ✅ Create a new Project — **Project ID: `proj_BgsRyvp`**
3. Environments: `development` (free, 10-user limit) and `production` (paid plan required)

### 4.2 Create Pipedream OAuth Client (for API access)

1. Visit [API settings](https://pipedream.com/settings/api)
2. Create OAuth client → note `client_id` and `client_secret`
3. These authenticate YOUR requests to Pipedream's API (not end-user OAuth)

### 4.3 Register Custom OAuth Apps in Pipedream

**CRITICAL**: To retrieve credentials via API (needed for Jobber direct calls), you MUST use your own OAuth client, not Pipedream's default.

| App | Pipedream App Slug | OAuth Client Source | Scopes Needed |
|-----|--------------------|---------------------|---------------|
| **Jobber** | `jobber_developer_app` | Your Jobber Developer App (existing) | `read`, `write` (existing scopes) |
| **Google Calendar** | `google_calendar` | Your Google Cloud OAuth Client (existing) | `calendar.events`, `calendar.readonly` |
| **Square Bookings** | `squareup` | Your Square Developer App (existing) | `APPOINTMENTS_READ`, `APPOINTMENTS_WRITE`, `APPOINTMENTS_BUSINESS_SETTINGS_READ` |
| **Housecall Pro** | TBD — check if exists | HCP API key (not OAuth) | N/A (API key based) |

#### Step-by-Step: Register Jobber OAuth App

1. Go to [Pipedream OAuth Clients](https://pipedream.com/@/accounts/oauth-clients)
2. Click **New OAuth Client**
3. Search for app: **"Jobber"** — select `jobber_developer_app` (custom OAuth, not the default `jobber`)
4. Enter your **Jobber Developer App** credentials:
   - **Client ID** — from your [Jobber Developer Center](https://developer.getjobber.com/) app
   - **Client Secret** — from the same Jobber app
   - These are the SAME credentials currently configured in Nango's dashboard
5. Pipedream will assign an **OAuth App ID** (e.g. `oa_abc123`) — save this
6. Scopes: Pipedream inherits scopes from your Jobber app config (no separate scope config needed)

#### Step-by-Step: Register Google Calendar OAuth App

1. Same page: [Pipedream OAuth Clients](https://pipedream.com/@/accounts/oauth-clients)
2. Click **New OAuth Client**
3. Search for app: **"Google Calendar"** — select `google_calendar`
4. Enter your **Google Cloud Console** OAuth 2.0 credentials:
   - **Client ID** — from [Google Cloud Console](https://console.cloud.google.com/apis/credentials) > OAuth 2.0 Client IDs
   - **Client Secret** — from the same Google OAuth client
   - These are the SAME credentials currently configured in Nango's dashboard
5. **IMPORTANT**: Add Pipedream's redirect URI to your Google OAuth client's authorized redirect URIs:
   - Pipedream will show you the exact redirect URI to add (typically `https://api.pipedream.com/connect/oauth/oa_xxx/callback`)
   - Go to Google Cloud Console > APIs & Services > Credentials > your OAuth client > Authorized redirect URIs > add it
6. Pipedream will assign an **OAuth App ID** (e.g. `oa_def456`) — save this

#### Where to Find Your Existing Credentials

Your Jobber and Google OAuth client ID + secret are currently stored in **Nango's dashboard**, not in your codebase. Nango manages the OAuth flow using those credentials.

To retrieve them:
- **Jobber**: Log into [Nango Dashboard](https://app.nango.dev) → Integrations → `jobber` → view the client ID and secret. Or go directly to [Jobber Developer Center](https://developer.getjobber.com/) → your app.
- **Google Calendar**: Nango Dashboard → Integrations → `google-calendar` → view credentials. Or go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → OAuth 2.0 Client IDs.

You're essentially copying the same client ID + secret from Nango into Pipedream. Both platforms use YOUR OAuth app — they just manage the token lifecycle differently.

### 4.4 Environment Variables

Add to `.env` and secrets manager:
```
PIPEDREAM_CLIENT_ID=your_pipedream_oauth_client_id
PIPEDREAM_CLIENT_SECRET=your_pipedream_oauth_client_secret
PIPEDREAM_PROJECT_ID=proj_BgsRyvp
PIPEDREAM_ENVIRONMENT=development  # or production
PIPEDREAM_ALLOWED_ORIGINS=["http://localhost:5173"]  # add production origin later
```

### 4.5 Important Constraints

#### Development Mode Constraints
- **Max 10 external users** in development — delete old test users if you hit the limit
- **Must be signed into pipedream.com** in the same browser when connecting accounts in dev mode
- Development is **free on any plan**; production requires a paid Connect plan

#### Connect Token Constraints
- Tokens expire after **4 hours**
- Tokens are **single-use** — each `connectAccount()` call needs a fresh token
- Our `use-pipedream-auth.ts` hook already handles this (fetches a new token on every connect)

#### COOP Header (may be needed)
If the Pipedream Connect iFrame can't open OAuth popups (e.g. Google consent screen), set this header on your frontend:
```
Cross-Origin-Opener-Policy: same-origin-allow-popups
```
Only needed if you explicitly enforce `same-origin` COOP. The default `unsafe-none` works fine.

#### Project Branding Customization
Customize the Pipedream Connect iFrame so it says "CallSaver uses Pipedream" instead of generic branding:
1. Open project in Pipedream → **Connect** tab → **Configuration**
2. Set **Application Name**: `CallSaver`
3. Set **Support Email**: `support@callsaver.ai`
4. Upload **Logo**: CallSaver logo

### 4.6 Webhook Payload Reference

The `POST /webhooks/pipedream` endpoint receives this payload on successful connection:

```json
{
  "event": "CONNECTION_SUCCESS",
  "connect_token": "abc123",
  "environment": "development",
  "connect_session_id": 123,
  "account": {
    "id": "apn_abc123",
    "name": "My Jobber Account",
    "external_id": "org_xxx",
    "healthy": true,
    "dead": false,
    "app": {
      "id": "app_abc123",
      "name_slug": "jobber_developer_app",
      "name": "Jobber",
      "auth_type": "oauth"
    },
    "created_at": "2026-02-21T00:00:00Z",
    "updated_at": "2026-02-21T00:00:00Z"
  }
}
```

On error:
```json
{
  "event": "CONNECTION_ERROR",
  "connect_token": "abc123",
  "environment": "development",
  "error": "Description of what went wrong"
}
```

Note: Credentials are NOT included in the webhook. Use `pd.accounts.retrieve(accountId, { include_credentials: true })` to get the access token.

### 4.7 Connect Link (Alternative to SDK)

For scenarios where you can't use the frontend SDK (e.g. email onboarding, mobile), Pipedream provides a hosted URL:

```typescript
// Backend generates the URL
const { connect_link_url } = await pdClient.createConnectToken({
  external_user_id: organizationId,
});

// Append app slug
const url = `${connect_link_url}&app=jobber_developer_app`;
// Send via email, SMS, or redirect
```

The URL expires after 4 hours and is single-use. After connection, Pipedream sends the webhook as normal.

---

## 5. Phase 1: Proof of Concept — Jobber Only

**Goal:** Validate that Pipedream Connect reliably handles Jobber token refresh before committing to full migration.

**Estimated effort:** 2-3 days

### 5.1 Install SDK

```bash
pnpm add @pipedream/sdk
```

### 5.2 Test Proxy vs Direct

**Before writing any code**, test whether Pipedream's proxy can reach Jobber's API or if Cloudflare blocks it (same issue as Nango):

```typescript
// Quick test script
import { PipedreamClient } from "@pipedream/sdk";

const pd = new PipedreamClient({
  projectId: process.env.PIPEDREAM_PROJECT_ID,
  clientId: process.env.PIPEDREAM_CLIENT_ID,
  clientSecret: process.env.PIPEDREAM_CLIENT_SECRET,
  projectEnvironment: "development",
});

// Test proxy
const resp = await pd.proxy.post({
  externalUserId: "test-user",
  accountId: "apn_xxx", // from a test connection
  url: "https://api.getjobber.com/api/graphql",
  headers: { "X-JOBBER-GRAPHQL-VERSION": "2025-01-20" },
  body: {
    query: `query { clients(first: 1) { nodes { id } } }`,
    variables: {},
  },
});
console.log("Proxy response:", resp);
```

**If proxy works** → Use proxy for Jobber (simplest path, Pipedream handles everything)
**If proxy is blocked by Cloudflare** → Use credential retrieval + direct axios (same pattern as current Nango approach, but with Pipedream managing tokens)

### 5.3 Create `PipedreamTokenProvider`

Abstract token retrieval behind an interface so we can swap providers:

```typescript
// src/services/PipedreamTokenProvider.ts
import { PipedreamClient } from "@pipedream/sdk";

export class PipedreamTokenProvider {
  private client: PipedreamClient;

  constructor() {
    this.client = new PipedreamClient({
      projectId: process.env.PIPEDREAM_PROJECT_ID!,
      clientId: process.env.PIPEDREAM_CLIENT_ID!,
      clientSecret: process.env.PIPEDREAM_CLIENT_SECRET!,
      projectEnvironment: (process.env.PIPEDREAM_ENVIRONMENT || "development") as "development" | "production",
    });
  }

  /**
   * Get access token for a connected account.
   * Pipedream handles token refresh automatically.
   */
  async getAccessToken(accountId: string): Promise<string> {
    const account = await this.client.accounts.retrieve(accountId, {
      include_credentials: true,
    });

    if (account.dead) {
      throw new Error(`Account ${accountId} is dead — needs reconnection`);
    }

    if (!account.healthy) {
      console.warn(`Account ${accountId} is unhealthy — token refresh may have failed`);
    }

    const token = account.credentials?.oauth_access_token;
    if (!token) {
      throw new Error(`No access token for account ${accountId}`);
    }

    return token;
  }

  /**
   * Check account health (built-in Pipedream feature)
   */
  async isHealthy(accountId: string): Promise<boolean> {
    const account = await this.client.accounts.retrieve(accountId);
    return account.healthy && !account.dead;
  }

  /**
   * Make a proxied request (if Cloudflare allows)
   */
  async proxyPost(externalUserId: string, accountId: string, url: string, body: any, headers?: Record<string, string>) {
    return this.client.proxy.post({
      externalUserId,
      accountId,
      url,
      body,
      headers,
    });
  }

  /**
   * Delete a connected account
   */
  async deleteAccount(accountId: string): Promise<void> {
    await this.client.accounts.delete(accountId);
  }

  /**
   * Generate a Connect token for frontend OAuth flow
   */
  async createConnectToken(externalUserId: string, webhookUri?: string) {
    return this.client.tokens.create({
      externalUserId,
      webhook_uri: webhookUri,
    });
  }

  /**
   * List accounts for a user
   */
  async listAccounts(externalUserId: string, appSlug?: string) {
    return this.client.accounts.list({
      external_user_id: externalUserId,
      app: appSlug,
    });
  }
}
```

### 5.4 Refactor JobberClient

Replace `nango.getConnection()` with `PipedreamTokenProvider.getAccessToken()`:

```typescript
// JobberClient.ts — key change
export class JobberClient {
  private tokenProvider: PipedreamTokenProvider;
  private accountId: string; // Pipedream account ID (apn_xxx)
  private axiosInstance: AxiosInstance;

  constructor(config: JobberClientConfig) {
    this.tokenProvider = config.tokenProvider;
    this.accountId = config.pipedreamAccountId;
    // ... axios setup same as before
  }

  private async getAccessToken(): Promise<string> {
    return this.tokenProvider.getAccessToken(this.accountId);
  }

  // ... rest stays the same (query, mutate, healthCheck)
}
```

### 5.5 Webhook Handler

Replace `POST /webhooks/nango` with `POST /webhooks/pipedream`:

```typescript
app.post('/webhooks/pipedream', async (req, res) => {
  const { event, account, error, connect_token, environment } = req.body;

  if (event === 'CONNECTION_SUCCESS') {
    const { id: accountId, app, external_id } = account;
    // external_id = our user/org ID (passed as externalUserId during token creation)

    // Map app slug to our integration type
    const integrationTypeMap: Record<string, string> = {
      'jobber_developer_app': 'jobber',
      'google_calendar': 'google-calendar',
      'squareup': 'square-bookings',
    };
    const integrationType = integrationTypeMap[app.name_slug] || app.name_slug;

    // Upsert IntegrationConnection record
    // ... (similar to current Nango webhook handler)

  } else if (event === 'CONNECTION_ERROR') {
    console.error('[Pipedream Webhook] Connection error:', error);
  }

  res.json({ received: true });
});
```

### 5.6 Stress Test: Token Refresh Reliability

After connecting a test Jobber account via Pipedream:

```bash
# Fire 10 concurrent token retrieval requests
for i in {1..10}; do
  curl -s "http://localhost:3002/internal/test-jobber-token" &
done
wait

# Wait 2 hours (let token expire), repeat
# Monitor: does account.healthy stay true?
# Monitor: does retrieve(include_credentials) return fresh token?
```

**Success criteria:**
- No `refresh_token_external_error` over 48 hours
- `account.healthy` stays `true`
- Concurrent requests don't invalidate tokens

---

## 6. Phase 2: Migrate Google Calendar & Square Bookings

**Estimated effort:** 1-2 days (mostly mechanical once Jobber works)

### 6.1 Google Calendar

- App slug: `google_calendar`
- OAuth client: Register your Google Cloud OAuth credentials in Pipedream
- **Proxy likely works** — Google APIs don't have Cloudflare-style blocking
- Replace `nango.getConnection('google-calendar', ...)` with `pd.proxy.post()` or credential retrieval

### 6.2 Square Bookings

- App slug: `squareup` (production) or `squareup_sandbox` (sandbox)
- OAuth client: Register your Square Developer App credentials in Pipedream
- Test proxy compatibility

### 6.3 Update Frontend

Replace Nango frontend SDK with Pipedream SDK for all three integrations. See [Section 9](#9-frontend-changes).

---

## 7. Phase 3: Add Housecall Pro

**Estimated effort:** 1 day

- Housecall Pro uses **API key auth**, not OAuth
- Check if Pipedream has an HCP app: search for `housecall_pro` in Pipedream's app registry
- If HCP exists: use Pipedream's key-based auth management
- If not: keep HCP using `OrganizationIntegration.accessToken` (current approach) — no migration needed since it's API key, not OAuth. No token refresh concerns.

---

## 8. Phase 4: Remove Nango

**Estimated effort:** 1 day

Once all integrations are verified on Pipedream:

1. Remove `@nangohq/node` and `@nangohq/frontend` from dependencies
2. Remove `NANGO_SECRET_KEY` from env vars and secrets manager
3. Delete `POST /webhooks/nango` endpoint
4. Remove all `import { Nango } from '@nangohq/node'` references
5. Run migration to rename `NangoConnection` → `IntegrationConnection` (or keep name, just repurpose)
6. Cancel Nango Cloud subscription

---

## 9. Frontend Migration (Detailed)

### 9.1 Current Frontend Architecture (Nango)

The Nango integration touches **5 files** in `callsaver-frontend`:

| File | Role | Lines | Nango Coupling |
|------|------|-------|----------------|
| `src/hooks/use-nango-auth.ts` | Core OAuth hook — fetches session token, opens Nango popup, handles errors | 167 | **HIGH** — imports `@nangohq/frontend`, uses `Nango` class + `AuthError` types |
| `src/lib/integrations-config.ts` | Config for available integrations (Jobber, GCal, Square) | 70 | **LOW** — `provider` and `sessionTokenKey` fields are Nango-specific but easily remapped |
| `src/components/integrations/integration-connect-dialog.tsx` | Modal dialog with idle/loading/connecting/success/error states | 293 | **MEDIUM** — imports `useNangoAuth` hook, uses `NangoAuthStatus` type |
| `src/components/integrations/integration-card.tsx` | Card component per integration | 126 | **NONE** — purely presentational, no Nango imports |
| `src/components/integrations/switch-integration-dialog.tsx` | Confirmation dialog for switching integrations | 57 | **NONE** — purely presentational |
| `src/components/integrations/disconnect-integration-dialog.tsx` | Confirmation dialog for disconnecting | 44 | **NONE** — purely presentational |
| `src/hooks/use-integrations.ts` | Fetches `/me/integrations` API, returns connection status | 110 | **NONE** — calls backend API, no Nango SDK |
| `src/pages/IntegrationsPage.tsx` | Settings page rendering cards + dialogs | 270 | **NONE** — uses shared components, no direct Nango imports |
| `src/pages/OnboardingPage.tsx` | Onboarding wizard step 3 (Integrations) | ~2752 | **NONE** — reuses `IntegrationConnectDialog` and `useIntegrations` |

**Key insight:** Nango coupling is concentrated in just **2 files**: `use-nango-auth.ts` (the hook) and `integration-connect-dialog.tsx` (which imports the hook). Everything else is Nango-agnostic.

#### Current OAuth Flow

```
User clicks "Connect" on IntegrationCard
  → IntegrationsPage opens IntegrationConnectDialog
    → useNangoAuth.connect(config) is called
      → Step 1: POST /me/session-token { integration: config.sessionTokenKey }
        → Backend returns { sessionToken: "nango_session_xxx" }
      → Step 2: new Nango({ connectSessionToken }).auth(config.provider)
        → Nango opens OAuth popup (iFrame)
        → User authorizes in popup
      → Step 3: Nango returns { connectionId, providerConfigKey }
      → Step 4: onSuccess(connectionId) → refetch /me/integrations
    Meanwhile: Nango sends webhook → POST /webhooks/nango → creates NangoConnection in DB
```

#### Package Dependency

```json
// package.json
"@nangohq/frontend": "^0.69.7"
```

---

### 9.2 Pipedream `@pipedream/connect-react` Evaluation

**Package:** [`@pipedream/connect-react`](https://github.com/PipedreamHQ/pipedream/tree/master/packages/connect-react)
**npm:** `@pipedream/connect-react`
**Dependencies:** `@pipedream/sdk`, `@tanstack/react-query`, `react-select`

#### What It Provides

| Component / Hook | Purpose | Relevant to Us? |
|------------------|---------|------------------|
| `FrontendClientProvider` | React context wrapping the Pipedream browser client | ✅ Yes — needed for any Pipedream React integration |
| `ComponentFormContainer` | Renders a form for configuring a Pipedream action/trigger (e.g. "send Slack message") | ❌ No — we don't use Pipedream actions/triggers |
| `ComponentForm` | Lower-level form for Pipedream component configuration | ❌ No |
| `CustomizeProvider` | Theming/styling for Pipedream components | ⚠️ Only if we use their components |
| `SelectApp` | App picker dropdown | ❌ No — we have a fixed list of integrations |
| `useAccounts` | React Query hook to list connected accounts | ✅ Yes — could replace our `useIntegrations` |
| `useApps` | React Query hook to list/search apps | ❌ No |
| `useFrontendClient` | Access the Pipedream client from context | ✅ Yes — needed for `connectAccount()` |

#### What It Does NOT Provide

**`@pipedream/connect-react` does NOT have a pre-built "Connect Account" button or dialog.** The `connectAccount()` method lives on the `BrowserClient` from `@pipedream/sdk/browser`, not in connect-react. The connect-react package is focused on **component forms** (configuring actions/triggers), not on the OAuth connection flow itself.

This means:
- The OAuth popup is triggered by calling `client.connectAccount({ app, oauthAppId, onSuccess, onError, onClose })` directly
- There is **no pre-built UI** for the connection flow — Pipedream opens a full-screen iFrame overlay
- We still need our own dialog/button UI to wrap the `connectAccount()` call

#### Recommendation: Hybrid Approach

**Use `@pipedream/sdk/browser` directly + keep our custom UI components.**

Rationale:
1. `connect-react` is designed for Pipedream action/trigger forms, not OAuth connection flows
2. Our existing `IntegrationCard`, `SwitchIntegrationDialog`, and `DisconnectIntegrationDialog` are **already Nango-agnostic** — they just need the hook swapped
3. Only `use-nango-auth.ts` needs to be rewritten → `use-pipedream-auth.ts`
4. `integration-connect-dialog.tsx` just needs its import changed
5. We get full control over UX, branding, error messages, and loading states

**Optionally install `@pipedream/connect-react`** for the `useAccounts` hook (to poll account health status) and `FrontendClientProvider` (to share the client instance). But this is a convenience, not a requirement.

---

### 9.3 Frontend Migration: File-by-File Plan

#### File 1: `src/lib/integrations-config.ts` — Update Config Shape

**Changes:** Rename `provider` → `appSlug`, add `oauthAppId`, remove `sessionTokenKey`

```typescript
// BEFORE (Nango)
export interface IntegrationConfig {
  id: string;
  displayName: string;
  shortDescription: string;
  fullDescription: string;
  image: string;
  provider: string;           // Nango provider key
  sessionTokenKey: string;    // Nango session token integration field
  apiMatchKeys: string[];
}

// AFTER (Pipedream)
export interface IntegrationConfig {
  id: string;
  displayName: string;
  shortDescription: string;
  fullDescription: string;
  image: string;
  appSlug: string;            // Pipedream app name_slug
  oauthAppId?: string;        // Pipedream custom OAuth app ID (oa_xxx)
  apiMatchKeys: string[];
}

export const AVAILABLE_INTEGRATIONS: IntegrationConfig[] = [
  {
    id: 'google-calendar',
    displayName: 'Google Calendar',
    shortDescription: 'Enable scheduling from calls',
    fullDescription: 'Connect your Google Calendar to let CallSaver check your availability and schedule appointments directly from incoming calls.',
    image: '/images/google-calendar.png',
    appSlug: 'google_calendar',
    oauthAppId: import.meta.env.VITE_PD_OAUTH_GOOGLE_CALENDAR, // oa_xxx
    apiMatchKeys: ['google-calendar'],
  },
  {
    id: 'jobber',
    displayName: 'Jobber',
    shortDescription: 'Sync jobs and customer data',
    fullDescription: 'Connect your Jobber account to sync job information, customer data, and scheduling details with CallSaver.',
    image: '/images/jobber.png',
    appSlug: 'jobber_developer_app',
    oauthAppId: import.meta.env.VITE_PD_OAUTH_JOBBER, // oa_xxx
    apiMatchKeys: ['jobber'],
  },
  {
    id: 'square-bookings',
    displayName: 'Square Bookings',
    shortDescription: 'Square Appointments integration',
    fullDescription: 'Connect your Square Bookings account to enable appointment scheduling and sync booking data with CallSaver.',
    image: '/images/square.png',
    appSlug: 'squareup',
    oauthAppId: import.meta.env.VITE_PD_OAUTH_SQUARE, // oa_xxx
    apiMatchKeys: ['square-bookings', 'squareup'],
  },
];
```

**New env vars** (frontend, public — OAuth app IDs are not sensitive):
```
VITE_PD_OAUTH_GOOGLE_CALENDAR=oa_xxx
VITE_PD_OAUTH_JOBBER=oa_xxx
VITE_PD_OAUTH_SQUARE=oa_xxx
```

---

#### File 2: `src/hooks/use-nango-auth.ts` → `src/hooks/use-pipedream-auth.ts` (REWRITE)

This is the **core change**. Replace the Nango SDK with Pipedream's `createFrontendClient` + `connectAccount()`.

```typescript
// src/hooks/use-pipedream-auth.ts
import { useState, useCallback, useRef } from 'react';
import { createFrontendClient } from '@pipedream/sdk/browser';
import { apiClient } from '@/lib/api-client';
import { logger } from '@/lib/logger';
import type { IntegrationConfig } from '@/lib/integrations-config';

const log = logger.child('UsePipedreamAuth');

export type PipedreamAuthStatus = 'idle' | 'loading' | 'connecting' | 'success' | 'error';

interface UsePipedreamAuthOptions {
  onSuccess?: (accountId: string) => void;
  onError?: (error: string) => void;
}

interface UsePipedreamAuthResult {
  status: PipedreamAuthStatus;
  error: string | null;
  connect: (config: IntegrationConfig) => Promise<void>;
  reset: () => void;
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    // Map common Pipedream errors to user-friendly messages
    if (error.message.includes('closed') || error.message.includes('close')) {
      return 'Authorization was cancelled. Please try again.';
    }
    if (error.message.includes('popup') || error.message.includes('blocked')) {
      return 'Pop-up was blocked by your browser. Please allow pop-ups for this site and try again.';
    }
    return error.message;
  }
  if (error && typeof error === 'object') {
    const err = error as { error?: string; message?: string };
    if (err.message) return err.message;
    if (err.error) return err.error;
  }
  return 'Something went wrong. Please try again.';
}

export function usePipedreamAuth(options: UsePipedreamAuthOptions = {}): UsePipedreamAuthResult {
  const { onSuccess, onError } = options;

  const [status, setStatus] = useState<PipedreamAuthStatus>('idle');
  const [error, setError] = useState<string | null>(null);
  const clientRef = useRef<ReturnType<typeof createFrontendClient> | null>(null);

  const reset = useCallback(() => {
    setStatus('idle');
    setError(null);
  }, []);

  const connect = useCallback(async (config: IntegrationConfig) => {
    try {
      setStatus('loading');
      setError(null);

      log.debug('Starting Pipedream OAuth flow for:', config.id);

      // Step 1: Get Connect token from backend
      const client = await apiClient;
      const tokenData = await client.user.createConnectToken();
      // Backend returns { token, expires_at }

      if (!tokenData.token) {
        throw new Error('Failed to get connect token from server');
      }

      log.debug('Got connect token, initializing Pipedream client');

      // Step 2: Create frontend client with token
      const pdClient = createFrontendClient({
        tokenCallback: async () => tokenData,
        externalUserId: tokenData.external_user_id,
      });
      clientRef.current = pdClient;

      // Step 3: Trigger OAuth flow via Pipedream iFrame
      setStatus('connecting');

      log.debug('Opening OAuth popup for app:', config.appSlug);

      await new Promise<void>((resolve, reject) => {
        pdClient.connectAccount({
          app: config.appSlug,
          oauthAppId: config.oauthAppId,
          onSuccess: (result) => {
            log.debug('OAuth flow completed successfully:', {
              accountId: result.id,
            });
            setStatus('success');
            onSuccess?.(result.id);
            resolve();
          },
          onError: (err) => {
            log.error('OAuth flow error:', err);
            reject(err);
          },
          onClose: (closeStatus) => {
            if (!closeStatus.successful) {
              if (!closeStatus.completed) {
                // User closed the popup without completing
                reject(new Error('Authorization was cancelled. Please try again.'));
              } else {
                reject(new Error('Connection failed. Please try again.'));
              }
            }
            // If successful, onSuccess already handled it
            resolve();
          },
        });
      });

    } catch (err) {
      log.error('OAuth flow failed:', err);
      const errorMessage = getErrorMessage(err);
      setError(errorMessage);
      setStatus('error');
      onError?.(errorMessage);
    }
  }, [onSuccess, onError]);

  return {
    status,
    error,
    connect,
    reset,
  };
}
```

**Key differences from Nango hook:**
- Uses `createFrontendClient` + `connectAccount()` instead of `new Nango().auth()`
- Backend endpoint changes from `POST /me/session-token` → `POST /me/connect-token`
- `connectAccount()` uses `onSuccess`/`onError`/`onClose` callbacks (wrapped in a Promise)
- Pipedream opens a full-screen iFrame overlay (not a popup window)
- Returns `accountId` (Pipedream `apn_xxx`) instead of `connectionId` (Nango UUID)

---

#### File 3: `src/components/integrations/integration-connect-dialog.tsx` — Swap Hook Import

**Minimal change** — just swap the import:

```typescript
// BEFORE
import { useNangoAuth, type NangoAuthStatus } from '@/hooks/use-nango-auth';

// AFTER
import { usePipedreamAuth, type PipedreamAuthStatus } from '@/hooks/use-pipedream-auth';
```

And update the usage:
```typescript
// BEFORE
const { status, error, connect, reset } = useNangoAuth({ onSuccess, onError });

// AFTER
const { status, error, connect, reset } = usePipedreamAuth({
  onSuccess: (accountId) => {
    if (integration) {
      onConnected(integration.id, accountId);
    }
  },
});
```

The `StatusContent` and `FooterActions` sub-components remain **unchanged** — they only depend on the status string (`idle`/`loading`/`connecting`/`success`/`error`) which is identical.

---

#### File 4: Backend — New `POST /me/connect-token` Endpoint

Replaces the existing `POST /me/session-token` endpoint:

```typescript
// src/server.ts
import { createBackendClient } from '@pipedream/sdk/server';

app.post('/me/connect-token', requireAuth, async (req, res) => {
  const userId = req.user.id;
  const member = await prisma.organizationMember.findFirst({
    where: { userId },
    select: { organizationId: true },
  });

  if (!member) {
    return res.status(404).json({ error: 'No organization' });
  }

  const pdClient = createBackendClient({
    projectId: process.env.PIPEDREAM_PROJECT_ID!,
    credentials: {
      clientId: process.env.PIPEDREAM_CLIENT_ID!,
      clientSecret: process.env.PIPEDREAM_CLIENT_SECRET!,
    },
    environment: process.env.PIPEDREAM_ENVIRONMENT as 'development' | 'production',
  });

  const tokenResponse = await pdClient.createConnectToken({
    external_user_id: member.organizationId,
    allowed_origins: [process.env.FRONTEND_URL || 'http://localhost:5173'],
    webhook_uri: `${process.env.API_URL}/webhooks/pipedream`,
  });

  res.json({
    token: tokenResponse.token,
    expires_at: tokenResponse.expires_at,
    external_user_id: member.organizationId,
  });
});
```

**Important:** The `allowed_origins` parameter is required by Pipedream to prevent cross-origin token abuse. Must match your frontend's origin exactly.

---

#### Files That Need NO Changes

These files are already Nango-agnostic and work with any auth provider:

| File | Why No Changes |
|------|----------------|
| `src/components/integrations/integration-card.tsx` | Pure presentational — takes `onConnect` callback |
| `src/components/integrations/switch-integration-dialog.tsx` | Pure confirmation dialog |
| `src/components/integrations/disconnect-integration-dialog.tsx` | Pure confirmation dialog |
| `src/hooks/use-integrations.ts` | Calls `/me/integrations` API — backend-agnostic |
| `src/pages/IntegrationsPage.tsx` | Orchestrates components — no Nango imports |
| `src/pages/OnboardingPage.tsx` | Reuses `IntegrationConnectDialog` — no Nango imports |

---

### 9.4 `@pipedream/connect-react` — Optional Enhancements

While we don't need connect-react for the core migration, it offers two useful hooks we could adopt later:

#### A. `useAccounts` — Poll Account Health

Replace or augment `useIntegrations` to show real-time account health from Pipedream:

```typescript
import { useAccounts } from '@pipedream/connect-react';

// In IntegrationCard or IntegrationsPage
const { accounts, isLoading } = useAccounts({
  external_user_id: organizationId,
  app: 'jobber_developer_app',
});

const jobberAccount = accounts[0];
const isHealthy = jobberAccount?.healthy && !jobberAccount?.dead;
const needsReauth = jobberAccount?.dead === true;
```

This would let us show a "Needs Reconnection" badge without needing our own health tracking DB columns (the `needsReauth` / `consecutiveFailures` fields planned in `nango-webhook-implementation.md` become unnecessary).

#### B. `FrontendClientProvider` — Shared Client Context

If we adopt connect-react, wrap the app in `FrontendClientProvider` to share the client:

```tsx
// src/App.tsx or layout
import { createFrontendClient } from '@pipedream/sdk/browser';
import { FrontendClientProvider } from '@pipedream/connect-react';

const pdClient = createFrontendClient({
  tokenCallback: fetchConnectToken,
  externalUserId: organizationId,
});

<FrontendClientProvider client={pdClient}>
  <App />
</FrontendClientProvider>
```

Then any component can use `useFrontendClient()` to access the client without prop drilling.

#### C. When to Adopt connect-react

| Scenario | Recommendation |
|----------|----------------|
| **Phase 1 (Jobber PoC)** | Skip connect-react. Use `@pipedream/sdk/browser` directly. |
| **Phase 2 (GCal + Square)** | Consider adding `FrontendClientProvider` if multiple components need the client. |
| **Future: Pipedream actions/triggers** | Adopt `ComponentFormContainer` if we ever want to embed Pipedream workflow forms. |
| **Future: Account health dashboard** | Adopt `useAccounts` for real-time health polling. |

---

### 9.5 UX Differences: Nango vs Pipedream

| Aspect | Nango | Pipedream |
|--------|-------|-----------|
| **OAuth popup** | Opens a new browser window/popup | Opens a **full-screen iFrame overlay** within the page |
| **Popup blocking** | Can be blocked by browser popup blockers | iFrame is not blocked (it's injected into the DOM) |
| **Close detection** | `detectClosedAuthWindow` option | `onClose` callback with `{ successful, completed }` status |
| **Error types** | `AuthError` with typed `type` field (`window_closed`, `blocked_by_browser`, etc.) | Generic `ConnectError` with message string |
| **Branding** | Nango-branded consent screen | Pipedream-branded consent screen (customizable via project settings) |
| **Session token** | `connectSessionToken` passed to `new Nango()` | `token` from `createConnectToken()`, passed via `tokenCallback` |

**UX impact:** The full-screen iFrame overlay is actually **better** than a popup because:
- No popup blocker issues
- No "complete the sign-in in the popup window" instructions needed
- User stays in context (overlay on top of the app)
- The `connecting` state in our dialog can be simplified

---

### 9.6 Frontend Environment Variables Summary

**Remove:**
```
# No Nango env vars in frontend currently (session token comes from backend)
```

**Add:**
```
# Pipedream OAuth App IDs (public, safe to expose)
VITE_PD_OAUTH_GOOGLE_CALENDAR=oa_xxx
VITE_PD_OAUTH_JOBBER=oa_xxx
VITE_PD_OAUTH_SQUARE=oa_xxx
```

**Backend (already in Section 4.4):**
```
PIPEDREAM_CLIENT_ID=xxx
PIPEDREAM_CLIENT_SECRET=xxx
PIPEDREAM_PROJECT_ID=proj_xxx
PIPEDREAM_ENVIRONMENT=development
PIPEDREAM_ALLOWED_ORIGINS=["https://app.callsaver.ai","http://localhost:5173"]
```

---

### 9.7 Frontend Package Changes

```bash
# Remove Nango
pnpm remove @nangohq/frontend

# Add Pipedream SDK (browser module for frontend)
pnpm add @pipedream/sdk

# Optional: add connect-react for useAccounts / FrontendClientProvider
# pnpm add @pipedream/connect-react
```

---

### 9.8 Frontend Migration Checklist

- [ ] Register custom OAuth apps in Pipedream dashboard → get `oauthAppId` values
- [ ] Add `VITE_PD_OAUTH_*` env vars to `.env.local` and deployment config
- [ ] Update `integrations-config.ts` — rename `provider`→`appSlug`, add `oauthAppId`, remove `sessionTokenKey`
- [ ] Create `use-pipedream-auth.ts` hook (rewrite of `use-nango-auth.ts`)
- [ ] Update `integration-connect-dialog.tsx` — swap hook import
- [ ] Add `POST /me/connect-token` backend endpoint
- [ ] Add `POST /webhooks/pipedream` backend endpoint
- [ ] Update generated API client types (if using openapi codegen)
- [ ] Test OAuth flow for each integration (Jobber, GCal, Square)
- [ ] Test onboarding wizard integration step
- [ ] Test switch-integration and disconnect flows
- [ ] Remove `@nangohq/frontend` from `package.json`
- [ ] Delete `use-nango-auth.ts`
- [ ] Remove old `POST /me/session-token` backend endpoint (after verifying nothing else uses it)

---

## 10. Database Migration

### Option A: Rename + repurpose NangoConnection (recommended)

```sql
-- Migration: rename nango_connections → integration_connections
ALTER TABLE nango_connections RENAME TO integration_connections;

-- Rename connection_id to more generic name
ALTER TABLE integration_connections RENAME COLUMN connection_id TO external_account_id;

-- Add Pipedream-specific columns
ALTER TABLE integration_connections
  ADD COLUMN provider TEXT DEFAULT 'nango',  -- 'nango' or 'pipedream'
  ADD COLUMN healthy BOOLEAN DEFAULT true,
  ADD COLUMN dead BOOLEAN DEFAULT false,
  ADD COLUMN last_refreshed_at TIMESTAMP,
  ADD COLUMN error_message TEXT;

-- Index for health queries
CREATE INDEX idx_integration_connections_health
  ON integration_connections(healthy, dead)
  WHERE dead = true OR healthy = false;
```

### Option B: Keep NangoConnection, just store Pipedream account IDs

Store the Pipedream `apn_xxx` account ID in the existing `connectionId` field. Minimal migration, but the name is confusing.

**Recommendation:** Option A — clean rename avoids confusion long-term.

---

## 11. Risk Assessment

### HIGH RISK: Cloudflare blocking Pipedream Proxy on Jobber
- **Mitigation:** Test proxy FIRST in Phase 1. If blocked, fall back to credential retrieval + direct axios (same as current approach).
- **Impact:** If proxy is also blocked, we still benefit from Pipedream's token refresh management — just can't use their proxy for Jobber specifically.

### MEDIUM RISK: Pipedream has same Jobber token refresh issue
- **Mitigation:** The community thread shows Pipedream already fixed this ("long-lived refresh tokens"). But we must verify with a 48-hour soak test.
- **Impact:** If Pipedream also fails, we move to Plan C (self-managed with Postgres advisory locks).

### LOW RISK: Pipedream rate limits (1,000 req / 5 min / project)
- **Mitigation:** Voice agent calls are low-frequency (a few API calls per phone call). Unlikely to hit limits.
- **Impact:** If hit, Pipedream returns 429. Our existing retry logic handles this.

### LOW RISK: Pipedream pricing
- **Mitigation:** Free in development. Verify production pricing fits budget before Phase 2.
- **Impact:** If too expensive, consider Composio or self-managed.

---

## 12. Rollback Plan

The migration is designed to be **incremental and reversible**:

1. **Phase 1 is Jobber-only** — Google Calendar stays on Nango during testing
2. **`provider` column** in the DB tracks which platform manages each connection
3. **Nango is not removed until Phase 4** — both platforms can coexist
4. **If Pipedream fails for Jobber**, simply set `provider = 'nango'` and revert JobberClient to use `nango.getConnection()`

---

## 13. Open Questions

| # | Question | Action |
|---|----------|--------|
| 1 | Does Pipedream Proxy work with Jobber (Cloudflare)? | **Test in Phase 1.2** |
| 2 | What is Pipedream Connect production pricing? | Check [pricing page](https://pipedream.com/pricing?plan=Connect) |
| 3 | Does Pipedream have a `jobber_developer_app` or just `jobber`? | Verify via `GET /v1/apps?q=jobber` |
| 4 | Does Pipedream support Housecall Pro? | Check app registry |
| 5 | How does Pipedream handle Jobber's refresh token rotation? | Ask Pipedream support, reference community thread |
| 6 | Do we need to re-authenticate all existing users when switching? | **Yes** — Pipedream has its own token store. Cannot migrate Nango tokens. |
| 7 | Can we use Pipedream's MCP server for AI agent tool calls? | Future consideration — could simplify field service tool layer |

---

## 14. Square Bookings Deprecation (Pre-Launch)

**Decision:** Temporarily remove Square Bookings from the UI for launch. Square was only in sandbox mode (`squareup-sandbox`) and has no active users. Re-add post-launch when Square production OAuth is configured in Pipedream.

### Frontend Changes Required

#### File 1: `callsaver-frontend/src/lib/integrations-config.ts`
**Action:** Remove the `square-bookings` entry from `AVAILABLE_INTEGRATIONS` array.

```typescript
// REMOVE this entire block (lines 50-59):
  {
    id: 'square-bookings',
    displayName: 'Square Bookings',
    shortDescription: 'Square Appointments integration',
    fullDescription: 'Connect your Square Bookings account to enable appointment scheduling and sync booking data with CallSaver.',
    image: '/images/square.png',
    provider: 'squareup-sandbox',
    sessionTokenKey: 'squareup-sandbox',
    apiMatchKeys: ['square-bookings', 'squareup-sandbox'],
  },
```

This single change removes Square from both the **Onboarding page** (step 3 integration grid) and the **Settings > Integrations** page, since both iterate `AVAILABLE_INTEGRATIONS`.

#### File 2: `callsaver-frontend/src/pages/OnboardingPage.tsx`
**Action:** Two changes:

1. **Line 442** — Remove `square-bookings` from `integrationManagesServices` check:
```typescript
// BEFORE:
const integrationManagesServices = connectedIntegrationType === 'jobber'
    || connectedIntegrationType === 'square-bookings';
// AFTER:
const integrationManagesServices = connectedIntegrationType === 'jobber';
```

2. **Lines 1624-1631** — Remove the Square-specific image styling branch. With Square removed from `AVAILABLE_INTEGRATIONS`, this code is dead, but clean it up:
```typescript
// BEFORE:
{cfg.id === 'square-bookings' ? (
  <div className="h-14 w-14 bg-white rounded-lg flex items-center justify-center p-2">
    <img src={cfg.image} alt={cfg.displayName} className="h-10 w-10 object-contain" />
  </div>
) : (
  <img src={cfg.image} alt={cfg.displayName} className={`h-14 w-14 object-contain ${cfg.id === 'jobber' ? 'rounded-lg' : ''}`} />
)}
// AFTER:
<img src={cfg.image} alt={cfg.displayName} className={`h-14 w-14 object-contain ${cfg.id === 'jobber' ? 'rounded-lg' : ''}`} />
```

#### File 3: `callsaver-frontend/src/components/app-tour/tour-steps.ts`
**Action:** Update tour text (line 118):
```typescript
// BEFORE:
content: 'Connect your calendar or field service software - Google Calendar, Jobber, Square, and more.',
// AFTER:
content: 'Connect your calendar or field service software - Google Calendar, Jobber, and more.',
```

### Backend Changes Required

#### File: `callsaver-api/src/server.ts`
**Action:** Remove `squareup-sandbox` from the valid integrations whitelist:
```typescript
// Line 6751 — BEFORE:
const validIntegrations = ['google-calendar', 'jobber', 'squareup-sandbox'];
// AFTER:
const validIntegrations = ['google-calendar', 'jobber'];

// Line 6758 — BEFORE:
allowedIntegrations = ['google-calendar', 'jobber', 'squareup-sandbox'];
// AFTER:
allowedIntegrations = ['google-calendar', 'jobber'];
```

Optionally remove the Square-specific error handling block (~lines 6972-6989) but it's harmless dead code.

### What NOT to Remove
- **`/images/square.png`** — keep the asset for when Square is re-added
- **Backend Square adapter code** (if any) — keep for future use
- **Nango `squareup-sandbox` integration config** — leave in Nango until full Nango removal

### Re-enabling Square Post-Launch
1. Register Square OAuth app in Pipedream (production, not sandbox)
2. Add `square-bookings` entry back to `AVAILABLE_INTEGRATIONS` with Pipedream `appSlug` and `oauthAppId`
3. Add `squareup` back to backend valid integrations list
4. Test end-to-end

---

## Immediate Next Steps (Action Items)

Here's the current status and what to do next:

### ✅ Completed
- Created Pipedream project (`proj_BgsRyvp`)
- Registered Jobber OAuth app in Pipedream (name: "jobber")
- Registered Google Calendar OAuth app in Pipedream

### Step 1: Note Your OAuth App IDs (~2 min)
Go to [pipedream.com/@/accounts/oauth-clients](https://pipedream.com/@/accounts/oauth-clients), expand each client, and note the `oauthAppId` values (e.g. `oa_xxx`) for both Jobber and Google Calendar. You'll need these in code.

### Step 2: Create Pipedream API OAuth Client (~5 min)
1. Go to [pipedream.com/settings/api](https://pipedream.com/settings/api)
2. Create a new OAuth client (this is separate from the Jobber/GCal OAuth apps)
3. Save the `client_id` and `client_secret` — these authenticate YOUR backend to Pipedream's API

### Step 3: Add Pipedream's Redirect URI to Google Cloud Console (~5 min)
Pipedream should have shown you the redirect URI when you created the Google Calendar OAuth client. Add it to your Google Cloud Console OAuth client's authorized redirect URIs.

### Step 4: Configure Project Branding (~5 min)
1. Open project `proj_BgsRyvp` in Pipedream → **Connect** tab → **Configuration**
2. Set app name: `CallSaver`, support email, upload logo

### Step 5: Add Environment Variables (~5 min)
Add to `callsaver-api/.env.local`:
```
PIPEDREAM_CLIENT_ID=<from step 2>
PIPEDREAM_CLIENT_SECRET=<from step 2>
PIPEDREAM_PROJECT_ID=proj_BgsRyvp
PIPEDREAM_ENVIRONMENT=development
```

### Step 6: Deprecate Square Bookings (~15 min)
Apply the 4 frontend + backend changes listed in Section 14.

### Step 7: Start Phase 1 Code (~2-3 hours)
Install `@pipedream/sdk`, implement the backend token endpoint, rewrite the frontend auth hook, and test connecting a Jobber account. Follow Section 5 of this plan.

---

## Implementation Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| **Pre-migration setup** | 1 day | Pipedream account, OAuth client registration |
| **Phase 1: Jobber PoC** | 2-3 days | Pre-migration complete |
| **Phase 1 soak test** | 2-7 days | Phase 1 code complete |
| **Phase 2: GCal + Square** | 1-2 days | Phase 1 soak test passed |
| **Phase 3: Housecall Pro** | 1 day | Phase 2 complete |
| **Phase 4: Remove Nango** | 1 day | All integrations verified |
| **Total** | ~1-2 weeks |  |

---

## Decision Criteria

**Proceed with full migration if:**
- [ ] Jobber token refresh is reliable over 48+ hours
- [ ] No Cloudflare blocking on proxy (or direct credential retrieval works)
- [ ] Pipedream production pricing is acceptable
- [ ] Account health monitoring (`healthy`/`dead`) works as documented

**Abort migration if:**
- [ ] Same `refresh_token_external_error` pattern appears
- [ ] Pipedream's Jobber integration is broken/unsupported
- [ ] Production pricing is prohibitive

**If aborted:** Fall back to Plan C (self-managed OAuth with Postgres advisory locks) as documented in `nango-jobber-token-reliability.md`.

---

## Appendix A: Pipedream App Slugs Reference

| Integration | Pipedream App Slug | Auth Type |
|-------------|--------------------|-----------|
| Jobber (custom app) | `jobber_developer_app` | OAuth 2.0 |
| Jobber (Pipedream default) | `jobber` | OAuth 2.0 |
| Google Calendar | `google_calendar` | OAuth 2.0 |
| Square | `squareup` | OAuth 2.0 |
| Square (sandbox) | `squareup_sandbox` | OAuth 2.0 |
| Housecall Pro | TBD | API Key |

## Appendix B: Pipedream Connect Proxy Limits

- 1,000 requests per 5 minutes per project
- 30 second max timeout per request
- Restricted headers: `Accept-Encoding`, `Cookie`, `Host`, `Origin`, headers starting with `Proxy-` or `Sec-`
- Custom headers must use `x-pd-proxy` prefix to be forwarded

## Appendix C: Relevant Pipedream Docs

- [Connect Overview](https://pipedream.com/docs/connect)
- [Managed Auth Quickstart](https://pipedream.com/docs/connect/managed-auth/quickstart)
- [Connect Proxy](https://pipedream.com/docs/connect/api-proxy)
- [OAuth Clients](https://pipedream.com/docs/connect/managed-auth/oauth-clients)
- [Connect Webhooks](https://pipedream.com/docs/connect/managed-auth/webhooks)
- [Retrieve Account (with credentials)](https://pipedream.com/docs/connect/api-reference/retrieve-account)
- [Connect Tokens](https://pipedream.com/docs/connect/managed-auth/tokens)
- [Custom Tools](https://pipedream.com/docs/connect/components/custom-tools)
- [SDK TypeScript](https://pipedream.com/docs/connect/api-reference/sdks)
- [Jobber Token Refresh Community Thread](https://pipedream.com/community/t/how-to-handle-access-token-expiration-and-refresh-token-requests-in-jobber-api-integration/10127)
- [connect-react README (GitHub)](https://github.com/PipedreamHQ/pipedream/tree/master/packages/connect-react)
- [Pipedream SDK Browser Client (source)](https://github.com/PipedreamHQ/pipedream/blob/master/packages/sdk/src/browser/index.ts)
