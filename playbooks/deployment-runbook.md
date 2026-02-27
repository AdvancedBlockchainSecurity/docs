# Playbook: Deployment Runbook

**Version:** 1.1.0
**Last Updated:** February 27, 2026
**Audience:** Platform Operator
**Priority:** High (must complete before go-live)

## Overview

Standard operating procedures for deploying services to GKE production and local development clusters.

---

## Pre-Deployment Checklist

- [ ] All unit tests passing (`pytest` — 0 failures)
- [ ] Feature branch merged to main via PR
- [ ] Version bumped in `pyproject.toml` / `package.json`
- [ ] Kustomization `newTag` updated to match version
- [ ] Docker image built and pushed to registry
- [ ] Database migrations tested (if applicable)
- [ ] Smoke test passing on staging/local
- [ ] Changelog written
- [ ] No unresolved security vulnerabilities in PR

---

## Standard Deployment (Local — kubectl)

### Single Service

```bash
SERVICE="api-service"
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# 1. Build and push
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION} .
docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}

# 2. Apply kustomization (updates Deployment + CronJob)
kubectl apply -k k8s/overlays/local/${SERVICE}/

# 3. Wait for rollout
kubectl rollout status deployment/${SERVICE} -n ${SERVICE}-local --timeout=120s

# 4. Verify
curl -sk https://app.blocksecops.local/api/v1/health/ready
```

### Multiple Services

Deploy in dependency order:

```
1. PostgreSQL, Redis, Vault (infrastructure — rarely redeployed)
2. data-service (database layer)
3. api-service (HTTP gateway)
4. celery-worker (background tasks)
5. intelligence-engine, tool-integration, orchestration (backend services)
6. notification (real-time)
7. dashboard, admin-portal (frontend)
```

---

## Standard Deployment (GCP Alpha — Manual)

### Prerequisites

```bash
# Authenticate to GCP
export GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token)

# Connect to GKE cluster
gcloud container clusters get-credentials blocksecops-staging-gke \
  --region us-west1 --project project-8a2657b9-d96c-4c0a-a69

# Verify access (admin IP must be 136.60.244.81/32)
kubectl get nodes
```

### Single Service Deployment

```bash
SERVICE="api-service"

# 1. Deploy (namespace + ExternalSecret + deployment)
kubectl apply -k k8s/overlays/gcp/services/${SERVICE}/

# 2. Verify ExternalSecret synced
kubectl get externalsecret -n ${SERVICE}-gcp
# STATUS should show "SecretSynced"

# 3. Wait for rollout
kubectl rollout status deployment/${SERVICE} -n ${SERVICE}-gcp --timeout=300s

# 4. Verify health
curl -I https://app.0xApogee.com/api/v1/health/live
```

### Full Platform Deployment (Dependency Order)

```
1. Infrastructure: kubectl apply -k k8s/overlays/gcp/  (PostgreSQL, Redis, Ingress, PriorityClasses, ExternalSecrets)
2. Create PostgreSQL credentials: kubectl create secret generic postgresql-credentials -n postgresql-gcp
3. data-service (database layer)
4. api-service (HTTP gateway — most services depend on it)
5. orchestration (workflow engine)
6. intelligence-engine (ML/AI)
7. notification (real-time, depends on Redis)
8. tool-integration, contract-parser (backend services)
9. analysis, findings (supporting services)
10. dashboard, admin-portal (frontends — last, depend on API)
```

### Secrets (GCP Secret Manager + ESO)

Secrets are stored in GCP Secret Manager and automatically synced via ExternalSecrets Operator. No manual `kubectl create secret` needed for services (only PostgreSQL credentials are manual).

```bash
# Populate secrets before first deployment
cd scripts/
./populate-secrets.sh --interactive
./populate-secrets.sh --verify
```

See [Secrets Management](../standards/secrets-management.md) for full details.

## Standard Deployment (GCP Production — ArgoCD)

### ArgoCD Sync

```bash
# 1. Push version changes to main
git push origin main

# 2. ArgoCD auto-syncs (3-minute poll interval)
# Or manual sync:
argocd app sync blocksecops-api-service

# 3. Monitor rollout
argocd app get blocksecops-api-service --show-operation

# 4. Verify health
argocd app get blocksecops-api-service | grep Health
```

### Manual Sync (If ArgoCD Unavailable)

```bash
# Connect to GKE cluster
gcloud container clusters get-credentials blocksecops-prod \
  --region us-west1 --project blocksecops-prod

# Apply kustomization
kubectl apply -k k8s/overlays/gcp-production/${SERVICE}/

# Wait for rollout
kubectl rollout status deployment/${SERVICE} -n ${SERVICE} --timeout=180s
```

---

## Database Migration Deployment

### Pre-Migration

```bash
# 1. MANDATORY: Create backup
gcloud sql backups create --instance=blocksecops-db \
  --description="Pre-migration $(date +%Y%m%d)" --async

# Or local:
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U blocksecops -d solidity_security -Fc \
  > backup_pre_migration_$(date +%Y%m%d).sql

# 2. Verify backup
gcloud sql backups list --instance=blocksecops-db | head -3

# 3. Review migration
cat alembic/versions/YYYYMMDD_HHMM-NNN_description.py
```

