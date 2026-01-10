# Authentication & Authorization Architecture

## Overview

BlockSecOps implements a secure authentication system using Supabase Auth with JWT token verification, tier-based access control, and quota enforcement. This document describes the technical architecture of the authentication and authorization system.

## Architecture Components

### 1. Supabase Auth (Identity Provider)

**Responsibilities:**
- User registration and login
- OAuth integration (Google, Microsoft, GitHub)
- Email verification
- Password reset workflows
- Session management
- JWT token generation (ES256)

**Configuration:**
- Project URL: `https://[project-ref].supabase.co`
- Public Key: JWKS endpoint at `/auth/v1/.well-known/jwks.json`
- Token expiration: 1 hour (configurable)
- Supported OAuth providers: Google, Microsoft/Azure, GitHub, Discord, Slack, BitBucket, X (Twitter)
- Algorithm: ES256 (ECDSA with P-256 curve and SHA-256)

### 2. API Service (Resource Server)

**Responsibilities:**
- JWT token verification (ES256/JWKS with RS256 fallback support)
- User synchronization from Supabase to local database
- Tier-based access control
- Quota enforcement
- API endpoint protection

**Implementation Location:**
- JWT verification: `src/infrastructure/auth/supabase_client.py`
- Middleware: `src/infrastructure/auth/middleware.py`
- Database models: `src/infrastructure/database/models.py`

## Authentication Flow

### User Registration Flow

```
1. User → app.blocksecops.com/signup
   ↓
2. Frontend → Supabase Auth (register)
   - Email/password OR OAuth provider
   ↓
3. Supabase → Email verification sent
   ↓
4. User clicks verification link
   ↓
5. Supabase → User verified
   ↓
6. Frontend → Receives session with JWT
   ↓
7. Frontend → First API call with JWT
   ↓
8. API → Verifies JWT, creates user in local DB
   - Default tier: 'free'
   - Auto-creates quota via DB trigger
```

### Login Flow

```
1. User → app.blocksecops.com/login
   ↓
2. Frontend → Supabase Auth (login)
   ↓
3. Supabase → Returns session with JWT
   ↓
4. Frontend → Stores session in localStorage
   ↓
5. Frontend → Makes API calls with JWT
   ↓
6. API → Verifies JWT, returns data
```

### API Request Flow

```
1. Frontend → API request with Authorization header
   Authorization: Bearer <supabase_jwt>
   ↓
2. API Middleware → Extract token
   ↓
3. API → Fetch JWKS from Supabase (.well-known/jwks.json)
   ↓
4. API → Verify JWT signature (ES256, with RS256 fallback)
   ↓
5. API → Extract user_id from token payload
   ↓
6. API → Look up user in local database
   ↓
7. If user not found:
   - Create user from Supabase data
   - Assign tier='free'
   - Trigger creates quota record
   ↓
8. API → Check tier-based permissions
   ↓
9. API → Check quota if applicable
   ↓
10. API → Execute business logic
    ↓
11. API → Return response
```

## JWT Verification (ES256)

### Token Structure

```json
{
  "header": {
    "alg": "ES256",
    "typ": "JWT",
    "kid": "key-id-from-jwks"
  },
  "payload": {
    "aud": "authenticated",
    "exp": 1699834800,
    "sub": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "role": "authenticated"
  },
  "signature": "..."
}
```

### Verification Process

1. **Extract token** from Authorization header
2. **Fetch JWKS** from Supabase (cached for performance)
3. **Find public key** matching `kid` from token header
4. **Verify signature** using ES256 algorithm (ECDSA with P-256 curve)
5. **Validate claims**:
   - `aud` must be "authenticated"
   - `exp` must be in future
   - Token must be well-formed
6. **Extract user data** from payload (`sub`, `email`)

### Security Properties

**ES256 (Asymmetric Elliptic Curve)**:
- Private key: Held by Supabase (signs tokens)
- Public key: Distributed via JWKS (verifies tokens)
- Compromise of API server does NOT allow token forgery
- More efficient than RSA with equivalent security

