# Development to Production Pipeline

**Version:** 1.0.0
**Last Updated:** March 1, 2026

## Overview

This document specifies the CI/CD pipeline architecture connecting GitHub to GKE production via GitHub Actions (CI) and Google Config Sync (CD). The pipeline follows the GitOps principle: Git is the single source of truth for both application code and infrastructure state.

**Key Principle:** CI and CD are two independent loops. Git is the sole coordination point between them.

---

## 1. Pipeline Architecture

```
                         GIT REPOSITORIES
          ┌──────────────────┬──────────────────┐
          │                  │                   │
          │  Service Repos   │  Infrastructure   │
          │  (app code)      │  (k8s manifests)  │
          │                  │                   │
          └────────┬─────────┴────────┬──────────┘
                   │                  │
      ┌────────────▼──────────┐  ┌───▼──────────────────┐
      │    LOOP 1: CI         │  │   LOOP 2: CD          │
      │    (GitHub Actions)   │  │   (Config Sync)       │
      └────────────┬──────────┘  └───┬──────────────────┘
                   │                 │
   ┌───────────────▼─────────┐  ┌───▼──────────────────┐
   │ 1. Push to main         │  │ 1. Poll Git repo      │
   │ 2. Lint → Test          │  │    (continuous)        │
   │ 3. Docker build         │  │ 2. Detect manifest    │
   │ 4. Push to Artifact Reg │  │    diff (newTag)       │
   │ 5. Update kustomization │  │ 3. Render kustomize   │
   │    newTag in infra repo │  │ 4. Apply to GKE       │
   │ 6. Commit manifest      │  │ 5. Rolling update     │
   └────────────┬────────────┘  │ 6. Drift correction   │
                │               └───┬──────────────────┘
                ▼                   ▼
   ┌─────────────────────┐  ┌──────────────────────┐
   │  Artifact Registry   │  │  GKE Cluster         │
   │  (image storage)     │◄─│  (pulls images)      │
   └─────────────────────┘  └──────────────────────┘
```

### Full End-to-End Sequence

```
Developer       Local Cluster   GitHub        GitHub Actions   Artifact Reg    gcp-infra repo   Config Sync     GKE
   │               │              │               │               │               │               │              │
   │──build+push──▶│ Harbor       │               │               │               │               │              │
   │──apply -k────▶│ local        │               │               │               │               │              │
   │──test────────▶│              │               │               │               │               │              │
   │               │              │               │               │               │               │              │
   │──commit+push────────────────▶│               │               │               │               │              │
   │──PR merge───────────────────▶│               │               │               │               │              │
   │               │              │──webhook──────▶│               │               │               │              │
   │               │              │               │──lint+test    │               │               │              │
   │               │              │               │──build+push──▶│               │               │              │
   │               │              │               │──update tag──────────────────▶│               │              │
   │               │              │               │               │               │──poll─────────▶│              │
   │               │              │               │               │               │               │──diff+apply─▶│
   │               │              │               │               │◄──────────────────────────────────image pull──│
   │               │              │               │               │               │               │──synced──────│
   │──verify prod──────────────────────────────────────────────────────────────────────────────────────────────▶│
```

---

## 2. CI Stages (GitHub Actions)

### Stage Overview

| Stage | Trigger | Input | Output | Duration |
|-------|---------|-------|--------|----------|
| Lint | Push to main | Source code | Pass/fail | ~30s |
| Test | After lint | Source + fixtures | Test report | ~2-5 min |
| Build | After test | Dockerfile + source | Docker image | ~3-10 min |
| Push | After build | Docker image | Image in Artifact Registry | ~30s-2 min |
| Update Manifests | After push | New image tag | Updated kustomization.yaml | ~15s |

### Stage 1: Lint

```yaml
# Runs language-specific linters
- name: Lint (Python)
  run: |
    ruff check src/
    ruff format --check src/

- name: Lint (TypeScript)
  run: |
    npm run lint
    npm run type-check
```

### Stage 2: Test

```yaml
# Unit and integration tests
- name: Test (Python)
  run: |
    pytest tests/ -v --tb=short

- name: Test (TypeScript)
  run: |
    npm run test -- --run

- name: Test (Rust)
  run: |
    cargo test --release
```

### Stage 3: Docker Build

```yaml
- name: Build Docker image
  run: |
    VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
    docker build \
      --build-arg SERVICE_VERSION=${VERSION} \
      --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
      --build-arg VCS_REF=${GITHUB_SHA::7} \
      -t ${ARTIFACT_REGISTRY}/${SERVICE}:${VERSION} .
```

### Stage 4: Push to Artifact Registry

```yaml
- name: Authenticate to GCP
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

- name: Push to Artifact Registry
  run: |
    gcloud auth configure-docker us-west1-docker.pkg.dev --quiet
    docker push ${ARTIFACT_REGISTRY}/${SERVICE}:${VERSION}
```

