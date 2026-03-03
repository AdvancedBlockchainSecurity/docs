# Scanner Documentation

**Last Updated**: March 3, 2026
**API Pipeline Tested**: February 13, 2026
**Parser Tests Passing**: February 13, 2026 (335 tests — unit, integration, regression)
**Fuzzer Filtering Tested**: December 29, 2025 (is_project filtering verified)
**Fuzzer Results Display**: December 30, 2025 (end-to-end verified)
**Active Scanners**: 18 available in orchestration (18 total registered)
**Supported Languages**: Solidity (12 scanners), Vyper (2 scanners), Solana (4 scanners, 2 active)
**Execution Mode**: Docker-based execution for Solana scanners
**Project Mode**: Foundry/Hardhat support enabled (Phase 3.2)
**Scanner Effectiveness**: Available at `/analytics/scanner-effectiveness`

---

## Overview

Security scanner integration, management, and troubleshooting guides for the Apogee Platform. This directory contains documentation for all scanner operations, from adding new scanners to debugging workflow issues.

---

## Contents

### 🚀 Project Mode (Phase 3.2)

- **[Project Mode Scanning](PROJECT-MODE-SCANNING.md)** - Foundry/Hardhat project support
  - Multi-file project uploads
  - Import remapping handling
  - Framework config parsing
  - Scanner project mode execution

### 🔧 Scanner Management

- **[Scanner Integration Guide](SCANNER-INTEGRATION-GUIDE.md)** - Add new scanners to the platform
  - Docker image creation
  - Kubernetes Job configuration
  - Result parsing and mapping
  - Testing scanner integration

- **[Scanner Update Guide](SCANNER-UPDATE-GUIDE.md)** - Update existing scanners
  - Version updates
  - Configuration changes
  - Detector additions
  - Breaking change handling

- **[Scanner Upgrade Workflow](../workflows/scanner-upgrade-workflow.md)** - Automated upgrade pipeline
  - Admin Dashboard one-click upgrade (metadata only)
  - Full pipeline: version update → image build → detector comparison → pattern seeding → audit
  - CLI scripts: `upgrade_scanner.py`, `seed_scanner_patterns.py`, `audit_scanner_upgrade.py`

- **[Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md)** - Step-by-step manual upgrade
  - Docker image build and push
  - ConfigMap updates
  - Test scan verification
  - Pattern seeding

- **[Scanner Removal Guide](SCANNER-REMOVAL-GUIDE.md)** - Remove scanners safely
  - Deprecation process
  - Database cleanup
  - User notification
  - Migration guide for users

### 🧠 Intelligence Integration

- **[Scanner Intelligence Integration](SCANNER-INTELLIGENCE-INTEGRATION.md)** - Connect scanners to intelligence engine
  - Pattern mapping creation
  - Detector-to-pattern relationships
  - Enrichment pipeline integration
  - Testing intelligence enrichment

- **[Detector Tracking](SCANNER-DETECTOR-TRACKING.md)** - Track detector coverage
  - Detector inventory (509 total)
  - Coverage statistics by scanner
  - Intelligence integration progress
  - Missing detector identification

### 🐛 Troubleshooting

- **[Workflow Troubleshooting](SCANNER-WORKFLOW-TROUBLESHOOTING.md)** - Debug scanner workflows
  - Common scanner errors
  - Kubernetes Job failures
  - Result parsing issues
  - Timeout problems
  - Performance optimization

---

## Active Scanners (15 Production-Ready)

### Solidity Static Analysis (7)

| Scanner | Version | Detectors | Project Mode | Requires Project | Status |
|---------|---------|-----------|--------------|------------------|--------|
| **Slither** | 0.3.4 | 93 | ✅ Foundry/Hardhat | ❌ No | ✅ Active |
| **Aderyn** | 0.7.4 | 88 | ✅ Foundry | ❌ No | ✅ Active |
| **Mythril** | - | 4 | ❌ Single-file | ❌ No | ✅ Active |
| **Semgrep** | 0.3.9 | 47 | ❌ Single-file | ❌ No | ✅ Active |
| **Solhint** | 0.1.9 | 20 | ❌ Single-file | ❌ No | ✅ Active |
| **Wake** | 0.3.9 | - | ✅ Foundry | ❌ No | ✅ Active |
| **SolidityDefend** | 0.9.2 | 204+ | ✅ Foundry/Hardhat | ❌ No | ✅ Active |

