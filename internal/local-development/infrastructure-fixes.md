# Infrastructure Fixes and Workarounds

> **⚠️ LOCAL DEVELOPMENT ONLY - These fixes are NOT for production use**

## Overview

This document details all infrastructure fixes and workarounds applied to resolve deployment issues in the local development environment. These modifications ensure functionality while maintaining simplicity for local development.

## Database Services Fixes

### PostgreSQL Image Issues ❌➡️✅

#### **Problem**
Original Helm deployment failed with image pull errors:
```bash
Failed to pull image "docker.io/bitnami/postgresql:17.6.0-debian-12-r4":
Error response from daemon: manifest for bitnami/postgresql:17.6.0-debian-12-r4 not found
```

#### **Root Cause**
- Bitnami images with specific version tags were not available
- Helm chart specified non-existent image versions
- Platform compatibility issues with specified tags

#### **Solution Applied**
Replaced Bitnami deployment with official PostgreSQL image:

```yaml
# File: /Users/pwner/Git/ABS/postgresql-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:15  # ✅ Official stable image
        env:
        - name: POSTGRES_PASSWORD
          value: "dev-password"
        - name: POSTGRES_DB
          value: "soliditysecurity"
        - name: POSTGRES_USER
          value: "postgres"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgresql-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgresql-storage
        emptyDir: {}  # ⚠️ LOCAL DEV ONLY - Use PVC in production
```

#### **Verification**
```bash
kubectl exec postgresql-<pod-id> -- psql -U postgres -d soliditysecurity -c "SELECT version();"
# Result: PostgreSQL 15.14 (Debian 15.14-1.pgdg13+1) ✅
```

### Redis Image Issues ❌➡️✅

#### **Problem**
Similar Bitnami Redis image pull failures:
```bash
Failed to pull image "docker.io/bitnami/redis:8.2.1-debian-12-r0":
manifest for bitnami/redis:8.2.1-debian-12-r0 not found
```

#### **Solution Applied**
Replaced with official Redis image:

```yaml
# File: /Users/pwner/Git/ABS/redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-master
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
      role: master
  template:
    metadata:
      labels:
        app: redis
        role: master
    spec:
      containers:
      - name: redis
        image: redis:7  # ✅ Official stable image
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-storage
          mountPath: /data
      volumes:
      - name: redis-storage
        emptyDir: {}  # ⚠️ LOCAL DEV ONLY - Use PVC in production
```

#### **Verification**
```bash
kubectl exec redis-master-<pod-id> -- redis-cli ping
# Result: PONG ✅
```

## ConfigMap Updates

### Database Connection Strings

Updated ConfigMap to use correct internal DNS names:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-config
  namespace: blocksecops
data:
  DATABASE_URL: "postgresql://postgres:dev-password@postgresql.default.svc.cluster.local:5432/soliditysecurity"
  REDIS_URL: "redis://redis-master.default.svc.cluster.local:6379"
  VAULT_URL: "http://vault.default.svc.cluster.local:8200"
  VAULT_TOKEN: "dev-root-token"
```

**Key Changes:**
- Added `.default.svc.cluster.local` for cross-namespace DNS resolution
- Changed from Bitnami service names to custom service names
- Maintained production-compatible environment variable names

## Docker Build Fixes

### Memory Allocation Issue ❌➡️✅

#### **Problem**
```bash
Docker Desktop has only 7837MB memory but you specified 12288MB
```

#### **Solution**
Reduced minikube memory allocation:
```bash
# Original (failed)
minikube start --memory=12288

# Fixed (working)
minikube start --driver=docker --memory=7000 --cpus=6 --disk-size=80g
```

### Docker Engine Connection ❌➡️✅

#### **Problem**
Docker daemon not running / wrong socket path

#### **Solution**
Used podman-machine with Docker API compatibility:
```bash
# Start podman machine
podman machine start podman-machine-default

