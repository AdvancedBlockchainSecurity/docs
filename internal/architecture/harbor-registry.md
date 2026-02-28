# Harbor Container Registry Architecture

**Last Updated**: December 12, 2025
**Status**: Deployed (Local Environment)
**Version**: 2.11.2

---

## Overview

Harbor is an open-source container registry that provides policy and role-based access control, vulnerability scanning, and image signing. In Apogee, Harbor serves as the local container registry for development and will be the production registry for all service images.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Apogee Platform                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐   │
│  │   Developer     │     │    CI/CD        │     │   Kubernetes    │   │
│  │   Workstation   │     │   Pipeline      │     │   Cluster       │   │
│  └────────┬────────┘     └────────┬────────┘     └────────┬────────┘   │
│           │                       │                       │             │
│           │ docker push           │ docker push           │ docker pull │
│           │                       │                       │             │
│           ▼                       ▼                       ▼             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        Harbor Registry                          │   │
│  │  ┌───────────────────────────────────────────────────────────┐  │   │
│  │  │                     Traefik Ingress                       │  │   │
│  │  │                   harbor.local:443                        │  │   │
│  │  └─────────────────────────┬─────────────────────────────────┘  │   │
│  │                            │                                     │   │
│  │  ┌──────────────┐  ┌───────┴───────┐  ┌──────────────┐          │   │
│  │  │    Portal    │  │     Core      │  │   Registry   │          │   │
│  │  │   (Web UI)   │──│  (API/Auth)   │──│   (Storage)  │          │   │
│  │  └──────────────┘  └───────┬───────┘  └──────┬───────┘          │   │
│  │                            │                  │                  │   │
│  │  ┌──────────────┐  ┌───────┴───────┐  ┌──────┴───────┐          │   │
│  │  │  JobService  │  │  PostgreSQL   │  │    Redis     │          │   │
│  │  │  (GC/Scan)   │  │   (Harbor)    │  │   (Cache)    │          │   │
│  │  └──────────────┘  └───────────────┘  └──────────────┘          │   │
│  │                                                                  │   │
│  │  ┌──────────────┐                    ┌──────────────────────┐   │   │
│  │  │    Trivy     │                    │   Registry Storage   │   │   │
│  │  │  (Optional)  │                    │   (PVC: 10Gi)        │   │   │
│  │  └──────────────┘                    └──────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Components

### Core Components

| Component | Purpose | Port | Required |
|-----------|---------|------|----------|
| **harbor-core** | API server, authentication, authorization | 8080 | Yes |
| **harbor-portal** | Web UI | 8080 | Yes |
| **harbor-registry** | Docker distribution registry | 5000 | Yes |
| **harbor-jobservice** | Garbage collection, replication | 8080 | Yes |
| **harbor-database** | PostgreSQL for Harbor metadata | 5432 | Yes* |
| **harbor-redis** | Cache and session storage | 6379 | Yes* |

*Can use external shared PostgreSQL/Redis

### Optional Components

| Component | Purpose | Recommendation |
|-----------|---------|----------------|
| **harbor-trivy** | Vulnerability scanning | Enable for production |
| **harbor-notary** | Image signing (DCT) | Optional |
| **harbor-chartmuseum** | Helm chart repository | Optional |

---

## Local Development Configuration

### Resource Allocation (Minimal)

```yaml
# Local development - optimized for Minikube
harbor-core:
  replicas: 1
  resources:
    requests: { cpu: 50m, memory: 128Mi }
    limits: { cpu: 100m, memory: 256Mi }

harbor-portal:
  replicas: 1
  resources:
    requests: { cpu: 25m, memory: 64Mi }
    limits: { cpu: 50m, memory: 128Mi }

harbor-registry:
  replicas: 1
  resources:
    requests: { cpu: 50m, memory: 128Mi }
    limits: { cpu: 100m, memory: 256Mi }

harbor-jobservice:
  replicas: 1
  resources:
    requests: { cpu: 25m, memory: 64Mi }
    limits: { cpu: 50m, memory: 128Mi }

harbor-database:
  replicas: 1
  resources:
    requests: { cpu: 50m, memory: 128Mi }
    limits: { cpu: 100m, memory: 256Mi }

# Total: ~200m CPU, ~512Mi Memory
```

### Storage Configuration

| PVC | Local Size | Production Size |
|-----|------------|-----------------|
| registry-pvc | 20Gi | 100Gi+ |
| database-pvc | 2Gi | 10Gi |
| jobservice-pvc | 1Gi | 5Gi |

**Current Local Deployment Storage Usage:**
- Scanner images: ~4.3GB (15 scanner images)
- Service images: ~2GB (5 Python services)

---

## Network Architecture

### Traefik IngressRoute Configuration

