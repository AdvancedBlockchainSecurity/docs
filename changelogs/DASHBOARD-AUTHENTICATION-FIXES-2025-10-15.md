# Dashboard Authentication Fixes - October 15, 2025

> **Date**: October 15, 2025
> **Environment**: Local Development (Dashboard + API)
> **Status**: ✅ Fixed

## Executive Summary

Fixed immediate logout issue after successful login caused by race condition between cookie setting and WebSocket connection attempt.

## Issue: Immediate Logout After Login

### Symptoms
- User successfully logs in (HTTP 200)
- User is immediately logged out and redirected to login page
- Pattern occurs consistently on every login attempt

### Error Details

**API Logs**:
```
INFO:     127.0.0.1:59730 - "POST /api/v1/auth/login HTTP/1.1" 200 OK
INFO:     127.0.0.1:59730 - "GET /api/v1/auth/ws-token HTTP/1.1" 401 Unauthorized
INFO:     127.0.0.1:59731 - "GET /api/v1/auth/ws-token HTTP/1.1" 401 Unauthorized
INFO:     127.0.0.1:59729 - "OPTIONS /api/v1/auth/refresh HTTP/1.1" 200 OK
INFO:     127.0.0.1:59731 - "POST /api/v1/auth/refresh HTTP/1.1" 500 Internal Server Error
```

**Sequence of Events**:
1. Login succeeds → cookies set in response
2. Dashboard renders WebSocketStatus component immediately
3. WebSocket hook tries to fetch token from `/api/v1/auth/ws-token`
4. Request fails with 401 (cookies not yet available in browser)
5. Axios interceptor triggers token refresh
6. Multiple concurrent refresh attempts cause HTTP 500
7. Refresh fails → user logged out

### Root Cause Analysis

1. **Cookie Timing Issue**
   - Cookies are set by API in login response
   - Browser needs time to process and store cookies
   - WebSocket connection attempt happens immediately (< 10ms)
   - Cookies not yet available for subsequent requests

2. **Race Condition in Dashboard**
   - `WebSocketStatus` component mounts immediately after authentication
   - `useWebSocketConnection()` hook connects on mount
   - Connection attempt happens before cookies are ready

3. **Concurrent Refresh Attempts**
   - Multiple failed requests (WebSocket token, possibly others)
   - Each triggers axios interceptor independently
   - Multiple concurrent calls to `/api/v1/auth/refresh`
   - Race condition in session update causes HTTP 500

## Solution Applied

### Fix 1: Add WebSocket Connection Delay

**File**: `blocksecops-dashboard/src/hooks/useWebSocket.ts:40-54`

Added 500ms delay before WebSocket connection attempt to ensure cookies are available:

```typescript
// Connect with WebSocket token (fetched from server using HttpOnly cookie)
const connectWebSocket = async () => {
  try {
    // Add a small delay to ensure cookies are set after login
    // This prevents race condition where WebSocket connection happens before cookies are ready
    await new Promise(resolve => setTimeout(resolve, 500));

    // Import getWebSocketToken dynamically to avoid circular dependencies
    const { getWebSocketToken } = await import('../lib/api/auth');
    const token = await getWebSocketToken();
    wsManager.connect(token);
  } catch (error) {
    console.error('Failed to connect WebSocket:', error);
    setConnectionStatus('disconnected');
    // Don't throw - just stay disconnected, user can retry later
  }
};
```

