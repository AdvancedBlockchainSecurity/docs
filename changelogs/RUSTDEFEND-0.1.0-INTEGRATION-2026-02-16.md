# RustDefend Scanner Integration Changelog

**Date:** 2026-02-16 (initial), 2026-02-17 (v0.3.1 hotfix, v0.3.3 reliability fix)
**Scanner Image Version:** 0.3.3
**Tool Version:** 0.3.1 (50 detectors)
**Platform:** BlockSecOps

---

## Summary

RustDefend is a proprietary Rust smart contract static analysis scanner integrated into the BlockSecOps platform. It provides AST-based static analysis powered by the `syn` crate, covering 50 detectors across 4 blockchain ecosystems: Solana, CosmWasm, NEAR, and Ink!.

---

## Scanner Capabilities

- **Language:** Rust
- **Analysis Method:** AST-based static analysis via the `syn` crate
- **Total Detectors:** 50
  - Solana: 14 detectors (SOL-001 through SOL-014)
  - CosmWasm: 11 detectors (CW-001 through CW-011)
  - NEAR: 12 detectors (NEAR-001 through NEAR-012)
  - Ink!: 11 detectors (INK-001 through INK-011)
  - Cross-chain / Dependency: 2 detectors (DEP-001, DEP-002)
- **Output Format:** JSON array of findings
- **Exit Codes:** 0 (clean), 1 (findings detected), 2 (invalid input)

---

## Version History

### v0.3.3 (2026-02-17) -- Scanner Reliability Fix

**Root Cause:** ConfigMap race condition destroyed mounts for concurrent scanners. Job timeout (120s) too low — Kubernetes killed pods before results could be posted.

**Fixes:**
| Fix | File | Details |
|-----|------|---------|
| ConfigMap race condition | `src/scanners/kubernetes_job_manager.py` | Replace delete-recreate on 409 with create-or-reuse pattern |
| Job timeout increase | `src/scanners/kubernetes_job_manager.py` | 120s → 300s (also solhint 60→180, soliditydefend 60→180, aderyn 120→300) |
| Cleanup trap | `scanner-images/rustdefend/rustdefend-scan` | `trap cleanup EXIT` replaces individual `rm -f` calls |
| Curl error handling | `scanner-images/rustdefend/rustdefend-scan` | All 4 curl paths use HTTP code capture instead of `|| true` |
| Sed error masking | `scanner-images/rustdefend/rustdefend-scan` | Removed `|| true` from JSON extraction sed commands |
| Detector ID normalization | `src/main.py` | `.strip().upper().replace(" ", "-").replace("_", "-")` |
| Hidden dir filter | `src/main.py` | Aligned with shell script symlink exclusion pattern |
| Version propagation | ConfigMaps + KJM fallback | All 4 version locations updated (base, local, prod, KJM) |

**Tests Added:** 35 new tests (5 ConfigMap race, 20 timeout validation, 10 vulnerability filters)

### v0.3.1 (2026-02-17) -- Hotfix

**Root Cause:** Scanner found 0 vulnerabilities when run in Kubernetes because `find` without `-L` flag could not follow ConfigMap volume symlinks.

**Fixes:**
| Fix | File | Details |
|-----|------|---------|
| ConfigMap symlink discovery | `scanner-images/rustdefend/rustdefend-scan` | Changed `find .` to `find -L .` to follow Kubernetes ConfigMap symlinks |
| Callback code_snippet field | `src/main.py` | Changed `finding.get("snippet")` to `finding.get("code_snippet") or finding.get("snippet")` |
| Callback confidence hardcoded | `src/main.py` | Changed `confidence: 0.7` to `finding.get("confidence", 0.7)` |
| KJM fallback tag drift | `src/scanners/kubernetes_job_manager.py` | Updated fallback from `0.1.0` to `0.3.1` |
| Production overlay tag | `k8s/overlays/production/scanner-versions-patch.yaml` | Updated from `0.1.0` to `0.3.1` |
| Cross-repo version alignment | `blocksecops-api-service/.../scanner-versions-configmap.yaml` | Updated from `0.3.0` to `0.3.1` |

