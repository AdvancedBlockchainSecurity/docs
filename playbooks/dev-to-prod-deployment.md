# Playbook: Development to Production Deployment

**Version:** 1.0.0
**Last Updated:** March 1, 2026
**Audience:** Platform Developer, Platform Operator
**Priority:** Critical (standard deployment procedure)

## Overview

End-to-end deployment procedure for shipping code from local development to GCP production. This playbook covers the complete lifecycle:

```
Local Dev → Local Cluster → Test → Commit → GitHub Actions → Config Sync → GCP → Verify
```

**Key Principle:** Code is tested locally on a real Kubernetes cluster before it ever reaches production. The same Kustomize base manifests are used in both environments — only the overlay changes.

---

## Prerequisites

### Tools Required

| Tool | Purpose | Install |
|------|---------|---------|
| `docker` | Build container images | Docker Engine |
| `kubectl` | Cluster management | `apt install kubectl` |
| `kustomize` | Manifest rendering (built into kubectl) | Bundled with kubectl |
| `gh` | GitHub CLI for PRs | `apt install gh` |
| `curl` | API testing | Pre-installed |
| `git` | Version control | Pre-installed |

### Access Required

| Resource | Local | Production |
|----------|-------|------------|
| Kubernetes cluster | kubeadm on `debian-server` | GKE on GCP |
| Container registry | Harbor (`harbor.blocksecops.local`) | Artifact Registry (`us-west1-docker.pkg.dev`) |
| Domain | `app.0xapogee.local` | `app.0xapogee.com` |
| Secrets | HashiCorp Vault + ESO | GCP Secret Manager + ESO |
| Git repos | GitHub (push access) | GitHub (push access) |

### DNS Entries (one-time setup)

```bash
# On development server
echo "127.0.0.1  app.0xapogee.local" | sudo tee -a /etc/hosts

# On client machines
echo "192.168.86.225  app.0xapogee.local" | sudo tee -a /etc/hosts
```

---

## Phase 1: Local Development

### 1.1 Create Feature Branch

```bash
cd /home/pwner/Git/blocksecops-<service>
git checkout main && git pull origin main
git checkout -b feat/<short-description>
```

### 1.2 Make Code Changes

Edit source code, add tests, update configuration as needed.

### 1.3 Bump Version

```bash
# Python service
sed -i 's/version = ".*"/version = "X.Y.Z"/' pyproject.toml

# Node.js service
npm version X.Y.Z --no-git-tag-version
```

### 1.4 Update Local Kustomization

```bash
# Update image tag to match source version
vim k8s/overlays/local/<service>/kustomization.yaml
# Change newTag: "X.Y.Z"
```

### 1.5 Build and Push to Harbor

```bash
SERVICE="<service>"
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION} .

docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}
```

### 1.6 Deploy to Local Cluster

```bash
# Apply kustomization (updates Deployment + CronJobs)
kubectl apply -k k8s/overlays/local/${SERVICE}/

# Wait for rollout
kubectl rollout status deployment/${SERVICE} -n ${SERVICE}-local --timeout=120s
```

Or use the automated deploy script:

```bash
./scripts/deploy.sh
```

See [Local Deployment Workflow](../workflows/local-deployment-workflow.md) for detailed deploy.sh behavior.

---

## Phase 2: Local Testing

### 2.1 Health Checks

```bash
# API health
curl -sk https://app.0xapogee.local/api/v1/health/live
# Expected: {"status":"healthy","service":"Apogee API Service","version":"X.Y.Z"}

# API ready (includes DB, Redis checks)
curl -sk https://app.0xapogee.local/api/v1/health/ready
# Expected: {"ready":true,"checks":{"database":true,"service":true,"encryption":true}}
```

### 2.2 Smoke Test

Run the platform smoke test to verify nothing is broken:

```bash
# Pod status
kubectl get pods -n ${SERVICE}-local

# Verify image version matches
kubectl get deployment ${SERVICE} -n ${SERVICE}-local \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Test the specific feature you changed
curl -sk https://app.0xapogee.local/api/v1/<your-endpoint>
```

See [Smoke Test Standards](../standards/smoke-test.md) for the full smoke test procedure.

### 2.3 Security Headers

```bash
curl -sk -I https://app.0xapogee.local/api/v1/health/live | grep -E "strict-transport|x-frame|x-content|content-security"
```

### 2.4 Acceptance Criteria

Before proceeding to commit:

- [ ] Health endpoints return healthy
- [ ] New/changed feature works as expected
- [ ] No regressions in existing functionality
- [ ] Security headers present (HSTS, CSP, X-Frame-Options)
- [ ] No new errors in pod logs: `kubectl logs -n ${SERVICE}-local deployment/${SERVICE} --tail=50`

**CRITICAL:** Do NOT commit code that hasn't been tested locally. See [Testing & Deployment Standards](../standards/testing-deployment.md).

---

## Phase 3: Commit and Pull Request

