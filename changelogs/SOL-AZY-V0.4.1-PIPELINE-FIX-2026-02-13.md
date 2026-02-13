# Sol-azy Scanner v0.4.1 - Pipeline Fix

**Date:** February 13, 2026
**Component:** blocksecops-tool-integration (scanner-sol-azy)
**Version:** 0.4.0 → 0.4.1

---

## Summary

Fixed the sol-azy Solana static analyzer scanner pipeline. The scanner container was crashing on all 4 retry attempts (BackoffLimitExceeded) due to UID mismatch, outdated Rust toolchain, and silent build failures.

---

## Root Causes

### 1. UID Mismatch (Primary)
The Dockerfile created a `scanner` user with UID 1001 (`useradd -m -u 1001`), but the K8s security context enforces `runAsUser: 1000`. The container started as UID 1000 but had no matching user or home directory, causing permission errors.

### 2. Outdated Rust Version
The `home@0.5.12` crate (a transitive dependency) requires Rust 1.88+. The Dockerfile pinned `RUST_VERSION=1.85-bookworm`, causing `cargo install` to fail during the build. However, due to the silent build failure (see #3), the image was built without the sol-azy binary.

### 3. Silent Build Failure
When `sol-azy` binary wasn't found after cargo install, the Dockerfile's entrypoint script printed `echo "sol-azy binary not found"` but did not `exit 1`. The build succeeded with a broken image.

### 4. Runtime Git Clone Fallback
The entrypoint attempted to `git clone` the sol-azy repository at runtime as a fallback, which fails in air-gapped K8s clusters with no internet access.

### 5. No Curl Retry on Callback
The callback POST to tool-integration had no retry logic, so transient DNS issues (common with Alpine musl) caused silent callback failures.

### 6. /tmp Ownership
The scanner writes to `/tmp/solana-analysis` at runtime, but the directory didn't exist and UID 1000 couldn't create it due to permission constraints.

---

## Fixes Applied

| Fix | Detail |
|-----|--------|
| UID 1001→1000 | `useradd -m -u 1000 scanner` |
| Rust 1.85→1.88 | `ARG RUST_VERSION=1.88-bookworm` |
| Build verification | Added `RUN sol-azy --help` post-build check + `exit 1` on failure |
| Removed git clone fallback | Fail fast with error callback POST to tool-integration |
| Curl retry | `--retry 3 --retry-delay 2 --retry-all-errors --connect-timeout 10` |
| /tmp pre-creation | `mkdir -p /tmp/solana-analysis && chown scanner:scanner /tmp/solana-analysis` |
| Shell strictness | `set -euo pipefail` instead of `set -e` |

---

## Files Modified

| File | Change |
|------|--------|
| `scanner-images/sol-azy/Dockerfile` | All fixes above |
| `src/scanners/kubernetes_job_manager.py` | Default image 0.4.0 → 0.4.1 |
| `k8s/base/scanner-versions-configmap.yaml` | Sol-azy version and image tag → 0.4.1 |
| `k8s/overlays/local/scanner-versions-patch.yaml` | Harbor image tag → 0.4.1 |
| `k8s/overlays/production/scanner-versions-patch.yaml` | Artifact Registry image tag → 0.4.1 |

---

## Verification

After deploying, trigger a scan with sol-azy on a Solana/Rust contract:

```bash
# Check scanner image version in ConfigMap
kubectl get configmap scanner-versions -n tool-integration-local -o jsonpath='{.data.SCANNER_IMAGE_SOL_AZY}'

# Trigger a scan via the platform UI or API
# Monitor the K8s Job
kubectl get jobs -n tool-integration-local -l scanner=sol-azy --watch

# Check Job logs
kubectl logs -n tool-integration-local -l scanner=sol-azy --tail=50
```

The scan should complete without BackoffLimitExceeded. The scanner may return 0 findings depending on the contract patterns (sol-azy has limited detection rules for raw `invoke()` patterns).
