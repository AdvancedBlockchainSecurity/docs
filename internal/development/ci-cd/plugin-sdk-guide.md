# BlockSecOps Plugin SDK Guide

## Overview

The BlockSecOps Plugin SDK enables third-party developers to integrate custom security scanners into the platform without modifying core code. Plugins run as isolated Kubernetes Jobs with standardized interfaces, providing a secure and scalable way to extend the platform's analysis capabilities.

## Table of Contents

- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Plugin Types](#plugin-types)
- [API Reference](#api-reference)
- [Development Guide](#development-guide)
- [Testing Plugins](#testing-plugins)
- [Deployment](#deployment)
- [Best Practices](#best-practices)
- [Security Considerations](#security-considerations)
- [Examples](#examples)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   BlockSecOps Platform                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐         ┌──────────────┐            │
│  │ Core Scanners│         │Plugin Manager│            │
│  │  (Built-in)  │◄────────┤   (Discovery)│            │
│  └──────────────┘         └──────┬───────┘            │
│                                   │                     │
│                         ┌─────────▼─────────┐          │
│                         │  Plugin Registry   │          │
│                         │  - Metadata        │          │
│                         │  - Docker Images   │          │
│                         │  - Capabilities    │          │
│                         └─────────┬─────────┘          │
│                                   │                     │
│         ┌─────────────────────────┼─────────────────┐  │
│         │                         │                 │  │
│    ┌────▼────┐               ┌───▼────┐      ┌────▼──┐│
│    │ Plugin A│               │Plugin B│      │Plugin C││
│    │(Docker) │               │(Docker)│      │(Docker)││
│    └─────────┘               └────────┘      └────────┘│
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### How It Works

1. **Plugin Registration**: Plugins are registered via Kubernetes CRD manifests
2. **Discovery**: Platform discovers available plugins through the Plugin Registry
3. **Execution**: When a scan is requested, plugins run as isolated Kubernetes Jobs
4. **Result Collection**: Plugins output standardized JSON results to shared volumes
5. **Aggregation**: Platform aggregates results from all scanners (core + plugins)

## Quick Start

### Prerequisites

- Python 3.11+
- Docker
- Kubernetes cluster (local via Minikube or production)
- Basic understanding of smart contract security

### Installation

```bash
# Install the Plugin SDK
pip install blocksecops-plugin-sdk

# Or install from source
git clone https://github.com/SolidityOps/plugin-sdk
cd plugin-sdk
pip install -e .
```

### Create Your First Plugin

```python
# my_scanner.py
from blocksecops_plugin_sdk import (
    ScannerPlugin,
    ScanResult,
    Finding,
    Severity,
    Confidence,
    plugin
)

@plugin("my-custom-scanner")
class MyScanner(ScannerPlugin):
    """Example custom security scanner."""

    def __init__(self, config=None):
        super().__init__(config)
        self.name = "My Custom Scanner"
        self.version = "1.0.0"

    def scan(self, contracts):
        """Scan contracts and return findings."""
        findings = []

        for contract in contracts:
            # Your analysis logic here
            if "selfdestruct" in contract['content']:
                findings.append(Finding(
                    id=f"finding-{len(findings)+1}",
                    type="dangerous_function",
                    severity=Severity.HIGH,
                    confidence=Confidence.HIGH,
                    message="Use of selfdestruct detected",
                    file=contract['path'],
                    line=self._find_line(contract['content'], "selfdestruct"),
                    column=0,
                    code_snippet=self._extract_snippet(contract['content'], "selfdestruct"),
                    details={
                        "description": "selfdestruct can destroy contract code",
                        "recommendation": "Consider using upgradeable patterns instead"
                    }
                ))

        return ScanResult(
            tool=self.name,
            version=self.version,
            findings=findings,
            metadata={
                "total_files": len(contracts),
                "files_with_issues": len([f for f in findings]),
                "analysis_time_ms": 1000
            }
        )

    def get_metadata(self):
        """Return plugin metadata."""
        return {
            "name": self.name,
            "version": self.version,
            "author": "Your Name",
            "description": "Custom security scanner example",
            "supported_languages": ["solidity"],
            "capabilities": ["static_analysis", "pattern_matching"],
            "homepage": "https://github.com/yourname/my-scanner"
        }

    def _find_line(self, content, pattern):
        """Find line number of pattern in content."""
        for i, line in enumerate(content.split('\n'), 1):
            if pattern in line:
                return i
        return 0

    def _extract_snippet(self, content, pattern):
        """Extract code snippet around pattern."""
        for line in content.split('\n'):
            if pattern in line:
                return line.strip()
        return ""
```

### Test Locally

```python
# test_scanner.py
from my_scanner import MyScanner

# Sample contract
contracts = [
    {
        "path": "Vulnerable.sol",
        "content": """
        pragma solidity ^0.8.0;

        contract Vulnerable {
            function destroy() public {
                selfdestruct(payable(msg.sender));
            }
        }
        """
    }
]

# Run scan
scanner = MyScanner()
result = scanner.scan(contracts)

# Print results
print(result.to_json())
```

## Plugin Types

### 1. Scanner Plugins

Analyze smart contracts and return vulnerability findings.

**Use Cases**:
- Static analysis
- Pattern matching
- Symbolic execution
- Fuzzing
- Formal verification

**Interface**: Must implement `ScannerPlugin` base class

### 2. Preprocessor Plugins

Transform contracts before analysis.

**Use Cases**:
- Code formatting
- AST transformation
- Import resolution
- Optimization detection

**Interface**: Must implement `PreprocessorPlugin` base class

### 3. Postprocessor Plugins

Process scan results after analysis.

**Use Cases**:
- Report generation
- False positive filtering
- Vulnerability deduplication
- Risk scoring

**Interface**: Must implement `PostprocessorPlugin` base class

### 4. Integration Plugins

Connect to external services.

**Use Cases**:
- CI/CD integrations (GitHub Actions, GitLab CI)
- Issue trackers (Jira, GitHub Issues)
- Notification systems (Slack, Discord, Email)
- SIEM integrations

**Interface**: Must implement `IntegrationPlugin` base class

## API Reference

### Core Classes

#### `ScannerPlugin` (Abstract Base Class)

Base class for all scanner plugins.

```python
from abc import ABC, abstractmethod

class ScannerPlugin(ABC):
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        """Initialize plugin with optional configuration."""
        self.config = config or {}

    @abstractmethod
    def scan(self, contracts: List[Dict[str, str]]) -> ScanResult:
        """
        Scan contracts and return findings.

        Args:
            contracts: List of dicts with 'path' and 'content' keys

        Returns:
            ScanResult containing all findings
        """
        pass

    @abstractmethod
    def get_metadata(self) -> Dict[str, Any]:
        """
        Return plugin metadata.

        Returns:
            Dict with name, version, author, description, etc.
        """
        pass

    def validate_config(self) -> bool:
        """Validate plugin configuration. Override if needed."""
        return True

    def preprocess(self, contracts: List[Dict[str, str]]) -> List[Dict[str, str]]:
        """Preprocess contracts before scanning. Override if needed."""
        return contracts

    def postprocess(self, findings: List[Finding]) -> List[Finding]:
        """Postprocess findings after scanning. Override if needed."""
        return findings
```

#### `Finding` (Data Class)

Represents a single security finding.

```python
@dataclass
class Finding:
    id: str                      # Unique identifier
    type: str                    # Vulnerability type (e.g., "reentrancy")
    severity: Severity           # Severity level
    confidence: Confidence       # Confidence level
    message: str                 # Human-readable description
    file: str                    # File path where issue was found
    line: int                    # Line number
    column: int                  # Column number
    code_snippet: str            # Relevant code snippet
    details: Dict[str, Any]      # Additional details (description, recommendation, references)

    def to_dict(self) -> Dict[str, Any]:
        """Convert Finding to dictionary."""
        pass
```

#### `ScanResult` (Data Class)

Represents the complete scan result.

```python
@dataclass
class ScanResult:
    tool: str                    # Scanner name
    version: str                 # Scanner version
    findings: List[Finding]      # List of findings
    metadata: Dict[str, Any]     # Additional metadata (timing, statistics, etc.)

    def to_dict(self) -> Dict[str, Any]:
        """Convert ScanResult to dictionary."""
        pass

    def to_json(self) -> str:
        """Convert ScanResult to JSON string."""
        pass
```

#### `Severity` (Enum)

Finding severity levels.

```python
class Severity(Enum):
    CRITICAL = "critical"  # Immediate action required
    HIGH = "high"          # Should be fixed soon
    MEDIUM = "medium"      # Should be reviewed
    LOW = "low"            # Minor issue
    INFO = "info"          # Informational only
```

#### `Confidence` (Enum)

Finding confidence levels.

```python
class Confidence(Enum):
    HIGH = "high"      # Very likely true positive
    MEDIUM = "medium"  # May need verification
    LOW = "low"        # High false positive rate
```

### Registry Functions

#### `@plugin` Decorator

Register a plugin with the global registry.

```python
@plugin("my-scanner")
class MyScanner(ScannerPlugin):
    pass

# Plugin is now registered and discoverable
```

#### `PluginRegistry`

Manage plugin lifecycle.

```python
from blocksecops_plugin_sdk import registry

# Register plugin manually
registry.register("my-scanner", MyScanner)

# Get plugin class
plugin_class = registry.get("my-scanner")

# Create instance
instance = registry.create_instance("my-scanner", config={"key": "value"})

# List all plugins
plugins = registry.list_plugins()
```

## Development Guide

### Project Structure

```
my-scanner-plugin/
├── src/
│   └── my_scanner/
│       ├── __init__.py
│       ├── scanner.py          # Main scanner implementation
│       ├── patterns.py         # Vulnerability patterns
│       └── utils.py            # Helper functions
├── tests/
│   ├── test_scanner.py
│   ├── test_patterns.py
│   └── fixtures/
│       └── contracts/          # Test contracts
├── Dockerfile                  # Container image
├── plugin.yaml                 # Plugin manifest
├── requirements.txt
├── setup.py
└── README.md
```

### Implementing a Scanner

**Step 1**: Create scanner class

```python
# src/my_scanner/scanner.py
from blocksecops_plugin_sdk import ScannerPlugin, ScanResult, Finding, Severity, Confidence

class MyScanner(ScannerPlugin):
    def __init__(self, config=None):
        super().__init__(config)
        self.timeout = config.get("timeout", 300) if config else 300
        self.severity_threshold = config.get("severity_threshold", "medium") if config else "medium"

    def scan(self, contracts):
        """Main scanning logic."""
        findings = []

        for contract in contracts:
            # Parse contract
            ast = self._parse_contract(contract['content'])

            # Run detection rules
            for pattern in self.get_patterns():
                matches = pattern.detect(ast, contract['content'])
                findings.extend(self._create_findings(matches, contract))

        return ScanResult(
            tool=self.get_metadata()["name"],
            version=self.get_metadata()["version"],
            findings=findings,
            metadata=self._collect_metadata(contracts, findings)
        )

    def get_metadata(self):
        """Return plugin metadata."""
        return {
            "name": "My Scanner",
            "version": "1.0.0",
            "author": "Your Name",
            "description": "Custom security scanner",
            "supported_languages": ["solidity"],
            "capabilities": ["static_analysis"],
            "homepage": "https://github.com/yourname/my-scanner"
        }

    def get_patterns(self):
        """Return list of detection patterns."""
        from .patterns import PATTERNS
        return PATTERNS

    def _parse_contract(self, content):
        """Parse contract source code."""
        # Use solc, slither, or custom parser
        pass

    def _create_findings(self, matches, contract):
        """Convert pattern matches to Findings."""
        findings = []
        for match in matches:
            findings.append(Finding(
                id=f"finding-{len(findings)+1}",
                type=match['type'],
                severity=match['severity'],
                confidence=match['confidence'],
                message=match['message'],
                file=contract['path'],
                line=match['line'],
                column=match['column'],
                code_snippet=match['code'],
                details=match['details']
            ))
        return findings

    def _collect_metadata(self, contracts, findings):
        """Collect scan metadata."""
        return {
            "total_files": len(contracts),
            "files_with_issues": len(set(f.file for f in findings)),
            "lines_analyzed": sum(len(c['content'].split('\n')) for c in contracts),
            "analysis_time_ms": 1000  # Actual timing
        }
```

**Step 2**: Define detection patterns

```python
# src/my_scanner/patterns.py
from dataclasses import dataclass
from typing import List, Dict, Any
import re

@dataclass
class Pattern:
    name: str
    type: str
    severity: str
    confidence: str
    message: str
    description: str
    recommendation: str
    references: List[str]
    regex: str = None

    def detect(self, ast, source_code):
        """Detect pattern in contract."""
        matches = []

        if self.regex:
            # Regex-based detection
            for i, line in enumerate(source_code.split('\n'), 1):
                if re.search(self.regex, line):
                    matches.append({
                        'type': self.type,
                        'severity': self.severity,
                        'confidence': self.confidence,
                        'message': self.message,
                        'line': i,
                        'column': 0,
                        'code': line.strip(),
                        'details': {
                            'description': self.description,
                            'recommendation': self.recommendation,
                            'references': self.references
                        }
                    })

        return matches

# Define patterns
PATTERNS = [
    Pattern(
        name="Unchecked Call",
        type="unchecked_call",
        severity="high",
        confidence="high",
        message="Low-level call without checking return value",
        description="External calls can fail silently if return value is not checked",
        recommendation="Always check return values of low-level calls",
        references=["https://swcregistry.io/docs/SWC-104"],
        regex=r'\.(call|delegatecall|staticcall)\{.*\}\('
    ),
    Pattern(
        name="Selfdestruct",
        type="dangerous_function",
        severity="high",
        confidence="high",
        message="Use of selfdestruct detected",
        description="selfdestruct permanently destroys contract code",
        recommendation="Consider using upgradeable patterns instead",
        references=["https://docs.soliditylang.org/en/latest/security-considerations.html"],
        regex=r'\bselfdestruct\s*\('
    ),
    # Add more patterns...
]
```

**Step 3**: Create Dockerfile

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy plugin code
COPY src/ ./src/

# Install plugin
RUN pip install -e .

# Create entrypoint script
RUN cat > /app/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

CONTRACTS_DIR="${CONTRACTS_DIR:-/contracts}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
CONFIG_FILE="${CONFIG_FILE:-/config/plugin-config.json}"

echo "🔍 Starting My Scanner Plugin"
echo "Contracts: $CONTRACTS_DIR"
echo "Output: $OUTPUT_DIR"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading config from $CONFIG_FILE"
    CONFIG_ARG="--config $CONFIG_FILE"
fi

# Run scanner
python3 -m blocksecops_plugin_sdk.runner \
    src.my_scanner.scanner.MyScanner \
    --contracts-dir "$CONTRACTS_DIR" \
    --output-dir "$OUTPUT_DIR" \
    $CONFIG_ARG

echo "✅ Scan complete"
EOF

RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
```

**Step 4**: Create plugin manifest

```yaml
# plugin.yaml
apiVersion: 0xapogee.com/v1
kind: ScannerPlugin
metadata:
  name: my-custom-scanner
  version: 1.0.0
  namespace: solidity-security

spec:
  displayName: My Custom Scanner
  author: Your Name
  email: your.email@example.com
  description: |
    Custom security scanner for Solidity smart contracts.
    Detects common vulnerability patterns using static analysis.

  license: MIT
  homepage: https://github.com/yourname/my-scanner
  repository: https://github.com/yourname/my-scanner

  # Docker image
  image: your-registry/my-scanner:1.0.0
  imagePullPolicy: IfNotPresent

  # Supported languages
  languages:
    - solidity
    - vyper

  # Plugin capabilities
  capabilities:
    - static_analysis
    - pattern_matching
    - ast_analysis

  # Resource requirements
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

  # Timeout (seconds)
  timeout: 300

  # Configuration schema (JSON Schema)
  configSchema:
    type: object
    properties:
      severity_threshold:
        type: string
        enum: [critical, high, medium, low, info]
        default: medium
        description: Minimum severity level to report

      enable_experimental:
        type: boolean
        default: false
        description: Enable experimental detectors

      exclude_patterns:
        type: array
        items:
          type: string
        default: []
        description: List of patterns to exclude

      timeout:
        type: integer
        minimum: 30
        maximum: 600
        default: 300
        description: Scan timeout in seconds

  # Default configuration
  defaultConfig:
    severity_threshold: medium
    enable_experimental: false
    timeout: 300

  # Pricing (optional)
  pricing:
    tier: free  # or: premium, enterprise
    monthlyScans: 1000
    price: "$0/month"

  # Support information
  support:
    documentation: https://github.com/yourname/my-scanner/docs
    issues: https://github.com/yourname/my-scanner/issues
    email: support@example.com
```

### Building the Plugin

```bash
# Build Docker image
docker build -t your-registry/my-scanner:1.0.0 .

# Test locally
docker run --rm \
  -v /path/to/contracts:/contracts \
  -v /tmp/output:/output \
  your-registry/my-scanner:1.0.0

# Push to registry
docker push your-registry/my-scanner:1.0.0
```

## Testing Plugins

### Unit Tests

```python
# tests/test_scanner.py
import pytest
from my_scanner.scanner import MyScanner
from my_scanner.patterns import PATTERNS

def test_scanner_initialization():
    """Test scanner initializes correctly."""
    scanner = MyScanner()
    assert scanner.get_metadata()["name"] == "My Scanner"

def test_scanner_with_config():
    """Test scanner accepts configuration."""
    config = {"timeout": 600, "severity_threshold": "high"}
    scanner = MyScanner(config)
    assert scanner.timeout == 600
    assert scanner.severity_threshold == "high"

def test_selfdestruct_detection():
    """Test detection of selfdestruct calls."""
    scanner = MyScanner()
    contracts = [{
        "path": "test.sol",
        "content": """
        contract Test {
            function destroy() public {
                selfdestruct(payable(msg.sender));
            }
        }
        """
    }]

    result = scanner.scan(contracts)

    assert len(result.findings) == 1
    assert result.findings[0].type == "dangerous_function"
    assert result.findings[0].severity.value == "high"
    assert "selfdestruct" in result.findings[0].message

def test_no_findings_for_clean_contract():
    """Test clean contract produces no findings."""
    scanner = MyScanner()
    contracts = [{
        "path": "test.sol",
        "content": """
        contract Clean {
            uint256 public value;
            function setValue(uint256 _value) public {
                value = _value;
            }
        }
        """
    }]

    result = scanner.scan(contracts)
    assert len(result.findings) == 0

def test_pattern_count():
    """Test all patterns are loaded."""
    scanner = MyScanner()
    patterns = scanner.get_patterns()
    assert len(patterns) >= 2  # At least our example patterns

def test_metadata_format():
    """Test metadata has required fields."""
    scanner = MyScanner()
    metadata = scanner.get_metadata()

    assert "name" in metadata
    assert "version" in metadata
    assert "author" in metadata
    assert "description" in metadata
    assert "supported_languages" in metadata
    assert "capabilities" in metadata

@pytest.fixture
def vulnerable_contract():
    """Fixture providing a vulnerable contract."""
    return {
        "path": "vulnerable.sol",
        "content": """
        contract Vulnerable {
            function withdraw() public {
                msg.sender.call{value: address(this).balance}("");
            }
        }
        """
    }

def test_unchecked_call_detection(vulnerable_contract):
    """Test detection of unchecked low-level calls."""
    scanner = MyScanner()
    result = scanner.scan([vulnerable_contract])

    assert len(result.findings) >= 1
    unchecked_calls = [f for f in result.findings if f.type == "unchecked_call"]
    assert len(unchecked_calls) >= 1
```

### Integration Tests

```python
# tests/test_integration.py
import json
import subprocess
import tempfile
import os

def test_docker_container():
    """Test plugin runs in Docker container."""
    # Create temporary directories
    with tempfile.TemporaryDirectory() as contracts_dir, \
         tempfile.TemporaryDirectory() as output_dir:

        # Write test contract
        contract_path = os.path.join(contracts_dir, "test.sol")
        with open(contract_path, 'w') as f:
            f.write("""
            contract Test {
                function destroy() public {
                    selfdestruct(payable(msg.sender));
                }
            }
            """)

        # Run container
        result = subprocess.run([
            "docker", "run", "--rm",
            "-v", f"{contracts_dir}:/contracts",
            "-v", f"{output_dir}:/output",
            "your-registry/my-scanner:1.0.0"
        ], capture_output=True, text=True)

        assert result.returncode == 0

        # Check output
        output_file = os.path.join(output_dir, "results.json")
        assert os.path.exists(output_file)

        with open(output_file) as f:
            results = json.load(f)

        assert results["tool"] == "My Scanner"
        assert len(results["findings"]) >= 1
```

### Test Coverage

```bash
# Install coverage
pip install pytest-cov

# Run tests with coverage
pytest --cov=src --cov-report=html tests/

# View coverage report
open htmlcov/index.html
```

## Deployment

### Local Development (Minikube)

```bash
# Start Minikube
minikube start

# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build image locally
docker build -t my-scanner:1.0.0 .

# Install plugin
kubectl apply -f plugin.yaml

# Verify installation
kubectl get plugins -n solidity-security

# Check plugin status
kubectl describe plugin my-custom-scanner -n solidity-security
```

### Production Deployment

```bash
# Build and push to registry
docker build -t your-registry/my-scanner:1.0.0 .
docker push your-registry/my-scanner:1.0.0

# Update plugin manifest with registry URL
sed -i 's|image: .*|image: your-registry/my-scanner:1.0.0|' plugin.yaml

# Deploy to production cluster
kubectl apply -f plugin.yaml -n solidity-security

# Verify deployment
kubectl get plugins -n solidity-security
kubectl logs -l app=plugin-registry -n solidity-security
```

### Plugin Configuration

Create a ConfigMap for plugin configuration:

```yaml
# plugin-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-scanner-config
  namespace: solidity-security
data:
  config.json: |
    {
      "severity_threshold": "medium",
      "enable_experimental": false,
      "timeout": 300,
      "exclude_patterns": [
        "test_*.sol",
        "*_mock.sol"
      ]
    }
```

```bash
kubectl apply -f plugin-config.yaml
```

### Using Secrets

For plugins requiring API keys:

```yaml
# plugin-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-scanner-secrets
  namespace: solidity-security
type: Opaque
stringData:
  api-key: "your-api-key-here"
  api-secret: "your-api-secret-here"
```

```bash
kubectl apply -f plugin-secret.yaml
```

Update plugin manifest to reference secrets:

```yaml
spec:
  env:
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: my-scanner-secrets
          key: api-key
    - name: API_SECRET
      valueFrom:
        secretKeyRef:
          name: my-scanner-secrets
          key: api-secret
```

## Best Practices

### 1. Error Handling

Always handle errors gracefully:

```python
def scan(self, contracts):
    findings = []
    errors = []

    for contract in contracts:
        try:
            # Analysis logic
            contract_findings = self._analyze_contract(contract)
            findings.extend(contract_findings)
        except Exception as e:
            errors.append({
                "file": contract['path'],
                "error": str(e)
            })
            # Continue with other contracts

    return ScanResult(
        tool=self.name,
        version=self.version,
        findings=findings,
        metadata={
            "errors": errors,
            "files_analyzed": len(contracts) - len(errors)
        }
    )
```

### 2. Performance Optimization

- Implement timeouts for long-running analyses
- Use multiprocessing for parallel contract analysis
- Cache parsed ASTs and intermediate results
- Provide progress indicators for long scans

```python
from concurrent.futures import ProcessPoolExecutor, TimeoutError
import multiprocessing

def scan(self, contracts):
    max_workers = min(multiprocessing.cpu_count(), len(contracts))
    timeout = self.config.get("timeout", 300)

    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(self._analyze_contract, c): c
            for c in contracts
        }

        findings = []
        for future in futures:
            try:
                result = future.result(timeout=timeout)
                findings.extend(result)
            except TimeoutError:
                contract = futures[future]
                print(f"Timeout analyzing {contract['path']}")
            except Exception as e:
                print(f"Error analyzing contract: {e}")

    return ScanResult(...)
```

### 3. Memory Management

- Stream large files instead of loading into memory
- Clean up temporary files and resources
- Set appropriate memory limits in plugin manifest

```python
def scan(self, contracts):
    for contract in contracts:
        # Stream large contracts
        if len(contract['content']) > 1_000_000:  # 1MB
            with open(contract['path'], 'r') as f:
                for chunk in self._read_chunks(f):
                    self._analyze_chunk(chunk)
        else:
            self._analyze_contract(contract)
```

### 4. Logging

Use structured logging for debugging:

```python
import logging

logger = logging.getLogger(__name__)

class MyScanner(ScannerPlugin):
    def scan(self, contracts):
        logger.info(f"Starting scan of {len(contracts)} contracts")

        for i, contract in enumerate(contracts, 1):
            logger.debug(f"Analyzing contract {i}/{len(contracts)}: {contract['path']}")
            findings = self._analyze_contract(contract)
            logger.info(f"Found {len(findings)} issues in {contract['path']}")

        logger.info(f"Scan complete. Total findings: {len(all_findings)}")
```

### 5. Configuration Validation

Validate configuration on initialization:

```python
def validate_config(self):
    """Validate plugin configuration."""
    if "severity_threshold" in self.config:
        valid_severities = ["critical", "high", "medium", "low", "info"]
        if self.config["severity_threshold"] not in valid_severities:
            raise ValueError(f"Invalid severity_threshold: {self.config['severity_threshold']}")

    if "timeout" in self.config:
        timeout = self.config["timeout"]
        if not isinstance(timeout, int) or timeout < 30:
            raise ValueError(f"Timeout must be integer >= 30, got {timeout}")

    return True
```

### 6. Versioning

Follow semantic versioning and include version checks:

```python
class MyScanner(ScannerPlugin):
    VERSION = "1.0.0"
    MIN_SDK_VERSION = "1.0.0"

    def __init__(self, config=None):
        super().__init__(config)
        self._check_sdk_version()

    def _check_sdk_version(self):
        import blocksecops_plugin_sdk
        sdk_version = blocksecops_plugin_sdk.__version__
        if sdk_version < self.MIN_SDK_VERSION:
            raise RuntimeError(f"SDK version {sdk_version} < minimum required {self.MIN_SDK_VERSION}")
```

## Security Considerations

### 1. Container Isolation

Plugins run in isolated containers with restricted permissions:

```yaml
# plugin.yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
```

### 2. Resource Limits

Always set resource limits to prevent resource exhaustion:

```yaml
spec:
  resources:
    limits:
      memory: "1Gi"
      cpu: "1000m"
    requests:
      memory: "256Mi"
      cpu: "250m"
```

### 3. Network Policies

By default, plugins have no network access. If needed, explicitly allow:

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-scanner-network
spec:
  podSelector:
    matchLabels:
      plugin: my-scanner
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api-server
      ports:
        - protocol: TCP
          port: 443
```

### 4. Secret Management

Never hardcode secrets. Use Kubernetes Secrets:

```python
import os

API_KEY = os.environ.get("API_KEY")
if not API_KEY:
    raise ValueError("API_KEY environment variable not set")
```

### 5. Input Validation

Always validate input contracts:

```python
def scan(self, contracts):
    for contract in contracts:
        # Validate required fields
        if "path" not in contract or "content" not in contract:
            raise ValueError("Contract must have 'path' and 'content' fields")

        # Validate file size
        if len(contract['content']) > 10_000_000:  # 10MB
            raise ValueError(f"Contract too large: {contract['path']}")

        # Validate file type
        if not contract['path'].endswith(('.sol', '.vy')):
            raise ValueError(f"Unsupported file type: {contract['path']}")
```

### 6. Code Signing (Production)

For production deployments, sign plugin images:

```bash
# Sign image with cosign
cosign sign --key cosign.key your-registry/my-scanner:1.0.0

# Verify signature
cosign verify --key cosign.pub your-registry/my-scanner:1.0.0
```

Update platform to only allow signed images:

```yaml
spec:
  imagePullPolicy: Always
  imageVerification:
    required: true
    publicKey: |
      -----BEGIN PUBLIC KEY-----
      ...
      -----END PUBLIC KEY-----
```

## Examples

### Example 1: Simple Pattern Matcher

See [examples/plugins/regex-detector/](../examples/plugins/regex-detector/) for a complete implementation of a regex-based vulnerability detector.

### Example 2: AST Analyzer

See [examples/plugins/ast-analyzer/](../examples/plugins/ast-analyzer/) for an AST-based static analyzer.

### Example 3: AI-Powered Analyzer

See [examples/plugins/ai-analyzer/](../examples/plugins/ai-analyzer/) for a machine learning-based vulnerability detector.

### Example 4: Compliance Checker

See [examples/plugins/compliance-checker/](../examples/plugins/compliance-checker/) for a regulatory compliance checker.

## FAQ

**Q: What languages are supported?**
A: The SDK supports any language that can run in a Docker container. Examples are provided in Python, but you can use Go, Rust, JavaScript, etc.

**Q: How do I debug my plugin?**
A: Run the container locally with debug flags:
```bash
docker run --rm -it \
  -v /path/to/contracts:/contracts \
  -v /tmp/output:/output \
  -e DEBUG=1 \
  your-registry/my-scanner:1.0.0 /bin/bash
```

**Q: Can plugins access the internet?**
A: By default, no. You must explicitly configure network policies to allow internet access.

**Q: How are plugin results merged with core scanner results?**
A: The platform automatically aggregates results from all scanners (core + plugins) and deduplicates findings based on file, line, and vulnerability type.

**Q: Can I charge for my plugin?**
A: Yes! Specify pricing in the plugin manifest. The platform supports free, premium, and enterprise tiers.

**Q: How do I handle plugin failures?**
A: The platform automatically retries failed jobs (default: 3 retries). Implement proper error handling and logging in your plugin.

**Q: Can plugins call external APIs?**
A: Yes, if network policies allow it. Use environment variables for API keys and implement proper timeout handling.

## Support

- **Documentation**: https://docs.0xapogee.io/plugins
- **SDK Repository**: https://github.com/SolidityOps/plugin-sdk
- **Examples**: https://github.com/SolidityOps/plugin-examples
- **Discord**: https://discord.gg/blocksecops
- **Email**: plugins@0xapogee.com

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](https://github.com/SolidityOps/plugin-sdk/blob/main/CONTRIBUTING.md) for guidelines.

## License

The Plugin SDK is open source under the MIT License. See [LICENSE](https://github.com/SolidityOps/plugin-sdk/blob/main/LICENSE) for details.
