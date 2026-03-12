# Scanner-Slither v0.3.8 — Pre-install 18 solc Versions

**Component:** blocksecops-tool-integration (scanner-images/slither)
**Scope:** Scanner image performance, solc compiler availability
**Date:** March 11, 2026
**Status:** Deployed to GCP production
**Image:** `scanner-slither:0.3.8`

---

## Summary

Pre-installed 18 solc compiler versions (0.5.16 through 0.8.28) into the scanner-slither Docker image, eliminating runtime downloads from soliditylang.org. Solc binaries are stored at `/opt/solc-select/artifacts` to survive the emptyDir mount that K8s places at `/home/scanner` for `readOnlyRootFilesystem` compliance.

---

## Problem

Scanner pods were stuck downloading solc compilers from soliditylang.org at runtime, causing scans to hang or timeout. The original image only included solc 0.8.20. Any contract requiring a different compiler version triggered a download that could take 30+ seconds or fail entirely due to network latency.

Additionally, the KJM mounts an `emptyDir` at `/home/scanner` for `readOnlyRootFilesystem` compliance, which shadows any files baked into the Docker image under that path — including previously attempted solc installations at `~/.solc-select/`.

---

## Changes

### 1. Dockerfile — Pre-install 18 solc Versions

**File:** `scanner-images/slither/Dockerfile`

Replaced single-version solc install with loop-based install of 18 versions covering contracts from 2022–2026:

- 0.5.16, 0.5.17
- 0.6.6, 0.6.12
- 0.7.0, 0.7.6
- 0.8.0, 0.8.4, 0.8.7, 0.8.9, 0.8.13, 0.8.17, 0.8.19, 0.8.20, 0.8.21, 0.8.24, 0.8.26, 0.8.28

Binaries installed to `/opt/solc-select/artifacts` (not `/home/scanner/.solc-select`) to survive the emptyDir mount.

### 2. Entrypoint Script — Runtime Seed

**File:** `scanner-images/slither/run-slither.sh`

Added seed step after environment validation:
- Checks if `/opt/solc-select/artifacts` exists and `$HOME/.solc-select` hasn't been populated yet
- Copies pre-installed binaries from `/opt` into `$HOME/.solc-select/`
- Logs count of seeded versions

### 3. ConfigMap Version Update

**File:** `k8s/base/scanner-versions-configmap.yaml`

- `SCANNER_IMAGE_SLITHER`: `scanner-slither:0.3.6` → `scanner-slither:0.3.8`
- `SCANNER_METADATA.slither._note`: Updated to reflect 0.3.8 with 18 pre-installed solc versions

### 4. KJM Fallback Default

**File:** `src/scanners/kubernetes_job_manager.py`

Updated `default_images["slither"]` fallback from `scanner-slither:0.3.6` to `scanner-slither:0.3.8`.

---

## Why 0.3.8 (not 0.3.7)?

The initial fix was tagged 0.3.7 but installed solc to `/home/scanner/.solc-select/` — which gets shadowed by the emptyDir mount. After discovering this, the install path was changed to `/opt/solc-select/` with a runtime copy step. Because Artifact Registry enforces immutable tags, the already-pushed 0.3.7 could not be overwritten, requiring a bump to 0.3.8.

---

## Verification

| Check | Result |
|-------|--------|
| Scanner pod logs: "Seeded 18 solc versions" | Confirmed |
| Scan completes in ~15s (vs hanging) | Confirmed |
| `solc-select versions` in pod shows 18 versions | Confirmed |
| ConfigMap SCANNER_IMAGE_SLITHER = 0.3.8 | Confirmed |
| KJM default_images matches ConfigMap | Confirmed |

---

## Related

- GCP audit finding: scanner pods stuck downloading solc at runtime
- Immutable tag policy: `docs/standards/docker-image-versioning.md`
- Scanner version bump workflow: `docs/workflows/scanner-image-version-bump.md`
