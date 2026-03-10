# GCP Security

## Cluster Security

| Feature | Status | Detail |
|---------|--------|--------|
| Private nodes | Enabled | No external IPs on nodes |
| Master authorized networks | Enabled | `136.60.244.81/32` only |
| Shielded nodes | Enabled | Secure Boot + Integrity Monitoring |
| Workload Identity | Enabled | `project-8a2657b9-d96c-4c0a-a69.svc.id.goog` |
| Binary Authorization | Enabled | `PROJECT_SINGLETON_POLICY_ENFORCE` |
| etcd encryption | CMEK | Cloud KMS with 90-day rotation |
| Network Policy | Calico | Enabled cluster-wide |
| Kubernetes Dashboard | Disabled | |
| Container scanning | Enabled | Automatic vulnerability scanning on push |

## IAM

### Service Accounts

| Account | Purpose | Roles |
|---------|---------|-------|
| `apogee-production-gke-nodes@...` | GKE node SA | `logging.logWriter`, `monitoring.metricWriter`, `monitoring.viewer`, `artifactregistry.reader` |
| `eso-secrets-accessor@...` | ESO secret access | `secretmanager.secretAccessor` |
| `739955249550-compute@developer...` | Compute default SA | `roles/editor` (should be disabled) |

### Workload Identity Bindings

| K8s Service Account | Namespace | GCP Service Account |
|---------------------|-----------|---------------------|
| `external-secrets-sa` | `external-secrets-prod` | `eso-secrets-accessor@...` |

## Cloud Armor WAF

Policy: `apogee-production-waf-policy`

| Priority | Rule | Action |
|----------|------|--------|
| 100-102 | Allow Cloudflare IPs (IPv4 + IPv6) | Allow |
| 1000 | XSS protection (xss-v33-stable) | Deny 403 |
| 1001 | SQL injection (sqli-v33-stable) | Deny 403 |
| 1002 | Local file inclusion (lfi-v33-stable) | Deny 403 |
| 1003 | Remote file inclusion (rfi-v33-stable) | Deny 403 |
| 1004 | Remote code execution (rce-v33-stable) | Deny 403 |
| 1005 | Scanner detection (scannerdetection-v33-stable) | Deny 403 |
| 1006 | Protocol attack (protocolattack-v33-stable) | Deny 403 |
| 2000 | Rate limiting: 300 req/min per IP | Rate-based ban (5 min) |
| 2147483647 | Default deny (non-Cloudflare) | Deny 403 |

**Note:** WAF policy must be attached to each backend service to take effect.

## Network Policies

74 NetworkPolicy resources across 14 namespaces. Every namespace has:

- `default-deny-all` — Deny all ingress and egress by default
- `allow-dns` — Allow DNS resolution to kube-system
- Service-specific policies for allowed traffic paths

## Encryption

| Layer | Method |
|-------|--------|
| etcd at rest | Cloud KMS CMEK (AES-256, 90-day rotation) |
| Node disks | Google default encryption |
| PostgreSQL TLS | cert-manager self-signed CA (`apogee-internal-ca-issuer`) |
| Redis TLS | cert-manager self-signed CA, TLS-only (port 0, tls-port 6379) |
| External traffic | Google-managed TLS via Gateway + Cloudflare |
| Secrets at rest | GCP Secret Manager (Google-managed encryption) |

## Monitoring Alerts

| Alert | Condition |
|-------|-----------|
| Pod Crash Loop Detected | `restart_count` rate > 0 over 5 min |
| GKE Node Not Ready | Node condition != Ready |
| High 5xx Error Rate | 5xx responses detected |
| Log Ingestion > 1GB | Warning threshold |
| Log Ingestion > 5GB (Critical) | Critical threshold |

## Storage Security

Both buckets (`apogee-gcp-terraform-state`, `apogee-production-ml-models`):
- Public access prevention: `enforced`
- Uniform bucket-level access: enabled
- No public ACLs