### v0.3.0 (2026-02-17) -- Security Hardening

- Pinned base images via ARG for reproducible builds
- Added non-root USER scanner (UID 1000)
- Hidden directory filter for ConfigMap duplicate deduplication

### v0.1.0 (2026-02-16) -- Initial Integration

- Initial Docker image with multi-stage build
- 22 files across 7 repositories
- 36 BVD vulnerability patterns created

---

## New Vulnerability Patterns

36 BVD (BlockSecOps Vulnerability Definition) patterns were created as part of this integration:

| Ecosystem | Pattern Count | Severity Breakdown |
|-----------|--------------|-------------------|
| Solana | 12 | 4 critical, 5 high, 3 medium |
| CosmWasm | 8 | 2 critical, 3 high, 3 medium |
| NEAR | 8 | 3 critical, 3 high, 2 medium |
| Ink! | 6 | 2 critical, 2 high, 2 medium |
| Cross-chain | 2 | 1 critical, 1 high |
| **Total** | **36** | **12 critical, 14 high, 10 medium** |

---

## Files Modified

### blocksecops-tool-integration

| File | Action | Description |
|------|--------|-------------|
| `scanner-images/rustdefend/Dockerfile` | Created | Multi-stage Docker build, non-root scanner user (UID 1000) |
| `scanner-images/rustdefend/rustdefend-scan` | Created | Wrapper script with `find -L` for ConfigMap symlinks, curl retry |
| `k8s/base/scanner-versions-configmap.yaml` | Modified | Added `SCANNER_IMAGE_RUSTDEFEND` and `SCANNER_METADATA` entry |
| `k8s/overlays/local/scanner-versions-patch.yaml` | Modified | Harbor registry entry |
| `k8s/overlays/production/scanner-versions-patch.yaml` | Modified | GCP Artifact Registry entry |
| `src/main.py` | Modified | Added rustdefend to `valid_scanners`, `scanner_configs`, and dedicated callback handler |
| `src/scanners/kubernetes_job_manager.py` | Modified | Added 5 KJM entries (image, command, memory, timeout) |
| `src/scanners/parser.py` | Modified | Added rustdefend output format support |
| `tests/unit/scanners/test_rustdefend_parser.py` | Created | 18 parser unit tests |
| `tests/fixtures/scanner_outputs/rustdefend_output.json` | Created | Test fixture with 4 findings |
| `tests/conftest.py` | Modified | Added rustdefend fixtures |
| `tests/integration/test_callback_endpoint.py` | Modified | Added TestRustDefendCallback class |
| `tests/integration/test_trigger_endpoint.py` | Modified | Added rustdefend to parametrize list |
| `tests/regression/test_scanner_availability.py` | Modified | Added rustdefend to ALL_SCANNERS |

### blocksecops-orchestration

| File | Action | Description |
|------|--------|-------------|
| `src/blocksecops_orchestration/parsers/solana_parsers.py` | Modified | Added RustDefendParser class |
| `src/blocksecops_orchestration/parsers/registry.py` | Modified | Imported and registered RustDefendParser |
| `src/blocksecops_orchestration/scanners/registry.py` | Modified | Registered RustDefend scanner executor |
| `src/blocksecops_orchestration/scanners/solana_scanners.py` | Modified | Added RustDefend scanner executor |
| `tests/integration/test_all_scanners.py` | Modified | Updated expected scanner count (18->19) and set |
| `tests/unit/scanners/test_registry_completeness.py` | Modified | Added rustdefend to expected Solana set |

### blocksecops-api-service

