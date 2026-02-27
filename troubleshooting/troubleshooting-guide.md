# Local Development Troubleshooting Guide

> Quick reference for common issues and their solutions

## Table of Contents

1. [Redis Connection Issues](#redis-connection-issues)
2. [Pod ImagePullBackOff](#pod-imagepullbackoff)
3. [Stale Scanner Jobs](#stale-scanner-jobs)
4. [Service Restarts/CrashLoopBackOff](#service-restarts-crashloopbackoff)
5. [Database Authentication Issues (ExternalSecret)](#database-authentication-issues-externalsecret)
6. [Port Conflicts](#port-conflicts)
7. [Secret/ConfigMap Issues](#secret-configmap-issues)
8. [Docker Build Issues](#docker-build-issues)
9. [Minikube Memory Issues](#minikube-memory-issues)
10. [Contract Stuck in "Scanning" Status](#contract-stuck-in-scanning-status)
11. [Dashboard React Router Context Errors](#dashboard-react-router-context-errors)

---

## Redis Connection Issues

### Symptoms
```bash
# Pods showing 2/3 or 1/2 ready
$ kubectl get pods -n <namespace>
NAME                      READY   STATUS    RESTARTS
service-xxxxx-xxxxx       2/3     Running   15

# Logs showing connection errors
redis.exceptions.ConnectionError: Error -3 connecting to redis...
Temporary failure in name resolution
```

### Quick Diagnosis
```bash
# 1. Check Redis service name
kubectl get svc -n redis-local
# Should show: redis-master (NOT redis)

# 2. Check secret configuration
kubectl get secret <service>-secrets -n <namespace>-local -o yaml | grep redis

# 3. Test DNS resolution
kubectl exec -n <namespace>-local deployment/<service> -- nslookup redis-master.redis-local.svc.cluster.local
```

### Solution

**Wrong service name**: Update secret to use `redis-master.redis-local.svc.cluster.local`:

```yaml
# File: k8s/overlays/local/<service>/secret.yaml
stringData:
  redis_url: "redis://:redis-local-password@redis-master.redis-local.svc.cluster.local:6379/0"
```

**Missing password**: Ensure password format is correct:
```
redis://:password@host:port/db
         ^
         Note the colon before password
```

**Apply fix**:
```bash
kubectl apply -k k8s/overlays/local/<service>/
kubectl delete pod <pod-name> -n <namespace>-local  # Force restart
```

---

## Pod ImagePullBackOff

### Symptoms
```bash
$ kubectl get pods -n <namespace>-local
NAME                     READY   STATUS             RESTARTS
service-xxxxx-xxxxx      0/1     ImagePullBackOff   0

# Describe shows:
Failed to pull image "service:version": pull access denied
```

### Quick Diagnosis
```bash
# 1. Check if image exists in Minikube
eval $(minikube docker-env)
docker images | grep <service>

# 2. Check imagePullPolicy
kubectl get deployment <service> -n <namespace>-local -o yaml | grep imagePullPolicy

# 3. Check deployment events
kubectl describe pod <pod-name> -n <namespace>-local
```

### Solution

**Image doesn't exist locally**:
```bash
cd blocksecops-<service>
eval $(minikube docker-env)
docker build -t <service>:<version> .

# Verify
docker images | grep <service>
```

**Wrong imagePullPolicy** (should be `Never` for local):
```yaml
# File: k8s/overlays/local/<service>/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service>
spec:
  template:
    spec:
      containers:
      - name: <service>
        imagePullPolicy: Never  # Add this line
```

**Apply fix**:
```bash
kubectl apply -k k8s/overlays/local/<service>/
kubectl rollout restart deployment/<service> -n <namespace>-local
```

---

## Stale Scanner Jobs

### Symptoms
```bash
$ kubectl get jobs -n tool-integration-local
NAME                   COMPLETIONS   STATUS   AGE
scan-slither-xxxxxx    0/1          Error     3h

# Events show:
Warning  FailedMount  MountVolume.SetUp failed: configmap "scan-xxxxx-source" not found
```

### Quick Diagnosis
```bash
# 1. List failed jobs
kubectl get jobs -n tool-integration-local --field-selector status.successful=0

# 2. Check job age
kubectl get jobs -n tool-integration-local -o wide

# 3. Check for referenced ConfigMaps
kubectl describe job <job-name> -n tool-integration-local | grep -A5 Events
```

### Solution

**Delete stale jobs**:
```bash
# Delete specific job
kubectl delete job <job-name> -n tool-integration-local

# Delete all failed jobs
kubectl get jobs -n tool-integration-local --field-selector status.successful=0 -o name | xargs kubectl delete -n tool-integration-local

# Delete jobs older than 1 hour
kubectl get jobs -n tool-integration-local -o json | \
  jq -r '.items[] | select(.status.conditions[0].type=="Failed") | select(.status.startTime | fromdateiso8601 < (now - 3600)) | .metadata.name' | \
  xargs kubectl delete job -n tool-integration-local
```

**Prevention** - Add TTL to job template:
```yaml
# In scanner job template
spec:
  ttlSecondsAfterFinished: 3600  # Auto-delete after 1 hour
  backoffLimit: 3
```

---

## Service Restarts/CrashLoopBackOff

### Symptoms
```bash
$ kubectl get pods -n <namespace>-local
NAME                     READY   STATUS             RESTARTS
service-xxxxx-xxxxx      0/1     CrashLoopBackOff   5

# Or high restart count
service-xxxxx-xxxxx      1/1     Running            42
```

### Quick Diagnosis
```bash
# 1. Check pod logs
kubectl logs <pod-name> -n <namespace>-local --tail=50

# 2. Check previous container logs (if restarted)
kubectl logs <pod-name> -n <namespace>-local --previous

# 3. Check pod events
kubectl describe pod <pod-name> -n <namespace>-local

# 4. Check resource usage
kubectl top pod <pod-name> -n <namespace>-local
```

### Common Causes & Solutions

**Missing environment variable/secret**:
```bash
# Check secret exists and has all required keys
kubectl get secret <service>-secrets -n <namespace>-local -o yaml

# Compare with deployment requirements
kubectl get deployment <service> -n <namespace>-local -o yaml | grep -A10 "envFrom\|env:"
```

**Port mismatch**:
```bash
# Check Dockerfile EXPOSE
grep EXPOSE blocksecops-<service>/Dockerfile

# Check deployment containerPort
kubectl get deployment <service> -n <namespace>-local -o yaml | grep containerPort

# Check service targetPort
kubectl get svc <service> -n <namespace>-local -o yaml | grep targetPort

# All three should match!
```

**Health check failures**:
```bash
# Check readiness probe
kubectl get deployment <service> -n <namespace>-local -o yaml | grep -A5 readinessProbe

# Test endpoint manually
kubectl port-forward -n <namespace>-local svc/<service> 8080:8000
curl http://localhost:8080/health
```

**Database connection issues**:
```bash
# Check PostgreSQL is accessible
kubectl exec -n <namespace>-local deployment/<service> -- nc -zv postgresql.postgresql-local.svc.cluster.local 5432

# Check Redis is accessible
kubectl exec -n <namespace>-local deployment/<service> -- nc -zv redis-master.redis-local.svc.cluster.local 6379
```

---

## Database Authentication Issues (ExternalSecret)

### Symptoms
```bash
# Pods crash-looping with authentication errors
$ kubectl get pods -n api-service-local
NAME                     READY   STATUS             RESTARTS
api-service-xxxxx-xxxxx  0/1     CrashLoopBackOff   5

# Logs show:
asyncpg.exceptions.InvalidPasswordError: password authentication failed for user "postgres"
ERROR:    Application startup failed. Exiting.

# Login hangs indefinitely on dashboard
# Browser shows no network requests reaching API
```

### Quick Diagnosis
```bash
# 1. Check pod logs for authentication errors
kubectl logs -n api-service-local -l app=api-service --tail=50 | grep -i "password\|auth"

# 2. Verify actual PostgreSQL credentials
kubectl exec -n postgresql-local postgresql-0 -- env | grep POSTGRES

# 3. Check if ExternalSecret is managing the secret
kubectl get externalsecret -n api-service-local

# 4. Check secret contents
kubectl get secret api-service-secret -n api-service-local -o jsonpath='{.data.DATABASE_URL}' | base64 -d

# 5. Check deployment environment variables
kubectl exec -n api-service-local deployment/api-service -- env | grep DATABASE_URL
```

### Root Cause

ExternalSecret Operator syncs credentials from Vault every 15 seconds. If Vault contains incorrect credentials, manual secret updates are continuously overwritten.

**Common Credential Mismatch:**
- ExternalSecret uses: `postgres:postgres`
- Actual PostgreSQL uses: `harbor:harbor-local-password`

### Solution

**Option 1: Quick Fix for Local Development** (Recommended)

Remove ExternalSecret dependency and use static secret:

```bash
# 1. Delete ExternalSecret (stops automatic sync)
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

# 3. Restart API service pods
kubectl delete pods --all -n api-service-local

# 4. Verify pod is running
kubectl get pods -n api-service-local
# Expected: api-service-xxx 1/1 Running

# 5. Restart port-forward if needed
lsof -ti :8000 | xargs kill -9 2>/dev/null
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &

# 6. Test API health
sleep 3
curl http://127.0.0.1:8000/api/v1/health/ready
```

**Option 2: Fix Vault Credentials** (Production Approach)

Update Vault with correct credentials:

```bash
# Access Vault - use standardized path structure
# Shared secrets: secret/postgresql, secret/redis
# Service-specific: secret/local/<service>/<secret-type>
kubectl exec -n vault-local vault-0 -- vault kv put secret/postgresql \
  POSTGRES_USER=postgres \
  POSTGRES_PASSWORD=postgres \
  POSTGRES_DB=solidity_security

# Force ExternalSecret to sync immediately
kubectl annotate externalsecret api-service-secret -n api-service-local \
  force-sync="$(date +%s)" --overwrite

# Restart API service
kubectl delete pods --all -n api-service-local
```

### Verification

```bash
# Test API endpoint
curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test-rebrand@0xapogee.com", "password": "TestPass123"}'

# Expected response:
# {"message":"Login successful","user_id":"...","email":"test-rebrand@0xapogee.com"}
```

### Prevention

**Document credential sources:**
```yaml
# File: k8s/overlays/local/api-service/externalsecret.yaml
# Add comment at top:
# NOTE: This syncs from Vault using standardized paths:
# - Shared: secret/postgresql, secret/redis
# - Service-specific: secret/local/api-service/jwt, secret/local/api-service/session
# IMPORTANT: Do NOT include /data/ in paths - ESO handles this automatically
# For local dev debugging, consider using static secret instead
```

**Check for ExternalSecret before manual edits:**
```bash
# Always check before creating/updating secrets
kubectl get externalsecret -n <namespace>-local

# If ExternalSecret exists, either:
# 1. Update Vault (production approach)
# 2. Delete ExternalSecret and use static secret (local dev)
```

### Related Issues

- **Port conflicts**: See [Port Conflicts](#port-conflicts)
- **CORS errors**: Ensure `cors_origins` includes `http://127.0.0.1:3000` (not wildcard `*`)
- **IPv4/IPv6 mismatch**: Always use `127.0.0.1` (not `localhost`) for consistency

### Reference

For complete fix details, see:
- `/Users/pwner/Git/ABS/docs/API-SERVICE-DATABASE-AUTH-FIX-2025-10-16.md`

---

## Port Conflicts

### Symptoms
```bash
# Port-forward fails
$ kubectl port-forward -n <namespace>-local svc/<service> 8000:8000
error: unable to listen on port 8000: Listeners failed to create with the following errors:
[unable to create listener: Error listen tcp4 127.0.0.1:8000: bind: address already in use]
```

### Quick Diagnosis
```bash
# 1. Check what's using the port
lsof -ti:8000

# 2. See the process details
lsof -ti:8000 | xargs ps -p

# 3. Check for existing port-forwards
ps aux | grep "port-forward"
```

### Solution

**Kill process using port**:
```bash
# Kill specific port
lsof -ti:8000 | xargs kill -9

# Kill all kubectl port-forwards
pkill -f "kubectl port-forward"
```

**Use different local port**:
```bash
# Forward service port 8000 to local port 8080
kubectl port-forward -n <namespace>-local svc/<service> 8080:8000
curl http://localhost:8080/health
```

---

## Secret/ConfigMap Issues

### Symptoms
```bash
# Pod events show:
Warning  Failed  Error: couldn't find key <key> in Secret <namespace>/<secret-name>

# Or:
Warning  Failed  Error: secret "<secret-name>" not found
```

### Quick Diagnosis
```bash
# 1. Check if secret exists
kubectl get secret <secret-name> -n <namespace>

# 2. Check secret keys
kubectl get secret <secret-name> -n <namespace> -o yaml

# 3. Check what deployment expects
kubectl get deployment <service> -n <namespace> -o yaml | grep -A20 "envFrom\|secretRef"

# 4. Check kustomization references
cat k8s/overlays/local/<service>/kustomization.yaml
```

### Solution

**Secret missing** - Create it:
```bash
# Create from kustomize
kubectl apply -k k8s/overlays/local/<service>/

# Or create directly
kubectl create secret generic <secret-name> -n <namespace> \
  --from-literal=key1=value1 \
  --from-literal=key2=value2
```

**Missing keys** - Update secret file:
```yaml
# File: k8s/overlays/local/<service>/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: <service>-secrets
  namespace: <namespace>-local
type: Opaque
stringData:
  database_url: "postgresql+asyncpg://..."
  redis_url: "redis://..."
  api_service_url: "http://..."  # Add missing key
```

**ExternalSecret not syncing** - Switch to static secret:
```yaml
# In kustomization.yaml
resources:
- ../../base
- deployment-patch.yaml
- service.yaml
- secret.yaml  # Change from externalsecret.yaml
```

---

## Docker Build Issues

### Symptoms
```bash
# Build fails with warnings or errors
$ docker build -t service:version .
Warning: FromAsCasing: 'as' and 'FROM' keywords' casing do not match
Warning: UndefinedVar: Usage of undefined variable '$VAR'
ERROR: failed to solve...
```

### Quick Diagnosis
```bash
# 1. Check Dockerfile syntax
docker build --check -t service:version .

# 2. Build with detailed output
docker build --progress=plain -t service:version .

# 3. Check if in Minikube context
echo $DOCKER_HOST
# Should show minikube docker daemon

# 4. Verify base images
grep "^FROM" Dockerfile
```

### Common Issues & Solutions

**Not using Minikube Docker daemon**:
```bash
# Set Minikube context
eval $(minikube docker-env)

# Verify
docker ps  # Should show Minikube containers

# Build
docker build -t service:version .
```

**FROM casing warnings**:
```dockerfile
# Wrong
FROM python:3.11-slim as builder

# Correct
FROM python:3.11-slim AS builder
```

**Undefined variable warnings**:
```dockerfile
# Wrong
ENV PATH="/app/bin:$PATH"  # If $PATH might be empty

# Correct
ENV PATH="/app/bin"
# Or ensure variable is defined first
```

**Module not found errors**:
```bash
# Check if src directory exists
ls -la blocksecops-<service>/src/

# Check if __init__.py exists
ls -la blocksecops-<service>/src/__init__.py

# Check Dockerfile COPY commands
grep "COPY" Dockerfile
```

**Port mismatches**:
```bash
# Check all port references are consistent
grep -n "PORT\|8000\|8002" Dockerfile
grep -n "containerPort" k8s/base/deployment.yaml
grep -n "targetPort" k8s/base/service.yaml
```

---

## Quick Command Reference

### Common Debugging Commands

```bash
# Check all pods in all namespaces
kubectl get pods -A | grep -E "(api|data|notification|tool-integration|orchestration|intelligence)"

# Get pod details
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace> --tail=100 --follow

# Check previous container logs (after restart)
kubectl logs <pod-name> -n <namespace> --previous

# Execute command in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Check service endpoints
kubectl get endpoints <service> -n <namespace>

# Port forward service
kubectl port-forward -n <namespace> svc/<service> 8080:8000

# Check resource usage
kubectl top pods -n <namespace>

# Restart deployment
kubectl rollout restart deployment/<service> -n <namespace>

# Delete pod (will recreate)
kubectl delete pod <pod-name> -n <namespace>

# Apply kustomize
kubectl apply -k k8s/overlays/local/<service>/

# Check kustomize output
kubectl kustomize k8s/overlays/local/<service>/

# Check Docker images in Minikube
eval $(minikube docker-env)
docker images | grep blocksecops

# Check running containers
docker ps

# Clean up stopped containers
docker container prune -f

# Clean up unused images
docker image prune -f
```

### Namespace-specific Commands

```bash
# Get all resources in namespace
kubectl get all -n <namespace>

# Delete all failed pods in namespace
kubectl delete pods --field-selector status.phase=Failed -n <namespace>

# Delete all jobs in namespace
kubectl delete jobs --all -n <namespace>

# Get events in namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Watch pods in namespace
kubectl get pods -n <namespace> -w
```

---

## Getting Help

### Check Service Status
```bash
# Quick status check
./scripts/check-services.sh  # If exists

# Or manually:
for ns in api-service-local data-service-local notification-local \
          tool-integration-local orchestration-local intelligence-engine-local; do
  echo "=== $ns ==="
  kubectl get pods -n $ns
  echo ""
done
```

### Collect Diagnostic Information
```bash
# Create diagnostic report
cat > /tmp/diagnostics.txt <<EOF
=== Pods ===
$(kubectl get pods -A | grep -E "(api|data|notification|tool-integration|orchestration|intelligence)")

=== Services ===
$(kubectl get svc -A | grep -E "(api|data|notification|tool-integration|orchestration|intelligence|redis|postgresql)")

=== Recent Events ===
$(kubectl get events -A --sort-by='.lastTimestamp' | tail -20)

=== Docker Images ===
$(eval $(minikube docker-env); docker images | grep blocksecops)
EOF

cat /tmp/diagnostics.txt
```

### Related Documentation

- [Infrastructure Fixes](infrastructure-fixes.md) - Detailed fix history
- [Deployment Verification](deployment-verification.md) - Verification procedures
- [Development Workflow](development-workflow.md) - Day-to-day development guide
- [Setup Summary](setup-summary.md) - Initial setup instructions

---

## Minikube Memory Issues

### Symptoms
```bash
# Pods stuck in Pending state
$ kubectl get pods -n api-service-local
NAME                           READY   STATUS    RESTARTS   AGE
api-service-xxxxx-xxxxx        0/1     Pending   0          5m

# Describe shows "Insufficient memory"
$ kubectl describe pod <pod-name> -n <namespace>
Events:
  Warning  FailedScheduling  default-scheduler  0/1 nodes are available: 1 Insufficient memory

# Node showing high memory allocation
$ kubectl describe node minikube | grep -A 5 "Allocated resources"
Allocated resources:
  Resource           Requests      Limits
  cpu                3850m (64%)   4600m (76%)
  memory             5906Mi (99%)  6700Mi (112%)  # <-- Problem: 99% memory used
```

### Quick Diagnosis
```bash
# 1. Check node resources
kubectl describe node minikube | grep -A 10 "Allocated resources"

# 2. Check minikube configuration
minikube config view

# 3. Check Docker Desktop memory allocation (macOS)
# Docker Desktop → Settings → Resources → Advanced → Memory

# 4. List pods consuming memory
kubectl top pods -A --sort-by=memory | head -20

# 5. Check for stale/failed pods consuming allocations
kubectl get pods -A --field-selector=status.phase=Failed
```

### Root Cause

Minikube was started with insufficient memory, or Docker Desktop doesn't have enough memory allocated. The BlockSecOps platform requires **10GB memory and 6 CPUs** minimum.

**Common causes:**
- Minikube started with default resources (2GB memory, 2 CPUs)
- Docker Desktop memory limit is too low
- Stale pods/jobs consuming memory allocations
- Too many services running simultaneously

### Solution

**Option 1: Recreate Minikube with Proper Resources** (Recommended)

```bash
# 1. Stop and delete existing cluster
minikube stop
minikube delete

# 2. Configure resources
minikube config set memory 10240
minikube config set cpus 6

# 3. Verify Docker Desktop has enough memory
# Docker Desktop → Settings → Resources → Advanced → Memory: 10GB+

# 4. Start new cluster
minikube start --memory=10240 --cpus=6

# 5. Verify resources
kubectl describe node minikube | grep -A 5 "Allocatable"
# Should show ~10GB allocatable memory
```

**Option 2: Clean Up Stale Resources** (Quick fix)

```bash
# Delete failed pods from all namespaces
for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
  kubectl delete pods -n $ns --field-selector=status.phase=Failed 2>/dev/null
done

# Delete old job pods from tool-integration
kubectl delete pods -n tool-integration-local -l job-name --field-selector=status.phase!=Running

# Scale down non-essential services temporarily
kubectl scale deployment notification -n notification-local --replicas=0
kubectl scale deployment data-service -n data-service-local --replicas=0
```

**Option 3: Increase Docker Desktop Memory**

1. Open Docker Desktop
2. Go to Settings → Resources → Advanced
3. Increase Memory to at least 10GB
4. Click "Apply & Restart"
5. Restart minikube: `minikube stop && minikube start`

### Prevention

Add to your development setup checklist:
```bash
# Verify minikube resources before starting work
minikube config view
# Expected:
# - memory: 10240
# - cpus: 6

# If not configured, set them
minikube config set memory 10240
minikube config set cpus 6
```

### Reference

See [Local Development Setup Standards](/Users/pwner/Git/ABS/docs/standards/local-development-setup.md) for complete minikube configuration requirements.

---

## Contract Stuck in "Scanning" Status

### Symptoms
```bash
# Dashboard shows contract with "scanning" badge that never completes
# Contract detail page shows spinning indicator indefinitely
# No scan results appear after extended time (>5 minutes)
```

### Quick Diagnosis
```bash
# 1. Check contract status in database
kubectl exec -n postgresql-local postgresql-0 -- psql -U harbor -d blocksecops -c \
  "SELECT id, name, status FROM contracts WHERE id = '<contract-id>';"

# 2. Check associated scans
kubectl exec -n postgresql-local postgresql-0 -- psql -U harbor -d blocksecops -c \
  "SELECT id, contract_id, status, scanner_id, error_message FROM scans WHERE contract_id = '<contract-id>';"

# 3. Check for failed scanner jobs
kubectl get jobs -n tool-integration-local --field-selector=status.successful=0

# 4. Check scanner pod logs
kubectl logs -n tool-integration-local -l job-name=scan-<scanner>-<id> --tail=50
```

### Root Cause

Contract status becomes stuck when:
1. **Scan fails but contract status not updated**: Scanner job fails (e.g., 402 quota exceeded), but contract remains in "scanning"
2. **Scanner job crashes**: Pod OOMKilled or other fatal error
3. **Missing callback**: Scanner completes but doesn't notify API service
4. **Database transaction error**: Status update fails to commit

### Solution

**Reset contract status via database:**

```bash
# 1. First check current status
kubectl exec -n postgresql-local postgresql-0 -- psql -U harbor -d blocksecops -c \
  "SELECT id, status FROM contracts WHERE id = '<contract-id>';"

# 2. Check if any scans completed successfully
kubectl exec -n postgresql-local postgresql-0 -- psql -U harbor -d blocksecops -c \
  "SELECT status, COUNT(*) FROM scans WHERE contract_id = '<contract-id>' GROUP BY status;"

# 3. Reset contract to appropriate status
# If scans exist (even failed ones):
kubectl exec -n postgresql-local postgresql-0 -- psql -U harbor -d blocksecops -c \
  "UPDATE contracts SET status = 'scanned' WHERE id = '<contract-id>';"

# If no scans exist, reset to uploaded:
kubectl exec -n postgresql-local postgresql-0 -- psql -U harbor -d blocksecops -c \
  "UPDATE contracts SET status = 'uploaded' WHERE id = '<contract-id>';"

# 4. Verify the update
kubectl exec -n postgresql-local postgresql-0 -- psql -U harbor -d blocksecops -c \
  "SELECT id, status FROM contracts WHERE id = '<contract-id>';"
```

**Clean up failed scanner jobs:**

```bash
# Delete failed jobs
kubectl delete jobs -n tool-integration-local --field-selector=status.successful=0

# Delete orphaned scan configmaps
kubectl delete configmaps -n tool-integration-local -l app=scanner-source
```

### Contract Status Reference

Valid status values (enum):
- `uploaded` - Contract uploaded, not yet scanned
- `pending` - Scan queued
- `scanning` - Scan in progress
- `scanned` - Scan complete (success or failure)
- `failed` - Upload or processing failed

### Prevention

The orchestration service should handle scan failures and update contract status automatically. If this issue occurs frequently, check:

```bash
# Check orchestration service logs for error handling
kubectl logs -n orchestration-local deployment/orchestration --tail=100 | grep -i "status\|error\|fail"

# Verify webhook callbacks are configured
kubectl get configmap orchestration-config -n orchestration-local -o yaml | grep callback
```

---

## Dashboard React Router Context Errors

### Symptoms
```bash
# Browser console shows:
Uncaught Error: useNavigate() may be used only in the context of a <Router> component.

# Or similar Router context errors:
Error: useLocation() may be used only in the context of a <Router> component.
Error: useParams() may be used only in the context of a <Router> component.

# Modal or component fails to render
# Navigation doesn't work from certain components
```

### Quick Diagnosis
```bash
# 1. Check App.tsx component tree order
cat blocksecops-dashboard/src/App.tsx | grep -A 20 "function App"

# 2. Look for components using Router hooks outside Router
grep -r "useNavigate\|useLocation\|useParams" blocksecops-dashboard/src/ --include="*.tsx"

# 3. Check if providers are in correct order
# Router must wrap any component that uses navigation hooks
```

### Root Cause

React Router hooks (`useNavigate`, `useLocation`, `useParams`, etc.) can only be used inside a `<Router>` component. If a provider or component that uses these hooks is placed **outside** the Router in the component tree, this error occurs.

**Example of the problem (App.tsx):**
```tsx
// ❌ WRONG: QuotaProvider uses useNavigate but is outside Router
function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <QuotaProvider>  {/* Uses useNavigate for modal */}
          <Router>       {/* Router is too late in tree */}
            <AppContent />
          </Router>
        </QuotaProvider>
      </AuthProvider>
    </QueryClientProvider>
  );
}
```

### Solution

**Ensure Router wraps all components using navigation hooks:**

```tsx
// ✅ CORRECT: Router wraps QuotaProvider
function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <Router>
          <QuotaProvider>  {/* Now inside Router - useNavigate works */}
            <AppContent />
          </QuotaProvider>
        </Router>
      </AuthProvider>
    </QueryClientProvider>
  );
}
```

**Component tree rules:**
1. `<Router>` must be an ancestor of any component using Router hooks
2. Only `QueryClientProvider` and basic context providers should be above Router
3. Any provider that renders UI (modals, toasts) using navigation should be inside Router

**After fixing App.tsx:**

```bash
# Rebuild dashboard
cd /Users/pwner/Git/ABS
eval $(minikube docker-env)
docker build --no-cache -t blocksecops-dashboard:latest -f blocksecops-dashboard/Dockerfile .

# Restart deployment
kubectl rollout restart deployment/dashboard -n dashboard-local

# Verify pod is running
kubectl get pods -n dashboard-local -w
```

### Identifying Problematic Components

Look for components that:
1. Are providers/context that render modals or overlays
2. Use `useNavigate()` for redirects
3. Are placed outside `<Router>` in App.tsx

```bash
# Find all components using useNavigate
grep -rn "useNavigate()" blocksecops-dashboard/src/ --include="*.tsx"

# Check each one's position in the component tree
# If it's a context provider, ensure it's inside Router in App.tsx
```

### Common Affected Components

- `QuotaProvider` - Shows QuotaExceededModal with "Upgrade" button navigation
- `NotificationProvider` - May navigate on notification click
- `AuthProvider` - May redirect on auth state changes
- Any modal component with navigation buttons

### Reference

For the specific QuotaExceededModal fix, the component tree was corrected in:
- `/Users/pwner/Git/ABS/blocksecops-dashboard/src/App.tsx`

---

**Last Updated**: November 25, 2025
**Environment**: Local Development (Minikube)
