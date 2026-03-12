# GCP Audit Findings

**Audit Date:** 2026-03-10

## Critical

| # | Finding | Status |
|---|---------|--------|
| 1 | ~~Cloud Armor WAF not attached to any backend service~~ — Fixed: GCPBackendPolicy resources added in `backend-policies/` directory with per-service namespaces | Resolved (2026-03-10) |
| 2 | ~~No SSL policy on HTTPS proxy~~ — Fixed: `apogee-production-ssl-policy` (MODERN profile, TLS 1.2+) attached via `GCPGatewayPolicy` | Resolved (2026-03-10) |
| 3 | ~~Redis-0 Pending~~ — Fixed: CPU requests right-sized, autoscaling enabled (`max_count` 2→4). See [RCA](rca/pending-pods-redis-orchestration.md) | Resolved (2026-03-10) |
| 4 | ~~Orchestration Pending~~ — Fixed: Same root cause as #3. CPU requests right-sized across all services | Resolved (2026-03-10) |
| 5 | ~~cert-manager-cainjector CrashLoopBackOff~~ — Fixed: Missing NetworkPolicy for API server egress. Added `allow-cert-manager.yaml` and `allow-external-secrets.yaml` | Resolved (2026-03-10) |
| 6 | ~~notification CrashLoopBackOff~~ — Resolved: Was dependency on Redis (Finding #3). Running after Redis fix | Resolved (2026-03-10) |
| 7 | ~~api-service not ready~~ — Resolved: Was dependency on Redis (Finding #3). Running after Redis fix | Resolved (2026-03-10) |
| 8 | ~~data-service not ready~~ — Resolved: Was dependency on Redis/DB (Finding #3). Running after Redis fix | Resolved (2026-03-10) |

## High

| # | Finding | Status |
|---|---------|--------|
| 9 | ~~Compute Engine default SA~~ — Fixed: SA had no project roles (editor was on Google APIs agent, not compute SA). SA disabled via `google_project_default_service_accounts` | Resolved (2026-03-10) |
| 10 | ~~16 unnecessary APIs enabled~~ — Fixed: Disabled 5 unnecessary APIs (Cloud SQL, Memorystore Redis, Deployment Manager, Datastore, sql-component). Removed `sqladmin` and `redis` from Terraform `required_apis`. BigQuery suite APIs are GCP project defaults that re-enable as dependencies — accepted risk | Resolved (2026-03-10) |
| 11 | ~~Node disk oversized~~ — Fixed: Scanner pool disk reduced 200 GB → 50 GB. Default pool 100 GB is appropriate for container images | Resolved (2026-03-10) |
| 12 | ~~Private IP range `10.3.0.0` reserved~~ — Fixed: Removed private IP range, VPC peering connection, and both unused subnets from Terraform. Resources deleted from GCP | Resolved (2026-03-10) |
| 13 | ~~Unused subnets: `database-subnet`, `redis-subnet`~~ — Fixed: Deleted as part of Finding #12 cleanup | Resolved (2026-03-10) |
| 14 | ~~HTTP forwarding rule exists alongside HTTPS~~ — Not an issue: HTTP listener returns 301 redirect to HTTPS. Managed by GKE Gateway `http-redirect` listener | Resolved (2026-03-10) |

## Critical (March 11, 2026 — Smoke Test Findings)

| # | Finding | Status |
|---|---------|--------|
| 19 | ~~intelligence-engine unreachable from api-service~~ — Base NetworkPolicy used `-local` namespaces and wrong port (8002 instead of 8000). Created GCP overlay patches for all 7 egress policies + ingress | Resolved (2026-03-11) |
| 20 | ~~contract-parser unreachable from api-service~~ — Same pattern as #19. Base used `-local` namespaces and wrong port. Created GCP overlay patches for ingress, redis, dns | Resolved (2026-03-11) |
| 21 | ~~PostgreSQL FATAL errors every 5s~~ — `POSTGRES_USER=apogee` and `POSTGRES_DB=apogee` in GCP Secret Manager were wrong. Correct values: `blocksecops`/`solidity_security`. Liveness/readiness probes (`pg_isready`) used these vars | Resolved (2026-03-11) |
| 22 | ~~stale-scan-recovery CronJob failing~~ — Two root causes: (1) No NetworkPolicy for `app.kubernetes.io/name: stale-scan-recovery` pods — default-deny blocked all egress. (2) Missing `JWT_SECRET_KEY`, `SESSION_SECRET`, `INTEGRATION_ENCRYPTION_KEY`, `INTERNAL_SERVICE_KEY` env vars — `Settings()` validation failed on import | Resolved (2026-03-11) |
| 23 | ~~celery-worker liveness probe timeout~~ — No NetworkPolicy for `app.kubernetes.io/name: celery-worker` pods. Could not reach Redis broker, causing `celery inspect ping` to timeout after 15s. Created 4 egress policies (dns, redis, postgresql, intelligence) | Resolved (2026-03-11) |
| 24 | ~~dedup-maintenance CronJob missing secret env vars~~ — Same import chain as stale-scan-recovery. Would fail on next scheduled run (Sunday 2AM). Added 4 required secret env vars preemptively | Resolved (2026-03-11) |

## High (March 11, 2026 — Smoke Test Findings)

| # | Finding | Status |
|---|---------|--------|
| 25 | ~~HPA `tool_execution_queue_length` custom metric errors~~ — No custom metrics API adapter deployed. Metric not exported by application. Removed dead config from HPA; CPU/memory scaling works correctly | Resolved (2026-03-11) |
| 26 | ~~dashboard `api-service-proxy` ExternalName pointing to `-local`~~ — Base uses `api-service.api-service-local.svc.cluster.local`. Created GCP overlay patch to point to `-prod` | Resolved (2026-03-11) |
| 27 | ~~PostgreSQL/Redis NetworkPolicies allow ingress from non-existent `scanner-prod` namespace~~ — Scanner Jobs run in `tool-integration-prod`, not a separate namespace. Removed `scanner-prod` entries from `allow-database-access.yaml` | Resolved (2026-03-11) |
| 28 | ~~PostgreSQL NetworkPolicy allows ingress from `contract-parser-prod`~~ — contract-parser has no `DATABASE_URL` (Rust service, Redis-only). Removed per least-privilege principle | Resolved (2026-03-11) |
| 29 | ~~Contract upload returns 500 "User quota not found"~~ — User auto-creation in auth middleware inserts into `users` table but not `user_quotas`. Fixed data (created missing quota record) and code (`middleware.py` now auto-creates quota on first login). Code fix requires version bump + deploy | Resolved (2026-03-11) |
| 30 | ~~`scanner-prod` namespace in database NetworkPolicies~~ — Scanner Jobs run in `tool-integration-prod`. Removed non-existent `scanner-prod` from PostgreSQL and Redis ingress policies | Resolved (2026-03-11) |

## Medium

| # | Finding | Status |
|---|---------|--------|
| 15 | ~~NAT logging set to `ERRORS_ONLY`~~ — Fixed: Changed to `ALL` in Terraform (`nat.tf`) | Resolved (2026-03-10) |
| 16 | 3 GKE auto-created firewall rules have logging disabled | Accepted — GKE-managed rules, cannot be modified without GKE overwriting changes |
| 17 | GKE Gateway firewall rule has logging disabled | Accepted — GKE Gateway-managed rule, same limitation as #16 |
| 18 | ~~Scanner node pool disk size 200 GB~~ — Fixed: Reduced to 50 GB (same as Finding #11) | Resolved (2026-03-10) |

## Critical (March 11, 2026 — Namespace Audit)

| # | Finding | Status |
|---|---------|--------|
| 31 | ~~GCP Secret Manager `apogee-gcp-api-service-url` pointed to `api-service-gcp` (non-existent namespace)~~ — Fixed: Updated to `http://api-service.api-service-prod.svc.cluster.local:8000`. ExternalSecrets force-synced for tool-integration-prod and orchestration-prod | Resolved (2026-03-11) |
| 32 | ~~`api-service-ingress` NetworkPolicy missing ingress from internal services~~ — Fixed: Added ingress rules for tool-integration-prod and orchestration-prod with AND selector logic. api-service v0.29.78 | Resolved (2026-03-11) |

## High (March 11, 2026 — Namespace Audit)

| # | Finding | Status |
|---|---------|--------|
| 33 | ~~tool-integration reported hardcoded version `0.1.0`~~ — Fixed: Dynamic version from SERVICE_VERSION env var / importlib.metadata. Dockerfile persists build arg as ENV. tool-integration v0.5.29 | Resolved (2026-03-11) |
| 34 | ~~12 scan result forwarding error handlers missing dead-letter enqueue~~ — Fixed: All 12 handlers now call `dead_letter_store.enqueue()`. tool-integration v0.5.29 | Resolved (2026-03-11) |
| 35 | ~~`/cluster/metrics` returned 403 due to missing RBAC~~ — Fixed: ClusterRole `tool-integration-cluster-reader` with nodes+pods list. GCP overlay patch for tool-integration-prod SA. tool-integration v0.5.29 | Resolved (2026-03-11) |
| 36 | ~~Legacy namespace `solidity-security` in defaults and examples~~ — Fixed: Replaced with `tool-integration-local` in kubernetes_job_manager.py, result_collector.py, and example Job manifests. tool-integration v0.5.29 | Resolved (2026-03-11) |
| 37 | ~~Orchestration service_name default `solidity-security-orchestration`~~ — Fixed: Changed to `blocksecops-orchestration`. orchestration v0.10.9 PR #100 | Resolved (2026-03-11) |
| 38 | ~~Orchestration hardcoded version `0.1.0` in config and `0.7.1` in FastAPI~~ — Fixed: Dynamic version from SERVICE_VERSION env var / importlib.metadata. Dockerfile persists build arg as ENV. orchestration v0.10.9 PR #100 | Resolved (2026-03-11) |
| 39 | ~~tool-integration production overlay SCANNER_REGISTRY legacy GCP project~~ — Fixed: Updated from `solidity-security` to current GCP project. tool-integration PR #137 | Resolved (2026-03-11) |

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
- 7 monitoring alert policies active (added CPU request utilization + node allocatable alerts)
- Logging: system + workloads + API server + scheduler + controller manager
- 86 NetworkPolicy resources across 14 namespaces (default-deny + allow)
