# API Service Database Authentication Fix - 2025-10-16

## Issue Summary

**Date:** October 16, 2025
**Environment:** Local Development (Minikube)
**Services Affected:** API Service (blocksecops-api-service)
**Severity:** Critical - Login functionality completely broken

### Symptoms

- Dashboard login hanging indefinitely with no network requests reaching the API
- API service pods failing to start with database authentication errors
- Error: `asyncpg.exceptions.InvalidPasswordError: password authentication failed for user "postgres"`
- Pod status: CrashLoopBackOff / Running but never Ready

## Root Cause Analysis

### Primary Issue: ExternalSecret Overwriting Credentials

The API service was configured to use External Secrets Operator to sync database credentials from Vault. However, the ExternalSecret was using incorrect database credentials:

**Incorrect Credentials (from Vault):**
- User: `postgres`
- Password: `postgres`
- Connection string included `?ssl=require` parameter

**Actual PostgreSQL Configuration:**
- User: `harbor`
- Password: `harbor-local-password`
- Database: `blocksecops`

### Secondary Issues Discovered

1. **IPv4/IPv6 Port Forwarding Mismatch**
   - kubectl port-forward binds to IPv6 localhost by default
   - Dashboard configured for 127.0.0.1 (IPv4)
   - Initial incorrect fix: Changed to use `localhost` everywhere
   - Correct approach: Maintain consistent use of `127.0.0.1`

2. **CORS Configuration Issues**
   - Cannot use wildcard `*` with `withCredentials: true`
   - API CORS must specify explicit origins for HttpOnly cookie support

3. **ExternalSecret Sync Interval**
   - ExternalSecret refreshes every 15 seconds
   - Manual secret updates were continuously overwritten
   - ownerReferences prevented manual edits from persisting

## Investigation Process

### Step 1: Initial Diagnosis
```bash
# Checked API pod status
kubectl get pods -n api-service-local
# Result: Pods crash-looping

# Examined pod logs
kubectl logs api-service-xxx -n api-service-local
# Found: "password authentication failed for user postgres"
```

### Step 2: Database Verification
```bash
# Verified actual PostgreSQL credentials
kubectl exec -n postgresql-local postgresql-0 -- env | grep POSTGRES
# Found:
# POSTGRES_USER=harbor
# POSTGRES_PASSWORD=harbor-local-password
# POSTGRES_DB=harbor (note: API uses 'blocksecops' database)
```

### Step 3: Secret Investigation
```bash
# Checked secret contents
kubectl get secret api-service-secret -n api-service-local -o yaml

# Discovered ExternalSecret was managing the secret
kubectl get externalsecret -n api-service-local
# Found: api-service-secret with 15s refresh interval
```

### Step 4: ExternalSecret Analysis
```yaml
# File: k8s/overlays/local/api-service/externalsecret.yaml
spec:
  refreshInterval: 15s
  target:
    template:
      data:
        DATABASE_URL: "postgresql+asyncpg://{{ .postgresql_username }}:{{ .postgresql_password }}@postgresql.postgresql-local.svc.cluster.local:5432/blocksecops?ssl=require"
  data:
    - secretKey: postgresql_username
      remoteRef:
        key: kv/postgresql/local
        property: username
    - secretKey: postgresql_password
      remoteRef:
        key: kv/postgresql/local
        property: password
```

The ExternalSecret was pulling credentials from Vault at `kv/postgresql/local` which contained the wrong credentials.

## Solution

### Immediate Fix (Local Development)

For local development, the ExternalSecret dependency was removed and replaced with a static Kubernetes secret:

```bash
# 1. Delete the ExternalSecret to stop automatic sync
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

# 3. Restart API service pods to pick up new secret
kubectl delete pods --all -n api-service-local

# 4. Verify pod started successfully
kubectl get pods -n api-service-local
# Expected: api-service-xxx 1/1 Running

# 5. Restart port-forward
lsof -ti :8000 | xargs kill -9
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &
```

### Verification

```bash
# Test API health
curl http://127.0.0.1:8000/api/v1/health/ready
# Expected: {"ready":true,"checks":{"database":true,"service":true},"message":"Service is ready"}

# Test login
curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test-rebrand@blocksecops.com", "password": "TestPass123"}'
# Expected: {"message":"Login successful","user_id":"...","email":"test-rebrand@blocksecops.com"}
```

## Long-Term Solutions

### For Production Environments

The ExternalSecret approach is correct for production, but the Vault credentials need to be updated:

```bash
# Update Vault with correct PostgreSQL credentials
vault kv put kv/postgresql/local \
  username=harbor \
  password=harbor-local-password
```

### Configuration Standards

