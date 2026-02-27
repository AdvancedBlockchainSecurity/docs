# GCP Deployment Drift Report

**Date:** February 27, 2026
**Purpose:** Compare local cluster (ground truth) vs GCP infrastructure repo vs admin portal cost estimator to identify drift and align the GCP deployment plan.

---

## Executive Summary

There are three major sources of drift:

1. **The GCP infrastructure repo over-provisions** — It deploys Cloud SQL (~$80/mo), Memorystore Redis (~$52/mo), Secret Manager, ML storage bucket, and 3 node pools. The local cluster runs PostgreSQL and Redis as simple pods. Total unnecessary spend: ~$130-150/mo.

2. **Name mismatches everywhere** — The K8s GCP overlays reference `blocksecops-gcp-*` but terraform creates `blocksecops-staging-*`. Cloud SQL proxy sidecars, ExternalSecrets, bucket references, Artifact Registry paths, and the load balancer IP all have wrong names. Nothing would actually connect.

3. **The admin portal cost estimator is outdated** — It was built ~1 month ago and doesn't reflect the current architecture (OpenClaw/Ollama, celery-worker, contract-parser, prometheus-adapter, HPA custom metrics). The minimal tier is the closest match but still includes Secret Manager which isn't needed for alpha.

---

## Side-by-Side Comparison

### Application Services

| Service | Local Cluster | GCP Repo Overlay | Cost Estimator | Notes |
|---------|--------------|-----------------|----------------|-------|
| api-service | 1 pod | Yes + Cloud SQL proxy sidecar | Included | GCP adds unnecessary sidecar |
| celery-worker | 1 pod | Not present | Not present | **Missing from both GCP sources** |
| dashboard | 1 pod | Yes | Included | OK |
| admin-portal | 1 pod | Yes | Not present | **Missing from cost estimator** |
| data-service | 1 pod + HPA (1-3) | Yes + Cloud SQL proxy sidecar | Included | GCP adds unnecessary sidecar |
| intelligence-engine | 1 pod | Yes + Cloud SQL proxy sidecar | Included | GCP adds unnecessary sidecar |
| orchestration | 1 pod (4 containers) | Yes + Cloud SQL proxy sidecar | Included | GCP adds unnecessary sidecar |
| notification | 1 pod | Yes | Included | OK |
| tool-integration | 2 pods + HPA (2-10) | Yes | Included | OK |
| contract-parser | 1 pod | Yes | Not present | **Missing from cost estimator** |
| analysis (frontend) | Not deployed | Yes | Not present | GCP overlay exists but not running locally |
| findings (frontend) | Not deployed | Yes | Not present | GCP overlay exists but not running locally |
| OpenClaw (ollama + gateway) | 3 pods + HPA | Not present | Not present | **Missing from both GCP sources** |

### Infrastructure Services

| Service | Local Cluster | GCP Repo (Terraform) | Cost Estimator | Notes |
|---------|--------------|---------------------|----------------|-------|
| **PostgreSQL** | StatefulSet (1 pod, 5Gi PVC) | Cloud SQL db-custom-2-8192 (~$80/mo) | Minimal: self-hosted, Medium+: Cloud SQL | **Cloud SQL not needed for alpha** |
| **Redis** | Deployment (1 pod) | Memorystore 2GB BASIC (~$52/mo) | Minimal: self-hosted, Medium+: Memorystore | **Memorystore not needed for alpha** |
| postgres-exporter | 1 pod | Not present | Not present | Needed for monitoring |
| redis-exporter | 1 pod | Not present | Not present | Needed for monitoring |

### Ingress / Networking

| Service | Local Cluster | GCP Repo (Terraform) | Cost Estimator | Notes |
|---------|--------------|---------------------|----------------|-------|
| **Traefik** | NodePort (80/443) | Not in terraform (GKE Ingress used instead) | Not mentioned | GCP uses GKE Ingress, not Traefik |
| cert-manager | 3 pods (local CA) | Not in terraform | Not mentioned | GCP uses Google-managed SSL cert |
| Cloud NAT | N/A | 1 NAT IP (~$25/mo) | Yes (~$22/mo) | Required for private GKE nodes |
| Global LB | N/A | Static IP + Cloud Armor (~$18/mo) | Yes | Required for public access |
| VPC + Subnets | N/A | 3 subnets (GKE + DB + Redis) | Not detailed | Only GKE subnet needed if no managed DB/Redis |

### Security / Secrets

| Service | Local Cluster | GCP Repo (Terraform) | Cost Estimator | Notes |
|---------|--------------|---------------------|----------------|-------|
| **Vault** | StatefulSet (1 pod, 1Gi PVC) | Not in terraform | Not mentioned | **Keep self-hosted or replace with GCP Secret Manager** |
| External Secrets Operator | 2 pods | In K8s overlay (ClusterSecretStore) | Not mentioned | Connects to Secret Manager (but names mismatch) |
| Secret Manager | N/A | 5+ secrets (~$1/mo) | Yes (~$1/mo) | Could replace Vault for alpha |

### Monitoring