### Stage 5: Update Manifests

```yaml
- name: Update GCP kustomization
  run: |
    INFRA_REPO="blocksecops-gcp-infrastructure"
    git clone https://x-access-token:${GITHUB_TOKEN}@github.com/AdvancedBlockchainSecurity/${INFRA_REPO}.git
    cd ${INFRA_REPO}

    # Update image tag in GCP overlay
    KUSTOMIZATION="k8s/overlays/gcp/services/${SERVICE}/kustomization.yaml"
    sed -i "s/newTag: .*/newTag: \"${VERSION}\"/" ${KUSTOMIZATION}

    git add ${KUSTOMIZATION}
    git commit -m "ci(${SERVICE}): update image tag to ${VERSION}"
    git push origin main
```

---

## 3. CD Stages (Config Sync)

### Config Sync Behavior

| Action | Timing | Detail |
|--------|--------|--------|
| Poll Git | Continuous | Watches `main` branch of gcp-infrastructure repo |
| Detect diff | On poll | Compares rendered manifests vs live cluster state |
| Render | On diff | Runs `kustomize build` on `k8s/overlays/gcp/` |
| Apply | After render | kubectl apply equivalent — rolling update on Deployments |
| Verify | After apply | Waits for rollout completion |
| Drift correct | Continuous | Reverts any manual cluster changes to match Git |

### RootSync Configuration

```yaml
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
  override:
    reconcileTimeout: 5m
```

### Enable Config Sync on GKE

```bash
# Enable Config Management feature
gcloud container fleet config-management apply \
  --membership=blocksecops-gke \
  --config=config-sync.yaml \
  --project=<project-id>

# Create Git credentials secret
kubectl create secret generic git-creds \
  --namespace=config-management-system \
  --from-literal=username=x-access-token \
  --from-literal=token=${GITHUB_TOKEN}
```

### Verify Sync Status

```bash
# Check Config Sync status
gcloud beta container fleet config-management status \
  --project=<project-id>

# Or via kubectl
kubectl get rootsync root-sync -n config-management-system -o yaml
```

---

## 4. GitHub Actions Reusable Workflows

Organization-level reusable workflows in `.github` repository:

### Python Services

```yaml
# .github/workflows/ci-python.yml
name: CI — Python Service
on:
  workflow_call:
    inputs:
      service-name:
        required: true
        type: string

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.13"
      - run: pip install ruff
      - run: ruff check src/ && ruff format --check src/

  test:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.13"
      - run: pip install -e ".[test]"
      - run: pytest tests/ -v

  build-push:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write    # For Workload Identity Federation
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
      - run: gcloud auth configure-docker us-west1-docker.pkg.dev --quiet
      - run: |
          VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
          docker build \
            --build-arg SERVICE_VERSION=${VERSION} \
            -t us-west1-docker.pkg.dev/${{ secrets.GCP_PROJECT }}/blocksecops/${{ inputs.service-name }}:${VERSION} .
          docker push us-west1-docker.pkg.dev/${{ secrets.GCP_PROJECT }}/blocksecops/${{ inputs.service-name }}:${VERSION}

  update-manifests:
    needs: build-push
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: AdvancedBlockchainSecurity/blocksecops-gcp-infrastructure
          token: ${{ secrets.INFRA_REPO_TOKEN }}
      - run: |
          VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
          sed -i "s/newTag: .*/newTag: \"${VERSION}\"/" \
            k8s/overlays/gcp/services/${{ inputs.service-name }}/kustomization.yaml
          git add .
          git commit -m "ci(${{ inputs.service-name }}): update image to ${VERSION}"
          git push
```

### React Services

```yaml
# .github/workflows/ci-react.yml
name: CI — React Service
on:
  workflow_call:
    inputs:
      service-name:
        required: true
        type: string
    secrets:
      VITE_SUPABASE_URL:
        required: true
      VITE_SUPABASE_ANON_KEY:
        required: true

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "22"
      - run: npm ci
      - run: npm run lint && npm run type-check
      - run: npm run test -- --run
```

### Rust Services

```yaml
# .github/workflows/ci-rust.yml
name: CI — Rust Service
on:
  workflow_call:
    inputs:
      service-name:
        required: true
        type: string

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo clippy -- -D warnings
      - run: cargo test --release
```

### Service Workflow Caller

Each service repo has a caller workflow:

```yaml
# blocksecops-api-service/.github/workflows/release.yml
name: Release
on:
  push:
    branches: [main]

jobs:
  ci-cd:
    uses: AdvancedBlockchainSecurity/.github/.github/workflows/ci-python.yml@main
    with:
      service-name: api-service
    secrets: inherit
```

