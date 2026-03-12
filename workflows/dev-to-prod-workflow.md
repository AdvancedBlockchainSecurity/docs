# Development to Production Workflow

**Version:** 1.0.0
**Last Updated:** March 1, 2026

## Overview

This document provides visual workflows and decision guidance for the Apogee platform development-to-production lifecycle. The same code, same Kustomize base manifests, and same deployment patterns are used in both environments — only the overlay changes.

---

## 1. End-to-End Pipeline

```
Developer                Local Cluster              GitHub                CI (Actions)           GCP Cluster
   │                       (kubeadm)                   │                      │                   (GKE)
   │                          │                        │                      │                      │
   │──code changes───────────▶│                        │                      │                      │
   │──docker build + push────▶│ Harbor                 │                      │                      │
   │──kubectl apply -k───────▶│ local overlay          │                      │                      │
   │──test (curl, smoke)─────▶│                        │                      │                      │
   │                          │                        │                      │                      │
   │──git commit + push──────────────────────────────▶│                      │                      │
   │──gh pr create + merge───────────────────────────▶│                      │                      │
   │                          │                        │──webhook────────────▶│                      │
   │                          │                        │                      │──lint + test         │
   │                          │                        │                      │──docker build        │
   │                          │                        │                      │──push to Artifact Reg│
   │                          │                        │◄─update newTag───────│                      │
   │                          │                        │                      │                      │
   │                          │                        │─────Config Sync polls (continuous)─────────▶│
   │                          │                        │                      │        detect diff──▶│
   │                          │                        │                      │        apply overlay─│
   │                          │                        │                      │        rolling update│
   │                          │                        │                      │                      │
   │──verify production──────────────────────────────────────────────────────────────────────────▶│
   │  curl https://app.0xapogee.com/api/v1/health     │                      │                      │
```

---

## 2. Environment Comparison

| Aspect | Local (kubeadm) | Production (GKE) |
|--------|-----------------|-------------------|
| **Cluster** | kubeadm on Debian server | GKE on GCP |
| **Registry** | Harbor (`harbor.blocksecops.local`) | Artifact Registry (`us-west1-docker.pkg.dev`) |
| **Namespace suffix** | `-local` (e.g., `api-service-local`) | `-prod` (e.g., `api-service-prod`) |
| **Domain** | `app.0xapogee.com` | `app.0xapogee.com` |
| **Ingress** | Traefik (hostPort 80/443, self-signed TLS) | GCP HTTPS Load Balancer (managed cert) |
| **Secrets** | HashiCorp Vault + ESO | GCP Secret Manager + ESO |
| **Database** | PostgreSQL pod (in-cluster) | PostgreSQL pod (in-cluster, GKE) |
| **Redis** | Redis pod (in-cluster) | Redis pod (in-cluster, GKE with PVC) |
| **CD tool** | `kubectl apply -k` (manual) | Config Sync (GitOps, automatic) |
| **Kustomize overlay** | `k8s/overlays/local/` | `k8s/overlays/gcp/` |
| **Deploy trigger** | Developer runs build + apply | Git push triggers CI → Config Sync |

---

## 3. Kustomize Overlay Strategy

