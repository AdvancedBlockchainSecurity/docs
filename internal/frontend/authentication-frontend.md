# Authentication Frontend

**⚠️ DEPRECATED - November 13, 2025**

**Repository:** blocksecops-frontend (deprecated)
**Version:** 0.1.1 (final)
**Port:** 3002 (no longer active)
**Status:** ⛔ Deprecated and Removed
**Last Updated:** November 13, 2025

## Deprecation Notice

**This standalone authentication frontend has been deprecated and replaced by integrated authentication in the main dashboard.**

**Migration Complete**: All authentication functionality has been moved to **blocksecops-dashboard** (port 3000).

**What Changed**:
- ✅ Port 3000 now handles login, registration, and OAuth
- ✅ Single unified entry point for all users
- ✅ Port 3002 frontend removed from Kubernetes (frontend-local namespace deleted)
- ✅ All documentation updated to reference port 3000 only

**New Authentication Location**:
- Login: `http://127.0.0.1:3000/login`
- Register: `http://127.0.0.1:3000/register`
- Dashboard: `http://127.0.0.1:3000`

**Current Status**: ✅ Production Ready (November 20, 2025)
- Fast page loads (< 1 second)
- Smooth authentication flow
- Session persistence across page refreshes
- Non-blocking initialization

For current authentication documentation, see:
- **[Production Optimization (Nov 20, 2025)](/Users/pwner/Git/ABS/docs/DASHBOARD-AUTH-PRODUCTION-OPTIMIZATION-2025-11-20.md)** - Latest implementation
- **[Authentication Changelog](/Users/pwner/Git/ABS/docs/CHANGELOG-DASHBOARD-AUTH-2025-11-20.md)** - Recent changes
- **[Authentication Documentation Index](/Users/pwner/Git/ABS/docs/AUTHENTICATION-DOCUMENTATION-INDEX.md)** - Complete reference
- [Dashboard Development Guide](/Users/pwner/Git/ABS/docs/standards/dashboard-development.md)
- [Phase 3.1a Backend Complete](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/02-phase-3.1a-freemium-auth/PHASE-3.1A-BACKEND-COMPLETE.md)

---

## Historical Overview (For Reference Only)

The Authentication Frontend was a standalone React + TypeScript application that provided user authentication for the BlockSecOps platform using Supabase Auth. It handled user registration, login, email verification, OAuth flows, and displayed user tier/quota information.

**This application is no longer in use. All functionality has been integrated into blocksecops-dashboard.**

## Architecture

### Purpose & Scope

**What this frontend does:**
- User registration with email verification
- User login (email/password + OAuth providers)
- OAuth callback handling (Google, Microsoft, GitHub)
- Display user's tier and quota information
- Redirect authenticated users to main platform dashboard

