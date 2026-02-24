# Nango + Jobber Token Reliability

## Status
**Active concern** — Jobber refresh tokens are failing intermittently via Nango Cloud, causing integration outages that require manual reconnection.

## Current Setup
- **Nango Cloud** (not self-hosted) — `https://api.nango.dev`
- **Nango SDK**: `@nangohq/node@0.69.20`
- **Auth flow**: `nango.getConnection('jobber', connectionId)` → extract `access_token` → direct `axios.post()` to Jobber GraphQL API
- **Cannot use Nango Proxy**: Jobber's API (`api.getjobber.com`) is behind Cloudflare, which blocks requests from Nango's proxy servers (returns Cloudflare challenge page)

## The Problem

### Error observed
```
type: "refresh_token_external_error"
message: "The external API returned an error when trying to refresh the access token."
```

Nango Cloud tried to refresh the Jobber access token using the stored refresh token, and Jobber's OAuth endpoint (`https://api.getjobber.com/api/oauth/token`) returned a **401 Unauthorized**, meaning the refresh token itself is invalid/expired/revoked.

### Possible causes
1. **Jobber revoked the refresh token** — user disconnected the app in Jobber settings, or Jobber's internal token rotation policy invalidated it
2. **Nango Cloud bug with Jobber's refresh token rotation** — Jobber issues a new refresh token on every use; if Nango doesn't store the new one atomically, subsequent refreshes fail
3. **Intermittent Jobber OAuth endpoint failures** — Jobber's token endpoint returning transient 401s
4. **Race condition in Nango Cloud** — multiple concurrent `getConnection()` calls could theoretically trigger multiple refresh attempts, though Nango Cloud should serialize these

### Why Nango Proxy doesn't work for Jobber
Jobber's API is behind Cloudflare. When requests come from Nango's proxy servers (shared infrastructure IPs), Cloudflare returns a "Just a moment..." challenge page (HTML) instead of the API response. This forces us to use `getConnection()` + direct axios calls from our own server.

## Current Implementation

### JobberClient.ts
- `getAccessToken()` calls `nango.getConnection()` to fetch token
- `query()` makes direct axios calls to Jobber's GraphQL API
- On 401 from Jobber: fetches fresh token via `getAccessToken()` and retries once
- Detects `refresh_token_external_error` and `invalid_credentials` from Nango and throws `TOKEN_PERMANENTLY_INVALIDATED`

### What we tried and reverted
1. **Token caching + refresh lock** — added in-memory `tokenCache` and `refreshPromise` lock to prevent concurrent refreshes. Removed because Nango Cloud should handle this internally.
2. **Nango Proxy** — switched to `nango.post()` for all Jobber API calls. Reverted because Cloudflare blocks Nango's proxy servers.

## Contingency Plans (in priority order)

### Plan A: Stay on Nango Cloud + monitor
- Current approach. If failures are rare (< 1% of calls), acceptable for launch.
- Add monitoring/alerting for `TOKEN_PERMANENTLY_INVALIDATED` errors.
- Auto-notify customers when reconnection is needed.

### Plan B: Try alternative OAuth platforms

**Priority 1 — Pipedream Connect**
- ~11k GitHub stars, acquired by Workday (enterprise backing)
- "Connect" is a dedicated managed OAuth product (not a side feature)
- Has Jobber listed as a supported integration
- SDK provides raw access tokens — compatible with our direct axios approach
- Mature platform, likely handles Jobber's refresh token rotation correctly
- https://pipedream.com/connect

**Priority 2 — Composio**
- ~15k GitHub stars, specifically built for AI agent tool integrations
- Managed auth returns raw tokens
- Natural fit for AI voice agent use case, but newer company
- Unclear if Jobber is specifically supported — verify before investing time
- https://composio.dev

**Dropped: Membrane** — too small (~400 stars), unclear Jobber support, risky for production launch.
**Dropped: Paragon** — enterprise-heavy, overkill for our needs.

**Test criteria for any platform**: Connect Jobber, fire 10 concurrent token requests, verify no refresh failures over 24 hours.

### Plan C: Self-managed OAuth with Postgres advisory locks
If all platforms fail with Jobber, build our own token management:

- **Store tokens** in an encrypted `OAuthToken` Prisma model (access_token, refresh_token, expires_at)
- **Use `pg_advisory_xact_lock`** on a hash of the connection ID to serialize refresh operations
- **Refresh flow**: acquire lock → check if token was already refreshed by another request → if not, call Jobber's OAuth endpoint directly → store new tokens → release lock
- **Encryption**: AES-256-GCM for tokens at rest
- **Estimated effort**: ~200-300 lines of code + new Prisma model
- **Risk**: We become responsible for OAuth infrastructure maintenance

### Architecture for Plan C (if needed)
```
Request A ──┐
Request B ──┼── pg_advisory_xact_lock(hash(connection_id))
Request C ──┘         │
                      ▼
             Check token expiry in DB
             If expired:
               Call Jobber /api/oauth/token with refresh_token
               Store new access_token + refresh_token
             Release lock
             Return access_token
```

## Decision Log
| Date | Decision | Reason |
|------|----------|--------|
| 2025-02-21 | Added token cache + refresh lock | Prevent concurrent refresh race conditions |
| 2025-02-21 | Removed token cache + refresh lock | Nango Cloud handles this internally |
| 2025-02-21 | Tried Nango Proxy | Eliminate token handling entirely |
| 2025-02-21 | Reverted Nango Proxy | Cloudflare on api.getjobber.com blocks Nango's proxy servers |
| 2025-02-21 | Reverted to getConnection() + direct axios | Only viable approach given Cloudflare constraint |

## Next Steps
1. Monitor Nango Cloud reliability over the next week with real Jobber connections
2. If failures persist, contact Nango support about Jobber-specific refresh token handling
3. If unresolved, evaluate **Pipedream Connect** as Plan B (primary alternative)
4. If Pipedream also fails, evaluate **Composio** (secondary alternative)
5. Plan C (self-managed with Postgres advisory locks) only if all platforms fail
