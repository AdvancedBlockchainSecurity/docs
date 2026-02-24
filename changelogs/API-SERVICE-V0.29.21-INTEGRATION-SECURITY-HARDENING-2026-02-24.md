# API Service v0.29.21 - Integration Security Hardening

**Date:** February 24, 2026
**Version:** 0.29.21
**Type:** Security (PATCH)
**PR:** #255

## Summary

Comprehensive security hardening of integration endpoints, notification system, and Kubernetes secrets configuration. Addresses 22 findings from the pre-GCP integration security audit.

## Changes

### Encryption at Rest
- Webhook secrets encrypted with Fernet (AES-128-CBC + HMAC-SHA256) before database storage
- Plaintext secret returned only on create/rotate (one-time display)

### SSRF Protection
- Added `validate_webhook_url()` to monitoring webhook_url, repo_url, JIRA base_url
- Re-validation in notification notifiers (Slack, Teams, Discord) before HTTP send
- Blocks private IP ranges and internal network addresses

### Error Sanitization
- Replaced all `str(e)` patterns in OAuth service, notification notifiers, JIRA service
- OAuthServiceError messages no longer leak internal exception details
- Notification delivery errors use safe static messages
- JIRA API errors omit `response.text` content

### Input Validation
- OAuth `error_description` capped at 500 characters
- Integration `settings` dict restricted to allowlisted keys, no nested objects
- JIRA project key: `max_length=10`, pattern `^[A-Z][A-Z0-9_]+$`
- JIRA project name: `max_length=255`
- Notification channel `filters` typed as `Dict[str, str]` with key allowlist

### Access Control
- Fixed `verify_org_admin` null role bypass (`if role and` -> `if not role or`)
- Added rate limiting (`30/minute`) to webhook list/get/deliveries endpoints

### API Response Hardening
- Notification webhook URLs masked in responses (`https://hooks.slack.com/...xxxx`)
- Stripe webhook health endpoint no longer exposes `supported_events` list

### Kubernetes Secrets
- Removed `| default ""` from 8 OAuth credential ExternalSecret entries
- Moved SUPABASE_SERVICE_KEY and SUPABASE_ANON_KEY from ConfigMap to ExternalSecret
- Added INTERNAL_SERVICE_KEY to ExternalSecret with Vault path
- Deployment patched to use secretKeyRef instead of configMapKeyRef
- Cleaned up stale base/overlay ExternalSecret files

## Files Modified

### Application Code (13 files)
- `src/presentation/api/v1/endpoints/webhooks.py`
- `src/presentation/api/v1/endpoints/notification_channels.py`
- `src/presentation/schemas/monitoring.py`
- `src/presentation/api/v1/endpoints/oauth_callbacks.py`
- `src/presentation/api/v1/endpoints/integrations.py`
- `src/presentation/api/v1/endpoints/service_accounts.py`
- `src/presentation/api/v1/endpoints/stripe_webhook.py`
- `src/application/services/oauth_service.py`
- `src/application/services/jira_support_service.py`
- `src/infrastructure/notifications/slack.py`
- `src/infrastructure/notifications/teams.py`
- `src/infrastructure/notifications/discord.py`
- `src/infrastructure/notifications/service.py`

### Kubernetes Configuration (5 files)
- `k8s/overlays/local/api-service/externalsecret.yaml`
- `k8s/overlays/local/configmap-patch.yaml`
- `k8s/overlays/local/deployment-patch.yaml`
- `k8s/base/external-secret.yaml`
- `k8s/overlays/local/externalsecret.yaml`

### Version Files (2 files)
- `pyproject.toml` (0.29.20 -> 0.29.21)
- `k8s/overlays/local/api-service/kustomization.yaml` (0.29.20 -> 0.29.21)

## Breaking Changes

None. All changes are backward-compatible security improvements.

## Deployment Notes

- Requires Vault entries for `secret/data/api-service/supabase` (service_key, anon_key) and `secret/data/api-service/internal` (service_key)
- Existing webhook secrets in database are plaintext; new/rotated secrets will be encrypted
- ExternalSecret sync must succeed before pod starts (no more `| default ""` fallbacks)

## Hotfix: v0.29.22

The rate limiting on webhook GET endpoints was missing the `response: Response` parameter required by slowapi, causing 500 errors. Fixed in [v0.29.22](./API-SERVICE-V0.29.22-WEBHOOK-RATE-LIMIT-FIX-2026-02-24.md) (PR #257).
