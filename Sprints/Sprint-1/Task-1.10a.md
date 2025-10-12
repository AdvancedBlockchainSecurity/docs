# Task 1.10a: Backend Microservices K8s Templates - Phase 1 (Local Environment)

## Phase 1 Focus: Local Development Environment

**Objective**: Create complete, deployable Kubernetes templates for all 7 backend services in local minikube environment.

**Estimated Time**: 2 hours
**Owner**: DevOps/Backend Team
**Priority**: P0 (Critical - Immediate)
**Status**: In Progress

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Overview

Phase 1 delivers immediate value by creating working Kubernetes deployments for all backend services in the local development environment. This establishes proven patterns that will be replicated to staging and production in subsequent phases.

### Services in Scope (7 total)

1. **api-service** - FastAPI authentication and API gateway
2. **tool-integration** - Multi-container deployment (Python/Rust/Node.js)
3. **intelligence-engine** - Hybrid Python/Rust ML analysis
4. **orchestration** - Celery worker deployment
5. **data-service** - Hybrid Python/Rust database operations
6. **notification** - Node.js WebSocket server
7. **contract-parser** - Pure Rust HTTP API

## Directory Structure Per Service

```
<service-repository>/
└── k8s/
    ├── base/
    │   └── <service-name>/
    │       ├── kustomization.yaml
    │       ├── deployment.yaml
    │       ├── service.yaml
    │       ├── configmap.yaml
    │       └── serviceaccount.yaml
    │
    └── overlays/
        └── local/
            ├── kustomization.yaml (root)
            └── <service-name>/
                ├── kustomization.yaml
                ├── namespace.yaml
                ├── deployment-patch.yaml
                ├── configmap-patch.yaml
                └── externalsecret.yaml
```

**Total files per service**: ~9-10 files
**Total Phase 1 files**: ~70 files across 7 services

## Implementation Steps

### Step 1: Base Templates (60 minutes)

Create base Kubernetes manifests for each service:

#### 1.1 Deployment Manifests
- Container specifications with image references
- Resource requests and limits (minimal for local)
- Health checks (liveness, readiness, startup probes)
- Security contexts (non-root, read-only filesystem where possible)
- Environment variable placeholders
- Volume mounts for configurations

#### 1.2 Service Definitions
- ClusterIP services for internal communication
- Port mappings for service endpoints
- Service discovery labels and selectors

#### 1.3 ConfigMaps
- Non-sensitive configuration values
- Environment-specific settings
- Feature flags
- Service endpoints and URLs

#### 1.4 ServiceAccounts
- Per-service identity for RBAC
- Annotations for future IRSA integration

### Step 2: Local Overlays (45 minutes)

Create local environment-specific configurations:

#### 2.1 Namespace Configuration
- Per-service namespace: `<service>-local`
- Resource quotas (optional for local)
- Labels for organization

#### 2.2 Deployment Patches
- Local-specific resource limits:
  - memory: 128Mi-512Mi
  - cpu: 100m-500m
- Replica count: 1
- Image pull policy: IfNotPresent
- Development environment variables
- Debugging configurations

