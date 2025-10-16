# Platform Development Standards

**Version:** 1.1.0
**Last Updated:** October 16, 2025
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
1. Update configuration files in Git repo folder
2. Commit changes to version control
3. Apply changes to Kubernetes/platform
4. Verify changes work as expected
5. Document changes in relevant docs

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
1. Merge PR with code changes to main branch
2. Pull latest code: git pull origin main
3. Build and push new Docker image (if image-based deployment)
4. Restart deployment: kubectl rollout restart deployment/<service> -n <namespace>
5. Wait for rollout: kubectl rollout status deployment/<service> -n <namespace>
6. Verify changes are active

❌ INCORRECT WORKFLOW:
1. Merge PR with code changes
2. Pull latest code
3. Assume running pods will pick up changes automatically
4. Wonder why new features don't work
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
- [ ] Dashboard `.env.local` uses `127.0.0.1` endpoints
- [ ] Backend CORS includes `127.0.0.1:3000`
- [ ] Can access dashboard at `http://127.0.0.1:3000`
- [ ] Can access API docs at `http://127.0.0.1:8000/docs`

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

### Pull Request Requirements

**Every PR MUST include:**

1. Clear title describing the change, never mention Claude or Claude Code
2. Description with:
   - What changed
   - Why it changed
   - How to test
   - Any breaking changes
3. Updated documentation (if applicable)
4. Tests passing (if applicable)
5. No merge conflicts
6. Commit, open PR and merge with user account, not claude. 

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

## Standards Reference

This document establishes standards for:
- **Codebase-First Development:** All changes in Git first
- **Local Development:** Use `127.0.0.1` consistently
- **CORS Configuration:** Include all required origins
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
| 1.1.0 | 2025-10-16 | Added Database Management and Recovery section with backup procedures, recovery steps, and cautionary example | BlockSecOps Team |
| 1.0.0 | 2025-10-16 | Initial standards document | BlockSecOps Team |

---

## Questions or Issues?

Contact the development team or create an issue in the `blocksecops-docs` repository.

**Remember: These are MANDATORY standards. Violations will require immediate correction.**
