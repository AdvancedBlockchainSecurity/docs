# API Service v0.29.20 - OAuth Audit Hardening

**Component:** blocksecops-api-service
**Scope:** OAuth credential encryption enforcement, error message sanitization
**Date:** February 24, 2026
**Status:** PRs Created

---

## Summary

Three security fixes from an OAuth integration audit preparing for GCP production deployment:

1. **Enforce encryption key in production** — API service now refuses to start without `INTEGRATION_ENCRYPTION_KEY`
2. **Sanitize OAuth error messages** — Error messages no longer leak environment variable names
3. **Safe error detail** — Token exchange and user info errors stored with `get_safe_error_detail()`

---

## Changes

### Encryption Key Enforcement

**File:** `src/infrastructure/config.py`

Previously, a missing `INTEGRATION_ENCRYPTION_KEY` in production only emitted a warning via `warnings.warn()`. Now it appends to the validation `errors` list, causing the Pydantic `model_post_init` to raise `ValueError` and prevent startup.

```python
# Before: warning only
if is_production and not self.integration_encryption_key:
    import warnings
    warnings.warn("INTEGRATION_ENCRYPTION_KEY is not set...")

# After: fail-fast
if is_production and not self.integration_encryption_key:
    errors.append("INTEGRATION_ENCRYPTION_KEY is required in production...")
```

### Error Message Sanitization

**File:** `src/application/services/oauth_service.py`

Removed environment variable names from user-facing error messages.

```python
# Before: leaks env var names
raise OAuthServiceError(
    f"Set {env_prefix}_CLIENT_ID and {env_prefix}_CLIENT_SECRET environment variables."
)

# After: safe for users
raise OAuthServiceError(
    f"Contact your administrator to set up OAuth credentials for this provider."
)
```

### Safe Error Detail Storage

**File:** `src/presentation/api/v1/endpoints/oauth_callbacks.py`

Replaced `str(e)` with `get_safe_error_detail()` for storing error details in the database.

```python
# Before: raw exception in database
integration.last_error = str(e)

# After: sanitized
integration.last_error = get_safe_error_detail(e, "token exchange")
integration.last_error = get_safe_error_detail(e, "user info retrieval")
```

---

## Version Changes

| File | Before | After |
|------|--------|-------|
| `pyproject.toml` | 0.29.19 | 0.29.20 |
| `k8s/overlays/local/api-service/kustomization.yaml` | 0.29.19 | 0.29.20 |

---

## Testing

- 1007 unit tests passing (5 pre-existing failures unrelated to OAuth)
- Error messages verified to not contain env var names
- Production config validation verified via existing test infrastructure