1. **Always Use 127.0.0.1 for Local Development**
   - Consistent IPv4 addressing across all services
   - Avoid mixing `localhost` and `127.0.0.1`
   - Files affected:
     - `.env.development.local`: `VITE_API_BASE_URL=http://127.0.0.1:8000`
     - `.env.development`: `VITE_API_BASE_URL=http://127.0.0.1:8000`
     - `vite.config.ts`: `host: '127.0.0.1'`

2. **ExternalSecret Management**
   - Local development: Consider disabling ExternalSecrets for easier debugging
   - Production: Ensure Vault credentials are synchronized with actual database configuration
   - Add documentation comment in externalsecret.yaml about credential source

3. **CORS Configuration**
   - Never use wildcard `*` when `withCredentials: true` is required
   - Explicitly list all development origins:
     ```yaml
     cors_origins: "http://localhost:3000,http://localhost:3001,http://localhost:8080,http://127.0.0.1:3000"
     ```

## Files Modified

### Created
- `/tmp/api-service-secret.yaml` - Static secret for local development

### Configuration Files (Reverted)
- `/Users/pwner/Git/ABS/blocksecops-dashboard/.env.development.local`
  - Initially changed to `localhost`, reverted to `127.0.0.1`
- `/Users/pwner/Git/ABS/blocksecops-dashboard/.env.development`
  - Initially changed to `localhost`, reverted to `127.0.0.1`
- `/Users/pwner/Git/ABS/blocksecops-dashboard/vite.config.ts`
  - Initially changed host to `'localhost'`, reverted to `'127.0.0.1'`

### Kubernetes Resources Modified
- Deleted: ExternalSecret `api-service-secret` in namespace `api-service-local`
- Created: Static Secret `api-service-secret` in namespace `api-service-local`

## Lessons Learned

1. **ExternalSecret Debugging is Complex**
   - ownerReferences prevent manual secret modifications
   - 15-second refresh interval means changes are quickly overwritten
   - For local debugging, consider using static secrets instead

2. **Database Credential Management**
   - Document the actual database credentials in multiple places
   - Ensure Vault credentials match actual database configuration
   - Consider using a secrets verification script in CI/CD

3. **Port Forwarding Best Practices**
   - Be explicit about IPv4 vs IPv6 binding
   - Use `127.0.0.1:PORT` in kubectl port-forward for IPv4
   - Kill stale processes before restarting port-forwards

4. **Systematic Troubleshooting**
   - Check pod logs first
   - Verify actual database configuration (not assumed)
   - Check for external controllers (like ExternalSecret) before manual fixes
   - Test at each layer: pod health → port-forward → API endpoint → dashboard

## Related Documentation

- `/Users/pwner/Git/ABS/blocksecops-docs/local-development/troubleshooting-guide.md`
- `/Users/pwner/Git/ABS/blocksecops-docs/local-development/vault-initialization.md`
- `/Users/pwner/Git/ABS/docs/VAULT-SETUP-QUICKSTART.md`
- `/Users/pwner/Git/ABS/docs/DASHBOARD-AUTHENTICATION-FIXES-2025-10-15.md`

## Current Status

✅ **RESOLVED** - Login functionality fully restored

### Services Running
- Dashboard: http://127.0.0.1:3000 ✅
- API Service: http://127.0.0.1:8000 ✅
- Database: Connected ✅
- Redis: Connected ✅

### Verified Functionality
- User authentication with test account
- HttpOnly cookie handling
- CORS with credentials
- Database queries
- Health checks

## Commands for Quick Reference

```bash
# Check API service status
kubectl get pods -n api-service-local
kubectl logs -n api-service-local -l app=api-service --tail=50

# Verify secret contents
kubectl get secret api-service-secret -n api-service-local -o jsonpath='{.data.DATABASE_URL}' | base64 -d

# Check for ExternalSecret
kubectl get externalsecret -n api-service-local

# Restart API service
kubectl delete pods --all -n api-service-local

# Test login
curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test-rebrand@blocksecops.com", "password": "TestPass123"}'
```

## Timeline

- **12:00 PM** - Issue reported: "signin is hanging"
- **12:05 PM** - Discovered CORS error in browser console
- **12:10 PM** - Attempted kubectl patch (incorrect approach)
- **12:15 PM** - Applied kustomize configuration (caused deployment failures)
- **12:30 PM** - Discovered database authentication errors
- **12:45 PM** - Found ExternalSecret was overwriting credentials
- **1:00 PM** - Deleted ExternalSecret and created static secret
- **1:05 PM** - API service successfully started
- **1:10 PM** - Login functionality verified working
- **1:15 PM** - Documentation completed

**Total Resolution Time:** ~1 hour 15 minutes