### 3.1 Stage and Commit

```bash
cd /home/pwner/Git/blocksecops-<service>

# Stage changes (be specific — don't use git add -A)
git add src/ pyproject.toml k8s/overlays/local/<service>/kustomization.yaml

# Commit with conventional commit format
git commit -m "feat(<service>): <short description>

- Detailed change 1
- Detailed change 2

Refs: #<issue>"
```

### 3.2 Push and Create PR

```bash
git push -u origin feat/<short-description>

gh pr create \
  --title "feat(<service>): <short description>" \
  --body "## Summary
- What changed and why

## Testing
- Tested locally on kubeadm cluster
- Health endpoints verified
- Feature verified via curl/browser

## Checklist
- [x] Version bumped
- [x] Kustomization updated
- [x] Local deploy verified
- [x] No security vulnerabilities"
```

### 3.3 Merge to Main

After PR review:

```bash
gh pr merge <number> --merge
git checkout main && git pull origin main
```

See [Version Control Standards](../standards/version-control-standards.md) for commit format and PR requirements.

---

## Phase 4: CI — GitHub Actions

**Trigger:** Merge to `main` branch of any service repository.

GitHub Actions automatically:

1. **Lint** — Code style and static analysis
2. **Test** — Unit tests (`pytest` for Python, `vitest` for React, `cargo test` for Rust)
3. **Build** — Docker build with OCI labels
4. **Push** — Push image to GCP Artifact Registry
5. **Update manifests** — Update `newTag` in `blocksecops-gcp-infrastructure/k8s/overlays/gcp/services/<service>/kustomization.yaml`
6. **Commit** — Push manifest change to gcp-infrastructure repo

```
┌─────────────────────────────────────────────────────────────────┐
│  GitHub Actions (triggered on merge to main)                     │
│                                                                  │
│  lint → test → docker build → push to Artifact Registry          │
│                                        │                         │
│                               update kustomization newTag        │
│                                        │                         │
│                               commit to gcp-infrastructure       │
└─────────────────────────────────────────────────────────────────┘
```

### Image Tag Strategy

| Environment | Tag Format | Example |
|-------------|-----------|---------|
| Local (Harbor) | Semver from source | `0.29.44` |
| GCP (Artifact Registry) | `sha-<7char>` from CI | `sha-abc1234` |
| Kustomization (GCP) | Semver (updated by CI) | `0.29.44` |

### Artifact Registry Authentication

GitHub Actions authenticates to Artifact Registry via **Workload Identity Federation** (OIDC). No long-lived service account keys.

See [Dev-to-Prod Pipeline](../pipelines/dev-to-prod-pipeline.md) for full CI stage details.

---

## Phase 5: CD — Google Config Sync

**Trigger:** Manifest change committed to `blocksecops-gcp-infrastructure` repo (by CI in Phase 4).

Config Sync continuously watches the Git repository and applies changes to the GKE cluster:

```
┌─────────────────────────────────────────────────────────────────┐
│  Config Sync (running on GKE)                                    │
│                                                                  │
│  1. Poll gcp-infrastructure repo (configurable interval)         │
│  2. Detect manifest diff (kustomization newTag changed)          │
│  3. Render kustomize overlays                                    │
│  4. Apply to GKE cluster (rolling update)                        │
│  5. Report sync status                                           │
│  6. Continuous drift detection                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Config Sync Setup

```yaml
# RootSync resource on GKE
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: https://github.com/AdvancedBlockchainSecurity/blocksecops-gcp-infrastructure
    branch: main
    dir: k8s/overlays/gcp
    auth: token
    secretRef:
      name: git-creds
```

### What Config Sync Replaces

Config Sync replaces ArgoCD for GCP deployments. It is free with GKE and provides:
- GitOps sync (watch Git, apply to cluster)
- Drift detection and auto-correction
- Kustomize rendering
- Multi-cluster support (via Fleet)

See [Dev-to-Prod Workflow](../workflows/dev-to-prod-workflow.md) for Config Sync architecture.

---

## Phase 6: Production Verification

### 6.1 Health Checks

```bash
# API health
curl -s https://app.0xapogee.com/api/v1/health/live
# Expected: {"status":"healthy","version":"X.Y.Z"}

# API ready
curl -s https://app.0xapogee.com/api/v1/health/ready
# Expected: {"ready":true}
```

### 6.2 Version Verification

```bash
# Verify deployed version matches what was pushed
curl -s https://app.0xapogee.com/api/v1/health/live | jq -r '.version'
# Expected: X.Y.Z (matches pyproject.toml)
```

### 6.3 Security Headers

```bash
curl -sI https://app.0xapogee.com/api/v1/health/live | grep -E "strict-transport|x-frame|x-content"
```

### 6.4 Production Smoke Test

- [ ] Dashboard loads at `https://app.0xapogee.com`
- [ ] Login works (JWT auth)
- [ ] API key authentication works
- [ ] Contract creation succeeds
- [ ] Scan triggers and completes
- [ ] No 5xx errors in logs

