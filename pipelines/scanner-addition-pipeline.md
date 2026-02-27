# Scanner Addition Pipeline

**Last Updated:** February 16, 2026

This document describes the full end-to-end pipeline for adding a new scanner to the BlockSecOps platform. It covers all 13 steps from initial evaluation through GitOps deployment, with actual file paths, code examples, and lessons learned from real integrations.

---

## Pipeline Overview

Adding a new scanner to BlockSecOps requires coordinated changes across multiple repositories and systems. The pipeline ensures consistent integration, proper testing, and complete documentation for every scanner onboarded to the platform.

**Typical scope:** 20-25 files across 7 repositories.

### Repositories Involved

| Repository | Changes Required |
|------------|-----------------|
| `blocksecops-tool-integration` | Docker image, wrapper script, KJM config, callback handler, valid_scanners, scanner_configs, ConfigMap entries, tests |
| `blocksecops-orchestration` | Parser class, parser registry, scanner registry, tests |
| `blocksecops-api-service` | Scanner metadata (SCANNERS dict), presets, ConfigMap overlay, pattern seed scripts, tests |
| `blocksecops-dashboard` | Admin portal scanner config (SCANNERS array, NAME_TO_KEY), tests |
| `blocksecops-gcp-infrastructure` | Production overlay ConfigMap (if separate from tool-integration) |
| `docs` | Pipeline docs, changelogs, scanner README |
| `TaskDocs-BlockSecOps` | Task documentation |

---

## Step 1: Scanner Evaluation

Evaluate the candidate scanner for platform compatibility before beginning integration work.

### Evaluation Criteria

| Criterion | Requirement |
|-----------|-------------|
| **Capabilities** | Must detect security vulnerabilities relevant to supported blockchain ecosystems |
| **Output Format** | Must produce machine-parseable output (JSON preferred, SARIF accepted) |
| **Licensing** | Must be compatible with platform distribution (proprietary or OSS) |
| **CLI Interface** | Must support non-interactive CLI execution |
| **Exit Codes** | Must use distinct exit codes for clean, findings, and error states |
| **Resource Footprint** | Must run within platform resource limits (max 4Gi memory, 600s timeout) |

### Reference Files
- `docs/scanners/` -- existing scanner READMEs for output format reference
- `docs/evaluation/` -- evaluation template (if available)

### Checklist
- [ ] Scanner output format documented
- [ ] Licensing reviewed and approved
- [ ] CLI interface tested with sample projects
- [ ] Exit codes verified
- [ ] Resource usage profiled

---

## Step 2: Docker Image Creation

Package the scanner into a Docker image with a standardized wrapper script.

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `Dockerfile` | `blocksecops-tool-integration/scanner-images/<scanner>/Dockerfile` | Multi-stage build for minimal image size |
| Wrapper script | `blocksecops-tool-integration/scanner-images/<scanner>/<scanner>-scan` | Entrypoint script that normalizes invocation and handles callback |

### Dockerfile Standards
- Use multi-stage builds to minimize final image size.
- Pin base image versions via `ARG` for reproducibility (e.g., `ARG RUST_VERSION=1.85-bookworm`).
- Create non-root user `scanner` (UID 1000 or 1001) -- **never run as root**.
- Create `/contracts` (input) and `/output` (results) directories owned by scanner user.
- Use OCI-compliant labels (`org.opencontainers.image.*`).
- Copy only required binaries and configuration.

### Wrapper Script Standards
- Named `<scanner>-scan` (e.g., `rustdefend-scan`, `slither-scan`).
- Accept contract source via ConfigMap volume mount at `/contracts/`.
- **CRITICAL:** Use `find -L` (follow symlinks) when discovering files in `/contracts/`. Kubernetes ConfigMap volumes use symlinks (`..data` -> `..2026_02_17_...`), and `find` without `-L` will miss all files.
- Filter out hidden directory paths (`-not -path '*/\.*'`) to avoid duplicate findings from ConfigMap internal symlink structure.
- Produce JSON output to `/output/results.json`.
- POST results back to tool-integration callback URL via `curl`.
- Include `curl` retry logic (`--retry 3 --retry-delay 2 --max-time 30`).
- Log scanner version on startup for debugging.
- Handle SIGTERM gracefully for Kubernetes pod termination.