| File | Action | Description |
|------|--------|-------------|
| `src/infrastructure/scanner_config/scanners.py` | Modified | Added RustDefend to SCANNERS dict and scan presets |
| `k8s/overlays/local/api-service/scanner-versions-configmap.yaml` | Modified | Added SCANNER_IMAGE_RUSTDEFEND entry |
| `scripts/intelligence/rustdefend-patterns.json` | Created | 36 vulnerability pattern definitions |
| `scripts/intelligence/rustdefend-detector-pattern-mappings.json` | Created | 50 detector-to-pattern mappings |
| `scripts/seed_scanner_patterns.py` | Modified | Added rustdefend to supported scanners |
| `tests/unit/test_scanner_config.py` | Created | Scanner config and preset validation tests |
| `tests/integration/test_scanner_api_language_support.py` | Modified | Added rustdefend to rust_scanners list |
| `tests/integration/solana/test_solana_integration.py` | Modified | Added rustdefend to dedup and detector tests |

### docs

| File | Action | Description |
|------|--------|-------------|
| `pipelines/scanner-addition-pipeline.md` | Created | Full 14-step integration pipeline with actual file paths |
| `pipelines/scanner-readiness-checklist.md` | Modified | Updated with all 17 scanners including RustDefend |
| `standards/docker-image-versioning.md` | Modified | Updated scanner-rustdefend version to 0.3.1 |
| `changelogs/RUSTDEFEND-0.1.0-INTEGRATION-2026-02-16.md` | Created | This file |
| `scanners/RustDefend/README.md` | Created | Scanner documentation with detector table |
| `feature-tests/22-scanner-validation.md` | Modified | Updated RustDefend section with v0.3.1 tests |

---

## Integration Points

### Docker
- Image: `scanner-rustdefend:0.3.3`
- Base: `rust:1.85-slim-bookworm` (builder), `debian:bookworm-slim` (runtime)
- Entrypoint: `rustdefend-scan` wrapper script
- Non-root user: `scanner` (UID 1000)
- Directories: `/contracts` (input), `/output` (results)

### Kubernetes
- ConfigMap registration across base, local (Harbor), and production (GCP AR) overlays
- KJM configuration:
  - `image`: `scanner-rustdefend:0.3.3` (env var `SCANNER_IMAGE_RUSTDEFEND`)
  - `command`: `None` (wrapper is entrypoint)
  - `memory_limit`: `1Gi`
  - `memory_request`: `512Mi`
  - `timeout`: `300s`

### Callback Handler
- Dedicated `elif scanner_type == "rustdefend":` branch in `src/main.py`
- Handles both native format (`detector_id` key) and wrapper format (`locations` key)
- Confidence mapping: high=0.9, medium=0.7, low=0.5
- 50 detector ID to human-readable name mappings
- ConfigMap hidden directory path filtering

### Orchestration Parser
- `RustDefendParser` class in `parsers/solana_parsers.py`
- Registered in `parsers/registry.py`
- Handles `chain` field for multi-ecosystem support

### API Service
- Scanner metadata in SCANNERS dict: `is_blocksecops_scanner=True`, `requires_compilation=False`
- Included in rust quick/standard/deep scan presets
- 50 detector-to-pattern mappings seeded to database

---

## Lessons Learned

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| Scanner finds 0 files in K8s | `find` without `-L` can't follow ConfigMap symlinks | Use `find -L .` |
| `code_snippet` always null | Handler reads `"snippet"`, wrapper sends `"code_snippet"` | Use `get("code_snippet") or get("snippet")` |
| Confidence always 0.7 | Handler hardcoded default instead of reading scanner value | Read from scanner: `get("confidence", 0.7)` |
| KJM uses wrong image | Fallback tag `0.1.0` not updated with ConfigMap | Keep KJM fallback in sync with base ConfigMap |
| Cross-repo test failure | API service ConfigMap had `0.3.0`, tool-integration had `0.3.1` | Update all ConfigMaps in lockstep |

---

## Related Documentation

| Document | Path |
|----------|------|
| Scanner README | `docs/scanners/RustDefend/README.md` |
| Scanner Addition Pipeline | `docs/pipelines/scanner-addition-pipeline.md` |
| Scanner Readiness Checklist | `docs/pipelines/scanner-readiness-checklist.md` |
| Task Documentation | `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-02-16-RUSTDEFEND-INTEGRATION.md` |
