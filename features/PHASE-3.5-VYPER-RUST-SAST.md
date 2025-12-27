# Phase 3.5: Vyper/Rust SAST Testing Implementation

**Last Updated**: December 21, 2025

## Overview

Phase 3.5 extends BlockSecOps security scanning capabilities to support Vyper smart contracts and Rust-based Solana programs. This phase implements scanner executors for 6 additional security tools, bringing the total scanner count to 17.

## New Scanners

### Vyper Scanners (2 tools)

| Scanner | Type | Description |
|---------|------|-------------|
| **Slither-Vyper** | Static Analysis | Slither with Vyper compilation support for Python-based contracts |
| **Moccasin** | Fuzzing | Cyfrin's Titanoboa-based property fuzzer for Vyper |

### Solana/Rust Scanners (4 tools)

| Scanner | Type | Description |
|---------|------|-------------|
| **Sol-azy** | Static Analysis | AST-based analysis by FuzzingLabs (14 detectors) |
| **Sec3 X-Ray** | Static Analysis | LLVM-based deep analysis (40+ vulnerability types) |
| **Trident** | Fuzzing | Ackee Blockchain's property-based fuzzer for Anchor |
| **Cargo Fuzz Solana** | Fuzzing | rust-fuzz LibFuzzer for Solana programs |

## Architecture

### Executor Implementation

Each scanner follows the standard `ScannerExecutor` pattern:

```python
class ScannerExecutor(ABC):
    def __init__(self, scanner_id: str, timeout: int, requires_project: bool):
        self.scanner_id = scanner_id
        self.timeout = timeout
        self.requires_project = requires_project

    @abstractmethod
    def execute(self, context: ScannerContext) -> ScannerResult:
        """Execute scanner and return results."""
        pass

    @abstractmethod
    def is_available(self) -> bool:
        """Check if scanner is installed."""
        pass
```

### File Structure

```
blocksecops-orchestration/src/blocksecops_orchestration/scanners/
├── base.py                  # Base classes
├── registry.py              # Scanner registration
├── solidity_scanners.py     # Solidity scanners (11)
├── vyper_scanners.py        # Vyper scanners (2)
└── solana_scanners.py       # Solana scanners (4)
```

## Vyper Scanner Details

### SlitherVyperExecutor

Uses Slither with Vyper compilation support:

```python
class SlitherVyperExecutor(ScannerExecutor):
    def execute(self, context: ScannerContext) -> ScannerResult:
        # Write .vy file
        contract_file = context.temp_dir / f"{context.contract_name}.vy"
        contract_file.write_text(context.source_code)

        # Execute Slither
        command = ["slither", str(contract_file), "--json", "-"]
        result = subprocess.run(command, capture_output=True, timeout=context.timeout)

        return ScannerResult(
            scanner_id="vyper",
            success=True,
            raw_output=json.loads(result.stdout),
        )
```

**Requirements:**
- Slither >= 0.9.0
- Vyper compiler >= 0.3.0

### MoccasinExecutor

Cyfrin's fuzzing framework:

```python
class MoccasinExecutor(ScannerExecutor):
    def execute(self, context: ScannerContext) -> ScannerResult:
        # Write contract and config
        contract_file = context.temp_dir / f"{context.contract_name}.vy"
        contract_file.write_text(context.source_code)

        # Generate moccasin.toml config
        config_file = context.temp_dir / "moccasin.toml"
        config_file.write_text(self._generate_moccasin_config(context))

        # Execute Moccasin
        command = ["mox", "test", "--json"]
        result = subprocess.run(command, cwd=context.temp_dir, ...)

        return ScannerResult(...)
```

**Requirements:**
- Moccasin (mox) CLI
- Python 3.10+

## Solana Scanner Details

### SolAzyExecutor

AST-based static analysis:

