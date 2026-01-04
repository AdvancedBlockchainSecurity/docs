# Scanner Docker Images

This document describes the production-ready Docker images for security scanner tools used by the Kubernetes Jobs-based scanner execution architecture.

## Architecture Overview

The scanner images solve dependency conflicts by running each scanner in an isolated container with its own dependencies. This resolves issues like:
- **Mythril**: requires `ckzg<2`
- **Slither**: requires `ckzg>=2.0.0` (via web3>=7.10)

By running scanners as Kubernetes Jobs, each scanner gets:
- Isolated environment with specific dependencies
- Resource limits (CPU/memory)
- Automatic retry on failure
- TTL-based cleanup after completion

## Scanner Images

### 1. Vyper (scanner-vyper:0.4.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/vyper/Dockerfile`

Python-based static analyzer for Vyper smart contracts using Slither with native Vyper support and vvm (Vyper Version Manager) for multi-version compatibility.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/vyper
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-vyper:0.4.0 .
docker tag scanner-vyper:0.4.0 scanner-vyper:latest
```

**Features**:
- Multi-stage build (build + runtime)
- **vvm 0.3.2** - Vyper Version Manager for automatic version detection and installation
- **Vyper 0.3.10** - Latest stable 0.3.x (pre-installed)
- **Vyper 0.4.3** - Latest stable 0.4.x (pre-installed)
- **Slither 0.11.3** - Latest stable static analysis engine
- **Contract Preprocessing** - Handles module-level docstrings that Slither cannot parse
- **Automatic Version Selection** - Uses latest stable version for each major.minor line
- Python 3.11-slim base image
- Automated callback mechanism for result posting
- Build time: ~60 seconds (first build), ~2 seconds (cached)

**Version Selection Logic**:
| Contract Pragma | Vyper Version Used |
|-----------------|-------------------|
| `^0.3.x`, `~=0.3.x` | 0.3.10 (latest 0.3.x) |
| `^0.4.x`, `~=0.4.x` | 0.4.3 (latest 0.4.x) |

**Vulnerability Patterns**:
- Reentrancy (HIGH) - External calls before state updates
- Unchecked Send (LOW) - Ignored return value from send()
- Arbitrary ETH Send (HIGH) - Unprotected ETH transfers
- Missing Access Control (HIGH) - Unauthorized function access
- Unchecked External Calls (MEDIUM) - raw_call without checks
- Low-Level Calls (INFORMATIONAL) - raw_call usage
- See `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/vyper/VYPER_PATTERNS.md` for complete list

**Environment Variables**:
- `CALLBACK_URL` - Tool-integration result collection endpoint (required)
- `SCAN_ID` - UUID of the scan (required)
- `CONTRACTS_DIR` - Directory containing contracts (default: /contracts)

**Resource Requirements**:
- Memory limit: 1Gi
- Memory request: 512Mi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (December 29, 2025)

**Version History**:
- 0.4.0 (2025-12-29): Updated to latest stable versions per dependency standards
- 0.3.x (2025-12-29): Added vvm, preprocessing, automatic version selection
- 0.2.0 (2025-12-15): Initial Kubernetes Jobs implementation

---

### 2. Solana (scanner-solana-rust:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/solana-rust/Dockerfile`

Solana static analyzer using sol-azy from FuzzingLabs for Solana sBPF programs.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/solana-rust
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-solana-rust:0.1.0 .
```

**Features**:
- Multi-stage build (Rust builder + runtime)
- Sol-azy static analyzer from GitHub (FuzzingLabs/sol-azy)
- AST-based pattern matching
- Custom Starlark security rules
- JSON output format
- Build time: ~5-10 minutes (Rust compilation)

**Vulnerability Patterns**:
- Saturating Math Operations (MEDIUM-HIGH) - Precision loss in calculations
- Unsafe Rust Code (HIGH) - Memory safety issues
- Missing Signer Checks (CRITICAL) - Authorization bypass
- Missing Owner Checks (CRITICAL) - Account validation
- PDA Validation Issues (HIGH) - Program Derived Address security
- Integer Overflow/Underflow (HIGH) - Arithmetic vulnerabilities
- See `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/solana-rust/SOLANA_PATTERNS.md` for complete list

**Resource Requirements**:
- Memory limit: 1Gi
- Memory request: 512Mi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (October 13, 2025)

**Note**: Sol-azy's AST-based analysis automatically detects saturating math and unsafe code. Solana-specific patterns (PDAs, account validation) require manual review until future MIR/LLVM IR analysis is added.

---

### 3. Sec3 X-Ray (scanner-sec3-xray:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/sec3-xray/Dockerfile`