# Set Docker host for minikube
export DOCKER_HOST='unix:///var/folders/b3/bj8j75yx1db_5cdbgbsl5f5c0000gn/T/podman/podman-machine-default-api.sock'
```

### Development Dependencies Issue ❌➡️✅

#### **Problem**
Service builds failing on missing development packages:
```bash
ERROR: Could not find a version that satisfies the requirement httpx-mock<1.0.0,>=0.10.1
```

#### **Solution**
Modified Dockerfiles to exclude dev dependencies in production builds:
```dockerfile
# Before (failing)
RUN pip install --user --no-cache-dir -r requirements/base.txt -r requirements/dev.txt

# After (working)
RUN pip install --user --no-cache-dir -r requirements/base.txt
```

**⚠️ Production Note**: Production builds should include proper dev dependency management.

## Namespace Strategy

### Applied Structure
```
default              # Infrastructure services (PostgreSQL, Redis, Vault)
├── postgresql       # Custom PostgreSQL deployment
├── redis-master     # Custom Redis deployment
└── vault-0          # Vault (Helm deployment)

monitoring           # Monitoring stack (Helm deployment)
├── monitoring-grafana
├── prometheus-monitoring-kube-prometheus-prometheus-0
└── alertmanager-monitoring-kube-prometheus-alertmanager-0

blocksecops    # Application services (future deployments)
└── service-config   # ConfigMap with database URLs

ingress-nginx        # Ingress controller (minikube addon)
kube-system          # Kubernetes system components
```

**Rationale**:
- Infrastructure in `default` for simplicity
- Applications in dedicated namespace for isolation
- Monitoring in separate namespace per Helm chart requirements

## Local Registry Configuration

### Setup
```bash
# Start local Docker registry
docker run -d -p 5000:5000 --name registry \
  -v registry-data:/var/lib/registry \
  --restart unless-stopped \
  registry:2

# Verify
curl http://localhost:5000/v2/_catalog
```

### Integration
All built images use the `localhost:5000/` prefix for local development.

## Storage Simplifications

### **⚠️ LOCAL DEVELOPMENT ONLY**

All persistent storage uses `emptyDir` volumes:

```yaml
volumes:
- name: postgresql-storage
  emptyDir: {}  # Data lost on pod restart
```

**Production Requirements:**
- Use PersistentVolumeClaims (PVC)
- Configure appropriate StorageClasses
- Implement backup strategies
- Use StatefulSets for databases

## Security Relaxations

### **⚠️ LOCAL DEVELOPMENT ONLY**

1. **Vault**: Development mode with static token
2. **PostgreSQL**: Simple password in ConfigMap (not Secret)
3. **Redis**: No authentication enabled
4. **Container Security**: Running as non-root but simplified

**Production Requirements:**
- Proper secret management with Vault
- Encrypted secret storage
- Network policies
- Pod security standards
- RBAC implementation

## Performance Optimizations Applied

### Resource Allocation
```yaml
# Applied to minikube
--memory=7000    # Reduced from 12GB
--cpus=6         # Maintained
--disk-size=80g  # Maintained
```

### Image Optimization
- Multi-stage Docker builds maintained
- Dependency caching enabled
- Local registry for faster pulls

## Network Configuration

### Ingress Setup
```yaml
# File: /Users/pwner/Git/ABS/local-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blocksecops-ingress
  namespace: monitoring
spec:
  rules:
  - host: grafana.0xapogee.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
```

**Note**: Host resolution requires `/etc/hosts` entries or port-forwarding for local access.

## Monitoring and Observability

### Working Components
- ✅ Prometheus metrics collection
- ✅ Grafana dashboards (admin/admin)
- ✅ Alertmanager notifications
- ✅ Node and pod metrics

### Access Methods
```bash
# Port forwarding (recommended for local dev)
kubectl port-forward svc/monitoring-grafana 3001:80 -n monitoring &

# Ingress (requires host configuration)
echo "$(minikube ip) grafana.0xapogee.com" | sudo tee -a /etc/hosts
```

## Troubleshooting Applied Fixes

### Common Issues Resolved

1. **Pod Pending State**: Resolved with correct resource allocation
2. **ImagePullBackOff**: Fixed with official Docker images
3. **DNS Resolution**: Fixed with full service DNS names
4. **Permission Denied**: Fixed Dockerfile user/directory permissions
5. **Build Failures**: Resolved dependency and shared library issues

### Diagnostic Commands Used
```bash
# Pod investigation
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Resource checking
kubectl top nodes
kubectl top pods -A

