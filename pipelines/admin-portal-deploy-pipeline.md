# Admin Portal Deploy Pipeline

**Version:** 1.0.0
**Last Updated:** February 27, 2026
**Status:** Active

## Overview

The admin portal is a React (Vite) SPA that authenticates via Supabase and communicates with the API service. Supabase credentials are baked into static assets at build time via `--build-arg`.

```
Developer
    │
    ▼
package.json (version bump)
    │
    ▼
kustomization.yaml (newTag update)
    │
    ▼
docker build (with Supabase build args)
    │
    ▼
Harbor (immutable tag push)
    │
    ▼
kubectl apply -k (deploy to cluster)
    │
    ▼
Verify: bundle contents, health check, MFA flow
```

## Pipeline Steps

### 1. Version Bump

```bash
cd /home/pwner/Git/blocksecops-admin-portal

# Bump version in package.json
npm version patch --no-git-tag-version
VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)

# Update kustomization newTag
sed -i "s/newTag: \".*\"/newTag: \"${VERSION}\"/" k8s/overlays/local/kustomization.yaml
sed -i "s/app.kubernetes.io\/version: \".*\"/app.kubernetes.io\/version: \"${VERSION}\"/" k8s/overlays/local/kustomization.yaml
```

### 2. Build with Supabase Credentials

Supabase credentials are sourced from the dashboard ConfigMap (same project):

```bash
REGISTRY="harbor.blocksecops.local"
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL="${SUPABASE_URL}" \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY="${SUPABASE_KEY}" \
  --build-arg VITE_API_BASE_URL=/api/v1 \
  --build-arg VITE_ENVIRONMENT=local \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/admin-portal:${VERSION} .
```

### 3. Push and Deploy

```bash
docker push ${REGISTRY}/blocksecops/admin-portal:${VERSION}
kubectl apply -k k8s/overlays/local/
kubectl rollout status deployment/admin-portal -n admin-portal-local --timeout=60s
```

### 4. Verify

```bash
# Health check
curl -sk https://admin.0xapogee.local/ -o /dev/null -w "%{http_code}"
# Expected: 200

# Verify Supabase URL baked in
kubectl exec -n admin-portal-local deployment/admin-portal -- \
  grep -c 'supabase.co' /app/dist/assets/index-*.js
# Expected: >= 1

# Verify no stale API calls
kubectl exec -n admin-portal-local deployment/admin-portal -- \
  grep -c 'admin/auth/login' /app/dist/assets/index-*.js
# Expected: 0

# Verify image tag
kubectl get deployment -n admin-portal-local admin-portal \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: harbor.blocksecops.local/blocksecops/admin-portal:<VERSION>
```

## Key Differences from Backend Services

| Aspect | Backend (Python) | Admin Portal (React) |
|--------|-----------------|---------------------|
| Version source | `pyproject.toml` | `package.json` |
| Build context | Service directory | Service directory |
| Build args | SERVICE_VERSION only | Supabase URL + key + environment |
| Runtime env vars | ConfigMap → env | None (static assets) |
| Credential source | Vault/ExternalSecret | Baked at build time |
| Auth flow | N/A | Supabase SDK (client-side) |

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `POST /admin/auth/login` → 404 | Stale JS bundle from old `dist/` | Rebuild from source |
| MFA verify always fails | Encryption key changed, old secret undecryptable | Reset MFA in DB, see [MFA Recovery](../playbooks/admin-mfa-lockout-reset.md) |
| Build fails with TS error | TypeScript strict mode catches unused vars | Fix the error (e.g., rename `e` to `_e`) |
| Supabase auth fails | Wrong VITE_ADMIN_SUPABASE_URL baked in | Rebuild with correct credentials |

## Related Documentation

- [Admin Portal Deployment Playbook](../playbooks/admin-portal-deployment.md)
- [Admin MFA Recovery](../playbooks/admin-mfa-lockout-reset.md)
- [Docker Image Versioning](../standards/docker-image-versioning.md)
- [Frontend Build-Time Environment Variables](../standards/frontend-build-env.md)
