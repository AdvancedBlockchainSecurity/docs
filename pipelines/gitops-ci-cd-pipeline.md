# GitOps CI/CD Pipeline — BlockSecOps Platform

## Overview

This document defines the CI/CD pipeline architecture for all BlockSecOps services, connecting GitHub.com to GKE via GCP Artifact Registry, with ArgoCD as the GitOps controller.

**Key principle:** CI and CD are two independent loops. Git is the sole coordination point.
**Sources:** Actual Dockerfiles in each repo, `blocksecops-gcp-infrastructure/k8s/overlays/gcp/argocd/applications/applicationset.yaml`, `docs/INFRA-AGENT.md`.

---

## 1. Pipeline Architecture

### Corrected Pipeline Model

```
                              GIT REPOSITORY
                      (blocksecops-gcp-infrastructure)
                                    │
                 ┌──────────────────┴──────────────────┐
                 │                                      │
        ┌────────▼────────┐                    ┌────────▼────────┐
        │   LOOP 1: CI    │                    │   LOOP 2: CD    │
        │  (GitHub Actions)│                    │   (ArgoCD)      │
        └────────┬────────┘                    └────────┬────────┘
                 │                                      │
    ┌────────────▼──────────────┐          ┌────────────▼──────────────┐
    │  1. Developer pushes code │          │  1. ArgoCD polls Git      │
    │  2. CI triggers on main   │          │     (3 min interval)      │
    │  3. Lint → Test → Build   │          │  2. Detects manifest diff │
    │  4. Docker build          │          │  3. Compares desired vs   │
    │  5. Push to Artifact Reg  │          │     live state on GKE     │
    │  6. Update image tag in   │          │  4. Applies rolling update│
    │     gcp-infrastructure    │          │  5. Reports sync status   │
    └───────────────────────────┘          └───────────────────────────┘
                 │                                      │
                 ▼                                      ▼
    ┌───────────────────────┐              ┌───────────────────────┐
    │  GCP Artifact Registry│              │  GKE Cluster (GCP)    │
    │  (Image Storage)      │◄─────────────│  (Pulls images)       │
    └───────────────────────┘   image pull └───────────────────────┘
```

### Full End-to-End Flow

```
Developer            GitHub              GitHub Actions         Artifact Registry      gcp-infrastructure     ArgoCD              GKE
   │                   │                      │                      │                      │                   │                  │
   │──git push────────▶│                      │                      │                      │                   │                  │
   │                   │──webhook────────────▶│                      │                      │                   │                  │
   │                   │                      │──lint/test──────────▶│                      │                   │                  │
   │                   │                      │──docker build+push──▶│                      │                   │                  │
   │                   │                      │                      │  sha-abc1234         │                   │                  │
   │                   │                      │──update image tag──────────────────────────▶│                   │                  │
   │                   │                      │                      │                      │◄──poll (3 min)────│                  │
   │                   │                      │                      │                      │──manifest diff───▶│                  │
   │                   │                      │                      │                      │                   │──sync───────────▶│
   │                   │                      │                      │◄─────────────────────────────────────────────image pull──────│
   │                   │                      │                      │                      │                   │──status: Synced──│
```

### What ArgoCD Does NOT Do

- ArgoCD does **not** build images
- ArgoCD does **not** run tests
- ArgoCD does **not** receive webhooks from GitHub Actions
- ArgoCD **only** watches Git and syncs to clusters

---

## 2. Current State: What Exists vs What's Missing

### Dockerfiles (13 of 14 services have them)

| Service | Dockerfile | Base Image | Notes |
|---------|-----------|-----------|-------|
| api-service | YES | `python:3.11-slim` | Multi-stage |
| data-service | YES | `python:3.11-slim` | Multi-stage |
| orchestration | YES | Custom `blocksecops-orchestration-base` (5.32GB) | Includes scanner tools |
| tool-integration | YES | `python:3.11-slim` | Multi-stage |
| intelligence-engine | YES | Custom `blocksecops-intelligence-base-cpu` (1.85GB) | Includes PyTorch/ML |
| contract-parser | YES | `rust:1.90-slim` | Multi-stage → minimal runtime |
| notification | YES | `python:3.11-slim` | Multi-stage (rewritten from Node.js) |
| dashboard | YES | `node:20-alpine` → nginx | Multi-stage |
| admin-portal | YES | `node:20-alpine` → nginx | Multi-stage |
| findings | YES | `node:18-alpine` → nginx | Static site |
| analysis | YES | `node:18-alpine` → nginx | Static site |
| ui-core | YES | `node:18-alpine` | Multi-stage |
| monitoring | **NO** | — | Needs to be created |

