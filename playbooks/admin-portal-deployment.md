# Admin Portal Deployment Playbook

**Version:** 1.2.0
**Created:** 2026-02-02
**Updated:** 2026-02-05
**Component:** blocksecops-admin-portal

---

## Overview

This playbook covers deployment of the separate admin portal to various environments. The admin portal is isolated from the customer dashboard at the network level (IP allowlist) while sharing the same Supabase project for authentication.

---

## Prerequisites

### Required Accounts/Services

- [ ] Supabase URL and keys available (same as customer dashboard)
- [ ] DNS configured for `admin.blocksecops.com` (production)
- [ ] TLS certificate available or Let's Encrypt configured
- [ ] IP allowlist configured in Traefik middleware (production)

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `VITE_ADMIN_SUPABASE_URL` | Supabase project URL (same as dashboard) | Yes |
| `VITE_ADMIN_SUPABASE_ANON_KEY` | Supabase anonymous key (same as dashboard) | Yes |
| `VITE_API_BASE_URL` | API service base URL | Yes |
| `VITE_ENVIRONMENT` | Environment name (local/production) | Yes |

> **Note:** The admin portal uses the same Supabase project as the customer dashboard. Security is enforced through IP allowlist, MFA requirements, and admin_role checks in the database.

---

## Local Development Deployment

### Step 1: Clone and Install

```bash
cd /home/pwner/Git
git clone <admin-portal-repo> blocksecops-admin-portal
cd blocksecops-admin-portal
npm install
```

### Step 2: Configure Environment

```bash
# Copy example env file
cp .env.example .env.local

# Edit with local values
cat > .env.local << 'EOF'
VITE_ADMIN_SUPABASE_URL=https://xxx.supabase.co
VITE_ADMIN_SUPABASE_ANON_KEY=eyJ...
VITE_API_BASE_URL=http://127.0.0.1:8000/api/v1
VITE_ENVIRONMENT=local
EOF
```

### Step 3: Start Development Server

```bash
npm run dev
# Access at http://localhost:5173
```

### Step 4: Deploy to Local Kubernetes

```bash
# Build Docker image
VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${VITE_ADMIN_SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${VITE_ADMIN_SUPABASE_ANON_KEY} \
  --build-arg VITE_API_BASE_URL=http://127.0.0.1:8000/api/v1 \
  --build-arg VITE_ENVIRONMENT=local \
  -t blocksecops-admin-portal:${VERSION} .

# Apply Kubernetes manifests
kubectl apply -k k8s/overlays/local/
```

---

## Server Deployment (kubeadm)

### Step 1: Build and Push to Harbor

```bash
cd /home/pwner/Git/blocksecops-admin-portal

VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
REGISTRY="harbor.blocksecops.local"

# Get environment variables from secrets/configmaps
ADMIN_SUPABASE_URL=$(kubectl get secret admin-supabase-credentials -o jsonpath='{.data.url}' | base64 -d)
ADMIN_SUPABASE_KEY=$(kubectl get secret admin-supabase-credentials -o jsonpath='{.data.anon_key}' | base64 -d)

# Build with build args
docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${ADMIN_SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${ADMIN_SUPABASE_KEY} \
  --build-arg VITE_API_BASE_URL=https://api.blocksecops.com/api/v1 \
  --build-arg VITE_ENVIRONMENT=production \
  -t ${REGISTRY}/blocksecops/admin-portal:${VERSION} .

# Push to Harbor
docker push ${REGISTRY}/blocksecops/admin-portal:${VERSION}
```

### Step 2: Update Kustomization

```bash
# Update image tag in kustomization
cd k8s/overlays/production
sed -i "s/newTag:.*/newTag: \"${VERSION}\"/" kustomization.yaml
```

### Step 3: Apply Kubernetes Manifests

```bash
kubectl apply -k k8s/overlays/production/
```

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/name=admin-portal

# Check ingress
kubectl get ingressroute admin-portal

# Test endpoint
curl -I https://admin.blocksecops.com
```

---

## Production Deployment (GCP)

### Step 1: Build and Push to Artifact Registry

```bash
cd /home/pwner/Git/blocksecops-admin-portal

VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
REGISTRY="us-central1-docker.pkg.dev/blocksecops/blocksecops"

# Get secrets from Secret Manager
ADMIN_SUPABASE_URL=$(gcloud secrets versions access latest --secret=admin-supabase-url)
ADMIN_SUPABASE_KEY=$(gcloud secrets versions access latest --secret=admin-supabase-anon-key)