**vs HS256 (Symmetric)**:
- Single shared secret
- Anyone with secret can create tokens
- Compromise of ANY server allows token forgery

**JWKS (JSON Web Key Set)**:
- Public keys published at `/.well-known/jwks.json`
- Automatic key rotation support
- No hardcoded secrets in backend

### Local Development Fallback (Updated November 16, 2025)

For local development and testing without a Supabase instance, the JWT verification system implements an intelligent fallback to HS256:

**File**: `src/infrastructure/security/jwt.py`

```python
def decode_supabase_token(token: str) -> Optional[dict[str, Any]]:
    """
    Decode and validate a Supabase JWT token using JWKS public key verification.

    For local development/testing without Supabase, falls back to HS256 verification.
    """
    try:
        # Get unverified header to check key ID (kid)
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")

        # If no kid in token, it's likely an HS256 token (local testing)
        # Fall back to HS256 verification
        if not kid:
            return decode_token(token)

        # Get JWKS from Supabase (cache for performance)
        if _supabase_jwks_cache is None:
            supabase_url = settings.supabase_url
            if not supabase_url:
                # SUPABASE_URL not configured - fall back to HS256 for local testing
                return decode_token(token)

            # ... RS256 verification continues
```

**Fallback Logic**:
1. **Check for "kid" in token header**
   - ES256 tokens from Supabase always include a "kid" (key ID)
   - HS256 tokens for local testing do not have a "kid"

2. **If no "kid"** → Use HS256 verification with `JWT_SECRET_KEY`
3. **If "kid" present but SUPABASE_URL not configured** → Fall back to HS256
4. **If "kid" present and SUPABASE_URL configured** → Use ES256/RS256 with JWKS (auto-detected)

**Benefits**:
- ✅ Production uses secure ES256 with Supabase JWKS (auto-detects algorithm)
- ✅ Local development works without Supabase instance
- ✅ Integration tests can run without external dependencies
- ✅ Automatic, transparent switching - no code changes needed
- ✅ Fast local testing (no JWKS fetch overhead)

**Security Note**: The HS256 fallback is ONLY active when:
- Token has no "kid" in header (intentional local test token), OR
- `SUPABASE_URL` environment variable is not configured (local dev only)

Production environments with `SUPABASE_URL` configured will never fall back to HS256.

## User Synchronization

### Database Tables

#### users
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,  -- Empty for Supabase users
    supabase_user_id UUID UNIQUE,
    is_active BOOLEAN DEFAULT true,
    is_superuser BOOLEAN DEFAULT false,
    tier VARCHAR(20) DEFAULT 'free',
    tier_updated_at TIMESTAMP WITH TIME ZONE,
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    -- Ethereum wallet (Phase 3.3)
    wallet_address VARCHAR(42) UNIQUE,           -- Checksummed Ethereum address
    wallet_nonce VARCHAR(64),                    -- SIWE nonce
    wallet_linked_at TIMESTAMP WITH TIME ZONE,
    ens_name VARCHAR(255),                       -- ENS domain name
    -- Solana wallet (Phase 3.1b)
    solana_wallet_address VARCHAR(44) UNIQUE,    -- Base58 encoded (32 bytes = 44 chars)
    solana_wallet_nonce VARCHAR(64),             -- Ed25519 signature nonce
    solana_wallet_linked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

