# FIX-BSO-SEC-002: SSRF via Webhook URLs

**Date Fixed:** January 31, 2026
**Severity:** CRITICAL
**Status:** Fixed
**Audit Area:** INJ (Input Validation), INT (Integrations)

---

## Issue Description

The webhook functionality allowed users to configure arbitrary URLs without validation. An attacker could configure webhook endpoints pointing to:
- Internal Kubernetes services (`*.svc.cluster.local`)
- Cloud metadata endpoints (`169.254.169.254`)
- Private network resources (`10.x.x.x`, `172.16.x.x`, `192.168.x.x`)
- Localhost services (`127.0.0.1`)

This Server-Side Request Forgery (SSRF) vulnerability could allow:
- Access to cloud instance metadata (credentials, secrets)
- Internal service discovery and exploitation
- Data exfiltration through the API server
- Bypass of network segmentation

## Root Cause

The webhook URL validation only checked format (via Pydantic's `HttpUrl`) but did not validate:
1. URL scheme (HTTP was allowed, not just HTTPS)
2. Target IP address after DNS resolution
3. Blocked hostname patterns

## Fix Applied

### 1. Created SSRF Protection Module

New file: `src/infrastructure/security/url_validation.py`

Features:
- Blocks private IP ranges (RFC 1918)
- Blocks cloud metadata IPs (169.254.x.x)
- Blocks loopback addresses
- Blocks internal hostnames (*.local, *.internal, *.svc.cluster.local)
- Requires HTTPS scheme
- Validates IP after DNS resolution (prevents DNS rebinding)

```python
# Blocked IP networks
BLOCKED_IP_NETWORKS = [
    ipaddress.ip_network("127.0.0.0/8"),        # Loopback
    ipaddress.ip_network("10.0.0.0/8"),         # Private Class A
    ipaddress.ip_network("172.16.0.0/12"),      # Private Class B
    ipaddress.ip_network("192.168.0.0/16"),     # Private Class C
    ipaddress.ip_network("169.254.0.0/16"),     # Link-local (cloud metadata)
    # ... more
]
```

### 2. Integrated Validation at Webhook Creation

```python
class WebhookCreate(BaseModel):
    url: HttpUrl = Field(...)

    @field_validator('url', mode='after')
    @classmethod
    def validate_url_ssrf(cls, v: HttpUrl) -> HttpUrl:
        """Validate webhook URL to prevent SSRF attacks."""
        try:
            validate_webhook_url(str(v))
        except SSRFValidationError as e:
            raise ValueError(str(e))
        return v
```

### 3. Defense-in-Depth at Delivery

Even if validation was bypassed at creation, URLs are re-validated before making requests:

```python
async def _deliver_with_retry(self, url: str, ...):
    try:
        validate_webhook_url(url)
    except SSRFValidationError as e:
        logger.error(f"SECURITY: Webhook URL failed SSRF validation: {url}")
        return False
```

## Files Modified

| File | Change |
|------|--------|
| `src/infrastructure/security/url_validation.py` | New file - SSRF protection |
| `src/presentation/api/v1/endpoints/webhooks.py` | Added URL validation |
| `src/infrastructure/blockchain/webhook_delivery.py` | Defense-in-depth validation |

## Verification

### Test 1: Block Internal IPs
```python
from src.infrastructure.security.url_validation import validate_webhook_url

# These should raise SSRFValidationError
validate_webhook_url("https://192.168.1.1/webhook")  # Private IP
validate_webhook_url("https://10.0.0.1/webhook")     # Private IP
validate_webhook_url("https://169.254.169.254/")     # Cloud metadata
validate_webhook_url("https://localhost/webhook")    # Localhost
```

### Test 2: Block Internal Hostnames
```python
validate_webhook_url("https://api-service.api-service-local.svc.cluster.local/")  # K8s service
validate_webhook_url("https://metadata.google.internal/")  # GCP metadata
```

### Test 3: Allow Valid External URLs
```python
validate_webhook_url("https://api.example.com/webhook")  # OK
validate_webhook_url("https://hooks.slack.com/services/xxx")  # OK
```

### Test 4: Require HTTPS
```python
validate_webhook_url("http://api.example.com/webhook")  # Should fail - HTTP not allowed
```

## Attack Scenarios Mitigated

| Attack | Before | After |
|--------|--------|-------|
| Cloud metadata access | Possible | Blocked |
| Internal service discovery | Possible | Blocked |
| Private network scanning | Possible | Blocked |
| DNS rebinding | Possible | Mitigated (IP check after resolution) |
| HTTP downgrade | Possible | Blocked (HTTPS required) |

## Remediation for Existing Webhooks

1. Audit existing webhook configurations:
   ```sql
   SELECT id, url FROM webhooks WHERE url NOT LIKE 'https://%';
   ```

2. Identify webhooks pointing to internal resources:
   ```sql
   SELECT id, url FROM webhooks
   WHERE url LIKE '%localhost%'
      OR url LIKE '%127.0.0.1%'
      OR url LIKE '%.local%'
      OR url LIKE '%.internal%';
   ```

3. Disable suspicious webhooks and notify users

## Prevention

- Input validation on all user-provided URLs
- Regular security audits of HTTP client usage
- Network segmentation and egress filtering
- Monitoring for unusual outbound connections
