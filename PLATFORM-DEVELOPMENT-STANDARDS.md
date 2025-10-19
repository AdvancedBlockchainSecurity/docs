# Platform Development Standards

**Version:** 1.6.0
**Last Updated:** October 19, 2025
**Status:** Active

## Table of Contents

1. [Overview](#overview)
2. [Critical Rules](#critical-rules)
3. [Codebase-First Development](#codebase-first-development)
4. [Local Development Standards](#local-development-standards)
5. [Database Management and Recovery](#database-management-and-recovery)
6. [Documentation Requirements](#documentation-requirements)
7. [Version Control Standards](#version-control-standards)
8. [Testing Standards](#testing-standards)
9. [Deployment Workflow](#deployment-workflow)
10. [Compliance Checklist](#compliance-checklist)
11. [Docker Image Versioning Standards](#docker-image-versioning-standards)
12. [Tool Metadata Management via ConfigMaps](#tool-metadata-management-via-configmaps)

---

## Overview

This document defines mandatory development standards for the BlockSecOps Platform. These standards ensure:

- **Reproducibility** through code-first development
- **Traceability** of all platform changes
- **Consistency** across development environments
- **Safety** through documented change processes
- **Collaboration** through clear standards

**All platform changes MUST comply with these standards without exception.**

---

## Critical Rules

### Rule 1: Codebase-First Development

**MANDATORY:** Never make changes to the platform or Kubernetes without updating the codebase first.

```
✅ CORRECT WORKFLOW:
1. Create feature branch from main
2. Update configuration files in Git repo folder
3. Commit changes to version control
4. Push feature branch and create pull request
5. Review and merge PR (user account only)
6. Apply changes to Kubernetes/platform
7. Verify changes work as expected
8. Document changes in relevant docs

❌ INCORRECT WORKFLOW:
1. Make ad-hoc changes via kubectl
2. Test changes in cluster
3. Forget to update codebase
4. Changes lost on next deployment
```

**Why this matters:**
- **Reproducibility:** Changes not in code cannot be reproduced
- **Collaboration:** Team members unaware of ad-hoc changes
- **Disaster Recovery:** Cannot rebuild platform without code
- **Audit Trail:** No record of what changed or why
- **Debugging:** Impossible to diff actual state vs intended state

**Violations of this rule are considered CRITICAL incidents.**

### Rule 2: Local Development Endpoint

**MANDATORY:** Always use `127.0.0.1` to access the dashboard for local development.

```
✅ CORRECT:
- Dashboard access: http://127.0.0.1:3000
- API access: http://127.0.0.1:8000
- Port forwards: kubectl port-forward svc/api-service 8000:8000

❌ INCORRECT:
- Dashboard access: http://localhost:3000
- API access: http://localhost:8000
```

**CORS Configuration Requirement:**

All backend services MUST include `127.0.0.1` in CORS allowed origins:

```python
# Python FastAPI example
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:3000",  # MANDATORY for local development
        "http://localhost:3000",   # Optional for compatibility
        "https://app.blocksecops.com",  # Production
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Why `127.0.0.1` instead of `localhost`:**
- **DNS Resolution:** Avoids IPv4/IPv6 resolution issues
- **Consistency:** Same behavior across all systems
- **Performance:** Bypasses DNS lookups
- **CORS Clarity:** Explicit IP-based origin

### Rule 3: Restart Pods After Code Changes

**MANDATORY:** After merging code changes or pulling latest code, pods must be restarted to pick up the new changes.

```
✅ CORRECT WORKFLOW:
1. Create feature branch from main
2. Make code changes and commit to feature branch
3. Push feature branch and create pull request
4. Review and merge PR (user account only)
5. Pull latest code: git pull origin main
6. Build and push new Docker image (if image-based deployment)
7. Restart deployment: kubectl rollout restart deployment/<service> -n <namespace>
8. Wait for rollout: kubectl rollout status deployment/<service> -n <namespace>
9. Verify changes are active

❌ INCORRECT WORKFLOW:
1. Make changes directly on main branch
2. Commit and push to main
3. Pull latest code
4. Assume running pods will pick up changes automatically
5. Wonder why new features don't work
```

**When Pod Restarts Are Required:**
- After merging code changes (API service, workers, etc.)
- After pulling latest code from main branch
- After configuration changes in ConfigMaps or Secrets
- After updating environment variables
- After dependency updates (requirements.txt, package.json, etc.)

**Example - Restarting Services After Code Merge:**

```bash
# 1. Pull latest code
cd /Users/pwner/Git/ABS/blocksecops-api-service
git checkout main
git pull

# 2. Restart the API service pod to pick up changes
kubectl rollout restart deployment/api-service -n api-service-local

# 3. Wait for rollout to complete
kubectl rollout status deployment/api-service -n api-service-local

# 4. Verify new code is running
kubectl logs -n api-service-local -l app.kubernetes.io/name=api-service --tail=20

# 5. Verify API health
curl -s http://127.0.0.1:8000/api/v1/health/ready | jq '.'
```

**Common Services That Need Restart:**

```bash
# API Service (after backend code changes)
kubectl rollout restart deployment/api-service -n api-service-local

# Data Service (after data processing code changes)
kubectl rollout restart deployment/data-service -n data-service-local

# Tool Integration (after scanner integration changes)
kubectl rollout restart deployment/tool-integration -n tool-integration-local

# Workers (after background job code changes)
kubectl rollout restart deployment/celery-worker -n workers-local
```

**Why This Matters:**
- **Stale Code:** Running pods continue using old code until restarted
- **Testing Failures:** New features won't work if pods aren't restarted
- **Confusing Bugs:** Seeing old behavior when expecting new fixes
- **Wasted Time:** Debugging issues that don't exist in the new code

**Port Forward Note:** After restarting API service, you may need to restart the port-forward:

```bash
# Kill old port-forward
ps aux | grep "port-forward.*svc/api-service" | grep -v grep | awk '{print $2}' | xargs kill

# Start new port-forward
kubectl port-forward -n api-service-local svc/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
```

---

## Codebase-First Development

### What Must Be in Code

**ALL of the following MUST exist in Git before being applied:**

1. **Kubernetes Manifests**
   - Deployments, Services, ConfigMaps
   - Secrets (via External Secrets, not values)
   - Ingress rules, Network Policies
   - RBAC roles and bindings

2. **Configuration Files**
   - Application configs (`.env.example`, `config.yaml`)
   - Infrastructure configs (Terraform, Kustomize)
   - Build configs (Dockerfiles, build scripts)

3. **Database Changes**
   - Migration scripts
   - Schema definitions
   - Seed data scripts

4. **Infrastructure Changes**
   - Terraform modules and variables
   - Helm charts and values
   - Kustomize bases and overlays

5. **Scripts and Automation**
   - Deployment scripts
   - Backup/restore scripts
   - Maintenance scripts

### Workflow for Platform Changes

#### Making Kubernetes Changes

```bash
# 1. NEVER do this directly
kubectl edit deployment api-service -n api-service-local  ❌

# 2. ALWAYS do this instead
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/api-service

# 3. Edit the manifest file
vim deployment-patch.yaml

# 4. Commit the change
git add deployment-patch.yaml
git commit -m "Update API service memory limits

- Increase memory limit from 512Mi to 1Gi
- Required for handling larger scan payloads

Refs: #123"

# 5. Apply from code
kubectl apply -k .

# 6. Verify change
kubectl get deployment api-service -n api-service-local -o yaml | grep memory
```

#### Making Configuration Changes

```bash
# 1. Update configuration file in repository
cd /Users/pwner/Git/ABS/blocksecops-api-service
vim src/config.py

# 2. Update corresponding ConfigMap
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/api-service
vim configmap-patch.yaml

# 3. Commit both changes together
git add ../../blocksecops-api-service/src/config.py
git add configmap-patch.yaml
git commit -m "Add request timeout configuration

- Add REQUEST_TIMEOUT_SECONDS to config
- Default: 30 seconds
- Configurable via environment variable"

# 4. Rebuild and deploy
cd /Users/pwner/Git/ABS/blocksecops-api-service
docker build -t localhost:8080/library/api-service:0.3.7 .
docker push localhost:8080/library/api-service:0.3.7

# 5. Apply ConfigMap changes
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
kubectl apply -k k8s/overlays/local/api-service

# 6. Restart deployment to pick up changes
kubectl rollout restart deployment api-service -n api-service-local
```

#### Emergency Hotfixes

**Even in emergencies, follow this process:**

```bash
# 1. Make temporary fix (if absolutely necessary)
kubectl patch deployment api-service -n api-service-local \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-service","resources":{"limits":{"memory":"2Gi"}}}]}}}}'

# 2. IMMEDIATELY document the change
echo "EMERGENCY HOTFIX: Increased API service memory to 2Gi at $(date)" >> HOTFIX.log

# 3. Within 1 hour, update the codebase
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/api-service
vim deployment-patch.yaml
git add deployment-patch.yaml
git commit -m "HOTFIX: Increase API service memory to 2Gi

Emergency fix applied at [timestamp]
Root cause: Memory leak in scan result processing
Permanent fix tracked in: #456"

# 4. Verify code matches running state
kubectl diff -k k8s/overlays/local/api-service
```

### Documentation Requirements for Changes

**Every platform change MUST include:**

1. **Commit Message** with:
   - Clear description of what changed
   - Why the change was necessary
   - Impact assessment
   - Reference to issue/ticket (if applicable)

2. **Update Summary Document** (for significant changes):
   ```markdown
   # Change Summary: [Brief Title]

   **Date:** YYYY-MM-DD
   **Author:** [Your Name]
   **Services Affected:** api-service, data-service

   ## What Changed
   - [Specific change 1]
   - [Specific change 2]

   ## Why
   [Rationale for the change]

   ## Impact
   - Performance: [impact]
   - Availability: [impact]
   - Dependencies: [impact]

   ## Rollback Plan
   [How to revert if needed]

   ## Verification
   - [ ] Code committed and pushed
   - [ ] Changes applied to local environment
   - [ ] Tests passing
   - [ ] Monitoring confirms expected behavior
   ```

3. **Update Relevant Docs**:
   - Architecture docs if structure changed
   - Deployment guides if process changed
   - Troubleshooting guides if behavior changed

---

## Local Development Standards

### Access Endpoints

**MANDATORY endpoints for local development:**

| Service | Endpoint | Notes |
|---------|----------|-------|
| Dashboard | `http://127.0.0.1:3000` | Frontend React app |
| API Service | `http://127.0.0.1:8000` | FastAPI backend |
| API Docs | `http://127.0.0.1:8000/docs` | Swagger UI |
| Notification | `http://127.0.0.1:8003` | WebSocket server |
| Grafana | `http://127.0.0.1:3001` | Monitoring dashboard |
| Prometheus | `http://127.0.0.1:9090` | Metrics (when forwarded) |

### Port Forward Standards

**Standard port-forward script** (save as `scripts/port-forward-local.sh`):

```bash
#!/bin/bash
# Port forward all local development services

echo "Starting port forwards for local development..."

# Kill existing port forwards
lsof -ti:3000,8000,8003,3001 | xargs kill -9 2>/dev/null

# Dashboard
kubectl port-forward -n dashboard-local svc/dashboard 3000:80 &
echo "✅ Dashboard: http://127.0.0.1:3000"

# API Service
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &
echo "✅ API Service: http://127.0.0.1:8000"

# Notification Service
kubectl port-forward -n notification-local svc/notification 8003:8003 &
echo "✅ Notification: http://127.0.0.1:8003"

# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3001:80 &
echo "✅ Grafana: http://127.0.0.1:3001"

echo ""
echo "All port forwards active. Use 127.0.0.1 for all connections."
```

### Port Number Consistency Standards

**CRITICAL:** Never change port numbers without updating all dependent configurations.

**Why this matters:**
- **Platform Consistency:** Changing port numbers breaks integrations across the platform
- **CORS Configuration:** Backend services whitelist specific ports
- **Documentation Accuracy:** All docs reference standard ports
- **Team Coordination:** Other developers expect services on standard ports
- **Testing Scripts:** Automated tests hardcode port numbers

**Standard Port Assignments:**

| Service | Port | Purpose | Notes |
|---------|------|---------|-------|
| Dashboard | 3000 | Frontend UI | Primary user interface |
| API Service | 8000 | Backend API | FastAPI application |
| Notification | 8003 | WebSocket | Real-time notifications |
| Grafana | 3001 | Monitoring | Metrics dashboard |
| PostgreSQL | 5432 | Database | Port-forwarded only |
| Redis | 6379 | Cache | Port-forwarded only |

**If a port is occupied:**

```bash
# ❌ INCORRECT: Let service pick next available port
npm run dev  # Picks port 3002, 3003, etc.

# ✅ CORRECT: Free up the standard port
lsof -ti:3000 | xargs kill -9  # Kill process using port 3000
npm run dev  # Now uses port 3000
```

**When ports conflict during development:**

```bash
# 1. Identify what's using the port
lsof -i:3000

# 2. If it's an old/stale process, kill it
kill -9 <PID>

# 3. If it's a legitimate service, check if it should be running
ps aux | grep <process-name>

# 4. Restart the service on the correct port
# (Example for dashboard)
cd /Users/pwner/Git/ABS/blocksecops-dashboard
npm run dev
```

### Kubernetes Service Selector Standards

**CRITICAL:** Service selectors must match pod labels, or services will have no endpoints.

#### The includeSelectors Problem

**Issue:** Kustomize `includeSelectors: true` adds ALL common labels to service selectors, creating mismatches.

**Example of the problem:**

```yaml
# kustomization.yaml with includeSelectors: true
labels:
- includeSelectors: true  # ❌ DANGEROUS
  pairs:
    app.kubernetes.io/name: api-service
    app.kubernetes.io/instance: local-api-service
    app.kubernetes.io/version: 0.3.12
    app.kubernetes.io/component: backend-api
    app.kubernetes.io/part-of: blocksecops-platform
    app.kubernetes.io/managed-by: kustomize
    environment: local
    team: backend
```

**Result:** Service selector gets 8 labels, but deployment only adds 3 labels to pod template:

```yaml
# Service selector (8 labels)
selector:
  app.kubernetes.io/name: api-service
  app.kubernetes.io/instance: local-api-service
  app.kubernetes.io/version: 0.3.12
  app.kubernetes.io/component: backend-api
  app.kubernetes.io/part-of: blocksecops-platform
  app.kubernetes.io/managed-by: kustomize
  environment: local
  team: backend

# Pod labels (only 3 labels)
labels:
  app.kubernetes.io/name: api-service
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: blocksecops-platform
```

**Result:** Service has NO ENDPOINTS because selector doesn't match pods.

```bash
$ kubectl get endpoints -n api-service-local api-service
NAME          ENDPOINTS   AGE
api-service   <none>      10d
```

#### The Solution: includeSelectors: false

**MANDATORY:** Always set `includeSelectors: false` in Kustomize overlays.

```yaml
# ✅ CORRECT: includeSelectors: false
labels:
- includeSelectors: false  # Only adds labels to metadata, not selectors
  pairs:
    app.kubernetes.io/name: api-service
    app.kubernetes.io/instance: local-api-service
    app.kubernetes.io/version: 0.3.12
    app.kubernetes.io/component: backend-api
    app.kubernetes.io/part-of: blocksecops-platform
    app.kubernetes.io/managed-by: kustomize
    environment: local
    team: backend
```

**Result:** Service selector uses only the labels defined in base service manifest:

```yaml
# Service selector (minimal, matches pods)
selector:
  app.kubernetes.io/name: api-service

# Pod labels (matches selector)
labels:
  app.kubernetes.io/name: api-service
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: blocksecops-platform
```

**Verification:**

```bash
# 1. Check service selector
kubectl get svc -n api-service-local api-service -o jsonpath='{.spec.selector}' | jq .

# 2. Check pod labels
kubectl get pods -n api-service-local -l app.kubernetes.io/name=api-service -o jsonpath='{.items[0].metadata.labels}' | jq .

# 3. Verify service has endpoints
kubectl get endpoints -n api-service-local api-service

# ✅ GOOD: Shows IP addresses and ports
# NAME          ENDPOINTS                           AGE
# api-service   10.244.4.14:9090,10.244.4.14:8000   10d

# ❌ BAD: No endpoints (selector mismatch)
# NAME          ENDPOINTS   AGE
# api-service   <none>      10d
```

#### Service Selector Best Practices

**1. Keep selectors minimal** - Only use labels that uniquely identify the pod:

```yaml
# ✅ GOOD: Minimal, specific selector
selector:
  app.kubernetes.io/name: api-service

# ❌ BAD: Too many labels
selector:
  app.kubernetes.io/name: api-service
  app.kubernetes.io/version: 0.3.12  # Version changes with each release!
  environment: local
  team: backend
```

**2. Base service defines selector** - Overlay only patches if absolutely necessary:

```yaml
# base/api-service/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app.kubernetes.io/name: api-service  # ✅ Simple, stable selector
  ports:
  - name: http
    port: 8000
    targetPort: http
```

**3. Never change selectors in overlays** - Use service-patch.yaml only for ports/annotations:

```yaml
# overlays/local/service-patch.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
  annotations:
    prometheus.io/scrape: "true"
spec:
  type: NodePort
  ports:
  - name: http
    port: 8000
    targetPort: 8000
    nodePort: 30800
  # ✅ NO selector override - uses base service selector
```

#### Troubleshooting Service Endpoints

**Symptom:** Service has no endpoints, port-forward fails, API not accessible

**Diagnosis:**

```bash
# 1. Check if service has endpoints
kubectl get endpoints -n <namespace> <service-name>

# 2. If no endpoints, check selector vs pod labels
kubectl get svc -n <namespace> <service-name> -o yaml | grep -A 10 "selector:"
kubectl get pods -n <namespace> -o yaml | grep -A 10 "labels:"

# 3. Check kustomization.yaml for includeSelectors
cat k8s/overlays/local/kustomization.yaml | grep -A 2 "includeSelectors"
```

**Fix:**

```bash
# 1. Update kustomization.yaml
cd /Users/pwner/Git/ABS/blocksecops-<service>/k8s/overlays/local
vim kustomization.yaml

# Change:
# includeSelectors: true
# To:
# includeSelectors: false

# 2. Apply changes
kubectl apply -k .

# 3. Verify endpoints now exist
kubectl get endpoints -n <namespace> <service-name>

# 4. Test connectivity
kubectl port-forward -n <namespace> svc/<service-name> <port>:<port> &
sleep 2
curl http://localhost:<port>/health
```

#### Standard Kustomization Pattern

**Use this pattern for ALL service overlays:**

```yaml
# k8s/overlays/local/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- ../../base/

namespace: <service>-local

patches:
- path: deployment-patch.yaml
  target:
    kind: Deployment
    name: <service>
- path: configmap-patch.yaml
  target:
    kind: ConfigMap
    name: <service>-config
- path: service-patch.yaml
  target:
    kind: Service
    name: <service>

images:
- name: PLACEHOLDER_REGISTRY/<service>
  newName: <service>
  newTag: 0.1.0

# ✅ CRITICAL: includeSelectors MUST be false
labels:
- includeSelectors: false  # Never change this to true!
  pairs:
    app.kubernetes.io/name: <service>
    app.kubernetes.io/instance: local-<service>
    app.kubernetes.io/version: 0.1.0
    app.kubernetes.io/component: backend-api
    app.kubernetes.io/part-of: blocksecops-platform
    app.kubernetes.io/managed-by: kustomize
    environment: local
    team: backend
```

### Environment Configuration

**Required `.env.local` for dashboard** (never commit this file):

```bash
# Dashboard local development environment
# Location: blocksecops-dashboard/.env.local

# MANDATORY: Use 127.0.0.1 for local development
VITE_API_BASE_URL=http://127.0.0.1:8000
VITE_WS_URL=ws://127.0.0.1:8003

# Optional
VITE_ENVIRONMENT=local
VITE_DEBUG=true
```

**CORS Configuration Template:**

```python
# Location: blocksecops-api-service/src/infrastructure/middleware/cors.py

from fastapi.middleware.cors import CORSMiddleware
from src.config import settings

def configure_cors(app):
    """Configure CORS for all environments."""

    # Base origins (always allowed)
    origins = [
        "http://127.0.0.1:3000",  # MANDATORY: Local development
        "http://localhost:3000",   # Optional: Compatibility
    ]

    # Add environment-specific origins
    if settings.ENVIRONMENT == "staging":
        origins.append("https://staging.blocksecops.com")
    elif settings.ENVIRONMENT == "production":
        origins.append("https://app.blocksecops.com")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
```

### Local Development Checklist

Before starting development work:

- [ ] Minikube cluster is running
- [ ] All required services deployed
- [ ] Port forwards configured to use `127.0.0.1`
- [ ] Dashboard running on correct port 3000 (not 3002 or other)
- [ ] API service running on correct port 8000
- [ ] Dashboard `.env.local` uses `127.0.0.1` endpoints
- [ ] Backend CORS includes `127.0.0.1:3000`
- [ ] All services have endpoints: `kubectl get endpoints -n <namespace>`
- [ ] Can access dashboard at `http://127.0.0.1:3000`
- [ ] Can access API docs at `http://127.0.0.1:8000/docs`

---

## Dashboard Development Setup

### CRITICAL: Python 3.13 Compatibility Issue

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

### Proper Dashboard Startup Procedure

**CRITICAL:** Port-forwards can die during pod restarts. Always verify ALL port-forwards are running before testing.

#### Step 1: Start Minikube and Services

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

#### Step 2: Verify Services Have Endpoints

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
- Review [Kubernetes Service Selector Standards](#kubernetes-service-selector-standards)
- Fix `includeSelectors: false` in kustomization.yaml
- Reapply: `kubectl apply -k k8s/overlays/local/<service>/`

#### Step 3: Start Required Port-Forwards

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

#### Step 4: Verify API Health

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

#### Step 5: Configure Dashboard Environment

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

#### Step 6: Start Dashboard

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

#### Step 7: Verify Dashboard Connectivity

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

### Troubleshooting Dashboard Issues

#### Issue: "Network Error" or "ERR_CONNECTION_REFUSED"

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

#### Issue: Port-forward keeps dying

**Root Cause:** Port-forwarding to a specific pod that gets replaced during rollouts.

**Solution:** Use deployment-based port-forward (auto-reconnects):
```bash
# ❌ BAD: Port-forward to service or pod
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &
kubectl port-forward -n api-service-local pod/api-service-xxxxx 8000:8000 &

# ✅ GOOD: Port-forward to deployment
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 &
```

#### Issue: Port-forward dies after pod restart/rollout

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

**Related:** See [Dashboard Development Setup](#dashboard-development-setup) for complete port-forward startup procedures.

#### Issue: "MissingGreenlet" error when creating scans

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

#### Issue: Service has no endpoints

**Symptom:**
```bash
kubectl get endpoints -n api-service-local api-service
# NAME          ENDPOINTS   AGE
# api-service   <none>      2d
```

**Root Cause:** `includeSelectors: true` in kustomization.yaml adds too many labels to selector.

**Solution:** See [Kubernetes Service Selector Standards](#kubernetes-service-selector-standards)

### Dashboard Development Workflow

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

### Dashboard Development Checklist

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

## Database Management and Recovery

### Critical Database Safety Rules

**MANDATORY:** Never apply configuration changes to a running database without backups.

```
✅ CORRECT WORKFLOW:
1. Create database backup
2. Verify backup is valid
3. Apply configuration changes
4. Test database connectivity
5. Verify data integrity

❌ INCORRECT WORKFLOW:
1. Apply configuration changes to running database
2. Restart database to pick up changes
3. Discover authentication is broken
4. No backup available for recovery
```

**Why this matters:**
- **Data Loss Prevention:** Database corruption without backups means permanent data loss
- **Development Continuity:** Lost work impacts entire team
- **Configuration Safety:** Can safely test changes knowing recovery is possible
- **Debugging:** Can compare working vs broken state
- **Compliance:** Backup procedures required for production readiness

**Violations of this rule can result in unrecoverable data loss.**

### Rule 3: Automated Local Development Backups

**MANDATORY:** Create automated daily backups of local development databases.

#### PostgreSQL Backup Script

Create `/Users/pwner/Git/ABS/scripts/backup-local-db.sh`:

```bash
#!/bin/bash
# Automated PostgreSQL backup for local development
# Run daily via cron: 0 2 * * * /Users/pwner/Git/ABS/scripts/backup-local-db.sh

set -euo pipefail

# Configuration
BACKUP_DIR="/Users/pwner/Git/ABS/backups/postgresql"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="solidity_security"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Port forward PostgreSQL (if not already running)
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
PF_PID=$!
sleep 3

# Create backup
echo "Creating backup: ${DB_NAME}_${TIMESTAMP}.sql"
PGPASSWORD=postgres pg_dump \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d "$DB_NAME" \
  -F c \
  -f "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"

# Compress backup
gzip "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"

# Kill port forward
kill $PF_PID 2>/dev/null || true

# Verify backup
if [ -f "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz" ]; then
  SIZE=$(du -h "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz" | cut -f1)
  echo "✅ Backup created successfully: ${SIZE}"
else
  echo "❌ Backup failed!"
  exit 1
fi

# Clean up old backups (keep last RETENTION_DAYS days)
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "✅ Cleaned up backups older than $RETENTION_DAYS days"

echo "Backup complete: ${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
```

**Make script executable:**

```bash
chmod +x /Users/pwner/Git/ABS/scripts/backup-local-db.sh
```

**Set up automated backups (cron):**

```bash
# Open crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /Users/pwner/Git/ABS/scripts/backup-local-db.sh >> /Users/pwner/Git/ABS/logs/backup.log 2>&1
```

#### Manual Backup Before Changes

**Before applying ANY database configuration changes:**

```bash
# 1. Create immediate backup
cd /Users/pwner/Git/ABS
./scripts/backup-local-db.sh

# 2. Verify backup exists
ls -lh backups/postgresql/

# 3. Test backup integrity
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3
PGPASSWORD=postgres pg_restore --list \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  backups/postgresql/solidity_security_*.sql.gz | head -20

# 4. NOW proceed with changes
```

### Database Recovery Procedures

#### Quick Recovery from Backup

If database becomes corrupted or inaccessible:

```bash
# 1. Find most recent backup
ls -lt /Users/pwner/Git/ABS/backups/postgresql/

# 2. Scale down PostgreSQL
kubectl scale deployment postgresql -n postgresql-local --replicas=0

# 3. Delete corrupted PVC
kubectl delete pvc postgresql-data -n postgresql-local

# 4. Scale up PostgreSQL (creates new PVC)
kubectl scale deployment postgresql -n postgresql-local --replicas=1
kubectl rollout status deployment postgresql -n postgresql-local

# 5. Wait for PostgreSQL to be ready
sleep 10

# 6. Port forward PostgreSQL
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3

# 7. Create database
PGPASSWORD=postgres psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -c "CREATE DATABASE solidity_security;"

# 8. Restore from backup
BACKUP_FILE="/Users/pwner/Git/ABS/backups/postgresql/solidity_security_YYYYMMDD_HHMMSS.sql.gz"
gunzip -c "$BACKUP_FILE" | PGPASSWORD=postgres pg_restore \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  --no-owner \
  --no-acl \
  -v

# 9. Verify data restored
PGPASSWORD=postgres psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  -c "\dt" \
  -c "SELECT COUNT(*) FROM users;"

# 10. Restart API service to reconnect
kubectl rollout restart deployment api-service -n api-service-local
```

#### Emergency Recovery Without Backup

**IF NO BACKUP EXISTS (data loss inevitable):**

```bash
# 1. Scale down PostgreSQL
kubectl scale deployment postgresql -n postgresql-local --replicas=0

# 2. Delete corrupted PVC
kubectl delete pvc postgresql-data -n postgresql-local
echo "⚠️  WARNING: All database data will be lost!"

# 3. Scale up PostgreSQL (fresh start)
kubectl scale deployment postgresql -n postgresql-local --replicas=1
kubectl rollout status deployment postgresql -n postgresql-local

# 4. Wait for PostgreSQL initialization
sleep 15

# 5. Port forward
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3

# 6. Create database
PGPASSWORD=postgres psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -c "CREATE DATABASE solidity_security;"

# 7. Run Alembic migrations to recreate schema
cd /Users/pwner/Git/ABS/blocksecops-api-service
source .venv/bin/activate
export DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/solidity_security"
alembic upgrade head

# 8. Create test user
PGPASSWORD=postgres psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  -c "INSERT INTO users (id, email, password_hash, created_at) VALUES (
    '45b0f212-e9d5-4030-b489-4896ae1263cf',
    'test-rebrand@blocksecops.com',
    '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5TS0PgEqZQC6m',
    NOW()
  );"

# 9. Restart API service
kubectl rollout restart deployment api-service -n api-service-local

# 10. Test login
curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test-rebrand@blocksecops.com","password":"TestPass123"}'
```

### Pre-Change Checklist for Database Configuration

Before applying ANY changes to database configuration:

- [ ] **Backup created** - Run `./scripts/backup-local-db.sh`
- [ ] **Backup verified** - Confirm file exists and is valid
- [ ] **Changes documented** - Know exactly what will change
- [ ] **Rollback plan ready** - Know how to revert changes
- [ ] **Team notified** - If shared development environment

**NEVER skip the backup step. Data loss is NOT acceptable.**

### Cautionary Example: Database Corruption Incident (October 16, 2025)

#### What Happened

On October 16, 2025, a simple CORS configuration change resulted in complete loss of the local development database:

1. **Initial Change:** Updated CORS configuration in `configmap-patch.yaml` to prioritize `127.0.0.1`
2. **Applied Change:** Ran `kubectl apply -k k8s/overlays/local/api-service`
3. **Unintended Effect:** Kustomize also created/updated an ExternalSecret, changing database credentials
4. **First Problem:** API service couldn't authenticate to PostgreSQL (wrong password)
5. **Troubleshooting:** Multiple PostgreSQL restarts while attempting to fix authentication
6. **Second Problem:** Discovered PostgreSQL required SSL connections (from Sprint 14 Security Hardening)
7. **Attempted Fix:** Created local overlay to disable SSL for development
8. **Critical Failure:** PostgreSQL `pg_authid` file corrupted during multiple restarts
9. **Data Loss:** Database files intact but no users/roles exist - authentication system destroyed
10. **No Recovery:** No backups available - 10 days of development data lost permanently

#### Root Causes

1. **No backups** - No automated or manual backups of local development database
2. **Dangerous changes** - Applied configuration changes to running database without safety net
3. **Incomplete understanding** - Didn't realize ExternalSecret would be created
4. **Multiple restarts** - Restarted PostgreSQL multiple times during troubleshooting
5. **No verification** - Didn't verify backup before making changes

#### Lessons Learned

1. **ALWAYS create backups** before any database-related changes
2. **Test configuration changes** in isolation before applying to running systems
3. **Understand cascading effects** of Kustomize and other tools
4. **Minimize restarts** during troubleshooting - each restart increases corruption risk
5. **Verify assumptions** - Don't assume local environment is safe to break

#### Prevention Measures

The following measures are now MANDATORY to prevent recurrence:

1. **Automated daily backups** of local development PostgreSQL database
2. **Pre-change backup requirement** - NO database config changes without backup
3. **Recovery procedure documentation** - Clear steps for database restoration
4. **Configuration testing** - Test Kustomize changes with `kubectl diff` first
5. **Change isolation** - Apply only the specific change needed, not entire overlays

**Remember this incident:** 10 days of development data lost permanently because backup was skipped before a "simple" CORS configuration change.

---

## Documentation Requirements

### Documentation Requirements for Changes

**Every platform change MUST include:**

1. **Commit Message** with:
   - Clear description of what changed
   - Why the change was necessary
   - Impact assessment
   - Reference to issue/ticket (if applicable)

2. **Update Summary Document** (for significant changes):
   ```markdown
   # Change Summary: [Brief Title]

   **Date:** YYYY-MM-DD
   **Author:** [Your Name]
   **Services Affected:** api-service, data-service

   ## What Changed
   - [Specific change 1]
   - [Specific change 2]

   ## Why
   [Rationale for the change]

   ## Impact
   - Performance: [impact]
   - Availability: [impact]
   - Dependencies: [impact]

   ## Rollback Plan
   [How to revert if needed]

   ## Verification
   - [ ] Code committed and pushed
   - [ ] Changes applied to local environment
   - [ ] Tests passing
   - [ ] Monitoring confirms expected behavior
   ```

3. **Update Relevant Docs**:
   - Architecture docs if structure changed
   - Deployment guides if process changed
   - Troubleshooting guides if behavior changed

---

## Version Control Standards

### Commit Message Format

**MANDATORY format for all commits:**

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `hotfix`: Emergency production fix

**Example:**

```
feat: Add request timeout configuration to API service

- Add REQUEST_TIMEOUT_SECONDS to configuration
- Default timeout: 30 seconds
- Configurable via TIMEOUT environment variable
- Add validation for timeout range (1-300 seconds)

This prevents hung requests from blocking workers during
long-running scan operations.

Refs: #123
```

### Branch Naming

**Standard branch naming:**

```
<type>/<short-description>

Examples:
- feat/add-timeout-config
- fix/cors-127-address
- docs/update-deployment-guide
- hotfix/memory-leak-api-service
```

### Git Workflow - Feature Branch Model

**CRITICAL:** NEVER commit directly to main branch. ALL changes MUST go through feature branches and pull requests.

```
✅ CORRECT WORKFLOW:
1. Create feature branch from main
2. Make changes and commit to feature branch
3. Push feature branch to remote
4. Create pull request
5. Review and merge PR (user account only, NEVER as Claude)
6. Delete feature branch after merge

❌ INCORRECT WORKFLOW:
1. Make changes directly on main branch
2. Commit to main branch
3. Push directly to main
```

**Why this matters:**
- **Code Review:** All changes reviewed before merging to main
- **Quality Control:** Prevents broken code from reaching main
- **Audit Trail:** Clear history of what changed and why
- **Collaboration:** Team members can review and discuss changes
- **Rollback Safety:** Easy to revert problematic changes
- **CI/CD Integration:** Automated tests run before merge

**MANDATORY: This is the standard git workflow. Violations are unacceptable.**

#### Step-by-Step Feature Branch Workflow

**1. Start New Feature/Fix:**

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Create and switch to feature branch
git checkout -b feat/add-scan-filtering
# or
git checkout -b fix/vulnerability-status-update
# or
git checkout -b docs/update-api-guide
```

**2. Make Changes and Commit:**

```bash
# Make your code changes
vim src/api/endpoints/scans.py

# Stage changes
git add src/api/endpoints/scans.py

# Commit with descriptive message
git commit -m "feat: Add filtering by severity to scan endpoint

- Add severity query parameter to /api/v1/scans
- Support multiple severity filters (e.g., ?severity=high,critical)
- Add validation for severity values
- Update API documentation

Allows users to filter scans by vulnerability severity.

Refs: #234"

# Continue making changes as needed
# Commit frequently with clear messages
```

**3. Push Feature Branch:**

```bash
# Push branch to remote (first time)
git push -u origin feat/add-scan-filtering

# Subsequent pushes
git push
```

**4. Create Pull Request:**

```bash
# Option 1: Using GitHub CLI
gh pr create \
  --title "feat: Add filtering by severity to scan endpoint" \
  --body "## Summary
- Adds severity filtering to scan list endpoint
- Supports multiple severity values
- Includes validation and tests

## Testing
- Unit tests added for filter logic
- Integration tests verify API behavior
- Manual testing with curl commands

## Breaking Changes
None - backwards compatible addition"

# Option 2: Via GitHub web interface
# Navigate to repository and click "Create Pull Request"
```

**5. Code Review and Merge:**

```bash
# CRITICAL: User (not Claude) reviews and merges PR
# - Review code changes in GitHub
# - Check CI/CD tests passed
# - Verify no merge conflicts
# - Click "Merge pull request" (as user, NOT as Claude)
# - Delete feature branch after merge
```

**6. Clean Up:**

```bash
# After PR is merged, delete local branch
git checkout main
git pull origin main
git branch -d feat/add-scan-filtering

# Remote branch is automatically deleted if "Delete branch" was clicked
```

#### Branch Protection Rules

**MANDATORY settings for main branch:**

1. **Require pull request reviews** - At least 1 approval (in team environments)
2. **Require status checks** - Tests must pass before merge
3. **No direct commits to main** - All changes via PR
4. **Include administrators** - Even admins must follow workflow

**GitHub Settings Path:**
Repository → Settings → Branches → Branch protection rules → main

#### Common Git Workflow Scenarios

**Scenario 1: Need to update feature branch with latest main:**

```bash
# Switch to your feature branch
git checkout feat/add-scan-filtering

# Fetch latest from remote
git fetch origin

# Rebase on top of latest main (preferred)
git rebase origin/main

# OR merge main into feature branch (alternative)
git merge origin/main

# Push updated feature branch
git push --force-with-lease  # If rebased
# or
git push  # If merged
```

**Scenario 2: Multiple commits in feature branch, want to squash:**

```bash
# Interactive rebase to squash commits
git rebase -i HEAD~3  # Last 3 commits

# In editor, change "pick" to "squash" for commits to combine
# Save and edit combined commit message

# Push squashed commits
git push --force-with-lease
```

**Scenario 3: Accidentally committed to main:**

```bash
# Create feature branch from current main state
git branch fix/accidental-commit

# Reset main to remote state (removes local commits)
git reset --hard origin/main

# Switch to feature branch (commits are preserved here)
git checkout fix/accidental-commit

# Push feature branch and create PR
git push -u origin fix/accidental-commit
gh pr create --title "fix: [description]" --body "[details]"
```

**Scenario 4: Need to make hotfix to production:**

```bash
# Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-security-patch

# Make minimal changes to fix issue
vim src/security/auth.py
git add src/security/auth.py
git commit -m "hotfix: Patch critical security vulnerability

- Fix SQL injection in login endpoint
- Add input validation for email parameter
- Backport to stable branches

CRITICAL: Deploy immediately

Refs: SEC-001"

# Push and create PR marked as urgent
git push -u origin hotfix/critical-security-patch
gh pr create --title "HOTFIX: Critical security patch" --body "..."

# After review and merge, tag for deployment
git checkout main
git pull origin main
git tag -a v1.2.3 -m "Hotfix release v1.2.3 - Security patch"
git push origin v1.2.3
```

### Pull Request Requirements

**Every PR MUST include:**

1. **Clear title** describing the change (never mention Claude or Claude Code)
2. **Description** with:
   - What changed
   - Why it changed
   - How to test
   - Any breaking changes
3. **Updated documentation** (if applicable)
4. **Tests passing** (all CI/CD checks green)
5. **No merge conflicts** with main branch
6. **Commits merged by user account** (NEVER by Claude or automated tools)

**PR Title Format:**
```
<type>: <brief description>

Examples:
feat: Add severity filtering to scan endpoint
fix: Correct vulnerability status update logic
docs: Update API authentication guide
refactor: Simplify scan result processing
test: Add integration tests for scan workflow
```

**PR Description Template:**

```markdown
## Summary
Brief description of what this PR does (2-3 sentences).

## Changes
- Specific change 1
- Specific change 2
- Specific change 3

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests passing
- [ ] Manual testing completed
- [ ] Tested in local environment

## Breaking Changes
Yes/No - If yes, describe what breaks and migration path.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Documentation updated
- [ ] Tests passing
- [ ] No merge conflicts
- [ ] Ready for review
```

**PR Review Checklist:**

Before merging any PR:
- [ ] All CI/CD checks passing (tests, linting, build)
- [ ] Code reviewed for quality and correctness
- [ ] No security vulnerabilities introduced
- [ ] Documentation updated if needed
- [ ] No merge conflicts with main
- [ ] Commit messages follow standards
- [ ] Breaking changes documented
- [ ] User (not Claude) performs the merge

---

## Testing Standards

### Test Before Deploy

**MANDATORY testing sequence:**

```bash
# 1. Unit tests (in service repository)
cd /Users/pwner/Git/ABS/blocksecops-api-service
pytest tests/unit/

# 2. Build Docker image
docker build -t localhost:8080/library/api-service:0.3.7 .

# 3. Push to registry
docker push localhost:8080/library/api-service:0.3.7

# 4. Update Kubernetes manifests (commit first!)
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
vim k8s/overlays/local/api-service/kustomization.yaml
git add .
git commit -m "Update API service to v0.3.7"

# 5. Deploy
kubectl apply -k k8s/overlays/local/api-service

# 6. Wait for rollout
kubectl rollout status deployment api-service -n api-service-local

# 7. Integration tests
curl http://127.0.0.1:8000/api/v1/health/live
curl http://127.0.0.1:8000/api/v1/health/ready

# 8. Verify logs
kubectl logs -n api-service-local -l app.kubernetes.io/name=api-service --tail=50
```

### CRITICAL: Do Not Rollback Working Deployments

**IMPORTANT:** If you have already deployed working code and then realize you forgot to commit it to version control first:

```bash
✅ CORRECT ACTION:
1. Leave the working deployment running
2. Commit the code changes that match what's deployed
3. Push commits and create pull request
4. Document what was deployed and when

❌ INCORRECT ACTION:
1. Rollback the working deployment
2. Commit the code
3. Redeploy

**Why this matters:**
- **Service Availability:** Rolling back working code causes unnecessary downtime
- **User Experience:** Users lose access to working features during rollback
- **Development Time:** Wasted time rolling back and redeploying
- **Risk Introduction:** Additional deployment increases risk of errors

**The proper workflow is:**
1. **If deployment is working:** Keep it running, commit the code to match
2. **If deployment is broken:** Follow the rollback procedure below
```

### CRITICAL: Test Before Committing Fixes

**MANDATORY:** When fixing bugs or issues, ALWAYS test and confirm the fix works BEFORE committing the code.

```bash
✅ CORRECT WORKFLOW:
1. Identify the issue and root cause
2. Make code changes to fix the issue
3. Build and deploy the fix to local environment
4. Test and verify the fix resolves the issue
5. Once confirmed working, commit the code changes
6. Push commits and create pull request

❌ INCORRECT WORKFLOW:
1. Identify the issue
2. Make code changes
3. Commit the code immediately
4. Deploy and test
5. Discover the fix doesn't work or causes new issues
6. Need to revert commit or make additional commits
```

**Why this matters:**
- **Commit Quality:** Commits should represent working, tested code
- **Git History:** Cleaner history without fix-the-fix commits
- **Code Review:** Reviewers see tested, working code
- **Confidence:** Know the fix works before committing
- **Rollback Safety:** Each commit is a known-working state

**Example - Fixing Analytics Issue:**

```bash
# 1. Make the fix
vim src/presentation/api/v1/endpoints/analytics.py

# 2. Build and deploy (DON'T COMMIT YET)
eval $(minikube docker-env)
docker build --no-cache -t api-service:latest .
kubectl set image deployment/api-service api-service=api-service:latest -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 3. Force pod restart to ensure new image is used
kubectl delete pod -n api-service-local -l app.kubernetes.io/name=api-service
kubectl rollout status deployment/api-service -n api-service-local

# 4. Test the fix thoroughly
curl http://127.0.0.1:8000/api/v1/analytics/summary | jq '.vulnerability_trends.summary.total_resolved_vulnerabilities'
# Verify the dashboard shows correct numbers
# Test with different scenarios

# 5. ONLY AFTER confirming it works, commit
git add src/presentation/api/v1/endpoints/analytics.py
git commit -m "fix: Correct analytics resolved vulnerabilities count

- Changed net_change calculation to not subtract all-time resolved from time-windowed new
- Without status history, we can't track when vulnerabilities were resolved
- Now shows accurate counts without negative numbers

Tested: Dashboard analytics now shows correct resolved count"

# 6. Push and create PR
git push
```

**When to commit before testing:**
- Documentation changes (no risk of breaking functionality)
- Configuration file updates that don't affect running systems
- Non-functional refactoring with comprehensive test coverage

**Always test before committing:**
- Bug fixes (verify they actually fix the issue)
- New features (verify they work as intended)
- API changes (verify backward compatibility)
- Database migrations (verify data integrity)
- Deployment configuration changes (verify services remain healthy)

### CRITICAL: Always Build Docker Images with --no-cache

**MANDATORY:** Docker images MUST be built with the `--no-cache` flag to prevent stale code from being included in builds.

**The Problem:**

Docker uses layer caching to speed up builds. When you change application code but the Dockerfile hasn't changed, Docker may reuse cached layers containing OLD code. This results in deploying images that don't include your latest changes.

**Example of the issue:**

```bash
# Day 1: Build image with code version A
docker build -t api-service:latest .
# Docker caches layers including code version A

# Day 2: Update analytics.py with bug fix (code version B)
vim src/presentation/api/v1/endpoints/analytics.py

# Build image - Docker reuses cached layers!
docker build -t api-service:latest .
# ❌ Image contains OLD code (version A), not your fix (version B)!

# Deploy the image
kubectl set image deployment/api-service api-service=api-service:latest -n api-service-local
# ❌ Deployed code doesn't have your fix!

# Test shows bug still exists
curl http://127.0.0.1:8000/api/v1/analytics/summary
# Returns old behavior - your fix isn't deployed
```

**The Solution:**

ALWAYS use `--no-cache` flag when building Docker images for local development and testing:

```bash
✅ CORRECT: Build with --no-cache
eval $(minikube docker-env)
docker build --no-cache -t api-service:latest .

# This ensures:
# - All layers rebuilt from scratch
# - Latest code is included
# - No stale cached code
# - Deployed image matches source code
```

**When --no-cache is MANDATORY:**

- **Bug fixes** - Ensuring the fix is actually included
- **Code changes** - Any modifications to application code
- **After editing Python/JS/TS files** - Source code changes
- **Testing fixes locally** - Before committing code
- **When unsure** - Better safe than deploying stale code

**When --no-cache is optional (but still recommended):**

- **Dockerfile changes only** - No application code changes
- **Dependency updates in requirements.txt** - Package changes trigger rebuild anyway
- **CI/CD pipelines** - Automated builds with version control

**Why this matters:**

- **Code Accuracy:** Deployed code must match source code
- **Testing Validity:** Can't test a fix that isn't deployed
- **Debugging Time:** Hours wasted debugging "broken fixes" that aren't deployed
- **Cache Reliability:** Docker cache can be unpredictable with `COPY . /app` commands
- **Development Speed:** Faster to rebuild than debug phantom issues

**Build Time Trade-offs:**

```bash
# With cache (fast but risky)
docker build -t api-service:latest .
# Time: ~10-30 seconds
# Risk: May include stale code

# Without cache (slower but reliable)
docker build --no-cache -t api-service:latest .
# Time: ~2-5 minutes
# Risk: None - guaranteed fresh build
```

**The extra 2-5 minutes is worth it to ensure your code changes are actually deployed.**

**Real-World Example:**

On October 17, 2025, an analytics bug fix was deployed THREE times before working:

1. **First attempt:** Built without `--no-cache`, deployed stale code, bug persisted
2. **Second attempt:** Built with `--no-cache`, BUT Kubernetes cached old image, bug persisted
3. **Third attempt:** Built with `--no-cache` AND deleted pod, fix finally worked

**Complete workflow to ensure code changes deploy:**

```bash
# 1. Make code changes
vim src/presentation/api/v1/endpoints/analytics.py

# 2. Build with --no-cache (MANDATORY)
eval $(minikube docker-env)
docker build --no-cache -t api-service:latest .

# 3. Update deployment
kubectl set image deployment/api-service api-service=api-service:latest -n api-service-local

# 4. Force pod restart (ensures Kubernetes pulls fresh image)
kubectl delete pod -n api-service-local -l app.kubernetes.io/name=api-service

# 5. Wait for rollout
kubectl rollout status deployment/api-service -n api-service-local

# 6. Verify deployed code matches source
kubectl exec -n api-service-local deployment/api-service -- grep -A 2 "net_change" /app/src/presentation/api/v1/endpoints/analytics.py

# 7. Test the fix
curl http://127.0.0.1:8000/api/v1/analytics/summary | jq '.'
```

**Exception for Production:**

In CI/CD pipelines for staging/production, you MAY use Docker cache IF:
- Images are tagged with specific versions (not `latest`)
- Build system tracks source code changes
- Each version is guaranteed a unique build
- Cache invalidation is properly configured

**For local development: ALWAYS use --no-cache. No exceptions.**

### Rollback Procedure

**If tests fail after deployment:**

```bash
# 1. Check what version is currently deployed
kubectl get deployment api-service -n api-service-local -o jsonpath='{.spec.template.spec.containers[0].image}'

# 2. Rollback Kubernetes deployment
kubectl rollout undo deployment api-service -n api-service-local

# 3. Verify rollback
kubectl rollout status deployment api-service -n api-service-local

# 4. Update code to match deployed version
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
git revert HEAD
git push

# 5. Document the rollback
echo "Rolled back API service from 0.3.7 to 0.3.6 at $(date) - reason: [explain]" >> ROLLBACK.log
```

---

## Deployment Workflow

### Standard Deployment Process

**For ALL platform changes:**

```
1. CODE UPDATE
   ├─ Update service code
   ├─ Update Kubernetes manifests
   ├─ Update configuration files
   └─ Commit all changes

2. BUILD
   ├─ Build Docker image
   ├─ Tag with semantic version
   └─ Push to registry

3. DEPLOY
   ├─ Apply Kubernetes changes from code
   ├─ Wait for rollout completion
   └─ Verify health checks

4. TEST
   ├─ Run integration tests
   ├─ Check logs for errors
   └─ Verify expected behavior

5. DOCUMENT
   ├─ Update deployment log
   ├─ Update relevant documentation
   └─ Communicate to team (if significant)
```

### Deployment Checklist

Before deploying any change:

- [ ] All changes committed to Git
- [ ] Changes pushed to remote repository
- [ ] Docker image built and pushed
- [ ] Kubernetes manifests updated in code
- [ ] Version numbers incremented (if applicable)
- [ ] Tests passing locally
- [ ] Rollback plan documented
- [ ] Team notified (if significant change)

After deploying:

- [ ] Deployment successful
- [ ] Health checks passing
- [ ] No errors in logs
- [ ] Integration tests passing
- [ ] Monitoring shows expected metrics
- [ ] Documentation updated
- [ ] Deployment logged

---

## Compliance Checklist

### Daily Development

- [ ] Using `127.0.0.1` for all local development endpoints
- [ ] All services include `127.0.0.1:3000` in CORS
- [ ] Port forwards configured correctly
- [ ] Dashboard `.env.local` uses correct endpoints
- [ ] Recent database backup exists (within 24 hours)

### Making Changes

- [ ] Changes committed to Git BEFORE applying to platform
- [ ] Commit messages follow standard format
- [ ] Documentation updated for significant changes
- [ ] Tests passing before deployment
- [ ] Rollback plan documented
- [ ] **Database backup created** (if changes affect database config)
- [ ] **includeSelectors: false** verified in all kustomization.yaml files
- [ ] Service endpoints verified after applying changes

### Database Configuration Changes

- [ ] **Backup created and verified** - Run `./scripts/backup-local-db.sh`
- [ ] Changes documented with clear rationale
- [ ] Recovery procedure identified and ready
- [ ] Team notified (if shared environment)
- [ ] Tested with `kubectl diff` before applying
- [ ] Only specific changes applied (not entire overlays)

### Code Review

- [ ] All platform changes in version control
- [ ] No ad-hoc kubectl edits without code updates
- [ ] CORS configuration includes required origins
- [ ] Proper semantic versioning used
- [ ] Documentation matches actual state
- [ ] Database backup procedures followed (if applicable)

---

## Docker Image Versioning Standards

### Semantic Versioning for Docker Images

**MANDATORY:** All Docker images MUST follow [Semantic Versioning 2.0.0](https://semver.org/) specification.

**Format:** `MAJOR.MINOR.PATCH`

Where:
- **MAJOR** version = Breaking changes (incompatible API changes)
- **MINOR** version = New features (backwards-compatible functionality)
- **PATCH** version = Bug fixes (backwards-compatible fixes)

**Examples:**

```bash
# Bug fix (scanner import error) - increment PATCH
api-service:0.3.12 → api-service:0.3.13

# New feature (custom scanner selection) - increment MINOR
api-service:0.3.13 → api-service:0.4.0

# Breaking change (new authentication system) - increment MAJOR
api-service:0.4.0 → api-service:1.0.0
```

### Version Increment Rules

**MANDATORY:** Docker image version MUST be incremented whenever code changes are made to the service.

**When to increment PATCH (0.3.12 → 0.3.13):**
- Bug fixes
- Security patches
- Performance improvements (no API changes)
- Documentation updates
- Dependency updates (no behavior change)
- Code changes (any source code modifications)

**When to increment MINOR (0.3.13 → 0.4.0):**
- New features (backwards-compatible)
- New API endpoints
- New configuration options
- Deprecated features (not removed)
- Internal refactoring with new capabilities

**When to increment MAJOR (0.4.0 → 1.0.0):**
- Breaking API changes
- Removed endpoints or features
- Changed authentication/authorization
- Database schema changes requiring migration
- Configuration format changes
- Removed or changed environment variables

### Pre-1.0 Development

**Current Status:** All services are in `0.x.x` (pre-release/development)

During `0.x.x` versions:
- **MINOR** versions MAY introduce breaking changes
- **PATCH** versions MUST be backwards-compatible
- Version `1.0.0` signals production-ready, stable API

**When to release 1.0.0:**
- API is stable and well-tested
- All critical features implemented
- Comprehensive test coverage
- Security hardening complete
- Documentation complete
- Ready for production use

### Image Tagging Workflow

**Building and tagging images:**

```bash
# 1. Determine version increment based on changes
# Bug fix example: 0.3.12 → 0.3.13

# 2. Build image with new version
eval $(minikube docker-env)
docker build -t api-service:0.3.13 -f Dockerfile .

# 3. Also tag as 'latest' for local development
docker tag api-service:0.3.13 api-service:latest

# 4. Verify image exists
docker images | grep api-service
```

### Updating Kustomize Configuration

**After building new image version, update ALL relevant files:**

```yaml
# k8s/overlays/local/kustomization.yaml
images:
- name: PLACEHOLDER_REGISTRY/blocksecops-api-service
  newName: api-service
  newTag: 0.3.13  # ← Update version

labels:
- includeSelectors: false
  pairs:
    app.kubernetes.io/version: 0.3.13  # ← Update version label
```

**Critical:** Update BOTH `newTag` AND `app.kubernetes.io/version` to match!

### Version Tracking

**Track image versions in multiple locations:**

1. **Docker Image Tag:** Actual image version
2. **Kustomization:** Kubernetes deployment version
3. **Git Tag:** Code version matching image

**Creating git tags for releases:**

```bash
# Tag the commit that matches the Docker image
git tag -a api-service-v0.3.13 -m "Release API Service v0.3.13

- Fix: Scanner endpoint import error
- Allows scanner metadata to be retrieved via API
- Resolves blocking issue for custom scanner selection feature"

# Push tag to remote
git push origin api-service-v0.3.13
```

### Version Documentation

**Document version changes in CHANGELOG:**

```markdown
# CHANGELOG - API Service

## [0.3.13] - 2025-10-17

### Fixed
- Scanner endpoint import error preventing scanner metadata retrieval
- Corrected import path from non-existent ScannerService to ToolIntegrationClient

## [0.3.12] - 2025-10-17

### Fixed
- Kubernetes service endpoint issue with includeSelectors
- Service selector mismatch causing zero endpoints

## [0.3.11] - 2025-10-16

### Added
- TypeScript build fixes for ui-core package
- Scan modal UX improvements with loading states
```

### Rollback Considerations

**Version tracking enables easy rollbacks:**

```bash
# Rollback to previous version
kubectl set image deployment/api-service \
  api-service=api-service:0.3.12 \
  -n api-service-local

# Or update kustomization and reapply
vim k8s/overlays/local/kustomization.yaml
# Change newTag: 0.3.13 back to newTag: 0.3.12
kubectl apply -k k8s/overlays/local/
```

### Version Checklist

Before incrementing version:

- [ ] Determine correct increment type (MAJOR/MINOR/PATCH)
- [ ] Build Docker image with new version tag
- [ ] Update kustomization.yaml (newTag + version label)
- [ ] Create git tag matching version
- [ ] Update CHANGELOG with changes
- [ ] Document breaking changes (if MAJOR/MINOR increment)
- [ ] Test deployment with new version
- [ ] Verify rollback procedure works

**Example Version History:**

```
0.1.0 - Initial development version
0.2.0 - Added scan functionality
0.3.0 - Added vulnerability management
0.3.1 - Fixed vulnerability status bug
0.3.2 - Performance improvements
...
0.3.12 - Fixed service endpoint issue
0.3.13 - Fixed scanner import error
0.4.0 - Added custom scanner selection (next)
1.0.0 - Production release (future)
```

---

## Tool Metadata Management via ConfigMaps

### Overview

**MANDATORY:** Third-party tool metadata (versions, developer information, configuration) MUST be managed via Kubernetes ConfigMaps rather than hardcoded in application code.

**Why this matters:**
- **Production Sustainability:** Version updates don't require code changes or deployments
- **Single Source of Truth:** All tool metadata centralized in one location
- **Git-Tracked History:** All version changes auditable through Git
- **Environment Flexibility:** Overlay-specific ConfigMaps enable staging/production version differences
- **Operational Simplicity:** Update ConfigMap → Restart service (no Docker rebuild required)

**Violations of this pattern result in:**
- Version drift (displayed versions don't match actual tools)
- Manual maintenance burden (every version update requires code change)
- Deployment overhead (Docker rebuild and push for simple version changes)
- No audit trail (can't track which versions ran when)

### The Problem with Hardcoded Versions

**Anti-Pattern Example** (DO NOT DO THIS):

```python
# ❌ WRONG: Hardcoded scanner metadata in Python code
SCANNERS = {
    "slither": ScannerMetadata(
        id="slither",
        name="Slither",
        version="0.10.4",  # Hardcoded - requires code change to update
        developer="Trail of Bits",  # Hardcoded - no central management
        # ... other fields
    ),
    # ... 20+ more scanners with hardcoded versions
}
```

**Problems:**
- Every scanner version update requires:
  1. Edit Python code
  2. Commit code changes
  3. Build new Docker image
  4. Push Docker image
  5. Update deployment
  6. Restart pods
- No way to track version history separate from code changes
- Can't use different versions in staging vs production without code branches
- Version information scattered across multiple files

### The ConfigMap Solution

**Pattern:** Store tool metadata in a Kubernetes ConfigMap as JSON, load at runtime

**ConfigMap Structure:**

```yaml
# Location: k8s/base/scanner-versions-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
  namespace: tool-integration-local
data:
  # Tool metadata as JSON (single source of truth)
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.4",
        "developer": "Trail of Bits",
        "release_date": "2024-09-15"
      },
      "mythril": {
        "version": "0.24.8",
        "developer": "ConsenSys",
        "release_date": "2024-08-20"
      },
      "aderyn": {
        "version": "0.1.0",
        "developer": "Cyfrin",
        "release_date": "2024-07-10"
      }
    }

  # Tool Docker image tags (used by orchestration service)
  SCANNER_IMAGE_SLITHER: "scanner-slither:0.2.0"
  SCANNER_IMAGE_MYTHRIL: "mythril/myth:latest"
  SCANNER_IMAGE_ADERYN: "scanner-aderyn:0.1.0"
```

**Benefits:**
- One file contains all tool metadata
- Git tracks all version changes
- Can diff versions across environments
- Easy to review what versions are deployed

### Application Integration Pattern

**Step 1: Inject ConfigMap as Environment Variable**

```yaml
# Location: k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
spec:
  template:
    spec:
      containers:
      - name: api-service
        image: api-service:0.1.8
        env:
        # Inject tool metadata from ConfigMap
        - name: SCANNER_METADATA
          valueFrom:
            configMapKeyRef:
              name: scanner-versions
              key: SCANNER_METADATA
```

**Step 2: Load Metadata at Application Startup**

```python
# Location: src/infrastructure/scanner_config/scanners.py
import os
import json
import logging
from typing import Dict

logger = logging.getLogger(__name__)

def _load_scanner_metadata_from_env() -> Dict[str, dict]:
    """
    Load scanner metadata from SCANNER_METADATA environment variable.

    Returns:
        Dictionary mapping scanner_id -> {version, developer, ...}
    """
    metadata_json = os.getenv("SCANNER_METADATA", "{}")
    try:
        metadata = json.loads(metadata_json)
        logger.info(f"Loaded metadata for {len(metadata)} scanners from ConfigMap")
        return metadata
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse SCANNER_METADATA env var: {e}")
        return {}

# Load at module initialization (runs once at startup)
_SCANNER_METADATA_FROM_CONFIG = _load_scanner_metadata_from_env()
```

**Step 3: Use Metadata in Application Code**

```python
class ScannerMetadata:
    def __init__(
        self,
        id: str,
        name: str,
        description: str,
        version: Optional[str] = None,
        developer: Optional[str] = None,
        # ... other fields
    ):
        self.id = id
        self.name = name
        self.description = description

        # Load version/developer from ConfigMap automatically
        config_metadata = _SCANNER_METADATA_FROM_CONFIG.get(id, {})
        self.version = version or config_metadata.get("version", "unknown")
        self.developer = developer or config_metadata.get("developer", "unknown")

        # ✅ GOOD: Version defaults to ConfigMap value
        # Optional override parameter allows backward compatibility
```

**Benefits of this pattern:**
- Metadata loaded once at startup (no repeated JSON parsing)
- Comprehensive logging of what was loaded
- Fail-safe defaults if ConfigMap unavailable
- Optional override parameters for testing
- Type-safe Python access to metadata

### Version Update Workflow

**When a tool version changes (e.g., Slither 0.10.4 → 0.10.5):**

```bash
# 1. Update ConfigMap
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
vim k8s/base/scanner-versions-configmap.yaml

# Change:
#   "version": "0.10.4"
# To:
#   "version": "0.10.5"

# 2. Commit ConfigMap change
git add k8s/base/scanner-versions-configmap.yaml
git commit -m "feat: Update Slither scanner to v0.10.5

- Updated SCANNER_METADATA version for slither
- New version includes performance improvements
- Release notes: https://github.com/crytic/slither/releases/tag/0.10.5"

# 3. Apply ConfigMap to Kubernetes
kubectl apply -f k8s/base/scanner-versions-configmap.yaml

# 4. Restart API service to reload env vars
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 5. Verify version update
curl http://localhost:8000/api/v1/scanners | \
  jq '.scanners[] | select(.id=="slither") | {id, version, developer}'

# Expected output:
# {
#   "id": "slither",
#   "version": "0.10.5",
#   "developer": "Trail of Bits"
# }
```

**Total time:** ~2 minutes (vs ~15 minutes with code change + Docker rebuild)

**No Docker rebuild required!**

### Multi-Environment Support

**Use Kustomize overlays for environment-specific versions:**

**Base ConfigMap** (production-stable versions):

```yaml
# k8s/base/scanner-versions-configmap.yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.4",
        "developer": "Trail of Bits"
      }
    }
```

**Local Development Override** (latest versions for testing):

```yaml
# k8s/overlays/local/scanner-versions-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.5-dev",
        "developer": "Trail of Bits"
      }
    }
```

**Staging Override** (release candidates):

```yaml
# k8s/overlays/staging/scanner-versions-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.5-rc1",
        "developer": "Trail of Bits"
      }
    }
```

**Benefits:**
- Test new versions in local/staging before production
- Production always uses stable versions
- No code changes required across environments
- Git tracks version differences

### Monitoring and Validation

**RECOMMENDED:** Implement version validation to detect drift

**Pattern 1: Log Loaded Metadata**

```python
# At startup, log all loaded metadata
def _load_scanner_metadata_from_env() -> Dict[str, dict]:
    metadata_json = os.getenv("SCANNER_METADATA", "{}")
    try:
        metadata = json.loads(metadata_json)
        logger.info(f"Loaded metadata for {len(metadata)} scanners from ConfigMap")

        # Log summary for audit trail
        for scanner_id, meta in metadata.items():
            logger.info(f"  {scanner_id}: v{meta.get('version', 'unknown')} "
                       f"by {meta.get('developer', 'unknown')}")

        return metadata
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse SCANNER_METADATA env var: {e}")
        return {}
```

**Pattern 2: Health Check Endpoint**

```python
# Add metadata to health check response
@router.get("/health/metadata")
async def get_metadata():
    return {
        "scanners": {
            scanner_id: {
                "version": meta.version,
                "developer": meta.developer
            }
            for scanner_id, meta in SCANNERS.items()
        },
        "loaded_at": startup_time,
        "source": "scanner-versions ConfigMap"
    }
```

**Pattern 3: Alert on "unknown" Versions**

```python
# Monitor for fallback to "unknown" (indicates ConfigMap loading issue)
for scanner_id, meta in SCANNERS.items():
    if meta.version == "unknown" or meta.developer == "unknown":
        logger.error(f"Scanner {scanner_id} has unknown metadata - ConfigMap may not be loaded!")
        # Send alert to monitoring system
```

### Real-World Example: Scanner Metadata Refactoring

**Context:** BlockSecOps Platform manages 21 security scanners across 5 blockchain languages

**Before (Anti-Pattern):**
```python
# 21 scanners with hardcoded versions in scanners.py
"slither": ScannerMetadata(
    id="slither",
    version="0.10.4",  # Hardcoded
    developer="Trail of Bits",  # Hardcoded
    # ...
),
# ... 20 more scanners
```

**After (ConfigMap Pattern):**
```yaml
# scanner-versions-configmap.yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {"version": "0.10.4", "developer": "Trail of Bits"},
      "mythril": {"version": "0.24.8", "developer": "ConsenSys"},
      "aderyn": {"version": "0.1.0", "developer": "Cyfrin"},
      # ... 18 more scanners
    }
```

```python
# scanners.py - NO hardcoded versions
"slither": ScannerMetadata(
    id="slither",
    name="Slither",
    description="Industry-standard static analysis",
    # version/developer auto-loaded from ConfigMap
),
```

**Results:**
- ✅ Version updates: 15 minutes → 2 minutes
- ✅ Single source of truth established
- ✅ Git tracks all version history
- ✅ Dashboard displays actual tool versions
- ✅ Zero code changes for version updates

**Documentation:** See `/Users/pwner/Git/ABS/docs/SCANNER-METADATA-REFACTORING-2025-10-18.md`

### Best Practices

**1. JSON Structure Standards:**

```json
{
  "tool-id": {
    "version": "MAJOR.MINOR.PATCH",
    "developer": "Organization Name",
    "release_date": "YYYY-MM-DD",
    "notes": "Optional release notes or warnings"
  }
}
```

**2. ConfigMap Naming:**
- Use descriptive names: `scanner-versions`, `tool-metadata`, `external-tool-config`
- Include purpose in name: `*-versions`, `*-metadata`, `*-config`

**3. JSON Validation:**
- Validate JSON at startup with comprehensive error handling
- Log parsing errors clearly
- Provide fail-safe defaults for missing fields

**4. Documentation Requirements:**
- Comment ConfigMap with usage instructions
- Document what services consume the ConfigMap
- Track version update history in commit messages

**5. Testing:**
```bash
# Test ConfigMap JSON is valid
kubectl get configmap scanner-versions -o jsonpath='{.data.SCANNER_METADATA}' | jq '.'

# Test application loads metadata correctly
kubectl logs deployment/api-service | grep "Loaded metadata"

# Test health endpoint shows correct versions
curl http://localhost:8000/api/v1/health/metadata | jq '.scanners'
```

### When to Use This Pattern

**✅ MANDATORY for:**
- Third-party tool versions (scanners, analyzers, validators)
- External service versions (APIs, SDKs, libraries)
- Tool configuration that changes independently of code
- Metadata displayed to users (version numbers, developer names)
- Multi-environment version differences

**❌ NOT REQUIRED for:**
- Application version numbers (use Docker image tags)
- Code logic or business rules (belongs in code)
- Secrets or sensitive data (use Kubernetes Secrets + External Secrets)
- Data that changes per-request (use database)

### Checklist: Implementing ConfigMap Metadata Management

Before deploying tool metadata via ConfigMaps:

- [ ] **ConfigMap created** with valid JSON structure
- [ ] **Environment variable** added to deployment
- [ ] **Loading function** implemented with error handling
- [ ] **Logging** added for startup and errors
- [ ] **Fail-safe defaults** defined (e.g., "unknown")
- [ ] **Health endpoint** exposes loaded metadata
- [ ] **Documentation** updated with ConfigMap location
- [ ] **Testing** validates JSON parsing and loading
- [ ] **Monitoring** alerts on "unknown" values
- [ ] **Version update workflow** documented

After deployment:

- [ ] Verify ConfigMap exists: `kubectl get configmap -n <namespace>`
- [ ] Verify pod has env var: `kubectl describe pod <pod-name>`
- [ ] Check startup logs: `kubectl logs <pod-name> | grep metadata`
- [ ] Test health endpoint: `curl http://localhost:8000/health/metadata`
- [ ] Perform version update test (update ConfigMap, restart pod, verify)

### Common Issues and Troubleshooting

**Issue:** Pod shows `CreateContainerConfigError`

**Cause:** ConfigMap doesn't exist in pod's namespace

**Solution:**
```bash
# Check ConfigMap exists
kubectl get configmap scanner-versions -n <namespace>

# If missing, apply ConfigMap
kubectl apply -f k8s/base/scanner-versions-configmap.yaml -n <namespace>
```

**Issue:** Metadata shows "unknown" for all tools

**Cause:** Environment variable not mounted, JSON parsing failed, or ConfigMap empty

**Diagnosis:**
```bash
# Check pod has env var
kubectl describe pod -n <namespace> <pod-name> | grep SCANNER_METADATA

# Check ConfigMap content
kubectl get configmap scanner-versions -o jsonpath='{.data.SCANNER_METADATA}' | jq '.'

# Check pod logs for parsing errors
kubectl logs -n <namespace> <pod-name> | grep -i "metadata\|parse\|config"
```

**Issue:** Version update not reflected after ConfigMap change

**Cause:** Pods not restarted (environment variables loaded at container start)

**Solution:**
```bash
# Restart deployment to reload env vars
kubectl rollout restart deployment/<service-name> -n <namespace>
kubectl rollout status deployment/<service-name> -n <namespace>

# Verify new version
curl http://localhost:8000/api/v1/scanners | jq '.scanners[0].version'
```

---

## Standards Reference

This document establishes standards for:
- **Codebase-First Development:** All changes in Git first
- **Local Development:** Use `127.0.0.1` consistently
- **Port Number Consistency:** Maintain standard port assignments
- **Kubernetes Service Selectors:** Use `includeSelectors: false` in Kustomize
- **Docker Image Versioning:** Semantic Versioning 2.0.0 for all images
- **Tool Metadata Management:** Use ConfigMaps for third-party tool versions
- **CORS Configuration:** Include all required origins
- **Database Safety:** Always backup before configuration changes
- **Version Control:** Proper commit messages and workflow
- **Testing:** Test before deploy, rollback if needed
- **Documentation:** Keep docs synchronized with code

**Related Documents:**
- [Docker Image Standards](/Users/pwner/Git/ABS/docs/DOCKER-IMAGE-STANDARDS.md)
- [Claude Spec Kit](/Users/pwner/Git/ABS/docs/CLAUDE-SPEC-KIT.md)
- [Quick Start Guide](/Users/pwner/Git/ABS/docs/QUICK-START-FOR-CLAUDE.md)
- [Development Workflow](/Users/pwner/Git/ABS/blocksecops-docs/local-development/development-workflow.md)

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.6.0 | 2025-10-19 | **MANDATORY:** Added Tool Metadata Management via ConfigMaps section establishing pattern for managing third-party tool versions, developer info, and configuration. Eliminates hardcoded versions, enables updates without code changes, provides single source of truth via Kubernetes ConfigMaps with JSON metadata loaded at runtime. | BlockSecOps Team |
| 1.5.0 | 2025-10-17 | **CRITICAL:** Added comprehensive Git Workflow Standards section mandating feature branch model, prohibiting direct commits to main, documenting PR requirements, branch protection rules, and common workflow scenarios. All changes MUST now go through feature branches and pull requests. | BlockSecOps Team |
| 1.4.0 | 2025-10-17 | Added comprehensive Dashboard Development Setup section documenting Python 3.13 greenlet issue, proper startup procedures, port-forward best practices (deployment vs service), troubleshooting steps, and development workflow | BlockSecOps Team |
| 1.3.0 | 2025-10-17 | Added Docker Image Versioning Standards section with Semantic Versioning 2.0.0 specification, version increment rules, image tagging workflow, and version tracking procedures | BlockSecOps Team |
| 1.2.0 | 2025-10-17 | Added Port Number Consistency Standards and Kubernetes Service Selector Standards sections with includeSelectors best practices and troubleshooting | BlockSecOps Team |
| 1.1.0 | 2025-10-16 | Added Database Management and Recovery section with backup procedures, recovery steps, and cautionary example | BlockSecOps Team |
| 1.0.0 | 2025-10-16 | Initial standards document | BlockSecOps Team |

---

## Questions or Issues?

Contact the development team or create an issue in the `blocksecops-docs` repository.

**Remember: These are MANDATORY standards. Violations will require immediate correction.**
