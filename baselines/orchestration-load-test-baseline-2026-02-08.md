# Orchestration Service - Load Test Baseline

**Date:** February 8, 2026
**Version Change:** 0.9.5 --> 0.9.10
**PR:** [#68](https://github.com/BlockSecOps/blocksecops-orchestration/pull/68)
**Branch:** `fix/solc-echidna-scanner-fixes`

---

## Resource Settings Comparison

### Worker Container (orchestration-worker)

| Setting | Before (0.9.5) | After (0.9.10) | Notes |
|---------|----------------|---------------|-------|
| Memory request | 256Mi | 2Gi | 8x increase |
| Memory limit | 1Gi | 8Gi | 8x increase |
| CPU request | 100m | 500m | 5x increase |
| CPU limit | 500m | 4000m | 8x increase |
| Worker concurrency (ConfigMap) | 1 | 4 | Was ignored by code in 0.9.5 |
| Worker concurrency (actual) | 4 (hardcoded) | 4 (from env var) | Bug fix: now reads `WORKER_CONCURRENCY` env |

### Beat Container (orchestration-beat)

| Setting | Before (0.9.5) | After (0.9.10) | Notes |
|---------|----------------|---------------|-------|
| Memory request | 128Mi | 128Mi | Unchanged |
| Memory limit | 512Mi | 512Mi | Unchanged |
| CPU request | 50m | 50m | Unchanged |
| CPU limit | 250m | 250m | Unchanged |

### Monitor Container (orchestration-monitor / Flower)

| Setting | Before (0.9.5) | After (0.9.10) | Notes |
|---------|----------------|---------------|-------|
| Memory request | 64Mi | 64Mi | Unchanged |
| Memory limit | 256Mi | 256Mi | Unchanged |
| CPU request | 25m | 25m | Unchanged |
| CPU limit | 100m | 100m | Unchanged |

### API Container (orchestration-api)

| Setting | Before (0.9.5) | After (0.9.10) | Notes |
|---------|----------------|---------------|-------|
| Memory request | 128Mi | 128Mi | Unchanged |
| Memory limit | 512Mi | 512Mi | Unchanged |
| CPU request | 50m | 50m | Unchanged |
| CPU limit | 250m | 250m | Unchanged |

### Init Container (init-solc-cache)

| Setting | Before (0.9.5) | After (0.9.10) | Notes |
|---------|----------------|---------------|-------|
| Image tag | 0.9.5 | 0.9.10 | Tracks app version |
| Script | Guarded with `if [ -d ... ]` | Direct `cp -r` with debug output | Simplified |

---

## ConfigMap Settings Comparison

| Key | Before (0.9.5) | After (0.9.10) | Notes |
|-----|----------------|---------------|-------|
| `environment` | "local" | "local" | Unchanged |
| `log_level` | "debug" | "debug" | Unchanged |
| `worker_concurrency` | "1" | "4" | Was previously ignored by code |
| `beat_schedule` | 2 tasks (cleanup + health-check) | 2 tasks (cleanup + health-check) | Unchanged |
| `task_time_limit` | 7200 (2hr) | 7200 (2hr) | Unchanged |
| `task_soft_time_limit` | 6600 (1hr50m) | 6600 (1hr50m) | Unchanged |
| `worker_prefetch_multiplier` | 1 | 1 | Unchanged |
| `worker_max_tasks_per_child` | 100 | 100 | Unchanged |

---

## Code Changes

### scan_worker.py - Concurrency Fix

**Before (0.9.5):** Hardcoded `--concurrency=4`, ignoring the ConfigMap's `WORKER_CONCURRENCY` env var. Fixed in 0.9.8.

```python
celery_app.worker_main([
    "worker",
    "--loglevel=INFO",
    "--pool=prefork",
    "--concurrency=4",  # Hardcoded
    ...
])
```

**After (0.9.8+):** Reads from environment variable, defaults to 4.

```python
import os
concurrency = os.getenv("WORKER_CONCURRENCY", "4")

celery_app.worker_main([
    "worker",
    "--loglevel=INFO",
    "--pool=prefork",
    f"--concurrency={concurrency}",  # Configurable
    ...
])
```

### solidity_scanners.py - Echidna Fix

**Before:** Passed contract name with `.sol` suffix (e.g., `VulnerableVault.sol`), causing Echidna to fail.

**After:** Strips `.sol` suffix via `.removesuffix(".sol")` before passing to `--contract` flag.

### Dockerfile.orchestration (Base Image) - Solc Fix

**Before:** Used `solc-select install` which calls GitHub API (rate-limited, unreliable).

**After:** Direct `wget` downloads from `binaries.soliditylang.org` with SHA256 verification for solc versions: 0.8.0, 0.8.19, 0.8.20, 0.8.25, 0.8.28. Default set to 0.8.28.

### celery_app.py - RedBeat Lock Recovery (v0.9.10)

**Before (0.9.5-0.9.8):** Default RedBeat lock timeout of 1500s (25 min) and lock retry interval of 300s (5 min). After pod rollouts, beat would remain stuck on "Acquiring lock..." for up to 25 minutes.

**After (0.9.10):** Added two settings to `celery_app.conf.update()`:

```python
# Lock TTL: 30s instead of 1500s (25 min default)
redbeat_lock_timeout=30,
# Lock retry interval: 10s instead of 300s (5 min default)
beat_max_loop_interval=10,
```

Beat now recovers within ~45 seconds after pod rollouts. Verified with `kubectl rollout restart` test.

---

## Load Test Results (February 8, 2026)

### Test Configuration

| Parameter | Value |
|-----------|-------|
| Server RAM | 125Gi total, ~96Gi free |
| Worker concurrency | Tested at 8, settled on 4 for production |
| Memory limit during test | 16Gi (load test), 8Gi (production) |
| Scans submitted | 15 (all scanners, all languages) |

### All 15 Scanners - Pass/Fail

| # | Scanner | Language | Status | Notes |
|---|---------|----------|--------|-------|
| 1 | slither | Solidity | PASS | |
| 2 | aderyn | Solidity | PASS | |
| 3 | semgrep | Solidity | PASS | |
| 4 | solhint | Solidity | PASS | |
| 5 | halmos | Solidity | PASS | |
| 6 | echidna | Solidity | PASS | Fixed .sol suffix stripping |
| 7 | wake | Solidity | PASS | |
| 8 | medusa | Solidity | PASS | |
| 9 | soliditydefend | Solidity | PASS | |
| 10 | sol-azy | Solidity | PASS | |
| 11 | vyper | Vyper | PASS | |
| 12 | moccasin | Vyper | PASS | |
| 13 | sec3-xray | Rust/Solana | PASS | |
| 14 | trident | Rust/Solana | PASS | |
| 15 | cargo-fuzz-solana | Rust/Solana | PASS | |

### Resource Usage During Load Test

| Metric | At Concurrency=8 (load test) | At Concurrency=4 (production) |
|--------|------------------------------|-------------------------------|
| Pod memory | 742Mi peak | 430Mi steady-state |
| Pod CPU | Not recorded | 338m steady-state |
| Pod status | 4/4 Running, 0 restarts | 4/4 Running, 1 restart (beat lock) |

### Previous Failures (Before Fixes)

| Issue | Root Cause | Impact |
|-------|-----------|--------|
| Worker OOMKilled (Exit 137) | Hardcoded concurrency=4 with 1Gi memory limit | All scans failed |
| Echidna scan failures | Contract name passed with `.sol` suffix | Echidna could not find contract |
| Solc installation failures | `solc-select install` used GitHub API (rate-limited) | Base image builds intermittently failed |
| RedBeat lock stuck | Beat lock not released after pod rollouts | Scheduler stopped sending tasks |

---

## Scan IDs (Load Test Reference)

These scan IDs were submitted during the load test on 2026-02-08:

```
d3961552-a017-4afd-9d7e-7aab44f81feb : slither
3abcd94a-221e-4025-a481-15f5714c918e : aderyn
cce49383-148a-488b-b70a-6a83e1b2c58f : semgrep
7f8e8362-5f26-44c8-9af1-f06fa4aa437a : solhint
06ac3b09-e3fd-40f9-85be-50a2984f6d3a : halmos
f97e66eb-edc1-4332-b65e-7b8ca65e9d52 : echidna
f61a40f8-6891-4ae9-a228-52a1a6c16e4e : wake
bba18283-7ffc-48e9-877a-63c06c1b101e : medusa
ca305c68-5b04-4cd1-9005-a86ced842eb9 : soliditydefend
f964d466-b014-4797-a589-e7434d209ce9 : sol-azy
46a0fb74-7843-48ba-85b5-c23472944359 : vyper
32bf3500-b809-447e-89d8-8a1d29663bd5 : moccasin
9b726434-91e2-4fd4-8e76-a49547373cea : sec3-xray
41394676-600f-4a86-bbd1-8e4b5c0777f7 : trident
6da8431d-3b8e-45bc-8e09-94aaf8fa8d64 : cargo-fuzz-solana
```

---

## Known Issues (Post-Load-Test)

| Issue | Severity | Status | Resolution |
|-------|----------|--------|------------|
| RedBeat lock stuck after pod rollouts | Medium | RESOLVED (v0.9.10) | Set `redbeat_lock_timeout=30` + `beat_max_loop_interval=10` in celery_app.py. Beat recovers in ~45s. |
| Scanner orchestrator expands single-scanner requests to all 6 Solidity scanners | Low | BY DESIGN | Each scan record has exactly one scanner. No fan-out occurring. |
| Severity counts show 0 findings across load test scans | Low | RESOLVED | False alarm. DB confirmed: aderyn=16, soliditydefend=18, wake=2, 6 others=1 each. Fuzzers correctly return 0. |

---

## Environment

| Component | Value |
|-----------|-------|
| Server | debian-server (kubeadm) |
| Total RAM | 125Gi |
| Kubernetes | kubeadm with containerd |
| Registry | Harbor (harbor.blocksecops.local) |
| Image | harbor.blocksecops.local/blocksecops/orchestration:0.9.10 |
| Base image tag | 1.0.0-0e97f76b |
| Python | 3.11 |
| Celery pool | prefork |