LLVM-based static analyzer for Solana smart contracts, detecting 40+ vulnerability types in Rust-native and Anchor programs.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/sec3-xray
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-sec3-xray:0.1.0 .
```

**Features**:
- Multi-stage build (Rust builder + runtime)
- Clones from GitHub: https://github.com/sec3-product/x-ray
- LLVM 16-based deep program analysis
- Detects 40+ vulnerability types automatically
- Includes Anchor framework-specific security rules
- JSON output format
- Build time: ~10-15 minutes (LLVM + Rust compilation)

**Vulnerability Patterns**:
- Missing Signer Constraint (CRITICAL) - Authorization bypass in Anchor
- Missing Owner Constraint (CRITICAL) - Account ownership validation
- Missing PDA Seeds Constraint (HIGH) - PDA derivation security
- Missing `mut` Constraint (HIGH) - State mutation without marker
- Bump Seed Manipulation (HIGH) - PDA bump seed attacks
- Missing Account Type Validation (HIGH) - Type confusion attacks
- Integer Overflow/Underflow (HIGH) - Arithmetic vulnerabilities
- Unsafe Rust Code (HIGH) - Memory safety issues
- Missing Rent Exemption Check (MEDIUM) - Account rent issues
- See `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/sec3-xray/ANCHOR_PATTERNS.md` for complete Anchor patterns

**Resource Requirements**:
- Memory limit: 2Gi (LLVM analysis is memory-intensive)
- Memory request: 1Gi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (October 13, 2025)

**Advantages over sol-azy**: X-Ray uses LLVM IR for deeper analysis compared to sol-azy's AST-only approach. This enables detection of complex control flow vulnerabilities and compiler-level optimizations that could introduce bugs.

---

### 4. Trident Fuzzer (scanner-trident-fuzzer:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/trident-fuzzer/Dockerfile`

Property-based and stateful fuzzing framework for Anchor programs, using honggfuzz for input generation.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/trident-fuzzer
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-trident-fuzzer:0.1.0 .
```

**Features**:
- Multi-stage build (Rust builder + runtime)
- Trident CLI from Cargo (https://github.com/Ackee-Blockchain/trident)
- Solana CLI included (required dependency)
- Property-based fuzzing with honggfuzz
- Stateful fuzzing for complex program interactions
- Configurable iterations and timeout via environment variables
- Auto-initialization of Trident test suite
- JSON output format
- Build time: ~10-15 minutes (Rust + Solana CLI)

**Detection Capabilities**:
- Fuzzing Crash (HIGH) - Program crashes under unexpected inputs
- Assertion Failure (MEDIUM) - Failed runtime assertions
- Property Violation (HIGH) - Violated program invariants
- Panic Conditions (HIGH) - Unhandled panic scenarios
- State Transition Bugs (MEDIUM) - Invalid state changes

**Environment Variables**:
- `FUZZ_ITERATIONS` - Number of fuzz iterations (default: 1000)
- `FUZZ_TIMEOUT` - Timeout in seconds (default: 300)

**Resource Requirements**:
- Memory limit: 1Gi
- Memory request: 512Mi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (October 13, 2025)

**Use Case**: Trident complements static analysis (sol-azy, X-Ray) by discovering runtime bugs through fuzzing. It's especially effective for Anchor programs with complex state machines and cross-program invocations.

---

### 5. Move Prover (scanner-move-prover:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/move-prover/Dockerfile`

