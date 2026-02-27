# BlockSecOps Infrastructure Agent Reference

> Comprehensive infrastructure knowledge base for the BlockSecOps platform.
> Use this document as context when asking infrastructure, Kubernetes, or GCP questions.
> Server: 128GB RAM local dev server. Target: GCP GKE with Spot VMs.

---

## Platform Overview

BlockSecOps is a blockchain/smart-contract security analysis platform with 12 microservices, a scanner job system, and supporting infrastructure (PostgreSQL, Redis, Vault, Traefik, ArgoCD, Harbor).

### Repositories (all under /home/pwner/Git/)

| Repo | Type | Port | Language |
|------|------|------|----------|
| blocksecops-api-service | Backend API (FastAPI) | 8000 | Python |
| blocksecops-orchestration | Celery workers + beat + API | 8003 (flower), 8004 (API) | Python |
| blocksecops-tool-integration | Scanner execution engine | 8005 | Python |
| blocksecops-data-service | Data service | 8001 | Python |
| blocksecops-intelligence-engine | ML/pattern engine | 8000 | Python |
| blocksecops-contract-parser | Contract parser (Rust) | 9000 | Rust |
| blocksecops-notification | Notifications + WebSocket | 8003 | Python |
| blocksecops-dashboard | Main UI | 3000 | TypeScript/Vite |
| blocksecops-admin-portal | Admin UI | 3000 | TypeScript |
| blocksecops-findings | Findings static site | 80 | nginx |
| blocksecops-analysis | Analysis static site | 80 | nginx |
| blocksecops-monitoring | Dependency monitor | 8000 | Python |

### Infrastructure Repos

| Repo | Purpose |
|------|---------|
| blocksecops-gcp-infrastructure | Local + GCP infra (Vault, Redis, PostgreSQL, Traefik, ArgoCD, Harbor, Monitoring stack) |
| blocksecops-gcp-infrastructure | GCP Terraform + GCP K8s overlays for all services |

---

## Kustomize Overlay Structure

All services follow: `k8s/base/` -> `k8s/overlays/{local,staging,production}/`

**Current environment: LOCAL** (overlays/local)
**Target environment: GCP** (blocksecops-gcp-infrastructure/k8s/overlays/gcp/)

### Local Overlay Namespaces

| Service | Namespace |
|---------|-----------|
| api-service | api-service-local |
| orchestration | orchestration-local |
| tool-integration | tool-integration-local |
| dashboard | dashboard-local |
| notification | notification-local |
| data-service | data-service-local |
| intelligence-engine | intelligence-engine-local |
| contract-parser | contract-parser-local |
| findings | findings-local |
| analysis | analysis-local |
| admin-portal | admin-portal-local |
| monitoring | monitoring-local |
| postgresql | postgresql-local |
| redis | redis-local |
| vault | vault-local |
| traefik | traefik-system |
| argocd | argocd-local |
| harbor | harbor-local |

---

## Service Resource Allocation (Base)

| Service | CPU Req/Limit | Memory Req/Limit | Replicas | HPA |
|---------|--------------|------------------|----------|-----|
| api-service | 200m/500m | 256Mi/512Mi | 3 | 3-20 (CPU 70%, Mem 80%) |
| orchestration-worker | 250m/500m | 512Mi/1Gi | 2 | 2-8 (CPU 75%, Mem 85%) |
| orchestration-beat | 100m/250m | 256Mi/512Mi | (sidecar) | - |
| orchestration-api | 100m/250m | 256Mi/512Mi | (sidecar) | - |
| orchestration-monitor | 50m/100m | 128Mi/256Mi | (sidecar) | - |
| tool-integration | 500m/1000m | 1Gi/2Gi | 2 | 2-10 (CPU 75%, Mem 85%) |
| data-service | 500m/1000m | 1Gi/2Gi | 2 | - |
| intelligence-engine | 500m/1000m | 1Gi/2Gi | 2 | - |
| contract-parser | 250m/500m | 512Mi/1Gi | 3 | - |
| notification | 100m/250m | 256Mi/512Mi | 2 | - |
| dashboard | 100m/500m | 128Mi/512Mi | 1 | - |
| admin-portal | 50m/200m | 64Mi/256Mi | 2 | - |
| findings | 100m/500m | 128Mi/512Mi | 2 | - |
| analysis | 100m/500m | 128Mi/512Mi | 2 | - |
| monitoring | 250m/500m | 256Mi/512Mi | 1 | - |