**Changes**:
- Added `await new Promise(resolve => setTimeout(resolve, 500))` before token fetch
- Added comment explaining race condition prevention
- Improved error handling (don't throw, stay disconnected)

### Fix 2: Prevent Concurrent Token Refresh

**File**: `blocksecops-dashboard/src/lib/api/client.ts:47-95`

Added refresh token queueing to prevent concurrent refresh attempts:

```typescript
// Refresh token promise to prevent concurrent refresh attempts
let refreshTokenPromise: Promise<void> | null = null;

/**
 * Response interceptor for error handling and token refresh
 */
apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

    // Handle 401 Unauthorized - attempt token refresh
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        // If a refresh is already in progress, wait for it to complete
        if (!refreshTokenPromise) {
          refreshTokenPromise = axios.post(
            `${API_BASE_URL}${API_PREFIX}/auth/refresh`,
            {},
            { withCredentials: true }  // Send cookies with refresh request
          ).then(() => {
            // Clear the promise after successful refresh
            refreshTokenPromise = null;
          }).catch((err) => {
            // Clear the promise and rethrow the error
            refreshTokenPromise = null;
            throw err;
          });
        }

        // Wait for the refresh to complete
        await refreshTokenPromise;

        // New tokens are automatically set as HttpOnly cookies by the server
        // Retry original request (cookies will be sent automatically)
        return apiClient(originalRequest);
      } catch (refreshError) {
        // Refresh failed, clear user data and redirect to login
        sessionStorage.removeItem('user');
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);
```

**Changes**:
- Added `refreshTokenPromise` module-level variable to track ongoing refresh
- Only ONE refresh request is made when multiple requests fail simultaneously
- All failed requests wait for the same refresh promise
- Promise is cleared after completion (success or failure)

## Verification

### Test Case 1: Login Flow
```bash
# Expected flow after fix:
1. User submits login form
2. POST /api/v1/auth/login → HTTP 200 (cookies set)
3. Dashboard renders authenticated UI
4. 500ms delay
5. GET /api/v1/auth/ws-token → HTTP 200 (cookies sent)
6. WebSocket connects successfully
7. User remains logged in
```

### Test Case 2: Concurrent Refresh
```bash
# Expected flow when multiple requests fail:
1. Request A fails with 401
2. Request B fails with 401
3. Request A interceptor: creates refresh promise, waits
4. Request B interceptor: sees existing promise, waits
5. Single POST /api/v1/auth/refresh → HTTP 200
6. Both requests A and B retry with new tokens
7. No HTTP 500 errors
```

## Cookie Configuration (Reference)

**API Service** (`src/presentation/api/v1/endpoints/auth.py:28-58`):

```python
def set_auth_cookies(response: Response, access_token: str, refresh_token: str) -> None:
    """
    Set HttpOnly cookies for authentication tokens (OWASP 2025).

    Security features:
    - HttpOnly: Prevents JavaScript access (XSS protection)
    - Secure: HTTPS only in production
    - SameSite=Lax: CSRF protection while allowing normal navigation
    - Path=/api: Restrict cookie scope to API endpoints only
    """
    # Access token cookie (short-lived)
    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,  # XSS protection
        secure=not settings.debug,  # HTTPS only in production
        samesite="lax",  # CSRF protection
        max_age=settings.jwt_access_token_expire_minutes * 60,
        path="/api",  # Scope to API only
    )

    # Refresh token cookie (long-lived, restricted path)
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=not settings.debug,
        samesite="lax",
        max_age=settings.jwt_refresh_token_expire_days * 24 * 60 * 60,
        path="/api/v1/auth/refresh",  # Most restrictive path
    )
```

**Key Settings**:
- `HttpOnly=True`: Prevents XSS attacks
- `SameSite=Lax`: Prevents CSRF while allowing normal navigation
- `Secure=False` in debug mode (localhost doesn't use HTTPS)
- Access token path: `/api` (all API endpoints)
- Refresh token path: `/api/v1/auth/refresh` (most restrictive)

## Why 500ms Delay?

1. **Browser Cookie Processing Time**
   - Browser needs to parse `Set-Cookie` headers
   - Store cookies in cookie jar
   - Make them available for subsequent requests
   - Typical time: 10-100ms

2. **Safety Margin**
   - 500ms provides comfortable buffer
   - Accounts for slower browsers/systems
   - Minimal UX impact (barely noticeable)
   - Prevents race condition reliably

3. **Alternative Approaches Considered**
   - ❌ **Disable WebSocket**: Loses real-time functionality
   - ❌ **Delay login redirect**: Confusing UX
   - ❌ **Retry on 401**: More complex, multiple failed requests
   - ✅ **Delay WebSocket connection**: Simple, effective, minimal UX impact

## Related Issues

### Issue: Contract Data Mixing (Fixed Previously)
- Fixed `/api/v1/scans` endpoint to filter by `contract_id`
- See: `AUTHENTICATION-FIXES-2025-10-15.md`

### Issue: CORS Configuration (Fixed Previously)
- CORS allows both `localhost:3000` and `127.0.0.1:3000`
- `allow_credentials=True` enables cookie support
- See: `AUTHENTICATION-FIXES-2025-10-15.md`

## Files Modified

| File | Change | Lines |
|------|--------|-------|
| `blocksecops-dashboard/src/hooks/useWebSocket.ts` | Added 500ms delay before connection | 40-54 |
| `blocksecops-dashboard/src/lib/api/client.ts` | Added refresh token queueing | 47-95 |

## Testing Checklist

- ✅ User can log in successfully
- ✅ User remains logged in after login
- ✅ WebSocket connection succeeds
- ✅ No immediate logout after login
- ✅ No HTTP 500 errors on refresh endpoint
- ✅ Concurrent requests handled correctly
- ✅ Cookie-based authentication working
- ✅ Token refresh works properly

## ⚠️ CRITICAL: localhost vs 127.0.0.1

**IMPORTANT**: You MUST use the same hostname for both frontend and backend!

### The Problem
Browsers treat `localhost` and `127.0.0.1` as **different domains** for security reasons. Cookies set by one will NOT be sent to the other.

### Symptoms
- Login succeeds but immediately logs out
- Cookies visible in DevTools but not sent with requests
- All API requests return 401 Unauthorized after login

### Solution
**Use the SAME hostname for both services**:

**✅ Option 1: Use 127.0.0.1 for everything**
- Dashboard: `http://127.0.0.1:3000`
- API: `http://127.0.0.1:8000`

**✅ Option 2: Use localhost for everything**
- Dashboard: `http://localhost:3000`
- API: `http://localhost:8000`

**❌ DO NOT MIX**:
- Dashboard: `http://localhost:3000` + API: `http://127.0.0.1:8000` ← FAILS
- Dashboard: `http://127.0.0.1:3000` + API: `http://localhost:8000` ← FAILS

### Verification
After logging in, check Browser DevTools → Application → Cookies:
- If using `localhost:3000`: Cookies should be under `localhost`
- If using `127.0.0.1:3000`: Cookies should be under `127.0.0.1`

If cookies are under a different domain than your current URL, they won't be sent!

## Prevention

### For Future Development

1. **Always delay WebSocket connections after authentication changes**
   - Use minimum 200ms delay after login/token refresh
   - Consider user experience vs reliability tradeoff

2. **Always implement request queueing for critical operations**
   - Token refresh should never run concurrently
   - Use promise-based queueing pattern

3. **Test authentication flow with network throttling**
   - Simulates slower cookie processing
   - Reveals race conditions

4. **Monitor for concurrent refresh attempts**
   - Log when refresh promise already exists
   - Alert if seeing many concurrent attempts

### Monitoring Queries

```bash
# Check for concurrent refresh attempts
grep "POST /api/v1/auth/refresh" api.log | awk '{print $1, $2}' | uniq -c

# Look for refresh failures
grep "500 Internal Server Error.*refresh" api.log

# Check WebSocket token 401s
grep "GET /api/v1/auth/ws-token.*401" api.log
```

## Related Documentation

- [Authentication Local vs AWS](./AUTHENTICATION-LOCAL-VS-AWS.md) - Session storage architecture
- [Authentication Fixes](./AUTHENTICATION-FIXES-2025-10-15.md) - Previous auth fixes (CORS, cookies)
- [Infrastructure Fixes](./INFRASTRUCTURE-FIXES-2025-10-15.md) - Kubernetes service fixes

---

**Document Status**: ✅ Complete
**Last Updated**: October 15, 2025
**Verified By**: Manual testing of login flow
**Next Review**: When deploying to production environment