```
k8s/
├── base/                          ← Shared across ALL environments
│   ├── api-service/
│   │   ├── deployment.yaml        ← Container spec, env vars, probes
│   │   ├── service.yaml           ← ClusterIP service
│   │   └── kustomization.yaml
│   ├── dashboard/
│   ├── orchestration/
│   └── ...
│
├── overlays/
│   ├── local/                     ← kubeadm + Harbor
│   │   ├── api-service/
│   │   │   ├── kustomization.yaml ← namespace: api-service-local
│   │   │   │                        images: harbor.blocksecops.local/...
│   │   │   ├── configmap-patch.yaml
│   │   │   └── deployment-patch.yaml
│   │   ├── traefik/               ← Traefik IngressRoutes, TLS, HSTS
│   │   └── ...
│   │
│   └── gcp/                       ← GKE + Artifact Registry
│       ├── services/
│       │   ├── api-service/
│       │   │   ├── kustomization.yaml ← namespace: api-service-prod
│       │   │   │                        images: us-west1-docker.pkg.dev/...
│       │   │   ├── namespace.yaml
│       │   │   ├── deployment.yaml
│       │   │   ├── service.yaml
│       │   │   ├── externalsecret.yaml
│       │   │   ├── hpa.yaml
│       │   │   └── pdb.yaml
│       │   └── ...
│       ├── ingress/               ← GCP HTTPS Load Balancer (replaces Traefik)
│       ├── infrastructure/        ← Cloud SQL Proxy, Memorystore
│       ├── external-secrets/      ← ClusterSecretStore for GCP
│       ├── network-policies/
│       └── priority-classes/
```

### What Changes Between Overlays

| Resource | Local Overlay | GCP Overlay |
|----------|---------------|-------------|
| Image registry | `harbor.blocksecops.local/blocksecops/` | `us-west1-docker.pkg.dev/.../blocksecops/` |
| Namespace | `<service>-local` | `<service>-prod` |
| Ingress | Traefik IngressRoute CRDs | GKE Ingress + BackendConfig |
| Secrets | Vault `ClusterSecretStore` | GCP SM `ClusterSecretStore` |
| Database | In-cluster PostgreSQL pod | In-cluster PostgreSQL pod |
| Redis | In-cluster Redis pod | In-cluster Redis pod (with PVC) |
| HPA | Not used | Enabled (min 2, max 10) |
| PDB | Optional | Required |

### What Stays the Same (Base)

- Container image name (before registry prefix)
- Container ports, health probes
- Environment variable names
- RBAC roles
- NetworkPolicy rules (default-deny + allow lists)
- Security contexts (runAsNonRoot, drop ALL, readOnlyRootFilesystem)

---

## 4. Image Registry Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  LOCAL DEVELOPMENT                                               │
│                                                                  │
│  docker build → docker push ──► Harbor                           │
│                              harbor.blocksecops.local/           │
│                              blocksecops/<service>:<semver>      │
│                                                                  │
│  kubectl apply -k overlays/local/ ──► kubeadm pulls from Harbor  │
└─────────────────────────────────────────────────────────────────┘
                          │
                    git push to main
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  CI (GitHub Actions)                                             │
│                                                                  │
│  docker build → docker push ──► Artifact Registry                │
│                              us-west1-docker.pkg.dev/            │
│                              .../blocksecops/<service>:<semver>  │
│                                                                  │
│  update gcp kustomization newTag ──► commit to gcp-infra repo    │
└─────────────────────────────────────────────────────────────────┘
                          │
                    Config Sync detects
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  CD (Config Sync on GKE)                                         │
│                                                                  │
│  render kustomize overlays/gcp/ ──► apply to GKE                 │
│  GKE pulls image from Artifact Registry                          │
│  rolling update completes                                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Branch Strategy

```
main ─────────────────────────────────────────────────────► (production-ready)
  │                                     │
  └──feat/add-scan-filter──────────────►│  (merge via PR)
  │                                     │
  └──fix/cors-header───────────────────►│  (merge via PR)
  │                                     │
  └──hotfix/critical-auth-fix──────────►│  (merge via PR, urgent)
```

**Rules:**
- `main` is always production-ready
- All changes go through feature branches → PR → merge
- No direct commits to `main`
- Merging to `main` triggers CI → CD pipeline automatically
- Hotfix branches follow the same flow but with expedited review

See [Version Control Standards](../standards/version-control-standards.md) for branch naming and commit format.

---