### Wrapper Script Callback Format
```bash
curl -s -X POST "${CALLBACK_URL}" \
  -H "Content-Type: application/json" \
  --retry 3 --retry-delay 2 --max-time 30 \
  -d @/output/results.json
```

### Reference Files
- `blocksecops-tool-integration/scanner-images/slither/` -- Solidity scanner example
- `blocksecops-tool-integration/scanner-images/rustdefend/` -- Rust scanner example
- `blocksecops-tool-integration/scanner-images/sol-azy/` -- Solana scanner example

### Checklist
- [ ] Dockerfile created with multi-stage build
- [ ] Non-root user `scanner` created (UID 1000 or 1001)
- [ ] Wrapper script uses `find -L` for ConfigMap symlink compatibility
- [ ] Wrapper script filters hidden directory duplicates
- [ ] Wrapper script includes curl retry logic for callback
- [ ] Image builds successfully
- [ ] Image runs locally against sample input (test with ConfigMap-style symlink mount)
- [ ] Image size is reasonable (document final size)

### Common Pitfalls
| Issue | Cause | Fix |
|-------|-------|-----|
| Scanner finds 0 files in K8s | `find` without `-L` flag | Use `find -L .` to follow ConfigMap symlinks |
| Duplicate findings | Files accessible via both real path and symlink | Filter `./..` prefixed paths in wrapper or callback |
| Callback fails silently | No retry on transient network errors | Add `--retry 3 --retry-delay 2 --max-time 30` |

---

## Step 3: ConfigMap Registration

Register the scanner image version in Kubernetes ConfigMaps across all deployment overlays.

### Three-Layer ConfigMap Structure

| Layer | File | Registry |
|-------|------|----------|
| Base (defaults) | `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` | No registry prefix (e.g., `scanner-<key>:<version>`) |
| Local overlay | `blocksecops-tool-integration/k8s/overlays/local/scanner-versions-patch.yaml` | Harbor (`harbor.0xapogee.local/blocksecops/scanner-<key>:<version>`) |
| Production overlay | `blocksecops-tool-integration/k8s/overlays/production/scanner-versions-patch.yaml` | GCP Artifact Registry (`us-central1-docker.pkg.dev/solidity-security/blocksecops/scanner-<key>:<version>`) |

### ConfigMap Entry Format
```yaml
# In scanner-versions-configmap.yaml (base)
data:
  SCANNER_IMAGE_<KEY>: "scanner-<key>:<version>"
```

### Scanner Metadata (Base ConfigMap Only)
The base ConfigMap also contains `SCANNER_METADATA` JSON with tool version and developer info:
```yaml
data:
  SCANNER_METADATA: |
    {
      "<key>": {
        "version": "<tool-version>",
        "developer": "<Developer Name>",
        "_note": "Updated <date>, image <image-version> - <change description>"
      }
    }
```

### API Service ConfigMap (Cross-Repo)
The API service has its own scanner-versions ConfigMap that must stay in sync:
- `blocksecops-api-service/k8s/overlays/local/api-service/scanner-versions-configmap.yaml`

**CRITICAL:** Version tags must match across all ConfigMaps. A cross-repo consistency test (`test_configmap_overlay_consistency.py`) validates this.

### Reference Files
- `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` -- base ConfigMap (source of truth)
- `blocksecops-tool-integration/k8s/overlays/local/scanner-versions-patch.yaml` -- Harbor registry overlay
- `blocksecops-tool-integration/k8s/overlays/production/scanner-versions-patch.yaml` -- GCP Artifact Registry overlay
- `blocksecops-api-service/k8s/overlays/local/api-service/scanner-versions-configmap.yaml` -- API service overlay

