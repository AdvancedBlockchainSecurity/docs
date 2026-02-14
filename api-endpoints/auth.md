# Authentication

**Base URL:** `/api/v1/auth`
**Auth:** Bearer JWT required (except OAuth callbacks)

## Overview

Authentication is handled by Supabase. The API service validates JWTs using both RS256 (JWKS) and HS256 (secret key fallback). Additional auth endpoints support wallet linking (Ethereum and Solana) and OAuth provider callbacks.

## Ethereum Wallet Auth

### Get Wallet Status

```
GET /api/v1/auth/wallet/status
```

**Response (200):**
```json
{
  "has_wallet": false,
  "wallet_address": null,
  "ens_name": null,
  "wallet_linked_at": null
}
```

### Request Nonce

```
POST /api/v1/auth/wallet/nonce
```

### Verify Wallet Signature

```
POST /api/v1/auth/wallet/verify
```

### Link Wallet

```
POST /api/v1/auth/wallet/link
```

### Unlink Wallet

```
POST /api/v1/auth/wallet/unlink
```

### Lookup by Address

```
GET /api/v1/auth/wallet/lookup/{wallet_address}
```

## Solana Wallet Auth

### Get Solana Status

```
GET /api/v1/auth/wallet/solana/status
```

**Response (200):**
```json
{
  "has_solana_wallet": false,
  "solana_wallet_address": null,
  "linked_at": null
}
```

### Request Nonce

```
POST /api/v1/auth/wallet/solana/nonce
```

### Verify Signature

```
POST /api/v1/auth/wallet/solana/verify
```

### Link Wallet

```
POST /api/v1/auth/wallet/solana/link
```

### Unlink Wallet

```
POST /api/v1/auth/wallet/solana/unlink
```

### Lookup by Address

```
GET /api/v1/auth/wallet/solana/lookup/{address}
```

## OAuth Callbacks

These endpoints handle OAuth provider redirects:

```
GET /api/v1/oauth/github/callback
GET /api/v1/oauth/gitlab/callback
GET /api/v1/oauth/bitbucket/callback
GET /api/v1/oauth/jenkins/callback
GET /api/v1/oauth/jira/callback
```

## Consent

### Get Current Consent

```
GET /api/v1/consent/current
```

**Response (200):**
```json
{
  "has_consent": false,
  "latest_consent": null,
  "is_current": false,
  "current_tos_version": "2026.01.1",
  "current_privacy_policy_version": "2026.01.1",
  "needs_reconsent": true
}
```

### Accept Terms of Service

```
POST /api/v1/consent/tos
```

### Get Version History

```
GET /api/v1/consent/versions
```

**Response (200):**
```json
{
  "tos_version": "2026.01.1",
  "privacy_policy_version": "2026.01.1",
  "tos_url": "/legal/terms",
  "privacy_policy_url": "/legal/privacy"
}
```

### Withdraw ML Consent

```
POST /api/v1/consent/withdraw-ml
```

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /wallet/status | 200 | No wallet linked |
| GET /wallet/solana/status | 200 | No Solana wallet linked |
| GET /consent/current | 200 | Needs reconsent |
| GET /consent/versions | 200 | TOS v2026.01.1 |
