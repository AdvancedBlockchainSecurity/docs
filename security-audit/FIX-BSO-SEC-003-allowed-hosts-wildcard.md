# FIX-BSO-SEC-003: Allowed Hosts Wildcard Default

**Date Fixed:** January 31, 2026
**Severity:** HIGH
**Status:** Fixed
**Audit Area:** NET (Network Security)

---

## Issue Description

The application configuration had a wildcard default for allowed hosts:

```python
# BEFORE (VULNERABLE)
allowed_hosts: Union[str, list[str]] = Field(default=["*"])
```

This allowed requests with any Host header value, enabling:
- Host header injection attacks
- Cache poisoning
- Password reset poisoning
- Web cache deception

## Root Cause

Convenience-oriented default to allow the application to work without configuration. No production validation to detect unsafe wildcard values.

## Fix Applied

### 1. Changed Default to Localhost Only

```python
# AFTER (FIXED)
allowed_hosts: Union[str, list[str]] = Field(
    default=["localhost", "127.0.0.1"],
    description="Allowed Host header values. Configure explicitly per environment."
)
```

### 2. Production Validation

The model validator now blocks wildcard in production:

```python
if "*" in self.allowed_hosts:
    if is_production:
        raise ValueError(
            "ALLOWED_HOSTS cannot contain wildcard '*' in production. "
            "Configure explicit hostnames."
        )
```

## Files Modified

| File | Change |
|------|--------|
| `blocksecops-api-service/src/infrastructure/config.py` | Changed default, added validation |
| `blocksecops-api-service/.env.example` | Updated documentation |

## Verification

### Test 1: Production Blocks Wildcard
```bash
ENVIRONMENT=production ALLOWED_HOSTS="*" python -c "from src.infrastructure.config import get_settings; get_settings()"
# Expected: ValueError - ALLOWED_HOSTS cannot contain wildcard
```

### Test 2: Local Environment Warns
```bash
ENVIRONMENT=local ALLOWED_HOSTS="*" python -c "from src.infrastructure.config import get_settings; get_settings()"
# Expected: UserWarning about wildcard
```

## Configuration Examples

### Local Development
```bash
ALLOWED_HOSTS="localhost,127.0.0.1"
```

### Server (kubeadm)
```bash
ALLOWED_HOSTS="app.0xapogee.com,192.168.86.225"
```

### Production (GCP)
```bash
ALLOWED_HOSTS="app.0xapogee.com,api.0xapogee.com"
```

## Prevention

- Explicit configuration required per environment
- Production validation catches misconfigurations
- Infrastructure-as-code review for allowed hosts settings