### Checklist
- [ ] Base ConfigMap: `SCANNER_IMAGE_<KEY>` entry added
- [ ] Base ConfigMap: `SCANNER_METADATA` JSON updated with scanner entry
- [ ] Local overlay: Harbor-prefixed entry added
- [ ] Production overlay: GCP Artifact Registry-prefixed entry added
- [ ] API service overlay: Entry added with matching version tag
- [ ] All version tags are identical across all 4 files
- [ ] ConfigMap applies without errors (`kubectl apply -k k8s/overlays/local --dry-run=client`)

---

## Step 4: KJM Configuration

Configure the Kubernetes Job Manager (KJM) with the 5 required configuration entries for the new scanner.

### File Location
`blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py`

### Required Entries (5 Dictionaries)

Each scanner needs an entry in these 5 dictionaries within KJM:

| Dictionary | Method | Description | Example |
|------------|--------|-------------|---------|
| `scanner_images` | `_get_scanner_image()` | Docker image reference (fallback if env var missing) | `"scanner-<key>:0.3.0"` |
| `scanner_commands` | `_get_scanner_command()` | Command override (`None` if wrapper is entrypoint) | `None` |
| `memory_limits` | `_get_memory_limit()` | Maximum memory allocation | `"1Gi"` |
| `memory_requests` | `_get_memory_request()` | Requested memory allocation | `"512Mi"` |
| `scanner_timeouts` | `_get_scanner_timeout()` | Maximum scan execution time (seconds) | `120` |

### Code Pattern
```python
# In _get_scanner_image():
scanner_images = {
    # ... existing scanners ...
    "<key>": "scanner-<key>:<version>",
}

# In _get_scanner_command():
scanner_commands = {
    # ... existing scanners ...
    "<key>": None,  # Wrapper script is the entrypoint
}

# In _get_memory_limit():
memory_limits = {
    # ... existing scanners ...
    "<key>": "1Gi",
}

# In _get_memory_request():
memory_requests = {
    # ... existing scanners ...
    "<key>": "512Mi",
}

# In _get_scanner_timeout():
scanner_timeouts = {
    # ... existing scanners ...
    "<key>": 120,
}
```

### Image Resolution Order
KJM resolves scanner images in this priority:
1. Environment variable `SCANNER_IMAGE_<KEY>` (from ConfigMap, set by kustomize overlay)
2. Fallback value in `scanner_images` dictionary

**CRITICAL:** The fallback tag in KJM must match the base ConfigMap tag. If they drift, scans may use the wrong image version.

### Reference Files
- `blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py` -- KJM source

### Checklist
- [ ] All 5 dictionary entries added (image, command, memory_limit, memory_request, timeout)
- [ ] Fallback image tag matches base ConfigMap tag
- [ ] Resource values appropriate for scanner profile
- [ ] Timeout value validated against scanner execution benchmarks
- [ ] `command` is `None` if the wrapper script is the Docker entrypoint

---

## Step 5: Tool-Integration Callback Handler

Add a callback handler branch in the tool-integration main.py to parse scanner results POSTed back from the scanner container.

### File Location
`blocksecops-tool-integration/src/main.py`

### Three Integration Points

#### 5a. Add to `valid_scanners` list (~line 397)
```python
valid_scanners = [
    # ... existing scanners ...
    "<key>",
]
```

#### 5b. Add to `scanner_configs` dict (~line 557)
```python
scanner_configs = {
    # ... existing scanners ...
    "<key>": {"language": "<Language>", "type": "<Scanner Type>"},
}
```

#### 5c. Add callback handler branch (before the `else:` fallback)
```python
elif scanner_type == "<key>":
    # Parse <Scanner Name> results
    findings_raw = results_json.get("findings", [])
    vulnerability_results = []

    for finding in findings_raw:
        vulnerability_results.append({
            "vulnerability_type": finding.get("detector_id", "unknown"),
            "severity": finding.get("severity", "medium"),
            "title": finding.get("title", "Unknown Issue"),
            "description": finding.get("message", ""),
            "line_number": finding.get("line"),
            "column_number": finding.get("column"),
            "code_snippet": finding.get("code_snippet") or finding.get("snippet"),
            "recommendation": finding.get("recommendation"),
            "confidence": finding.get("confidence", 0.7),
            "scanner_id": "<key>",
            "category": "uncategorized",
            "scanner_name": "<key>",
            "file_path": finding.get("file", ""),
        })

    # POST to API service
    scan_results = {
        "scanner": "<key>",
        "status": "completed",
        "vulnerabilities": vulnerability_results
    }
    # ... POST to api-service ...
```

