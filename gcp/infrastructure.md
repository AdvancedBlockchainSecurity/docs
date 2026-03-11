# GCP Infrastructure

## Project

| Setting | Value |
|---------|-------|
| Project ID | `project-8a2657b9-d96c-4c0a-a69` |
| Region | `us-west1` |
| Owner | `dehvcurtis@protonmail.com` |
| Terraform state | `gs://apogee-gcp-terraform-state` |

## GKE Cluster

| Setting | Value |
|---------|-------|
| Name | `apogee-production-gke` |
| Version | `1.34.3-gke.1444000` |
| VPC | `apogee-production-vpc` |
| Subnet | `apogee-production-gke-subnet` (10.0.0.0/20) |
| Pod CIDR | `10.1.0.0/16` (managed by GKE) |
| Master CIDR | `172.16.0.0/28` |
| Master endpoint | `34.168.74.79` (public), `172.16.0.2` (private) |
| Master authorized networks | `136.60.244.81/32` (admin-primary) |
| Private nodes | Yes (no external IPs on nodes) |
| Release channel | Regular |

## Artifact Registry

| Setting | Value |
|---------|-------|
| Repository | `apogee` |
| Location | `us-west1` |
| Format | Docker |
| Full path | `us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee` |
| Size | ~8 GB |
| Auth | GKE nodes pull via Workload Identity (no imagePullSecrets) |

## Storage Buckets

| Bucket | Purpose | Location |
|--------|---------|----------|
| `apogee-gcp-terraform-state` | Terraform remote state | US-WEST1 |
| `apogee-production-ml-models` | ML model artifacts | US-WEST1 |

Both buckets have public access prevention enforced and uniform bucket-level access enabled.

## Persistent Disks

| Disk | Size | Type | Used By |
|------|------|------|---------|
| Node boot disks (x2) | 100 GB | pd-ssd | Default node pool |
| PostgreSQL PVC | 10 GB | pd-balanced | `postgresql-data-postgresql-0` |
| Redis PVC | 1 GB | pd-ssd (premium-rwo) | `redis-data-redis-0` |

## Secret Manager

All secrets use the `apogee-gcp-` prefix. Terraform auto-generates 3 secrets; the rest are populated via `scripts/populate-secrets.sh`.

| Secret | Source |
|--------|--------|
| `apogee-gcp-jwt-secret` | Terraform (auto-generated) |
| `apogee-gcp-session-secret` | Terraform (auto-generated) |
| `apogee-gcp-encryption-key` | Terraform (auto-generated) |
| `apogee-gcp-database-url` | Manual (populate-secrets.sh) |
| `apogee-gcp-redis-url` | Manual |
| `apogee-gcp-postgres-db` | Terraform (corrected to `solidity_security`, 2026-03-11) |
| `apogee-gcp-postgres-user` | Terraform (corrected to `blocksecops`, 2026-03-11) |
| `apogee-gcp-postgres-password` | Terraform |
| `apogee-gcp-redis-password` | Terraform |
| `apogee-gcp-stripe-api-key` | Manual |
| `apogee-gcp-stripe-webhook-secret` | Manual |
| `apogee-gcp-anthropic-api-key` | Manual |
| `apogee-gcp-supabase-url` | Manual |
| `apogee-gcp-supabase-key` | Manual |
| `apogee-gcp-internal-service-key` | Manual |
| `apogee-gcp-internal-service-token` | Terraform |
| `apogee-gcp-integration-encryption-key` | Manual |
| `apogee-gcp-openai-api-key` | Manual |
| `apogee-gcp-smtp-host` | Manual |
| `apogee-gcp-smtp-password` | Manual |
| `apogee-gcp-api-service-url` | Manual |
| `apogee-gcp-database-url-sync` | Terraform |
| `admin-portal-api-service-url` | Manual |
| `admin-portal-supabase-service-role-key` | Manual |

Secrets are synced to K8s via External Secrets Operator (ESO) with GCP Secret Manager as the `ClusterSecretStore` backend.

## Load Balancing

| Component | Value |
|-----------|-------|
| Type | GKE Gateway API (external managed) |
| External IP | `34.149.16.104` (global static) |
| SSL | Google-managed certificate (via Gateway) |
| DNS | `app.0xapogee.com` → Cloudflare → `34.149.16.104` |
| Cloud Armor | `apogee-production-waf-policy` (attached to all 4 backends via GCPBackendPolicy) |
| SSL Policy | `apogee-production-ssl-policy` (MODERN profile, TLS 1.2+) |

Traffic flow: `Client → Cloudflare → GCP LB (34.149.16.104) → GKE Gateway → Service pods`

## Cloud KMS

| Setting | Value |
|---------|-------|
| Key ring | `apogee-production-gke-etcd` |
| Key | `apogee-production-gke-etcd-key` |
| Purpose | etcd encryption at rest (CMEK) |
| Rotation | 90 days (automatic) |
| Algorithm | Google Symmetric Encryption |

## Cloud NAT

| Setting | Value |
|---------|-------|
| Router | `apogee-production-router` |
| NAT | `apogee-production-nat` |
| IP allocation | Auto (currently `136.109.182.120`) |
| Dynamic port allocation | Enabled |
| Min ports per VM | 64 |
| Logging | All (translations + errors) |

## Enabled APIs

Core APIs required by the platform (28 total, unnecessary APIs disabled):

- `container.googleapis.com` — GKE
- `compute.googleapis.com` — Compute Engine, networking
- `artifactregistry.googleapis.com` — Container images
- `secretmanager.googleapis.com` — Secrets
- `cloudkms.googleapis.com` — etcd encryption
- `containerscanning.googleapis.com` — Vulnerability scanning
- `containeranalysis.googleapis.com` — Image analysis
- `certificatemanager.googleapis.com` — TLS certificates
- `iam.googleapis.com` / `iamcredentials.googleapis.com` — IAM
- `cloudresourcemanager.googleapis.com` — Resource management
- `servicenetworking.googleapis.com` — Service networking
- `monitoring.googleapis.com` — Cloud Monitoring
- `logging.googleapis.com` — Cloud Logging
- `billingbudgets.googleapis.com` — Budget alerts
- `gkebackup.googleapis.com` — GKE backup
- `dns.googleapis.com` — Cloud DNS
- `storage.googleapis.com` — Cloud Storage
- `pubsub.googleapis.com` — Pub/Sub (GKE dependency)

Disabled APIs: BigQuery (7), Cloud SQL (2), Memorystore Redis, Datastore, Deployment Manager, Dataform, Dataplex, Analytics Hub

## Terraform

State is in `gs://apogee-gcp-terraform-state`. Modules:

```
terraform/
├── environments/gcp/
│   ├── main.tf          # Root: APIs, secrets, monitoring alerts, ESO SA
│   ├── variables.tf
│   └── backend.tfvars
└── modules/
    ├── gke/
    │   ├── main.tf       # SA, KMS, IAM
    │   ├── cluster.tf    # GKE cluster config
    │   └── node_pools.tf # Node pool definitions
    └── networking/
        ├── main.tf       # VPC, subnets, router, NAT
        └── firewall.tf   # Firewall rules
```