### Solidity Fuzzing & Symbolic (3)

| Scanner | Version | Type | Project Mode | Requires Project | Status |
|---------|---------|------|--------------|------------------|--------|
| **Echidna** | 0.3.1 | Fuzzer | ✅ Foundry | ✅ Yes | ✅ Active |
| **Medusa** | 0.3.3 | Fuzzer | ✅ Foundry | ✅ Yes | ✅ Active |
| **Halmos** | 0.3.4 | Symbolic | ❌ Single-file | ✅ Yes | ✅ Active |

> **Note on "Requires Project"**: Scanners marked with "Requires Project = Yes" are hidden from the scanner list when uploading single-file contracts. These scanners need test harnesses or project structure to provide meaningful results. They appear only for project uploads (ZIP/Foundry/Hardhat).

#### Fuzzer Results Display (December 30, 2025)

Fuzzer scanners now properly store and display results in the dashboard:

- **Fuzzing Results Panel**: Appears on scan results page when fuzzer scanners are used
- **Test Summary**: Shows passed/failed/error counts and average coverage
- **Individual Tests**: Each test displays status, executions, coverage percentage
- **Failure Details**: Failed tests show counterexamples and failure traces
- **Status Filtering**: Filter by passed/failed/error status

**Scanner-Specific Behavior:**

| Scanner | Summary Record | Handles No Tests | Parser Format |
|---------|---------------|------------------|---------------|
| Echidna | `echidna_scan_summary` | ✅ Creates passed summary | Standard |
| Medusa | `medusa_scan_summary` | ✅ Creates passed summary | Wrapper (`tool: "medusa"`) |
| Halmos | `halmos_scan_summary` | ✅ Creates passed summary | Standard |

**API Endpoints:**
- `GET /api/v1/scans/{id}/result-types` - Returns `["fuzzing"]` for fuzzer scans
- `GET /api/v1/scans/{id}/fuzzing-results` - Returns fuzzing test data with filtering

### Vyper Scanners (2)

| Scanner | Version | Type | Requires Project | Status |
|---------|---------|------|------------------|--------|
| **Vyper** | 0.3.2 | Compiler/Analyzer | ❌ No | ✅ Active |
| **Moccasin** | 0.3.2 | Fuzzer | ✅ Yes | ✅ Active |

### Solana/Rust Scanners (4) — 2 Active, 2 Pending

Docker images built and deployed to Harbor. Sol-azy and RustDefend are fully operational on the platform pipeline. Remaining scanners require additional orchestration integration.

| Scanner | Version | Type | Requires Project | Status |
|---------|---------|------|------------------|--------|
| **Sol-azy** | 0.4.1 | Static Analysis | ❌ No | ✅ Active |
| **RustDefend** | 0.4.3 | Static Analysis (AST) | ❌ No | ✅ Active |
| **Trident** | 0.3.0 | Fuzzer | ✅ Yes | ⏳ Unavailable |
| **cargo-fuzz-solana** | 0.3.0 | Fuzzer | ✅ Yes | ⏳ Unavailable |

### Removed Scanners (December 2025)

**Cairo/StarkNet (December 13, 2025)**:
- `caracal/` - Cairo static analyzer (14 detectors) - ecosystem not supported
- `starknet-foundry/` - Cairo fuzzer - ecosystem not supported
- `tayt/` - Cairo fuzzing library (archived by Trail of Bits)

**Earlier Removals (December 11, 2025)**:
- `4naly3er/` - Tool abandoned
- `foundry-fuzz/` - Superseded by other tools
- `thoth/` - Not implemented
- `trident-fuzzer/` - Renamed to `trident/`