### 6.5 Monitoring

```bash
# Check pod status on GKE
kubectl get pods -n <service>-gcp

# Check for CrashLoopBackOff or OOMKilled
kubectl get events -n <service>-gcp --sort-by='.lastTimestamp' | tail -10
```

---

## Rollback Procedures

### Local Rollback

```bash
# Roll back to previous deployment version
kubectl rollout undo deployment/${SERVICE} -n ${SERVICE}-local

# Verify rollback
kubectl rollout status deployment/${SERVICE} -n ${SERVICE}-local
```

### Production Rollback

```bash
# Option 1: Git revert (preferred — maintains GitOps)
cd /home/pwner/Git/blocksecops-gcp-infrastructure
git revert HEAD   # Reverts the kustomization newTag change
git push origin main
# Config Sync detects the revert and rolls back the cluster

# Option 2: kubectl rollback (emergency only)
kubectl rollout undo deployment/<service> -n <service>-gcp
# WARNING: This creates drift between Git and cluster state.
# Follow up by reverting the Git change immediately.
```

**CRITICAL:** Do NOT rollback a working deployment to undo uncommitted changes. If deployed code works but isn't committed, commit to match — don't roll back. See [Testing & Deployment Standards](../standards/testing-deployment.md).

---

## Emergency Hotfix Workflow

For critical production issues requiring immediate fix:

```
1. Create hotfix branch from main
   git checkout -b hotfix/<description>

2. Make minimal fix
3. Test locally (Phase 1-2)
4. Commit and push
5. Create urgent PR
6. Merge to main
7. GitHub Actions runs CI automatically (Phase 4)
8. Config Sync deploys to production (Phase 5)
9. Verify in production (Phase 6)
10. Document the hotfix
```

For the fastest possible deployment, the developer can also manually push the image and update the GCP kustomization:

```bash
# Manual emergency push to Artifact Registry
REGISTRY="us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/blocksecops"
docker build -t ${REGISTRY}/<service>:<version> .
docker push ${REGISTRY}/<service>:<version>

# Update GCP overlay manually
cd /home/pwner/Git/blocksecops-gcp-infrastructure
# Edit k8s/overlays/gcp/services/<service>/kustomization.yaml
git add . && git commit -m "hotfix: <description>" && git push
# Config Sync picks up the change
```

---

## Pre-Deployment Checklist

- [ ] Code changes tested locally on kubeadm cluster
- [ ] Health endpoints return healthy after local deploy
- [ ] Version bumped in `pyproject.toml` / `package.json`
- [ ] Kustomization `newTag` matches source version
- [ ] Docker image built and pushed to Harbor
- [ ] Feature branch merged to main via PR
- [ ] No unresolved security vulnerabilities
- [ ] Database migrations tested (if applicable)
- [ ] Documentation updated (if applicable)

## Post-Deployment Checklist (Production)

- [ ] Health endpoint returns healthy with correct version
- [ ] No 5xx errors in production logs
- [ ] Security headers present (HSTS, CSP, X-Frame-Options)
- [ ] Key user flows work (login, contract creation, scan)
- [ ] No CrashLoopBackOff or OOMKilled events
- [ ] Monitoring shows normal metrics
- [ ] Config Sync shows Synced status

---

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Local deploy fails | Version mismatch | Ensure `pyproject.toml` version matches `kustomization.yaml` `newTag` |
| Harbor push rejected | Immutable tag exists | Bump version — cannot overwrite existing tags |
| GitHub Actions fails | Test failures | Fix tests locally, push again |
| Config Sync not syncing | Git credentials expired | Refresh `git-creds` secret in `config-management-system` namespace |
| Production pod CrashLoop | Missing env vars / secrets | Check ExternalSecret status: `kubectl get es -n <service>-gcp` |
| Version drift | CI didn't update manifest | Check GitHub Actions run; manually update if needed |
| HSTS missing in prod | Load Balancer config | Verify GCP FrontendConfig has HTTPS redirect |

---

## Related Documentation

- [Deployment Runbook](./deployment-runbook.md) — Detailed deployment procedures
- [Dev-to-Prod Workflow](../workflows/dev-to-prod-workflow.md) — Visual workflow diagrams
- [Dev-to-Prod Pipeline](../pipelines/dev-to-prod-pipeline.md) — CI/CD pipeline specification
- [Local Deployment Workflow](../workflows/local-deployment-workflow.md) — Local deploy.sh details
- [Build Workflow Standards](../standards/build-workflow.md) — Docker build standards
- [Testing & Deployment Standards](../standards/testing-deployment.md) — Test-first deployment rules
- [Version Control Standards](../standards/version-control-standards.md) — Git workflow
- [Kustomize Standards](../standards/kustomize-standards.md) — Overlay patterns
- [Smoke Test](../standards/smoke-test.md) — Post-deployment verification