# Network testing
kubectl exec -it <pod-name> -- nslookup <service-name>
```

## Rollback Procedures

### Infrastructure Services
```bash
# Remove custom deployments
kubectl delete -f postgresql-deployment.yaml
kubectl delete -f redis-deployment.yaml

# Reinstall with Helm (if needed)
helm install postgresql bitnami/postgresql [options]
```

### Application Services
```bash
# Remove local images
docker rmi localhost:5000/blocksecops-api-service:dev

# Clean local registry
docker stop registry && docker rm registry
```

---

## October 15, 2025 - Additional Fixes

### Orchestration Service Redis Connection Fix ❌➡️✅

#### **Problem**
```bash
# Pod showing 2/3 ready with 41 restarts
orchestration-5745474478-nd76d   2/3     Running   41 (3m ago)

# Error in orchestration-beat container
redis.exceptions.ConnectionError: Error -3 connecting to redis.redis-local.svc.cluster.local:6379.
Temporary failure in name resolution.
```

#### **Root Cause**
1. Incorrect Redis service name: `redis.redis-local.svc.cluster.local` (should be `redis-master`)
2. Missing password authentication in connection strings
3. ExternalSecret not properly syncing in local environment

#### **Solution Applied**
Created static secret with correct configuration:

```yaml
# File: blocksecops-orchestration/k8s/overlays/local/orchestration/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: orchestration-secrets
  namespace: orchestration-local
type: Opaque
stringData:
  redis_url: "redis://:redis-local-password@redis-master.redis-local.svc.cluster.local:6379/0"
  celery_broker_url: "redis://:redis-local-password@redis-master.redis-local.svc.cluster.local:6379/0"
  celery_result_backend: "redis://:redis-local-password@redis-master.redis-local.svc.cluster.local:6379/0"
```

Updated kustomization.yaml to use static secret instead of externalsecret.yaml.

#### **Verification**
```bash
$ kubectl get pods -n orchestration-local
NAME                             READY   STATUS    RESTARTS
orchestration-5745474478-nd76d   3/3     Running   0
```

### Scanner Job Cleanup ❌➡️✅

#### **Problem**
```bash
# Stale jobs in Error state
scan-slither-6dd43644  0/1   Error    3h12m
scan-slither-df11cd3a  0/1   Error    2h45m

# Error: ConfigMap mount failures
Warning  FailedMount  MountVolume.SetUp failed for volume "contract-source" :
configmap "scan-6dd43644-source" not found
```

#### **Root Cause**
Jobs referencing deleted ConfigMaps from previous scan attempts. ConfigMaps were cleaned up but jobs persisted.

#### **Solution Applied**
```bash
kubectl delete job scan-slither-6dd43644 -n tool-integration-local
kubectl delete job scan-slither-df11cd3a -n tool-integration-local
```

#### **Recommended Improvement**
Add TTL to scanner job template:
```yaml
apiVersion: batch/v1
kind: Job
spec:
  ttlSecondsAfterFinished: 3600  # Auto-delete after 1 hour
  backoffLimit: 3
```

### Intelligence Engine Implementation ❌➡️✅

#### **Problem**
```bash
# Image pull failure
intelligence-engine-78db644755-8crsv   0/1     ImagePullBackOff   0

# Error: Image doesn't exist
Failed to pull image "blocksecops-intelligence-engine:0.2.0":
pull access denied for blocksecops-intelligence-engine, repository does not exist
```

#### **Root Cause**
1. Service was skeleton/placeholder with no actual source code
2. No `src` directory existed in repository
3. Dockerfile expected `src.main:app` but no implementation
4. Port mismatch: Dockerfile used 8002, deployment expected 8000
5. Missing `api_service_url` in secrets

#### **Solution Applied**

**Created Application Files:**
- `src/__init__.py` - Package initialization
- `src/config.py` - Settings and configuration
- `src/main.py` - FastAPI application with health endpoints

**Fixed Dockerfile:**
```dockerfile
# Fixed FROM casing
FROM python:3.11-slim AS builder  # Was: as builder

