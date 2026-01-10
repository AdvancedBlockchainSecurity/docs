# Wallet Authentication Tests (Phase 3.3 + 3.1b)

**Priority**: P1 - High
**Last Tested**: _Not yet tested_
**Feature**: Ethereum (MetaMask/WalletConnect) and Solana (Phantom/Solflare) Authentication
**Session Management**: Supabase Admin API (unified sessions)

---

## 1. Backend API Tests

### 1.1 Nonce Generation
- [ ] `POST /api/v1/auth/wallet/nonce` returns nonce for valid address
- [ ] Nonce is unique per request
- [ ] Nonce expires after 5 minutes
- [ ] Invalid address format returns 400 error
- [ ] SIWE message format is correct (EIP-4361)

### 1.2 Signature Verification
- [ ] `POST /api/v1/auth/wallet/verify` with valid signature returns Supabase session
- [ ] Invalid signature returns 401 error
- [ ] Expired nonce returns 401 error
- [ ] Wrong message returns 401 error
- [ ] Response includes access_token, refresh_token, expires_in
- [ ] Token is valid Supabase JWT (can be used with protected endpoints)

### 1.3 Wallet Linking
- [ ] `POST /api/v1/auth/wallet/link` links wallet to existing account
- [ ] Cannot link wallet already linked to another account
- [ ] Requires valid JWT authentication
- [ ] Wallet address stored correctly in database

### 1.4 Wallet Unlinking
- [ ] `POST /api/v1/auth/wallet/unlink` removes wallet from account
- [ ] Cannot unlink if wallet is only auth method
- [ ] Requires valid JWT authentication
- [ ] Wallet fields cleared in database

### 1.5 Wallet Status
- [ ] `GET /api/v1/auth/wallet/status` returns current wallet info
- [ ] Returns has_wallet: false when no wallet linked
- [ ] Returns wallet_address when wallet linked
- [ ] Returns ens_name when available

### 1.6 Wallet Lookup
- [ ] `GET /api/v1/auth/wallet/lookup/{address}` returns if wallet registered
- [ ] Returns exists: true for registered wallets
- [ ] Returns exists: false for unregistered wallets
- [ ] Works without authentication (public endpoint)

---

## 2. Frontend - Wallet Connection

### 2.1 MetaMask Connection
- [ ] "Connect Wallet" button visible on login page
- [ ] Clicking button opens MetaMask popup
- [ ] User can approve connection
- [ ] User can reject connection (handled gracefully)
- [ ] Connected address displayed correctly

### 2.2 WalletConnect Connection
- [ ] WalletConnect option available in wallet modal
- [ ] QR code displays correctly
- [ ] Mobile wallet can scan QR code
- [ ] Connection established successfully
- [ ] Works with Trust Wallet, Rainbow, etc.

### 2.3 Coinbase Wallet Connection
- [ ] Coinbase Wallet option available
- [ ] Connection flow works correctly
- [ ] Handles both browser extension and mobile

### 2.4 Network Handling
- [ ] Correct networks supported (mainnet, sepolia, polygon, arbitrum, optimism)
- [ ] Network name displayed after connection
- [ ] Network switching handled correctly
- [ ] Unsupported network shows warning

---

## 3. Frontend - Sign-In Flow

### 3.1 Signature Request
- [ ] After connection, signature request sent to wallet
- [ ] SIWE message displayed correctly in wallet
- [ ] Domain matches current site
- [ ] Nonce included in message
- [ ] Expiration time reasonable (5 minutes)

### 3.2 Successful Sign-In
- [ ] Approved signature triggers verification
- [ ] Supabase session set via `supabase.auth.setSession()`
- [ ] Session stored in localStorage as `sb-*-auth-token`
- [ ] User redirected to dashboard
- [ ] User info displayed (address or ENS)
- [ ] Protected API calls work with Supabase session

### 3.3 Failed Sign-In
- [ ] Rejected signature shows error message
- [ ] User can retry sign-in
- [ ] Timeout handled gracefully
- [ ] Invalid signature from backend handled

---

## 4. Frontend - Wallet Settings

### 4.1 Settings Page Display
- [ ] Wallet settings section visible in Settings page
- [ ] Shows "No wallet linked" when not linked
- [ ] Shows wallet address when linked
- [ ] Shows ENS name when available
- [ ] Shows linked date

