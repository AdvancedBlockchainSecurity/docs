# FIX-BSO-SEC-001: Default Secrets in Configuration

**Date Fixed:** January 31, 2026
**Severity:** CRITICAL
**Status:** Fixed
**Audit Area:** SEC (Secrets Management)

---

## Issue Description

The application configuration (`src/infrastructure/config.py`) contained hardcoded default values for critical secrets:

```python
# BEFORE (VULNERABLE)
jwt_secret_key: str = Field(default="changeme-in-production")
session_secret: str = Field(default="changeme-in-production")
```

If deployed without proper environment configuration, these known default values could be used by attackers to:
- Forge JWT tokens and impersonate any user
- Create valid sessions bypassing authentication
- Gain unauthorized access to all platform features

## Root Cause

Convenience-oriented defaults were added during development to allow the application to start without full configuration. No production validation was implemented to detect these insecure values.

## Fix Applied

### 1. Removed Insecure Defaults

```python
# AFTER (FIXED)
jwt_secret_key: str = Field(
    default="",
    description="JWT signing secret. REQUIRED."
)
session_secret: str = Field(
    default="",
    description="Session signing secret. REQUIRED."
)
```

### 2. Added Production Security Validator

A model validator was added that:
- **Fails fast** in production environments if secrets are not configured
- **Warns** in development environments if insecure values are detected
- Checks against a blocklist of known insecure values

```python
@model_validator(mode='after')
def validate_production_security(self):
    """Enforce secure configuration in production environments."""
    is_production = self.environment.lower() in ('production', 'staging', 'server', 'gcp')

    if not self.jwt_secret_key or self.jwt_secret_key.lower() in _INSECURE_SECRET_VALUES:
        if is_production:
            raise ValueError("JWT_SECRET_KEY must be set to a secure value in production")
```

### 3. Updated Documentation

- `.env.example` updated with security warnings
- Clear instructions for generating secure secrets
- Documentation of `ENVIRONMENT` variable behavior

## Files Modified

| File | Change |
|------|--------|
| `blocksecops-api-service/src/infrastructure/config.py` | Removed defaults, added validation |
| `blocksecops-api-service/.env.example` | Updated with security guidance |

## Verification

### Test 1: Production Environment Blocks Insecure Config
```bash
ENVIRONMENT=production JWT_SECRET_KEY="" python -c "from src.infrastructure.config import get_settings; get_settings()"
# Expected: ValueError - SECURITY ERROR: Insecure configuration detected
```

### Test 2: Local Environment Warns
```bash
ENVIRONMENT=local JWT_SECRET_KEY="" python -c "from src.infrastructure.config import get_settings; get_settings()"
# Expected: UserWarning about insecure values
```

### Test 3: Secure Config Works
```bash
ENVIRONMENT=production JWT_SECRET_KEY=$(python -c "import secrets; print(secrets.token_urlsafe(32))") ...
# Expected: Application starts normally
```

## Remediation for Existing Deployments

1. Generate new secrets:
   ```bash
   python -c "import secrets; print('JWT_SECRET_KEY=' + secrets.token_urlsafe(32))"
   python -c "import secrets; print('SESSION_SECRET=' + secrets.token_urlsafe(32))"
   ```

2. Store in Vault:
   ```bash
   vault kv put secret/production/api-service/jwt secret_key="<generated-value>"
   vault kv put secret/production/api-service/session secret="<generated-value>"
   ```

3. Restart API service pods to pick up new configuration

4. Invalidate all existing sessions (force re-authentication)

## Prevention

- CI/CD pipeline should validate configuration before deployment
- Pre-commit hooks to detect hardcoded secrets
- Regular secret rotation schedule
