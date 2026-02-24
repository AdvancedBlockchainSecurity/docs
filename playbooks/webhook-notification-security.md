# Webhook & Notification Security Playbook

**Version:** 1.0.0
**Last Updated:** February 24, 2026
**API Version:** 0.29.22+
**Audience:** Platform Administrator | Security

---

## Overview

This playbook covers security measures for the webhook and notification channel systems introduced in Phase 4.5 and hardened in the pre-GCP integration security audit (v0.29.22).

---

## Webhook Secret Encryption

### How It Works

Webhook HMAC signing secrets are encrypted at rest using Fernet (AES-128-CBC + HMAC-SHA256). The `encryption_service` uses the same `INTEGRATION_ENCRYPTION_KEY` as OAuth token encryption.

```
Create/Rotate:
  1. Generate random secret (32 bytes, URL-safe)
  2. Encrypt with Fernet: encrypted = encryption_service.encrypt(secret)
  3. Store encrypted value in database
  4. Return plaintext to user (one-time display)

HMAC Verification:
  1. Read encrypted secret from database
  2. Decrypt: plaintext = encryption_service.decrypt(webhook.secret)
  3. Compute HMAC-SHA256 with decrypted secret
  4. Compare with signature header
```

### Migration Notes

- Existing webhook secrets created before v0.29.21 remain plaintext in the database
- New secrets and rotated secrets are encrypted
- The decrypt function handles both formats (encrypted strings start with `gAAAAA`)

### Verification

```bash
# Check if a webhook secret is encrypted (should start with gAAAAA)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT id, LEFT(secret, 10) as secret_prefix FROM webhooks LIMIT 5;"
```

---

## Notification Channel Webhook URL Security

### SSRF Protection

All webhook URLs are validated at two layers:

1. **Schema validation** (Pydantic `@field_validator`): Rejects private IPs on create/update
2. **Send-time validation** (notifier classes): Re-validates before each HTTP request

Blocked ranges: `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`, `::1`, `fc00::/7`

### Response Masking

Webhook URLs are masked in API responses to prevent accidental exposure:

```
Stored:  https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXX
API:     https://hooks.slack.com/...XXXX
```

The full URL is stored in the database and used for delivery, but only the masked version is returned to API consumers.

### Frontend Domain Validation (v0.46.4)

The `CreateChannelModal` validates webhook URLs per provider:

| Provider | Allowed Domains |
|----------|----------------|
| Slack | `hooks.slack.com` |
| Teams | `webhook.office.com`, `outlook.office.com` |
| Discord | `discord.com`, `discordapp.com` |

### Filter Typing

Notification channel filters are typed as `Dict[str, str]` with an allowlist:
- `min_severity` - Minimum severity level
- `project_id` - Filter to specific project

Unknown keys are rejected. Nested objects are not allowed.

---

## Rate Limiting

| Endpoint | Limit | Added |
|----------|-------|-------|
| Webhook list (`GET /webhooks`) | 30/minute | v0.29.22 |
| Webhook get (`GET /webhooks/{id}`) | 30/minute | v0.29.22 |
| Webhook deliveries (`GET /webhooks/{id}/deliveries`) | 30/minute | v0.29.22 |
| OAuth callbacks | 10/minute | v0.29.19 |

### Technical Note

slowapi requires both `request: Request` and `response: Response` parameters in rate-limited endpoint functions. Missing `response` causes 500 errors (fixed in v0.29.22, PR #257).

---

## Stripe Webhook Health Endpoint

The `/webhooks/stripe/health` endpoint no longer exposes `supported_events` (removed in v0.29.21). This prevents information disclosure about internal event routing.

---

## ExternalSecret Configuration

### OAuth Credentials

All 8 OAuth credential entries in `externalsecret.yaml` must **not** use `| default ""`:

```yaml
# CORRECT (v0.29.22+)
GITHUB_CLIENT_ID: "{{ .github_client_id }}"

# WRONG (pre-v0.29.21)
GITHUB_CLIENT_ID: "{{ .github_client_id | default \"\" }}"
```

Missing secrets should cause ExternalSecret to report an error, not silently produce empty strings.

### Sensitive Keys in ExternalSecret (not ConfigMap)

These keys must be in ExternalSecret, not ConfigMap:
- `SUPABASE_SERVICE_KEY` (JWT token)
- `SUPABASE_ANON_KEY` (JWT token)
- `INTERNAL_SERVICE_KEY`
- `INTEGRATION_ENCRYPTION_KEY`

---

## Security Audit Checklist

Before GCP production deployment, verify:

- [ ] `INTEGRATION_ENCRYPTION_KEY` set in Vault/GCP Secret Manager
- [ ] Webhook secrets encrypted in database (new/rotated ones start with `gAAAAA`)
- [ ] Notification webhook URLs masked in API responses
- [ ] SSRF validation blocks private IPs on all URL inputs
- [ ] Rate limiting active on webhook GET endpoints
- [ ] ExternalSecret has no `| default ""` fallbacks
- [ ] `SUPABASE_SERVICE_KEY` comes from secret, not ConfigMap
- [ ] Stripe health endpoint does not expose `supported_events`
- [ ] Frontend validates webhook domains per provider
- [ ] Frontend validates `https://` protocol on external URLs

---

## Related Documentation

- [Integration Security Feature Test](../feature-tests/77-integration-security-hardening.md) - Manual test checklist
- [OAuth Integration Workflow](../workflows/oauth-integration-workflow.md) - Full OAuth flow
- [OAuth Integration Pipeline](../pipelines/oauth-integration-pipeline.md) - Environment setup
- [OAuth Provider Setup Playbook](./oauth-provider-setup.md) - Provider configuration
- [Security Configuration Playbook](./security-configuration.md) - General security settings
- [Secrets Management Standards](../standards/secrets-management.md) - Vault and ExternalSecret patterns