#### user_quotas
```sql
CREATE TABLE user_quotas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    tier VARCHAR(20) NOT NULL,
    monthly_scan_limit INTEGER NOT NULL,
    monthly_scans_used INTEGER DEFAULT 0,
    max_files_per_scan INTEGER NOT NULL,
    scan_priority INTEGER NOT NULL,
    webhooks_enabled BOOLEAN DEFAULT false,
    api_access_enabled BOOLEAN DEFAULT false,
    result_retention_days INTEGER NOT NULL,
    quota_reset_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Auto-Sync Trigger

```sql
CREATE OR REPLACE FUNCTION create_user_quota()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_quotas (
        user_id, tier, monthly_scan_limit, max_files_per_scan,
        scan_priority, webhooks_enabled, api_access_enabled,
        result_retention_days, quota_reset_at
    ) VALUES (
        NEW.id,
        NEW.tier,
        CASE NEW.tier
            WHEN 'free' THEN 10
            WHEN 'pro' THEN -1  -- unlimited
            WHEN 'enterprise' THEN -1
            WHEN 'enterprise_broker' THEN -1
        END,
        CASE NEW.tier
            WHEN 'free' THEN 25
            WHEN 'pro' THEN 100
            WHEN 'enterprise' THEN -1
            WHEN 'enterprise_broker' THEN -1
        END,
        CASE NEW.tier
            WHEN 'free' THEN 25
            WHEN 'pro' THEN 50
            WHEN 'enterprise' THEN 75
            WHEN 'enterprise_broker' THEN 100
        END,
        CASE NEW.tier WHEN 'free' THEN false ELSE true END,
        CASE NEW.tier WHEN 'free' THEN false ELSE true END,
        CASE NEW.tier
            WHEN 'free' THEN 30
            WHEN 'pro' THEN 365
            ELSE -1
        END,
        (DATE_TRUNC('month', NOW()) + INTERVAL '1 month')::timestamptz
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_quota_auto_create
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_user_quota();
```

## Tier-Based Access Control

### Tier Hierarchy

```
free (0) < pro (1) < enterprise (2) < enterprise_broker (3)
```

### Tier Limits

| Feature | Free | Pro | Enterprise | Enterprise Broker |
|---------|------|-----|------------|-------------------|
| Monthly Scans | 10 | Unlimited | Unlimited | Unlimited |
| Files per Scan | 25 | 100 | Unlimited | Unlimited |
| Scan Priority | 25 (low) | 50 (medium) | 75 (high) | 100 (highest) |
| Webhooks | No | Yes | Yes | Yes |
| API Access | No | Yes | Yes | Yes |
| Result Retention | 30 days | 365 days | Unlimited | Unlimited |

### Middleware Implementation

#### require_tier(min_tier)

```python
def require_tier(min_tier: str):
    """Dependency factory for tier-based access control."""
    TIER_HIERARCHY = {
        "free": 0,
        "pro": 1,
        "enterprise": 2,
        "enterprise_broker": 3,
    }

    async def check_tier(user: UserModel = Depends(get_current_user)) -> UserModel:
        user_tier_level = TIER_HIERARCHY.get(user.tier, 0)
        required_tier_level = TIER_HIERARCHY.get(min_tier, 99)

        if user_tier_level < required_tier_level:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"This feature requires {min_tier} tier or higher"
            )
        return user

    return check_tier
```

**Usage:**
```python
@router.post("/webhooks")
async def create_webhook(user: UserModel = Depends(require_tier("pro"))):
    # Only Pro+ users can access
    ...
```

#### check_quota(operation)

```python
async def check_quota(
    operation: str,
    user: UserModel = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
) -> UserModel:
    """Check if user has quota available."""
    quota = await db.get(UserQuotaModel, user_id=user.id)

    if operation == "scan":
        if quota.monthly_scan_limit != -1:  # -1 = unlimited
            if quota.monthly_scans_used >= quota.monthly_scan_limit:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail={
                        "error": "Monthly scan quota exceeded",
                        "quota_limit": quota.monthly_scan_limit,
                        "quota_used": quota.monthly_scans_used,
                        "tier": user.tier,
                        "message": "Upgrade to Pro for unlimited scans"
                    }
                )

    return user
```

**Usage:**
```python
@router.post("/scans")
async def create_scan(
    user: UserModel = Depends(check_quota("scan")),
    db: AsyncSession = Depends(get_db)
):
    # Quota checked before scan creation
    ...
