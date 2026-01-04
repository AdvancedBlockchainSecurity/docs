# Scanner Update Guide

**Version:** 1.1
**Last Updated:** December 4, 2025
**Purpose:** Guide for updating third-party security scanners and SBOM generators in the BlockSecOps platform

---

## Table of Contents

1. [Overview](#overview)
2. [Critical Concepts](#critical-concepts)
3. [Update Complexity Matrix](#update-complexity-matrix)
4. [Standard Update Workflow](#standard-update-workflow)
5. [Parser vs Pattern Mapping](#parser-vs-pattern-mapping)
6. [When Parser Updates Are Needed](#when-parser-updates-are-needed)
7. [Pattern Mapping Process](#pattern-mapping-process)
8. [Automated Tools](#automated-tools)
9. [Testing Strategy](#testing-strategy)
10. [Scanner-Specific Guidance](#scanner-specific-guidance)
11. [Troubleshooting](#troubleshooting)

---

## Overview

This guide covers the process for updating security scanners (Slither, Mythril, SolidityDefend, etc.) and SBOM generators (SolidityBOM) in the BlockSecOps platform.

### Platform Architecture for Scanner Updates

The platform is designed to make scanner updates as painless as possible:

- **Centralized Version Management**: Single source of truth via ConfigMap
- **Modular Components**: Isolated parsers, pattern mappings, and Docker images
- **Semantic Versioning**: Clear version tracking for all scanner images
- **Git-Tracked Configuration**: Auditable update history

### Key Files for Scanner Updates

```
blocksecops-tool-integration/
└── k8s/base/scanner-versions-configmap.yaml    # Version metadata

blocksecops-orchestration/
├── scanners/
│   ├── soliditydefend/
│   │   ├── Dockerfile                          # Scanner container
│   │   └── build.sh                            # Build script
│   └── soliditybom/
│       ├── Dockerfile
│       └── build.sh
└── src/blocksecops_orchestration/
    ├── parsers/
    │   ├── soliditydefend_parser.py            # JSON → VulnerabilityFinding
    │   └── soliditybom_parser.py               # JSON → SBOMReport
    └── intelligence/patterns/
        └── soliditydefend_patterns.py          # Detector ID → Pattern Code
```

---

## Critical Concepts

### Parser vs Pattern Mapping

This is the most important distinction to understand:

| Component | Purpose | When to Update |
|-----------|---------|----------------|
| **Parser** | Converts scanner JSON output to platform objects (`VulnerabilityFinding`, `SBOMReport`) | When output **format** changes |
| **Pattern Mapping** | Maps detector IDs to pattern codes for deduplication | When **new detectors** are added |

**Key Insight**: Adding new detectors does NOT require parser changes if the output structure stays the same.

### Scanner Types

| Type | Examples | Update Frequency | Complexity |
|------|----------|------------------|------------|
| **Vulnerability Scanners** | SolidityDefend, Slither, Mythril | High (new detectors) | Medium |
| **SBOM Generators** | SolidityBOM | Low (stable schema) | Low |
| **Linters** | Solhint, Semgrep | Medium | Low |
| **Fuzzers** | Echidna, Medusa | Low | Medium |

---

## Update Complexity Matrix

### Vulnerability Scanners (e.g., SolidityDefend, Slither)

| Change Type | Frequency | Complexity | Parser Update? | Pattern Mapping Update? |
|------------|-----------|-----------|----------------|------------------------|
| Bug fixes only | Common | 🟢 Easy | ❌ No | ❌ No |
| New detectors (same output format) | Common | 🟡 Medium | ❌ No | ✅ **Yes** |
| New optional fields | Occasional | 🟡 Medium | ⚠️ Optional | ❌ No |
| Output format changes | Rare | 🟠 Moderate | ✅ **Yes** | ❌ No |
| Breaking API changes | Very Rare | 🔴 Complex | ✅ **Yes** | ✅ **Yes** |

### SBOM Generators (e.g., SolidityBOM)

| Change Type | Frequency | Complexity | Parser Update? |
|------------|-----------|-----------|----------------|
| Bug fixes | Common | 🟢 Easy | ❌ No |
| Better dependency detection | Common | 🟢 Easy | ❌ No |
| CycloneDX spec update | Rare (1-2 years) | 🟡 Medium | ⚠️ Optional |
| SPDX format changes | Rare | 🟡 Medium | ⚠️ Only if using SPDX |

---

## Standard Update Workflow

### Pre-Update Phase

```bash
# 1. Check release notes for breaking changes
cd /Users/pwner/Git/ABS/SolidityDefend  # Or other scanner repo
git fetch origin
git log v0.7.0..v0.8.0 --oneline

# Look for:
# - "BREAKING CHANGE" markers
# - Output format modifications
# - New detectors
# - Schema changes

# 2. Review changelog
cat CHANGELOG.md

# 3. Check output format changes
git diff v0.7.0..v0.8.0 -- src/output/ src/formatters/
```

### Update Execution

Following the **Codebase-First Development** standard from `PLATFORM-DEVELOPMENT-STANDARDS.md`:

```bash
# 1. Create feature branch
cd /Users/pwner/Git/ABS
git checkout main
git pull
git checkout -b update-soliditydefend-0.8.0

# 2. Update scanner source code (if you maintain it)
cd /Users/pwner/Git/ABS/SolidityDefend
git pull origin main

# 3. Rebuild Docker image
cd /Users/pwner/Git/ABS/blocksecops-orchestration/scanners/soliditydefend
vim Dockerfile  # Update if needed

# Build with new version tag
docker build -t scanner-soliditydefend:0.8.0 .
docker tag scanner-soliditydefend:0.8.0 scanner-soliditydefend:latest

# 4. Load into Minikube
minikube image load scanner-soliditydefend:0.8.0

# 5. Update ConfigMap (single source of truth)
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
vim k8s/base/scanner-versions-configmap.yaml

# Update version in SCANNER_METADATA:
#   "soliditydefend": {
#     "version": "0.8.0",  # Changed from 0.7.0-beta
#     "developer": "Advanced Blockchain Security",
#     "_note": "Updated 2025-10-25"
#   }

# 6. Update scanner configuration
cd /Users/pwner/Git/ABS/blocksecops-orchestration
vim src/blocksecops_orchestration/config/scanners.yaml

# Update docker_image version:
#   "docker_image": "scanner-soliditydefend:0.8.0"

# 7. (IF NEEDED) Update parser for new output format
vim src/blocksecops_orchestration/parsers/soliditydefend_parser.py

# 8. (IF NEEDED) Add new detector pattern mappings
vim src/blocksecops_orchestration/intelligence/patterns/soliditydefend_patterns.py

# 9. Add test fixtures
mkdir -p tests/fixtures/soliditydefend
# Copy sample output from new version
cp ~/sample_output.json tests/fixtures/soliditydefend/v0.8.0_output.json

# 10. Commit changes (MANDATORY before applying)
git add .
git commit -m "Update SolidityDefend from 0.7.0-beta to 0.8.0

- Updated Docker image version to 0.8.0
- Updated ConfigMap metadata
- Updated scanner configuration
- Added 10 new detector pattern mappings:
  - erc4337-signature-replay → ERC-004
  - cross-chain-replay → CRO-001
  - zkp-verification-bypass → ZKP-001
  - (list all new mappings)

Breaking Changes: None (backward compatible)

Refs: #UPDATE-TICKET"

# 11. Push and create PR (user account only)
git push origin update-soliditydefend-0.8.0
# Create PR via GitHub UI, request review

# 12. After PR merge: Apply ConfigMap changes
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-tool-integration/k8s/overlays/local

# 13. Restart orchestration service to pick up new image
kubectl rollout restart deployment/orchestration-worker -n orchestration-local
kubectl rollout status deployment/orchestration-worker -n orchestration-local

# 14. Verify new version is active
kubectl logs -n orchestration-local -l app.kubernetes.io/name=orchestration --tail=50 | grep soliditydefend

# 15. Test with a scan
# Upload test contract and trigger scan via API
curl -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Content-Type: application/json" \
  -d '{"contract_id": "test-uuid", "scanners": ["soliditydefend"]}'

# 16. Verify results
# Check that findings are parsed correctly and new detectors appear
```

---

## Parser vs Pattern Mapping

### Parser Updates (Rare)

**Purpose**: Convert scanner output format to platform data structures.

**Example - SolidityDefend Parser**:

```python
# soliditydefend_parser.py
# This code stays the SAME when new detectors are added

def parse(self, output_path: str, contract_id: str, scan_id: str) -> List[VulnerabilityFinding]:
    """
    Parse SolidityDefend JSON output.

    This parser works for v0.7.0, v0.8.0, v0.9.0... as long as
    the JSON structure remains the same.
    """
    findings = []

    with open(output_path, 'r') as f:
        data = json.load(f)

    raw_findings = data.get("findings", [])

    for finding in raw_findings:
        vuln = VulnerabilityFinding(
            scanner_id="soliditydefend",
            scanner_version="0.8.0",
            contract_id=contract_id,
            scan_id=scan_id,

            # These fields extract from JSON - structure stays same
            title=finding.get("title", "Unknown Issue"),
            description=finding.get("description", ""),
            severity=self._map_severity(finding.get("severity", "info")),

            # New detector IDs automatically extracted
            detector_id=finding.get("detector_id"),  # ← Works for new detectors!

            file_path=finding.get("location", {}).get("file"),
            line_number=finding.get("location", {}).get("line"),
            remediation=finding.get("suggestion"),
        )

        findings.append(vuln)

    return findings
```

**Key Point**: The parser doesn't care what the detector ID is - it just extracts it. New detectors like `"erc4337-signature-replay"` work automatically.

### Pattern Mapping Updates (Common)

**Purpose**: Map detector IDs to pattern codes for cross-scanner deduplication.

**Example - SolidityDefend Pattern Mapping**:

```python
# soliditydefend_patterns.py
# This NEEDS updates when new detectors are added

SOLIDITYDEFEND_PATTERN_MAPPING = {
    # Existing detectors (v0.7.0)
    "reentrancy-eth": "REE-001",
    "reentrancy-benign": "REE-002",
    "oracle-manipulation": "DEF-001",
    "flash-loan-attack": "DEF-002",

    # NEW DETECTORS (v0.8.0) - MUST ADD THESE
    "erc4337-signature-replay": "ERC-004",
    "cross-chain-replay": "CRO-001",
    "zkp-verification-bypass": "ZKP-001",
    "account-abstraction-nonce": "ERC-005",
    "bundler-dos": "DOS-001",

    # Default for unmapped detectors
    "unknown": "GEN-999"
}

def get_pattern_code(detector_id: str) -> str:
    """Get pattern code for SolidityDefend detector ID."""
    return SOLIDITYDEFEND_PATTERN_MAPPING.get(detector_id, "GEN-999")
```

**Why Pattern Codes Matter**: Allows deduplication across scanners.

Example:
- SolidityDefend detector: `"reentrancy-eth"` → Pattern: `"REE-001"`
- Slither detector: `"reentrancy-vulnerable-to-ether-theft"` → Pattern: `"REE-001"`
- Platform knows these are the **same issue** from different scanners

---

## When Parser Updates Are Needed

### Scenario 1: Output Format Changes (BREAKING)

**Example**: Scanner changes field structure

```json
// OLD FORMAT (v0.7.0)
{
  "findings": [
    {
      "severity": "high",  // ← String value
      "detector_id": "reentrancy-eth"
    }
  ]
}

// NEW FORMAT (v0.8.0) - BREAKING CHANGE
{
  "findings": [
    {
      "severity": {        // ← Now an object!
        "level": "high",
        "confidence": 0.95,
        "justification": "Direct ether transfer after external call"
      },
      "detector_id": "reentrancy-eth"
    }
  ]
}
```

**Required Parser Update**:

```python
def _map_severity(self, severity_data: Any) -> str:
    """
    Map SolidityDefend severity to platform standard.

    Handles both old format (string) and new format (object).
    """
    # New format (v0.8.0+): severity is an object
    if isinstance(severity_data, dict):
        level = severity_data.get("level", "info")
        # Optionally extract confidence for future use
        confidence = severity_data.get("confidence")
        return self.SEVERITY_MAPPING.get(level.lower(), "informational")

    # Old format (v0.7.0): severity is a string
    elif isinstance(severity_data, str):
        return self.SEVERITY_MAPPING.get(severity_data.lower(), "informational")

    # Fallback
    return "informational"
```

### Scenario 2: New Required Fields

**Example**: Scanner adds new mandatory field

```python
# Parser update to handle new field
vuln = VulnerabilityFinding(
    detector_id=finding.get("detector_id"),
    severity=self._map_severity(finding.get("severity")),

    # NEW FIELD (v0.8.0)
    cwe_id=finding.get("cwe_id"),  # Common Weakness Enumeration ID

    # NEW FIELD (v0.8.0)
    owasp_category=finding.get("owasp_category"),  # OWASP Top 10 mapping
)
```

### Scenario 3: Location Structure Changes

```python
# OLD: Simple location object
location = finding.get("location", {})
file_path = location.get("file")
line_number = location.get("line")

# NEW: Multiple locations (e.g., for cross-function vulnerabilities)
locations = finding.get("locations", [])
if locations:
    primary_location = locations[0]  # Take first as primary
    file_path = primary_location.get("file")
    line_number = primary_location.get("line")

    # Store secondary locations for reference
    secondary_locations = [
        {"file": loc.get("file"), "line": loc.get("line")}
        for loc in locations[1:]
    ]
```

### Scenario 4: Severity Mapping Changes

**Example**: Scanner adds new severity levels

```python
# OLD MAPPING
SEVERITY_MAPPING = {
    "high": "high",
    "medium": "medium",
    "low": "low",
    "info": "informational"
}

# NEW MAPPING (v0.8.0 adds "critical")
SEVERITY_MAPPING = {
    "critical": "critical",  # NEW severity level
    "high": "high",
    "medium": "medium",
    "low": "low",
    "info": "informational"
}
```

---

## Pattern Mapping Process

### Step 1: Identify New Detectors

```bash
# Run scanner on test contract with old and new versions
docker run scanner-soliditydefend:0.7.0 test.sol > v0.7.0_output.json
docker run scanner-soliditydefend:0.8.0 test.sol > v0.8.0_output.json

# Extract detector IDs from outputs
jq '.findings[].detector_id' v0.7.0_output.json | sort -u > v0.7.0_detectors.txt
jq '.findings[].detector_id' v0.8.0_output.json | sort -u > v0.8.0_detectors.txt

# Find new detectors
comm -13 v0.7.0_detectors.txt v0.8.0_detectors.txt
# Output:
# "account-abstraction-nonce"
# "bundler-dos"
# "cross-chain-replay"
# "erc4337-signature-replay"
# "zkp-verification-bypass"
```

### Step 2: Assign Pattern Codes

**Pattern Code Format**: `CATEGORY-NUMBER`

Common categories:
- `REE-XXX`: Reentrancy
- `ACC-XXX`: Access Control
- `ARI-XXX`: Arithmetic
- `DEF-XXX`: DeFi
- `MEV-XXX`: MEV/Front-running
- `ERC-XXX`: ERC Standard violations
- `CRO-XXX`: Cross-chain
- `ZKP-XXX`: Zero-knowledge proofs
- `DOS-XXX`: Denial of Service
- `GAS-XXX`: Gas optimization
- `GEN-XXX`: General/Uncategorized

**Assigning Process**:

```python
# New detector: "erc4337-signature-replay"
# 1. Identify category: ERC standard violation → ERC-XXX
# 2. Check existing ERC codes:
#    ERC-001: erc20-approve-race
#    ERC-002: erc721-unsafe-mint
#    ERC-003: erc4626-inflation-attack
# 3. Assign next number: ERC-004

"erc4337-signature-replay": "ERC-004"
```

### Step 3: Update Pattern Mapping File

```python
# soliditydefend_patterns.py

SOLIDITYDEFEND_PATTERN_MAPPING = {
    # ... existing mappings ...

    # ============================================================
    # NEW DETECTORS (v0.8.0) - Added 2025-10-25
    # ============================================================

    # ERC-4337 Account Abstraction
    "erc4337-signature-replay": "ERC-004",
    "account-abstraction-nonce": "ERC-005",
    "bundler-dos": "DOS-001",

    # Cross-chain Security
    "cross-chain-replay": "CRO-001",
    "cross-chain-message-validation": "CRO-002",

    # Zero-Knowledge Proofs
    "zkp-verification-bypass": "ZKP-001",
    "zkp-proof-malleability": "ZKP-002",

    # ... rest of mappings ...

    # Default
    "unknown": "GEN-999"
}
```

### Step 4: Document Pattern Assignments

Create a reference document:

```markdown
# Pattern Code Registry

## ERC Standards (ERC-XXX)

| Code | Detector ID | Scanner | Description | Added |
|------|-------------|---------|-------------|-------|
| ERC-001 | erc20-approve-race | slither, soliditydefend | ERC20 approve race condition | v0.1.0 |
| ERC-002 | erc721-unsafe-mint | soliditydefend | ERC721 unsafe minting | v0.3.0 |
| ERC-003 | erc4626-inflation-attack | soliditydefend | ERC4626 share inflation | v0.5.0 |
| ERC-004 | erc4337-signature-replay | soliditydefend | ERC4337 signature replay | v0.8.0 |
| ERC-005 | account-abstraction-nonce | soliditydefend | AA nonce mismanagement | v0.8.0 |

## Cross-Chain (CRO-XXX)

| Code | Detector ID | Scanner | Description | Added |
|------|-------------|---------|-------------|-------|
| CRO-001 | cross-chain-replay | soliditydefend | Cross-chain replay attack | v0.8.0 |
| CRO-002 | cross-chain-message-validation | soliditydefend | Invalid message validation | v0.8.0 |
```

---

## Automated Tools

### Pattern Mapping Generator Script

Save as: `scripts/generate_pattern_mappings.py`

```python
#!/usr/bin/env python3
"""
Generate pattern mapping template for new scanner detectors.

Usage:
  python scripts/generate_pattern_mappings.py \\
    --scanner soliditydefend \\
    --old-output tests/fixtures/soliditydefend/v0.7.0_output.json \\
    --new-output tests/fixtures/soliditydefend/v0.8.0_output.json
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Set
import re

def extract_detector_ids(output_file: Path) -> Set[str]:
    """Extract all detector IDs from scanner output."""
    with open(output_file) as f:
        data = json.load(f)

    findings = data.get("findings", [])
    return {f.get("detector_id") for f in findings if f.get("detector_id")}

def find_new_detectors(old_ids: Set[str], new_ids: Set[str]) -> List[str]:
    """Find detectors that exist in new version but not old."""
    return sorted(new_ids - old_ids)

def categorize_detector(detector_id: str) -> str:
    """Categorize detector based on ID pattern."""
    categories = {
        r"^reentrancy": "REE",
        r"^access|^unprotected|^missing-access": "ACC",
        r"^integer|^overflow|^underflow|^division": "ARI",
        r"^oracle|^flash-loan|^slippage|^price": "DEF",
        r"^front-running|^sandwich|^mev": "MEV",
        r"^erc\d+|^eip\d+": "ERC",
        r"^cross-chain": "CRO",
        r"^zkp|^zero-knowledge": "ZKP",
        r"^dos|^denial": "DOS",
        r"^gas": "GAS",
    }

    for pattern, category in categories.items():
        if re.match(pattern, detector_id, re.IGNORECASE):
            return category

    return "GEN"

def load_existing_patterns(scanner: str) -> Dict[str, str]:
    """Load existing pattern mappings from file."""
    pattern_file = Path(f"src/blocksecops_orchestration/intelligence/patterns/{scanner}_patterns.py")

    if not pattern_file.exists():
        return {}

    # Simple regex extraction (could be improved with AST parsing)
    content = pattern_file.read_text()
    pattern_dict = {}

    # Match lines like: "detector-id": "PATTERN-123",
    pattern = r'"([^"]+)":\s*"([A-Z]{3}-\d{3})"'
    matches = re.findall(pattern, content)

    for detector_id, pattern_code in matches:
        pattern_dict[detector_id] = pattern_code

    return pattern_dict

def suggest_pattern_codes(detector_ids: List[str], existing_patterns: Dict[str, str]) -> Dict[str, str]:
    """Suggest pattern codes for new detectors."""
    suggestions = {}

    # Group existing patterns by category
    category_counts = {}
    for pattern_code in existing_patterns.values():
        category = pattern_code.split("-")[0]
        num = int(pattern_code.split("-")[1])
        category_counts[category] = max(category_counts.get(category, 0), num)

    for detector_id in detector_ids:
        category = categorize_detector(detector_id)
        next_num = category_counts.get(category, 0) + 1
        category_counts[category] = next_num

        suggestions[detector_id] = f"{category}-{next_num:03d}"

    return suggestions

def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate pattern mapping suggestions for new scanner detectors"
    )
    parser.add_argument("--scanner", required=True, help="Scanner name (e.g., soliditydefend)")
    parser.add_argument("--old-output", required=True, type=Path, help="Old version output JSON")
    parser.add_argument("--new-output", required=True, type=Path, help="New version output JSON")

    args = parser.parse_args()

    # Extract detector IDs
    print(f"📖 Reading scanner outputs...")
    old_ids = extract_detector_ids(args.old_output)
    new_ids = extract_detector_ids(args.new_output)

    print(f"   Old version: {len(old_ids)} detectors")
    print(f"   New version: {len(new_ids)} detectors")

    # Find new detectors
    new_detectors = find_new_detectors(old_ids, new_ids)

    if not new_detectors:
        print("✅ No new detectors found!")
        return 0

    print(f"\n🔍 Found {len(new_detectors)} new detectors:")
    for detector in new_detectors:
        print(f"   - {detector}")

    # Load existing patterns
    print(f"\n📋 Loading existing pattern mappings...")
    existing_patterns = load_existing_patterns(args.scanner)
    print(f"   Found {len(existing_patterns)} existing patterns")

    # Suggest pattern codes
    suggestions = suggest_pattern_codes(new_detectors, existing_patterns)

    # Output suggestions
    print(f"\n✨ Suggested pattern mappings:")
    print(f"\nAdd these to {args.scanner}_patterns.py:\n")

    # Group by category
    by_category = {}
    for detector_id, pattern_code in suggestions.items():
        category = pattern_code.split("-")[0]
        by_category.setdefault(category, []).append((detector_id, pattern_code))

    for category, mappings in sorted(by_category.items()):
        print(f"    # {category} Category")
        for detector_id, pattern_code in sorted(mappings):
            print(f'    "{detector_id}": "{pattern_code}",  # NEW v0.X.0')
        print()

    return 0

if __name__ == "__main__":
    sys.exit(main())
```

**Make it executable**:

```bash
chmod +x scripts/generate_pattern_mappings.py
```

**Usage Example**:

```bash
python scripts/generate_pattern_mappings.py \
  --scanner soliditydefend \
  --old-output tests/fixtures/soliditydefend/v0.7.0_output.json \
  --new-output tests/fixtures/soliditydefend/v0.8.0_output.json

# Output:
# 📖 Reading scanner outputs...
#    Old version: 100 detectors
#    New version: 110 detectors
#
# 🔍 Found 10 new detectors:
#    - account-abstraction-nonce
#    - bundler-dos
#    - cross-chain-replay
#    - erc4337-signature-replay
#    - zkp-verification-bypass
#    ...
#
# 📋 Loading existing pattern mappings...
#    Found 100 existing patterns
#
# ✨ Suggested pattern mappings:
#
# Add these to soliditydefend_patterns.py:
#
#     # CRO Category
#     "cross-chain-replay": "CRO-001",  # NEW v0.8.0
#
#     # DOS Category
#     "bundler-dos": "DOS-001",  # NEW v0.8.0
#
#     # ERC Category
#     "account-abstraction-nonce": "ERC-005",  # NEW v0.8.0
#     "erc4337-signature-replay": "ERC-004",  # NEW v0.8.0
#
#     # ZKP Category
#     "zkp-verification-bypass": "ZKP-001",  # NEW v0.8.0
```

---

## Testing Strategy

### Test Fixture Organization

```
tests/fixtures/
├── soliditydefend/
│   ├── v0.7.0-beta_output.json        # Baseline
│   ├── v0.8.0_output.json             # New version
│   └── v0.9.0_output.json             # Future
├── soliditybom/
│   ├── v1.0.0_output.json
│   └── v1.1.0_output.json
├── slither/
│   ├── v0.10.4_output.json
│   └── v0.11.0_output.json
└── mythril/
    ├── v0.24.7_output.json
    └── v0.24.8_output.json
```

### Parser Backward Compatibility Tests

```python
# tests/parsers/test_soliditydefend_parser.py

import pytest
from blocksecops_orchestration.parsers.soliditydefend_parser import SolidityDefendParser

@pytest.fixture
def parser():
    return SolidityDefendParser()

def test_parser_v0_7_0_output(parser):
    """Verify parser works with v0.7.0-beta output."""
    output_file = "tests/fixtures/soliditydefend/v0.7.0-beta_output.json"
    contract_id = "test-contract-uuid"
    scan_id = "test-scan-uuid"

    findings = parser.parse(output_file, contract_id, scan_id)

    # Basic assertions
    assert len(findings) > 0
    assert all(f.scanner_id == "soliditydefend" for f in findings)
    assert all(f.detector_id is not None for f in findings)
    assert all(f.severity in ["critical", "high", "medium", "low", "informational"] for f in findings)

def test_parser_v0_8_0_output(parser):
    """Verify parser works with v0.8.0 output (backward compatible)."""
    output_file = "tests/fixtures/soliditydefend/v0.8.0_output.json"
    contract_id = "test-contract-uuid"
    scan_id = "test-scan-uuid"

    findings = parser.parse(output_file, contract_id, scan_id)

    # Basic assertions
    assert len(findings) > 0

    # Check that new detectors are parsed
    detector_ids = {f.detector_id for f in findings}

    # Expect at least one new detector from v0.8.0
    new_detectors = {
        "erc4337-signature-replay",
        "cross-chain-replay",
        "zkp-verification-bypass"
    }

    # At least one new detector should be present
    assert len(detector_ids & new_detectors) > 0, \
        f"Expected new detectors, found: {detector_ids}"

def test_parser_handles_missing_optional_fields(parser):
    """Verify parser handles missing optional fields gracefully."""
    # Create minimal output with only required fields
    minimal_output = {
        "findings": [
            {
                "detector_id": "test-detector",
                "severity": "high",
                "title": "Test Finding",
                # Missing: description, location, suggestion, etc.
            }
        ]
    }

    import json
    import tempfile

    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(minimal_output, f)
        temp_path = f.name

    findings = parser.parse(temp_path, "test-uuid", "scan-uuid")

    assert len(findings) == 1
    assert findings[0].detector_id == "test-detector"
    assert findings[0].severity == "high"

def test_severity_mapping(parser):
    """Verify severity levels are mapped correctly."""
    test_cases = [
        ("critical", "critical"),
        ("high", "high"),
        ("medium", "medium"),
        ("low", "low"),
        ("info", "informational"),
        ("informational", "informational"),
        ("unknown", "informational"),  # Default
    ]

    for input_severity, expected_output in test_cases:
        result = parser._map_severity(input_severity)
        assert result == expected_output, \
            f"Severity '{input_severity}' mapped to '{result}', expected '{expected_output}'"
```

### Pattern Mapping Tests

```python
# tests/intelligence/test_soliditydefend_patterns.py

import pytest
from blocksecops_orchestration.intelligence.patterns.soliditydefend_patterns import (
    SOLIDITYDEFEND_PATTERN_MAPPING,
    get_pattern_code
)

def test_all_known_detectors_have_patterns():
    """Verify all known detectors have pattern mappings."""
    # This test should be updated when new detectors are added
    known_detectors = [
        "reentrancy-eth",
        "oracle-manipulation",
        "erc4337-signature-replay",  # v0.8.0
        "cross-chain-replay",        # v0.8.0
        # ... add more as they're released
    ]

    for detector in known_detectors:
        pattern = get_pattern_code(detector)
        assert pattern != "GEN-999", \
            f"Detector '{detector}' has no pattern mapping (got default GEN-999)"

def test_pattern_codes_follow_format():
    """Verify all pattern codes follow CATEGORY-NNN format."""
    pattern_format = re.compile(r'^[A-Z]{3}-\d{3}$')

    for detector_id, pattern_code in SOLIDITYDEFEND_PATTERN_MAPPING.items():
        if detector_id == "unknown":
            continue  # Skip the default

        assert pattern_format.match(pattern_code), \
            f"Pattern code '{pattern_code}' for detector '{detector_id}' " \
            f"doesn't match format CATEGORY-NNN"

def test_no_duplicate_pattern_codes():
    """Verify no two detectors map to the same pattern code."""
    seen_patterns = {}

    for detector_id, pattern_code in SOLIDITYDEFEND_PATTERN_MAPPING.items():
        if detector_id == "unknown":
            continue

        if pattern_code in seen_patterns:
            pytest.fail(
                f"Duplicate pattern code '{pattern_code}' found:\n"
                f"  - Detector 1: {seen_patterns[pattern_code]}\n"
                f"  - Detector 2: {detector_id}"
            )

        seen_patterns[pattern_code] = detector_id

def test_unknown_detector_gets_default():
    """Verify unknown detectors get default pattern code."""
    unknown_detectors = [
        "some-future-detector",
        "not-yet-mapped",
        "brand-new-check"
    ]

    for detector in unknown_detectors:
        pattern = get_pattern_code(detector)
        assert pattern == "GEN-999", \
            f"Unknown detector '{detector}' should get GEN-999, got '{pattern}'"
```

### End-to-End Integration Tests

```python
# tests/integration/test_scanner_updates.py

import pytest
from blocksecops_orchestration.scanners.orchestrator import ScannerOrchestrator
from blocksecops_orchestration.parsers.soliditydefend_parser import SolidityDefendParser
from blocksecops_orchestration.intelligence.patterns.soliditydefend_patterns import get_pattern_code

@pytest.mark.integration
def test_new_detectors_end_to_end():
    """Test that new detectors work through the entire pipeline."""

    # 1. Run scanner (mock or actual)
    scanner_output = {
        "findings": [
            {
                "detector_id": "erc4337-signature-replay",  # NEW in v0.8.0
                "severity": "high",
                "title": "ERC-4337 Signature Replay Attack",
                "description": "Signature can be replayed across different user operations",
                "location": {
                    "file": "contracts/Wallet.sol",
                    "line": 42,
                    "function": "validateUserOp"
                },
                "suggestion": "Include nonce and chainId in signature"
            }
        ]
    }

    # 2. Parse output
    parser = SolidityDefendParser()
    # ... save scanner_output to temp file ...
    findings = parser.parse(temp_file, "contract-uuid", "scan-uuid")

    # 3. Verify parsing worked
    assert len(findings) == 1
    finding = findings[0]
    assert finding.detector_id == "erc4337-signature-replay"

    # 4. Verify pattern mapping works
    pattern_code = get_pattern_code(finding.detector_id)
    assert pattern_code == "ERC-004", \
        f"New detector should map to ERC-004, got {pattern_code}"

    # 5. Verify deduplication would work
    # (if another scanner also finds ERC-004, they should merge)
    assert pattern_code != "GEN-999", \
        "New detector should not get default pattern"
```

---

## Scanner-Specific Guidance

### SolidityDefend Updates

**Typical Update Frequency**: Quarterly (new detectors)

**Common Changes**:
- New detector additions (Medium - pattern mapping only)
- Output format changes (Rare - parser update)
- Severity level adjustments (Rare - parser update)

**Update Checklist**:
```
- [ ] Check for new detectors (pattern mapping)
- [ ] Check for output format changes (parser)
- [ ] Test on DeFi contracts (reentrancy, oracle issues)
- [ ] Test on ERC standards (token security)
- [ ] Verify performance on large contracts
```

**Known Quirks**:
- Beta versions may have unstable detector IDs
- Some detectors may be experimental (mark as low confidence)

### SolidityBOM Updates

**Typical Update Frequency**: Semi-annual (stable SBOM schema)

**Common Changes**:
- Better dependency detection (Easy - no code changes)
- Support for new package managers (Medium - parser enhancement)
- CycloneDX spec version updates (Rare - parser update)

**Update Checklist**:
```
- [ ] Check CycloneDX spec version
- [ ] Test on Foundry projects
- [ ] Test on Hardhat projects
- [ ] Verify dependency graph accuracy
- [ ] Check license detection
```

**Known Quirks**:
- Requires full project structure (not single files)
- May need Foundry/Hardhat setup in Docker image

### Slither Updates

**Typical Update Frequency**: Monthly (Trail of Bits actively maintains)

**Common Changes**:
- New detectors (frequent)
- Detector refinements to reduce false positives
- Solidity version support updates

**Update Checklist**:
```
- [ ] Review new detector list
- [ ] Check Solidity version compatibility
- [ ] Test on complex inheritance hierarchies
- [ ] Verify library detection works
```

### Mythril Updates

**Typical Update Frequency**: Quarterly

**Common Changes**:
- Symbolic execution improvements
- Timeout optimizations
- Solidity version support

**Update Checklist**:
```
- [ ] Test timeout settings (may need adjustment)
- [ ] Verify EVM version compatibility
- [ ] Check memory limits (Mythril can be resource-intensive)
```

---

## Troubleshooting

### Issue: Parser Fails After Update

**Symptoms**:
- Scanner runs successfully
- Parser throws exceptions
- No findings stored in database

**Diagnosis**:
```bash
# Check scanner output format
kubectl logs -n orchestration-local -l app.kubernetes.io/name=orchestration | grep soliditydefend

# Extract raw scanner output
kubectl exec -n orchestration-local deployment/orchestration-worker -- \
  cat /tmp/scan-results/scan-uuid/soliditydefend/results.json | jq .
```

**Solution**:
1. Compare output format to parser expectations
2. Update parser to handle new format
3. Ensure backward compatibility with old format
4. Add tests for both formats

### Issue: New Detectors Get Pattern GEN-999

**Symptoms**:
- Findings appear in database
- All new findings have pattern code `GEN-999`
- No deduplication with other scanners

**Diagnosis**:
```bash
# Check if pattern mapping exists
grep "new-detector-id" src/intelligence/patterns/soliditydefend_patterns.py
```

**Solution**:
1. Add missing pattern mappings
2. Update ConfigMap if needed
3. Restart orchestration service
4. Re-run affected scans

### Issue: Scanner Version Mismatch

**Symptoms**:
- ConfigMap shows v0.8.0
- Logs show v0.7.0
- Unexpected behavior

**Diagnosis**:
```bash
# Check running image version
kubectl describe pod -n orchestration-local -l app.kubernetes.io/name=orchestration | grep Image:

# Check ConfigMap
kubectl get configmap -n tool-integration-local scanner-versions -o yaml
```

**Solution**:
1. Verify Docker image was built with correct tag
2. Verify image was loaded into Minikube
3. Verify deployment references correct image
4. Restart pods to pick up new image

### Issue: Scanner Times Out After Update

**Symptoms**:
- Scanner job exceeds timeout
- Incomplete results
- Job marked as failed

**Diagnosis**:
```bash
# Check job timeout settings
kubectl get job -n orchestration-local soliditydefend-xxx -o yaml | grep timeout
```

**Solution**:
1. Increase timeout in scanner configuration
2. Optimize scanner settings (e.g., reduce fuzz runs)
3. Check if scanner has performance regression
4. Consider running scanner on smaller contract chunks

---

## Update Checklist Template

Copy this checklist for each scanner update:

```markdown
# Scanner Update: [Scanner Name] v[Old] → v[New]

**Date**: YYYY-MM-DD
**Scanner**: [soliditydefend, slither, etc.]
**Old Version**: [e.g., 0.7.0-beta]
**New Version**: [e.g., 0.8.0]
**Update Type**: [Bug Fix / New Detectors / Format Change / Breaking]

## Pre-Update

- [ ] Read release notes/changelog
- [ ] Identify breaking changes
- [ ] Review output format changes
- [ ] List new detectors
- [ ] Check dependencies (Solidity version, etc.)

## Code Changes

### Pattern Mapping (if new detectors)
- [ ] Extract new detector IDs from sample output
- [ ] Run pattern mapping generator script
- [ ] Assign pattern codes
- [ ] Update `*_patterns.py`
- [ ] Document pattern assignments in registry

### Parser Updates (if output format changed)
- [ ] Update parser code for new fields
- [ ] Handle backward compatibility
- [ ] Update severity mappings if needed
- [ ] Update location extraction if needed

## Testing

- [ ] Add test fixture for new version
- [ ] Test parser on old version output
- [ ] Test parser on new version output
- [ ] Verify all findings parse correctly
- [ ] Check pattern classification works
- [ ] Run end-to-end scan test
- [ ] Verify deduplication works

## Deployment

- [ ] Create feature branch
- [ ] Rebuild Docker image with new version tag
- [ ] Load image to Minikube
- [ ] Update ConfigMap version metadata
- [ ] Update scanner configuration
- [ ] Commit all changes
- [ ] Create and merge PR
- [ ] Apply ConfigMap changes
- [ ] Restart orchestration pods
- [ ] Monitor logs for errors
- [ ] Verify scans complete successfully
- [ ] Test on production-like contract

## Verification

- [ ] Version in ConfigMap matches running scanner
- [ ] New detectors appear in findings
- [ ] Pattern codes assigned correctly
- [ ] No regression in existing detectors
- [ ] Performance acceptable

## Documentation

- [ ] Update CHANGELOG
- [ ] Document breaking changes
- [ ] Update pattern registry
- [ ] Update scanner version matrix

## Rollback Plan (if needed)

- [ ] Previous Docker image available
- [ ] Previous ConfigMap backed up
- [ ] Rollback procedure documented
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.1 | 2025-12-04 | Updated scanner versions table, added latest stable versions | BlockSecOps Team |
| 1.0 | 2025-10-25 | Initial version | BlockSecOps Team |

---

## Related Documentation

- `/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md` - Development standards
- `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/implementation-summaries/SOLIDITYBOM-SOLIDITYDEFEND-INTEGRATION-PLAN.md` - Integration plan
- `/Users/pwner/Git/ABS/docs/architecture-templates/kubernetes-kustomize-structure-template.md` - K8s structure

---

**Questions or Issues?**

Contact the development team or create an issue in the `blocksecops-docs` repository.
