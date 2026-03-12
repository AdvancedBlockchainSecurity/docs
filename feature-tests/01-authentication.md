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

### 3.1 New User Registration (Email)
- [ ] Registration form accessible
- [ ] Email field validates format
- [ ] Password requirements displayed
- [ ] Password confirmation matches
- [ ] Successful registration creates account

### 3.2 Registration via OAuth Signup
- [ ] "Sign up with Google" button visible on Register page
- [ ] Google OAuth signup redirects to Google consent screen
- [ ] Successful Google OAuth signup creates account and redirects to dashboard
- [ ] "Sign up with GitHub" button visible on Register page
- [ ] GitHub OAuth signup redirects to GitHub consent screen
- [ ] Successful GitHub OAuth signup creates account and redirects to dashboard

### 3.3 Registration via Wallet Signup
- [ ] "Sign up with Ethereum" option visible on Register page
- [ ] Ethereum wallet signup triggers wallet connection prompt (MetaMask/WalletConnect)
- [ ] Successful Ethereum wallet signup creates account linked to wallet address
- [ ] User redirected to dashboard after Ethereum wallet signup
- [ ] "Sign up with Solana" option visible on Register page
- [ ] Solana wallet signup triggers wallet connection prompt (Phantom/Solflare)
- [ ] Successful Solana wallet signup creates account linked to wallet address
- [ ] User redirected to dashboard after Solana wallet signup

### 3.4 Registration Validation
- [ ] Duplicate email rejected
- [ ] Weak password rejected
- [ ] Empty fields show validation errors
- [ ] Email confirmation sent (if enabled)

### 3.5 New User Defaults
- [ ] New user assigned to developer tier
- [ ] New user quota initialized correctly (3 scans/month, 2 team members)
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
- [ ] "Sign in with Google" button visible on Login page
- [ ] Clicking redirects to Google OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with Google provider

### 6.2 GitHub OAuth
- [ ] "Sign in with GitHub" button visible on Login page
- [ ] Clicking redirects to GitHub OAuth consent
- [ ] Successful auth redirects back to dashboard
- [ ] User created in database with GitHub provider

### 6.3 Removed Providers — Verify Absence
- [ ] Azure/Microsoft OAuth button is NOT present on Login page
- [ ] Discord OAuth button is NOT present on Login page
- [ ] Slack OAuth button is NOT present on Login page
- [ ] BitBucket OAuth button is NOT present on Login page
- [ ] X (Twitter) OAuth button is NOT present on Login page
- [ ] Only Google and GitHub OAuth buttons are shown on Login page
- [ ] No remnant OAuth callback routes exist for removed providers (Azure, Discord, Slack, BitBucket, Twitter)

---

## 7. Wallet Authentication

### 7.1 Ethereum Wallet Login
- [ ] "Sign in with Ethereum" option visible on Login page
- [ ] Wallet connection prompt appears (MetaMask/WalletConnect)
- [ ] Successful wallet auth redirects to dashboard
- [ ] User session linked to wallet address

### 7.2 Solana Wallet Login
- [ ] "Sign in with Solana" option visible on Login page
- [ ] Wallet connection prompt appears (Phantom/Solflare)
- [ ] Successful wallet auth redirects to dashboard
- [ ] User session linked to wallet address

---

## Test Notes

_Record authentication test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