### Common Pitfalls
| Issue | Cause | Fix |
|-------|-------|-----|
| `code_snippet` is always null | Scanner wrapper uses `"code_snippet"` key but handler reads `"snippet"` | Use `finding.get("code_snippet") or finding.get("snippet")` |
| Confidence always 0.7 | Handler hardcodes confidence instead of reading from scanner | Use `finding.get("confidence", 0.7)` |
| Duplicate findings from ConfigMap symlinks | Hidden dir paths not filtered | Filter `file_path.startswith("./..") or file_path.startswith("..")` |

### Reference Files
- `blocksecops-tool-integration/src/main.py` -- callback handler source
- Existing handler examples: `soliditydefend` (~line 1320), `rustdefend` (~line 1408)

### Checklist
- [ ] Added to `valid_scanners` list
- [ ] Added to `scanner_configs` dict
- [ ] Callback handler branch added with correct field mapping
- [ ] ConfigMap symlink paths filtered
- [ ] Confidence read from scanner output (not hardcoded)
- [ ] Code snippet key matches wrapper output format

---

## Step 6: Orchestration Parser + Registry

Implement a parser class in the orchestration layer and register it.

### Parser Implementation
**File:** `blocksecops-orchestration/src/blocksecops_orchestration/parsers/<language>_parsers.py`

Choose the appropriate parser file based on language:
- `solidity_parsers.py` -- Solidity scanners
- `vyper_parsers.py` -- Vyper scanners
- `solana_parsers.py` -- Solana/Rust scanners

### Parser Class Pattern
```python
class <Scanner>Parser(ResultParser):
    """Parser for <Scanner Name> output."""

    def __init__(self):
        super().__init__(scanner_id="<key>")

    def parse(
        self,
        raw_output: Dict[str, Any],
        scan_id: UUID,
        contract_id: UUID,
        source_code: str,
    ) -> List[ParsedFinding]:
        findings = []
        raw_findings = raw_output.get("findings", raw_output.get("vulnerabilities", []))

        for finding in raw_findings:
            finding_data = {
                "detector_id": finding.get("detector_id", "unknown"),
                "severity": finding.get("severity", "medium"),
                "title": finding.get("title", "Unknown Issue"),
                "description": finding.get("message", ""),
                "file_path": finding.get("file", ""),
                "line_number": finding.get("line"),
                "column_number": finding.get("column"),
                "code_snippet": finding.get("snippet", ""),
                "recommendation": finding.get("recommendation", ""),
            }
            findings.append(ParsedFinding(
                finding_type=FindingType.VULNERABILITY,
                scanner_id=self.scanner_id,
                data=finding_data,
            ))
        return findings
```

### Registry Registration
**File:** `blocksecops-orchestration/src/blocksecops_orchestration/parsers/registry.py`

1. Add import:
```python
from blocksecops_orchestration.parsers.<language>_parsers import (
    # ... existing imports ...
    <Scanner>Parser,
)
```

2. Add registration in `_register_default_parsers()`:
```python
self.register(<Scanner>Parser())
```

### Reference Files
- `blocksecops-orchestration/src/blocksecops_orchestration/parsers/solana_parsers.py` -- Solana parser examples
- `blocksecops-orchestration/src/blocksecops_orchestration/parsers/registry.py` -- parser registry

### Checklist
- [ ] Parser class implemented in appropriate `<language>_parsers.py`
- [ ] Parser handles empty output and malformed JSON gracefully
- [ ] Parser handles both `"findings"` and `"vulnerabilities"` keys
- [ ] Parser imported and registered in `registry.py`
- [ ] Unit tests created and passing

