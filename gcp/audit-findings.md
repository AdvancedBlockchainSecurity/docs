# GCP Audit Findings

**Audit Date:** 2026-03-10

## Critical

| # | Finding | Status |
|---|---------|--------|
| 1 | Cloud Armor WAF not attached to any backend service — rules exist but are not protecting traffic | Open |
| 2 | No SSL policy on HTTPS proxy — allows TLS 1.0/1.1 | Open |
| 3 | Redis-0 Pending — pod cannot schedule (no node resources in target zone) | Open |
| 4 | Orchestration Pending — pod cannot schedule | Open |
| 5 | cert-manager-cainjector CrashLoopBackOff (15+ restarts) | Open |
| 6 | notification CrashLoopBackOff (19+ restarts) | Open |
| 7 | api-service not ready (16 restarts, likely Redis/DB dependency) | Open |
| 8 | data-service not ready (19 restarts, likely DB dependency) | Open |

## High

| # | Finding | Status |
|---|---------|--------|
| 9 | Compute Engine default SA has `roles/editor` on project — should be disabled | Open |
| 10 | 16 unnecessary APIs enabled (BigQuery, Cloud SQL, Datastore, Deployment Manager, etc.) | Open |
| 11 | Node disk 200 GB (scanner pool) / 100 GB (default) — oversized | Open |
| 12 | Private IP range `10.3.0.0` reserved but unused (was for Cloud SQL peering) | Open |
| 13 | Unused subnets: `database-subnet`, `redis-subnet` (databases run in-cluster) | Open |
| 14 | HTTP forwarding rule exists alongside HTTPS — should redirect to HTTPS only | Open |

## Medium

| # | Finding | Status |
|---|---------|--------|
| 15 | NAT logging set to `ERRORS_ONLY` — should be `ALL` during initial deployment | Open |
| 16 | 3 GKE auto-created firewall rules have logging disabled | Open |
| 17 | GKE Gateway firewall rule has logging disabled | Open |
| 18 | Scanner node pool disk size 200 GB is wasteful | Open |

## Passed

- Private GKE cluster with private nodes
- Master authorized networks (single admin IP)
- etcd CMEK encryption with 90-day rotation
- Binary Authorization enabled
- Shielded nodes (Secure Boot + Integrity Monitoring)
- Workload Identity enabled
- Network Policy (Calico) enabled
- Kubernetes Dashboard disabled
- Dedicated node service account (least privilege)
- ESO service account with `secretAccessor` only
- Cloud Armor WAF rules comprehensive (7 OWASP rules + rate limiting + Cloudflare-only)
- Storage buckets: public access prevention enforced
- Container scanning API enabled
- 5 monitoring alert policies active
- Logging: system + workloads + API server + scheduler + controller manager
- 74 NetworkPolicy resources across 14 namespaces (default-deny + allow)
