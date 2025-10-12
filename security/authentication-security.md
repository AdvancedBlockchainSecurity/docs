# Authentication Security Best Practices

## Overview

This document outlines security recommendations for the authentication system in the BlockSecOps Platform. The current implementation uses JWT tokens stored in browser localStorage, which is suitable for development but requires enhancements for production deployment.

## Current Implementation

### Architecture
- **Frontend:** React with AuthContext for state management
- **Backend:** FastAPI with JWT authentication
- **Storage:** Browser localStorage
- **Token Types:** Access token (30 min) + Refresh token (7 days)

### Files
- `blocksecops-dashboard/src/lib/api/auth.ts` - Auth API methods
- `blocksecops-dashboard/src/lib/api/client.ts` - Axios interceptors
- `blocksecops-dashboard/src/contexts/AuthContext.tsx` - React context
- `blocksecops-api-service/src/infrastructure/security/jwt.py` - JWT creation

## Security Recommendations for Production

### 1. HttpOnly Cookies (CRITICAL PRIORITY)

**Current Issue:**
- Tokens stored in localStorage are accessible via JavaScript
- Vulnerable to XSS attacks that can steal tokens
- Any malicious script can read `localStorage.getItem('access_token')`

**Recommended Solution:**
```python
# Backend (FastAPI) - Set HttpOnly cookies
from fastapi import Response

@router.post("/auth/login")
async def login(response: Response, credentials: LoginRequest):
    # Authenticate user and create tokens
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    # Set cookies instead of returning in body
    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,      # Prevents JavaScript access
        secure=True,        # HTTPS only
        samesite="strict",  # CSRF protection
        max_age=1800        # 30 minutes
    )

    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,
        samesite="strict",
        max_age=604800      # 7 days
    )

    return {"message": "Login successful"}
```

```typescript
// Frontend - No localStorage, cookies handled automatically
apiClient.interceptors.request.use((config) => {
  // No need to manually add Authorization header
  // Cookies sent automatically with credentials: 'include'
  return config;
});

// Configure axios to send cookies
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,  // Send cookies with requests
});
```

**Benefits:**
- ✅ XSS protection - JavaScript cannot access tokens
- ✅ Automatic cookie management by browser
- ✅ CSRF protection with SameSite attribute

**Implementation Priority:** CRITICAL

---

### 2. Refresh Token Rotation (HIGH PRIORITY)

**Current Issue:**
- Same refresh token used multiple times
- If stolen, attacker has 7 days of access
- No detection of token theft

**Recommended Solution:**
```python
# Backend - Issue new refresh token on each refresh
@router.post("/auth/refresh")
async def refresh_token(
    current_refresh_token: str,
    db: AsyncSession = Depends(get_db)
):
    # Verify current refresh token
    payload = decode_token(current_refresh_token)

    # Check if token already used (rotation detection)
    session = await db.get(SessionModel, payload["session_id"])
    if session.is_revoked or session.refresh_count > 0:
        # Token reuse detected - possible attack
        await revoke_all_user_sessions(payload["user_id"])
        raise HTTPException(status_code=401, detail="Token reuse detected")

    # Create new tokens
    new_access_token = create_access_token(payload["user_id"])
    new_refresh_token = create_refresh_token(payload["user_id"])

    # Invalidate old refresh token
    session.is_revoked = True
    session.refresh_count += 1
    await db.commit()

    # Create new session
    new_session = SessionModel(
        user_id=payload["user_id"],
        token=new_access_token,
        refresh_token=new_refresh_token
    )
    await db.add(new_session)
    await db.commit()

    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token
    }
```

**Benefits:**
- ✅ Limits impact of stolen refresh token
- ✅ Detects and blocks token reuse attacks
- ✅ Automatic revocation on suspicious activity

**Implementation Priority:** HIGH

---

### 3. Token Encryption (MEDIUM PRIORITY)

**Use Case:** If HttpOnly cookies cannot be implemented immediately

**Recommended Solution:**
```typescript
// Frontend - Encrypt tokens before localStorage
import CryptoJS from 'crypto-js';

const ENCRYPTION_KEY = process.env.VITE_TOKEN_ENCRYPTION_KEY;

export function saveTokens(accessToken: string, refreshToken: string): void {
  const encryptedAccess = CryptoJS.AES.encrypt(
    accessToken,
    ENCRYPTION_KEY
  ).toString();

  const encryptedRefresh = CryptoJS.AES.encrypt(
    refreshToken,
    ENCRYPTION_KEY
  ).toString();

  localStorage.setItem('access_token', encryptedAccess);
  localStorage.setItem('refresh_token', encryptedRefresh);
}

export function getAccessToken(): string | null {
  const encrypted = localStorage.getItem('access_token');
  if (!encrypted) return null;

  const decrypted = CryptoJS.AES.decrypt(
    encrypted,
    ENCRYPTION_KEY
  ).toString(CryptoJS.enc.Utf8);

  return decrypted;
}
```

**Benefits:**
- ✅ Additional security layer if cookies not used
- ✅ Harder for attackers to use stolen tokens
- ⚠️ Still vulnerable to XSS (attacker can call getAccessToken())