---

## Step 7: API Metadata Registration

Register the scanner in the API service's SCANNERS dictionary and scan presets.

### File Location
`blocksecops-api-service/src/infrastructure/scanner_config/scanners.py`

### SCANNERS Dictionary Entry
```python
"<key>": ScannerMetadata(
    id="<key>",
    name="<Display Name>",
    description="<Brief description>",
    language="<rust|solidity|vyper>",
    scanner_type="<static_analysis|fuzzer|formal_verification|linter>",
    version="<tool-version>",
    developer="<Developer Name>",
    is_blocksecops_scanner=<True|False>,
    requires_compilation=<True|False>,
    detector_count=<count>,
),
```

### Scan Presets
Add the scanner key to relevant presets (quick, standard, deep):
```python
SCAN_PRESETS = {
    "<language>_quick": ScanPreset(scanner_ids=[..., "<key>"]),
    "<language>_standard": ScanPreset(scanner_ids=[..., "<key>"]),
    "<language>_deep": ScanPreset(scanner_ids=[..., "<key>"]),
}
```

### Reference Files
- `blocksecops-api-service/src/infrastructure/scanner_config/scanners.py` -- scanner metadata and presets
- `blocksecops-api-service/tests/unit/test_scanner_config.py` -- scanner config tests

### Checklist
- [ ] SCANNERS dict entry added with all required fields
- [ ] Added to all relevant scan presets
- [ ] `is_blocksecops_scanner` set correctly (True for internal tools)
- [ ] `requires_compilation` set correctly
- [ ] Scanner config tests updated and passing

---

## Step 8: Admin Portal Registration

Register the scanner in the admin portal frontend configuration.

### Files to Modify
- `blocksecops-dashboard/admin-portal/src/lib/scanners.ts` -- SCANNERS array and NAME_TO_KEY mapping

### SCANNERS Array Entry
```typescript
{
  key: "<key>",
  name: "<Display Name>",
  description: "<Brief description>",
  language: "<Solidity|Rust|Vyper>",
  type: "<Static Analysis|Fuzzer|Formal Verification|Linter>",
  developer: "<Developer Name>",
  version: "<tool-version>",
  enabled: true,
}
```

### NAME_TO_KEY Mapping
```typescript
NAME_TO_KEY["<Display Name>"] = "<key>";
```

### Reference Files
- `blocksecops-dashboard/admin-portal/src/lib/scanners.ts` -- scanner config

### Checklist
- [ ] SCANNERS array entry added
- [ ] NAME_TO_KEY mapping added
- [ ] Scanner displays correctly in admin UI
- [ ] Admin portal tests updated and passing

---

## Step 9: Vulnerability Pattern Creation + Mappings

Define BVD (BlockSecOps Vulnerability Definition) patterns for the scanner's detectors and create mapping files.

### Pattern Files
**Location:** `blocksecops-api-service/scripts/intelligence/`

Two JSON files per scanner:
1. `<key>-patterns.json` -- vulnerability pattern definitions
2. `<key>-detector-pattern-mappings.json` -- maps detector IDs to pattern codes

### Pattern JSON Format
```json
{
  "description": "<Scanner Name> vulnerability patterns",
  "patterns": [
    {
      "pattern_code": "BVD-<ECOSYSTEM>-<CATEGORY>-<SCANNER>-<DETECTOR>",
      "title": "<Vulnerability Title>",
      "description": "<Detailed description>",
      "severity": "<critical|high|medium|low|info>",
      "ecosystem": "<solidity|rust|vyper>",
      "cwe": "CWE-XXX",
      "recommendation": "<Remediation guidance>"
    }
  ]
}
```

### Mapping JSON Format
```json
{
  "scanner_id": "<key>",
  "mappings": [
    {
      "detector_id": "<DETECTOR-ID>",
      "pattern_code": "BVD-<ECOSYSTEM>-<CATEGORY>-<SCANNER>-<DETECTOR>"
    }
  ]
}
```