Formal verification tool for Move smart contracts on Aptos and Sui blockchains, providing mathematical guarantees of contract correctness.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/move-prover
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-move-prover:0.1.0 .
```

**Features**:
- Multi-stage build (Rust builder + runtime)
- Installs Aptos CLI (includes Move Prover)
- Microsoft Z3 SMT solver for formal verification
- Move Specification Language (MSL) support
- Automatic invariant checking
- Precondition and postcondition verification
- JSON output format
- Build time: ~15-20 minutes (Aptos CLI + dependencies)

**Vulnerability Patterns**:
- Missing Abort Conditions (CRITICAL) - Invalid state transitions
- Incorrect Resource Handling (CRITICAL) - Resource duplication/leaks
- Missing Access Control (HIGH) - Unauthorized modifications
- Integer Overflow/Underflow (HIGH) - Arithmetic vulnerabilities
- Missing Global Invariants (HIGH) - Protocol-wide violations
- Uninitialized Storage (HIGH) - Missing existence checks
- Reentrancy (MEDIUM) - Cross-module state changes
- Timestamp Dependence (MEDIUM) - Timing manipulation
- Incorrect Capability Management (CRITICAL - Sui) - Permission issues
- See `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/move-prover/MOVE_PATTERNS.md` for complete patterns

**Resource Requirements**:
- Memory limit: 2Gi (Z3 solver is memory-intensive)
- Memory request: 1Gi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (October 13, 2025)

**Key Advantage**: Move Prover provides **formal verification** - mathematical proofs that contracts behave correctly under all possible inputs. Unlike traditional testing or static analysis, formal verification can guarantee the absence of certain classes of bugs.

**Use Case**: Essential for high-value Move contracts on Aptos and Sui where correctness guarantees are critical. The prover verifies specification blocks (`spec`) written alongside contract code.

---

### 6. Cairo/Caracal (scanner-cairo:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/cairo/Dockerfile`

Static analyzer for Cairo smart contracts on StarkNet using Caracal from Trail of Bits/Crytic.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/cairo
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-cairo:0.1.0 .
```

**Features**:
- Multi-stage build (Rust builder + runtime)
- Caracal static analyzer from GitHub (crytic/caracal)
- SIERRA representation analysis (Cairo's intermediate language)
- 14 built-in vulnerability detectors
- Taint analysis and data flow analysis
- Control flow graph and call graph generation
- Supports Cairo 1.x and 2.x via Scarb projects
- JSON output format
- Build time: ~10-15 minutes (Rust compilation)

**Vulnerability Patterns**:
- Unchecked L1 Handler From Address (CRITICAL) - Cross-layer security
- Reentrancy Vulnerabilities (CRITICAL) - External calls before state updates
- Unchecked Felt252 Arithmetic (HIGH) - Overflow/underflow in felt operations
- Uninitialized State Variables (HIGH) - Missing initialization checks
- Unused Return Values (HIGH) - Ignored external call results
- Controlled Library Call (MEDIUM) - User-controlled contract calls
- Dead Code (MEDIUM) - Unreachable code paths
- Unused Events (MEDIUM) - Declared but never emitted events
- Naming Convention Violations (LOW) - Code quality issues
- Pragma Version Issues (INFORMATIONAL) - Missing or loose version constraints
- See `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/cairo/CAIRO_PATTERNS.md` for complete patterns

**Resource Requirements**:
- Memory limit: 1Gi
- Memory request: 512Mi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (October 13, 2025)

**Key Advantage**: Caracal is developed by Trail of Bits/Crytic (creators of Slither), providing industry-standard static analysis for StarkNet. It analyzes SIERRA representation (Cairo's intermediate language) for deep vulnerability detection with low false positive rates.

**Use Case**: Essential for Cairo/StarkNet contracts requiring comprehensive static analysis. Caracal detects both StarkNet-specific vulnerabilities (L1/L2 bridges, felt252 arithmetic) and general security issues (reentrancy, access control).

---

### 7. Echidna (scanner-echidna:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/echidna/Dockerfile`