### Apply Migration

```bash
# Option A: Via pod exec (local)
kubectl exec -n api-service-local deploy/api-service -- \
  alembic upgrade head

# Option B: Via rebuilt image (preferred)
# Migration runs on startup if ALEMBIC_AUTO_UPGRADE=true

# 4. Verify migration applied
kubectl exec -n api-service-local deploy/api-service -- \
  alembic current
```

### Rollback Migration

```bash
# 1. Identify target revision
alembic history --verbose | head -10

# 2. Downgrade
kubectl exec -n api-service-local deploy/api-service -- \
  alembic downgrade -1

# 3. If downgrade fails, restore from backup
# Local:
pg_restore -h 127.0.0.1 -U blocksecops -d solidity_security backup.sql

# GCP:
gcloud sql backups restore BACKUP_ID --restore-instance=blocksecops-db
```

---

## Canary Deployment

For high-risk changes, deploy to a subset of traffic first.

### Local (Manual Canary)

```bash
# 1. Scale to 2 replicas
kubectl scale deployment/api-service -n api-service-local --replicas=2

# 2. Update one pod with new image
kubectl set image deployment/api-service -n api-service-local \
  api-service=${REGISTRY}/blocksecops/api-service:${NEW_VERSION}

# 3. Monitor for 10 minutes
kubectl logs -n api-service-local -l app=api-service --tail=50 -f

# 4. If healthy, scale back to 1
kubectl scale deployment/api-service -n api-service-local --replicas=1
```

### GCP (ArgoCD Progressive)

```yaml
# ArgoCD Application with canary strategy
spec:
  strategy:
    canary:
      steps:
        - setWeight: 10    # 10% traffic
        - pause: {duration: 5m}
        - setWeight: 50    # 50% traffic
        - pause: {duration: 10m}
        - setWeight: 100   # Full rollout
```

---

## Rollback Procedures

### Quick Rollback (Image Revert)

```bash
# 1. Find previous version
kubectl rollout history deployment/api-service -n api-service-local

# 2. Rollback to previous revision
kubectl rollout undo deployment/api-service -n api-service-local

# 3. Verify
kubectl rollout status deployment/api-service -n api-service-local
curl -sk https://app.blocksecops.local/api/v1/health/live
```

### Kustomization Rollback

```bash
# 1. Revert kustomization to previous version
# Edit k8s/overlays/local/api-service/kustomization.yaml
# Change newTag back to previous version

# 2. Apply
kubectl apply -k k8s/overlays/local/api-service/

# 3. Commit revert
git commit -am "revert(api-service): rollback to v${PREV_VERSION}"
```

---

## Post-Deployment Verification

### Health Checks

```bash
# API health
curl -sk https://app.blocksecops.local/api/v1/health/live
curl -sk https://app.blocksecops.local/api/v1/health/ready

# Service health (all 7 services)
for svc in data-service:8001 intelligence-engine:80 notification:8003 \
  orchestration:8004 tool-integration:8005 contract-parser:80; do
  name=$(echo $svc | cut -d: -f1)
  port=$(echo $svc | cut -d: -f2)
  kubectl exec -n api-service-local deploy/api-service -- \
    curl -sf "http://${name}.${name}-local.svc.cluster.local:${port}/health" \
    && echo " PASS $name" || echo " FAIL $name"
done
```

### Version Confirmation

```bash
# Verify deployed version
curl -sk https://app.blocksecops.local/api/v1/health/live | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['version'])"
```

### ExternalSecret Sync

```bash
kubectl get externalsecret --all-namespaces -o custom-columns=\
'NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[0].status'
```

### Smoke Test

```bash
# Run full smoke test
# See: docs/standards/smoke-test.md
```

---

## Deployment Decision Tree

```
Is this a database migration?
├── YES → Pre-migration backup → Apply migration → Verify → Deploy service
└── NO
    Is this a breaking API change?
    ├── YES → Canary deployment → Monitor → Full rollout
    └── NO
        Is this a security patch?
        ├── YES → Direct deployment → Verify immediately
        └── NO → Standard deployment
```

---

## Emergency Deployment

When ArgoCD is unavailable or immediate action is required:

```bash
# 1. Build image locally
docker build -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}-hotfix .
docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}-hotfix

# 2. Direct kubectl apply
kubectl set image deployment/${SERVICE} -n ${SERVICE}-local \
  ${SERVICE}=${REGISTRY}/blocksecops/${SERVICE}:${VERSION}-hotfix

# 3. IMMEDIATELY: Update kustomization and commit
# This ensures codebase-first rule is followed
```

---

## Related

- [Docker Image Versioning](../standards/docker-image-versioning.md)
- [Kustomize Standards](../standards/kustomize-standards.md)
- [Database Management](../standards/database-management.md)
- [Smoke Test](../standards/smoke-test.md)
- [Testing & Deployment](../standards/testing-deployment.md)
