# FIX-BSO-SEC-006: In-Memory Nonce Storage Without Redis

**Date Fixed:** January 31, 2026
**Severity:** HIGH
**Status:** Fixed
**Also Fixes:** BSO-SEC-008 (Nonce TOCTOU Race Condition)

---

## Issue Description

Wallet authentication nonces were stored in Python dictionaries (`_nonce_store` and `_solana_nonce_store`) rather than Redis. In multi-process deployments, nonces stored in one process are invisible to others, allowing authentication bypass across instances.

## Root Cause

In-memory storage was used as a quick implementation for development but was never migrated to Redis for production use.

## Fix Applied

### 1. Created Redis-Based Nonce Storage Module

New file: `src/infrastructure/auth/nonce_storage.py`

```python
class RedisNonceStorage:
    """Redis-backed nonce storage for wallet authentication

    Uses Redis SETEX for atomic store-with-expiration and GETDEL for
    atomic check-and-delete to prevent TOCTOU race conditions.
    """

    async def store_nonce(self, wallet_address: str, nonce: str) -> None:
        """Store nonce with automatic expiration using SETEX"""

    async def get_and_delete_nonce(self, wallet_address: str) -> Optional[str]:
        """Atomically get and delete nonce using GETDEL"""
```

### 2. Updated Ethereum Wallet Auth

`src/presentation/api/v1/endpoints/wallet_auth.py`:
- Removed in-memory `_nonce_store` dictionary
- Imported Redis nonce storage
- Updated all nonce operations to use Redis

### 3. Updated Solana Wallet Auth

`src/presentation/api/v1/endpoints/solana_wallet_auth.py`:
- Removed in-memory `_solana_nonce_store` dictionary
- Imported Redis nonce storage with Solana-specific prefix
- Updated all nonce operations to use Redis

## Security Benefits

1. **Multi-process safety**: Works correctly in distributed/replicated deployments
2. **Persistence**: Nonces survive pod restarts
3. **Atomic operations**: Redis GETDEL prevents TOCTOU race conditions (BSO-SEC-008)
4. **TTL-based expiration**: Automatic cleanup of expired nonces
5. **Fallback for local dev**: In-memory fallback with warning when Redis unavailable

## Files Modified

| File | Change |
|------|--------|
| `src/infrastructure/auth/nonce_storage.py` | NEW: Redis-based nonce storage |
| `src/presentation/api/v1/endpoints/wallet_auth.py` | Use Redis nonce storage |
| `src/presentation/api/v1/endpoints/solana_wallet_auth.py` | Use Redis nonce storage |

## Verification

```bash
# Test nonce flow with Redis
# 1. Request nonce (stored in Redis with TTL)
curl -X POST http://localhost:8000/api/v1/auth/wallet/nonce \
  -H "Content-Type: application/json" \
  -d '{"wallet_address": "0x..."}'

# 2. Verify Redis key exists
redis-cli GET "wallet_nonce:eth:0x..."

# 3. Complete auth (nonce atomically deleted)
curl -X POST http://localhost:8000/api/v1/auth/wallet/verify ...

# 4. Verify nonce deleted
redis-cli GET "wallet_nonce:eth:0x..."  # Should return nil
```