---

## 5. Authentication and Security

### Workload Identity Federation (OIDC)

GitHub Actions authenticates to GCP without long-lived service account keys:

```
GitHub Actions ──OIDC token──► GCP Workload Identity Pool
                                      │
                                      ▼
                               Service Account
                               (ci-push@project.iam)
                                      │
                                      ▼
                               Artifact Registry
                               (push permission)
```

**Setup:**

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --description="GitHub Actions OIDC"

# Create Provider
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

# Bind to Service Account
gcloud iam service-accounts add-iam-policy-binding \
  ci-push@<project>.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/<project-number>/locations/global/workloadIdentityPools/github-pool/attribute.repository/AdvancedBlockchainSecurity/*"
```

### Image Signing (Future)

Binary Authorization can enforce that only CI-built, signed images are deployed:

```bash
# Sign image after push (future enhancement)
cosign sign --key kms://... ${ARTIFACT_REGISTRY}/${SERVICE}:${VERSION}
```

---

## 6. Environment-Specific Configuration

| Setting | Local | GCP |
|---------|-------|-----|
| `REGISTRY` | `harbor.blocksecops.local` | `us-west1-docker.pkg.dev/<project>/blocksecops` |
| `DATABASE_URL` | `postgresql+asyncpg://...@postgresql.postgresql-local:5432/solidity_security` | `postgresql+asyncpg://...@postgresql.postgresql-prod:5432/solidity_security` |
| `REDIS_URL` | `redis://redis.redis-local:6379` | `redis://redis.redis-prod:6379` |
| `CORS_ORIGINS` | `https://app.0xapogee.com` | `https://app.0xapogee.com` |
| `VAULT_ADDR` | `http://vault.vault-local:8200` | N/A (GCP Secret Manager) |
| `SECRET_BACKEND` | Vault + ESO | GCP SM + ESO |
| `LOG_LEVEL` | `DEBUG` | `INFO` |
| `REPLICAS` | 1 | 2+ (HPA) |

---

## 7. Failure Handling

### CI Failures

| Failure | Action |
|---------|--------|
| Lint fails | Fix code style, push again |
| Tests fail | Fix tests locally, push again |
| Docker build fails | Fix Dockerfile or dependencies, push again |
| Artifact Registry push fails | Check auth (WIF), check quota |
| Manifest update fails | Check infra repo permissions |

### CD Failures

| Failure | Action |
|---------|--------|
| Config Sync out of sync | Check `gcloud beta container fleet config-management status` |
| Pod CrashLoopBackOff | Check logs, ExternalSecrets, ConfigMaps |
| Image pull fails | Verify image exists in Artifact Registry; check IAM |
| Drift detected | Config Sync auto-corrects; investigate manual changes |
| Rollout timeout | Check resource limits, pod scheduling, node capacity |

### Alerting

| Event | Channel | Severity |
|-------|---------|----------|
| CI workflow failure | GitHub notification + Slack | Warning |
| Config Sync out of sync > 10 min | GCP Monitoring alert | Critical |
| Pod CrashLoopBackOff | GCP Monitoring alert | Critical |
| Health endpoint 5xx | GCP Uptime Check alert | Critical |

---

## 8. Pipeline Comparison: Local vs Production

| Aspect | Local Pipeline | Production Pipeline |
|--------|---------------|---------------------|
| **Trigger** | Developer runs `deploy.sh` or manual commands | Git push to main |
| **CI** | None (developer tests locally) | GitHub Actions (lint, test, build, push) |
| **Registry** | Harbor (on-prem) | Artifact Registry (GCP) |
| **CD** | `kubectl apply -k` (manual) | Config Sync (automatic) |
| **Rollback** | `kubectl rollout undo` | `git revert` + Config Sync |
| **Drift detection** | None | Config Sync continuous |
| **Monitoring** | `kubectl logs` + health endpoints | GCP Monitoring + Uptime Checks |
| **Auth** | kubeconfig (local admin) | WIF (OIDC, no keys) |

---

## Related Documentation

- [Dev-to-Prod Deployment Playbook](../playbooks/dev-to-prod-deployment.md) — Step-by-step procedures
- [Dev-to-Prod Workflow](../workflows/dev-to-prod-workflow.md) — Visual workflow diagrams
- [GitOps CI/CD Pipeline](./gitops-ci-cd-pipeline.md) — Original CI/CD pipeline design
- [Local Build-Push-Apply Pipeline](./local-build-push-apply-pipeline.md) — Local pipeline details
- [Build Workflow Standards](../standards/build-workflow.md) — Docker build standards
- [Docker Image Versioning](../standards/docker-image-versioning.md) — Semver and tagging rules
- [Kustomize Standards](../standards/kustomize-standards.md) — Overlay patterns