Property-based fuzzer for Ethereum smart contracts from Trail of Bits, performing 50,000 test cases per contract.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/echidna
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-echidna:0.1.0 .
```

**Features**:
- Multi-stage build using official `trailofbits/echidna:v2.2.4`
- Property-based fuzzing with 50,000 test cases (configurable)
- Invariant testing via `echidna_*` functions
- Assertion checking for all `assert()` statements
- Counterexample generation with exact transaction sequences
- Corpus-based learning for improved coverage
- Grammar-aware input generation based on ABI
- Automatic Solidity version management via solc-select
- JSON output format
- Build time: ~3-5 minutes

**Vulnerability Patterns**:
- Reentrancy Vulnerabilities (CRITICAL) - External calls before state updates
- Integer Overflow/Underflow (HIGH) - Arithmetic operation wrap-around
- Access Control Violations (CRITICAL) - Unauthorized state changes
- State Consistency Violations (HIGH) - Broken business logic invariants
- Timestamp Manipulation (MEDIUM) - Miner-manipulable time dependencies
- Denial of Service (HIGH) - Unbounded operations causing contract freeze
- Front-Running Vulnerabilities (MEDIUM) - Transaction ordering exploits
- Unchecked Return Values (MEDIUM) - Silent external call failures
- Flash Loan Attacks (CRITICAL) - Single-transaction exploits
- Delegate Call Injection (CRITICAL) - Arbitrary code execution via delegatecall
- Gas Limit DoS (MEDIUM) - Operations exceeding block gas limit
- Oracle Manipulation (HIGH) - Price feed or data source manipulation
- See `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/echidna/ECHIDNA_PATTERNS.md` for complete patterns

**Configuration**:
- `TEST_LIMIT`: Number of test cases (default: 50,000)
- `TIMEOUT`: Fuzzing timeout in seconds (default: 300)
- `SOLC_VERSION`: Solidity compiler version (default: 0.8.25)

**Resource Requirements**:
- Memory limit: 1Gi
- Memory request: 512Mi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (October 13, 2025)

**Key Advantage**: Echidna uses property-based fuzzing to automatically generate test cases that violate invariants. Unlike static analysis, it executes contracts with random inputs to find edge cases that break properties. Provides counterexamples showing exact transaction sequence to reproduce bugs.

**Use Case**: Essential for testing smart contract invariants and properties. Write `echidna_*` functions that should always return `true`, and Echidna will try to find inputs that make them return `false`. Particularly effective for DeFi protocols where conservation properties (e.g., total supply, balance conservation) must hold.

---

### 8. Manticore (scanner-manticore:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/manticore/Dockerfile`

Symbolic execution tool for Ethereum smart contracts from Trail of Bits, exploring all possible execution paths.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/manticore
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-manticore:0.1.0 .
```

**Features**:
- Python 3.11 with Z3 SMT solver integration
- Complete path exploration through symbolic execution
- Constraint solving for feasibility analysis
- Concrete exploit generation with exact inputs
- Multi-transaction analysis
- State forking at each conditional branch
- Quick mode for faster initial scans
- Automatic vulnerability pattern detection
- Workspace management for state storage
- JSON output format
- Build time: ~5-8 minutes

**Vulnerability Patterns**:
- Integer Overflow/Underflow (CRITICAL) - Arithmetic vulnerabilities
- Reentrancy Attacks (CRITICAL) - Multi-transaction state exploitation
- Unchecked Low-Level Calls (HIGH) - `.call()`, `.delegatecall()` without checks
- Delegatecall to Untrusted Callee (CRITICAL) - Arbitrary code execution
- Assert Violations (HIGH) - Broken contract invariants
- Unprotected Selfdestruct (CRITICAL) - Unauthorized contract destruction
- Transaction Order Dependence (MEDIUM) - Ordering-dependent behavior
- Timestamp Dependence (MEDIUM) - `block.timestamp` manipulation
- Uninitialized Storage Pointers (HIGH) - Storage corruption vulnerabilities
- Denial of Service via Block Gas Limit (HIGH) - Unbounded loops
- See `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/manticore/MANTICORE_PATTERNS.md` for complete patterns

**Configuration**:
- `MAX_DEPTH`: Maximum exploration depth (default: 100)
- `TIMEOUT`: Analysis timeout in seconds (default: 600)
- `SOLC_VERSION`: Solidity compiler version (default: 0.8.25)

**Resource Requirements**:
- Memory limit: 3Gi (symbolic execution is memory-intensive due to state explosion)
- Memory request: 2Gi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (October 13, 2025)

**Key Advantage**: Manticore performs **symbolic execution** - treating inputs as symbolic rather than concrete values. This enables it to explore ALL possible execution paths and find bugs that require specific input values. Uses Z3 SMT solver to generate concrete inputs that trigger vulnerabilities.

**Use Case**: Deep analysis of critical contracts where comprehensive path coverage is needed. Finds bugs that static analyzers miss and that fuzzers are unlikely to discover (e.g., vulnerabilities requiring specific numeric values). Particularly useful for contracts with complex conditional logic.

---

### 9. Certora Prover (scanner-certora:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/certora/Dockerfile`