```

## Quota Enforcement

### Monthly Quota Reset

Quotas reset on the first day of each month at midnight UTC:

```sql
-- quota_reset_at calculation
DATE_TRUNC('month', NOW()) + INTERVAL '1 month'
```

### Scan Creation Flow with Quota

```
1. User → POST /scans
   ↓
2. Middleware → Verify JWT
   ↓
3. Middleware → check_quota("scan")
   ↓
4. If quota exceeded:
   - Return 429 Too Many Requests
   - Include upgrade message
   ↓
5. If file count > max_files_per_scan:
   - Return 400 Bad Request
   - Include tier limits
   ↓
6. Create scan job
   ↓
7. Increment quota.monthly_scans_used
   ↓
8. Submit to queue with priority based on tier
```

### Priority Queue

Scans are prioritized based on tier:

| Tier | Priority | Celery Priority | Processing Order |
|------|----------|-----------------|------------------|
| Free | 25 | 7 (low) | Last |
| Pro | 50 | 5 (medium) | Third |
| Enterprise | 75 | 2 (high) | Second |
| Enterprise Broker | 100 | 0 (highest) | First |

## Security Considerations

### Token Security

- **HTTPS Required**: All auth endpoints must use HTTPS in production
- **Token Storage**: Tokens stored in localStorage (accessible to JavaScript)
- **Token Rotation**: 1-hour expiration with refresh mechanism
- **CORS**: Strict origin whitelisting

### User Data Security

- **Password Hashing**: BCrypt (Supabase handles this)
- **Email Verification**: Required before API access
- **Session Storage**: PostgreSQL (not cookies/Redis)
- **Audit Trail**: All tier changes logged

### API Security

- **Rate Limiting**: Per-user quota enforcement
- **CORS Configuration**: Whitelist specific origins
- **Input Validation**: All endpoints validate input
- **SQL Injection**: Parameterized queries via SQLAlchemy

## Monitoring & Observability

### Metrics

- JWT verification success/failure rates
- User sync operations
- Quota enforcement hits
- Tier upgrade events
- Authentication failures

### Logging

```python
logger.info(f"User {user.id} authenticated via Supabase")
logger.info(f"User {user.id} quota check: {quota.monthly_scans_used}/{quota.monthly_scan_limit}")
logger.warning(f"User {user.id} quota exceeded")
logger.info(f"User {user.id} tier upgraded from {old_tier} to {new_tier}")
```

### Health Checks

- Supabase JWKS endpoint availability
- Database connectivity
- User synchronization lag

## Integration Points

### Frontend (app.blocksecops.com)

```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY,
  {
    auth: {
      redirectTo: 'https://app.blocksecops.com/auth/callback',
      cookieDomain: '.blocksecops.com',
      autoRefreshToken: true,
      persistSession: true,
    }
  }
)

// Get session and make authenticated request
const { data: { session } } = await supabase.auth.getSession()
const response = await fetch('https://api.blocksecops.com/api/v1/users/me/enhanced', {
  headers: { 'Authorization': `Bearer ${session.access_token}` }
})
```

### Backend (api.blocksecops.com)

```python
from fastapi import Depends, HTTPException
from src.infrastructure.auth.middleware import get_current_user, check_quota

@router.post("/scans")
async def create_scan(
    scan_request: ScanRequest,
    user: UserModel = Depends(check_quota("scan")),
    db: AsyncSession = Depends(get_db)
):
    # User is authenticated and has quota
    ...
```

## Testing Strategy

### Unit Tests

- JWT verification logic
- Tier hierarchy calculations
- Quota enforcement logic
- User sync operations

### Integration Tests

- End-to-end authentication flow
- Token verification with real JWKS
- Quota enforcement on endpoints
- Tier-based access control

### Security Tests

- Invalid token rejection
- Expired token handling
- Tampered token detection
- CORS policy enforcement

## Deployment Configuration

### Environment Variables

```bash
# Supabase Configuration
SUPABASE_URL=https://[project-ref].supabase.co
SUPABASE_SERVICE_KEY=<service-role-key>
SUPABASE_ANON_KEY=<anon-key>

