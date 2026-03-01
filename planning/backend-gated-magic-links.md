# Backend-Gated Magic Links

## Problem

Supabase's "Allow new users to sign up" toggle, when disabled, blocks `signInWithOtp()` entirely — even for existing users. This is because Supabase treats OTP/magic link as a combined sign-up/sign-in flow. We disabled signups to stop spam bot accounts, but this broke magic link sign-in for all existing users.

## Solution

Route magic link requests through the callsaver-api backend using the **Supabase Admin API**, which bypasses the signup restriction. The frontend no longer calls Supabase Auth directly for sign-in — it calls our backend instead.

**Supabase Dashboard setting**: Keep "Allow new users to sign up" **disabled**.

---

## Architecture

```
Frontend (login-form.tsx)
  │
  ├── Currently: supabase.auth.signInWithOtp({ email }) ← BLOCKED by signup restriction
  │
  └── New: POST /auth/magic-link { email } → callsaver-api
                                                  │
                                                  ├── 1. Check if user exists (admin.listUsers)
                                                  ├── 2. If exists → admin.generateLink({ type: 'magiclink', email })
                                                  ├── 3. Send email via our email provider (or let Supabase send it)
                                                  └── 4. Return 200 OK (always, to avoid leaking user existence)
```

---

## Backend Changes (callsaver-api)

### 1. New endpoint: `POST /auth/magic-link`

**File**: `src/server.ts` (or a new `src/routes/auth.ts` if preferred)

**Request body**:
```json
{
  "email": "user@example.com"
}
```

**Response** (always 200 to prevent email enumeration):
```json
{
  "success": true,
  "message": "If an account exists with this email, a magic link has been sent."
}
```

**Implementation**:
```typescript
import { createClient } from '@supabase/supabase-js';

// Admin client (uses service_role key, NOT anon key)
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

app.post('/auth/magic-link', async (req, res) => {
  const { email } = req.body;

  if (!email || typeof email !== 'string') {
    return res.status(400).json({ error: 'Email is required' });
  }

  // Normalize email
  const normalizedEmail = email.trim().toLowerCase();

  try {
    // 1. Check if user exists
    const { data: { users }, error: listError } = await supabaseAdmin.auth.admin.listUsers({
      filter: `email.eq.${normalizedEmail}`,
      page: 1,
      perPage: 1,
    });

    if (listError) {
      console.error('Error checking user existence:', listError);
      // Return success anyway to avoid leaking info
      return res.json({ success: true, message: 'If an account exists, a magic link has been sent.' });
    }

    // 2. If user doesn't exist, return success (don't leak)
    if (!users || users.length === 0) {
      console.log(`Magic link requested for non-existent email: ${normalizedEmail}`);
      return res.json({ success: true, message: 'If an account exists, a magic link has been sent.' });
    }

    // 3. Generate magic link for existing user
    const { data, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: normalizedEmail,
      options: {
        redirectTo: `${process.env.FRONTEND_URL}/dashboard`,
      },
    });

    if (linkError) {
      console.error('Error generating magic link:', linkError);
      return res.json({ success: true, message: 'If an account exists, a magic link has been sent.' });
    }

    // 4. Option A: Let Supabase send the email automatically
    //    generateLink with type 'magiclink' sends the email via Supabase's
    //    configured email provider by default.
    //
    // 4. Option B: If Supabase doesn't auto-send with generateLink,
    //    use the returned `data.properties.hashed_token` to construct
    //    the magic link URL and send via our own email service:
    //
    //    const magicLinkUrl = `${FRONTEND_URL}/sign-in?token_hash=${data.properties.hashed_token}&type=email`;
    //    await sendEmail(normalizedEmail, magicLinkUrl);

    return res.json({ success: true, message: 'If an account exists, a magic link has been sent.' });

  } catch (error) {
    console.error('Unexpected error in magic link endpoint:', error);
    return res.json({ success: true, message: 'If an account exists, a magic link has been sent.' });
  }
});
```

### 2. Rate limiting

Add rate limiting to prevent abuse. This endpoint is unauthenticated so it needs protection:

```typescript
// Rate limit: 5 requests per email per 15 minutes, 20 total per IP per 15 minutes
// Use the existing Redis instance for rate limiting
```

### 3. Environment variables needed

The backend already has `SUPABASE_URL` and likely has the service role key. Verify:

- `SUPABASE_URL` — already in env
- `SUPABASE_SERVICE_ROLE_KEY` — check if already available, if not add to Secrets Manager:
  - Secret name: `callsaver/staging/backend/SUPABASE_SERVICE_ROLE_KEY`
  - Value: from Supabase Dashboard → Settings → API → `service_role` key
  - **IMPORTANT**: The service_role key has FULL admin access. Never expose to frontend.
- `FRONTEND_URL` — e.g. `https://staging.app.callsaver.ai`

### 4. CORS

The `/auth/magic-link` endpoint must be accessible from the frontend origin. Verify CORS config allows `staging.app.callsaver.ai`.

---

## Frontend Changes (callsaver-frontend)

### 1. Update `auth-client.tsx`

Replace the direct Supabase `signInWithOtp` call with a fetch to the backend:

**File**: `src/lib/auth-client.tsx`