### GitHub Actions Workflows

| Service | Workflows | Status |
|---------|----------|--------|
| api-service | `release.yml`, `test.yml` | EXISTS |
| All other 11 services | None | **NEEDS CREATION** |

---

## 3. CI Pipeline Templates Per Stack

### 3a. Python Services (7 services)

**Applies to:** `api-service`, `data-service`, `orchestration`, `tool-integration`, `intelligence-engine`, `notification`, `monitoring`

All use Python 3.11 with FastAPI. Two services use pre-built custom base images (orchestration, intelligence-engine).

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  id-token: write  # OIDC for GCP auth

env:
  REGISTRY: us-west1-docker.pkg.dev
  PROJECT_ID: ${{ vars.GCP_PROJECT_ID }}
  REPOSITORY: solidity-security-production-docker
  IMAGE_NAME: ${{ github.event.repository.name }}

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip

      - run: pip install -r requirements.txt -r requirements-dev.txt

      - name: Lint
        run: ruff check .

      - name: Type check
        run: mypy .

      - name: Test
        run: pytest --cov --cov-report=xml

      - name: Security scan
        run: |
          pip install bandit safety
          bandit -r src/ -ll
          safety check

  build-and-push:
    needs: lint-and-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tag }}
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ vars.GCP_CI_SERVICE_ACCOUNT }}

      - uses: google-github-actions/setup-gcloud@v2

      - run: gcloud auth configure-docker ${{ env.REGISTRY }}

      - id: meta
        run: echo "tag=sha-${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.tag }}

  update-manifests:
    needs: build-and-push
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: BlockSecOps/blocksecops-gcp-infrastructure
          token: ${{ secrets.GCP_INFRA_REPO_TOKEN }}

      - name: Update image tag
        run: |
          cd k8s/overlays/gcp/services/${{ env.IMAGE_NAME }}
          # Update the image tag in kustomization.yaml or deployment patch
          sed -i "s|newTag:.*|newTag: \"${{ needs.build-and-push.outputs.image-tag }}\"|" kustomization.yaml

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          git commit -m "chore(${{ env.IMAGE_NAME }}): update image to ${{ needs.build-and-push.outputs.image-tag }}"
          git push
```

### 3b. Pure Rust (1 service)

**Applies to:** `contract-parser`

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  id-token: write

env:
  REGISTRY: us-west1-docker.pkg.dev
  PROJECT_ID: ${{ vars.GCP_PROJECT_ID }}
  REPOSITORY: solidity-security-production-docker
  IMAGE_NAME: contract-parser

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt

      - uses: Swatinem/rust-cache@v2

      - name: Format check
        run: cargo fmt --check

      - name: Clippy
        run: cargo clippy -- -D warnings

      - name: Test
        run: cargo test

      - name: Security audit
        run: |
          cargo install cargo-audit
          cargo audit

  build-and-push:
    needs: lint-and-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tag }}
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ vars.GCP_CI_SERVICE_ACCOUNT }}

      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud auth configure-docker ${{ env.REGISTRY }}

      - id: meta
        run: echo "tag=sha-${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"

      # Uses existing multi-stage Dockerfile: rust:1.90-slim builder → minimal runtime
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.tag }}

  update-manifests:
    needs: build-and-push
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: BlockSecOps/blocksecops-gcp-infrastructure
          token: ${{ secrets.GCP_INFRA_REPO_TOKEN }}

      - name: Update image tag
        run: |
          cd k8s/overlays/gcp/services/${{ env.IMAGE_NAME }}
          sed -i "s|newTag:.*|newTag: \"${{ needs.build-and-push.outputs.image-tag }}\"|" kustomization.yaml

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          git commit -m "chore(${{ env.IMAGE_NAME }}): update image to ${{ needs.build-and-push.outputs.image-tag }}"
          git push
```