### Scanner Job Resources (CRITICAL - KNOWN ISSUE)

Current (too low - causes OOMKill):
```yaml
# blocksecops-orchestration/k8s/base/scanner-jobs/configmap.yaml
SCANNER_MEMORY_REQUEST: "256Mi"
SCANNER_MEMORY_LIMIT: "512Mi"
SCANNER_CPU_REQUEST: "100m"
SCANNER_CPU_LIMIT: "500m"
JOB_BACKOFF_LIMIT: "0"          # No retries!
JOB_ACTIVE_DEADLINE_SECONDS: "300"  # 5 min - too short for fuzzers
MAX_CONCURRENT_JOBS: "5"
```

Scanner actual memory requirements:
| Scanner | Min Memory | Recommended | Type |
|---------|-----------|-------------|------|
| slither 0.11.5 | 512Mi | 1-2Gi | Static analysis |
| aderyn 0.6.7 | 400Mi | 1Gi | Static analysis (Rust) |
| semgrep 1.141.0 | 512Mi | 2Gi | Pattern SAST (SEMGREP_MAX_MEMORY=2000) |
| echidna 2.2.7 | 1Gi | 2-3Gi | Property fuzzer (50k tests, 300s timeout) |
| medusa 0.2.0 | 1.5Gi | 3-4Gi | Parallel fuzzer (4 workers, 100k tests) |
| halmos 0.3.3 | 512Mi | 1-2Gi | Symbolic testing (Z3 solver) |
| soliditydefend 2.0.1 | 256Mi | 512Mi | Static analysis |
| solhint 6.0.2 | 128Mi | 256Mi | Linter |
| wake 4.21.0 | 512Mi | 1Gi | Static analysis |

### Production Overlay Issue (KNOWN BUG)

Production patches in `blocksecops-tool-integration/k8s/overlays/production/patches/resource-patch.yaml`
and `blocksecops-orchestration/k8s/overlays/production/patches/resource-patch.yaml` **REDUCE** resources
below base values. This is backwards and needs to be fixed before GCP launch.

---

## High Availability Status

### PodDisruptionBudgets

| Service | Local PDB | GCP PDB | Status |
|---------|-----------|---------|--------|
| api-service | None in base | minAvailable: 2 | GCP only |
| orchestration | **MISSING** | minAvailable: 2 | Needs local PDB |
| tool-integration | minAvailable: 1 | None defined | Needs GCP PDB |
| dashboard | None | minAvailable: 1 | GCP only |
| data-service | None | minAvailable: 1 | GCP only |
| monitoring | None | - | - |

### Pod Anti-Affinity

All backend services have `preferredDuringSchedulingIgnoredDuringExecution` anti-affinity
spreading pods across hostnames. GCP orchestration uses `requiredDuringScheduling` (hard anti-affinity).

### GCP Spot VM Compatibility