#### 2.3 ConfigMap Patches
- Local service URLs (e.g., http://postgres.postgresql-local.svc)
- Vault URL: http://vault.vault-local.svc.cluster.local:8200
- Log level: DEBUG
- Local-specific feature flags

#### 2.4 External Secrets
- SecretStore reference to local Vault backend
- Secret path mappings
- Refresh interval: 15s (fast for development)
- Target Kubernetes secret specifications

### Step 3: Kustomization Files (15 minutes)

Create kustomization.yaml files for orchestration:

#### Base Kustomization
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: <service>-local

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - serviceaccount.yaml

commonLabels:
  app.kubernetes.io/name: <service>
  app.kubernetes.io/part-of: blocksecops-platform
  environment: local
```

#### Local Overlay Kustomization
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base/<service>

namespace: <service>-local

resources:
  - namespace.yaml
  - externalsecret.yaml

patchesStrategicMerge:
  - deployment-patch.yaml
  - configmap-patch.yaml
```

## Service-Specific Configurations

### 1. API Service (api-service)
- **Type**: Stateless Deployment
- **Language**: Python (FastAPI)
- **Ports**: 8000 (HTTP API)
- **Dependencies**: PostgreSQL, Redis, Vault
- **Special Config**: JWT authentication, session management
- **Resources**:
  - memory: 256Mi-512Mi
  - cpu: 200m-500m

### 2. Tool Integration (tool-integration)
- **Type**: Stateless Deployment (Multi-container)
- **Language**: Python/Rust/Node.js
- **Ports**: 8001 (coordinator), 8002-8004 (tool adapters)
- **Dependencies**: Various security tools
- **Special Config**: Multiple containers in single pod
- **Resources**:
  - memory: 512Mi-1Gi (total across containers)
  - cpu: 300m-800m

### 3. Intelligence Engine (intelligence-engine)
- **Type**: Stateless Deployment
- **Language**: Python/Rust hybrid
- **Ports**: 8010 (HTTP API)
- **Dependencies**: PostgreSQL, ML models
- **Special Config**: Model loading, GPU support (optional)
- **Resources**:
  - memory: 512Mi-1Gi
  - cpu: 500m-1000m

### 4. Orchestration (orchestration)
- **Type**: Stateless Deployment (Celery workers)
- **Language**: Python
- **Ports**: 5555 (Flower monitoring - optional)
- **Dependencies**: Redis, RabbitMQ/Redis broker
- **Special Config**: Worker concurrency, task queues
- **Resources**:
  - memory: 256Mi-512Mi
  - cpu: 200m-500m

### 5. Data Service (data-service)
- **Type**: Stateless Deployment
- **Language**: Python/Rust hybrid
- **Ports**: 8020 (HTTP API)
- **Dependencies**: PostgreSQL, Redis
- **Special Config**: Connection pooling, caching
- **Resources**:
  - memory: 256Mi-512Mi
  - cpu: 200m-500m

### 6. Notification Service (notification)
- **Type**: Stateless Deployment
- **Language**: Node.js/TypeScript
- **Ports**: 8030 (WebSocket), 8031 (HTTP API)
- **Dependencies**: Redis
- **Special Config**: WebSocket connections, pub/sub
- **Resources**:
  - memory: 128Mi-256Mi
  - cpu: 100m-300m

### 7. Contract Parser (contract-parser)
- **Type**: Stateless Deployment
- **Language**: Pure Rust
- **Ports**: 8040 (HTTP API)
- **Dependencies**: None (stateless parser)
- **Special Config**: High-performance parsing
- **Resources**:
  - memory: 256Mi-512Mi
  - cpu: 300m-800m

## External Secrets Configuration

Each service requires secrets from Vault:

### Common Secrets
- Database connection strings
- Redis connection strings
- API keys for service-to-service communication
- JWT signing keys

### Service-Specific Secrets
- **api-service**: Session secrets, OAuth credentials
- **tool-integration**: Tool API keys, license keys
- **intelligence-engine**: Model encryption keys
- **orchestration**: Broker credentials
- **data-service**: Database admin credentials
- **notification**: Push notification credentials
- **contract-parser**: None (stateless)

### External Secret Template
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <service>-secret
  namespace: <service>-local
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: <service>-secret
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: kv/<service>/local
        property: database_url
    - secretKey: REDIS_URL
      remoteRef:
        key: kv/<service>/local
        property: redis_url
```

## Health Check Configurations

### Standard Health Check Pattern
```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: http
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /health/startup
    port: http
  initialDelaySeconds: 0
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 30
```

## Testing and Validation

### Deployment Testing
```bash
# Apply templates for each service
kubectl apply -k k8s/overlays/local/<service>

# Verify deployments
kubectl get pods -n <service>-local

# Check service endpoints
kubectl get svc -n <service>-local

# View External Secret sync status
kubectl get externalsecret -n <service>-local

# Test health endpoints
kubectl port-forward -n <service>-local svc/<service> 8080:8000
curl http://localhost:8080/health/live
```

### Validation Checklist
- [ ] All pods reach Running status
- [ ] Health checks pass (liveness, readiness)
- [ ] External Secrets sync successfully
- [ ] Services are discoverable via DNS
- [ ] ConfigMaps mount correctly
- [ ] Resource limits respected
- [ ] Logs show successful startup

## Success Criteria

**Phase 1 Complete When**:
- [ ] All 7 services have complete K8s templates
- [ ] All services deploy successfully to local minikube
- [ ] All health checks pass
- [ ] External Secrets integration working
- [ ] Services can communicate with dependencies (PostgreSQL, Redis, Vault)
- [ ] No secrets committed to Git repositories
- [ ] Documentation updated with deployment instructions

## Next Phase Preview

**Phase 2 (Task 1.10b)**: Staging Environment
- Replicate local templates to staging overlays
- Increase resource limits (50-70% of production)
- Add IRSA configurations for AWS integration
- Implement network policies
- Configure shared ingress with load balancer

**Phase 3 (Task 1.10c)**: Production Environment
- Production-ready templates with full HA
- Production IRSA with least-privilege IAM roles
- ALB ingress with SSL termination
- HPA and PodDisruptionBudgets
- Comprehensive monitoring and alerting

## Files Tracking

### Repositories to Update
- [ ] blocksecops-api-service
- [ ] blocksecops-tool-integration
- [ ] blocksecops-intelligence-engine
- [ ] blocksecops-orchestration
- [ ] blocksecops-data-service
- [ ] blocksecops-notification
- [ ] blocksecops-contract-parser

### Files per Repository (~9-10 files)
**Base** (~4 files):
- k8s/base/<service>/kustomization.yaml
- k8s/base/<service>/deployment.yaml
- k8s/base/<service>/service.yaml
- k8s/base/<service>/configmap.yaml
- k8s/base/<service>/serviceaccount.yaml

**Local Overlay** (~5 files):
- k8s/overlays/local/kustomization.yaml
- k8s/overlays/local/<service>/kustomization.yaml
- k8s/overlays/local/<service>/namespace.yaml
- k8s/overlays/local/<service>/deployment-patch.yaml
- k8s/overlays/local/<service>/configmap-patch.yaml
- k8s/overlays/local/<service>/externalsecret.yaml

**Total**: ~70 files across all services

---

**Phase 1 Start Date**: October 6, 2025
**Phase 1 Target Completion**: 2 hours from start
**Status**: Ready to begin implementation