### 3c. React Frontends (4 services)

**Applies to:** `dashboard`, `admin-portal` (Node 20), `findings`, `analysis` (Node 18, static sites)

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  id-token: write

env:
  REGISTRY: us-west1-docker.pkg.dev
  PROJECT_ID: ${{ vars.GCP_PROJECT_ID }}
  REPOSITORY: solidity-security-production-docker
  IMAGE_NAME: ${{ github.event.repository.name }}

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: "20"  # Use "18" for findings/analysis
          cache: npm

      - run: npm ci

      - name: Lint
        run: npx eslint .

      - name: Type check
        run: npx tsc --noEmit

      - name: Test
        run: npx vitest run --coverage

      - name: Build
        run: npm run build

  build-and-push:
    needs: lint-and-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tag }}
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ vars.GCP_CI_SERVICE_ACCOUNT }}

      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud auth configure-docker ${{ env.REGISTRY }}

      - id: meta
        run: echo "tag=sha-${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"

      # Multi-stage: Node builder → nginx:alpine serving static assets
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.PROJECT_ID }}/${{ env.REPOSITORY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.tag }}

  update-manifests:
    needs: build-and-push
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: BlockSecOps/blocksecops-gcp-infrastructure
          token: ${{ secrets.GCP_INFRA_REPO_TOKEN }}

      - name: Update image tag
        run: |
          cd k8s/overlays/gcp/services/${{ env.IMAGE_NAME }}
          sed -i "s|newTag:.*|newTag: \"${{ needs.build-and-push.outputs.image-tag }}\"|" kustomization.yaml

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          git commit -m "chore(${{ env.IMAGE_NAME }}): update image to ${{ needs.build-and-push.outputs.image-tag }}"
          git push
```

### 3d. Terraform

**Applies to:** `gcp-infrastructure`

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    branches: [main]
    paths: ['terraform/**']

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.5"

      - name: Format check
        run: terraform fmt -check -recursive

      - name: Init
        run: terraform init -backend=false
        working-directory: terraform/

      - name: Validate
        run: terraform validate
        working-directory: terraform/

  plan:
    needs: validate
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ vars.GCP_TERRAFORM_SA }}

      - uses: hashicorp/setup-terraform@v3

      - name: Plan
        run: terraform plan -no-color
        working-directory: terraform/environments/production/

  apply:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ vars.GCP_TERRAFORM_SA }}

      - uses: hashicorp/setup-terraform@v3

      - name: Apply
        run: terraform apply -auto-approve
        working-directory: terraform/environments/production/
```

---

## 4. Image Tag Promotion Flow

### Tag Strategy

| Tag Format | Source | Purpose | Lifetime |
|------------|--------|---------|----------|
| `sha-{7-char}` | Git SHA | Every main build | Cleaned after 7 days if untagged |
| `v{major}.{minor}.{patch}` | Git tag | Release versions | Kept (10 most recent) |
| `latest` | **Never used** | Non-deterministic, breaks GitOps | — |

### Where Image Tags Live

The existing GCP ApplicationSet points all services at `blocksecops-gcp-infrastructure`:

```yaml
source:
  repoURL: https://github.com/BlockSecOps/blocksecops-gcp-infrastructure.git
  path: 'k8s/overlays/gcp/services/{{ .name }}'
```

So image tags are updated in:

```
blocksecops-gcp-infrastructure/
└── k8s/
    └── overlays/
        └── gcp/
            └── services/
                ├── api-service/kustomization.yaml     ← CI updates newTag here
                ├── orchestration/kustomization.yaml
                ├── data-service/kustomization.yaml
                ├── intelligence-engine/kustomization.yaml
                ├── dashboard/kustomization.yaml
                ├── notification/kustomization.yaml
                ├── tool-integration/kustomization.yaml
                ├── analysis/kustomization.yaml
                ├── findings/kustomization.yaml
                ├── contract-parser/kustomization.yaml
                ├── admin-portal/kustomization.yaml
                └── scanner-jobs/                       ← RBAC only, no image
```

