# Authentication Tests

**Priority**: P0 - Critical
**Last Tested**: _Not yet tested_

---

## 1. Login

### 1.1 Valid Login
- [ ] User can log in with valid email/password
- [ ] JWT token returned in response
- [ ] User redirected to dashboard after login
- [ ] User info displayed correctly after login

### 1.2 Invalid Login
- [ ] Invalid email shows appropriate error
- [ ] Invalid password shows appropriate error
- [ ] Account not found shows appropriate error
- [ ] Rate limiting after multiple failed attempts

### 1.3 Session Management
- [ ] Session persists across page refresh
- [ ] Session persists across browser tabs
- [ ] JWT token stored correctly (httpOnly cookie or localStorage)
- [ ] Token refresh works before expiration

---

## 2. Logout

- [ ] Logout button visible when logged in
- [ ] Logout clears session/token
- [ ] User redirected to login page after logout
- [ ] Protected pages inaccessible after logout

---

## 3. Registration

### 3.1 New User Registration
- [ ] Registration form accessible
- [ ] Email field validates format
- [ ] Password requirements displayed
- [ ] Password confirmation matches
- [ ] Successful registration creates account

### 3.2 Registration Validation
- [ ] Duplicate email rejected
- [ ] Weak password rejected
- [ ] Empty fields show validation errors
- [ ] Email confirmation sent (if enabled)

### 3.3 New User Defaults
- [ ] New user assigned to Free tier
- [ ] New user quota initialized correctly
- [ ] New user can access dashboard

---

## 4. Password Reset

- [ ] Forgot password link visible
- [ ] Reset email sent to valid email
- [ ] Reset link works correctly
- [ ] New password can be set
- [ ] Old password no longer works after reset

---

## 5. Protected Routes

- [ ] Dashboard requires authentication
- [ ] Upload endpoint requires authentication
- [ ] Scan endpoint requires authentication
- [ ] Projects endpoint requires authentication
- [ ] Unauthenticated requests return 401

---

## 6. OAuth Provider Login

### 6.1 Google OAuth
- [ ] "Sign in with Google" button visible
- [ ] Clicking redirects to Google OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with Google provider

### 6.2 GitHub OAuth
- [ ] "Sign in with GitHub" button visible
- [ ] Clicking redirects to GitHub OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with GitHub provider

### 6.3 Microsoft/Azure OAuth
- [ ] "Sign in with Microsoft" button visible
- [ ] Clicking redirects to Microsoft OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with Azure provider

### 6.4 Discord OAuth
- [ ] "Sign in with Discord" button visible
- [ ] Clicking redirects to Discord OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with Discord provider

### 6.5 Slack OAuth
- [ ] "Sign in with Slack" button visible
- [ ] Clicking redirects to Slack OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with Slack provider

### 6.6 BitBucket OAuth
- [ ] "Sign in with BitBucket" button visible
- [ ] Clicking redirects to BitBucket OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with BitBucket provider

### 6.7 X (Twitter) OAuth
- [ ] "Sign in with X" button visible
- [ ] Clicking redirects to Twitter OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with Twitter provider

---

## Test Notes

_Record authentication test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