### Reference Files
- `blocksecops-api-service/scripts/intelligence/rustdefend-patterns.json` -- Rust example
- `blocksecops-api-service/scripts/intelligence/rustdefend-detector-pattern-mappings.json` -- Rust mapping example

### Checklist
- [ ] Pattern JSON created with all detectors
- [ ] Mapping JSON created linking detectors to patterns
- [ ] Pattern codes follow BVD naming convention
- [ ] CWE identifiers verified
- [ ] All severity levels represented

---

## Step 10: Pattern Seeding to Database

Seed vulnerability patterns into the database using the seed script.

### Seed Script
**File:** `blocksecops-api-service/scripts/seed_scanner_patterns.py`

This is a shared script that reads pattern and mapping JSON files and inserts them into the database. It is idempotent (uses `INSERT ... ON CONFLICT DO NOTHING`).

### Usage
```bash
cd /home/pwner/Git/blocksecops-api-service

# Dry run (preview only)
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  python scripts/seed_scanner_patterns.py --scanner <key> --dry-run

# Apply
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  python scripts/seed_scanner_patterns.py --scanner <key> --apply
```

### Checklist
- [ ] Pattern and mapping JSON files exist in `scripts/intelligence/`
- [ ] Dry run shows expected patterns and mappings
- [ ] Applied to local database successfully
- [ ] Patterns queryable via API (`GET /api/v1/patterns?scanner=<key>`)

---

## Step 11: Test Suite Updates

Ensure all new and modified code is covered by tests.

### Required Test Updates

| Repository | File | Change |
|------------|------|--------|
| tool-integration | `tests/regression/test_scanner_availability.py` | Add `"<key>"` to `ALL_SCANNERS` list |
| tool-integration | `tests/integration/test_trigger_endpoint.py` | Add `"<key>"` to `@pytest.mark.parametrize` list |
| tool-integration | `tests/integration/test_callback_endpoint.py` | Add `Test<Scanner>Callback` class |
| tool-integration | `tests/unit/scanners/test_<key>_parser.py` | New parser unit test file |
| tool-integration | `tests/fixtures/scanner_outputs/<key>_output.json` | New fixture file with sample output |
| tool-integration | `tests/conftest.py` | Add `<key>_fixture` and `<key>_fixture_dict` session fixtures |
| orchestration | `tests/unit/scanners/test_registry_completeness.py` | Add scanner to expected set and count |
| orchestration | `tests/integration/test_all_scanners.py` | Add scanner to `expected_scanners` set and count assertion |
| api-service | `tests/unit/test_scanner_config.py` | Add `Test<Scanner>Config` class |
| api-service | `tests/integration/test_scanner_api_language_support.py` | Add to language-specific scanner list |

### Running Tests
```bash
# Tool-integration (should be ~388+ tests)
cd /home/pwner/Git/blocksecops-tool-integration
python3 -m pytest tests/ -v

# Orchestration (should be ~251+ tests)
cd /home/pwner/Git/blocksecops-orchestration
python3 -m pytest tests/ -v

# API service scanner config
cd /home/pwner/Git/blocksecops-api-service
PYTHONPATH=src python3 -m pytest tests/unit/test_scanner_config.py -v --override-ini="addopts="
```

### Checklist
- [ ] Fixture JSON created with realistic sample output
- [ ] Parser unit tests cover: multi-finding parse, severity mapping, confidence mapping, empty output, invalid JSON
- [ ] Callback integration tests verify field preservation
- [ ] Scanner availability regression test updated
- [ ] Trigger endpoint parametrize list updated
- [ ] Orchestration registry completeness test updated (scanner count + expected set)
- [ ] API scanner config test class added
- [ ] All test suites passing

---

## Step 12: Build, Push, and Deploy

Build the Docker image, push to Harbor, and deploy to the cluster.