# Build with build args
docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${ADMIN_SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${ADMIN_SUPABASE_KEY} \
  --build-arg VITE_API_BASE_URL=https://api.blocksecops.com/api/v1 \
  --build-arg VITE_ENVIRONMENT=production \
  -t ${REGISTRY}/admin-portal:${VERSION} .

# Push to Artifact Registry
docker push ${REGISTRY}/admin-portal:${VERSION}
```

### Step 2: Deploy via ArgoCD

ArgoCD will automatically detect the image change and deploy.

Or manually sync:

```bash
argocd app sync admin-portal
```

### Step 3: Verify DNS and TLS

```bash
# Check DNS resolution
dig admin.blocksecops.com

# Check TLS certificate
openssl s_client -connect admin.blocksecops.com:443 -servername admin.blocksecops.com < /dev/null 2>/dev/null | openssl x509 -noout -dates
```

---

## Backend Configuration

### API Service Environment Variables

Add to API service configuration:

```bash
# Admin Supabase credentials
ADMIN_SUPABASE_URL=https://xxx.supabase.co
ADMIN_SUPABASE_ANON_KEY=eyJ...
ADMIN_SUPABASE_SERVICE_KEY=eyJ...  # Service role key for admin operations
```

### Verify Backend Support

```bash
# Check admin auth endpoints work
curl -X POST https://api.blocksecops.com/api/v1/admin/auth/session \
  -H "Authorization: Bearer <admin-supabase-jwt>" \
  -H "Cookie: admin_session=<session-token>"

# Verify user management endpoints (returns 401 without auth)
curl -s https://api.blocksecops.com/api/v1/admin/users
# Expected: {"detail":"Not authenticated"}

# Verify organization endpoints (returns 401 without auth)
curl -s https://api.blocksecops.com/api/v1/admin/organizations
# Expected: {"detail":"Not authenticated"}
```

### Admin Portal Endpoints Reference

| Feature | Endpoint | API Version |
|---------|----------|-------------|
| User List | `/admin/users` | 0.22.4+ |
| User Detail | `/admin/users/{id}` | 0.22.4+ |
| User Actions | `/admin/users/{id}/*` | 0.22.4+ |
| Organization List | `/admin/organizations` | 0.22.4+ |
| Organization Detail | `/admin/organizations/{id}` | 0.22.4+ |
| Purchases | `/admin/purchases/*` | 0.22.0+ |
| Support | `/admin/support/*` | 0.22.0+ |
| System | `/admin/system/*` | 0.22.0+ |
| Emergency | `/admin/emergency/*` | 0.22.0+ |

---

## Rollback Procedure

### Quick Rollback

```bash
# Get previous version
kubectl rollout history deployment/admin-portal -n admin-portal

# Rollback to previous revision
kubectl rollout undo deployment/admin-portal -n admin-portal

# Or rollback to specific revision
kubectl rollout undo deployment/admin-portal -n admin-portal --to-revision=2
```

### Image Rollback

```bash
# Update kustomization to previous version
cd k8s/overlays/production
sed -i 's/newTag:.*/newTag: "0.1.0"/' kustomization.yaml

# Apply
kubectl apply -k .
```

---

## Troubleshooting

### Admin Portal Not Loading

1. Check pod status:
   ```bash
   kubectl get pods -l app.kubernetes.io/name=admin-portal
   kubectl logs -l app.kubernetes.io/name=admin-portal --tail=50
   ```

2. Check ingress:
   ```bash
   kubectl get ingressroute admin-portal -o yaml
   ```

3. Check service:
   ```bash
   kubectl get svc admin-portal
   kubectl get endpoints admin-portal
   ```

### Authentication Errors

1. Verify admin Supabase URL is correct:
   ```bash
   curl https://xxx.supabase.co/auth/v1/.well-known/jwks.json
   ```

2. Check browser console for CORS errors

3. Verify environment variables were baked into build:
   ```bash
   kubectl exec -it deployment/admin-portal -- cat /app/dist/assets/*.js | grep supabase
   ```

### MFA Verification Failing

1. Check server-side rate limiting:
   ```bash
   curl -X POST https://api.blocksecops.com/api/v1/admin/auth/mfa/verify \
     -H "Authorization: Bearer <token>" \
     -H "Content-Type: application/json" \
     -d '{"code": "123456"}'
   ```

2. Check MFA lockout status in database:
   ```sql
   SELECT email, mfa_failed_attempts, mfa_locked_until
   FROM users
   WHERE email = 'admin@blocksecops.com';
   ```

3. Reset MFA lockout (emergency):
   ```bash
   python -m src.cli.admin reset-mfa-lockout --email admin@blocksecops.com
   ```

---

## Security Checklist

Before deploying to production:

- [ ] Supabase credentials configured (same project as dashboard)
- [ ] TLS certificate configured and valid
- [ ] Security headers middleware enabled
- [ ] Rate limiting middleware enabled
- [ ] **IP allowlist REQUIRED** - restrict admin portal access to authorized networks
- [ ] Audit logging verified working
- [ ] MFA required for all admin accounts
- [ ] Admin roles assigned in database (`admin_role` column)

---

## Post-Deployment Health Verification

After deploying admin portal, verify the System page health monitoring:

### Dashboard Metrics Verification

```bash
# Access admin portal
# Local: http://admin.blocksecops.local:3000
# Server: http://admin.blocksecops.local

# Verify dashboard loads and shows all 8 KPI cards
# Verify system health panel shows component statuses
```

### System Page Verification

```bash
# Platform Services should show:
# - API Service: status + response time in ms (not "-")
# - All other services: status + response time

# Security Scanners should show:
# - All scanners with "Available" status (no "Degraded")
# - Scanner versions displayed

# If API Service response time shows "-":
# Check AdminSystem.tsx for responseTime assignment in isApiService branch
# See: docs/changelogs/ADMIN-SYSTEM-FIXES-2026-02-05.md

# If any scanner shows "Degraded":
# Check scanner job logs for HTTP 500 errors
# Likely JSON generation bug in scanner wrapper - see upgrade-scanner-image.md troubleshooting
```

### Build with OCI Labels (Required)

When building for server deployment, include OCI labels per standards:

```bash
VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  --build-arg VITE_ENVIRONMENT=local \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/admin-portal:${VERSION} .
```

> **Note:** Admin portal shares the same Supabase project as the customer dashboard. Credentials can be sourced from the `dashboard-config` ConfigMap in the `dashboard-local` namespace.

---

## Related Documentation

- [Platform Admin Guide](../admin/platform-admin.md)
- [Security Hardening](../../TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-01-24-SECURITY-HARDENING.md)
- [Admin Portal Isolation](../../TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-02-02-ADMIN-PORTAL-ISOLATION.md)
- [Admin System Fixes (2026-02-05)](../changelogs/ADMIN-SYSTEM-FIXES-2026-02-05.md)
- [Admin Dashboard Metrics Feature Test](../feature-tests/56-admin-dashboard-metrics.md)
