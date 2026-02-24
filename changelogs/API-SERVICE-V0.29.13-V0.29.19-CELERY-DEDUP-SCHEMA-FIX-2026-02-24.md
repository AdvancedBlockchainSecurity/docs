# API Service v0.29.13 - v0.29.19: Celery Dedup Workers, Overload Protection, Schema Fix

**Component:** blocksecops-api-service
**Scope:** Move dedup to Celery workers, add overload protection, fix is_canonical schema, init-time callable defaults
**Date:** February 24, 2026
**Status:** Deployed

---

## Summary

A series of releases addressing the API pod crash caused by inline dedup processing blocking the event loop. Moves dedup to isolated Celery workers, adds overload protection as defense-in-depth, fixes a systemic UUID initialization bug, and corrects the `is_canonical` schema mismatch in API responses.

---

## Release History

| Version | Date | Change |
|---------|------|--------|
| 0.29.13 | Feb 23 | Celery migration: move all dedup processing to worker pod |
| 0.29.14 | Feb 23 | Overload protection: rate limits, semaphores, vuln caps |
| 0.29.15 | Feb 23 | Batch size caps, vulnerability limit per scan |
| 0.29.16 | Feb 23 | Fix Celery task registration and worker startup |
| 0.29.17 | Feb 23 | Fix UUID None bug (vulnerability.id before flush) |
| 0.29.18 | Feb 24 | Systemic fix: init-time callable defaults on Base class |
| 0.29.19 | Feb 24 | Fix is_canonical schema alias (validation_alias for is_primary) |

---

## Problem

### Pod Crash (v0.29.12 and earlier)

A contract with 386 findings (VulnerableAMM) triggered dedup processing inline in the event loop. The heavy processing (embedding generation, cross-scan queries, DB writes) starved the event loop. Liveness probes couldn't respond, and Kubernetes killed the pod.

v0.29.11 used `asyncio.create_task()` for dedup, but background tasks still shared the same event loop and DB connection pool as health checks and API requests.

### UUID None Bug (discovered during Celery migration)

`VulnerabilityModel(default=uuid4)` does not fire during `__init__` — SQLAlchemy only runs callable defaults at flush time. When the code passed `vulnerability.id` to Celery before flush, it was `None`, causing `str(None) = "None"` as a task argument.

### is_canonical Schema Mismatch (v0.29.18 and earlier)

The API response schema used `is_canonical` but the DB column is `is_primary`. The `@property is_canonical` alias on the model was not reliably read through the `to_pydantic()` serialization path, so the field was always `None` in API responses.

---

## Solution

### Celery Workers (v0.29.13)

Moved all dedup processing to a Celery worker running in a separate pod:

```
API Pod                          Celery Worker Pod
────────                         ─────────────────
store_scan_results()             run_dedup_task()
  └─ run_dedup_task.delay()  →     Phase 1: Intra-scan dedup
     (enqueue to Redis)            Phase 2: Cross-scan dedup
     Return immediately            Phase 3: Post-scan maintenance
```

**Key design decisions:**
- Same Docker image as API (like CronJob), different `command:`
- Redis db 1 as broker, db 2 as result backend (already running)
- `worker_concurrency=3`, `task_acks_late=True` (re-deliver on crash)
- Soft time limit 5 min, hard kill 10 min
- Dedicated `dedup` queue

**New files:**
- `src/infrastructure/celery_app.py` — Celery instance with queue config
- `src/infrastructure/tasks/dedup_task.py` — Task wrapping async dedup phases
- `k8s/base/api-service/deployment-celery-worker.yaml` — Worker deployment

### Overload Protection (v0.29.14)

Defense-in-depth even with Celery isolation:
- `_DEDUP_SEMAPHORE` (max 3 concurrent dedup tasks)
- Vulnerability cap per scan (500 max, configurable)
- Batch processing with 50-vuln chunks
- Rate limit on `/scans/{id}/results` endpoint

### Init-Time Callable Defaults (v0.29.18)

Systemic fix on the `Base` SQLAlchemy class using an `init` event listener:

```python
@event.listens_for(Base, "init", propagate=True)
def _apply_callable_defaults(target, args, kwargs):
    """Fire callable column defaults at __init__ time."""
    mapper = sa_inspect(type(target))
    for col_attr in mapper.column_attrs:
        col = col_attr.columns[0]
        if col.default is not None and col.default.is_callable \
           and col_attr.key not in kwargs \
           and getattr(target, col_attr.key, None) is None:
            setattr(target, col_attr.key, col.default.arg(None))
```

This ensures all 78 models with `default=uuid4` get real UUIDs at construction time.

### is_canonical Schema Fix (v0.29.19)

Used Pydantic's `AliasChoices` to map the DB column name directly:

```python
from pydantic import AliasChoices

is_canonical: Optional[bool] = Field(
    None,
    validation_alias=AliasChoices("is_canonical", "is_primary"),
    description="True if this is the canonical (primary) finding"
)
```

- Pydantic tries `is_canonical` first (manual construction), then `is_primary` (from DB model)
- JSON output always uses `is_canonical` (the field name)
- Added `populate_by_name = True` to Config

---

## Files Created