Formal verification tool providing mathematical proofs of smart contract correctness using CVL (Certora Verification Language).

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/certora
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-certora:0.1.0 .
```

**Features**:
- Java 17 runtime for Certora Prover
- CVL (Certora Verification Language) specifications
- Mathematical proofs that properties hold for ALL possible inputs
- Automatic invariant checking
- Multi-contract verification
- Counterexample generation when proofs fail
- Cloud-based verification via API
- Default specifications auto-generated
- JSON output format
- Build time: ~8-10 minutes

**Formal Properties Verified**:
- Integer Overflow/Underflow - Proves arithmetic stays within bounds
- Reentrancy Prevention - Verifies state updates before external calls
- Access Control - Proves only authorized addresses can call functions
- Token Conservation - Proves total supply equals sum of balances
- State Consistency - Proves invariants hold across all states
- Atomicity - Proves operations are atomic or properly synchronized
- Liveness Properties - Proves operations eventually complete
- Safety Properties - Proves bad states are unreachable
- See `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/certora/CERTORA_PATTERNS.md` for CVL examples

**Configuration**:
- `CERTORA_KEY`: API key (required - sign up at https://www.certora.com/signup)
- `SOLC_VERSION`: Solidity compiler version (default: 0.8.25)

**Resource Requirements**:
- Memory limit: 2Gi (SMT solving is memory-intensive)
- Memory request: 1Gi
- CPU limit: 1000m
- CPU request: 250m

**Status**: ✅ Operational (October 13, 2025)

**License**: Commercial (free tier available for open source projects)

**Key Advantage**: Certora provides **formal verification** - mathematical guarantees that properties hold for ALL possible inputs and execution paths. Unlike testing (which checks specific cases) or fuzzing (which checks random cases), formal verification **proves** correctness. This is the highest level of assurance available for smart contracts.

**Use Case**: Critical for high-value contracts (DeFi protocols, bridges, governance) where bugs could result in catastrophic losses. Developers write specifications in CVL describing what the contract should do, and Certora mathematically proves the implementation matches the specification.

**Note**: Requires API key from https://www.certora.com/signup. Free tier available for open source projects. For production use, specifications should be written in CVL; the scanner auto-generates basic specs for initial testing.

---

### 10. Aderyn (scanner-aderyn:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/aderyn/Dockerfile`

Rust-based static analyzer for Solidity smart contracts from Cyfrin.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/aderyn
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-aderyn:0.1.0 .
```

**Features**:
- Multi-stage build (builder + runtime)
- Clones from GitHub: https://github.com/Cyfrin/aderyn
- Compiles from source using Cargo
- Optimized runtime image (debian:bookworm-slim)
- Build time: ~4-5 minutes (Rust compilation)

**Resource Requirements**:
- Memory limit: 512Mi
- Memory request: 256Mi
- CPU limit: 1000m
- CPU request: 250m

### 8. Mythril (mythril/myth:latest)
**Public Image**: Available from Docker Hub

Symbolic execution-based security analyzer.

**Pull Command**:
```bash
docker pull mythril/myth:latest
```

**Resource Requirements**:
- Memory limit: 2Gi (symbolic execution is memory-intensive)
- Memory request: 1Gi
- CPU limit: 1000m
- CPU request: 250m

### 9. Slither (scanner-slither:0.1.0)
**Location**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/slither/Dockerfile`

