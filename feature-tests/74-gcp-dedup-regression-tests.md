# GCP Deduplication Audit & Regression Test Suite

**Priority**: P1 - High
**Last Tested**: 2026-02-23
**Scope**: GCP production readiness audit, regression test suite (267 tests), reliability documentation
**API Version**: 0.29.13

---

## 1. GCP CronJob Overlay

### 1.1 Cloud SQL Proxy Sidecar

- [x] CronJob has `cloud-sql-proxy` container
- [x] `--quitquitquit` flag present (required for Job pod termination)
- [x] `--structured-logs` flag present
- [x] `--auto-iam-authn` flag present (Workload Identity, not passwords)
- [x] `--port=5432` flag present (standard PostgreSQL port)
- [x] Image pinned to semver tag (not `:latest`)
- [x] Security context: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, drop ALL
- [x] Resource requests and limits set
- [x] Main container `DATABASE_HOST=localhost` (connects via sidecar)

### 1.2 Sidecar Consistency with Deployment

- [x] CronJob and Deployment use same Cloud SQL Proxy image version
- [x] CronJob and Deployment connect to same Cloud SQL instance
- [x] CronJob has `--quitquitquit`, Deployment does NOT (long-running process)

### 1.3 GCP Metadata

- [x] Namespace is `api-service-gcp`
- [x] Pod template has `environment=gcp` label
- [x] ServiceAccount is `api-service`
- [x] ServiceAccount has Workload Identity annotation (`iam.gke.io/gcp-service-account`)

### 1.4 GCP Environment Variables

- [x] `INTELLIGENCE_ENGINE_URL` uses GCP namespace (not `-local.`)
- [x] `INTELLIGENCE_ENGINE_URL` uses port 80 (service port, not container port 8000)
- [x] `ML_STORAGE_BACKEND=gcs`
- [x] `ML_GCS_BUCKET` is set
- [x] `DATABASE_URL` from Kubernetes Secret (not hardcoded)

### 1.5 Kustomization

- [x] `cronjob-deduplication.yaml` listed in GCP kustomization resources

---

## 2. Retry Behavior (Semantic Deduplicator)

### 2.1 Async Retry

- [x] Success on first attempt: 1 call, no retry
- [x] Retries on `ConnectError`: 2 calls total
- [x] Retries on `TimeoutException`: 2 calls total
- [x] No retry on `HTTPStatusError` (4xx/5xx): 1 call, raises immediately
- [x] Max retries exhausted: 3 total attempts, raises `EmbeddingServiceError`
- [x] Exponential backoff delays: `[1.0, 2.0]` seconds
- [x] Empty text list returns empty array without HTTP call

### 2.2 Sync Retry

- [x] Success on first attempt: 1 call
- [x] Retries on `ConnectError`
- [x] No retry on `HTTPStatusError`
- [x] Max retries exhausted: 3 attempts
- [x] Exponential backoff delays match async

### 2.3 Retry Constants

- [x] `MAX_RETRIES = 2` (3 total attempts)
- [x] `RETRY_BASE_DELAY = 1.0` seconds
- [x] `HTTP_TIMEOUT = 30.0` seconds

---

## 3. IE URL Resolution

### 3.1 Fallback Chain

- [x] `INTELLIGENCE_ENGINE_URL` env var takes highest priority
- [x] Trailing slash stripped from env var
- [x] Config.py `service_url_intelligence` used when env var not set
- [x] Hardcoded local URL used when config fails

### 3.2 Lazy Caching

- [x] `_get_ie_url()` caches result after first call
- [x] Resetting cache to `None` triggers re-resolution

---

## 4. Base CronJob GCP Readiness

- [x] ServiceAccount matches Deployment (`api-service`)
- [x] Namespace not hardcoded to environment-specific value
- [x] No Cloud SQL Proxy in base (GCP overlay adds it)

---

## 5. Documentation

### 5.1 Pipeline Doc (`docs/pipelines/deduplication-pipeline.md`)

- [x] "Reliability & Regression Prevention" section added
- [x] SLO targets documented (inline <1s, CronJob <2h)
- [x] 4-layer test strategy table
- [x] Pre-deployment checklist with full pytest command

### 5.2 Workflow Doc (`docs/workflows/deduplication-workflow.md`)

- [x] "Testing & Regression Prevention" section added
- [x] Guide for adding new pipeline tasks
- [x] Guide for modifying IE integration
- [x] Guide for modifying CronJob configuration
- [x] Post-deployment validation steps (local + GCP)

### 5.3 Playbook (`docs/playbooks/deduplication-maintenance.md`)

- [x] Pre-deployment checklist added
- [x] Post-deployment smoke test (local + GCP)
- [x] Rollback procedures for 4 failure scenarios

---

## Test Execution

```bash
# All dedup regression tests (267 tests, ~2.4s)
python3 -m pytest \
  tests/unit/infrastructure/test_deduplication_maintenance.py \
  tests/unit/infrastructure/test_cronjob_manifest.py \
  tests/unit/infrastructure/test_cronjob_gcp_overlay.py \
  tests/unit/infrastructure/test_cronjob_production_overlay.py \
  tests/unit/infrastructure/test_dedup_multilevel_matching.py \
  tests/unit/ml/test_semantic_deduplicator.py \
  tests/unit/ml/test_semantic_deduplicator_config.py \
  tests/unit/ml/test_semantic_deduplicator_retry.py \
  tests/unit/ml/test_ie_url_resolution.py \
  tests/unit/presentation/test_scans_phase3.py \
  tests/unit/domain/test_deduplication_matcher.py \
  -v -o "addopts="
```

**Result:** 267 passed in 2.35s

---

## Repos Modified

| Repository | Changes |
|------------|---------|
| blocksecops-api-service | Retry logic, URL resolution, 46 new tests, 2 modified test files |
| blocksecops-gcp-infrastructure | GCP CronJob manifest, kustomization update, image tag 0.29.13 |
| docs | Pipeline, workflow, playbook updates + this feature-test |
| TaskDocs-BlockSecOps | Implementation summary |