# Database
DATABASE_URL=postgresql+asyncpg://postgres:postgres@postgresql:5432/solidity_security

# CORS
FRONTEND_URL=https://app.blocksecops.com
```

### Kubernetes Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: auth-secrets
type: Opaque
stringData:
  supabase-service-key: <base64-encoded-key>
  database-url: <base64-encoded-url>
```

## Web3 Wallet Authentication

### Supported Wallets

**Ethereum (EVM)**:
- MetaMask (browser extension)
- WalletConnect (QR code for mobile wallets)
- Coinbase Wallet
- Rainbow, Trust Wallet, and other WalletConnect-compatible wallets

**Solana**:
- Phantom
- Solflare
- Backpack
- Ledger (via Solana adapter)

### Ethereum Wallet Auth Flow (SIWE + Supabase)

```
1. User → Click "Connect Wallet"
   ↓
2. Frontend → Opens wallet modal (wagmi/RainbowKit)
   ↓
3. User → Selects wallet and approves connection
   ↓
4. Frontend → Receives wallet address
   ↓
5. Frontend → POST /api/v1/auth/wallet/nonce { address }
   ↓
6. Backend → Generates nonce, stores with address
   ↓
7. Frontend → Creates SIWE message (EIP-4361)
   ↓
8. Frontend → Requests signature from wallet
   ↓
9. User → Signs message in wallet
   ↓
10. Frontend → POST /api/v1/auth/wallet/verify { address, signature, message }
    ↓
11. Backend → Verifies signature using eth_account/siwe
    ↓
12. Backend → Creates/gets Supabase user via Admin API
    ↓
13. Backend → Returns Supabase session (access_token, refresh_token)
    ↓
14. Frontend → supabase.auth.setSession({ access_token, refresh_token })
    ↓
15. User → Authenticated with unified Supabase session
```

### Solana Wallet Auth Flow (+ Supabase)

```
1. User → Click "Connect Solana"
   ↓
2. Frontend → Opens Solana wallet modal (@solana/wallet-adapter)
   ↓
3. User → Selects wallet (Phantom, Solflare, etc.)
   ↓
4. Frontend → Receives public key (base58)
   ↓
5. Frontend → POST /api/v1/auth/wallet/solana/nonce { address }
   ↓
6. Backend → Generates nonce, stores with address
   ↓
7. Frontend → Creates sign-in message with nonce
   ↓
8. Frontend → Requests signature from wallet
   ↓
9. User → Signs message in wallet
   ↓
10. Frontend → POST /api/v1/auth/wallet/solana/verify { address, signature, message }
    ↓
11. Backend → Verifies signature using nacl (Ed25519)
    ↓
12. Backend → Creates/gets Supabase user via Admin API
    ↓
13. Backend → Returns Supabase session (access_token, refresh_token)
    ↓
14. Frontend → supabase.auth.setSession({ access_token, refresh_token })
    ↓
15. User → Authenticated with unified Supabase session
```

### Wallet Security Considerations

- **Nonce expiration**: 5 minutes to prevent replay attacks
- **One-time nonce**: Cleared after successful verification
- **Address validation**: Ethereum (checksummed hex), Solana (base58, 32 bytes)
- **Message format**: Clear, human-readable for user review

## References

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [JWT RS256 Specification](https://datatracker.ietf.org/doc/html/rfc7519)
- [JWKS Specification](https://datatracker.ietf.org/doc/html/rfc7517)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [SIWE (Sign-In with Ethereum)](https://eips.ethereum.org/EIPS/eip-4361)
- [Solana Wallet Adapter](https://github.com/solana-labs/wallet-adapter)

---

**Last Updated**: January 10, 2026
**Status**: Production