**Status**: ✅ Operational (October 14, 2025)

Lightweight Slither static analyzer with automated callback mechanism for Kubernetes Jobs.

**Build Command**:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/slither
eval $(minikube docker-env)  # For local Minikube
docker build -t scanner-slither:0.1.0 .
```

**Features**:
- Python 3.11-slim base image (613MB vs 7GB toolbox)
- Slither 0.10.0 static analyzer
- solc-select 1.0.4 for Solidity version management
- Pre-installed solc versions: 0.8.18, 0.8.19, 0.8.20
- Automated entrypoint script (`run-slither.sh`)
- Callback mechanism for result posting
- JSON output format
- Build time: ~5-8 minutes

**Vulnerability Patterns**:
- Reentrancy (CRITICAL) - SWC-107: reentrancy-eth, reentrancy-no-eth, reentrancy-benign
- Timestamp Dependence (MEDIUM) - SWC-116: block.timestamp manipulation
- Delegatecall Issues (CRITICAL) - SWC-112: controlled-delegatecall
- Unprotected Functions (CRITICAL) - SWC-106: unprotected-upgrade, suicidal
- Arbitrary Sends (HIGH) - SWC-105: arbitrary-send-eth, arbitrary-send-erc20
- tx.origin Usage (MEDIUM) - SWC-115: Authorization through tx.origin
- Unchecked Calls (HIGH) - SWC-104: unchecked-lowlevel, unchecked-send
- Uninitialized Storage (HIGH) - SWC-109: uninitialized-state, uninitialized-storage
- Weak PRNG (MEDIUM) - SWC-120: blockhash/timestamp randomness
- Incorrect Equality (LOW) - SWC-132: strict equality with block values
- State Shadowing (MEDIUM) - SWC-119: shadowing-state, shadowing-local

**Entrypoint Script** (`run-slither.sh`):
```bash
#!/bin/bash
# Environment variables:
# - CALLBACK_URL: URL to POST results (required)
# - SCAN_ID: Scan identifier (required)
# - SOLC_VERSION: Solidity compiler version (default: 0.8.20)

# 1. Validates environment variables
# 2. Sets solc version
# 3. Finds .sol files in /contracts
# 4. Runs Slither with JSON output
# 5. POSTs results to CALLBACK_URL
# 6. Exits with appropriate status code
```

**Environment Variables**:
- `CALLBACK_URL`: Tool-integration result collection endpoint (required)
- `SCAN_ID`: UUID of the scan (required)
- `CONTRACT_NAME`: Name of contract (optional)
- `SOLC_VERSION`: Solidity version to use (default: 0.8.20)

**Resource Requirements**:
- Memory limit: 1Gi
- Memory request: 512Mi
- CPU limit: 1000m
- CPU request: 250m

**Key Advantage**: Custom image is 10x smaller than eth-security-toolbox (613MB vs 7GB) while providing the same Slither functionality. Automated callback mechanism eliminates need for log scraping or shared storage.

## Usage with KubernetesJobManager

The `KubernetesJobManager` in `blocksecops-tool-integration` uses these images:

```python
from scanners import KubernetesJobManager

job_manager = KubernetesJobManager(namespace="blocksecops")

# Create a scanner Job
job_name = job_manager.create_scanner_job(
    scan_id="uuid-scan-id",
    scanner_name="slither",  # Options: slither, mythril, aderyn, vyper, solana-rust, sec3-xray, trident-fuzzer, move-prover, cairo, echidna, manticore, certora
    contract_path="MyContract.sol"  # or "program/" for Solana/Move, "/contracts" for Cairo
)

# Wait for completion
status = job_manager.wait_for_job_completion(job_name, timeout=600)