| Service | Local Cluster | GCP Repo (Terraform) | Cost Estimator | Notes |
|---------|--------------|---------------------|----------------|-------|
| **Prometheus** | 1 pod | Not in terraform (uses GKE Managed Prometheus) | Not mentioned | **GCP has free managed alternative** |
| **prometheus-adapter** | 1 pod | Not present | Not mentioned | Needed for HPA custom metrics |
| **Grafana** | Not deployed (scaled to 0) | Not present | Not mentioned | **GCP Cloud Monitoring replaces this** |
| Alertmanager | Not deployed | Not present | Not mentioned | Can use GCP Cloud Alerting |

### Registry

| Service | Local Cluster | GCP Repo (Terraform) | Cost Estimator | Notes |
|---------|--------------|---------------------|----------------|-------|
| **Harbor** | 7 pods, 4 PVCs (~24Gi) | Not in terraform | Not mentioned | **Artifact Registry replaces this** |
| Artifact Registry | N/A | 1 Docker repo (~$1/mo) | Yes (~$0.25/mo) | Already in terraform, correct |

### Other

| Service | Local Cluster | GCP Repo | Cost Estimator | Notes |
|---------|--------------|---------|----------------|-------|
| CronJob: deduplication | Weekly (Sun 2am) | Yes (in api-service overlay) | Not mentioned | OK |
| ML Storage (GCS) | N/A | GCS bucket (~$2/mo) | Not mentioned | Defer unless ML features active |
| Workload Identity | N/A | Module exists but NOT called | Not mentioned | Needed if using Secret Manager |
| CI/CD (GitHub Actions WIF) | N/A | Module exists but NOT called | Not mentioned | Defer to post-alpha |

---

## Critical Name Mismatches in GCP Repo

Every K8s GCP overlay references the wrong names:

| What | K8s Overlay Uses | Terraform Creates | Status |
|------|-----------------|-------------------|--------|
| Cloud SQL instance | `blocksecops-gcp-postgresql` | `blocksecops-staging-postgresql-<hex>` | Broken |
| Redis connection | `blocksecops-gcp-redis-url` | `blocksecops-staging-redis-connection` | Broken |
| JWT secret | `blocksecops-gcp-jwt-secret` | `blocksecops-staging-jwt-secret` | Broken |
| LB static IP | `blocksecops-gcp-ip` | `blocksecops-staging-lb-ip` | Broken |
| Artifact Registry | `blocksecops/<service>` | `blocksecops-staging-docker/<service>` | Broken |
| SSL cert domain | `app.0xApogee.com` (ingress) | `app.0xapogee.com` (tfvars) | Broken |
| GCP project ref | `blocksecops-gcp` (ESO) | `project-8a2657b9-d96c-4c0a-a69` | Broken |

**None of the GCP K8s overlays would work if deployed as-is.**

---

## Cost Comparison

| Component | Local (compute) | GCP Repo (current main.tf) | Estimator: Minimal | Estimator: Medium | Estimator: Large |
|-----------|----------------|---------------------------|-------------------|------------------|-----------------|
| GKE Cluster | N/A | $74 (Standard) | $73 (Autopilot) | $73 (Standard) | $73 |
| Compute Nodes | Server hardware | $179 (2 pools min) | Pay-per-pod | $196 (4 pools) | $587 (4 pools) |
| PostgreSQL | Self-hosted ($0) | $80 (Cloud SQL) | $0 (self-hosted) | $14 (db-f1-micro) | $307 (HA + replica) |
| Redis | Self-hosted ($0) | $52 (Memorystore) | $0 (self-hosted) | $5 (1GB BASIC) | $45 (5GB HA) |
| Networking | $0 | $43 (NAT+LB+Armor) | $29 (NAT+IP) | $54 (NAT+LB+IP) | $79 (NAT+LB+Armor+IPs) |
| Registry | Harbor ($0) | $1 (AR) | $0.25 | $0.25 | $0.25 |
| Secrets | Vault ($0) | $1 (SM) | $1 | $1 | $1 |
| ML Storage | N/A | $2 (GCS) | $0 | $0 | $0 |
| **Total (fixed)** | **$0** | **~$432/mo** | **~$103/mo** | **~$343/mo** | **~$1,098/mo** |
| **+ Scanner spot** | N/A | Variable | Variable | Variable | Variable |

---

## Google Services That Can Replace Self-Hosted

### Recommended Replacements (saves compute + operational overhead)

| Self-Hosted | Google Replacement | Monthly Cost | Benefit |
|-------------|-------------------|-------------|---------|
| **Harbor** (7 pods, 24Gi PVC) | **Artifact Registry** | ~$1/mo | Saves ~1GB RAM, 24Gi disk, 7 pods of management overhead |
| **Vault** (1 pod, 1Gi PVC) | **Secret Manager** | ~$1/mo | No unseal process, no backup needed, IAM-native. Note: requires rewriting ExternalSecret configs |
| **Prometheus + Grafana** | **GKE Managed Prometheus + Cloud Monitoring** | Free (included in GKE) | No pods to manage, built-in dashboards, alerting. Note: prometheus-adapter still needed for HPA custom metrics |

