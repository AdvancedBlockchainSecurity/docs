# Dashboard Development Standards

**Version:** 1.8.0
**Last Updated:** October 20, 2025
**Status:** Active

## CRITICAL: Python 3.13 Compatibility Issue

**Problem:** The API service uses Python 3.13, which has stricter greenlet handling for SQLAlchemy async sessions. Direct use of `model_validate()` on SQLAlchemy models causes `MissingGreenlet` errors that result in 500 Internal Server Errors.

**Error Signature:**
```
pydantic_core._pydantic_core.ValidationError: 1 validation error for <ModelName>
<field_name>
  Error extracting attribute: MissingGreenlet: greenlet_spawn has not been called;
  can't call await_only() here. Was IO attempted in an unexpected place?
```

**Root Cause:** SQLAlchemy models have lazy-loaded relationships. When Pydantic tries to validate the model outside an async session context, Python 3.13's stricter greenlet handling prevents lazy loading.

**Solution:** ALWAYS use helper functions from `src/infrastructure/database/helpers.py`:

```python
from src.infrastructure.database.helpers import to_pydantic, to_pydantic_list

# ❌ WRONG - Will cause MissingGreenlet error
scan_response = ScanResponse.model_validate(scan)

# ✅ CORRECT - Refreshes model before validation
scan_response = await to_pydantic(db, scan, ScanResponse)

# For lists:
scans = await to_pydantic_list(db, scan_models, ScanResponse)
```

**Reference:** See `/Users/pwner/Git/ABS/blocksecops-api-service/docs/PYTHON-3.13-COMPATIBILITY.md` for full details.

## Proper Dashboard Startup Procedure

**CRITICAL:** Port-forwards can die during pod restarts. Always verify ALL port-forwards are running before testing.

### Step 1: Start Minikube and Services

```bash
# 1. Ensure Minikube is running
minikube status

# 2. If not running, start it
minikube start

# 3. Verify all services are deployed and running
kubectl get pods -A | grep -E "api-service|postgresql|redis|notification"

# Expected output - all should show "Running" status:
# api-service-local       api-service-xxxxx          1/1     Running   0          10m
# postgresql-local        postgresql-xxxxx           1/1     Running   0          2d
# redis-local             redis-xxxxx                1/1     Running   0          2d
# notification-local      notification-xxxxx         1/1     Running   0          1d
```

### Step 2: Verify Services Have Endpoints

**CRITICAL:** Services with no endpoints cannot be port-forwarded!

```bash
# Check all service endpoints
kubectl get endpoints -n api-service-local api-service
kubectl get endpoints -n postgresql-local postgresql
kubectl get endpoints -n redis-local redis
kubectl get endpoints -n notification-local notification

# ✅ GOOD: Shows IP addresses
# NAME          ENDPOINTS                AGE
# api-service   10.244.0.14:8000         2d

# ❌ BAD: No endpoints (selector mismatch)
# NAME          ENDPOINTS   AGE
# api-service   <none>      2d
```