### Build and Push
```bash
cd /home/pwner/Git/blocksecops-tool-integration

# Build scanner image
docker build -t harbor.0xapogee.local/blocksecops/scanner-<key>:<version> \
  scanner-images/<key>/

# Push to Harbor
docker push harbor.0xapogee.local/blocksecops/scanner-<key>:<version>

# Apply kustomize overlay (updates ConfigMap in cluster)
kubectl apply -k k8s/overlays/local

# Restart tool-integration to pick up new ConfigMap
kubectl rollout restart deployment/tool-integration -n tool-integration-local
kubectl rollout status deployment/tool-integration -n tool-integration-local
```

### Verify Deployment
```bash
# Check env var is set in running pod
kubectl exec -n tool-integration-local deployment/tool-integration -- \
  env | grep SCANNER_IMAGE_<KEY>

# Run a test scan via API
curl -sk -X POST "https://app.0xapogee.local/api/v1/scans/<scan-id>/trigger?scanner=<key>" \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"contract_source": "<test contract>"}'
```

### Checklist
- [ ] Image built successfully
- [ ] Image pushed to Harbor
- [ ] Kustomize overlay applied
- [ ] Tool-integration deployment restarted
- [ ] Env var visible in running pod
- [ ] Test scan completes with findings

---

## Step 13: Documentation

Create all required documentation artifacts.

### Required Documents

| Document | Path | Content |
|----------|------|---------|
| Changelog | `docs/changelogs/<SCANNER>-<VERSION>-INTEGRATION-<DATE>.md` | Integration changelog with all changes |
| Scanner README | `docs/scanners/<Scanner>/README.md` | Scanner capabilities, CLI usage, detector table |
| Task Documentation | `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-<DATE>-<SCANNER>-INTEGRATION.md` | Task summary, files modified, verification |

### Reference Files
- `docs/changelogs/` -- existing changelogs
- `docs/scanners/RustDefend/README.md` -- recent scanner README example
- `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-02-16-RUSTDEFEND-INTEGRATION.md` -- recent task doc example

### Checklist
- [ ] Changelog written with all files modified
- [ ] Scanner README written with full detector table
- [ ] Task documentation written with verification checklist
- [ ] Pipeline docs updated (this file, readiness checklist)

---

## Step 14: GitOps Workflow

Follow the GitOps branching strategy for multi-repository changes.

### Branch Strategy
- Create a feature branch in each affected repository.
- Branch naming convention: `feat/<scanner-key>-integration`.
- Each repository gets its own pull request.
- Pull requests cross-reference each other.

### Deployment Order
1. Scanner Docker image (build and push to Harbor).
2. `blocksecops-tool-integration` -- ConfigMaps, KJM, callback handler, tests.
3. `blocksecops-orchestration` -- Parser, registry, tests.
4. `blocksecops-api-service` -- Scanner config, presets, ConfigMap overlay, patterns, tests.
5. `blocksecops-dashboard` -- Admin portal scanner config.
6. `docs` / `TaskDocs-BlockSecOps` -- Documentation.

### Checklist
- [ ] Feature branches created in all affected repositories
- [ ] Pull requests opened with cross-references
- [ ] All test suites passing
- [ ] Code reviews completed
- [ ] Deployment order followed
- [ ] Post-deployment verification completed (end-to-end scan)

---

## Master Checklist Template

Copy this checklist when starting a new scanner integration:

