# Playbook: Cloudflare Proxy + GCP Certificate Manager — DNS-01 Authorization

**Version:** 1.0.0
**Last Updated:** 2026-06-19
**Audience:** Platform Operator | Infrastructure Engineer

## Overview

This playbook covers diagnosing and resolving TLS certificate errors (Cloudflare 525/526) in the production stack where Google-managed certificates are issued via Certificate Manager and traffic passes through Cloudflare proxy before reaching the GKE load balancer.

**Key rule:** All production domains behind Cloudflare proxy MUST use DNS-01 ACME authorization. HTTP-01 cannot pass through Cloudflare proxy when the origin certificate is expired or invalid. See `docs/standards/ingress-networking.md` for the authoritative requirement.

---

## Prerequisites

- `gcloud` CLI authenticated: `gcloud auth application-default login`
- `kubectl` access to GKE cluster: `gcloud container clusters get-credentials apogee-production-gke --region us-west1 --project project-8a2657b9-d96c-4c0a-a69`
- Terraform working directory: `blocksecops-gcp-infrastructure/terraform/environments/gcp`
- Cloudflare API access (via Cloudflare API MCP or `curl` with Zone API token)

---

## Section 1: Diagnosing 525/526 Errors

### Error meanings

| Cloudflare Error | Meaning | Likely cause |
|-----------------|---------|--------------|
| 525 — SSL handshake failed | Cloudflare could connect to origin but TLS handshake failed | Origin cert is expired or self-signed but Full (Strict) mode is set |
| 526 — Invalid SSL certificate | Origin certificate is expired, untrusted, or invalid | Certificate expired; DNS-01 renewal failed |

### Step 1: Verify the origin certificate status

```bash
# Check Certificate Manager certificates
gcloud certificate-manager certificates list \
  --project=project-8a2657b9-d96c-4c0a-a69

# Expected: ACTIVE for both apogee-tls-cert and apogee-admin-tls-cert
# If PROVISIONING or FAILED, certificate renewal has a problem
```

```bash
# Describe the specific certificate for details
gcloud certificate-manager certificates describe apogee-tls-cert \
  --project=project-8a2657b9-d96c-4c0a-a69
```

Look at `managed.authorizationAttemptInfo` in the output. If `state: FAILED` or `state: AUTHORIZING` with no progress, the ACME challenge is failing.

### Step 2: Verify DNS authorization resources exist

```bash
gcloud certificate-manager dns-authorizations list \
  --project=project-8a2657b9-d96c-4c0a-a69
```

Expected output: two DNS authorizations, one for `app.0xapogee.com` and one for `admin.0xapogee.com`.

If either is missing, the Terraform resource was not applied. Proceed to Section 2.

### Step 3: Verify CNAME records exist at Cloudflare

```bash
# Get the expected CNAME values from Terraform outputs
cd blocksecops-gcp-infrastructure/terraform/environments/gcp
export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)
~/.local/bin/terraform output apogee_cert_dns_authorization_cname
~/.local/bin/terraform output admin_cert_dns_authorization_cname
```

Then verify the `_acme-challenge` CNAMEs exist in Cloudflare DNS and are set to **DNS-only (gray cloud)** — not proxied.

```bash
# Query DNS directly to verify the CNAMEs resolve
dig CNAME _acme-challenge.app.0xapogee.com
dig CNAME _acme-challenge.admin.0xapogee.com
```

If the CNAMEs are missing or proxied (orange cloud), proceed to Section 3.

### Step 4: Test the origin directly

```bash
# Bypass Cloudflare and test the GKE load balancer directly
curl -k --resolve app.0xapogee.com:443:34.149.16.104 \
  https://app.0xapogee.com/api/v1/health/live
```

If this returns 200, the platform is up but the TLS certificate presented to Cloudflare is invalid. If it fails, there may be a deeper infrastructure problem.

---

## Section 2: Adding DNS-01 Authorization (Terraform)

Use this section when DNS authorization resources are missing or when setting up a new domain.

### Step 1: Add DNS authorization resources

In `terraform/environments/gcp/main.tf`, add a `google_certificate_manager_dns_authorization` resource for each domain:

```hcl
resource "google_certificate_manager_dns_authorization" "apogee" {
  name        = "apogee-dns-auth"
  description = "DNS authorization for app.0xapogee.com"
  domain      = "app.0xapogee.com"
  project     = var.project_id
}

resource "google_certificate_manager_dns_authorization" "admin" {
  name        = "admin-dns-auth"
  description = "DNS authorization for admin.0xapogee.com"
  domain      = "admin.0xapogee.com"
  project     = var.project_id
}
```

### Step 2: Reference DNS authorizations in the certificates

In the existing `google_certificate_manager_certificate` resources, add `dns_authorizations` to the `managed {}` block:

```hcl
resource "google_certificate_manager_certificate" "apogee_tls" {
  # ... existing config ...
  managed {
    domains            = ["app.0xapogee.com"]
    dns_authorizations = [google_certificate_manager_dns_authorization.apogee.id]
  }
}
```

### Step 3: Add outputs for CNAME values

In `terraform/environments/gcp/outputs.tf`:

