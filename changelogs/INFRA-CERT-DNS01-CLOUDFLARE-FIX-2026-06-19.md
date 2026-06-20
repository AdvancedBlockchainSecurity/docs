# Infrastructure: Production TLS Cert Outage — DNS-01 Authorization Fix

**Date:** 2026-06-19
**Author:** Apogee Team
**Services Affected:** blocksecops-gcp-infrastructure (Terraform), Cloudflare DNS
**Branch:** `fix/cert-manager-dns-01-authorization`
**Outage Window:** 2026-06-08 to 2026-06-19 (11 days)
**Resolution:** Migrated Google-managed certificates for `app.0xapogee.com` and `admin.0xapogee.com` from HTTP-01 to DNS-01 ACME authorization

## Summary

Production was down with Cloudflare 526 errors (invalid SSL certificate) for 11 days. Google-managed certificates for both production domains expired on June 8 and could not auto-renew because HTTP-01 ACME validation is incompatible with Cloudflare proxy (orange-cloud). DNS-01 authorization was added to both certs via Terraform, with CNAME records created at Cloudflare to satisfy the challenge. Both certificates are now ACTIVE (valid Jun 20 – Sep 18, 2026) and auto-renewal will continue to work without operator intervention.

## Root Cause

### HTTP-01 incompatibility with Cloudflare proxy

HTTP-01 ACME challenge requires Let's Encrypt (or Google Trust Services) to send an HTTP request to `http://<domain>/.well-known/acme-challenge/<token>`. When Cloudflare proxy is enabled on a domain:

1. The challenge HTTP request hits Cloudflare's edge, not the GKE load balancer.
2. Cloudflare cannot forward the challenge to the origin because the origin has no valid certificate (which is what is being renewed).
3. The challenge fails with a Cloudflare 526 error (invalid SSL) rather than reaching `34.149.16.104`.

This is a fundamental incompatibility: HTTP-01 validation cannot pass through an active Cloudflare proxy to an origin that currently lacks a valid cert.

### DNS-01 resolves the incompatibility

DNS-01 authorization works by placing a `_acme-challenge.<domain>` CNAME (pointing to a Google-managed validation endpoint) in the DNS zone. Google Trust Services validates ownership by querying DNS, which bypasses Cloudflare proxy entirely. Cloudflare's proxy status is irrelevant to DNS validation.

## Timeline

| Date | Event |
|------|-------|
| 2026-06-08 | TLS certificates for `app.0xapogee.com` and `admin.0xapogee.com` expired. Cloudflare began returning 526 errors. |
| 2026-06-08 to 2026-06-18 | Platform inaccessible from internet. HTTP-01 renewal attempts by Certificate Manager continued to fail silently (no operator alert was configured for cert provisioning failures). |
| 2026-06-19 | Root cause identified: HTTP-01 blocked by Cloudflare proxy. Fix implemented: DNS-01 authorization added via Terraform. CNAMEs added at Cloudflare. Certs force-replaced. |
| 2026-06-19 | Both certs reached ACTIVE state. `curl https://app.0xapogee.com/api/v1/health/live` returned 200. |
| 2026-06-20 | Cert validity confirmed: Jun 20 – Sep 18, 2026. |

## Fix Applied

### Terraform changes (`terraform/environments/gcp/main.tf`)

Added two `google_certificate_manager_dns_authorization` resources:

- `apogee-dns-auth` for `app.0xapogee.com`
- `admin-dns-auth` for `admin.0xapogee.com`

Added `dns_authorizations` reference to the `managed {}` block of both existing `google_certificate_manager_certificate` resources (`apogee-tls-cert` and `apogee-admin-tls-cert`).

### Terraform outputs (`terraform/environments/gcp/outputs.tf`)

Added two new outputs:
- `apogee_cert_dns_authorization_cname` — CNAME record values for `app.0xapogee.com`
- `admin_cert_dns_authorization_cname` — CNAME record values for `admin.0xapogee.com`

These outputs expose the `cname_record` field from the DNS authorization resources so the operator can retrieve the correct CNAME targets without reading the GCP console.

### Cloudflare DNS records added

Two CNAME records added to the `0xapogee.com` zone via Cloudflare API (DNS-only, gray cloud — these must NOT be proxied):

| Name | Type | Target | Proxy |
|------|------|--------|-------|
| `_acme-challenge.app.0xapogee.com` | CNAME | Google DNS auth endpoint | DNS-only (gray cloud) |
| `_acme-challenge.admin.0xapogee.com` | CNAME | Google DNS auth endpoint | DNS-only (gray cloud) |

The actual CNAME values are available from `terraform output apogee_cert_dns_authorization_cname` and `terraform output admin_cert_dns_authorization_cname`.

### Terraform state import

The `apogee-admin-tls-cert` certificate and its cert-map-entry had been created out-of-band prior to this incident. Both were imported into Terraform state before `terraform apply` to avoid drift.

### Certificate force-replace

Both certificates and their cert-map-entries were force-replaced using `terraform apply -replace=` to trigger immediate reprovisioning with DNS-01 authorization rather than waiting for the next natural renewal cycle.

## Files Modified

| File | Change |
|------|--------|
| `terraform/environments/gcp/main.tf` | Added two `google_certificate_manager_dns_authorization` resources; added `dns_authorizations` to both cert `managed {}` blocks |
| `terraform/environments/gcp/outputs.tf` | Added `apogee_cert_dns_authorization_cname` and `admin_cert_dns_authorization_cname` outputs |

## Verification

```bash
# Confirm certs are ACTIVE
gcloud certificate-manager certificates list --project=project-8a2657b9-d96c-4c0a-a69

# Confirm platform is responding
curl https://app.0xapogee.com/api/v1/health/live

# Confirm TLS cert validity
curl -vI https://app.0xapogee.com/api/v1/health/live 2>&1 | grep -E "expire|subject|issuer"
```

## Open Issues Discovered During Fix

**`admin.0xapogee.com` has no A record at Cloudflare.** The certificate, cert-map-entry, and gateway HTTPRoute all exist for the admin domain, but the public hostname has no DNS A record pointing to `34.149.16.104`. The admin portal has never been reachable from the internet. This is a pre-existing gap unrelated to the cert outage. See `TaskDocs-BlockSecOps/docs/OPEN-ISSUE-ADMIN-DNS-MISSING-2026-06-19.md` for the tracking entry.

## Prevention

See `docs/playbooks/cloudflare-proxy-gcp-cert-dns01.md` for the runbook covering diagnosis and resolution of 525/526 errors in the Cloudflare + GCP Certificate Manager stack.

An alert for cert provisioning failures should be added to the monitoring configuration. Currently Certificate Manager provisioning failures are silent unless the operator actively inspects cert status.
