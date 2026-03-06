# Playbook: Deploy New Image to Cluster

**Version:** 2.0.0
**Last Updated:** March 6, 2026

## Overview

This playbook covers deploying a new Docker image to the local Kubernetes cluster for Apogee services.

---

## Prerequisites

- [ ] Docker running locally
- [ ] kubectl configured for local cluster
- [ ] Harbor registry accessible at `harbor.blocksecops.local`
- [ ] Service source code checked out

---

## Quick Reference

```bash
# Full deployment cycle
1. Update version in source (pyproject.toml / package.json)
2. Sync kustomization: /home/pwner/Git/blocksecops-shared/scripts/docker/sync-version.sh .
3. Build image with OCI labels (SERVICE_VERSION, BUILD_DATE, VCS_REF)
4. Push to Harbor
5. Apply kustomization: kubectl apply -k k8s/overlays/local/
6. Verify rollout
```

---

## Step 1: Update Version

### Python Services (api-service, etc.)

Edit `pyproject.toml`:
```toml
[project]
version = "X.Y.Z"  # Increment appropriately
```

### Node.js Services (dashboard, etc.)

Edit `package.json`:
```json
{
  "version": "X.Y.Z"
}
```

### Version Guidelines

| Change Type | Bump | Example |
|-------------|------|---------|
| Breaking change | MAJOR | 1.0.0 → 2.0.0 |
| New feature | MINOR | 1.0.0 → 1.1.0 |
| Bug fix | PATCH | 1.0.0 → 1.0.1 |

---

## Step 2: Build Docker Image

### Services Using Base Images (Orchestration, Intelligence-Engine)

These services use pre-built base images from Harbor for faster builds:

```bash
cd /home/pwner/Git/blocksecops-orchestration

# Set version
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)

# Build using base image (fast: ~2-3 min for code changes)
docker build \
  --build-arg BASE_IMAGE_TAG=1.0.0-ac02c353 \
  --build-arg SERVICE_VERSION=$VERSION \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/orchestration:$VERSION .
```

**Note:** Base images are stored in Harbor (use versioned tags, not `latest` — Harbor enforces immutable tags):
- `harbor.blocksecops.local/blocksecops/blocksecops-orchestration-base:1.0.0-ac02c353`
- `harbor.blocksecops.local/blocksecops/blocksecops-intelligence-base-cpu:1.0.0-5ede3c61`

To rebuild base images (only needed for dependency changes):
```bash
./docker/build-base-image.sh
docker push harbor.blocksecops.local/blocksecops/blocksecops-orchestration-base:1.0.0-ac02c353
```

### API Service (Python)

```bash
cd /home/pwner/Git/blocksecops-api-service

# Set version
VERSION="0.11.4"

# Build image
docker build \
  --build-arg SERVICE_VERSION=$VERSION \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/api-service:$VERSION .
```

### Dashboard (Node.js/TypeScript)

```bash
cd /home/pwner/Git

# Set version
VERSION="0.30.13"

# Get Supabase credentials from cluster
SUPABASE_URL=$(kubectl get configmap dashboard-config -n dashboard-local \
  -o jsonpath='{.data.supabase_url}')
SUPABASE_ANON_KEY=$(kubectl get configmap dashboard-config -n dashboard-local \
  -o jsonpath='{.data.supabase_anon_key}')

# Build from parent directory (monorepo structure)
docker build \
  -f blocksecops-dashboard/Dockerfile \
  --build-arg VITE_SUPABASE_URL=$SUPABASE_URL \
  --build-arg VITE_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --build-arg SERVICE_VERSION=$VERSION \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(cd blocksecops-dashboard && git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/dashboard:$VERSION .
```

### Build Tips

- Use `--no-cache` only when debugging build issues or rebuilding the same version tag
- With cache: ~10-30 seconds; without cache: ~2-5 minutes
- Monitor with `docker build` output or check `docker images` after

---

## Step 3: Push to Harbor Registry

```bash
# Push API service
docker push harbor.blocksecops.local/blocksecops/api-service:$VERSION

# Push Dashboard
docker push harbor.blocksecops.local/blocksecops/dashboard:$VERSION
```

### Verify Push

```bash
# List images in Harbor
curl -s https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories \
  --insecure | jq '.[].name'
```

---

## Step 4: Auto-Sync Kustomization (Recommended)

As of March 2026, version sync is automated. After updating the source file, run:

```bash
/home/pwner/Git/blocksecops-shared/scripts/docker/sync-version.sh .
```

This automatically updates all kustomization.yaml `newTag` values under `k8s/` to match the source version.

### Manual Kustomization Update (if auto-sync fails)

Edit the kustomization.yaml for the target environment:

### API Service

File: `k8s/overlays/local/api-service/kustomization.yaml`