**If any service shows `<none>` for endpoints:**
- Review [Local Development Setup - Kubernetes Service Selector Standards](./local-development-setup.md#kubernetes-service-selector-standards)
- Fix `includeSelectors: false` in kustomization.yaml
- Reapply: `kubectl apply -k k8s/overlays/local/<service>/`

### Step 3: Start Required Port-Forwards

**MANDATORY order:** Start port-forwards for ALL dependencies BEFORE starting dashboard.

```bash
# Kill any existing port-forwards first
ps aux | grep "port-forward" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null

# Wait for processes to die
sleep 2

# 1. PostgreSQL (required by API)
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 > /tmp/pf-postgresql.log 2>&1 &
echo "PostgreSQL port-forward started"

# 2. Redis (required by API)
kubectl port-forward -n redis-local svc/redis 6379:6379 > /tmp/pf-redis.log 2>&1 &
echo "Redis port-forward started"

# 3. API Service (required by Dashboard)
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
echo "API Service port-forward started"

# 4. Notification Service (required for WebSocket)
kubectl port-forward -n notification-local svc/notification 8003:80 > /tmp/pf-notification.log 2>&1 &
echo "Notification port-forward started"

# Wait for port-forwards to stabilize
sleep 3

# Verify all port-forwards are active
lsof -i :5432,6379,8000,8003 | grep LISTEN
```

**Why use `deployment/api-service` instead of `svc/api-service`?**
- Port-forwarding to a **service** creates a connection to the underlying pods
- Port-forwarding to a **deployment** automatically handles pod restarts
- When a pod is replaced (during rollout), deployment port-forward reconnects automatically
- Service port-forward will die when the old pod terminates

**Expected output:**
```
kubectl  48801  0.0  0.1 35597176  24408   ??  SN    6:21PM   0:00.54 kubectl port-forward... 8000
kubectl  48802  0.0  0.1 35597176  24408   ??  SN    6:21PM   0:00.54 kubectl port-forward... 5432
kubectl  48803  0.0  0.1 35597176  24408   ??  SN    6:21PM   0:00.54 kubectl port-forward... 6379
kubectl  48804  0.0  0.1 35597176  24408   ??  SN    6:21PM   0:00.54 kubectl port-forward... 8003
```

### Step 4: Verify API Health

**CRITICAL:** API must be healthy BEFORE starting dashboard.

```bash
# Test API health endpoint
curl -s http://127.0.0.1:8000/api/v1/health/live | jq '.'

# Expected output:
# {
#   "status": "healthy",
#   "service": "BlockSecOps API Service",
#   "version": "0.1.0",
#   "timestamp": "2025-10-17T18:25:00.123456"
# }

# Test API readiness (checks database connection)
curl -s http://127.0.0.1:8000/api/v1/health/ready | jq '.'

# Expected output:
# {
#   "status": "ready",
#   "database": "connected",
#   "redis": "connected"
# }
```

**If health checks fail:**

```bash
# 1. Check API logs for errors
kubectl logs -n api-service-local deployment/api-service --tail=50

# 2. Check port-forward logs
tail -50 /tmp/pf-api-service.log

# 3. Common issues:
#    - Port-forward died during pod restart
#    - Database connection failed
#    - Redis connection failed
#    - Service has no endpoints
```

### Step 5: Configure Dashboard Environment

**Verify dashboard `.env.local` exists and is correct:**

```bash
# Check if file exists
cat /Users/pwner/Git/ABS/blocksecops-dashboard/.env.local

# Expected content:
# VITE_API_BASE_URL=http://127.0.0.1:8000
# VITE_WS_URL=ws://127.0.0.1:8003/ws
# VITE_ENVIRONMENT=local
# VITE_DEBUG=true
```

**If file is missing or incorrect, create it:**

```bash
cat > /Users/pwner/Git/ABS/blocksecops-dashboard/.env.local <<'EOF'
# Dashboard local development environment
# MANDATORY: Use 127.0.0.1 for local development
VITE_API_BASE_URL=http://127.0.0.1:8000
VITE_WS_URL=ws://127.0.0.1:8003/ws

# Optional
VITE_ENVIRONMENT=local
VITE_DEBUG=true
EOF

echo "✅ Dashboard .env.local created"
```

### Step 6: Start Dashboard

```bash
# Navigate to dashboard directory
cd /Users/pwner/Git/ABS/blocksecops-dashboard

# Install dependencies (if not already installed)
npm install

# Start development server
npm run dev

# Expected output:
# VITE v5.0.0  ready in 500 ms
#
# ➜  Local:   http://localhost:5173/
# ➜  Network: use --host to expose
# ➜  press h to show help
```

**IMPORTANT:** Vite may assign a different port (5173, 5174, etc.) if 3000 is occupied. This is INCORRECT.

**If dashboard starts on wrong port:**

```bash
# 1. Stop the dashboard (Ctrl+C)

# 2. Find what's using port 3000
lsof -i :3000

# 3. Kill the process
lsof -ti :3000 | xargs kill -9

# 4. Restart dashboard
npm run dev

# 5. Verify it's on port 3000
lsof -i :3000 | grep LISTEN
```

### Step 7: Verify Dashboard Connectivity

```bash
# 1. Open browser to http://127.0.0.1:3000

# 2. Open browser console (F12)

# 3. Check for connection errors
#    ✅ GOOD: No errors, dashboard loads
#    ❌ BAD: "Network Error", "ERR_CONNECTION_REFUSED"

# 4. If errors occur, check:
curl -s http://127.0.0.1:8000/api/v1/health/live

# 5. Verify WebSocket connection
#    Browser console should show:
#    "WebSocket connected to ws://127.0.0.1:8003/ws"
```

## Troubleshooting Dashboard Issues

### Issue: "Network Error" or "ERR_CONNECTION_REFUSED"

**Root Cause:** API port-forward is not running.

**Solution:**
```bash
# 1. Check if API port-forward is running
ps aux | grep "port-forward.*8000" | grep -v grep

# 2. If not running, restart it
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &

# 3. Wait and test
sleep 3
curl http://127.0.0.1:8000/api/v1/health/live

# 4. Refresh dashboard browser page
```

### Issue: Port-forward keeps dying

**Root Cause:** Port-forwarding to a specific pod that gets replaced during rollouts.

**Solution:** Use deployment-based port-forward (auto-reconnects):
```bash
# ❌ BAD: Port-forward to service or pod
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &
kubectl port-forward -n api-service-local pod/api-service-xxxxx 8000:8000 &

# ✅ GOOD: Port-forward to deployment
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 &
```

### Issue: Port-forward dies after pod restart/rollout

**Symptom:**
```bash
# Port-forward process exists but API not responding
ps aux | grep "port-forward.*8000"
# Shows port-forward process running

curl http://127.0.0.1:8000/api/v1/health/live
# Connection refused or timeout

# Check port-forward logs
lsof -ti:8000 | xargs ps -p 2>/dev/null
# Shows error: "container not running" or "lost connection to pod"
```

**Root Cause:** Port-forward process remains running but points to old pod that was deleted during deployment rollout or pod restart. When you restart a deployment (e.g., after CORS config changes or code updates), Kubernetes creates a new pod and deletes the old one. Any port-forward to the old pod loses connection but the process stays alive, making it appear working.

**Diagnosis:**
```bash
# 1. Check if pod changed recently
kubectl get pods -n api-service-local -o wide
# Look at AGE column - if pod is very new, port-forwards may be stale

# 2. Check port-forward process details
ps aux | grep "port-forward.*8000" | grep -v grep
# Look for the pod ID in the command - does it match current pod?

# 3. Check for "container not running" errors
lsof -ti:8000 | xargs ps -p 2>/dev/null
# or check /tmp/pf-*.log files if you logged port-forward output
```

**Solution:**
```bash
# 1. Kill ALL stale port-forwards on port 8000
ps aux | grep "kubectl port-forward" | grep "8000:8000" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null

# Alternative: Kill by port
lsof -ti:8000 | xargs kill -9 2>/dev/null

# 2. Wait for processes to die
sleep 2

# 3. Start fresh port-forward to DEPLOYMENT (not service/pod)
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 --address=127.0.0.1 > /tmp/pf-api.log 2>&1 &

# 4. Verify working
sleep 2
curl -s http://127.0.0.1:8000/api/v1/health/live
# Should return: {"status":"healthy","service":"BlockSecOps API Service"...}
```

**Prevention:**
- **Use deployment-based port-forwards** instead of service/pod port-forwards
- Deployment port-forwards automatically reconnect when pods are replaced
- After any `kubectl rollout restart` or config change, restart port-forwards
- Consider adding port-forward health checks to startup scripts

**Example - After Config Changes:**
```bash
# Scenario: Updated CORS configuration in configmap

# 1. Apply config changes
kubectl apply -k k8s/overlays/local/api-service

# 2. Restart deployment to pick up changes
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 3. IMMEDIATELY restart port-forwards (pod has been replaced)
lsof -ti:8000 | xargs kill -9 2>/dev/null
sleep 2
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 --address=127.0.0.1 &

# 4. Verify API is accessible
curl -s http://127.0.0.1:8000/api/v1/health/live
```

**Why deployment port-forward is better:**
- Service port-forward: Goes through service → endpoint → pod (breaks when pod changes)
- Pod port-forward: Direct to specific pod (breaks when that pod is deleted)
- Deployment port-forward: Follows deployment's current pod (auto-reconnects on pod replacement)

### Issue: "MissingGreenlet" error when creating scans

**Root Cause:** Endpoint uses direct `model_validate()` instead of helper functions.

**Solution:** All endpoints MUST use `to_pydantic()` or `to_pydantic_list()`:

```python
# Find the problematic endpoint
grep -n "model_validate" src/presentation/api/v1/endpoints/*.py

# Replace with helper function:
from src.infrastructure.database.helpers import to_pydantic

# Before:
return ScanResponse.model_validate(scan)

# After:
return await to_pydantic(db, scan, ScanResponse)
```

**Reference:** See Python 3.13 Compatibility section above and `/Users/pwner/Git/ABS/blocksecops-api-service/docs/PYTHON-3.13-COMPATIBILITY.md`

### Issue: Service has no endpoints

**Symptom:**
```bash
kubectl get endpoints -n api-service-local api-service
# NAME          ENDPOINTS   AGE
# api-service   <none>      2d
```

**Root Cause:** `includeSelectors: true` in kustomization.yaml adds too many labels to selector.

**Solution:** See [Local Development Setup - Kubernetes Service Selector Standards](./local-development-setup.md#kubernetes-service-selector-standards)

## Dashboard Development Workflow

**Daily development workflow:**

```bash
# 1. Verify Minikube is running
minikube status

# 2. Check all services are healthy
kubectl get pods -A | grep -v "kube-system"

# 3. Start port-forwards (if not already running)
ps aux | grep "port-forward" | grep -v grep || {
  kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 > /tmp/pf-postgresql.log 2>&1 &
  kubectl port-forward -n redis-local svc/redis 6379:6379 > /tmp/pf-redis.log 2>&1 &
  kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
  kubectl port-forward -n notification-local svc/notification 8003:80 > /tmp/pf-notification.log 2>&1 &
  sleep 3
}

# 4. Verify API is healthy
curl -s http://127.0.0.1:8000/api/v1/health/ready | jq '.status'

# 5. Start dashboard (if not already running)
cd /Users/pwner/Git/ABS/blocksecops-dashboard
npm run dev

# 6. Open browser to http://127.0.0.1:3000

# 7. Develop and test features
```

**After pulling code changes:**

```bash
# 1. Pull latest code
cd /Users/pwner/Git/ABS/blocksecops-api-service
git pull

# 2. Build new Docker image
eval $(minikube docker-env)
docker build -t api-service:0.3.20 .

# 3. Update deployment
kubectl set image -n api-service-local deployment/api-service api-service=api-service:0.3.20

# 4. Wait for rollout
kubectl rollout status -n api-service-local deployment/api-service

# 5. Port-forward should auto-reconnect (using deployment)
#    If using service/pod port-forward, restart it manually:
ps aux | grep "port-forward.*8000" | grep -v grep || {
  kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
}

# 6. Verify API health
curl http://127.0.0.1:8000/api/v1/health/live

# 7. Refresh dashboard browser page
```

## Dashboard Development Checklist

**Before starting development:**

- [ ] Minikube running (`minikube status`)
- [ ] All services deployed and healthy (`kubectl get pods -A`)
- [ ] All services have endpoints (`kubectl get endpoints -A | grep -v kube-system`)
- [ ] PostgreSQL port-forward active on 5432
- [ ] Redis port-forward active on 6379
- [ ] API port-forward active on 8000 (use deployment, not service!)
- [ ] Notification port-forward active on 8003
- [ ] API health check passing (`curl http://127.0.0.1:8000/api/v1/health/ready`)
- [ ] Dashboard `.env.local` configured correctly
- [ ] Dashboard running on port 3000 (not 5173 or other)
- [ ] Can access dashboard at `http://127.0.0.1:3000`
- [ ] No console errors in browser (F12 → Console tab)

**After code changes:**

- [ ] Code changes committed to Git
- [ ] Docker image built with incremented version
- [ ] Deployment updated to new image version
- [ ] Rollout completed successfully
- [ ] Port-forwards reconnected (if needed)
- [ ] API health check passing
- [ ] Dashboard refreshed in browser
- [ ] Feature tested and verified

---

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Local Development Setup](./local-development-setup.md) - Local development standards and setup
- [Testing & Deployment](./testing-deployment.md) - Testing and deployment workflows
