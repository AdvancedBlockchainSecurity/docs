# FIX-BSO-SEC-005: Missing Rate Limiting on Wallet Nonce Endpoints

**Date Fixed:** January 31, 2026
**Severity:** HIGH
**Status:** Fixed
**Audit Area:** AUTH (Authentication)

Follow standards for codebase, kustomize, image, database, ports and versioning docs/standards

---

## Issue Description

The wallet authentication nonce endpoints lacked rate limiting:

```python
# BEFORE (VULNERABLE) - No rate limiting
@router.post("/nonce", response_model=WalletNonceResponse)
async def request_nonce(
    request: WalletNonceRequest,
    db: AsyncSession = Depends(get_db),
):
    # Nonce stored in memory without limit checks
    _nonce_store[wallet_address] = {"nonce": nonce, "expires_at": expires_at}
```

An attacker could:
- Request unlimited nonces for any wallet address
- Exhaust server memory by creating millions of nonce entries
- Perform denial-of-service attacks

## Root Cause

Rate limiting was applied to sensitive endpoints (login, MFA) but overlooked for the nonce generation endpoints, which appeared to be low-risk but actually allow resource exhaustion.

## Fix Applied

### 1. Added Rate Limiter to Ethereum Wallet Nonce

```python
# AFTER (FIXED)
from src.infrastructure.middleware.rate_limit import get_limiter
limiter = get_limiter()

@router.post("/nonce", response_model=WalletNonceResponse)
@limiter.limit("10/minute")  # Rate limit to prevent nonce flooding DoS
async def request_nonce(
    http_request: Request,  # Required for rate limiter
    request: WalletNonceRequest,
    db: AsyncSession = Depends(get_db),
):
    ...
```

### 2. Added Rate Limiter to Solana Wallet Nonce

```python
# AFTER (FIXED)
@router.post("/nonce", response_model=SolanaWalletNonceResponse)
@limiter.limit("10/minute")  # Rate limit to prevent nonce flooding DoS
async def request_solana_nonce(
    http_request: Request,  # Required for rate limiter
    request: SolanaWalletNonceRequest,
    db: AsyncSession = Depends(get_db),
):
    ...
```

## Files Modified

| File | Change |
|------|--------|
| `src/presentation/api/v1/endpoints/wallet_auth.py` | Added rate limiting import and decorator |
| `src/presentation/api/v1/endpoints/solana_wallet_auth.py` | Added rate limiting import and decorator |

## Verification

### Test 1: Rate Limit Enforced

```bash
# Rapidly request nonces
for i in {1..15}; do
  curl -X POST http://localhost:8000/api/v1/auth/wallet/nonce \
    -H "Content-Type: application/json" \
    -d '{"wallet_address": "0x1234567890123456789012345678901234567890"}'
done

# After 10 requests, should receive 429 Too Many Requests
```

### Test 2: Rate Limit Resets

```bash
# Wait 1 minute and try again
sleep 60
curl -X POST http://localhost:8000/api/v1/auth/wallet/nonce \
  -H "Content-Type: application/json" \
  -d '{"wallet_address": "0x1234567890123456789012345678901234567890"}'
# Expected: 200 OK
```

## Rate Limit Configuration

The rate limit is set to 10 requests per minute per IP address. This is sufficient for:
- Normal wallet authentication flows
- Users with multiple wallets
- Page refreshes and retries

But prevents:
- Automated flooding attacks
- Memory exhaustion via nonce spam
- Resource consumption attacks

## Prevention

- All new endpoints should be evaluated for rate limiting
- DoS potential should be considered during code review
- Rate limits documented in API specification