**What this frontend does NOT do:**
- Contract scanning and analysis (that's in blocksecops-dashboard)
- Vulnerability display
- Project management
- Analytics and reports

### Technology Stack

- **React 18.2** - UI framework
- **TypeScript 5.3** - Type-safe JavaScript
- **Vite 5.0** - Build tool and dev server
- **Supabase 2.39** - Authentication provider (JWT ES256)
- **React Router 6.20** - Client-side routing
- **Zustand 4.4** - State management
- **Axios 1.6** - HTTP client
- **Tailwind CSS 3.3** - Styling

### Authentication Flow

```
1. User visits http://127.0.0.1:3002/signup or /login
   ↓
2. User enters credentials (or clicks OAuth provider)
   ↓
3. Supabase authenticates user
   ↓
4. Supabase returns JWT token (ES256)
   ↓
5. Frontend stores token in Zustand + localStorage
   ↓
6. Frontend calls API: GET /users/me/enhanced (with JWT)
   ↓
7. API verifies JWT via Supabase JWKS endpoint
   ↓
8. API creates/updates user in local PostgreSQL database
   ↓
9. API returns user data + quota information
   ↓
10. Frontend displays quota briefly
    ↓
11. Frontend redirects to Main Dashboard: http://127.0.0.1:3000
    ↓
12. Main Dashboard uses same JWT token for API calls
```

## Local Testing Setup

### Prerequisites

1. **Running Services:**
   - Minikube cluster running
   - API Service deployed to Kubernetes
   - PostgreSQL database available
   - Port-forwards active (8000, 3002)

2. **Supabase Project:**
   - Free Supabase account (https://app.supabase.com)
   - Project created and provisioned
   - Email provider enabled
   - Project URL and anon key obtained

### Step-by-Step Local Testing

#### 1. Create Supabase Project

```bash
# 1. Go to https://app.supabase.com
# 2. Click "New Project"
# 3. Choose a name (e.g., "blocksecops-local")
# 4. Set a strong database password
# 5. Select a region close to you
# 6. Wait ~2 minutes for provisioning
```

#### 2. Configure Supabase Authentication

In Supabase Dashboard:

1. **Enable Email Provider:**
   - Go to **Authentication** → **Providers**
   - Ensure **Email** is enabled (default)
   - Confirm email confirmation is required

2. **Configure Site URL:**
   - Go to **Authentication** → **URL Configuration**
   - Set **Site URL**: `http://127.0.0.1:3002`
   - Add **Redirect URLs**:
     - `http://127.0.0.1:3002/auth/callback`
     - `http://127.0.0.1:3000` (main dashboard)

3. **Optional: Enable OAuth Providers:**
   - Go to **Authentication** → **Providers**
   - Enable **Google**, **GitHub**, **Microsoft** as needed
   - Follow provider-specific setup (OAuth client ID/secret)

4. **Get API Credentials:**
   - Go to **Settings** → **API**
   - Copy **Project URL** (e.g., `https://xxx.supabase.co`)
   - Copy **anon (public) key**

#### 3. Update Frontend Configuration

```bash
# Update .env.local with Supabase credentials
cat > /Users/pwner/Git/ABS/blocksecops-frontend/.env.local <<'EOF'
# API Service (running in Kubernetes)
VITE_API_BASE_URL=http://127.0.0.1:8000

# Supabase Configuration
VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here
EOF

echo "✅ Frontend configuration updated"
```

#### 4. Update API Service CORS

The API Service must allow requests from the frontend (port 3002):

```bash
# Check current CORS configuration
kubectl get configmap -n api-service-local api-service-config -o yaml | grep CORS

# If 127.0.0.1:3002 is not included, update the configmap
cd /Users/pwner/Git/ABS/blocksecops-api-service
vim k8s/overlays/local/configmap-patch.yaml

# Add to CORS_ORIGINS:
# "http://127.0.0.1:3000,http://127.0.0.1:3002,http://localhost:3000,http://localhost:3002"

# Apply changes
kubectl apply -k k8s/overlays/local/

# Restart API Service to pick up changes
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# Restart API port-forward (pod was replaced)
lsof -ti:8000 | xargs kill -9
sleep 2
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 &

# Verify API is accessible
curl -s http://127.0.0.1:8000/api/v1/health/live
```

#### 5. Start Port-Forwards

```bash
# Kill any existing port-forwards
lsof -ti:8000,3002 | xargs kill -9 2>/dev/null
sleep 2

# Start API Service port-forward
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
echo "✅ API Service: http://127.0.0.1:8000"

# Start Frontend port-forward
kubectl port-forward -n frontend-local svc/frontend 3002:80 > /tmp/pf-frontend.log 2>&1 &
echo "✅ Frontend: http://127.0.0.1:3002"

# Wait for stability
sleep 3

# Verify both are active
lsof -i :8000,3002 | grep LISTEN

# Test health endpoints
curl -s http://127.0.0.1:8000/api/v1/health/live | jq '.status'
curl -s http://127.0.0.1:3002/health
```

#### 6. Test Authentication Flow

**Test Signup:**

```bash
# 1. Open frontend in browser
open http://127.0.0.1:3002/signup

# 2. Fill in the form:
#    Email: your-email@example.com
#    Password: TestPass123 (min 6 characters)

# 3. Click "Sign up"

# 4. Check your email for verification link

# 5. Click verification link in email

# 6. You'll be redirected to Supabase confirmation page

# 7. Navigate back to login
open http://127.0.0.1:3002/login
```

**Test Login:**

```bash
# 1. Open login page
open http://127.0.0.1:3002/login

# 2. Enter verified email and password

# 3. Click "Sign in"

# 4. Observe:
#    - JWT token stored in localStorage
#    - API call to /users/me/enhanced
#    - User created in local database (if first time)
#    - Dashboard displays with quota information

# 5. Check browser console (F12) for any errors

# 6. Verify user in database:
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 2
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security \
  -c "SELECT id, email, tier, created_at FROM users ORDER BY created_at DESC LIMIT 5;"
```

**Test Quota Display:**

```bash
# After login, the dashboard shows:
# - Email address
# - Current tier (free, pro, enterprise, enterprise_broker)
# - Monthly scan usage (e.g., 0/10 scans used)
# - Scans remaining
# - Max files per scan
# - Scan priority
# - Webhooks enabled/disabled
# - API access enabled/disabled

# Verify quota via API
TOKEN=$(cat <<'JS' | node
const localStorage = require('localStorage');
console.log(localStorage.getItem('access_token'));
JS
)

curl -s -H "Authorization: Bearer $TOKEN" \
  http://127.0.0.1:8000/api/v1/users/me/enhanced | jq '.'
```

#### 7. Test Logout

```bash
# 1. In the frontend, click "Sign out"

# 2. Observe:
#    - Token removed from localStorage
#    - Redirect to /login

# 3. Verify cannot access protected routes
open http://127.0.0.1:3002/dashboard
# Should redirect to /login
```

### Expected Behavior

**Successful Authentication:**
- ✅ User can sign up with email
- ✅ Verification email sent by Supabase
- ✅ Email verification link works
- ✅ User can log in after verification
- ✅ JWT token stored in localStorage
- ✅ API call to `/users/me/enhanced` succeeds
- ✅ User created in local database with tier='free'
- ✅ Quota auto-created via database trigger
- ✅ Dashboard displays user email, tier, quota
- ✅ Protected routes require authentication

**Error Cases:**
- ❌ Login with unverified email → Error message
- ❌ Wrong password → Error message from Supabase
- ❌ Invalid email format → Validation error
- ❌ Password too short → Validation error
- ❌ API Service down → Network error displayed
- ❌ CORS misconfigured → CORS error in console
- ❌ Missing Supabase credentials → Auth initialization fails

## Deployment Status

### Kubernetes Deployment

**Namespace:** `frontend-local`
**Deployment:** `frontend`
**Service:** `frontend` (ClusterIP on port 80)
**Image:** `frontend:latest` (currently points to v0.1.1)
**Status:** ✅ Deployed and Running

```bash
# Check deployment status
kubectl get all -n frontend-local

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# pod/frontend-79d9b86f78-xxxxx   1/1     Running   0          5m
#
# NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
# service/frontend   ClusterIP   10.107.53.16   <none>        80/TCP    5h
#
# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/frontend   1/1     1            1           5h

# Check health
kubectl exec -n frontend-local deployment/frontend -- wget -O- http://localhost/
```

### Docker Image

**Current Version:** 0.1.1 (PATCH increment - added Dockerfile build arguments)

**Build Command:**
```bash
cd /Users/pwner/Git/ABS/blocksecops-frontend

# Build with Supabase credentials as build arguments
docker build --no-cache \
  --build-arg VITE_API_BASE_URL=http://127.0.0.1:8000 \
  --build-arg VITE_SUPABASE_URL=https://huzjlpypdlelqnbjvxad.supabase.co \
  --build-arg VITE_SUPABASE_ANON_KEY=<your-anon-key> \
  -t frontend:0.1.1 \
  -f Dockerfile .

# Tag as latest for local development (per standards)
docker tag frontend:0.1.1 frontend:latest

# Load into minikube
minikube image load frontend:latest

# Restart deployment (no kustomization changes needed - uses 'latest')
kubectl rollout restart deployment/frontend -n frontend-local
```

**Image Details:**
- Base: `node:20-alpine` (builder stage)
- Production: `nginx:1.25-alpine`
- Size: ~48.7MB
- Multi-stage build for optimization
- Nginx serves static React build
- Supabase credentials baked in at build time (via ARG/ENV)

## Integration with Main Dashboard

### Redirect After Login

Currently, the frontend has its own `/dashboard` route. This should be modified to redirect to the main platform dashboard:

**Recommended Flow:**
```typescript
// After successful login in authStore.ts
signIn: async (email: string, password: string) => {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) throw error

  if (data.session) {
    const { data: userData } = await apiClient.get<EnhancedUser>('/users/me/enhanced')
    set({ user: userData, session: data.session })

    // Redirect to main platform dashboard
    window.location.href = 'http://127.0.0.1:3000'
  }
}
```

### Main Dashboard Integration

The main dashboard (blocksecops-dashboard) needs to:

1. **Read JWT token from localStorage:**
   ```typescript
   const token = localStorage.getItem('access_token')
   ```

2. **Use token for API calls:**
   ```typescript
   axios.defaults.headers.common['Authorization'] = `Bearer ${token}`
   ```

3. **Fetch and display quota:**
   ```typescript
   const response = await axios.get('http://127.0.0.1:8000/api/v1/users/me/enhanced')
   // Display tier, quota, scan limits, etc.
   ```

4. **Handle token expiration:**
   - Supabase tokens expire after 1 hour (configurable)
   - Implement auto-refresh using Supabase client
   - Redirect to auth frontend if token invalid

## Testing Checklist

### Prerequisites
- [ ] Minikube cluster running
- [ ] API Service deployed and healthy
- [ ] PostgreSQL database accessible
- [ ] Supabase project created
- [ ] Supabase email provider enabled
- [ ] Frontend `.env.local` configured
- [ ] API Service CORS includes port 3002
- [ ] Port-forwards active (8000, 3002)

### Authentication Tests
- [ ] Sign up with new email
- [ ] Receive verification email
- [ ] Click verification link successfully
- [ ] Login with verified credentials
- [ ] JWT token stored in localStorage
- [ ] API call to `/users/me/enhanced` succeeds
- [ ] User created in database with tier='free'
- [ ] Quota auto-created (10 scans, 25 files/scan)
- [ ] Dashboard displays correct tier and quota
- [ ] Logout clears token and redirects to login
- [ ] Cannot access `/dashboard` when logged out
- [ ] Can access `/dashboard` when logged in

### Error Handling Tests
- [ ] Login with wrong password shows error
- [ ] Login with unverified email shows error
- [ ] Password too short shows validation error
- [ ] Invalid email format shows validation error
- [ ] API Service down shows network error
- [ ] CORS error handled gracefully
- [ ] Token expiration triggers re-login

### OAuth Tests (if enabled)
- [ ] Google OAuth login works
- [ ] GitHub OAuth login works
- [ ] Microsoft OAuth login works
- [ ] OAuth callback redirects correctly
- [ ] User created via OAuth has correct data

## Troubleshooting

### Issue: Verification email not received

**Causes:**
- Supabase email rate limit
- Email in spam folder
- Invalid email address

**Solution:**
```bash
# Check Supabase dashboard logs
# Settings → Logs → Auth Logs
# Look for "verification email sent" messages

# Alternative: Use magic link instead
# Enable in Supabase: Authentication → Providers → Email → Magic Link
```

### Issue: CORS error in browser console

**Error:** `Access to XMLHttpRequest at 'http://127.0.0.1:8000' from origin 'http://127.0.0.1:3002' has been blocked by CORS policy`

**Solution:**
```bash
# Update API Service CORS configuration
cd /Users/pwner/Git/ABS/blocksecops-api-service
vim k8s/overlays/local/configmap-patch.yaml

# Ensure CORS_ORIGINS includes:
# "http://127.0.0.1:3000,http://127.0.0.1:3002,http://localhost:3000,http://localhost:3002"

kubectl apply -k k8s/overlays/local/
kubectl rollout restart deployment/api-service -n api-service-local
```

### Issue: "Supabase client initialization failed"

**Cause:** Missing or invalid Supabase credentials

**Solution:**
```bash
# Verify .env.local exists and has correct values
cat /Users/pwner/Git/ABS/blocksecops-frontend/.env.local

# Test Supabase connectivity
curl -s https://YOUR_PROJECT.supabase.co/auth/v1/health
# Should return: {"date":"...","name":"supabase-gotrue"}

# Rebuild Docker image if deployed to Kubernetes
docker build --no-cache -t frontend:0.1.0 .
minikube image load frontend:0.1.0
kubectl rollout restart deployment/frontend -n frontend-local
```

### Issue: User not created in database

**Cause:** API Service can't verify JWT or database connection issue

**Solution:**
```bash
# Check API Service logs
kubectl logs -n api-service-local deployment/api-service --tail=50

# Verify JWT verification is working
# Should see logs like: "User xxx authenticated via Supabase"

# Check database connection
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -d solidity_security -c "\dt"

# Verify Supabase URL is configured in API Service
kubectl get configmap -n api-service-local api-service-config -o yaml | grep SUPABASE
```

## Future Enhancements

### Phase 4.5: Enterprise SSO Integration (High Priority)

**Architecture Decision**: Same frontend will serve both freemium and enterprise users (Snyk-style pattern).

#### SSO Login Pattern

Based on Snyk's implementation (https://app.snyk.io/login), the authentication frontend will be enhanced to support enterprise SSO:

**Current State (Phase 3.1a):**
- Single login page with email/password form
- Supabase authentication only
- Supports freemium users (free, pro tiers)

**Future State (Phase 4.5):**
- Same login page enhanced with SSO option
- "Log in with your company SSO" link added below standard login form
- SSO login modal/form for company domain entry
- Smart email domain detection
- SAML 2.0 / OAuth OIDC integration with enterprise IdPs
- JIT (Just-In-Time) user provisioning

#### User Experience Flow

**Freemium Users (Current Flow - Unchanged):**
```
1. Visit login page → Enter email/password → Sign in → Dashboard
```

**Enterprise Users (Phase 4.5 - New Flow):**
```
1. Visit login page
2. Click "Log in with your company SSO"
3. Enter company domain or email (e.g., "acme.com" or "user@acme.com")
4. Backend checks if domain has SSO configured
5. If configured → Redirect to enterprise IdP (Okta, Azure AD, etc.)
6. User authenticates with IdP
7. SAML assertion returned to backend
8. Backend creates/updates user via JIT provisioning
9. JWT token issued → Redirect to dashboard
```

#### Implementation Requirements

**Frontend Changes (LoginPage.tsx):**
- Add "Log in with your company SSO" link/button
- Create SSO login modal with company domain input field
- API call to check if domain has SSO enabled: `GET /api/v1/sso/check-domain?domain=acme.com`
- Handle SSO redirect URL: `GET /api/v1/sso/initiate?domain=acme.com`
- Handle SSO callback: `/auth/sso/callback`
- Display SSO-specific error messages

**Backend Integration:**
- SSO configuration management (per enterprise organization)
- SAML 2.0 metadata endpoint: `GET /api/v1/sso/metadata`
- SSO initiation endpoint: `GET /api/v1/sso/initiate`
- SAML assertion consumer endpoint: `POST /api/v1/sso/acs`
- OAuth OIDC callback endpoint: `GET /api/v1/sso/oauth/callback`
- JIT user provisioning with tier='enterprise'
- SSO session management

**Database Schema:**
```sql
-- New table for Phase 4.5
CREATE TABLE sso_configurations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  domain VARCHAR(255) NOT NULL UNIQUE,
  provider VARCHAR(50) NOT NULL, -- 'saml', 'oidc'
  idp_entity_id TEXT,
  idp_sso_url TEXT NOT NULL,
  idp_certificate TEXT,
  client_id TEXT,
  client_secret TEXT,
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Smart Domain Detection

**API Endpoint:**
```typescript
GET /api/v1/sso/check-domain?domain=acme.com

Response (SSO Enabled):
{
  "sso_enabled": true,
  "provider": "saml",
  "organization_name": "Acme Corporation"
}

Response (SSO Disabled):
{
  "sso_enabled": false,
  "message": "No SSO configuration found for this domain"
}
```

#### Security Considerations

1. **SAML Signature Verification**: Verify IdP signatures on SAML assertions
2. **Replay Attack Prevention**: Check NotBefore/NotOnOrAfter timestamps
3. **Audience Restriction**: Validate Audience element matches our SP entity ID
4. **TLS Required**: All SSO communication over HTTPS
5. **Token Expiration**: SSO tokens expire after 1 hour (same as Supabase)
6. **Rate Limiting**: Limit SSO initiation requests to prevent abuse

#### Testing Strategy

**Local Testing (Phase 4.5):**
- Use test SAML IdP (e.g., SAML-test.id or local Keycloak)
- Create test organization with SSO configuration
- Test domain detection with multiple domains
- Test JIT user creation
- Test error handling (IdP down, invalid domain, missing SSO config)

**Staging Testing:**
- Integrate with real enterprise IdP (test environment)
- Test full SSO flow end-to-end
- Test multiple organizations with different IdPs
- Performance testing (SSO should complete in <3 seconds)

#### UI/UX Mockup

```
┌─────────────────────────────────────────┐
│     BlockSecOps Dashboard               │
│     Sign in to your account             │
├─────────────────────────────────────────┤
│  Email address                          │
│  [________________________]             │
│                                         │
│  Password                               │
│  [________________________]             │
│                                         │
│  [ Sign in ]                            │
│                                         │
│  ────────── or ──────────               │
│                                         │
│  [ Log in with your company SSO ]       │
│                                         │
│  Don't have an account? Sign up         │
└─────────────────────────────────────────┘
```

**SSO Modal (When "Log in with your company SSO" is clicked):**
```
┌─────────────────────────────────────────┐
│  Enterprise SSO Login                   │
├─────────────────────────────────────────┤
│  Enter your company domain or email:    │
│                                         │
│  [________________________]             │
│  Example: acme.com or user@acme.com     │
│                                         │
│  [ Continue ]  [ Cancel ]               │
└─────────────────────────────────────────┘
```

#### Reference Documentation

- [Phase 4.5 Enterprise SSO Implementation Plan](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/04-phase-4.5-enterprise-features/)
- [Snyk Login Pattern](https://app.snyk.io/login)
- [SAML 2.0 Specification](https://docs.oasis-open.org/security/saml/Post2.0/sstc-saml-tech-overview-2.0.html)
- [OAuth OIDC Specification](https://openid.net/connect/)

---

### Additional Planned Features (Post Phase 4.5)

1. **Password Reset Flow**
   - Add `/forgot-password` and `/reset-password` routes
   - Integrate with Supabase password reset

2. **Account Settings**
   - Email change
   - Password change
   - Profile management

3. **OAuth Provider Management**
   - Link/unlink OAuth providers
   - Show connected providers

4. **Session Management**
   - View active sessions
   - Revoke sessions

5. **Two-Factor Authentication**
   - TOTP support via Supabase
   - SMS verification (if needed)

## References

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [JWT ES256 Specification (RFC 7518)](https://datatracker.ietf.org/doc/html/rfc7518#section-3.4)
- [JWKS Specification (RFC 7517)](https://datatracker.ietf.org/doc/html/rfc7517)
- [Frontend Development Standards](/Users/pwner/Git/ABS/docs/standards/frontend-development.md)
- [Authentication System Architecture](/Users/pwner/Git/ABS/blocksecops-docs/architecture/authentication-system.md)

---

## Version History

### v0.1.1 (November 13, 2025) - Current
**Type:** PATCH (Bug Fix)
**Changes:**
- Added Dockerfile build arguments for Vite environment variables
- Supabase credentials now properly baked into static bundle at build time
- Fixed blank screen issue on initial load

### v0.1.0 (November 13, 2025)
**Type:** MINOR (Initial Release)
**Changes:**
- Initial React + TypeScript + Vite application
- Supabase Auth SDK integration
- Login, signup, dashboard, settings pages
- Protected routes with authentication guard
- Kubernetes deployment manifests
- Docker multi-stage build
- Documentation created

---

**Last Updated:** November 13, 2025
**Current Version:** 0.1.1
**Status:** ✅ Deployed to Kubernetes and Ready for Local Testing
**Next Steps:** Configure Supabase redirect URLs and test authentication flow
**Deployment Guide:** See `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/02-phase-3.1a-freemium-auth/PHASE-3.1A-FRONTEND-COMPLETE.md`
