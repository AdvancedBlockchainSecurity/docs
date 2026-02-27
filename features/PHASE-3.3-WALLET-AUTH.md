# Phase 3.3: MetaMask/WalletConnect Authentication

## Overview

Phase 3.3 introduces wallet-based authentication using the Sign-In with Ethereum (SIWE) standard. This allows users to authenticate using their Ethereum wallets (MetaMask, WalletConnect, Coinbase Wallet) in addition to traditional email/password and OAuth methods.

## Features

### Wallet Authentication
- **SIWE (EIP-4361)**: Industry-standard Sign-In with Ethereum protocol
- **MetaMask Support**: Connect and authenticate with MetaMask browser extension
- **WalletConnect**: Support for mobile wallets via WalletConnect protocol
- **Coinbase Wallet**: Native support for Coinbase Wallet
- **Multi-chain Support**: Ethereum Mainnet, Sepolia, Polygon, Arbitrum, Optimism

### Account Management
- **Wallet-Only Accounts**: Create accounts using only a wallet (no email required)
- **Wallet Linking**: Link wallet to existing email/password accounts
- **Wallet Unlinking**: Remove wallet from account (if email is linked)
- **ENS Support**: Display ENS names when available

## Architecture

### Authentication Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  User connects  │────▶│  Request nonce  │────▶│  Sign message   │
│  wallet         │     │  from server    │     │  in wallet      │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  JWT tokens     │◀────│  Server verifies│◀────│  Submit         │
│  issued         │     │  signature      │     │  signature      │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### SIWE Message Format (EIP-4361)

```
0xapogee.com wants you to sign in with your Ethereum account:
0x1234...5678

Sign in to BlockSecOps Security Platform

URI: https://0xapogee.com
Version: 1
Chain ID: 1
Nonce: abc123...
Issued At: 2025-11-30T18:00:00Z
Expiration Time: 2025-11-30T18:05:00Z
```

## API Endpoints

### Request Nonce
```http
POST /api/v1/auth/wallet/nonce
Content-Type: application/json

{
  "wallet_address": "0x1234567890abcdef1234567890abcdef12345678"
}
```

Response:
```json
{
  "nonce": "a1b2c3d4e5f6...",
  "message": "0xapogee.com wants you to sign in...",
  "expires_at": "2025-11-30T18:05:00Z"
}
```

### Verify Signature
```http
POST /api/v1/auth/wallet/verify
Content-Type: application/json

{
  "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
  "signature": "0xabcdef...",
  "message": "0xapogee.com wants you to sign in..."
}
```

Response:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "uuid",
    "email": null,
    "wallet_address": "0x1234...",
    "ens_name": "user.eth",
    "tier": "free",
    "is_active": true,
    "wallet_linked_at": "2025-11-30T18:00:00Z",
    "created_at": "2025-11-30T18:00:00Z"
  }
}
```

### Link Wallet (Authenticated)
```http
POST /api/v1/auth/wallet/link
Authorization: Bearer <token>
Content-Type: application/json

{
  "wallet_address": "0x1234...",
  "signature": "0xabcdef...",
  "message": "0xapogee.com wants you to sign in..."
}
```

### Unlink Wallet (Authenticated)
```http
POST /api/v1/auth/wallet/unlink
Authorization: Bearer <token>
Content-Type: application/json

{
  "confirm": true
}
```

### Get Wallet Status (Authenticated)
```http
GET /api/v1/auth/wallet/status
Authorization: Bearer <token>
```

### Lookup Wallet (Public)
```http
GET /api/v1/auth/wallet/lookup/0x1234...
```

## Database Schema

### Users Table Updates

```sql
ALTER TABLE users ADD COLUMN wallet_address VARCHAR(42) UNIQUE;
ALTER TABLE users ADD COLUMN wallet_nonce VARCHAR(64);
ALTER TABLE users ADD COLUMN wallet_linked_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN ens_name VARCHAR(255);

CREATE INDEX ix_users_wallet_address ON users(wallet_address);
CREATE INDEX ix_users_ens_name ON users(ens_name);
```

## Frontend Components

### WalletConnectButton
Main component for wallet connection and authentication.

```tsx
import { WalletConnectButton } from '@/components/auth/WalletConnectButton';

// For login page
<WalletConnectButton
  mode="login"
  onSuccess={(tokens) => handleAuthSuccess(tokens)}
  onError={(error) => handleAuthError(error)}
/>

// For settings page (linking)
<WalletConnectButton
  mode="link"
  onSuccess={() => refreshWalletStatus()}
  onError={(error) => showError(error)}
/>
```

### WalletSettings
Settings panel for managing wallet connection.

```tsx
import { WalletSettings } from '@/components/settings/WalletSettings';

// In Settings page
<WalletSettings />
```

## Configuration

### Environment Variables

```bash
# Frontend (.env)
VITE_WALLETCONNECT_PROJECT_ID=your-project-id

# Backend (.env)
# No additional config needed - uses existing JWT settings
```

### Wagmi Configuration

```typescript
// src/lib/web3/config.ts
import { createConfig } from 'wagmi';
import { mainnet, sepolia, polygon, arbitrum, optimism } from 'wagmi/chains';

export const wagmiConfig = createConfig({
  chains: [mainnet, sepolia, polygon, arbitrum, optimism],
  connectors: [
    injected(),
    walletConnect({ projectId }),
    coinbaseWallet({ appName: 'BlockSecOps' }),
  ],
  // ...
});
```

## Security Considerations

1. **Nonce Expiration**: Nonces expire after 5 minutes to prevent replay attacks
2. **Signature Verification**: Uses `eth-account` library for cryptographic verification
3. **Address Normalization**: All addresses are normalized to lowercase
4. **One Wallet Per Account**: Each wallet can only be linked to one account
5. **Wallet-Only Account Protection**: Cannot unlink wallet if it's the only auth method

## Dependencies

### Backend (Python)
```txt
web3>=6.0.0,<7.0.0
eth-account>=0.10.0,<1.0.0
```

### Frontend (npm)
```json
{
  "@web3modal/wagmi": "^5.1.0",
  "wagmi": "^2.0.0",
  "viem": "^2.0.0"
}
```

## Testing

### API Tests
```bash
# Test nonce generation
curl -X POST http://localhost:8000/api/v1/auth/wallet/nonce \
  -H "Content-Type: application/json" \
  -d '{"wallet_address": "0x1234..."}'

# Test wallet lookup
curl http://localhost:8000/api/v1/auth/wallet/lookup/0x1234...
```

### Frontend Testing
1. Install MetaMask browser extension
2. Create/import test wallet
3. Navigate to login page
4. Click "Connect Wallet"
5. Select MetaMask from wallet options
6. Approve connection
7. Sign the SIWE message
8. Verify successful authentication

## Migration Notes

- Run Alembic migration: `alembic upgrade head`
- Frontend dependencies: `npm install`
- No breaking changes to existing auth flows
- Wallet auth is additive to existing email/OAuth methods

## Future Enhancements

- ENS reverse resolution for displaying names
- Support for additional chains (Base, zkSync, etc.)
- Hardware wallet support (Ledger, Trezor)
- Multi-signature wallet support
- On-chain contract ownership verification