### Restored Scanners (December 2025)

**Mythril (December 20, 2025)**:
- `mythril/` - Symbolic execution scanner re-added to registry
- Was never actually removed, just missing from scanner registration
- Fixed via Scanner Pattern Coverage Audit (see `/docs/changelogs/SCANNER-PATTERN-AUDIT-2025-12-20.md`)
- 4 pattern mappings now active

---

## Scanner Types

### Static Analysis (7 scanners)
Analyzes source code without execution:
- **Pros**: Fast, comprehensive coverage, no execution environment needed
- **Cons**: May have false positives, limited to known patterns
- **Examples**: Slither, Aderyn, Semgrep, SolidityDefend, Sol-azy, RustDefend, Sec3 X-Ray

### Fuzzing (5 scanners)
Generates test inputs to find edge cases:
- **Pros**: Finds runtime bugs, discovers unexpected behaviors
- **Cons**: Time-consuming, requires good seed inputs
- **Examples**: Echidna, Medusa, Moccasin, Trident

### Formal Verification (1 scanner)
Mathematically proves correctness:
- **Pros**: Highest confidence, proves absence of bugs
- **Cons**: Requires specifications, very time-consuming
- **Examples**: Halmos

### Linters (1 scanner)
Code quality and style checking:
- **Pros**: Fast, improves code quality
- **Cons**: Not security-focused
- **Examples**: Solhint

### SBOM Generation (0 scanners - ROLLED BACK)
Software Bill of Materials:
- **Status**: ❌ **ROLLED BACK** (November 30, 2025)
- **Reason**: Authentication conflicts and scope creep
- **Pros**: Dependency tracking, supply chain security
- **Cons**: Not vulnerability detection, complex solc version management
- **Examples**: SolidityBOM (deferred to future phase)
- **See**: `/Users/pwner/Git/ABS/TaskDocs-Apogee/phases/02-phase-3.1-scanner-integration/SOLIDITYBOM-ROLLBACK-PLAN.md`

---

## Scanner-Specific Documentation

### Detailed Scanner Guides

- **[Slither](slither/README.md)** - Static analysis for Solidity and Vyper
  - 93 built-in detectors
  - Comprehensive vulnerability coverage
  - Fast analysis (seconds)
  - JSON output format

- **[SolidityDefend](SolidityDefend/README.md)** - Advanced Solidity security scanner
  - 204 detectors (market-leading coverage)
  - [Detector Mapping](SolidityDefend/DETECTOR-MAPPING.md)
  - High accuracy, low false positives
  - Enterprise-grade analysis

- **[Vyper](vyper/README.md)** - Vyper contract static analysis
  - Slither with Vyper compilation support
  - Python-based smart contract analysis

- **[Moccasin](moccasin/README.md)** - Vyper contract fuzzing
  - Cyfrin's Titanoboa-based fuzzer
  - Property-based testing for Vyper

---

## Scanner Workflow

### Execution Flow

```
1. User triggers scan via API
   │
2. API creates Kubernetes Job
   │
3. ConfigMap created with source code
   │
4. Scanner container starts
   │
5. Scanner reads source from ConfigMap
   │
6. Scanner executes analysis
   │
7. Scanner POSTs results to webhook
   │
8. Orchestration processes results
   │
9. Intelligence enriches findings
   │
10. Results stored in database
    │
11. WebSocket notifies frontend
```

### Scanner Docker Image Requirements

**Must include**:
- Scanner tool binary/executable
- Python 3.11+ (for result posting)
- `requests` library
- Entry script that:
  1. Reads source from `/source` mount
  2. Executes scanner
  3. Parses output to JSON
  4. POSTs to `$API_CALLBACK_URL`

**Example Dockerfile**:
```dockerfile
FROM python:3.11-slim

# Install scanner
RUN pip install slither-analyzer

# Copy entry script
COPY scanner-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Install requests for webhook
RUN pip install requests

ENTRYPOINT ["/entrypoint.sh"]
```

