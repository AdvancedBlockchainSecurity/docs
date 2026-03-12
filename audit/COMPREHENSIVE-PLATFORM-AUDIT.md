# Comprehensive Platform Audit

**Version:** 10.0.0
**Created:** February 28, 2026
**Last Updated:** March 11, 2026
**Audit Date:** March 11, 2026
**Environment:** GCP Production (gke_project-8a2657b9-d96c-4c0a-a69_us-west1_apogee-production-gke)
**Status:** PASS (with advisories) — All critical/high findings remediated. Platform operational. Smoke test 17/17. Behavioral audit 10/10 PASS.
**Scope:** Full platform audit — GCP cluster infrastructure, services, secrets, networking, security, versioning, Cloud Armor, documentation, behavioral testing
**Last Code Changes:** tool-integration v0.5.29, api-service v0.29.78 (March 11, 2026)
**Behavioral Audit:** See [BEHAVIORAL-AUDIT-2026-03-11.md](BEHAVIORAL-AUDIT-2026-03-11.md) — 10/10 checks pass, 2 low-priority cleanup items

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| [x] | Passed |
| [!] | Failed — requires remediation |
| [~] | Advisory — documented limitation or pending item |

---

## Table of Contents

1. [Cluster Overview](#1-cluster-overview)
2. [Service Health and Versions](#2-service-health-and-versions)
3. [Secrets Management](#3-secrets-management)
4. [Security Compliance](#4-security-compliance)
5. [Network Security](#5-network-security)
6. [TLS and Certificates](#6-tls-and-certificates)
7. [Versioning and Kustomize Compliance](#7-versioning-and-kustomize-compliance)
8. [CronJobs and Scheduled Tasks](#8-cronjobs-and-scheduled-tasks)
9. [Database](#9-database)
10. [Monitoring and Observability](#10-monitoring-and-observability)
11. [Cloud Armor WAF](#11-cloud-armor-waf)
12. [Findings History](#12-findings-history)
13. [Remaining Advisories](#13-remaining-advisories)
14. [Remediations Applied](#14-remediations-applied)
15. [Sign-Off](#15-sign-off)

---

## 1. Cluster Overview

### Cluster

| Property | Value |
|----------|-------|
| Provider | Google Kubernetes Engine (GKE) |
| Cluster | apogee-production-gke |
| Region | us-west1 |
| Kubernetes | v1.34.3-gke.1444000 |
| OS | Container-Optimized OS from Google |
| Container Runtime | containerd 2.1.5 |
| CNI | GKE native (Dataplane V2 / Cilium) |
| Node Count | 2 |
| Node Pool | apogee-production |

### Nodes

| Node | CPU | CPU% | Memory | Mem% | Status |
|------|-----|------|--------|------|--------|
| ...-4z8h | 280m | 14% | 2658Mi | 44% | Ready [x] |
| ...-84mg | 709m | 36% | 3506Mi | 58% | Ready [x] |

### Helm Releases

| Release | Namespace | Chart | App Version | Status |
|---------|-----------|-------|-------------|--------|
| external-secrets | external-secrets-prod | external-secrets-2.1.0 | v2.1.0 | deployed [x] |

### Namespaces (23)

Platform namespaces: admin-portal-prod, api-service-prod, cert-manager, contract-parser-prod, dashboard-prod, data-service-prod, external-secrets-prod, ingress-prod, intelligence-engine-prod, notification-prod, orchestration-prod, postgresql-prod, redis-prod, tool-integration-prod

System namespaces: default, gke-managed-networking-dra-driver, gke-managed-system, gke-managed-volumepopulator, gmp-public, gmp-system, kube-node-lease, kube-public, kube-system

---

## 2. Service Health and Versions

### Deployments (16 platform + infrastructure — all at desired replica count)

| Namespace | Deployment | Ready | Image | Status |
|-----------|-----------|-------|-------|--------|
| api-service-prod | api-service | 1/1 | api-service:0.29.78 | [x] |
| api-service-prod | celery-worker | 1/1 | api-service:0.29.78 | [x] |
| admin-portal-prod | admin-portal | 1/1 | admin-portal:0.7.11 | [x] |
| cert-manager | cert-manager | 1/1 | cert-manager-controller:v1.17.1 | [x] |
| cert-manager | cert-manager-cainjector | 1/1 | cert-manager-cainjector:v1.17.1 | [x] |
| cert-manager | cert-manager-webhook | 1/1 | cert-manager-webhook:v1.17.1 | [x] |
| contract-parser-prod | contract-parser | 1/1 | contract-parser:0.2.2 | [x] |
| dashboard-prod | dashboard | 2/2 | dashboard:0.46.24 | [x] |
| data-service-prod | data-service | 1/1 | data-service:0.2.7 | [x] |
| external-secrets-prod | external-secrets | 1/1 | external-secrets:v2.1.0 | [x] |
| external-secrets-prod | external-secrets-cert-controller | 1/1 | external-secrets:v2.1.0 | [x] |
| external-secrets-prod | external-secrets-webhook | 1/1 | external-secrets:v2.1.0 | [x] |
| intelligence-engine-prod | intelligence-engine | 1/1 | intelligence-engine:0.3.7 | [x] |
| notification-prod | notification | 1/1 | notification:0.2.6 | [x] |
| orchestration-prod | orchestration | 1/1 | orchestration:0.10.8 | [x] |
| tool-integration-prod | tool-integration | 2/2 | tool-integration:0.5.29 | [x] |

### StatefulSets

| Namespace | StatefulSet | Ready | Status |
|-----------|-----------|-------|--------|
| postgresql-prod | postgresql | 1/1 | [x] |
| redis-prod | redis | 1/1 | [x] |
| gmp-system | alertmanager | 0/0 | [~] GKE-managed |

### Version Alignment (source -> kustomize -> cluster)

| Service | Source | Cluster Image | CronJob Image | Status |
|---------|--------|---------------|---------------|--------|
| api-service | 0.29.78 | 0.29.78 | 0.29.78 | [x] |
| dashboard | 0.46.24 | 0.46.24 | — | [x] |
| tool-integration | 0.5.29 | 0.5.29 | — | [x] |
| orchestration | 0.10.8 | 0.10.8 | — | [x] |
| data-service | 0.2.7 | 0.2.7 | — | [x] |
| contract-parser | 0.2.2 | 0.2.2 | — | [x] |
| notification | 0.2.6 | 0.2.6 | — | [x] |
| intelligence-engine | 0.3.7 | 0.3.7 | — | [x] |
| admin-portal | 0.7.11 | 0.7.11 | — | [x] |

All images pulled from `us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee/`. Zero version drift.

### HTTPS Endpoints

| Endpoint | Protocol | HTTP Status | Status |
|----------|----------|-------------|--------|
| `https://app.0xapogee.com/` | HTTP/2 | 200 | [x] |
| `https://app.0xapogee.com/api/v1/health/live` | HTTP/2 | 200 | [x] |
| `https://app.0xapogee.com/api/v1/health/ready` | HTTP/2 | 200 (database:true, encryption:true) | [x] |
| `wss://app.0xapogee.com/ws` | HTTP/1.1 | 101 Switching Protocols | [x] |
| Dashboard login (Supabase auth) | — | Functional | [x] |

### Internal Service Health (via kubectl exec)

| Service | Endpoint | Response | Status |
|---------|----------|----------|--------|
| tool-integration | :8005/health | `{"status":"healthy"}` | [x] |
| orchestration | :8004/health | `{"status":"healthy"}` | [x] |
| notification | :8003/health | `{"status":"healthy"}` | [x] |
| intelligence-engine | :80/health | `{"status":"healthy"}` | [x] |
| data-service | :80/health | `{"status":"healthy"}` | [x] |
| contract-parser | :80/health | `{"status":"OK"}` | [x] |

### HorizontalPodAutoscalers

| Namespace | HPA | Target | Min/Max | Current | Status |
|-----------|-----|--------|---------|---------|--------|
| tool-integration-prod | tool-integration-hpa | Deployment/tool-integration | 2/10 | 2 | [x] |

### PodDisruptionBudgets

| Namespace | PDB | MinAvailable | Status |
|-----------|-----|-------------|--------|
| orchestration-prod | orchestration | 1 | [x] |
| tool-integration-prod | tool-integration | 1 | [x] |

---

## 3. Secrets Management

### GCP Secret Manager + External Secrets Operator

| Check | Status |
|-------|--------|
| ESO controller running | [x] |
| ESO webhook running | [x] |
| ESO cert-controller running | [x] |
| ClusterSecretStore (gcp-secret-manager) | [x] Valid, ReadWrite |

### ExternalSecret Sync Status (9/9 synced)

| Namespace | ExternalSecret | Condition | Status |
|-----------|---------------|-----------|--------|
| api-service-prod | api-service-secret | SecretSynced | [x] |
| contract-parser-prod | contract-parser-secrets | SecretSynced | [x] |
| data-service-prod | data-service-secrets | SecretSynced | [x] |
| intelligence-engine-prod | intelligence-engine-secrets | SecretSynced | [x] |
| notification-prod | notification-secrets | SecretSynced | [x] |
| orchestration-prod | orchestration-secrets | SecretSynced | [x] |
| postgresql-prod | postgresql-credentials | SecretSynced | [x] |
| redis-prod | redis-secret | SecretSynced | [x] |
| tool-integration-prod | tool-integration-secrets | SecretSynced | [x] |

### BSO-SEC-004 Compliance (no secrets in ConfigMaps)

| Secret | Location | Status |
|--------|----------|--------|
| Database credentials | GCP Secret Manager -> ExternalSecret | [x] |
| Redis credentials | GCP Secret Manager -> ExternalSecret | [x] |
| Stripe keys | GCP Secret Manager -> ExternalSecret | [x] |
| INTERNAL_SERVICE_KEY | GCP Secret Manager -> ExternalSecret -> secretKeyRef | [x] |
| SUPABASE_ANON_KEY | Baked at dashboard build time (VITE_ build arg) | [x] |

---

## 4. Security Compliance

### Pod Security (all 10 platform containers)

| Check | Standard | Status |
|-------|----------|--------|
| `runAsNonRoot: true` | kubernetes-pod-lifecycle | [x] All 10 containers |
| `readOnlyRootFilesystem: true` | kubernetes-pod-lifecycle | [x] All 10 containers |
| `allowPrivilegeEscalation: false` | kubernetes-pod-lifecycle | [x] All 10 containers |
| `revisionHistoryLimit: 3` | kubernetes-pod-lifecycle | [x] All 10 platform deployments |
| `runAsUser: 1000` | kubernetes-pod-lifecycle | [x] All 10 containers |

### Security Context Detail

| Service | runAsNonRoot | runAsUser | readOnlyRoot | allowPrivEsc | revHist | Status |
|---------|-------------|-----------|--------------|-------------|---------|--------|
| api-service | true | 1000 | true | false | 3 | [x] |
| celery-worker | true | 1000 | true | false | 3 | [x] |
| admin-portal | true | 1000 | true | false | 3 | [x] |
| contract-parser | true | 1000 | true | false | 3 | [x] |
| dashboard | true | 1000 | true | false | 3 | [x] |
| data-service | true | 1000 | true | false | 3 | [x] |
| intelligence-engine | true | 1000 | true | false | 3 | [x] |
| notification | true | 1000 | true | false | 3 | [x] |
| orchestration | true | 1000 | true | false | 3 | [x] |
| tool-integration | true | 1000 | true | false | 3 | [x] |

### revisionHistoryLimit Compliance

| Category | Value | Count | Status |
|----------|-------|-------|--------|
| Platform services | 3 | 16 deployments | [x] |
| cert-manager | 10 | 3 deployments | [~] Upstream default |
| ESO (Helm-managed) | 10 | 3 deployments | [~] Helm default |

### Application Security

| Check | Standard | Status |
|-------|----------|--------|
| No secrets in ConfigMaps | BSO-SEC-004 | [x] |
| CORS headers explicit (no wildcards) | BSO-SEC-014 | [x] |
| All platform access via HTTPS | core-development-rules Rule 2 | [x] |
| HTTP -> HTTPS redirect via Gateway | ingress-networking | [x] |
| Supabase JWT auth configured | frontend-development | [x] |
| Build-time VITE_ vars baked correctly | frontend-build-env | [x] |
| Cloud Armor WAF active | GCP security | [x] |

### Build and Deployment Security

| Check | Standard | Status |
|-------|----------|--------|
| All images from GCP Artifact Registry (immutable tags) | docker-image-versioning | [x] |
| Kustomize base/overlay pattern | kustomize-standards | [x] |
| Version source-of-truth alignment | docker-image-versioning | [x] 0 drift |

---

## 5. Network Security

### NetworkPolicies (86 total across 14 namespaces)

| Namespace | Policy Count | Status |
|-----------|-------------|--------|
| api-service-prod | 28 | [x] |
| intelligence-engine-prod | 9 | [x] |
| data-service-prod | 7 | [x] |
| dashboard-prod | 6 | [x] |
| contract-parser-prod | 6 | [x] |
| notification-prod | 4 | [x] |
| external-secrets-prod | 4 | [x] |
| cert-manager | 4 | [x] |
| admin-portal-prod | 4 | [x] |
| tool-integration-prod | 3 | [x] |
| redis-prod | 3 | [x] |
| postgresql-prod | 3 | [x] |
| orchestration-prod | 3 | [x] |
| ingress-prod | 2 | [x] |

**GKE Dataplane V2 (Cilium):** NetworkPolicies are **enforced at runtime** in GCP, unlike the local Flannel cluster where they were documentation-only.

### Gateway (GKE L7 Global External Managed)

| Gateway | IP | Programmed | Status |
|---------|----|-----------|--------|
| apogee-gateway | 34.149.16.104 | True | [x] |

### HTTPRoutes

| Route | Hostnames | Purpose | Status |
|-------|-----------|---------|--------|
| apogee-routes | app.0xapogee.com | Dashboard + API + WebSocket | [x] |
| admin-routes | admin.0xapogee.com | Admin portal | [x] |
| http-redirect | — | HTTP -> HTTPS redirect | [x] |

### CDN / Edge

| Component | Provider | Status |
|-----------|----------|--------|
| DNS | Cloudflare | [x] |
| Edge proxy | Cloudflare | [x] |
| TLS termination | Cloudflare -> GKE Gateway (dual) | [x] |

---

## 6. TLS and Certificates

### Transport Layer Security

| Check | Value | Status |
|-------|-------|--------|
| External TLS | Cloudflare edge + GKE Gateway | [x] |
| HTTP/2 | Enabled | [x] |
| PostgreSQL SSL | Enabled (hostssl enforced) | [x] |
| Redis TLS | Enabled via cert-manager | [x] |

### Certificate Inventory (3 certificates — all valid)

| Namespace | Certificate | Ready | Not After | Status |
|-----------|------------|-------|-----------|--------|
| cert-manager | apogee-internal-ca | True | 2036-03-06 | [x] |
| postgresql-prod | postgresql-tls | True | 2027-03-09 | [x] |
| redis-prod | redis-tls | True | 2027-03-09 | [x] |

Nearest expiry: postgresql-tls and redis-tls (2027-03-09, ~1 year).

---

## 7. Versioning and Kustomize Compliance

### Image Registry

All 9 platform service images use `us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee/<service>:<semver>` with immutable tags.

### Kustomize Structure

All services follow `k8s/base/` + `k8s/overlays/gcp/` pattern.

### Version Tooling

| Tool | Purpose | Status |
|------|---------|--------|
| `sync-version.sh` | Sync kustomization newTag to source version | [x] Available |
| `check-version-drift.sh` | Platform-wide drift detection | [x] Available |
| Manual version bumps | Edit pyproject.toml/package.json + sync-version.sh | [x] Per standards |

---

## 8. CronJobs and Scheduled Tasks

| Namespace | CronJob | Schedule | Image | Image Match | Status |
|-----------|---------|----------|-------|-------------|--------|
| api-service-prod | deduplication-maintenance | Weekly Sun 2am | api-service:0.29.78 | [x] | [x] |
| api-service-prod | stale-scan-recovery | Every 15min | api-service:0.29.78 | [x] | [x] |

All CronJob image tags match their parent Deployment image tags.

---

## 9. Database

### PostgreSQL

| Setting | Value | Status |
|---------|-------|--------|
| Version | PostgreSQL 15.4 (pgvector) | [x] |
| Database | solidity_security | [x] |
| User | blocksecops | [x] |
| SSL | On (13 active SSL connections) | [x] |
| Storage | GCE Persistent Disk (standard-rwo) | [x] |
| Credentials | GCP Secret Manager -> ExternalSecret | [x] |
| Alembic Version | 080_fix_trigger_starter_rename_and_quota_values | [x] |

### Data Statistics

| Table | Count | Status |
|-------|-------|--------|
| Tables (public schema) | 92 | [x] |
| Users | 16 | [x] |
| Scans | 693 | [x] |
| Vulnerabilities | 18,913 | [x] |
| Contracts | 213 | [x] |
| Vulnerability Patterns | 415 | [x] |

### Data Quality

| Check | Result | Status |
|-------|--------|--------|
| Failed scans with NULL error_message | 0 | [x] |
| Stale scans (queued/running > 1hr) | 0 | [x] |
| create_user_quota trigger present | Yes (migration 080) | [x] |

---

## 10. Monitoring and Observability

| Component | Status |
|-----------|--------|
| GKE Managed Prometheus (gmp-system) | Running [x] |
| Alertmanager (gmp-system) | Scaled to 0 [~] |

---

## 11. Cloud Armor WAF

| Check | Status |
|-------|--------|
| Policy name | apogee-production-waf-policy [x] |
| Total rules | 12 [x] |

### WAF Rules

| Priority | Action | Description | Status |
|----------|--------|-------------|--------|
| 100 | allow | Cloudflare IPs (1/3) | [x] |
| 1000 | deny(403) | XSS protection (xss-v33-stable) | [x] |
| 1001 | deny(403) | SQL injection protection (sqli-v33-stable) | [x] |
| 1002 | deny(403) | Local file inclusion (lfi-v33-stable) | [x] |
| 1003 | deny(403) | Remote file inclusion (rfi-v33-stable) | [x] |
| 1004 | deny(403) | Remote code execution (rce-v33-stable) | [x] |
| 1005+ | deny(403) | Scanner detection, protocol attack, session fixation | [x] |

---

## 12. Findings History

### v5.0.0-v8.0.0 Findings (Local Cluster — March 4-7)

All 22 findings remediated on local cluster. See previous audit version for full history.

### v9.0.0 Findings (GCP Production — March 10-11)

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| AUD-023 | MEDIUM | 3 failed scans missing error_message | Backfilled with historical note (March 11) |
| AUD-024 | LOW | 39 stale ReplicaSets (threshold 20) | Cleaned up to 11 (March 11) |
| AUD-025 | LOW | Smoke test WebSocket path wrong (/ws/ vs /ws) | Fixed in smoke-test.md (March 11) |
| AUD-026 | INFO | 1 test account in database (testdev@blocksecops.com) | Deleted from GCP PostgreSQL (March 11) |
| AUD-027 | INFO | 4 unconfirmed Supabase auth accounts | Pending: manual cleanup in Supabase dashboard |
| AUD-028 | CRITICAL | GCP Secret Manager `apogee-gcp-api-service-url` pointed to non-existent `api-service-gcp` namespace — scan results silently lost | Fixed: Secret updated to `http://api-service.api-service-prod.svc.cluster.local:8000`, ExternalSecrets force-synced (March 11) |
| AUD-029 | CRITICAL | `api-service-ingress` NetworkPolicy missing ingress from tool-integration-prod and orchestration-prod — internal ClusterIP traffic blocked by Cilium | Fixed: Added ingress rules with namespaceSelector+podSelector AND logic. api-service v0.29.78 (March 11) |
| AUD-030 | HIGH | tool-integration reported version `0.1.0` — 3 hardcoded references instead of reading from source of truth | Fixed: Dynamic version via SERVICE_VERSION env var / importlib.metadata. tool-integration v0.5.29 (March 11) |
| AUD-031 | HIGH | 12 scan result forwarding error handlers log errors but never enqueue to dead-letter store — results silently lost | Fixed: All 12 handlers now call `dead_letter_store.enqueue()`. tool-integration v0.5.29 (March 11) |
| AUD-032 | MEDIUM | `/cluster/metrics` endpoint returned 403 — missing ClusterRole for nodes and pods list | Fixed: Added ClusterRole `tool-integration-cluster-reader` + GCP overlay patch. tool-integration v0.5.29 (March 11) |
| AUD-033 | LOW | Legacy default namespace `solidity-security` in kubernetes_job_manager.py, result_collector.py, and example Job manifests | Fixed: Replaced with `tool-integration-local`. tool-integration v0.5.29 (March 11) |

---

## 13. Remaining Advisories

### ADV-001: Unconfirmed Supabase Test Accounts (INFO)

4 test accounts exist in Supabase auth but not in the platform database:
- `scanner-test@0xapogee.com`
- `orgtest-verify@mail.com`
- `support-test-1770008399@blocksecops.com`
- `freetieraudit2026@gmail.com`

**Action:** Remove via Supabase dashboard.

### ADV-002: GKE Alertmanager Scaled to 0 (INFO)

GKE-managed alertmanager StatefulSet is at 0 replicas. Custom alerting rules are not configured.

**Action:** Configure alerting when monitoring requirements are defined.

### ADV-003: cert-manager and ESO revisionHistoryLimit at 10 (INFO)

Upstream defaults, not managed by platform Kustomize. Does not affect platform services.

**Action:** None required.

### ADV-004: GCS Backup CronJob Not Yet Configured (LOW)

PostgreSQL backup to GCS is pending. Current backups are manual (`pg_dump` via kubectl exec).

**Action:** Implement GCS-based automated backup CronJob.

---

## 14. Remediations Applied

### v9.0.0 Remediations (March 10-11)

1. **Database restored from local cluster** — Full dump/restore to GCP production (92 tables, 17 users, trigger, alembic tracking)
2. **Middleware defense-in-depth verified** — `ON CONFLICT DO NOTHING` correctly handles upsert, trigger handles fresh inserts
3. **api-service bumped to 0.29.76** — Middleware fix + quota auto-creation
4. **dashboard bumped to 0.46.24** — Sidebar reorder + collapsible sections
5. **SCHEMA.md updated** — Table count 92, trigger docs aligned to migration 080
6. **3 failed scans backfilled** — error_message set for historical failures
7. **39 stale ReplicaSets cleaned** — Reduced to 11 (under threshold)
8. **Smoke test path fixed** — WebSocket `/ws/` corrected to `/ws`
9. **Test account removed** — testdev@blocksecops.com deleted from GCP database
10. **Enterprise user configured** — jasonbrailowbizop@mail.com set to enterprise tier

### v9.1.0 Remediations (March 11 — Namespace Audit)

1. **GCP Secret Manager `apogee-gcp-api-service-url` corrected** — Was `api-service-gcp` (non-existent), now `http://api-service.api-service-prod.svc.cluster.local:8000`
2. **api-service NetworkPolicy updated** — Added ingress from tool-integration-prod and orchestration-prod (v0.29.78)
3. **tool-integration version source of truth** — Replaced 3 hardcoded `"0.1.0"` with dynamic resolution from env/metadata
4. **Dead-letter queue enabled** — All 12 forwarding error handlers now enqueue to dead-letter store
5. **RBAC ClusterRole added** — `tool-integration-cluster-reader` with nodes+pods list for `/cluster/metrics`
6. **Legacy namespace cleanup** — `solidity-security` replaced with `tool-integration-local` in defaults and examples
7. **Dockerfile SERVICE_VERSION** — Build arg persisted as ENV for runtime access
8. **tool-integration bumped to 0.5.29** — All fixes deployed to GCP production

### Pull Requests Merged (v9.0.0)

| Repo | PR | Description |
|------|----|-------------|
| docs | #371 | Smoke test remediation: backfill, WebSocket path, backup docs |
| TaskDocs-BlockSecOps | #237 | Smoke test remediation summary and GCP task updates |

### Pull Requests Merged (v9.1.0)

| Repo | PR | Description |
|------|----|-------------|
| tool-integration | [#136](https://github.com/AdvancedBlockchainSecurity/blocksecops-tool-integration/pull/136) | Namespace audit, dead-letter queue, RBAC, version fix (v0.5.29) |
| api-service | [#313](https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service/pull/313) | Internal service ingress NetworkPolicy (v0.29.78) |

---

## 15. Sign-Off

### Audit Statistics

| Metric | Value |
|--------|-------|
| Total checks performed | 100+ |
| Checks passed | 98 |
| Advisories (non-blocking) | 4 |
| Checks failed | 0 |
| Findings remediated (all time) | 33 |
| Namespaces audited | 23 |
| Platform deployments verified | 16 |
| Pods running | 55 |
| NetworkPolicies deployed | 86 (enforced by Cilium) |
| ExternalSecrets synced | 9/9 |
| ClusterSecretStore valid | 1/1 |
| Certificates valid | 3/3 |
| CronJobs aligned | 2/2 |
| Cloud Armor WAF rules | 12 |
| Smoke test checks passed | 17/17 |
| Services with version drift | 0 |

### Architecture

```
                      Client Browser
                           |
                     [Cloudflare CDN]
                      DNS + Edge TLS
                           |
                  [GKE Gateway (L7 Global)]
                   Cloud Armor WAF (12 rules)
                   34.149.16.104
                    /        |        \
             [Dashboard] [API Service] [Admin Portal]
              (0.46.24)   (0.29.78)    (0.7.11)
                              |
           +--------+---------+---------+---------+
           |        |         |         |         |
     [Orch]   [Tool-Int]  [Data-Svc] [Intel-Eng] [Notif]
    (0.10.8)  (0.5.29)   (0.2.7)    (0.3.7)    (0.2.6)
           |        |         |         |
     [Contract-Parser]       |         |
      (0.2.2)                |         |
                             |         |
                       [PostgreSQL]  [Redis]
                     (SSL, 92 tables) (TLS)
                             \        |
                      [GCP Secret Manager]
                       (ESO, 9 synced)
```

**Registry:** us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee/ (immutable tags)
**Secrets:** GCP Secret Manager + ESO (Helm-managed)
**TLS:** Cloudflare edge + GKE Gateway + cert-manager internal CA
**WAF:** Cloud Armor (xss, sqli, lfi, rfi, rce, scanner detection)
**NetworkPolicies:** 86 policies, enforced by GKE Dataplane V2 (Cilium)
**Build workflow:** Edit source -> sync-version.sh -> docker build -> docker push -> kubectl apply -k

---

**Audit Date:** March 11, 2026
**Version:** 9.1.0
**Previous:** v9.0.0 (PASS, GCP production) -> v9.1.0 (PASS, namespace audit remediation)
**Result:** PASS — 0 failed checks, 4 non-blocking advisories, smoke test 17/17, all services healthy