### 4.2 Linking Wallet
- [ ] "Connect Wallet" button visible when not linked
- [ ] Connection flow same as login
- [ ] Signature request for linking
- [ ] Success message on link
- [ ] Page updates to show linked wallet

### 4.3 Unlinking Wallet
- [ ] "Unlink Wallet" button visible when linked
- [ ] Confirmation dialog before unlinking
- [ ] Cannot unlink if only auth method (error shown)
- [ ] Success message on unlink
- [ ] Page updates to show no wallet

---

## 5. Wallet-Only Accounts

- [ ] Can create account using only wallet (no email)
- [ ] Wallet-only account can access all features
- [ ] Wallet-only account cannot unlink wallet
- [ ] Wallet-only account can later add email

---

## 6. ENS Support

- [ ] ENS name resolved for wallet addresses
- [ ] ENS name displayed instead of address where appropriate
- [ ] ENS avatar displayed if available (future)
- [ ] Reverse resolution works correctly

---

## 7. Database & Migration

- [ ] Migration `012_add_wallet_authentication` runs successfully
- [ ] `wallet_address` column added to users table
- [ ] `wallet_nonce` column added
- [ ] `wallet_linked_at` column added
- [ ] `ens_name` column added
- [ ] Unique constraint on wallet_address works
- [ ] Index on wallet_address created

---

## 8. Error Handling

- [ ] No wallet installed shows install prompt
- [ ] User closes wallet popup handled
- [ ] Network error during verification handled
- [ ] Backend error during verification shown
- [ ] Session expired during flow handled

---

---

## 9. Solana Wallet - Backend API Tests

### 9.1 Solana Nonce Generation
- [ ] `POST /api/v1/auth/wallet/solana/nonce` returns nonce for valid Solana address
- [ ] Nonce is unique per request
- [ ] Nonce expires after 5 minutes
- [ ] Invalid address format (non-base58) returns 400 error
- [ ] Invalid address length (not 32-44 chars) returns 400 error

### 9.2 Solana Signature Verification
- [ ] `POST /api/v1/auth/wallet/solana/verify` with valid signature returns Supabase session
- [ ] Uses nacl/Ed25519 for signature verification
- [ ] Invalid signature returns 401 error
- [ ] Expired nonce returns 401 error
- [ ] Wrong message returns 401 error
- [ ] Response includes access_token, refresh_token, expires_in
- [ ] Token is valid Supabase JWT (can be used with protected endpoints)

---

## 10. Solana Wallet - Frontend Connection

### 10.1 Phantom Wallet Connection
- [ ] "Connect Solana" button visible on login page
- [ ] Clicking button opens Phantom wallet popup
- [ ] User can approve connection
- [ ] User can reject connection (handled gracefully)
- [ ] Connected address displayed correctly

### 10.2 Solflare Wallet Connection
- [ ] Solflare option available in wallet modal
- [ ] Connection flow works correctly
- [ ] Handles both browser extension and mobile

### 10.3 Backpack Wallet Connection
- [ ] Backpack wallet option available
- [ ] Connection flow works correctly

### 10.4 Ledger (via Solana Adapter)
- [ ] Ledger option available
- [ ] Hardware wallet connection works

---

## 11. Solana Wallet - Sign-In Flow

### 11.1 Solana Signature Request
- [ ] After connection, signature request sent to wallet
- [ ] Message displayed correctly in wallet
- [ ] Nonce included in message
- [ ] Wallet address included in message

### 11.2 Successful Solana Sign-In
- [ ] Approved signature triggers verification
- [ ] Supabase session set via `supabase.auth.setSession()`
- [ ] Session stored in localStorage as `sb-*-auth-token`
- [ ] User redirected to dashboard
- [ ] User info displayed (Solana address)
- [ ] Protected API calls work with Supabase session

### 11.3 Failed Solana Sign-In
- [ ] Rejected signature shows error message
- [ ] User can retry sign-in
- [ ] Timeout handled gracefully
- [ ] Invalid signature from backend handled

---

## 12. Solana Database & Migration

- [ ] Migration for Solana wallet fields runs successfully
- [ ] `solana_wallet_address` column added to users table
- [ ] `solana_wallet_nonce` column added
- [ ] `solana_wallet_linked_at` column added
- [ ] Unique constraint on solana_wallet_address works
- [ ] Index on solana_wallet_address created

---

## Test Notes

_Record wallet authentication test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