---

## Scanner Output Parsers

### Overview

Scanner output parsers normalize scanner-specific output formats into a standardized vulnerability finding structure. Parsers are implemented in `blocksecops-tool-integration/src/scanners/parser.py`.

### Available Parsers (Phase 3.5 Complete - 2025-12-29)

| Parser | Scanner(s) | Language | Output Type | Status |
|--------|-----------|----------|-------------|--------|
| **SlitherParser** | slither, vyper | Solidity, Vyper | vulnerabilities | ✅ Active |
| **MythrilParser** | mythril | Solidity | vulnerabilities | ✅ Active |
| **AderynParser** | aderyn | Solidity | vulnerabilities | ✅ Active |
| **EchidnaParser** | echidna | Solidity | vulnerabilities + fuzzing_results | ✅ Active |
| **MedusaParser** | medusa | Solidity | vulnerabilities + fuzzing_results | ✅ Active |
| **MoccasinParser** | moccasin | Vyper | vulnerabilities + fuzzing_results | ✅ Active |
| **SolAzyParser** | sol-azy, solana-rust | Solana/Rust | vulnerabilities | ✅ Active |
| **Sec3XRayParser** | sec3-xray | Solana/Rust | vulnerabilities | ✅ Active |
| **TridentParser** | trident | Solana/Rust | vulnerabilities + fuzzing_results | ✅ Active |
| **CargoFuzzSolanaParser** | cargo-fuzz-solana | Solana/Rust | vulnerabilities + fuzzing_results | ✅ Active |
| **GenericJsonParser** | fallback | Any | vulnerabilities | ✅ Active |

### Standardized Output Format

All parsers normalize output to this structure:

```python
{
    "status": "completed",
    "error": None,
    "vulnerabilities": [
        {
            "vulnerability_type": "reentrancy",
            "severity": "critical",  # critical, high, medium, low
            "title": "Reentrancy Vulnerability",
            "description": "...",
            "line_number": 42,
            "code_snippet": "...",
            "recommendation": "...",
            "confidence": "high",
            "scanner_id": "unique-id",
            "scanner_name": "slither",
            "raw_output": "..."
        }
    ]
}
```

### Fuzzing Results Format (Fuzzer Scanners Only)

Fuzzer parsers (Echidna, Medusa, Moccasin, Trident, cargo-fuzz-solana) return an additional `fuzzing_results` array:

```python
{
    "status": "completed",
    "error": None,
    "vulnerabilities": [...],  # Failed property tests become vulnerabilities
    "fuzzing_results": [
        {
            "test_name": "test_invariant_balance",
            "status": "passed",  # passed, failed
            "executions": 10000,
            "coverage_percentage": 85.5,
            "seed": 12345,
            "failure_trace": None,  # Call sequence if failed
            "edge_cases_found": []
        }
    ]
}
```

### Severity Mapping

Parsers normalize scanner-specific severity levels:

| Scanner Level | Normalized Level |
|--------------|------------------|
| High | critical |
| Medium | high |
| Low | medium |
| Informational | low |

### Parser Testing

```bash
# Run full test suite (335 tests — unit, integration, regression)
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
.venv/bin/python3 -m pytest tests/ -v

# Run parser unit tests only (68 tests)
.venv/bin/python3 -m pytest tests/unit/scanners/ -v
```

See: [Phase 3.5 Parser Changelog](/docs/changelogs/PHASE-3.5-PARSERS-2025-12-20.md)

---

## Adding a New Scanner

### Quick Start

1. **Create Docker Image**
   ```bash
   docker build -t scanner-myscan:1.0.0 .
   docker push registry.com/scanner-myscan:1.0.0
   ```

2. **Add Scanner Configuration** (orchestration-service)
   ```python
   SCANNERS = {
       "myscan": {
           "image": "registry.com/scanner-myscan:1.0.0",
           "language": "solidity",
           "timeout": 300,
           "type": "static_analysis"
       }
   }
   ```