# Get logs
logs = job_manager.get_job_logs(job_name)
```

## Production Deployment

### Building for Production

For production, push images to a container registry:

```bash
# Tag for your registry
docker tag scanner-aderyn:0.1.0 your-registry.com/scanner-aderyn:0.1.0

# Push to registry
docker push your-registry.com/scanner-aderyn:0.1.0
```

### Update KubernetesJobManager

Update the `_get_scanner_image()` method in `kubernetes_job_manager.py`:

```python
def _get_scanner_image(self, scanner: str) -> str:
    """Get Docker image for scanner."""
    images = {
        "slither": "scanner-slither:0.1.0",  # Custom lightweight image (613MB)
        "mythril": "mythril/myth:latest",
        "aderyn": "your-registry.com/scanner-aderyn:0.1.0",
        "vyper": "your-registry.com/scanner-vyper:0.1.0",
        "solana-rust": "your-registry.com/scanner-solana-rust:0.1.0",
        "sec3-xray": "your-registry.com/scanner-sec3-xray:0.1.0",
        "trident-fuzzer": "your-registry.com/scanner-trident-fuzzer:0.1.0",
        "move-prover": "your-registry.com/scanner-move-prover:0.1.0",
        "cairo": "your-registry.com/scanner-cairo:0.1.0",
        "echidna": "your-registry.com/scanner-echidna:0.1.0",
        "manticore": "your-registry.com/scanner-manticore:0.1.0",
        "certora": "your-registry.com/scanner-certora:0.1.0"
    }
    return images.get(scanner, "unknown-scanner:latest")
```

## Image Locations

**Custom Scanner Images**:
```
/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/
├── slither/
│   ├── Dockerfile                     # Slither scanner image (613MB)
│   └── run-slither.sh                # Entrypoint script with callback
├── vyper/
│   ├── Dockerfile                     # Vyper scanner image
│   └── VYPER_PATTERNS.md             # Vyper vulnerability patterns
├── solana-rust/
│   ├── Dockerfile                     # Solana (sol-azy) scanner image
│   └── SOLANA_PATTERNS.md            # Solana vulnerability patterns
├── sec3-xray/
│   ├── Dockerfile                     # Sec3 X-Ray LLVM analyzer
│   └── ANCHOR_PATTERNS.md            # Anchor framework patterns
├── trident-fuzzer/
│   └── Dockerfile                     # Trident fuzzer image
├── move-prover/
│   ├── Dockerfile                     # Move Prover formal verification
│   └── MOVE_PATTERNS.md              # Move security patterns
├── cairo/
│   ├── Dockerfile                     # Cairo/Caracal static analyzer
│   └── CAIRO_PATTERNS.md             # Cairo/StarkNet security patterns
├── echidna/
│   ├── Dockerfile                     # Echidna property-based fuzzer
│   └── ECHIDNA_PATTERNS.md           # Echidna fuzzing patterns
├── manticore/
│   ├── Dockerfile                     # Manticore symbolic execution
│   └── MANTICORE_PATTERNS.md         # Manticore symbolic execution patterns
├── certora/
│   ├── Dockerfile                     # Certora formal verification
│   └── CERTORA_PATTERNS.md           # Certora formal verification patterns
└── aderyn/
    └── Dockerfile                     # Aderyn scanner image