All critical services have tolerations for Spot VMs:
```yaml
tolerations:
- key: "cloud.google.com/gke-spot"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
- key: "cloud.google.com/gke-preemptible"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

Graceful shutdown configured:
- orchestration: `terminationGracePeriodSeconds: 60` + Celery drain preStop hook
- tool-integration: `terminationGracePeriodSeconds: 45` + 5s sleep preStop
- api-service: preStop connection draining

---

## GCP Target Architecture

### Terraform Modules (blocksecops-gcp-infrastructure/terraform/)

| Module | Purpose |
|--------|---------|
| gke | GKE cluster + node pools |
| networking | VPC, subnets, NAT, firewall |
| cloud-sql | Cloud SQL PostgreSQL (+ read replica) |
| memorystore | Redis (Memorystore) |
| secret-manager | GCP Secret Manager |
| artifact-registry | Container registry |
| workload-identity | Workload Identity for pods |
| cicd | Cloud Build pipelines |
| ml-storage | GCS buckets for ML models |
| load-balancer | GCLB |
| state-backend | Terraform state in GCS |

### GKE Node Pools

```
Defined in: blocksecops-gcp-infrastructure/terraform/modules/gke/variables.tf
```

| Pool | Machine | Min/Max | Spot | Disk | Labels | Taints |
|------|---------|---------|------|------|--------|--------|
| system | e2-standard-4 | 1/3 | No | 100GB pd-standard | node-type=system | None |
| application | e2-standard-4 | 2/6 | No | 100GB pd-standard | node-type=application | None |
| scanners-spot | e2-standard-8 | 0/20 | **Yes** | 200GB pd-ssd | node-type=scanner, spot=true | scanner=true:NoSchedule |
| scanners-fallback | e2-standard-4 | 1/5 | No | 200GB pd-ssd | node-type=scanner, spot=false | scanner=true:NoSchedule |
| stateful | e2-standard-4 | 1/3 | No | 100GB pd-ssd | node-type=stateful | None |

Node pool features: auto-repair, auto-upgrade, shielded instances (secure boot + integrity monitoring), Workload Identity.

### GCP Environments

| Environment | Description | Cluster Type |
|-------------|-------------|-------------|
| tier0-minimal | Minimal launch config | Standard |
| staging | Pre-production | Standard |
| production | Full production | Standard |

Region: `us-west1` (default)
K8s version: `1.29`, Release channel: `REGULAR`
Private nodes enabled, VPC-native networking.

Cost targets: ~$55-65/mo (tier0), ~$684/mo (staging), ~$2,078/mo (production)

### GCP Domains

- Local: `*.0xapogee.local`
- Staging: `*.staging.0xapogee.com`
- Production: `*.0xapogee.com`
- ArgoCD: `argocd.0xapogee.com`
- App: `app.0xapogee.com`

### GCP Service Overlays

Located at: `blocksecops-gcp-infrastructure/k8s/overlays/gcp/services/`

Services with GCP overlays:
- api-service (3 replicas, Cloud SQL proxy sidecar, HPA, PDB)
- orchestration (3 replicas, Cloud SQL proxy sidecar, HPA, PDB minAvailable:2)
- tool-integration (with externalsecret)
- dashboard (HPA, PDB)
- data-service (PDB)
- intelligence-engine
- contract-parser
- notification
- findings
- analysis

All GCP services use:
- Workload Identity service accounts
- ExternalSecrets from GCP Secret Manager
- Cloud SQL Proxy sidecar for database access
- nodeSelector: `node-type: application`

### GCP Networking

```
VPC CIDR: 10.0.0.0/16
GKE Subnet: 10.0.0.0/20
Pod CIDR: 10.1.0.0/16 (secondary range)
Service CIDR: 10.2.0.0/20 (secondary range)
Database Subnet: 10.0.16.0/24 (Cloud SQL private IP)
Redis Subnet: 10.0.17.0/24 (Memorystore)
Private Service Access: VPC peering for managed services
NAT: Cloud NAT (2 static IPs prod, 1 staging)
VPC Flow Logs: Enabled prod (50% sampling, 5sec aggregation)
```

### GCP Security

- Cloud Armor WAF (production only): XSS, SQLi, LFI, RFI, RCE, scanner detection, protocol attack
- Rate limiting: 100 req/min per IP, 300s ban
- Binary authorization (production)
- Shielded instances (secure boot + integrity monitoring)
- Private master endpoint (allow-listed IPs)
- Cloud NAT for all egress
- Workload Identity (no SA keys)
- TLS required for Cloud SQL, auth for Redis

### GCP Managed Services (replace local infra)

| Local | GCP Replacement |
|-------|----------------|
| PostgreSQL StatefulSet | Cloud SQL PostgreSQL 15 (HA, 4 vCPU/16GB prod) |
| Redis Deployment | Memorystore Redis 7.0 (5GB HA prod) |
| Vault | GCP Secret Manager + Workload Identity |
| Harbor (container registry) | Artifact Registry |
| Traefik | Google Cloud Load Balancer |
| Self-signed certs | Google-managed SSL certificates |
| Promtail + Loki | GCP Cloud Logging (native) |
| Prometheus | GCP Managed Prometheus |

### GCP CI/CD

- GitHub Actions with Workload Identity Federation (no SA keys)
- Trunk-based: all main branch pushes deploy to production
- Image tags: `sha-{commit_short}`, releases as `v*.*.*`
- ArgoCD auto-syncs from git after image tag update

### ArgoCD (GitOps)

Deployed in both local and GCP:
- Local: `argocd-local` namespace, v2.8.4
- GCP: ApplicationSet for auto-deploying services from git repos

---

## Monitoring Stack

### Location
```
blocksecops-gcp-infrastructure/k8s/overlays/local/monitoring/
```
Namespace: `monitoring-local`

### Components

| Component | Image | Status | Purpose |
|-----------|-------|--------|---------|
| Prometheus | prom/prometheus (latest) | Deployed | Metrics collection |
| Grafana | grafana/grafana:10.2.3 | **Deployed** (admin/admin) | Dashboards |
| Loki | grafana/loki:2.9.3 | Deployed | Log aggregation |
| Promtail | grafana/promtail:2.9.3 | Deployed (DaemonSet) | Log collection |

### Grafana Dashboards (Pre-provisioned)

6 dashboards auto-loaded via ConfigMaps:
1. **cluster** - Cluster overview metrics
2. **logs** - Log aggregation from Loki
3. **services** - Service-level metrics
4. **infra** - Infrastructure metrics
5. **scanners** - Scanner execution metrics
6. **metrics** - General platform metrics

Grafana access: port 3000, anonymous read enabled.
Datasources: Prometheus (metrics) + Loki (logs)

### Prometheus Scrape Targets

- Kubernetes pod auto-discovery (prometheus.io/scrape annotations)
- dependency-monitor:8000
- PostgreSQL exporter (postgresql-local namespace)
- Redis exporter (redis-local namespace)

### Alerting

**NO ALERTING RULES CONFIGURED** - AlertManager referenced but no rules defined.
This is a gap that needs to be addressed before GCP launch.

### Centralized Logging (Local)

Promtail DaemonSet scrapes:
- `/var/log` on each node
- `/var/lib/docker/containers` for container logs
- Ships to Loki at loki:3100

**NOTE:** Loki data stored in emptyDir (not persistent). Logs are lost on pod restart.

### Centralized Logging (GCP)

GCP has built-in Cloud Logging (Stackdriver) which automatically collects:
- Container stdout/stderr from all GKE pods
- System logs from nodes
- Audit logs

Cloud Logging is **free for GKE system logs** and charged for application logs.
You do NOT need to deploy Loki/Promtail on GCP - Cloud Logging handles this natively.

However, if you want the same Grafana dashboard experience on GCP, you can:
1. Use Cloud Logging API as a Grafana datasource (recommended)
2. Or deploy Loki + Promtail on GCP (adds operational overhead)

Recommendation: Use GCP Cloud Logging + Cloud Monitoring, with Grafana Cloud or
self-hosted Grafana pointed at Cloud Logging/Monitoring APIs.

---

## Database Infrastructure

### PostgreSQL

- **Local:** StatefulSet in `postgresql-local`, image: pgvector/pgvector:pg15
- **GCP:** Cloud SQL (via Terraform cloud-sql module), private IP, read replica support
- Connection: via ExternalSecret -> Vault (local) or GCP Secret Manager (GCP)
- Cloud SQL Proxy sidecar in all GCP deployments

### Redis

- **Local:** Deployment in `redis-local`, image: redis:7.2-alpine, with redis-exporter
- **GCP:** Memorystore (via Terraform memorystore module)
- Used for: Celery broker, caching, session storage, WebSocket state

### Vault

- **Local:** StatefulSet in `vault-local`, v1.15.0
- **GCP:** Not deployed (uses GCP Secret Manager + Workload Identity instead)
- ExternalSecrets operator bridges both: Vault (local) <-> Secret Manager (GCP)

---

## Scanner System Architecture

### How Scans Work

1. User triggers scan via API service
2. API service sends scan request to orchestration (Celery task)
3. Orchestration worker creates a K8s Job from the scanner job template
4. Job runs scanner container with the contract source mounted
5. Scanner outputs JSON results to /scan/output
6. Results posted back via callback URL to API service

### Scanner Job Template

```
File: blocksecops-orchestration/k8s/base/scanner-jobs/configmap.yaml
```

Key properties:
- `restartPolicy: Never` (correct for Jobs)
- `backoffLimit: 0` (NO RETRIES - should be 2+)
- `activeDeadlineSeconds: 300` (5 min - too short for fuzzers)
- Security: runAsNonRoot, drop ALL capabilities
- Volumes: scan-input (ConfigMap, readOnly), scan-output (emptyDir), tmp (emptyDir)

### Scanner Images

All in: `blocksecops-tool-integration/scanner-images/`

Each scanner has:
- `Dockerfile` - Multi-stage build with tools
- `*-scan` script - Entrypoint wrapper that runs tool and outputs JSON
- Callback mechanism: POST results to `$CALLBACK_URL` with `$SCAN_ID`

### Scanner Versions ConfigMap

Single source of truth: `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