3. **Test Scanner**
   ```bash
   curl -X POST http://localhost:8000/api/v1/scans \
     -H "Authorization: Bearer TOKEN" \
     -d '{"contract_id": "uuid", "scanners": ["myscan"]}'
   ```

4. **Add Intelligence Mapping** (optional)
   ```json
   {
     "scanner_id": "myscan",
     "detector_id": "my-detector-001",
     "pattern_code": "BVD-SOLIDITY-XXX-001"
   }
   ```

See: [Scanner Integration Guide](SCANNER-INTEGRATION-GUIDE.md)

---

## Scanner Statistics

### Coverage by Language

| Language | Active Scanners | Status |
|----------|----------------|--------|
| **Solidity** | 10 | ✅ Full support |
| **Vyper** | 2 | ✅ Full support |
| **Rust/Solana** | 2 (2 pending) | ✅ Sol-azy + RustDefend active; 2 remaining awaiting orchestration integration |

### Detector Coverage

- **Total Detectors**: 509+ across all scanners
- **Intelligence Integrated**: 78 (15.3%)
- **Remaining**: 431 detectors
- **Target**: 80% coverage by Q2 2026

### Performance Metrics

| Scanner | Avg Time | Max Size | Timeout |
|---------|----------|----------|---------|
| Slither | 15s | 10 MB | 5 min |
| Aderyn | 30s | 5 MB | 10 min |
| Mythril | 180s | 1 MB | 30 min |
| Semgrep | 10s | 10 MB | 5 min |
| Echidna | 600s | 5 MB | 60 min |

---

## Common Issues

### Scanner Job Fails to Start

**Symptoms**: Job stays in Pending state
**Causes**:
- Image pull error
- Insufficient resources
- ConfigMap not created

**Solution**: Check job logs
```bash
kubectl describe job scan-{scan_id} -n api-service-prod
kubectl logs job/scan-{scan_id} -n api-service-prod
```

### Scanner Times Out

**Symptoms**: Job exceeds activeDeadlineSeconds
**Causes**:
- Contract too large
- Scanner hung
- Insufficient CPU/memory

**Solution**: Increase timeout or optimize contract

### Results Not Posted

**Symptoms**: Scanner completes but no results in database
**Causes**:
- Webhook URL incorrect
- Network policy blocking
- Result parsing error

**Solution**: Check scanner logs for webhook errors

See: [Workflow Troubleshooting](SCANNER-WORKFLOW-TROUBLESHOOTING.md)

---

## Related Documentation

### Architecture
- [Scanner Integration Architecture](../architecture/phase-4e-scanner-integration-architecture.md)
- [Scanner Execution Architecture](../deployment/scanner-execution-architecture.md)

### Intelligence
- [Scanner Intelligence Integration](SCANNER-INTELLIGENCE-INTEGRATION.md)
- [Intelligence Integration Guide](../intelligence/INTELLIGENCE-INTEGRATION-GUIDE.md)

### Deployment
- [Scanner Docker Images](../deployment/scanner-docker-images.md)
- [Orchestration Service Deployment](../deployment/orchestration-service-deployment.md)

---

## Roadmap

### Q4 2025
- ✅ Phase 3 multi-language support complete (Solidity, Vyper, Rust/Solana)
- ✅ Cairo/StarkNet support deprecated (December 13, 2025)
- ⏳ Aderyn intelligence integration (88 detectors)

### Q1 2026
- 📋 Slither intelligence integration (93 detectors)
- 📋 Add missing Vyper scanners
- 📋 Add missing Solana scanners

### Q2 2026
- 📋 80% detector coverage target
- 📋 ML-powered scanner result aggregation
- 📋 Custom scanner SDK for community contributions

---

**Maintained by**: Apogee Scanner Integration Team
**Active Scanners**: 18 operational (February 17, 2026)
**Supported Languages**: Solidity (12 scanners), Vyper (2 scanners), Solana (4 scanners, 2 active)
**Total Detector Count**: 500+ and growing