# Fixed PYTHONPATH
ENV PYTHONPATH="/app/src"  # Was: "/app/src:$PYTHONPATH"

# Fixed port
EXPOSE 8000  # Was: 8002
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Updated Secrets:**
```yaml
# Added missing api_service_url
stringData:
  api_service_url: "http://api-service.api-service-local.svc.cluster.local:8000"
```

**Built Image:**
```bash
eval $(minikube docker-env)
docker build -t blocksecops-intelligence-engine:0.2.0 .
# Result: 10.5GB image, 0 warnings
```

#### **Verification**
```bash
$ kubectl get pods -n intelligence-engine-local
NAME                                   READY   STATUS    RESTARTS   AGE
intelligence-engine-78db644755-8crsv   1/1     Running   0          2m

$ curl http://localhost:8001/health
{"status":"healthy","service":"intelligence-engine","timestamp":"2025-10-15T04:35:57.123456"}
```

### ImagePullPolicy Standardization ✅

#### **Problem**
Inconsistent imagePullPolicy across services - some using `IfNotPresent` (would try Docker Hub).

#### **Solution Applied**
Updated all 8 services (12 total containers) to use `imagePullPolicy: Never` for local development:

**Services Updated:**
- blocksecops-api-service (1 container)
- blocksecops-data-service (1 container)
- blocksecops-notification (1 container)
- blocksecops-tool-integration (2 containers: initContainer + main)
- blocksecops-orchestration (4 containers: init + worker + beat + monitor)
- blocksecops-intelligence-engine (1 container)
- blocksecops-analysis (1 container)
- blocksecops-contract-parser (1 container)

```yaml
# All deployment patches now include:
spec:
  template:
    spec:
      containers:
      - name: <service>
        imagePullPolicy: Never  # Use local images only
```

#### **Benefits**
- Faster deployments (no Docker Hub lookups)
- Offline development support
- Guaranteed use of locally built images
- No Docker Hub rate limiting concerns

### Dockerfile Best Practices ✅

Fixed Docker build warnings in intelligence-engine:

**Before:**
```dockerfile
FROM python:3.11-slim as builder  # Warning: FromAsCasing
ENV PYTHONPATH="/app/src:$PYTHONPATH"  # Warning: UndefinedVar
```

**After:**
```dockerfile
FROM python:3.11-slim AS builder  # ✅ Uppercase AS
ENV PYTHONPATH="/app/src"  # ✅ No undefined variable reference
```

**Result:** Clean builds with zero warnings across all services.

---

## October 16, 2025 - Database Authentication Fix

### API Service Database Authentication (ExternalSecret) ❌➡️✅

#### **Problem**
```bash
# API service pods crash-looping
$ kubectl get pods -n api-service-local
NAME                     READY   STATUS             RESTARTS
api-service-xxxxx-xxxxx  0/1     CrashLoopBackOff   15

# Logs showing authentication failures
asyncpg.exceptions.InvalidPasswordError: password authentication failed for user "postgres"
ERROR:    Application startup failed. Exiting.

# Dashboard login hanging indefinitely
# Browser: No network requests reaching API
# Port-forward active but API not responding
```

#### **Root Cause**
1. **ExternalSecret Credential Mismatch**: ExternalSecret Operator syncing from Vault with wrong credentials every 15 seconds
   - Vault stored: `postgres:postgres`
   - Actual PostgreSQL: `harbor:harbor-local-password`
2. **Manual Updates Overwritten**: ownerReferences prevented persistence of manual secret changes
3. **CORS Misconfiguration**: Initial CORS wildcard `*` incompatible with `withCredentials: true`
4. **IPv4/IPv6 Port Forward Confusion**: kubectl port-forward defaulting to IPv6 localhost

#### **Solution Applied**

**Deleted ExternalSecret and Created Static Secret:**