```python
class SolAzyExecutor(ScannerExecutor):
    def __init__(self):
        super().__init__(
            scanner_id="sol-azy",
            timeout=300,
            requires_project=True,  # Needs Cargo project structure
        )

    def execute(self, context: ScannerContext) -> ScannerResult:
        # Create Solana project structure
        if context.is_project:
            context.write_project_files()
        else:
            self._create_minimal_solana_project(context)

        command = ["sol-azy", "analyze", str(target_dir), "--output-format", "json"]
        ...
```

**Detected Vulnerabilities:**
- Missing signer checks
- Missing owner validation
- Arbitrary CPI
- Integer overflow/underflow
- Account data matching

### Sec3XRayExecutor

LLVM-based deep analysis:

```python
class Sec3XRayExecutor(ScannerExecutor):
    def execute(self, context: ScannerContext) -> ScannerResult:
        # X-Ray requires compilation
        command = ["xray", "scan", str(project_dir), "--output", "json"]
        ...
```

**Capabilities:**
- 40+ vulnerability types
- Deep data flow analysis
- Cross-function analysis
- Anchor framework support

### TridentExecutor

Property-based fuzzing for Anchor:

```python
class TridentExecutor(ScannerExecutor):
    def execute(self, context: ScannerContext) -> ScannerResult:
        # Create Anchor project with Trident config
        self._create_anchor_project(context)

        command = ["trident", "fuzz", "run", "--exit-first-failure"]
        ...
```

**Features:**
- Stateful fuzzing
- Invariant testing
- Account state manipulation
- Transaction sequence fuzzing

### CargoFuzzSolanaExecutor

LibFuzzer integration:

```python
class CargoFuzzSolanaExecutor(ScannerExecutor):
    def execute(self, context: ScannerContext) -> ScannerResult:
        # Initialize fuzz targets
        subprocess.run(["cargo", "fuzz", "init"], cwd=project_dir)

        # Run fuzzer
        command = ["cargo", "fuzz", "run", "fuzz_target",
                   "--", "-max_total_time=30"]
        ...
```

## Vulnerability Patterns

### Vyper Patterns (99 total)

Categories covered:
- Reentrancy (BVD-VYPER-REE-*)
- Access Control (BVD-VYPER-ACC-*)
- External Calls (BVD-VYPER-EXT-*)
- Arithmetic (BVD-VYPER-ARI-*)
- State Variables (BVD-VYPER-STA-*)
- Gas Optimization (BVD-VYPER-GAS-*)

### Solana Patterns (32 total)

Categories covered:
- Account Validation (BVD-SOLANA-ACC-*)
- Cross-Program Invocation (BVD-SOLANA-CPI-*)
- Program Derived Address (BVD-SOLANA-PDA-*)
- Arithmetic (BVD-SOLANA-ARI-*)
- Type Safety (BVD-SOLANA-TYP-*)
- Security (BVD-SOLANA-SEC-*)

## Scan Presets

### Vyper Presets

```python
PRESETS["vyper"] = {
    "quick": ScanPreset(
        name="Quick Scan",
        description="Static analysis for Vyper contracts (~30 seconds)",
        scanner_ids=["vyper"],
        estimated_time_seconds=20,
    ),
    "standard": ScanPreset(
        name="Standard Scan",
        description="Static analysis + fuzzing (~2 minutes)",
        scanner_ids=["vyper", "moccasin"],
        estimated_time_seconds=110,
    ),
}
```

### Rust/Solana Presets

```python
PRESETS["rust"] = {
    "quick": ScanPreset(
        name="Quick Scan",
        description="AST-based static analysis (~1 minute)",
        scanner_ids=["sol-azy"],
        estimated_time_seconds=30,
    ),
    "standard": ScanPreset(
        name="Standard Scan",
        description="Deep LLVM analysis + fuzzing (~5 minutes)",
        scanner_ids=["sol-azy", "sec3-xray", "trident"],
        estimated_time_seconds=210,
    ),
    "deep": ScanPreset(
        name="Deep Scan",
        description="All Solana tools (~7 minutes)",
        scanner_ids=["sol-azy", "sec3-xray", "trident", "cargo-fuzz-solana"],
        estimated_time_seconds=360,
    ),
}
```

