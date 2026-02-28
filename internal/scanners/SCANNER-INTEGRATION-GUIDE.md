# Scanner Integration Guide

**Version:** 1.1.0
**Last Updated:** December 5, 2025
**Status:** Active Template

> **📚 IMPORTANT - Claude Code Users:** When reading this guide, also read the companion document:
> **[SCANNER-INTELLIGENCE-INTEGRATION.md](SCANNER-INTELLIGENCE-INTEGRATION.md)**
>
> The Intelligence Layer automatically enriches all scanner findings with pattern classification, fingerprinting, and cross-scanner deduplication. Understanding both guides is essential for complete scanner integration.

## Purpose

This is a **reusable template** for integrating any security scanner into the Apogee platform. Follow this guide step-by-step to ensure consistent, standards-compliant scanner integration.

**This guide covers:**
- Docker image creation
- Parser implementation
- Pattern mapping (manual step)
- API registration and deployment

**Companion guide covers (automatic):**
- Pattern classification enrichment
- Fingerprint generation
- Cross-scanner deduplication
- Intelligence Layer verification and troubleshooting

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Integration Checklist](#integration-checklist)
3. [Step-by-Step Integration](#step-by-step-integration)
4. [Verification & Testing](#verification--testing)
5. [Documentation Requirements](#documentation-requirements)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting integration, ensure you have:

- [ ] Scanner binary or source code access
- [ ] Scanner documentation (output format, command-line flags, exit codes)
- [ ] Scanner release version (semantic versioning)
- [ ] Docker installed and working
- [ ] kubectl access to local Kubernetes cluster
- [ ] Git feature branch created (`git checkout -b feature/integrate-<scanner-name>`)
- [ ] Understanding of platform standards: `/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md`

---

## Critical Integration Requirements

**⚠️ IMPORTANT:** Scanner integration requires **THREE components** to work correctly:

1. **Tool-Integration Executor** - Scanner registered in tool-integration's `valid_scanners` list
2. **API Service Metadata** - Scanner registered in `scanners.py` configuration
3. **Dashboard Configuration** - Scanner requirements defined in `scannerConfigurations.ts`

**Common Pitfall:** Installing the scanner but forgetting to register it in all three locations will result in silent failures or invisible scanners.

**Lesson:** Always verify all THREE components are in place before considering integration complete.

---

## Integration Checklist

Use this checklist to track progress:

### Phase 1: Docker Image Creation
- [ ] Create scanner directory: `blocksecops-tool-integration/scanner-images/<scanner-name>/`
- [ ] Write Dockerfile following platform patterns
- [ ] Create execution wrapper script (`run-<scanner-name>.sh`)
- [ ] Build and test Docker image locally
- [ ] Tag image with semantic version

### Phase 2: Scanner Configuration
- [ ] Add scanner metadata to `scanner-versions-configmap.yaml`
- [ ] Use semantic versioning (MAJOR.MINOR.PATCH)
- [ ] Document scanner developer/organization
- [ ] Follow version selection policy (latest stable)

### Phase 3: Parser Implementation
- [ ] Create parser in `blocksecops-orchestration/src/parsers/<scanner_name>_parser.py`
- [ ] Implement `BaseParser` interface
- [ ] Extract all required fields (detector_id, file_path, function_name, contract_name, severity, code_snippet)
- [ ] Register parser in `blocksecops-orchestration/src/parsers/__init__.py`
- [ ] Write unit tests for parser

### Phase 4: Pattern Mapping (Vulnerability Scanners Only)
- [ ] Create pattern mapping file: `blocksecops-api-service/seeds/<scanner>_pattern_mappings.json`
- [ ] Map all detector IDs to standardized pattern codes (BVD-EVM-REE-001, BVD-EVM-ACC-001, etc.)
- [ ] Update seed script: `blocksecops-api-service/scripts/seed_vulnerability_patterns.py`
- [ ] Run seed script to populate database

### Phase 5: Kubernetes Integration
- [ ] Create Kubernetes job template in `blocksecops-orchestration`
- [ ] Configure resource limits (CPU, memory, timeout)
- [ ] Set up volume mounts for contract and output

### Phase 6: API Service Registration
- [ ] Add scanner to `blocksecops-api-service/src/infrastructure/scanner_config/scanners.py`
- [ ] Set scanner metadata (id, name, description, type, languages)
- [ ] DO NOT hardcode version/developer (loaded from ConfigMap)
- [ ] **⚠️ CRITICAL:** Add scanner ID to tool-integration `valid_scanners` list (`blocksecops-tool-integration/src/main.py:122`)
- [ ] Verify scanner appears in both API and tool-integration (see verification commands in Troubleshooting section)

### Phase 7: Build & Deploy
- [ ] Build Docker image with semantic version tag
- [ ] Load image to Minikube: `minikube image load <image>:<version>`
- [ ] Build updated orchestration service
- [ ] Build updated API service
- [ ] Deploy to Kubernetes
- [ ] Restart affected services

### Phase 8: Testing
- [ ] Run test scan with new scanner
- [ ] Verify findings stored in database
- [ ] Verify pattern codes assigned (vulnerability scanners)
- [ ] Verify fingerprints generated (Phase 4D)
- [ ] Test deduplication with other scanners
- [ ] Check orchestration logs for errors

### Phase 9: Documentation
- [ ] Update CHANGELOG with integration details
- [ ] Create scanner-specific integration doc (if needed)
- [ ] Update platform README
- [ ] Document any scanner-specific configuration

### Phase 10: Git Workflow
- [ ] Commit all changes to feature branch
- [ ] Create pull request
- [ ] Code review
- [ ] Merge to main
- [ ] Tag release: `git tag -a v<version> -m "Integrate <Scanner>"`

---

## Step-by-Step Integration

### Step 1: Create Scanner Docker Image

#### 1.1 Create Scanner Directory

```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
mkdir -p scanner-images/<scanner-name>
cd scanner-images/<scanner-name>
```

#### 1.2 Write Dockerfile

Follow platform patterns from existing scanners (see `slither/Dockerfile`, `aderyn/Dockerfile`).

**Template Dockerfile:**

```dockerfile
FROM <base-image>:<version>

LABEL maintainer="Apogee Team"
LABEL description="<Scanner Name> - <Brief description>"
LABEL version="<MAJOR.MINOR.PATCH>"
LABEL scanner.id="<scanner-id>"
LABEL scanner.type="<static_analysis|fuzzing|formal_verification>"
LABEL scanner.language="<solidity|rust|cairo|move>"

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        <dependencies> \
    && rm -rf /var/lib/apt/lists/*

# Install scanner
# Option A: From package manager
RUN <package-manager> install <scanner>==<version>

# Option B: From GitHub release
ARG SCANNER_VERSION=<MAJOR.MINOR.PATCH>
RUN curl -L "https://github.com/<org>/<repo>/releases/download/v${SCANNER_VERSION}/<binary>" \
    -o /usr/local/bin/<scanner> && \
    chmod +x /usr/local/bin/<scanner>

# Option C: Build from source
RUN git clone --depth 1 --branch v${SCANNER_VERSION} https://github.com/<org>/<repo>.git && \
    cd <repo> && \
    <build-command> && \
    cp <binary> /usr/local/bin/ && \
    cd .. && rm -rf <repo>

# Verify installation
RUN <scanner> --version

# Create working directories
WORKDIR /contracts
RUN mkdir -p /output

# Copy scanner execution script
COPY run-<scanner>.sh /app/run-<scanner>.sh
RUN chmod +x /app/run-<scanner>.sh

# Set up environment
ENV <ENV_VAR>=<value>

ENTRYPOINT ["/app/run-<scanner>.sh"]
```

#### 1.3 Create Execution Wrapper Script

Create `run-<scanner>.sh` following this template:

```bash
#!/bin/bash
set -e

# run-<scanner>.sh
# Wrapper script for running <Scanner Name> in Apogee platform
#
# Usage: run-<scanner>.sh <contract_path> [output_path]
#
# Arguments:
#   contract_path: Path to contract file or directory to scan
#   output_path: Optional path for output JSON file (default: /output/<scanner>-results.json)
#
# Environment Variables:
#   MIN_SEVERITY: Minimum severity level [default: info]
#   SCANNER_TIMEOUT: Analysis timeout in seconds [default: 300]

# Configuration
CONTRACT_PATH="${1:-/contracts}"
OUTPUT_PATH="${2:-/output/<scanner>-results.json}"
MIN_SEVERITY="${MIN_SEVERITY:-info}"
TIMEOUT="${SCANNER_TIMEOUT:-300}"

# Validate contract path exists
if [ ! -e "$CONTRACT_PATH" ]; then
    echo "Error: Contract path does not exist: $CONTRACT_PATH" >&2
    exit 1
fi

# Create output directory
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
mkdir -p "$OUTPUT_DIR"

echo "Starting <Scanner Name> analysis..."
echo "Contract path: $CONTRACT_PATH"
echo "Output path: $OUTPUT_PATH"
echo "Minimum severity: $MIN_SEVERITY"
echo "Timeout: ${TIMEOUT}s"

# Build scanner command
SCANNER_CMD=(
    "<scanner>"
    "--format" "json"
    "--output" "$OUTPUT_PATH"
    # Add scanner-specific flags here
)

# Add contract path
if [ -d "$CONTRACT_PATH" ]; then
    # Directory: scan all .sol files
    SCANNER_CMD+=("$CONTRACT_PATH"/*.sol)
elif [ -f "$CONTRACT_PATH" ]; then
    # Single file
    SCANNER_CMD+=("$CONTRACT_PATH")
fi

# Execute with timeout
echo "Running: ${SCANNER_CMD[*]}"
if timeout "$TIMEOUT" "${SCANNER_CMD[@]}"; then
    SCAN_EXIT_CODE=$?
else
    SCAN_EXIT_CODE=$?
fi

# Check if output file was created
if [ ! -f "$OUTPUT_PATH" ]; then
    echo "Error: Scanner did not produce output file" >&2
    echo '{"findings": [], "error": "No output produced"}' > "$OUTPUT_PATH"
    exit 1
fi

# Validate JSON output
if ! jq empty "$OUTPUT_PATH" 2>/dev/null; then
    echo "Error: Scanner produced invalid JSON" >&2
    mv "$OUTPUT_PATH" "${OUTPUT_PATH}.invalid"
    echo '{"findings": [], "error": "Invalid JSON output"}' > "$OUTPUT_PATH"
    exit 1
fi

# Display summary
echo "Analysis complete!"
jq -r '.summary | "Total findings: \(.total)"' "$OUTPUT_PATH" 2>/dev/null || echo "No summary available"

exit $SCAN_EXIT_CODE
```

#### 1.4 Build and Test Docker Image

```bash
# Build image with semantic version and latest tag
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/<scanner-name>
eval $(minikube docker-env)
docker build -t scanner-<scanner-name>:<MAJOR.MINOR.PATCH> -t scanner-<scanner-name>:latest .

# Test image locally
docker run --rm -v /path/to/test/contract.sol:/contracts/contract.sol \
    scanner-<scanner-name>:<MAJOR.MINOR.PATCH>

# Verify output is valid JSON
cat /tmp/output/<scanner>-results.json | jq .
```

---

### Step 2: Update Scanner Metadata ConfigMap

**CRITICAL:** Follow platform standard for tool metadata management.

#### 2.1 Update ConfigMap

```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
vim k8s/base/scanner-versions-configmap.yaml
```

Add scanner metadata in JSON format:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
  namespace: tool-integration-local
data:
  SCANNER_METADATA: |
    {
      "existing-scanner": {
        "version": "1.0.0",
        "developer": "Existing Developer"
      },
      "<scanner-id>": {
        "version": "<MAJOR.MINOR.PATCH>",
        "developer": "<Organization Name>",
        "release_date": "<YYYY-MM-DD>",
        "notes": "<Optional notes about this version>"
      }
    }
```

**Semantic Versioning Rules:**
- **MAJOR**: Breaking changes (incompatible API, output format changes)
- **MINOR**: New features (new detectors, backwards-compatible)
- **PATCH**: Bug fixes (backwards-compatible fixes)

**Version Selection Policy:**
- ✅ **MUST** use latest stable version
- ❌ **MUST NOT** use beta/rc versions without documented exception
- ℹ️ If using older version, document reason in `notes` field

#### 2.2 Apply ConfigMap

```bash
kubectl apply -f k8s/base/scanner-versions-configmap.yaml
```

---

### Step 3: Implement Parser

#### 3.1 Create Parser File

```bash
cd /Users/pwner/Git/ABS/blocksecops-orchestration
touch src/parsers/<scanner_name>_parser.py
```

#### 3.2 Implement BaseParser Interface

**Template Parser:**

```python
"""
<Scanner Name> Parser

Parses <Scanner Name> JSON output into standardized VulnerabilityFinding format.

Scanner Output Format:
<Describe expected JSON structure>

Example Output:
{
  "findings": [
    {
      "id": "...",
      "title": "...",
      "severity": "...",
      ...
    }
  ],
  "summary": {...}
}
"""

from typing import List, Dict, Any
from src.parsers.base import BaseParser, ParsedFinding
from src.domain.models import Severity

class <ScannerName>Parser(BaseParser):
    """Parser for <Scanner Name> security analysis output."""

    def parse(self, raw_output: str) -> List[ParsedFinding]:
        """
        Parse <Scanner Name> JSON output.

        Args:
            raw_output: Raw JSON string from scanner

        Returns:
            List of ParsedFinding objects

        Raises:
            ValueError: If output cannot be parsed
        """
        try:
            data = self._parse_json(raw_output)
        except ValueError as e:
            raise ValueError(f"Failed to parse <Scanner Name> output: {e}")

        findings = []
        for item in data.get("findings", []):
            try:
                finding = self._parse_finding(item)
                findings.append(finding)
            except Exception as e:
                self.logger.warning(f"Skipped invalid finding: {e}")
                continue

        return findings

    def _parse_finding(self, item: Dict[str, Any]) -> ParsedFinding:
        """Parse a single finding from <Scanner Name> output."""

        # Extract required fields
        detector_id = item.get("detector", item.get("id", "unknown"))
        title = item.get("title", item.get("message", ""))
        severity = self._map_severity(item.get("severity", "medium"))

        # Extract location information
        location = item.get("location", {})
        file_path = location.get("file", location.get("filename", ""))
        line_number = location.get("line", location.get("line_number"))

        # Extract context information
        function_name = item.get("function", item.get("function_name"))
        contract_name = item.get("contract", item.get("contract_name"))
        code_snippet = item.get("code", item.get("code_snippet"))

        # Build description
        description = item.get("description", item.get("detail", ""))
        if "recommendation" in item:
            description += f"\n\nRecommendation: {item['recommendation']}"

        return ParsedFinding(
            scanner_id="<scanner-id>",
            detector_id=detector_id,
            title=title,
            description=description,
            severity=severity,
            file_path=file_path,
            line_number=line_number,
            function_name=function_name,
            contract_name=contract_name,
            code_snippet=code_snippet,
            raw_output=item,
        )

    def _map_severity(self, scanner_severity: str) -> Severity:
        """Map <Scanner Name> severity to platform Severity enum."""
        severity_map = {
            "critical": Severity.CRITICAL,
            "high": Severity.HIGH,
            "medium": Severity.MEDIUM,
            "low": Severity.LOW,
            "info": Severity.INFO,
            "informational": Severity.INFO,
        }

        normalized = scanner_severity.lower()
        return severity_map.get(normalized, Severity.MEDIUM)
```

#### 3.3 Register Parser

Edit `src/parsers/__init__.py`:

```python
from src.parsers.<scanner_name>_parser import <ScannerName>Parser

# Parser registry
PARSER_REGISTRY = {
    "slither": SlitherParser(),
    "aderyn": AderynParser(),
    # ... existing parsers
    "<scanner-id>": <ScannerName>Parser(),  # Add new parser
}
```

#### 3.4 Write Parser Unit Tests

Create `tests/parsers/test_<scanner_name>_parser.py`:

```python
"""Unit tests for <Scanner Name> Parser"""

import pytest
import json
from src.parsers.<scanner_name>_parser import <ScannerName>Parser

class Test<ScannerName>Parser:
    """Test suite for <Scanner Name> parser."""

    @pytest.fixture
    def parser(self):
        return <ScannerName>Parser()

    @pytest.fixture
    def sample_output(self):
        """Sample scanner output"""
        return json.dumps({
            "findings": [
                {
                    "detector": "test-detector",
                    "title": "Test Vulnerability",
                    "severity": "high",
                    "description": "Test description",
                    "location": {
                        "file": "Contract.sol",
                        "line": 42
                    },
                    "contract": "TestContract",
                    "function": "testFunction"
                }
            ],
            "summary": {
                "total": 1,
                "high": 1
            }
        })

    def test_parse_valid_output(self, parser, sample_output):
        """Test parsing valid scanner output"""
        findings = parser.parse(sample_output)

        assert len(findings) == 1
        assert findings[0].detector_id == "test-detector"
        assert findings[0].title == "Test Vulnerability"
        assert findings[0].severity.value == "high"
        assert findings[0].file_path == "Contract.sol"
        assert findings[0].line_number == 42

    def test_parse_empty_output(self, parser):
        """Test parsing empty findings"""
        output = json.dumps({"findings": [], "summary": {"total": 0}})
        findings = parser.parse(output)

        assert len(findings) == 0

    def test_parse_invalid_json(self, parser):
        """Test parsing invalid JSON raises ValueError"""
        with pytest.raises(ValueError):
            parser.parse("invalid json{")

    def test_severity_mapping(self, parser):
        """Test severity level mapping"""
        assert parser._map_severity("critical").value == "critical"
        assert parser._map_severity("high").value == "high"
        assert parser._map_severity("medium").value == "medium"
        assert parser._map_severity("low").value == "low"
        assert parser._map_severity("info").value == "info"
        assert parser._map_severity("unknown").value == "medium"  # Default
```

Run tests:

```bash
cd /Users/pwner/Git/ABS/blocksecops-orchestration
pytest tests/parsers/test_<scanner_name>_parser.py -v
```

---

### Step 4: Create Pattern Mappings (Vulnerability Scanners Only)

**Skip this step if scanner is NOT a vulnerability scanner** (e.g., SBOM generators, formatters).

**📚 See also:** [Scanner Intelligence Layer Integration Guide](SCANNER-INTELLIGENCE-INTEGRATION.md) for complete details on automatic enrichment, fingerprinting, and deduplication.

#### 4.1 Create Pattern Mapping File

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
touch seeds/<scanner>_pattern_mappings.json
```

#### 4.2 Map Detector IDs to Pattern Codes

**Pattern Code Categories (BVD Format):**
- `BVD-REE-xxx`: Reentrancy vulnerabilities
- `BVD-ACC-xxx`: Access Control issues
- `BVD-ARI-xxx`: Arithmetic issues (overflow, underflow)
- `BVD-DEF-xxx`: DeFi-specific vulnerabilities
- `BVD-MEV-xxx`: MEV and front-running
- `BVD-ERC-xxx`: ERC standard violations
- `BVD-CRY-xxx`: Cryptography issues
- `BVD-RAN-xxx`: Randomness issues
- `BVD-GAS-xxx`: Gas optimization
- `BVD-GEN-xxx`: General/other

**Note**: All pattern codes use the `BVD-` prefix (Blockchain Vulnerability Database) as of October 2025.

**Template:**

```json
{
  "version": "1.0",
  "scanner": "<scanner-id>",
  "scanner_version": "<MAJOR.MINOR.PATCH>",
  "mappings": [
    {
      "detector_id": "reentrancy-eth",
      "pattern_code": "BVD-EVM-REE-001",
      "category": "Reentrancy",
      "description": "Reentrancy vulnerability with ETH transfer"
    },
    {
      "detector_id": "missing-access-control",
      "pattern_code": "BVD-EVM-ACC-001",
      "category": "Access Control",
      "description": "Missing access control on sensitive function"
    },
    {
      "detector_id": "integer-overflow",
      "pattern_code": "BVD-EVM-ARI-001",
      "category": "Arithmetic",
      "description": "Integer overflow vulnerability"
    }
  ]
}
```

#### 4.3 Update Seed Script

Edit `scripts/seed_vulnerability_patterns.py`:

```python
def load_pattern_mappings():
    """Load pattern mappings from seed files."""
    mappings = []

    # Load existing mappings
    # ...

    # Load new scanner mappings
    scanner_file = SEEDS_DIR / "<scanner>_pattern_mappings.json"
    if scanner_file.exists():
        with open(scanner_file) as f:
            data = json.load(f)
            for mapping in data["mappings"]:
                mappings.append({
                    "tool_name": "<scanner-id>",
                    "detector_id": mapping["detector_id"],
                    "pattern_code": mapping["pattern_code"]
                })

    return mappings
```

#### 4.4 Run Seed Script

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
source venv/bin/activate
python scripts/seed_vulnerability_patterns.py
```

Verify in database:

```sql
SELECT tool_name, detector_id, pattern_code
FROM pattern_tool_mappings
WHERE tool_name = '<scanner-id>'
ORDER BY pattern_code;
```

---

### Step 5: Register Scanner in API Service

#### 5.1 Edit Scanner Configuration

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
vim src/infrastructure/scanner_config/scanners.py
```

#### 5.2 Add Scanner Entry

```python
from src.infrastructure.scanner_config.types import (
    ScannerMetadata,
    ScannerType,
    ScannerLanguage,
)

SCANNERS: Dict[str, ScannerMetadata] = {
    # ... existing scanners

    "<scanner-id>": ScannerMetadata(
        id="<scanner-id>",
        name="<Scanner Name>",
        description="<Brief description shown in UI>",
        scanner_type=ScannerType.STATIC_ANALYSIS,  # or FUZZING, FORMAL_VERIFICATION, SBOM
        languages=[ScannerLanguage.SOLIDITY],  # or RUST, CAIRO, MOVE
        estimated_time_seconds=60,
        requires_compilation=False,  # True if scanner needs compiled bytecode
        is_production_ready=True,
        confidence_level="high",  # high, medium, low
        # version and developer loaded from ConfigMap automatically
    ),
}
```

**IMPORTANT:** DO NOT hardcode `version` or `developer` fields. These are loaded from the ConfigMap automatically.

---

### Step 6: Build and Deploy

#### 6.1 Build Docker Images

```bash
# Build scanner image (tag with both version and latest)
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/<scanner-name>
eval $(minikube docker-env)
docker build -t scanner-<scanner-name>:<MAJOR.MINOR.PATCH> -t scanner-<scanner-name>:latest .

# Build orchestration service (tag with both version and latest)
cd /Users/pwner/Git/ABS/blocksecops-orchestration
eval $(minikube docker-env)
docker build -t blocksecops-orchestration:0.7.<N+1> -t blocksecops-orchestration:latest .

# Build API service (tag with both version and latest)
cd /Users/pwner/Git/ABS/blocksecops-api-service
eval $(minikube docker-env)
docker build -t api-service:0.3.<N+1> -t api-service:latest .
```

**Note**: Local development kustomizations use `newTag: latest`, so tagging versioned images as `latest` ensures they're picked up automatically without manual kustomization updates. See `/Users/pwner/Git/ABS/docs/standards/docker-image-versioning.md` for details.

#### 6.2 Deploy to Kubernetes

```bash
# Restart deployments to pick up new images
kubectl rollout restart deployment/orchestration -n orchestration-local
kubectl rollout restart deployment/api-service -n api-service-local

# Verify deployments
kubectl rollout status deployment/orchestration -n orchestration-local
kubectl rollout status deployment/api-service -n api-service-local
```

---

## Verification & Testing

### Test 1: Verify Scanner Appears in API

```bash
curl http://localhost:8000/api/v1/scanners | jq '.scanners[] | select(.id=="<scanner-id>")'
```

Expected output:
```json
{
  "id": "<scanner-id>",
  "name": "<Scanner Name>",
  "description": "...",
  "version": "<MAJOR.MINOR.PATCH>",
  "developer": "<Organization>",
  "scanner_type": "static_analysis",
  "languages": ["solidity"],
  "estimated_time_seconds": 60,
  "is_production_ready": true,
  "confidence_level": "high"
}
```

### Test 2: Run Test Scan

```bash
# Trigger scan via API
curl -X POST http://localhost:8000/api/v1/scans \
  -H "Content-Type: application/json" \
  -d '{
    "contract_id": "<test-contract-id>",
    "scanners": ["<scanner-id>"],
    "project_id": "test-project"
  }'

# Note scan_id from response
SCAN_ID="<scan_id>"

# Wait for completion
curl http://localhost:8000/api/v1/scans/$SCAN_ID
```

### Test 3: Verify Findings in Database

```sql
-- Check findings were stored
SELECT
    id,
    scanner_id,
    detector_id,
    title,
    severity,
    file_path,
    line_number
FROM vulnerabilities
WHERE scan_id = '<scan_id>'
LIMIT 10;
```

### Test 4: Verify Pattern Codes (Vulnerability Scanners Only)

```sql
-- Check pattern codes assigned
SELECT
    detector_id,
    pattern_code,
    classification_confidence,
    classification_method
FROM vulnerabilities
WHERE scan_id = '<scan_id>'
  AND scanner_id = '<scanner-id>';
```

All rows should have:
- `pattern_code` NOT NULL (e.g., "BVD-EVM-REE-001")
- `classification_confidence` = 0.9
- `classification_method` = "rule_based"

### Test 5: Check Orchestration Logs

```bash
kubectl logs -n orchestration-local deployment/orchestration --tail=200 | grep "<scanner-id>"
```

Look for:
- ✅ Scanner job created
- ✅ Scanner completed successfully
- ✅ Findings parsed
- ✅ Enrichment applied
- ❌ No error messages

---

## Documentation Requirements

### Update CHANGELOG

```markdown
# CHANGELOG - <Service Name>

## [<MAJOR.MINOR.PATCH>] - YYYY-MM-DD

### Added
- Integrated <Scanner Name> v<version> security scanner
- Added <Scanner Name> parser with support for <N> detector types
- Added pattern mappings for <N> vulnerability patterns

### Technical Details
- Docker image: scanner-<scanner-name>:<version>
- Parser: src/parsers/<scanner_name>_parser.py
- Pattern mappings: seeds/<scanner>_pattern_mappings.json
- ConfigMap: k8s/base/scanner-versions-configmap.yaml

### Testing
- ✅ Unit tests passing
- ✅ Integration test with sample contract
- ✅ Pattern matching verified
- ✅ Deduplication tested with existing scanners
```

### Create Scanner-Specific Documentation (Optional)

If scanner has special configuration or requirements, create:
`/Users/pwner/Git/ABS/blocksecops-docs/scanners/<SCANNER-NAME>-INTEGRATION.md`

---

## Troubleshooting

### Issue: Scanner registered in API but not in tool-integration

**⚠️ CRITICAL ISSUE:** Scanner can be registered in API service but silently fail if not added to tool-integration's `valid_scanners` list.

**Symptoms:**
- ✅ Scanner appears in API: `GET /api/v1/scanners`
- ✅ Scanner appears in dashboard preset selector
- ✅ API sends trigger request to tool-integration
- ✅ Tool-integration returns `200 OK`
- ❌ But response body contains `{"success": false, "error": "Invalid scanner: X"}`
- ❌ NO Kubernetes job is created
- ❌ NO error logged at INFO level (silent failure)
- ❌ API doesn't check response body `success` field

**Root Cause:**
Tool-integration has hardcoded `valid_scanners` list in `src/main.py` (around line 122):

```python
valid_scanners = ["slither", "mythril", "aderyn"]
```

When API triggers scanners not in this list, tool-integration:
1. Returns HTTP 200 OK (not 400/404)
2. Includes `{"success": false}` in response body
3. Does NOT log rejection at INFO level
4. API's `response.raise_for_status()` doesn't catch this (only checks HTTP status code)

**How to Fix:**

1. **Update tool-integration `valid_scanners` list** (`/Users/pwner/Git/ABS/blocksecops-tool-integration/src/main.py:122`):
   ```python
   valid_scanners = ["slither", "mythril", "aderyn", "semgrep", "halmos", "medusa", "wake", "solhint", "echidna"]
   ```

2. **Verify scanner has Docker image and parser implemented** (required for each scanner in list)

3. **Add response body validation to API service** (`/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py`):
   ```python
   response = await client.post(...)
   response.raise_for_status()
   result = response.json()

   # NEW: Check success field
   if not result.get("success", True):
       raise HTTPException(
           status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
           detail=f"Scanner trigger failed: {result.get('error', 'Unknown error')}"
       )
   ```

4. **Add ERROR-level logging to tool-integration** for invalid scanners

**Prevention:**
- When adding scanner to API service (`scanners.py`), ALWAYS add to tool-integration `valid_scanners` list
- Update this guide's checklist to include tool-integration registration
- Consider replacing hardcoded list with database-driven scanner registry

**Verification Commands:**
```bash
# Check API registered scanners
curl 'http://127.0.0.1:8000/api/v1/scanners?language=solidity' | jq -r '.scanners[].id'

# Check tool-integration valid scanners
grep "valid_scanners = " /Users/pwner/Git/ABS/blocksecops-tool-integration/src/main.py

# Check for mismatches
comm -13 <(grep "valid_scanners = " /path/to/tool-integration/src/main.py | grep -oP '"\K[^"]+' | sort) \
         <(curl -s 'http://127.0.0.1:8000/api/v1/scanners?language=solidity' | jq -r '.scanners[].id' | sort)
```

---

### Issue: Scanner appears in API but scan fails

**Check orchestration logs:**
```bash
kubectl logs -n orchestration-local deployment/orchestration --tail=500 | grep -i error
```

**Common causes:**
- Docker image not loaded to Minikube
- Scanner binary not in PATH
- Invalid command-line flags
- Timeout too short for large contracts
- **Scanner not in tool-integration `valid_scanners` list** (see issue above)

### Issue: Findings not stored in database

**Check parser registration:**
```bash
# Verify parser is registered
grep "<scanner-id>" /Users/pwner/Git/ABS/blocksecops-orchestration/src/parsers/__init__.py
```

**Check parser output:**
- Enable debug logging in parser
- Print parsed findings before database insert
- Verify ParsedFinding objects have all required fields

### Issue: Pattern codes not assigned

**Verify pattern mappings seeded:**
```sql
SELECT COUNT(*) FROM pattern_tool_mappings WHERE tool_name = '<scanner-id>';
```

**If count is 0:**
- Re-run seed script
- Check seed file JSON is valid
- Verify scanner_id matches everywhere

### Issue: Docker image build fails

**Common fixes:**
- Update base image version
- Install missing system dependencies
- Check internet connectivity for downloads
- Verify scanner release URL is correct

---

## Related Documentation

- **[Scanner Intelligence Layer Integration Guide](SCANNER-INTELLIGENCE-INTEGRATION.md)** - Automatic enrichment, fingerprinting, and deduplication ⭐
- [Platform Development Standards](/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md)
- [Scanner Removal Guide](/Users/pwner/Git/ABS/blocksecops-docs/SCANNER-REMOVAL-GUIDE.md)
- [Scanner Update Guide](/Users/pwner/Git/ABS/blocksecops-docs/SCANNER-UPDATE-GUIDE.md)
- [Phase 4D Pattern Matching](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/03-phase-4-intelligence/PHASE-4D-NEXT-STEPS.md)
- [Phase 4E Deduplication](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/implementation-summaries/PHASE-4E-DEDUPLICATION-COMPLETE.md)

---

**Document Owner:** Engineering Team
**Last Updated:** October 27, 2025
**Next Review:** Quarterly or when platform architecture changes