```hcl
output "apogee_cert_dns_authorization_cname" {
  description = "CNAME record to add at Cloudflare for app.0xapogee.com DNS-01 cert authorization"
  value       = google_certificate_manager_dns_authorization.apogee.dns_resource_record
}

output "admin_cert_dns_authorization_cname" {
  description = "CNAME record to add at Cloudflare for admin.0xapogee.com DNS-01 cert authorization"
  value       = google_certificate_manager_dns_authorization.admin.dns_resource_record
}
```

### Step 4: Apply Terraform

```bash
cd blocksecops-gcp-infrastructure/terraform/environments/gcp
export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)
~/.local/bin/terraform init -backend-config=backend.tfvars
~/.local/bin/terraform plan -out=tfplan
~/.local/bin/terraform apply tfplan
```

### Step 5: Retrieve CNAME values

```bash
~/.local/bin/terraform output apogee_cert_dns_authorization_cname
~/.local/bin/terraform output admin_cert_dns_authorization_cname
```

Note the `name` (the record to create, e.g. `_acme-challenge.app.0xapogee.com`) and `data` (the CNAME target) fields. Proceed to Section 3.

---

## Section 3: Creating CNAME Records at Cloudflare

The `_acme-challenge` CNAME records must be **DNS-only (gray cloud)**. If they are proxied, Cloudflare will intercept the DNS query and Google Trust Services will not receive the correct validation response.

### Via Cloudflare API

```bash
# Set your zone ID and API token
CF_ZONE_ID="<zone_id>"
CF_API_TOKEN="<api_token>"

# Create CNAME for app.0xapogee.com challenge
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CNAME",
    "name": "_acme-challenge.app.0xapogee.com",
    "content": "<cname_target_from_terraform_output>",
    "ttl": 60,
    "proxied": false
  }'

# Create CNAME for admin.0xapogee.com challenge
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CNAME",
    "name": "_acme-challenge.admin.0xapogee.com",
    "content": "<cname_target_from_terraform_output>",
    "ttl": 60,
    "proxied": false
  }'
```

**Critical:** `"proxied": false` is mandatory. These records must never be orange-cloud.

---

## Section 4: Force-Replacing Expired Certificates

If certificates expired and DNS-01 authorization has now been correctly set up, force-replace the certs to trigger immediate reprovisioning rather than waiting for the next scheduled renewal attempt.

```bash
# Force-replace the certificates and their cert-map-entries
cd blocksecops-gcp-infrastructure/terraform/environments/gcp
export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)

~/.local/bin/terraform apply \
  -replace=google_certificate_manager_certificate.apogee_tls \
  -replace=google_certificate_manager_certificate_map_entry.apogee \
  -replace=google_certificate_manager_certificate.admin_tls \
  -replace=google_certificate_manager_certificate_map_entry.admin
```

After apply, poll certificate status until ACTIVE:

```bash
watch -n 30 'gcloud certificate-manager certificates list \
  --project=project-8a2657b9-d96c-4c0a-a69'
```

Google-managed certificates typically provision within 15–60 minutes once DNS-01 CNAMEs are in place and DNS has propagated.

---

## Section 5: Importing Out-of-Band Resources

If a certificate or cert-map-entry was created outside Terraform (in the GCP console or via `gcloud`), import it before applying any changes to avoid Terraform trying to create a duplicate.

```bash
# Import a certificate
~/.local/bin/terraform import \
  google_certificate_manager_certificate.admin_tls \
  "projects/project-8a2657b9-d96c-4c0a-a69/locations/global/certificates/<cert_name>"

# Import a cert-map-entry
~/.local/bin/terraform import \
  google_certificate_manager_certificate_map_entry.admin \
  "projects/project-8a2657b9-d96c-4c0a-a69/locations/global/certificateMaps/apogee-cert-map/certificateMapEntries/<entry_name>"
```

---

## Section 6: Verification and Post-Fix Checks

```bash
# 1. Confirm certificates are ACTIVE
gcloud certificate-manager certificates list \
  --project=project-8a2657b9-d96c-4c0a-a69

# 2. Confirm platform is responding
curl https://app.0xapogee.com/api/v1/health/live

# 3. Check TLS validity
curl -vI https://app.0xapogee.com/api/v1/health/live 2>&1 | grep -E "expire|subject|issuer|SSL"

# 4. Confirm admin domain (once DNS A record exists)
# Note: admin.0xapogee.com has no A record as of 2026-06-19 — see open issue
# curl https://admin.0xapogee.com/health
```

---

## Known Open Issues

**`admin.0xapogee.com` missing A record (as of 2026-06-19):** The admin domain has a valid certificate and cert-map-entry, but no DNS A record at Cloudflare. The admin portal is not reachable from the internet. A single A record (`admin` → `34.149.16.104`, proxied / orange cloud) is needed. Tracked in `TaskDocs-BlockSecOps/docs/OPEN-ISSUE-ADMIN-DNS-MISSING-2026-06-19.md`.

---

## Reference

| Resource | Location |
|----------|---------|
| Ingress networking standard | `docs/standards/ingress-networking.md` |
| Cert outage RCA and timeline | `docs/changelogs/INFRA-CERT-DNS01-CLOUDFLARE-FIX-2026-06-19.md` |
| Terraform cert resources | `blocksecops-gcp-infrastructure/terraform/environments/gcp/main.tf` |
| Terraform CNAME outputs | `blocksecops-gcp-infrastructure/terraform/environments/gcp/outputs.tf` |
| GCP infrastructure reference | `blocksecops-gcp-infrastructure/docs/gcp/infrastructure.md` |
