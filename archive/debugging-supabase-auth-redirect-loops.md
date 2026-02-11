# Debugging Supabase Auth Redirect Loops

**Date:** February 9, 2026  
**Issue:** Web UI stuck in redirect loops between `/sign-in` and `/dashboard`  
**Environment:** Staging (`staging.app.callsaver.ai`)

## Symptoms

1. User logs in via magic link → Supabase session established ✅
2. Web UI redirects to `/dashboard` → immediately redirects back to `/sign-in`
3. Infinite loop between `/sign-in` and `/dashboard`
4. API calls to `/me/organization` return 401 "Invalid or expired Supabase session"
5. Browser DevTools shows valid Supabase session (access token, user ID, email)

## Root Cause Analysis

### Initial Misleading Clues

- **Supabase keys looked fake:** `sb_publishable_` and `sb_secret_` format (not `eyJ...` JWTs)
  - **Reality:** This is Supabase's newer key format — perfectly valid
- **Magic links worked:** Browser auth succeeded
  - **Reality:** Browser client talks directly to Supabase, bypassing API verification

### Actual Root Cause

The API's `supabase-auth.ts` had a broken custom `fetch` wrapper:

```typescript
// BROKEN CODE (removed)
global: {
  fetch: (url, options = {}) => {
    if (process.env.NODE_ENV === 'development') {
      const https = require('https'); // ❌ CommonJS in ESM module
      const agent = new https.Agent({
        rejectUnauthorized: false
      });
      return fetch(url, {
        ...options,
        agent: agent
      });
    }
    return fetch(url, options);
  }
}
```

**Why it failed:**
- `require('https')` doesn't work in ESM modules → `require is not defined`
- Every `auth.getUser(accessToken)` call crashed
- API couldn't verify Supabase access tokens → 401 on all authenticated requests
- Frontend received 401 → redirected to `/sign-in` → loop

## Solution

### Fix Applied

Removed the broken custom fetch wrapper from `~/callsaver-api/src/services/supabase-auth.ts`:

```typescript
// FIXED CODE
supabaseServiceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false
  }
  // ❌ Removed broken custom fetch wrapper
});
```

### Why This Is Safe

- **Local development:** `NODE_TLS_REJECT_UNAUTHORIZED=0` already handles SSL issues
- **Staging/production:** No SSL issues with valid certificates
- **Supabase calls:** Use HTTPS with valid certs in all environments

## Debugging Tools Added

Temporarily added debug UI to `SignInPage.tsx` (accessible via `/sign-in?debug=true`):

- Shows current session state (user ID, email, expiry)
- "Sign Out & Clear Session" button to clear stale tokens
- "Test /me/organization" button to directly test API endpoint
- Displays raw API response status and body

**Important:** Remove debug UI before production deployment.

## Deployment Impact

### Local Development
- ✅ Fixed immediately after restarting API
- ✅ `/me/organization` returns 200 with user/org data

### Staging Environment
- ❌ Still has old broken code in ECS container
- ✅ Fix: Rebuild Docker image and force new ECS deployment

### Production Environment
- ⚠️ Will have same issue if deployed with old code
- ✅ Fix: Ensure `supabase-auth.ts` fix is included in production build

## Prevention

### Code Review Checklist

1. **ESM compatibility:** Never use `require()` in ESM modules
2. **SSL handling:** Use `NODE_TLS_REJECT_UNAUTHORIZED=0` for dev, not custom fetch
3. **Supabase client:** Keep default fetch implementation unless absolutely necessary

### Testing Checklist

1. **Local auth flow:** Test magic link → dashboard → API calls
2. **Staging auth flow:** Verify same flow works after deployment
3. **Error logs:** Check for `require is not defined` or `AuthRetryableFetchError`

## Related Files

- `~/callsaver-api/src/services/supabase-auth.ts` - Fixed file
- `~/callsaver-api/src/middleware/auth.ts` - Auth middleware (calls supabase-auth)
- `~/callsaver-web-ui/src/pages/SignInPage.tsx` - Debug UI (temporary)
- `~/callsaver-web-ui/src/components/routing/AuthenticatedRoute.tsx` - Route guard
- `~/callsaver-web-ui/src/context/user-state-provider.tsx` - User state context

## Quick Recovery Commands

If this happens again:

```bash
# Check API logs for the error
grep -i "require is not defined\|AuthRetryableFetchError" api.log

# Verify fix locally
curl http://localhost:3000/api/me/organization \
  -H "Authorization: Bearer <access-token>"

# Deploy fix to staging
cd ~/callsaver-api
docker build -t callsaver-node-api:staging-latest .
docker tag callsaver-node-api:staging-latest 836347236108.dkr.ecr.us-west-1.amazonaws.com/callsaver-node-api:staging-latest
docker push 836347236108.dkr.ecr.us-west-1.amazonaws.com/callsaver-node-api:staging-latest
aws ecs update-service --cluster Callsaver-Cluster-staging --service callsaver-node-api-staging --force-new-deployment
```

## Lessons Learned

1. **ESM vs CommonJS:** Always check module system compatibility
2. **SSL in development:** Use environment variables, not custom fetch
3. **Debugging:** Add debug UI early to isolate auth vs API issues
4. **Deployment:** Test auth flow in each environment after changes
