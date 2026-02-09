# Supabase User Creation Workflow

End-to-end user registration, email verification, and first login experience.

---

## Overview

```
User                     Supabase                  Dashboard                 API Service
────                     ────────                  ─────────                 ───────────
Fill signup form    →    Create auth account   →   Show "check email"
                         Send verification email
Click email link    →    Validate token        →   Redirect to Site URL
                         Set session                Parse #access_token
                                                    Set auth state       →   Lazy-create local user
                                                    Fetch enhanced profile   Return tier + quotas
                                                    Render dashboard
```

---

## Step-by-Step Flow

### 1. Registration

| Step | What Happens |
|------|--------------|
| User navigates to `/register` | Registration form displayed |
| User enters email + password | Minimum 8 characters for password |
| Submit | `supabase.auth.signUp({ email, password })` called |
| Supabase creates account | User record created in Supabase project (not yet in local DB) |
| Confirmation email sent | Supabase sends verification link to user's email |
| UI feedback | "Please check your email for verification" message shown |

### 2. Email Verification

| Step | What Happens |
|------|--------------|
| User opens email | Clicks verification link from Supabase |
| Browser navigates | To `{Supabase Site URL}/#access_token=...&type=signup` |
| Supabase SDK | `detectSessionInUrl: true` automatically parses the hash fragment |
| Session established | JWT stored in localStorage, `SIGNED_IN` event fires |

### 3. First Login (Automatic After Verification)

| Step | What Happens |
|------|--------------|
| `SIGNED_IN` event | `AuthContext` creates initial user object from JWT claims |
| Token synced | `auth_token` saved to localStorage for API calls |
| Dashboard renders | User sees dashboard with default developer tier |
| Background API call | `getEnhancedUser()` triggers `GET /api/v1/users/me/enhanced` |
| Local user created | API middleware creates user record in local PostgreSQL (lazy sync) |
| Profile updated | Dashboard receives actual tier and quota data |

### 4. Subsequent Logins

| Step | What Happens |
|------|--------------|
| User navigates to `/login` | Login form displayed |
| Enter email + password | `supabase.auth.signInWithPassword()` called |
| Session restored | JWT refreshed, `SIGNED_IN` event fires |
| API call | `getEnhancedUser()` finds existing local user, returns profile |

---

## OAuth Login (Alternative)

| Step | What Happens |
|------|--------------|
| User clicks "Sign in with Google/GitHub" | `supabase.auth.signInWithOAuth()` called |
| Redirect | Browser redirected to OAuth provider |
| User authorizes | Grants access to BlockSecOps |
| Redirect back | `redirectTo: window.location.origin` returns user to dashboard |
| Session set | Same `SIGNED_IN` flow as email verification |

---

## Troubleshooting

### Blank Page After Email Verification

**Cause:** Supabase Site URL points to wrong address (e.g., `http://127.0.0.1:3000` instead of `http://app.blocksecops.local`).

**Fix:** Update Supabase project settings:
1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → Project → Authentication → URL Configuration
2. Set **Site URL** to `http://app.blocksecops.local`
3. Add `http://app.blocksecops.local/**` to **Redirect URLs**

### User Not Appearing in Local Database

**Cause:** User sync is lazy — happens on first authenticated API call, not at Supabase signup time.

**Normal behavior:** The user is created in the local database when the dashboard's `AuthContext` calls `getEnhancedUser()` after the `SIGNED_IN` event. If the dashboard fails to load (blank page), the sync never triggers.

**Manual check:**
```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -c "
import asyncio
from src.infrastructure.database.session import async_session_factory
from sqlalchemy import text
async def check():
    async with async_session_factory() as db:
        r = await db.execute(text(\"SELECT email, tier FROM users ORDER BY created_at DESC LIMIT 5\"))
        for row in r.fetchall(): print(row)
asyncio.run(check())
"
```

### Email Not Received

- Check spam/junk folder
- Verify Supabase project has email sending enabled (Authentication → Email Templates)
- Check Supabase logs for delivery errors

---

## Services Involved

| Service | Role |
|---------|------|
| Supabase (external) | User account creation, email verification, JWT issuance |
| Dashboard | Registration form, auth state management, token storage |
| API Service | JWT verification, local user creation (lazy sync), quota setup |
| PostgreSQL | User and quota storage |

---

## Related Documentation

- [Supabase User Creation Pipeline](../pipelines/supabase-user-creation-pipeline.md) - Technical implementation
- [Subscription Workflow](./subscription-workflow.md) - Upgrading from developer tier
- [Domain Management](../standards/domain-management.md) - Supabase URL configuration per environment

---

*Last Updated: February 8, 2026*