```
## Scanner Integration: <Scanner Name>
Date: <YYYY-MM-DD>

### Step 1: Scanner Evaluation
- [ ] Output format documented
- [ ] Licensing reviewed
- [ ] CLI tested with sample projects
- [ ] Exit codes verified
- [ ] Resource usage profiled

### Step 2: Docker Image
- [ ] Dockerfile created with multi-stage build and non-root user
- [ ] Wrapper script created with `find -L` and curl retry
- [ ] Image builds successfully
- [ ] Local test passes (including ConfigMap-style symlink mount)

### Step 3: ConfigMap Registration (4 files)
- [ ] Base ConfigMap entry added (scanner-versions-configmap.yaml)
- [ ] Base ConfigMap SCANNER_METADATA JSON updated
- [ ] Local overlay entry added (Harbor registry)
- [ ] Production overlay entry added (GCP Artifact Registry)
- [ ] API service overlay entry added (matching version)
- [ ] All 4 version tags identical

### Step 4: KJM Configuration (5 entries)
- [ ] image fallback defined
- [ ] command defined (None if wrapper is entrypoint)
- [ ] memory_limit defined
- [ ] memory_request defined
- [ ] timeout defined

### Step 5: Tool-Integration Callback (3 integration points)
- [ ] Added to valid_scanners list
- [ ] Added to scanner_configs dict
- [ ] Callback handler branch implemented
- [ ] ConfigMap symlink paths filtered
- [ ] Confidence read from scanner (not hardcoded)

### Step 6: Orchestration Parser + Registry
- [ ] Parser class implemented
- [ ] Parser registered in registry.py
- [ ] Handles empty/malformed output

### Step 7: API Metadata
- [ ] SCANNERS dict entry added
- [ ] Scan presets updated (quick/standard/deep)
- [ ] Scanner config tests passing

### Step 8: Admin Portal
- [ ] SCANNERS array entry added
- [ ] NAME_TO_KEY mapping added
- [ ] Tests passing

### Step 9: Vulnerability Patterns
- [ ] patterns.json created
- [ ] detector-pattern-mappings.json created
- [ ] All detectors mapped

### Step 10: Pattern Seeding
- [ ] Dry run reviewed
- [ ] Applied to database

### Step 11: Test Suite
- [ ] Parser unit tests passing
- [ ] Callback integration tests passing
- [ ] Scanner availability regression test updated
- [ ] Trigger endpoint test updated
- [ ] Orchestration registry test updated (count + set)
- [ ] API scanner config test added
- [ ] All test suites green

### Step 12: Build and Deploy
- [ ] Image built and pushed to Harbor
- [ ] Kustomize overlay applied
- [ ] Tool-integration restarted
- [ ] Env var verified in running pod
- [ ] End-to-end test scan produces findings

### Step 13: Documentation
- [ ] Changelog written
- [ ] Scanner README written
- [ ] Task documentation written
- [ ] Pipeline docs updated

### Step 14: GitOps
- [ ] Feature branches created
- [ ] PRs opened with cross-references
- [ ] All tests green
- [ ] Deployment order followed
- [ ] Post-deployment verified
```

---

## Lessons Learned

### From RustDefend Integration (February 2026)

| Lesson | Details |
|--------|---------|
| **ConfigMap symlinks** | Kubernetes ConfigMap volumes use hidden-dir symlinks. `find` without `-L` returns empty results. Always use `find -L`. |
| **Field name drift** | Wrapper script uses `"code_snippet"`, handler read `"snippet"`. Always verify field names match end-to-end. |
| **Hardcoded defaults** | Callback handler hardcoded `confidence: 0.7` instead of reading from scanner output. Always read values from scanner when available. |
| **Cross-repo version alignment** | Image tags must match across 4+ ConfigMap files in 2 repos. Automated consistency tests catch drift. |
| **KJM fallback drift** | KJM fallback image tag had `0.1.0` while deployed image was `0.3.0`. Keep fallback tags updated. |
| **Hidden dir duplicates** | ConfigMap creates both `./contract.rs` (symlink) and `./../contract.rs` (real). Filter `./..` paths to avoid counting findings twice. |
| **Build and deploy** | Always build, push, and deploy as part of any fix. A fix without deployment is not a fix. |

---

## Related Documentation

- [Scanner Readiness Checklist](./scanner-readiness-checklist.md) -- Operational readiness verification
- [Scanner Upgrade Pipeline](./scanner-upgrade-pipeline.md) -- Upgrading existing scanner versions
- [Scanner Data Audit Pipeline](./scanner-data-audit-pipeline.md) -- Data auditing for scanners
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md) -- Manual image build + deploy
- [Docker Image Versioning Standards](../standards/docker-image-versioning.md) -- Version bump workflow
- [Kustomize Standards](../standards/kustomize-standards.md) -- Overlay patterns