```yaml
# Local development ingress
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: harbor
  namespace: harbor-local
spec:
  entryPoints:
    - websecure
  routes:
    # Web UI
    - match: Host(`harbor.local`) && !PathPrefix(`/api/`) && !PathPrefix(`/v2/`) && !PathPrefix(`/service/`)
      kind: Rule
      services:
        - name: harbor-portal
          port: 80
    # API and Registry
    - match: Host(`harbor.local`) && (PathPrefix(`/api/`) || PathPrefix(`/v2/`) || PathPrefix(`/service/`) || PathPrefix(`/chartrepo/`))
      kind: Rule
      services:
        - name: harbor-core
          port: 80
  tls:
    secretName: harbor-tls
```

### Service Communication

```
┌─────────────────────────────────────────────────────────────────┐
│                        harbor-local namespace                   │
│                                                                 │
│  ┌──────────┐ HTTP  ┌──────────┐ HTTP  ┌──────────┐            │
│  │  portal  │◄─────►│   core   │◄─────►│ registry │            │
│  │  :8080   │       │  :8080   │       │  :5000   │            │
│  └──────────┘       └────┬─────┘       └──────────┘            │
│                          │                                      │
│              ┌───────────┼───────────┐                         │
│              ▼           ▼           ▼                         │
│         ┌─────────┐ ┌─────────┐ ┌─────────────┐               │
│         │  redis  │ │postgres │ │ jobservice  │               │
│         │  :6379  │ │ :5432   │ │   :8080     │               │
│         └─────────┘ └─────────┘ └─────────────┘               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

External Access (Local Development via Port Forward):
  - Harbor UI:     https://127.0.0.1:8443
  - Docker API:    https://127.0.0.1:8443/v2/
  - Chart API:     https://127.0.0.1:8443/chartrepo/

Internal Cluster Access:
  - ClusterIP:     https://10.106.241.219:443 (harbor-core service)
  - Service DNS:   harbor-core.harbor-local.svc.cluster.local:443
```

---

## Authentication & Authorization

### Authentication Methods

| Method | Local | Production | Notes |
|--------|-------|------------|-------|
| **Database** | ✅ | ✅ | Built-in user management |
| **LDAP/AD** | ❌ | ✅ | Enterprise integration |
| **OIDC** | ❌ | ✅ | SSO integration |

### Default Credentials (Local Only)

```
Username: admin
Password: Harbor12345 (from Vault)
```

### Project Structure

```
harbor.local/
├── blocksecops/              # Main project
│   ├── api-service           # API service images
│   ├── dashboard             # Dashboard images
│   ├── orchestration         # Orchestration images
│   ├── notification          # Notification images
│   └── scanner-*             # Scanner images
├── library/                  # Base images (optional)
│   ├── python
│   └── node
└── cache/                    # Build cache (optional)
```

---

## Integration with Apogee Services

### Build Workflow

**Local Development (Minikube):**

```bash
# 1. Use minikube's Docker daemon
eval $(minikube docker-env)

# 2. Build with versioned tag
docker build -t api-service:0.4.0 .

# 3. Tag for Harbor registry (use ClusterIP for internal access)
docker tag api-service:0.4.0 10.106.241.219:443/blocksecops/api-service:0.4.0

# 4. Push to Harbor (requires Docker login first)
docker push 10.106.241.219:443/blocksecops/api-service:0.4.0

# 5. Tag as latest for kustomization
docker tag api-service:0.4.0 blocksecops-api-service:latest

# 6. Deploy via kustomization
kubectl apply -k k8s/overlays/local/api-service

# 7. Force pod refresh if needed
kubectl delete pods -n api-service-local -l app.kubernetes.io/name=api-service
```

**Note:** With Harbor registry and versioned tags, `--no-cache` is no longer required for Docker builds. See [Docker Image Versioning Standards](/Users/pwner/Git/ABS/docs/standards/docker-image-versioning.md).

### Image Naming Convention

```
harbor.local/blocksecops/<service>:<version>

Examples:
  harbor.local/blocksecops/api-service:0.6.0
  harbor.local/blocksecops/dashboard:0.12.3
  harbor.local/blocksecops/scanner-slither:0.2.0
```

### Kubernetes ImagePullSecrets

```yaml
# Create secret for Harbor authentication
kubectl create secret docker-registry harbor-creds \
  --docker-server=harbor.local \
  --docker-username=admin \
  --docker-password=Harbor12345 \
  -n <namespace>

# Reference in deployment
spec:
  imagePullSecrets:
    - name: harbor-creds
```

---

## Secret Management

### Vault Integration

Harbor secrets are stored in HashiCorp Vault and synchronized via External Secrets Operator.