Maps `SCANNER_IMAGE_*` env vars to image names. Contains 15 scanners with pinned versions.

### Tool Integration RBAC

The tool-integration service account has RBAC to:
- Create/delete/watch Jobs (scanner execution)
- Get/list/watch Pods and Pod logs
- Create/delete/patch ConfigMaps (scan input)
- Get/patch Deployments (scanner upgrades)

---

## Security Context (All Services)

Standard security posture across all pods:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
containers:
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true  # (false for nginx-based frontends)
    capabilities:
      drop: [ALL]
```

### Network Policies

Defined for: api-service, tool-integration, orchestration, notification, contract-parser, data-service, intelligence-engine

Pattern: Default deny-all, then explicit allow rules for service-to-service communication + DNS (53) + Redis (6379) + HTTPS (443).

---

## Ingress / Networking

### Local: Traefik

- Deployed in `traefik-system` namespace
- TLS via cert-manager (self-signed local certs)
- IngressRoute CRDs for each service
- CORS middleware configured for dashboard/api

### GCP: Google Cloud Load Balancer

- HTTP(S) load balancing via GKE Ingress
- SSL managed by GCP Certificate Manager

### AWS (Historical/Reference)

- Some base manifests reference AWS ALB annotations
- api-service ingress: `api.solidityops.com`, `api-staging.solidityops.com`

---

## CI/CD

### GitHub Actions Workflows

- **api-service:** test (unit, integration, E2E) -> quality (lint, type check) -> security (bandit, safety) -> build (Docker + Trivy scan)
- Coverage threshold: 75%
- Docker images pushed to GHCR

### ArgoCD (GitOps Deployment)

- Local: ArgoCD v2.8.4 in `argocd-local`
- GCP: ApplicationSet auto-syncs services from git repos
- Pattern: Push to git -> ArgoCD detects change -> applies K8s manifests

---

## Known Issues & Action Items

### Critical (Scanner Stability)

1. **Scanner job memory limit 512Mi is too low** - Fuzzers need 2-4Gi
   - File: `blocksecops-orchestration/k8s/base/scanner-jobs/configmap.yaml`
2. **No scanner job retries** - `JOB_BACKOFF_LIMIT: "0"`
   - File: same as above
3. **Job deadline too short** - 300s vs fuzzer internal 600s timeouts
   - File: same as above
4. **Production patches reduce resources** below base values
   - Files: `*/k8s/overlays/production/patches/resource-patch.yaml`

### High Priority (HA)

5. **Missing orchestration PDB in local** - GCP has it (minAvailable:2), local does not
   - Need: `blocksecops-orchestration/k8s/base/orchestration/pdb.yaml`
6. **Orchestration worker memory too low** - 1Gi limit for managing multiple concurrent scans

### Medium Priority (Observability)

7. **No Prometheus alerting rules** - AlertManager exists but unconfigured
8. **Loki data not persistent** - emptyDir means logs lost on restart
9. **No post-deployment smoke tests in CI/CD** - Manual only (docs/standards/smoke-test.md)
10. **No distributed tracing** - No OpenTelemetry / request correlation across services

---

## File Quick Reference

### Core K8s Manifests

```
blocksecops-api-service/k8s/base/                    # API service base manifests
blocksecops-orchestration/k8s/base/orchestration/     # Orchestration deployment (4 containers)
blocksecops-orchestration/k8s/base/scanner-jobs/      # Scanner job template + config
blocksecops-tool-integration/k8s/base/               # Tool integration + RBAC + PDB + HPA
blocksecops-monitoring/k8s/base/dependency-monitor/   # Dependency monitor + CronJobs
```

### Local Overlays (Current Cluster)

```
blocksecops-api-service/k8s/overlays/local/api-service/
blocksecops-orchestration/k8s/overlays/local/
blocksecops-tool-integration/k8s/overlays/local/
blocksecops-dashboard/k8s/overlays/local/
blocksecops-notification/k8s/overlays/local/
blocksecops-data-service/k8s/overlays/local/
blocksecops-intelligence-engine/k8s/overlays/local/
blocksecops-contract-parser/k8s/overlays/local/
blocksecops-findings/k8s/overlays/local/
blocksecops-analysis/k8s/overlays/local/
blocksecops-admin-portal/k8s/overlays/local/
blocksecops-monitoring/k8s/overlays/local/
```

### Infrastructure (Local)

```
blocksecops-gcp-infrastructure/k8s/overlays/local/postgresql/
blocksecops-gcp-infrastructure/k8s/overlays/local/redis/
blocksecops-gcp-infrastructure/k8s/overlays/local/vault/
blocksecops-gcp-infrastructure/k8s/overlays/local/monitoring/    # Prometheus + Grafana + Loki + Promtail
blocksecops-gcp-infrastructure/k8s/overlays/local/argocd/
```

### GCP Overlays (Target)

```
blocksecops-gcp-infrastructure/k8s/overlays/gcp/services/       # All service GCP manifests
blocksecops-gcp-infrastructure/k8s/overlays/gcp/argocd/         # ArgoCD + ApplicationSet
blocksecops-gcp-infrastructure/k8s/overlays/gcp/external-secrets/
blocksecops-gcp-infrastructure/terraform/                        # All Terraform modules
```

### Scanner Images

```
blocksecops-tool-integration/scanner-images/slither/
blocksecops-tool-integration/scanner-images/aderyn/
blocksecops-tool-integration/scanner-images/semgrep/
blocksecops-tool-integration/scanner-images/echidna/
blocksecops-tool-integration/scanner-images/medusa/
blocksecops-tool-integration/scanner-images/halmos/
blocksecops-tool-integration/scanner-images/soliditydefend/
blocksecops-tool-integration/scanner-images/solhint/
blocksecops-tool-integration/scanner-images/wake/
```

### Documentation

```
docs/standards/smoke-test.md                          # Comprehensive smoke test checklist + script
docs/                                                  # General platform docs
```