## Test Contracts

### Vyper Test Contract

Location: `test-contracts/vyper/vulnerable_token.vy`

Intentional vulnerabilities:
1. Reentrancy in `withdraw()` - external call before state update
2. Missing access control on `mint()` - anyone can mint
3. Unprotected `selfdestruct()` - anyone can destroy
4. Arbitrary external call in `arbitraryCall()`

### Solana Test Contract

Location: `test-contracts/solana/vulnerable_vault.rs`

Intentional vulnerabilities:
1. Missing signer check in `process_deposit()`
2. Missing owner validation in `process_withdraw()`
3. Arbitrary CPI in `process_execute_cpi()`
4. PDA bump seed canonicalization issue
5. Account data matching (type cosplay)
6. Closing account without zeroing data

## Installation Requirements

### Vyper Scanners

```bash
# Slither with Vyper support
pip install slither-analyzer vyper

# Moccasin
pip install moccasin
```

### Solana Scanners

```bash
# Sol-azy
cargo install sol-azy

# Sec3 X-Ray (requires registration)
# Download from https://sec3.dev

# Trident
cargo install trident-cli

# Cargo Fuzz
cargo install cargo-fuzz
```

## Docker Images

Scanner Docker images are available in:

```
blocksecops-tool-integration/scanner-images/
├── slither-vyper/
│   └── Dockerfile
├── moccasin/
│   └── Dockerfile
├── sol-azy/
│   └── Dockerfile
├── sec3-xray/
│   └── Dockerfile
├── trident/
│   └── Dockerfile
└── cargo-fuzz-solana/
    └── Dockerfile
```

## Usage Examples

### Scanning a Vyper Contract

```python
from blocksecops_orchestration.scanners import get_scanner_registry

registry = get_scanner_registry()

# Check availability
if registry.is_available("vyper"):
    scanner = registry.get("vyper")
    result = scanner.execute(context)
    print(f"Found {len(result.raw_output.get('detectors', []))} issues")
```

### API Request

```bash
# Create scan for Vyper contract
curl -X POST http://localhost:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_id": "uuid",
    "scan_type": "standard",
    "scanner_ids": ["vyper", "moccasin"]
  }'
```

### Frontend Selection

The scanner selector UI automatically shows language-appropriate scanners:

```tsx
<ScannerSelector
  language="vyper"
  selectedScanners={selectedScanners}
  onSelectionChange={handleSelectionChange}
  showPresets={true}
/>
```

## Testing

### Unit Tests

```bash
cd blocksecops-orchestration
pytest tests/scanners/test_vyper_scanners.py -v
pytest tests/scanners/test_solana_scanners.py -v
```

### Integration Tests

```bash
# Test with vulnerable contracts
pytest tests/integration/vyper/test_vyper_scanner.py -v
pytest tests/integration/solana/test_solana_patterns.py -v
```

## Metrics and Monitoring

Scanner execution metrics are logged:

```python
logger.info(
    "scanner_completed",
    scanner_id="vyper",
    execution_time=12.5,
    findings_count=5,
    success=True,
)
```

Prometheus metrics available:
- `scanner_execution_duration_seconds{scanner_id="vyper"}`
- `scanner_findings_total{scanner_id="vyper", severity="high"}`
- `scanner_errors_total{scanner_id="vyper"}`

## Future Enhancements

1. **Additional Vyper Tools**:
   - Vyper-specific linter
   - Formal verification integration

2. **Solana Enhancements**:
   - Native program support (non-Anchor)
   - SPL token analysis
   - NFT program patterns

3. **Cross-Language Analysis**:
   - Bridge contract analysis
   - Multi-chain vulnerability correlation

4. **Performance Optimization**:
   - Parallel scanner execution
   - Incremental analysis for projects