```
Vault Path: secret/harbor
├── secretKey           # Harbor core secret key
├── HARBOR_ADMIN_PASSWORD # Admin password
└── registry-htpasswd   # Registry authentication

Vault Path: secret/postgresql
├── POSTGRES_USER       # Shared with Harbor
├── POSTGRES_PASSWORD
└── POSTGRES_DB

Vault Path: secret/redis
└── password            # Shared with Harbor
```

### ExternalSecret Configuration

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: harbor-core-secret
  namespace: harbor-local
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: harbor-core-secret
  data:
    - secretKey: secretKey
      remoteRef:
        key: secret/data/harbor
        property: secretKey
    - secretKey: HARBOR_ADMIN_PASSWORD
      remoteRef:
        key: secret/data/harbor
        property: HARBOR_ADMIN_PASSWORD
```

---

## Operations

### Health Checks

```bash
# Harbor health endpoint
curl -k https://harbor.local/api/v2.0/health

# Expected response
{
  "status": "healthy",
  "components": [
    {"name": "core", "status": "healthy"},
    {"name": "portal", "status": "healthy"},
    {"name": "registry", "status": "healthy"},
    {"name": "jobservice", "status": "healthy"},
    {"name": "database", "status": "healthy"},
    {"name": "redis", "status": "healthy"}
  ]
}
```

### Garbage Collection

```bash
# Trigger GC via API
curl -k -X POST "https://harbor.local/api/v2.0/system/gc/schedule" \
  -H "Content-Type: application/json" \
  -u "admin:Harbor12345" \
  -d '{"schedule": {"type": "Manual"}}'

# Check GC status
curl -k "https://harbor.local/api/v2.0/system/gc" \
  -u "admin:Harbor12345"
```

### Backup and Restore

```bash
# Backup database
kubectl exec -n harbor-local harbor-database-0 -- \
  pg_dump -U postgres harbor > harbor-backup.sql

# Backup registry storage
kubectl cp harbor-local/harbor-registry-0:/storage ./registry-backup

# Restore
kubectl exec -i -n harbor-local harbor-database-0 -- \
  psql -U postgres harbor < harbor-backup.sql
```

---

## Troubleshooting

### Common Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Push Fails** | `unauthorized: authentication required` | Check Docker login, verify credentials |
| **Pull Fails** | `x509: certificate signed by unknown authority` | Add insecure-registries or trust CA |
| **Slow Push** | Transfers take long time | Check network between host and Minikube |
| **Storage Full** | Push fails with 500 error | Run garbage collection, expand PVC |

### Debug Commands

```bash
# Check all Harbor pods
kubectl get pods -n harbor-local

# Check core logs
kubectl logs -n harbor-local deployment/harbor-core

# Check registry logs
kubectl logs -n harbor-local deployment/harbor-registry

# Test registry connectivity
curl -k https://harbor.local/v2/_catalog

# Test authentication
curl -k -u "admin:Harbor12345" https://harbor.local/api/v2.0/users/current
```

---

## Production Considerations

| Aspect | Local | Production |
|--------|-------|------------|
| **Replicas** | 1 | 2-3 (HA) |
| **HPA** | Disabled | Enabled |
| **PDB** | None | minAvailable: 1 |
| **Storage** | 10Gi | 100Gi+ (S3 recommended) |
| **TLS** | Self-signed | Proper CA |
| **Trivy** | Disabled | Enabled |
| **Backup** | Manual | Automated CronJob |
| **Monitoring** | Basic | Prometheus + Grafana |

---

## Related Documentation

- [Harbor Official Docs](https://goharbor.io/docs/2.11.0/)
- [Task Doc: Harbor Installation](/Users/pwner/Git/ABS/TaskDocs-Apogee/phases/02-phase-3.1a1-add-harbor/HARBOR-LOCAL-INSTALLATION.md)
- [Docker Image Versioning](/Users/pwner/Git/ABS/docs/standards/docker-image-versioning.md)
- [Kubernetes Kustomize Template](/Users/pwner/Git/ABS/docs/architecture-templates/kubernetes-kustomize-structure-template.md)

---

## Current Deployment Status (Local)

As of December 12, 2025:

| Component | Status | Version |
|-----------|--------|---------|
| harbor-core | Running | 2.11.2 |
| harbor-portal | Running | 2.11.2 |
| harbor-registry | Running | 2.11.2 |
| harbor-jobservice | Running | 2.11.2 |
| harbor-database | Running | PostgreSQL 13 |
| harbor-redis | Running | Redis 7 |
| harbor-trivy | Disabled | - |

**Images Stored:**
- Scanner images: 15 (slither, aderyn, wake, mythril, semgrep, solhint, medusa, halmos, echidna, foundry, hardhat, vyper, moccasin, soliditydefend, certora)
- Service images: 5 (api-service, orchestration, tool-integration, data-service, intelligence-engine)
- Total storage used: ~6.3GB

---

**Document Owner:** Infrastructure Team
**Last Updated:** December 12, 2025