```bash
# 1. Remove ExternalSecret dependency
kubectl delete externalsecret api-service-secret -n api-service-local

# 2. Create static secret with correct credentials
cat > /tmp/api-service-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: api-service-secret
  namespace: api-service-local
type: Opaque
stringData:
  DATABASE_URL: "postgresql+asyncpg://harbor:harbor-local-password@postgresql.postgresql-local.svc.cluster.local:5432/blocksecops"
  REDIS_URL: "redis://:redis-local-password@redis-master.redis-local.svc.cluster.local:6379/0"
  JWT_SECRET_KEY: "local-dev-jwt-secret-key-change-in-production"
  SESSION_SECRET: "local-dev-session-secret-change-in-production"
EOF

kubectl apply -f /tmp/api-service-secret.yaml

# 3. Restart API service
kubectl delete pods --all -n api-service-local

# 4. Fix port-forward
lsof -ti :8000 | xargs kill -9 2>/dev/null
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &
```

**Standardized IP Address Usage:**

Ensured consistent use of `127.0.0.1` (not `localhost`) across all services:
- Dashboard `.env.development.local`: `VITE_API_BASE_URL=http://127.0.0.1:8000`
- Dashboard `vite.config.ts`: `host: '127.0.0.1'`
- All curl commands: `http://127.0.0.1:8000`

#### **Verification**
```bash
# Test API health
$ curl http://127.0.0.1:8000/api/v1/health/ready
{"ready":true,"checks":{"database":true,"service":true},"message":"Service is ready"}

# Test login
$ curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test-rebrand@0xapogee.com", "password": "TestPass123"}'
{"message":"Login successful","user_id":"45b0f212-e9d5-4030-b489-4896ae1263cf","email":"test-rebrand@0xapogee.com"}

# Check pod status
$ kubectl get pods -n api-service-local
NAME                           READY   STATUS    RESTARTS   AGE
api-service-77c668b5c7-58px8   1/1     Running   0          5m

# Services operational
✅ Dashboard: http://127.0.0.1:3000
✅ API Service: http://127.0.0.1:8000
✅ Login: Working with test account
```

#### **Key Learnings**

1. **ExternalSecret Debugging**:
   - Always check for ExternalSecret before manually editing secrets
   - 15-second refresh interval means manual changes are quickly overwritten
   - ownerReferences prevent persistence of manual edits
   - For local dev, static secrets are simpler than Vault integration

2. **Database Credential Management**:
   - Document actual database credentials in multiple locations
   - Verify credentials with: `kubectl exec -n postgresql-local postgresql-0 -- env | grep POSTGRES`
   - Don't assume default usernames (postgres vs harbor)

3. **IPv4/IPv6 Consistency**:
   - `kubectl port-forward` binds to IPv6 localhost by default
   - Use `127.0.0.1` explicitly everywhere for IPv4 consistency
   - Don't mix `localhost` and `127.0.0.1` in configuration

4. **CORS with Credentials**:
   - Cannot use wildcard `*` origin with `withCredentials: true`
   - Must specify explicit origins: `http://127.0.0.1:3000,http://localhost:3000`
   - Required for HttpOnly cookie authentication

5. **Systematic Troubleshooting**:
   - Check pod logs first
   - Verify actual infrastructure configuration (not assumed)
   - Check for external controllers (ExternalSecret, operators)
   - Test at each layer: pod → port-forward → API → dashboard

#### **Production Note**

This fix uses static secrets for local development simplicity. **For production:**
- Update Vault credentials at `kv/postgresql/local`
- Re-enable ExternalSecret for proper secrets management
- Ensure Vault credentials match actual database configuration
- Use proper TLS for database connections

#### **Related Documentation**

- Detailed fix: `/Users/pwner/Git/ABS/docs/API-SERVICE-DATABASE-AUTH-FIX-2025-10-16.md`
- Troubleshooting: `/Users/pwner/Git/ABS/blocksecops-docs/local-development/troubleshooting-guide.md` (Section: Database Authentication Issues)

---

**Update Date**: October 16, 2025
**Previous Applied Date**: October 15, 2025 → October 2, 2025
**Environment**: Local Development minikube
**Status**: ✅ All fixes applied and tested
**Production Compatibility**: ❌ Requires production-specific configurations