| File | Description |
|------|-------------|
| `src/infrastructure/celery_app.py` | Celery app instance with queue/concurrency config |
| `src/infrastructure/tasks/dedup_task.py` | Celery task wrapping async dedup phases |
| `k8s/base/api-service/deployment-celery-worker.yaml` | Worker k8s deployment |
| `tests/unit/infrastructure/test_callable_defaults.py` | 6 tests for init-time defaults |

## Files Modified

| File | Change |
|------|--------|
| `src/infrastructure/config.py` | Added `celery_broker_url`, `celery_result_backend` settings |
| `src/infrastructure/database/connection.py` | Added `_apply_callable_defaults` init event listener |
| `src/presentation/api/v1/endpoints/scans.py` | Replaced `asyncio.create_task()` with `run_dedup_task.delay()` |
| `src/presentation/schemas/vulnerabilities.py` | Added `AliasChoices("is_canonical", "is_primary")`, `populate_by_name` |
| `k8s/base/api-service/kustomization.yaml` | Added `deployment-celery-worker.yaml` to resources |
| `k8s/overlays/local/api-service/kustomization.yaml` | Added celery-worker image entry, version bumps |
| `k8s/overlays/local/api-service/deployment-patch.yaml` | Added `CELERY_BROKER_URL` env var |
| `tests/unit/presentation/test_scans_phase3.py` | Rewritten for Celery architecture |

---

## Architecture Change

### Before (v0.29.12)

```
┌──────────────────────────────────────────┐
│              API Pod (single)             │
│                                          │
│  uvicorn event loop                      │
│    ├── HTTP request handling             │
│    ├── Health check probes               │
│    └── asyncio.create_task(dedup)  ←─── BLOCKS EVENT LOOP
│         ├── Intra-scan dedup             │
│         ├── Cross-scan dedup             │
│         └── Post-scan maintenance        │
│              └── _get_embeddings_sync()   │ ←── BLOCKING CALL
└──────────────────────────────────────────┘
```

### After (v0.29.13+)

```
┌─────────────────────────┐     ┌─────────────────────────────┐
│       API Pod            │     │     Celery Worker Pod        │
│                          │     │                             │
│  uvicorn event loop      │     │  celery worker process      │
│    ├── HTTP requests     │     │    ├── Intra-scan dedup     │
│    ├── Health checks     │     │    ├── Cross-scan dedup     │
│    └── task.delay()  ────┼─────┼──► └── Post-scan maint     │
│         (non-blocking)   │     │                             │
└─────────────────────────┘     └─────────────────────────────┘
         │                               │
         └──────── Redis (broker) ───────┘
```

---

## Kubernetes Resources

### Celery Worker Deployment

```yaml
# k8s/base/api-service/deployment-celery-worker.yaml
command: ["celery", "-A", "src.infrastructure.celery_app", "worker",
          "--loglevel=info", "--queues=dedup", "--concurrency=3"]
resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits: { cpu: 500m, memory: 512Mi }
```

### Verify Worker Running

```bash
kubectl get pods -n api-service-local -l app.kubernetes.io/name=celery-worker
kubectl logs -n api-service-local -l app.kubernetes.io/name=celery-worker --tail=20
```

---

## Verification

### Smoke Test (February 24, 2026)

All checks passed:
- API healthy at v0.29.19, Celery worker at v0.29.19
- All 6 internal services healthy
- 89 DB tables, 7,313 vulnerabilities, 0 info-severity patterns
- CronJob version matches deployment

### E2E Test (February 24, 2026)

Uploaded `CeleryDedupTest` contract (reentrancy, tx.origin, unchecked returns):
- Slither + Semgrep: 16 vulnerabilities found
- Celery worker processed 11 vulns in 9.8s
- Intra-scan dedup: 1 group created, 2 vulns updated, 1 duplicate identified
- Cross-scan: 0 (first scan for contract)
- Maintenance: 4 embeddings generated, 4.0s

### is_canonical Verification (February 24, 2026)

```python
# From deployed v0.29.19 pod
resp = VulnerabilityResponse.model_validate(FakeModel(is_primary=True), from_attributes=True)
assert resp.is_canonical == True   # Reads is_primary from DB
assert "is_canonical" in resp.model_dump_json()  # JSON uses is_canonical
```

### Unit Tests

1,032 passed, 2 pre-existing failures (unrelated):
- `test_cronjob_schedule_every_6_hours` — schedule changed to weekly in v0.29.11
- `test_production_has_all_base_scanners` — GCP overlay incomplete (pre-existing)

---

## What This Solves

| Problem | Before | After |
|---------|--------|-------|
| Event loop starvation | Dedup blocks health checks | Dedup in separate process |
| Pod restarts under load | Liveness timeout → SIGKILL | API stays responsive |
| UUID None in Celery args | `str(None)` = "None" | Real UUID at init time |
| is_canonical always None | Schema/model name mismatch | AliasChoices maps is_primary |
| No retry on dedup failure | Silent data loss | Celery retries 2x, 30s backoff |

---

## See Also

- [Deduplication Workflow](../workflows/deduplication-workflow.md)
- [Deduplication Pipeline](../pipelines/deduplication-pipeline.md)
- [Deduplication Playbook](../playbooks/deduplication-maintenance.md)
- [v0.29.11 Hybrid Deduplication](./API-SERVICE-V0.29.11-HYBRID-DEDUPLICATION-2026-02-23.md)
