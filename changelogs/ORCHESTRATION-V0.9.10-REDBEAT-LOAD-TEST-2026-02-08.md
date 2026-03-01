# Orchestration v0.9.10 - RedBeat Fix & Load Test Validation

**Date:** February 8, 2026
**PR:** [#68](https://github.com/AdvancedBlockchainSecurity/blocksecops-orchestration/pull/68)
**Branch:** `fix/solc-echidna-scanner-fixes`
**Previous Version:** 0.9.5

## Summary

Full orchestration service overhaul: solc installation fix, echidna scanner fix, worker concurrency fix, resource tuning, and RedBeat lock recovery. All 15 scanners validated via load test.

## Version History (0.9.5 → 0.9.10)

| Version | Changes |
|---------|---------|
| 0.9.5 | Baseline (pre-fixes) |
| 0.9.6 | Solc installation fix (direct wget + SHA256 verification) |
| 0.9.7 | Echidna .sol suffix stripping, worker concurrency env var fix |
| 0.9.8 | Resource tuning (memory 2Gi/8Gi, CPU 500m/4000m), load test validation |
| 0.9.9 | RedBeat lock timeout fix (incomplete - missing retry interval) |
| 0.9.10 | RedBeat lock retry interval fix (`beat_max_loop_interval=10`) |

## Changes

### Bug Fixes

1. **RedBeat lock stuck after pod rollouts (v0.9.9-0.9.10)**
   - **Root cause:** Default `redbeat_lock_timeout` (1500s/25 min) and `beat_max_loop_interval` (300s/5 min) too long for Kubernetes pod rollouts
   - **Fix:** Set `redbeat_lock_timeout=30` and `beat_max_loop_interval=10` in `celery_app.py`
   - **Result:** Beat recovers within ~45 seconds after pod rollout (verified)
   - **File:** `src/blocksecops_orchestration/core/celery_app.py`

2. **Solc installation failures (v0.9.6)**
   - **Root cause:** `solc-select install` calls GitHub API (rate-limited)
   - **Fix:** Direct `wget` from `binaries.soliditylang.org` with SHA256 verification
   - **Versions installed:** 0.8.0, 0.8.19, 0.8.20, 0.8.25, 0.8.28 (default)
   - **File:** `docker/Dockerfile.orchestration`

3. **Echidna scan failures (v0.9.7)**
   - **Root cause:** Contract name passed with `.sol` suffix to `--contract` flag
   - **Fix:** `.removesuffix(".sol")` before passing to Echidna
   - **File:** `src/blocksecops_orchestration/scanners/solidity_scanners.py`

4. **Worker concurrency ignored ConfigMap (v0.9.7)**
   - **Root cause:** Hardcoded `--concurrency=4` instead of reading `WORKER_CONCURRENCY` env var
   - **Fix:** `os.getenv("WORKER_CONCURRENCY", "4")` for configurable concurrency
   - **File:** `src/blocksecops_orchestration/workers/scan_worker.py`

### Resource Tuning (v0.9.8)

| Container | Resource | Before | After |
|-----------|----------|--------|-------|
| Worker | Memory request | 256Mi | 2Gi |
| Worker | Memory limit | 1Gi | 8Gi |
| Worker | CPU request | 100m | 500m |
| Worker | CPU limit | 500m | 4000m |
| Worker | Concurrency | 1 (ConfigMap, ignored) | 4 (from env var) |

## Load Test Results

All 15 scanners passed:

| Scanner | Language | Status | Findings |
|---------|----------|--------|----------|
| slither | Solidity | PASS | 1 high |
| aderyn | Solidity | PASS | 4 critical, 12 medium |
| semgrep | Solidity | PASS | 1 high |
| solhint | Solidity | PASS | 1 high |
| halmos | Solidity | PASS | 1 high |
| echidna | Solidity | PASS | 1 high |
| wake | Solidity | PASS | 1 high, 1 medium |
| medusa | Solidity | PASS | 0 (fuzzer) |
| soliditydefend | Solidity | PASS | 3 critical, 10 high, 5 medium |
| sol-azy | Solidity | PASS | 1 high |
| vyper | Vyper | PASS | 0 |
| moccasin | Vyper | PASS | 0 |
| sec3-xray | Rust/Solana | PASS | 0 |
| trident | Rust/Solana | PASS | 0 |
| cargo-fuzz-solana | Rust/Solana | PASS | 0 |

## Investigated Issues (Not Bugs)

- **Scanner fan-out:** Each scan has exactly one scanner in `scanners_used[]`. No fan-out occurring.
- **Severity counts showing 0:** False alarm. Database confirmed findings exist for 9 of 15 scanners. Fuzzers and cross-language scanners correctly return 0.

## Files Changed

- `src/blocksecops_orchestration/core/celery_app.py` - RedBeat lock settings
- `src/blocksecops_orchestration/workers/scan_worker.py` - Worker concurrency env var
- `src/blocksecops_orchestration/scanners/solidity_scanners.py` - Echidna .sol suffix fix
- `docker/Dockerfile.orchestration` - Solc direct download with SHA256
- `pyproject.toml` - Version 0.9.5 → 0.9.10
- `k8s/overlays/local/orchestration/kustomization.yaml` - Image tag + labels
- `k8s/overlays/local/orchestration/deployment-patch.yaml` - Worker resources
- `k8s/overlays/local/orchestration/configmap-patch.yaml` - Worker concurrency "4"

## Deployment

```bash
# Build and push
docker build -t harbor.blocksecops.local/blocksecops/orchestration:0.9.10 .
docker push harbor.blocksecops.local/blocksecops/orchestration:0.9.10

# Deploy
kubectl apply -k k8s/overlays/local/orchestration/
kubectl rollout restart deployment/orchestration -n orchestration-local
kubectl rollout status deployment/orchestration -n orchestration-local
```