```

**Service Images**: Each microservice has its own Dockerfile in its repository:
- `/Users/pwner/Git/ABS/blocksecops-api-service/Dockerfile`
- `/Users/pwner/Git/ABS/blocksecops-contract-parser/Dockerfile`
- `/Users/pwner/Git/ABS/blocksecops-data-service/Dockerfile`
- `/Users/pwner/Git/ABS/blocksecops-intelligence-engine/Dockerfile`
- `/Users/pwner/Git/ABS/blocksecops-notification/Dockerfile`
- `/Users/pwner/Git/ABS/blocksecops-tool-integration/Dockerfile`
- `/Users/pwner/Git/ABS/blocksecops-dashboard/Dockerfile`

## Testing

Test scanner images with the provided test script:

```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
python3 test_job_manager.py
```

This validates:
- ✅ KubernetesJobManager can be initialized
- ✅ Scanner Jobs can be created
- ✅ Job status can be retrieved
- ✅ Jobs can be listed
- ✅ Jobs can be deleted

## Solana Ecosystem Coverage

The platform provides comprehensive Solana security analysis through three complementary scanners:

1. **sol-azy** (scanner-solana-rust): AST-based pattern matching for common vulnerabilities
2. **Sec3 X-Ray** (scanner-sec3-xray): LLVM-based deep analysis for 40+ vulnerability types
3. **Trident Fuzzer** (scanner-trident-fuzzer): Property-based fuzzing for runtime bugs

This multi-layered approach covers:
- Static analysis (sol-azy, X-Ray)
- Dynamic analysis (Trident fuzzing)
- Anchor framework-specific patterns
- Native Solana programs
- Cross-program invocation (CPI) security

## Move Ecosystem Coverage

The platform provides **formal verification** for Move smart contracts on Aptos and Sui:

1. **Move Prover** (scanner-move-prover): Mathematical proof of correctness using Z3 solver

Key capabilities:
- Formal verification (mathematical guarantees)
- Specification language (MSL) support
- Precondition/postcondition verification
- Global invariant checking
- Resource handling verification
- Abort condition analysis

## Cairo/StarkNet Ecosystem Coverage

The platform provides **comprehensive static analysis** for Cairo smart contracts on StarkNet:

1. **Caracal** (scanner-cairo): Trail of Bits/Crytic static analyzer with 14 detectors

Key capabilities:
- SIERRA representation analysis
- 14 vulnerability detectors (reentrancy, arithmetic, access control, etc.)
- Taint analysis and data flow tracking
- Control flow and call graph generation
- Support for both Cairo 1.x and 2.x
- Scarb project support

## Analysis Depth Levels

The platform now supports 4 analysis depth levels:

**Level 1 - Static Analysis** (Fast, ~30 seconds):
- Tools: Slither, Aderyn, Mythril, Sol-azy, Sec3 X-Ray, Caracal, Vyper
- Coverage: Pattern matching, AST analysis, dataflow

**Level 2 - Fuzzing** (Medium, ~5 minutes):
- Tools: Trident, **Echidna**
- Coverage: Property testing, random inputs, 50K test cases

**Level 3 - Symbolic Execution** (Slow, ~10 minutes):
- Tools: Mythril, **Manticore**
- Coverage: Complete path exploration, constraint solving

**Level 4 - Formal Verification** (Very Slow, hours):
- Tools: Move Prover, **Certora**
- Coverage: Mathematical proofs, ALL possible inputs

## References

- **Vyper**: https://docs.vyperlang.org/
- **Sol-azy**: https://github.com/FuzzingLabs/sol-azy
- **Sec3 X-Ray**: https://github.com/sec3-product/x-ray
- **Trident**: https://github.com/Ackee-Blockchain/trident
- **Move Prover**: https://aptos.dev/build/smart-contracts/prover
- **Aptos Move**: https://aptos.dev/build/smart-contracts
- **Sui Move**: https://docs.sui.io/build/move
- **Caracal**: https://github.com/crytic/caracal
- **Cairo Book**: https://book.cairo-lang.org/
- **StarkNet Security**: https://www.starknet.io/cairo-book/ch104-00-starknet-smart-contracts-security.html
- **Echidna**: https://github.com/crytic/echidna
- **Echidna Documentation**: https://github.com/crytic/echidna/wiki
- **Manticore**: https://github.com/trailofbits/manticore
- **Manticore Documentation**: https://manticore.readthedocs.io/
- **Certora**: https://www.certora.com
- **Certora Documentation**: https://docs.certora.com
- **CVL Reference**: https://docs.certora.com/en/latest/docs/cvl/overview.html
- **Aderyn**: https://github.com/Cyfrin/aderyn
- **Mythril**: https://github.com/ConsenSys/mythril
- **Slither**: https://github.com/crytic/slither
- **Trail of Bits**: https://www.trailofbits.com
- **KubernetesJobManager**: `/Users/pwner/Git/ABS/blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py`