```typescript
// BEFORE (line 108-125):
export const signIn = {
  email: async ({ email, options }: { email: string; ... }) => {
    return supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/dashboard`,
        ...options,
      },
    });
  },
};

// AFTER:
export const signIn = {
  email: async ({ email }: { email: string }) => {
    const response = await fetch(`${import.meta.env.VITE_API_URL}/auth/magic-link`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    });

    if (!response.ok) {
      const body = await response.json().catch(() => ({}));
      return { error: { message: body.error || 'Failed to send magic link' } };
    }

    return { error: null };
  },
};
```

### 2. No changes to `login-form.tsx`

The form already calls `authClient.signIn.email({ email })` and handles the `{ error }` response shape. The success message already says "If an account is associated with [email]..." which is perfect for the new flow.

### 3. No changes to `SignInPage.tsx`

The OTP verification flow (`verifyOtp` with `token_hash`) remains unchanged — the magic link in the email still points to `/sign-in?token_hash=...&type=email` and the existing verification code handles it.

---

## Important: `generateLink` behavior

Supabase's `admin.generateLink()` returns a `data` object with:

```typescript
{
  properties: {
    action_link: string,    // Full magic link URL (uses Supabase site URL)
    hashed_token: string,   // The token_hash for verification
    email_otp: string,      // The OTP code
    redirect_to: string,    // Where to redirect after verification
    verification_type: string
  },
  user: { ... }             // The user object
}
```

**Key question**: Does `generateLink` automatically send the email?

- **NO** — `generateLink` only generates the link data. It does NOT send an email.
- You must either:
  - **Option A (simpler)**: Use `supabaseAdmin.auth.admin.inviteUserByEmail()` instead — but this is for invitations, not magic links.
  - **Option B (recommended)**: Use `generateLink` to get the `hashed_token`, construct the magic link URL yourself, and send it via your own email service (SES, Resend, etc.) or via Supabase's built-in email by calling `signInWithOtp` from the SERVER side using the admin client.

### Recommended approach for sending the email:

```typescript
// After confirming user exists, use the admin client to call signInWithOtp
// The admin client with service_role key bypasses the signup restriction
const { error } = await supabaseAdmin.auth.signInWithOtp({
  email: normalizedEmail,
  options: {
    emailRedirectTo: `${process.env.FRONTEND_URL}/sign-in`,
    shouldCreateUser: false,  // Explicitly prevent new user creation
  },
});
```

The `shouldCreateUser: false` option is the key — it tells Supabase to send the OTP email but NOT create a new user if one doesn't exist. Combined with the service_role key, this bypasses the dashboard "allow signups" toggle.

**This is actually the simplest implementation** — you may not even need the `listUsers` check if `shouldCreateUser: false` works correctly (it should return an error for non-existent users, which you can silently swallow).

---

## Simplified Implementation

Given `shouldCreateUser: false`, the endpoint simplifies to:

```typescript
app.post('/auth/magic-link', async (req, res) => {
  const { email } = req.body;
  if (!email || typeof email !== 'string') {
    return res.status(400).json({ error: 'Email is required' });
  }

  try {
    // signInWithOtp with shouldCreateUser: false + service_role key
    // bypasses the "allow signups" toggle and only works for existing users
    const { error } = await supabaseAdmin.auth.signInWithOtp({
      email: email.trim().toLowerCase(),
      options: {
        emailRedirectTo: `${process.env.FRONTEND_URL}/sign-in`,
        shouldCreateUser: false,
      },
    });

    // Swallow errors silently (don't leak whether user exists)
    if (error) {
      console.log(`Magic link OTP error for ${email}: ${error.message}`);
    }
  } catch (err) {
    console.error('Unexpected error in magic link endpoint:', err);
  }

  // Always return success
  return res.json({ success: true, message: 'If an account exists, a magic link has been sent.' });
});
```

---

## Checklist

### Backend (callsaver-api)
- [ ] Verify `SUPABASE_SERVICE_ROLE_KEY` is available in env (check Secrets Manager)
- [ ] Create Supabase admin client (service_role key)
- [ ] Add `POST /auth/magic-link` endpoint
- [ ] Add rate limiting (per-email + per-IP)
- [ ] Verify CORS allows frontend origin
- [ ] Test: existing user receives magic link email
- [ ] Test: non-existent user gets 200 OK but no email
- [ ] Deploy to staging

### Frontend (callsaver-frontend)
- [ ] Update `signIn.email()` in `auth-client.tsx` to call backend instead of Supabase directly
- [ ] Verify `VITE_API_URL` env var points to correct backend
- [ ] Test: login form sends request to backend
- [ ] Test: magic link email arrives and verification works
- [ ] Deploy to staging

### Supabase Dashboard
- [ ] Keep "Allow new users to sign up" **disabled**
- [ ] Verify email templates still work (they should — we're using the same OTP flow server-side)

---

## Security Notes

1. **Never expose the service_role key** to the frontend. It stays server-side only.
2. **Always return 200** from `/auth/magic-link` regardless of whether the user exists — prevents email enumeration attacks.
3. **Rate limit aggressively** — this is an unauthenticated endpoint. 5 per email per 15 min, 20 per IP per 15 min.
4. **Log but don't expose** errors from the Supabase admin API.
5. The `shouldCreateUser: false` flag is critical — without it, the admin client would create users for unknown emails even with signups disabled in the dashboard.