**Implementation Priority:** MEDIUM (only if cookies not feasible)

---

### 4. HTTPS Only (CRITICAL PRIORITY)

**Required Configuration:**

**Backend (FastAPI):**
```python
# Enforce HTTPS in production
from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware

if settings.environment == "production":
    app.add_middleware(HTTPSRedirectMiddleware)

# Add HSTS header
from fastapi.middleware.trustedhost import TrustedHostMiddleware

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["api.soliditysecurity.com"]
)

# Add security headers
@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    return response
```

**Kubernetes (Ingress):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-service-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - api.soliditysecurity.com
    secretName: api-tls-cert
```

**Implementation Priority:** CRITICAL

---

### 5. Token Lifetime Configuration

**Current Settings (GOOD):**
```python
# src/infrastructure/config.py
jwt_access_token_expire_minutes: int = 30   # ✅ Acceptable
jwt_refresh_token_expire_days: int = 7      # ✅ Acceptable
```

**Recommendations by Environment:**

**Development:**
- Access: 60 minutes (convenience)
- Refresh: 30 days (convenience)

**Staging:**
- Access: 30 minutes
- Refresh: 7 days

**Production:**
- Access: 15-30 minutes (current: 30 min ✅)
- Refresh: 7-14 days (current: 7 days ✅)

**High-Security Production:**
- Access: 5-15 minutes
- Refresh: 1-3 days
- Require re-authentication for sensitive operations

**Implementation Priority:** LOW (current settings acceptable)

---

### 6. Additional Security Measures

#### Rate Limiting
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/auth/login")
@limiter.limit("5/minute")  # Max 5 login attempts per minute
async def login(request: Request, credentials: LoginRequest):
    # Login logic
    pass
```

#### CAPTCHA Integration
```python
import httpx

async def verify_captcha(token: str) -> bool:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://www.google.com/recaptcha/api/siteverify",
            data={
                "secret": settings.recaptcha_secret,
                "response": token
            }
        )
        return response.json()["success"]

@app.post("/auth/register")
async def register(data: RegisterRequest, captcha_token: str):
    if not await verify_captcha(captcha_token):
        raise HTTPException(400, "Invalid CAPTCHA")
    # Register user
```

#### Session Management
```python
# Track active sessions per user
@app.post("/auth/logout-all")
async def logout_all_sessions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Revoke all user sessions
    await db.execute(
        update(SessionModel)
        .where(SessionModel.user_id == current_user.id)
        .values(is_revoked=True)
    )
    await db.commit()
    return {"message": "All sessions logged out"}
```

---

## Implementation Roadmap

### Phase 1: Critical Security (Before Production)
1. ✅ Enable HTTPS on all environments
2. ✅ Implement HttpOnly cookies
3. ✅ Add security headers (HSTS, CSP, etc.)
4. ⏳ Set up SSL/TLS certificates
5. ⏳ Configure CORS properly

### Phase 2: Enhanced Protection (Production Launch)
1. ⏳ Implement refresh token rotation
2. ⏳ Add rate limiting on auth endpoints
3. ⏳ Set up session management
4. ⏳ Monitor authentication metrics
5. ⏳ Implement forced logout capability

### Phase 3: Advanced Security (Post-Launch)
1. ⏳ Add 2FA/MFA support
2. ⏳ Implement CAPTCHA on login/register
3. ⏳ Add device tracking and suspicious activity alerts
4. ⏳ Implement IP whitelisting for admin users
5. ⏳ Add audit logging for all auth events

### Phase 4: Compliance (Enterprise)
1. ⏳ SOC 2 compliance measures
2. ⏳ GDPR data protection
3. ⏳ PCI DSS if handling payments
4. ⏳ Regular security audits
5. ⏳ Penetration testing

---

## Testing Security

### Manual Testing
```bash
# Test XSS protection (should fail with HttpOnly cookies)
# Open browser console on dashboard
localStorage.getItem('access_token')  # Should be null with cookies

# Test token refresh
curl -X POST http://localhost:8001/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token": "old_token"}'

# Test rate limiting
for i in {1..10}; do
  curl -X POST http://localhost:8001/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"wrong"}'
done
```

### Automated Security Testing
```python
# pytest test_security.py
async def test_token_rotation():
    # Login and get refresh token
    response = await client.post("/auth/login", json={...})
    refresh_token = response.json()["refresh_token"]

    # Use refresh token
    response1 = await client.post("/auth/refresh", json={
        "refresh_token": refresh_token
    })
    new_token = response1.json()["refresh_token"]

    # Try to reuse old token (should fail)
    response2 = await client.post("/auth/refresh", json={
        "refresh_token": refresh_token
    })
    assert response2.status_code == 401
```

---

## References

- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)
- [OWASP Top 10 Web Application Security Risks](https://owasp.org/www-project-top-ten/)
- [FastAPI Security Documentation](https://fastapi.tiangolo.com/tutorial/security/)

---

**Document Status:** Draft for Review
**Last Updated:** October 6, 2025
**Next Review:** Before production deployment
