# Scanner Readiness Checklist

**Last Updated:** February 16, 2026

Operational checklist for verifying any scanner (new or existing) is production-ready.

## Pre-Integration Checklist

### 1. Docker Image + Wrapper Script

- [ ] Dockerfile exists in `blocksecops-tool-integration/scanner-images/<scanner>/`
- [ ] Multi-stage build with pinned base image versions
- [ ] Non-root user `scanner` (UID 1000 or 1001)
- [ ] Wrapper script named `<scanner>-scan` as entrypoint
- [ ] Wrapper script uses `find -L` for ConfigMap symlink compatibility
- [ ] Wrapper script filters hidden directory paths (`-not -path '*/\.*'`)
- [ ] Wrapper script includes curl retry logic for callback POST
- [ ] OCI-compliant labels (`org.opencontainers.image.*`)
- [ ] Solc pre-installed to `/opt/solc-select/` (for solc-select scanners) and `/opt/svm/` (for Foundry scanners)
- [ ] Foundry-based scanners: forge-std pre-installed to `/opt/forge-std/lib/forge-std`
- [ ] Seed step after `USER scanner`: copies from `/opt/` to `$HOME/.solc-select/` and `$HOME/.svm/`
- [ ] No external downloads at runtime (NetworkPolicy blocks outbound HTTPS)
- [ ] Foundry-based run scripts set `offline = true` in foundry.toml

### 2. ConfigMap Registration (4 files)

- [ ] Base: `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` -- `SCANNER_IMAGE_<KEY>` entry
- [ ] Base: `SCANNER_METADATA` JSON updated with version, developer, and `_note`
- [ ] Local overlay: `blocksecops-tool-integration/k8s/overlays/local/scanner-versions-patch.yaml` -- Harbor registry prefix
- [ ] Production overlay: `blocksecops-tool-integration/k8s/overlays/production/scanner-versions-patch.yaml` -- GCP Artifact Registry prefix
- [ ] API service: `blocksecops-api-service/k8s/overlays/local/api-service/scanner-versions-configmap.yaml` -- matching version tag
- [ ] All version tags identical across all files

### 3. KJM Configuration (5 entries)

- [ ] `_get_scanner_image()` -- fallback image tag matches base ConfigMap
- [ ] `_get_scanner_command()` -- command override (`None` if wrapper is entrypoint)
- [ ] `_get_memory_limit()` -- memory limit configured
- [ ] `_get_memory_request()` -- memory request configured
- [ ] `_get_scanner_timeout()` -- timeout configured

### 4. Tool-Integration Callback (3 integration points)

- [ ] Scanner ID in `valid_scanners` list (`src/main.py` ~line 397)
- [ ] Scanner ID in `scanner_configs` dict (`src/main.py` ~line 557)
- [ ] Dedicated `elif scanner_type == "<key>":` callback handler branch
- [ ] Handler reads `confidence` from scanner output (not hardcoded)
- [ ] Handler supports both `code_snippet` and `snippet` field names
- [ ] Handler filters ConfigMap hidden directory paths

### 5. Orchestration Parser + Registry

- [ ] Parser class in `parsers/<language>_parsers.py` (solidity, vyper, or solana)
- [ ] `scanner_id` property matches the scanner ID exactly
- [ ] `parse()` converts raw output to a list of `ParsedFinding`
- [ ] Parser handles empty output and malformed JSON gracefully
- [ ] Parser imported in `parsers/registry.py`
- [ ] `self.register(<Parser>())` called in `_register_default_parsers()`

### 6. API Service Configuration

- [ ] Scanner in `SCANNERS` dict (`src/infrastructure/scanner_config/scanners.py`)
- [ ] Scanner in relevant scan presets (quick/standard/deep)
- [ ] `is_blocksecops_scanner` set correctly
- [ ] `requires_compilation` set correctly
- [ ] Detector count matches actual detector count

### 7. Admin Portal

- [ ] Scanner in `SCANNERS` array (`admin-portal/src/lib/scanners.ts`)
- [ ] `NAME_TO_KEY` mapping added
- [ ] Scanner displays correctly in admin UI

### 8. Vulnerability Patterns

- [ ] `<key>-patterns.json` in `blocksecops-api-service/scripts/intelligence/`
- [ ] `<key>-detector-pattern-mappings.json` in `blocksecops-api-service/scripts/intelligence/`
- [ ] Patterns seeded to database

### 9. Testing