---

## 5. GCP Artifact Registry Integration

### Registry Configuration (from Terraform module)

| Setting | Value |
|---------|-------|
| Format | Docker |
| Region | `us-west1` |
| Repo ID | `solidity-security-{env}-docker` |
| URL | `us-west1-docker.pkg.dev/{project_id}/solidity-security-{env}-docker` |
| Cleanup: Untagged | Deleted after 7 days |
| Cleanup: Versions | 10 most recent kept |
| GKE Pull Access | `{project}-compute@developer.gserviceaccount.com` has `artifactregistry.reader` |

### Authentication: GitHub Actions → Artifact Registry (OIDC)

Uses Workload Identity Federation — no long-lived service account keys.

**Required GCP Terraform resources** (to add to `gcp-infrastructure`):

```hcl
# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_ci" {
  account_id   = "github-ci"
  display_name = "GitHub Actions CI"
}

resource "google_artifact_registry_repository_iam_member" "ci_writer" {
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_ci.email}"
}
```

### Authentication: GKE → Artifact Registry (Image Pull)

Already configured in the Terraform module. GKE compute service account has `artifactregistry.reader` role.

### Image Naming Convention

```
us-west1-docker.pkg.dev/{project_id}/solidity-security-{env}-docker/{service-name}:{tag}
```

All 12 deployable services follow this pattern.

---

## 6. Reusable Workflow Strategy

### Organization-Level Reusable Workflows

Create a `.github` repository in the BlockSecOps GitHub organization:

```
BlockSecOps/.github/
└── .github/
    └── workflows/
        ├── ci-python.yml          # Reusable: lint + test Python 3.11
        ├── ci-rust.yml            # Reusable: lint + test Rust
        ├── ci-react.yml           # Reusable: lint + test + build React/Node
        ├── ci-terraform.yml       # Reusable: fmt + validate + plan
        ├── docker-build-push.yml  # Reusable: build + push to Artifact Registry
        └── update-manifests.yml   # Reusable: update image tag in gcp-infrastructure
```

### How Services Consume Reusable Workflows

Each service repo has a thin `ci.yml`:

```yaml
# blocksecops-api-service/.github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    uses: BlockSecOps/.github/.github/workflows/ci-python.yml@main
    with:
      python-version: "3.11"

  build-and-push:
    needs: lint-and-test
    if: github.ref == 'refs/heads/main'
    uses: BlockSecOps/.github/.github/workflows/docker-build-push.yml@main
    with:
      image-name: api-service
    secrets: inherit

  update-manifests:
    needs: build-and-push
    if: github.ref == 'refs/heads/main'
    uses: BlockSecOps/.github/.github/workflows/update-manifests.yml@main
    with:
      image-name: api-service
      image-tag: ${{ needs.build-and-push.outputs.image-tag }}
    secrets: inherit
```

### Custom Base Image Consideration

Two services (`orchestration`, `intelligence-engine`) use custom base images from Harbor (`harbor.0xapogee.local`). For GCP CI:

- Mirror these base images to Artifact Registry
- Or build them in a separate CI workflow and reference from Artifact Registry
- Current sizes: orchestration-base 5.32GB, intelligence-base-cpu 1.85GB (optimized from 12.1GB)

---

## 7. Service Ports and Dependencies Summary

From `docs/INFRA-AGENT.md`:

| Service | Port | DB | Redis | Depends on API_SERVICE_URL |
|---------|------|----|-------|---------------------------|
| api-service | 8000 | YES | YES | — |
| orchestration | 8004 (API), 8003 (Flower) | YES | YES | YES |
| data-service | 8000 | YES | YES | — |
| intelligence-engine | 8000 | YES | YES | — |
| tool-integration | 8005 | — | YES | YES |
| contract-parser | 9000 | — | — | — |
| notification | 3000 | — | YES | — |
| dashboard | 3000 | — | — | Runtime (browser → API) |
| admin-portal | 3000 | — | — | YES |
| findings | 80 (nginx) | — | — | Runtime (browser → API) |
| analysis | 80 (nginx) | — | — | Runtime (browser → API) |
| monitoring | 8000 | — | — | — |