```yaml
images:
  - name: blocksecops-api-service
    newName: harbor.blocksecops.local/blocksecops/api-service
    newTag: "0.11.4"  # Update to match source version
```

### Dashboard

File: `k8s/overlays/local/kustomization.yaml`

```yaml
images:
  - name: blocksecops-dashboard
    newName: harbor.blocksecops.local/blocksecops/dashboard
    newTag: "0.30.13"  # Update to match source version
```

---

## Step 5: Apply Deployment

### API Service

```bash
kubectl apply -k /home/pwner/Git/blocksecops-api-service/k8s/overlays/local/api-service/
```

### Dashboard

```bash
kubectl apply -k /home/pwner/Git/blocksecops-dashboard/k8s/overlays/local/
```

### Force Restart (if image tag unchanged)

```bash
# If you rebuilt the same tag, force pod restart
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout restart deployment/dashboard -n dashboard-local
```

---

## Step 6: Verify Rollout

### Wait for Rollout

```bash
# API Service
kubectl rollout status deployment/api-service -n api-service-local --timeout=120s

# Dashboard
kubectl rollout status deployment/dashboard -n dashboard-local --timeout=120s
```

### Check Pod Status

```bash
# API Service
kubectl get pods -n api-service-local -l app.kubernetes.io/name=api-service

# Dashboard
kubectl get pods -n dashboard-local -l app.kubernetes.io/name=dashboard
```

### Verify Image Version

```bash
# Check running image (Deployment)
kubectl get deployment api-service -n api-service-local \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check CronJob image (if applicable)
kubectl get cronjob -n api-service-local -o custom-columns='NAME:.metadata.name,IMAGE:.spec.jobTemplate.spec.template.spec.containers[0].image'
```

**IMPORTANT:** Kustomize `images` block applies to ALL resources. Both Deployments AND CronJobs will use the same version tag.

### Health Check

```bash
# API Service health
curl -s https://app.0xapogee.local/api/v1/health/ready --insecure

# Dashboard (check title in response)
curl -s https://app.0xapogee.local/ --insecure | grep -o '<title>.*</title>'
```

---

## Rollback Procedure

If deployment fails:

### Quick Rollback

```bash
# Rollback to previous revision
kubectl rollout undo deployment/api-service -n api-service-local
kubectl rollout undo deployment/dashboard -n dashboard-local
```

### Rollback to Specific Version

```bash
# Update kustomization.yaml to previous version
# Then apply
kubectl apply -k /path/to/overlay/

# Or use rollout history
kubectl rollout history deployment/api-service -n api-service-local
kubectl rollout undo deployment/api-service -n api-service-local --to-revision=N
```

---

## Troubleshooting

### Image Pull Failed

```bash
# Check pod events
kubectl describe pod -n api-service-local -l app.kubernetes.io/name=api-service

# Verify image exists in Harbor
docker pull harbor.blocksecops.local/blocksecops/api-service:$VERSION
```

### Pod CrashLoopBackOff

```bash
# Check logs
kubectl logs -n api-service-local deployment/api-service --tail=50

# Check previous container logs
kubectl logs -n api-service-local deployment/api-service --previous
```

### Deployment Stuck

```bash
# Check deployment status
kubectl describe deployment api-service -n api-service-local

# Check events
kubectl get events -n api-service-local --sort-by='.lastTimestamp' | tail -20
```

### Old Pod Still Running

```bash
# Force restart
kubectl rollout restart deployment/api-service -n api-service-local

# Or delete pods manually
kubectl delete pods -n api-service-local -l app.kubernetes.io/name=api-service
```

---

## Service-Specific Notes

### API Service

- Requires PostgreSQL and Redis running
- Check secrets are synced: `kubectl get externalsecret -n api-service-local`
- Health endpoints: `/api/v1/health/live`, `/api/v1/health/ready`, `/api/v1/health/startup`

### Dashboard

- Requires Supabase credentials at build time (baked into static assets)
- Uses `serve` to host static files on port 3000
- Clear browser cache after deployment (Ctrl+Shift+R)

### Other Services

| Service | Namespace | Port |
|---------|-----------|------|
| api-service | api-service-local | 8000 |
| dashboard | dashboard-local | 3000 |
| tool-integration | tool-integration-local | 8005 |
| notification | notification-local | 8003 |

---

## Checklist

- [ ] Version updated in source file
- [ ] Docker image built successfully
- [ ] Image pushed to Harbor
- [ ] Kustomization.yaml updated with new tag
- [ ] Deployment applied
- [ ] Rollout completed successfully
- [ ] CronJobs verified (same image as Deployment)
- [ ] Health check passed
- [ ] Smoke test passed (manual verification)

---

## Related Documentation

- [Versioning Standards](../development/versioning.md)
- [Docker Build Standards](../../blocksecops-api-service/docs/standards/docker-build-standards.md)
- [Troubleshooting](../Troubleshooting/README.md)