- [ ] `ALL_SCANNERS` in `test_scanner_availability.py` includes scanner ID
- [ ] `@pytest.mark.parametrize` in `test_trigger_endpoint.py` includes scanner ID
- [ ] `test_callback_endpoint.py` has `Test<Scanner>Callback` class
- [ ] Parser unit tests in `test_<key>_parser.py`
- [ ] Fixture JSON in `tests/fixtures/scanner_outputs/<key>_output.json`
- [ ] `conftest.py` has `<key>_fixture` and `<key>_fixture_dict` session fixtures
- [ ] `expected_scanners` set in orchestration `test_all_scanners.py` includes scanner ID
- [ ] Scanner count assertion in orchestration `test_all_scanners.py` is correct
- [ ] `test_registry_completeness.py` includes scanner in expected set
- [ ] `test_scanner_config.py` has `Test<Scanner>Config` class
- [ ] Language support integration test includes scanner ID

### 10. Deployment

- [ ] Image built and pushed to Harbor
- [ ] Kustomize overlay applied to cluster
- [ ] Tool-integration deployment restarted
- [ ] Env var `SCANNER_IMAGE_<KEY>` visible in running pod
- [ ] End-to-end test scan completes with findings

## Current Scanner Status Matrix

### Solidity Static Analysis

| Scanner | ID | Image | ConfigMap | KJM | Callback | Parser | Registry | API Config | Admin | Patterns | Tests | Status |
|---------|----|-------|-----------|-----|----------|--------|----------|------------|-------|----------|-------|--------|
| Slither | `slither` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Aderyn | `aderyn` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Semgrep | `semgrep` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Solhint | `solhint` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Wake | `wake` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| SolidityDefend | `soliditydefend` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |

### Solidity Fuzzing & Formal Verification

| Scanner | ID | Image | ConfigMap | KJM | Callback | Parser | Registry | API Config | Admin | Patterns | Tests | Status |
|---------|----|-------|-----------|-----|----------|--------|----------|------------|-------|----------|-------|--------|
| Echidna | `echidna` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Medusa | `medusa` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Halmos | `halmos` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |

### Vyper

| Scanner | ID | Image | ConfigMap | KJM | Callback | Parser | Registry | API Config | Admin | Patterns | Tests | Status |
|---------|----|-------|-----------|-----|----------|--------|----------|------------|-------|----------|-------|--------|
| Vyper (Slither) | `vyper` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Moccasin | `moccasin` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |

### Solana/Rust

| Scanner | ID | Image | ConfigMap | KJM | Callback | Parser | Registry | API Config | Admin | Patterns | Tests | Status |
|---------|----|-------|-----------|-----|----------|--------|----------|------------|-------|----------|-------|--------|
| Sol-azy | `sol-azy` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Sec3 X-Ray | `sec3-xray` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Trident | `trident` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| Cargo Fuzz | `cargo-fuzz-solana` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |
| RustDefend | `rustdefend` | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | OK |

### Orchestration-Only (not K8s Job-based)

| Scanner | ID | Executor | Parser | Exec Reg | Parser Reg | Default List | Status |
|---------|----|----------|--------|----------|------------|--------------|--------|
| Mythril | `mythril` | Yes | Yes | Yes | Yes | Yes | OK |
| Foundry Fuzz | `foundry-fuzz` | Yes | Yes | Yes | Yes | Yes | OK |
| 4naly3er | `4naly3er` | Yes | Yes | Yes | Yes | Yes | Deprecated (Dec 2025) |

**Total scanners:** 17 active (16 K8s Job-based + 1 orchestration-only), 2 deprecated/legacy

## Adding a New Scanner

1. Follow the [Scanner Addition Pipeline](./scanner-addition-pipeline.md) (14-step process)
2. Walk through every item in this checklist
3. Run tests across all repos:
   ```bash
   # Tool-integration (~388 tests)
   cd /home/pwner/Git/blocksecops-tool-integration && python3 -m pytest tests/ -v

   # Orchestration (~251 tests)
   cd /home/pwner/Git/blocksecops-orchestration && python3 -m pytest tests/ -v

   # API service scanner config
   cd /home/pwner/Git/blocksecops-api-service && PYTHONPATH=src python3 -m pytest tests/unit/test_scanner_config.py -v --override-ini="addopts="
   ```
4. Update the status matrix above
5. Build, push to Harbor, deploy, and verify end-to-end

## Related Documentation

- [Scanner Addition Pipeline](./scanner-addition-pipeline.md) -- Full 14-step integration guide
- [Scanner Upgrade Pipeline](./scanner-upgrade-pipeline.md) -- Upgrading existing scanner versions
- [Docker Image Versioning Standards](../standards/docker-image-versioning.md) -- Version bump workflow