### Keep Self-Hosted (cheaper than Google managed)

| Self-Hosted | Google Alternative | Why Keep Self-Hosted |
|-------------|-------------------|---------------------|
| **PostgreSQL** (196Mi RAM) | Cloud SQL ($80/mo minimum) | Single-digit GB database, no HA needed for alpha, saves $80/mo |
| **Redis** (tiny footprint) | Memorystore ($52/mo for 2GB) | Barely uses memory, saves $52/mo |

### ArgoCD Replacement: Google Cloud Deploy + Config Sync

| Option | What It Does | Cost | Fit |
|--------|-------------|------|-----|
| **Config Sync** (recommended) | GitOps for K8s — watches a Git repo branch and auto-syncs K8s manifests to the cluster | Free (included with GKE) | Direct ArgoCD replacement. Watches Git, applies kustomize overlays, drift detection. Works with GitHub Actions as the CI layer. |
| **Cloud Deploy** | CD pipeline for GKE — manages progressive rollouts (canary, blue-green) | Free tier: 1 delivery pipeline + 1 target | More than ArgoCD — adds managed rollout strategies. Good for production but heavier setup. |
| **Fleet** | Multi-cluster management with Config Sync across fleets | Free | If you plan multiple clusters later (staging + prod). |

**Recommendation:** **Config Sync** is the closest ArgoCD equivalent and it's free with GKE. GitHub Actions builds/pushes images and updates the kustomization `newTag`, then Config Sync detects the git change and applies it to the cluster. This is exactly the GitOps pattern you described.

Setup:
```bash
# Enable Config Sync on GKE cluster
gcloud container fleet config-management apply \
  --membership=blocksecops-staging-gke \
  --config=config-sync.yaml
```

---

## Recommended Alpha Architecture

Based on the local cluster (ground truth) and the goal of minimal GCP spend:

### Terraform Resources (~15)

| Module | Resources | Est. Cost/mo |
|--------|-----------|-------------|
| networking | VPC, 1 GKE subnet (no DB/Redis subnets), NAT, firewall rules | ~$25 |
| gke | 1 Standard cluster + 1 node pool (e2-standard-4, 1-3 nodes) | ~$170 |
| artifact-registry | Docker repo + GKE reader IAM | ~$1 |
| load-balancer | Global static IP, managed SSL cert, Cloud Armor | ~$18 |
| **Total** | **~15 resources** | **~$215/mo** |

### In-Cluster Services (same as local)

| Service | Source |
|---------|--------|
| PostgreSQL | Existing StatefulSet from local overlay |
| Redis | Existing Deployment from local overlay |
| All 10 application services | Existing Deployments, same images pushed to Artifact Registry |
| OpenClaw (ollama + gateway) | If needed for alpha |
| prometheus-adapter | For HPA custom metrics |

### Google Managed Services (replace self-hosted)

| Service | Replaces | Cost |
|---------|----------|------|
| Artifact Registry | Harbor | ~$1/mo |
| Secret Manager | Vault | ~$1/mo |
| GKE Managed Prometheus | Prometheus pod | Free |
| Cloud Monitoring | Grafana | Free |
| Config Sync | ArgoCD (future) | Free |

### Not Needed for Alpha

| Service | Why Not |
|---------|---------|
| Cloud SQL | Self-hosted PostgreSQL is sufficient |
| Memorystore | Self-hosted Redis is sufficient |
| ML Storage bucket | No ML features active |
| Workload Identity | No managed services need pod-level IAM |
| CI/CD WIF | Manual deploys for alpha, GitHub Actions later |
| VPC Flow Logs | Not needed until production |

### Estimated Alpha Monthly Cost: **~$215-280/mo**

(Depends on node autoscaling behavior — 1 node at rest, up to 3 under load)

---

## Action Items

1. **Rewrite `main.tf`** to 4 modules only (Task #194 — already planned)
2. **Fix all name mismatches** in K8s GCP overlays — standardize on `blocksecops-alpha-*` or whatever prefix terraform uses
3. **Remove Cloud SQL proxy sidecars** from all GCP deployment overlays
4. **Update cost estimator** in admin portal to reflect current architecture (add celery-worker, contract-parser, admin-portal, OpenClaw; remove Cloud SQL/Memorystore from minimal tier)
5. **Create GCP kustomize overlays** that mirror local overlays but swap Harbor → Artifact Registry image paths
6. **Set domain** to `app.0xApogee.com` consistently in terraform + K8s ingress + SSL cert
7. **Enable Config Sync** on GKE cluster for GitOps (post-alpha, after GitHub Actions CI)

---

## Files Referenced

- Local cluster: `kubectl` commands against live cluster
- GCP repo: `/home/pwner/Git/blocksecops-gcp-infrastructure/terraform/` and `k8s/overlays/gcp/`
- Cost estimator: `/home/pwner/Git/blocksecops-admin-portal/src/pages/AdminGcpCostEstimator.tsx`
- Alpha plan: `/home/pwner/Git/blocksecops-gcp-infrastructure/docs/ALPHA-DEPLOYMENT-PLAN.md`