## 6. Config Sync Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  GKE Cluster                                                     │
│                                                                  │
│  ┌──────────────────────────────┐                                │
│  │  config-management-system ns │                                │
│  │                              │                                │
│  │  Config Sync Agent           │                                │
│  │    │                         │                                │
│  │    ├── watches: GitHub repo  │                                │
│  │    │   branch: main          │                                │
│  │    │   dir: k8s/overlays/gcp │                                │
│  │    │                         │                                │
│  │    ├── renders kustomize     │                                │
│  │    │                         │                                │
│  │    ├── applies to cluster    │──────► api-service-prod         │
│  │    │                         │──────► dashboard-prod           │
│  │    │                         │──────► orchestration-prod       │
│  │    │                         │──────► ... (all services)      │
│  │    │                         │                                │
│  │    └── drift detection       │                                │
│  │        (auto-correct)        │                                │
│  └──────────────────────────────┘                                │
└─────────────────────────────────────────────────────────────────┘
```

### Config Sync vs ArgoCD

| Feature | Config Sync | ArgoCD |
|---------|-------------|--------|
| Cost | Free with GKE | Free (self-hosted) |
| Setup | `gcloud` CLI, minimal YAML | Helm install, Application CRDs |
| Kustomize | Native support | Native support |
| Drift detection | Built-in, auto-correct | Built-in, configurable |
| Multi-cluster | Fleet integration | ApplicationSet |
| UI | GCP Console | ArgoCD Dashboard |
| Auth | GCP IAM / Git token | Git SSH / HTTPS / SSO |

**Decision:** Config Sync chosen for GCP because it's free, native to GKE, and requires no additional infrastructure to manage.

---

## 7. Decision Tree: Deploy vs Rollback

```
Code change ready?
    │
    ├── YES → Tested locally?
    │           │
    │           ├── YES → Health checks pass?
    │           │           │
    │           │           ├── YES → Commit + PR + Merge
    │           │           │           │
    │           │           │           └── CI passes?
    │           │           │               │
    │           │           │               ├── YES → Config Sync deploys
    │           │           │               │           │
    │           │           │               │           └── Prod health OK?
    │           │           │               │               │
    │           │           │               │               ├── YES → Done
    │           │           │               │               │
    │           │           │               │               └── NO → Rollback
    │           │           │               │                   (git revert + push)
    │           │           │               │
    │           │           │               └── NO → Fix tests, push again
    │           │           │
    │           │           └── NO → Debug locally, fix, re-test
    │           │
    │           └── NO → Deploy locally first (Phase 1-2)
    │
    └── NO → Continue development
```

---

## 8. Environment Parity Principles

1. **Same base manifests** — `k8s/base/` is shared. Never duplicate base resources in overlays.
2. **Same container image** — The binary that runs locally is the same binary that runs in production (different registry, same content).
3. **Same security posture** — Security contexts, NetworkPolicies, and RBAC are identical in both environments.
4. **Same probes** — Health check paths and thresholds are defined in base, not overridden per environment.
5. **Environment-specific only in overlays** — Only registry, namespace, domain, ingress type, and managed services differ.
6. **Test locally, deploy to prod** — If it works on kubeadm with the local overlay, it will work on GKE with the GCP overlay (modulo managed service differences).

---

## Related Documentation

- [Dev-to-Prod Deployment Playbook](../playbooks/dev-to-prod-deployment.md) — Step-by-step procedures
- [Dev-to-Prod Pipeline](../pipelines/dev-to-prod-pipeline.md) — CI/CD pipeline specification
- [Local Deployment Workflow](./local-deployment-workflow.md) — Local deploy.sh details
- [ArgoCD GitOps Deployment](./argocd-gitops-deployment-workflow.md) — ArgoCD workflow (Config Sync replaces)
- [Build Workflow Standards](../standards/build-workflow.md) — Docker build standards
- [Kustomize Standards](../standards/kustomize-standards.md) — Overlay patterns and anti-patterns
- [GCP Deployment Drift Report](../reports/GCP-DEPLOYMENT-DRIFT-REPORT-2026-02-27.md) — Config Sync recommendation
