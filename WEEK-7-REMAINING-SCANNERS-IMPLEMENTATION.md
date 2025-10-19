# Week 7 - Remaining Scanners Implementation Guide

**Date**: October 18, 2025
**Goal**: Implement remaining 11 scanners to reach 37/37 tools (100% coverage)
**Current Status**: 26/37 operational (70%)

---

## Existing Docker Images (Already Built)

**These Dockerfiles exist and are ready to build**:
- ✅ `/blocksecops-tool-integration/scanner-images/vyper/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/solana-rust/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/move-prover/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/movesmith/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/cairo/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/certora/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/echidna/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/manticore/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/semgrep/Dockerfile`
- ✅ `/blocksecops-tool-integration/scanner-images/solhint/Dockerfile`

---

## Remaining 11 Scanners to Implement

### Group 1: Vyper Static Analysis (3 tools)
1. **Slither-Vyper** - Vyper-aware Slither analysis
2. **Mythril-Vyper** - Symbolic execution for Vyper
3. **Vyper Lint** - Vyper linting and style checks

### Group 2: Solana Static Analysis (4 tools)
4. **Soteria** - Solana-specific analyzer
5. **Sec3 X-Ray** - LLVM-based analyzer (40+ vulnerability types)
6. **Anchor Verify** - Anchor framework security checks
7. **Clippy** - Rust linter for Solana

### Group 3: Move & Cairo Static Analysis (3 tools)
8. **Move Analyzer** - Official Move static analyzer
9. **Cairo Analyzer (Caracal)** - StarkNet security analyzer (14 detectors)
10. **Vyper Compiler** - Built-in Vyper compiler checks

### Group 4: Additional Tools (1 tool)
11. **MoveSmith** - Move fuzzing tool (deferred from Week 5, Docker exists)

---

## Implementation Plan

### Phase 1: Build Docker Images (You can do in parallel)

**High-Priority Builds** (Start these first - complex builds):
1. **Move Prover** (15-30 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/move-prover
   docker build --no-cache -t move-prover:latest .
   ```

2. **Certora** (10-20 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/certora
   docker build --no-cache -t certora:latest .
   ```

3. **Manticore** (10-15 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/manticore
   docker build --no-cache -t manticore:latest .
   ```

**Medium-Priority Builds** (Moderate complexity):
4. **Echidna** (5-10 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/echidna
   docker build --no-cache -t echidna:latest .
   ```

5. **Cairo** (5-10 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/cairo
   docker build --no-cache -t cairo:latest .
   ```

6. **Vyper** (3-5 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/vyper
   docker build --no-cache -t vyper:latest .
   ```

**Quick Builds** (Simple Python/Node tools):
7. **Semgrep** (2-3 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/semgrep
   docker build --no-cache -t semgrep:latest .
   ```

8. **Solhint** (2-3 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/solhint
   docker build --no-cache -t solhint:latest .
   ```

9. **Solana-Rust** (5-10 min):
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/solana-rust
   docker build --no-cache -t solana-rust:latest .
   ```

10. **MoveSmith** (if attempting):
    ```bash
    cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/movesmith
    docker build --no-cache -t movesmith:latest .
    ```

---

### Phase 2: Create Executor Classes (I'll handle this)

For each scanner, we need to create an executor class in:
`/Users/pwner/Git/ABS/blocksecops-tool-integration/src/services/executors/`

**Pattern**:
```python
# {scanner_name}_executor.py
from typing import Dict, List, Optional
from ..base_executor import BaseExecutor

class {ScannerName}Executor(BaseExecutor):
    """
    Executor for {Scanner Name} - {Description}

    Language: {language}
    Type: {static_analysis|fuzzing|symbolic_execution|formal_verification|linting}
    """

    def __init__(self):
        super().__init__(
            tool_name="{scanner-name}",
            image_name="{scanner-name}:latest",
            language="{language}",
            tool_type="{type}"
        )

    async def execute(
        self,
        contract_code: str,
        contract_path: str,
        options: Optional[Dict] = None
    ) -> Dict:
        """Execute {scanner name} analysis"""

        # Prepare contract files
        await self._prepare_contract(contract_code, contract_path)

        # Build Docker run command
        command = self._build_docker_command(options)

        # Execute container
        result = await self._run_container(command)

        # Parse and normalize results
        findings = await self._parse_results(result)

        return {
            "tool": self.tool_name,
            "language": self.language,
            "findings": findings,
            "summary": self._generate_summary(findings)
        }

    def _build_docker_command(self, options: Optional[Dict]) -> List[str]:
        """Build Docker run command for this tool"""
        cmd = [
            "docker", "run", "--rm",
            "-v", f"{self.contracts_dir}:/contracts:ro",
            "-v", f"{self.output_dir}:/output",
            self.image_name
        ]

        # Add tool-specific options
        if options:
            # Handle tool-specific CLI args
            pass

        return cmd

    async def _parse_results(self, output: str) -> List[Dict]:
        """Parse tool output and convert to standard format"""
        # Tool-specific parsing logic
        pass
```

**Executors Needed**:
1. `vyper_slither_executor.py` - Slither for Vyper
2. `vyper_mythril_executor.py` - Mythril for Vyper
3. `vyper_lint_executor.py` - Vyper linting
4. `soteria_executor.py` - Soteria for Solana
5. `sec3_executor.py` - Sec3 X-Ray for Solana
6. `anchor_verify_executor.py` - Anchor Verify
7. `clippy_executor.py` - Clippy for Solana
8. `move_analyzer_executor.py` - Move Analyzer
9. `caracal_executor.py` - Cairo Analyzer
10. `vyper_compiler_executor.py` - Vyper Compiler checks
11. `movesmith_executor.py` - MoveSmith fuzzer

---

### Phase 3: Database Schema Updates

**Add scanner metadata to database**:

```python
# Migration: Add new scanners

SCANNERS = [
    {
        "id": "vyper-slither",
        "name": "Slither (Vyper)",
        "language": "vyper",
        "type": "static_analysis",
        "version": "0.10.0",
        "description": "Vyper-aware static analysis",
        "is_production_ready": True
    },
    {
        "id": "vyper-mythril",
        "name": "Mythril (Vyper)",
        "language": "vyper",
        "type": "symbolic_execution",
        "version": "0.23.0",
        "description": "Symbolic execution for Vyper",
        "is_production_ready": True
    },
    {
        "id": "vyper-lint",
        "name": "Vyper Lint",
        "language": "vyper",
        "type": "linting",
        "version": "0.3.10",
        "description": "Vyper linting and style checks",
        "is_production_ready": True
    },
    {
        "id": "soteria",
        "name": "Soteria",
        "language": "rust",
        "type": "static_analysis",
        "version": "latest",
        "description": "Solana-specific static analyzer",
        "is_production_ready": True
    },
    {
        "id": "sec3-xray",
        "name": "Sec3 X-Ray",
        "language": "rust",
        "type": "static_analysis",
        "version": "latest",
        "description": "LLVM-based Solana analyzer (40+ detectors)",
        "is_production_ready": True
    },
    {
        "id": "anchor-verify",
        "name": "Anchor Verify",
        "language": "rust",
        "type": "static_analysis",
        "version": "latest",
        "description": "Anchor framework security checks",
        "is_production_ready": True
    },
    {
        "id": "clippy",
        "name": "Clippy",
        "language": "rust",
        "type": "linting",
        "version": "latest",
        "description": "Rust linter for Solana programs",
        "is_production_ready": True
    },
    {
        "id": "move-analyzer",
        "name": "Move Analyzer",
        "language": "move",
        "type": "static_analysis",
        "version": "latest",
        "description": "Official Move static analyzer",
        "is_production_ready": True
    },
    {
        "id": "caracal",
        "name": "Caracal",
        "language": "cairo",
        "type": "static_analysis",
        "version": "latest",
        "description": "Cairo/StarkNet security analyzer (14 detectors)",
        "is_production_ready": True
    },
    {
        "id": "vyper-compiler",
        "name": "Vyper Compiler",
        "language": "vyper",
        "type": "static_analysis",
        "version": "0.3.10",
        "description": "Built-in Vyper compiler checks",
        "is_production_ready": True
    },
    {
        "id": "movesmith",
        "name": "MoveSmith",
        "language": "move",
        "type": "fuzzing",
        "version": "latest",
        "description": "Move fuzzing tool",
        "is_production_ready": False  # Complex build
    }
]
```

---

### Phase 4: Kubernetes Integration

**Update Kubernetes Job Manager**:

```python
# kubernetes_job_manager.py

SCANNER_IMAGE_MAP = {
    # Existing scanners...

    # Vyper
    "vyper-slither": "vyper-slither:latest",
    "vyper-mythril": "vyper-mythril:latest",
    "vyper-lint": "vyper-lint:latest",
    "vyper-compiler": "vyper:latest",

    # Solana
    "soteria": "soteria:latest",
    "sec3-xray": "sec3-xray:latest",
    "anchor-verify": "anchor-verify:latest",
    "clippy": "clippy:latest",

    # Move
    "move-analyzer": "move-analyzer:latest",
    "move-prover": "move-prover:latest",  # Already exists
    "movesmith": "movesmith:latest",

    # Cairo
    "caracal": "caracal:latest",
}
```

---

### Phase 5: Testing

**Test each scanner with sample contracts**:

```python
# test_new_scanners.py
import pytest
from src.services.executors import (
    VyperSlitherExecutor,
    VyperMythrilExecutor,
    # ... etc
)

@pytest.mark.asyncio
async def test_vyper_slither():
    executor = VyperSlitherExecutor()

    contract_code = """
    # @version 0.3.10

    @external
    def vulnerable_transfer(recipient: address, amount: uint256):
        # Missing access control - vulnerability
        send(recipient, amount)
    """

    result = await executor.execute(
        contract_code=contract_code,
        contract_path="test.vy"
    )

    assert result["tool"] == "vyper-slither"
    assert len(result["findings"]) > 0
    assert any(f["category"] == "access_control" for f in result["findings"])
```

---

## Parallel Work Distribution

**You can build Docker images** in another terminal while **I create executor classes** in parallel.

### Your Terminal (Docker Builds):
Start with the longest builds first:
1. Move Prover (~20 min) - START THIS FIRST
2. Certora (~15 min)
3. Manticore (~12 min)
4. Others can run sequentially (~5 min each)

**Total Docker build time**: ~60-90 minutes if done serially, or ~30 minutes if you run 3-4 in parallel

### My Work (Executor Classes):
While you're building Docker images, I'll:
1. Create 11 executor classes (~30 min total, 2-3 min each)
2. Update database migration with scanner metadata (~5 min)
3. Update Kubernetes job manager (~5 min)
4. Create integration tests (~15 min)
5. Update documentation (~10 min)

**Total my work**: ~65 minutes

---

## Success Criteria

**When Complete**:
- [x] 11 Docker images built and tagged
- [x] 11 executor classes created
- [x] Database migration run with new scanner metadata
- [x] Kubernetes integration tested
- [x] Sample contracts tested with each scanner
- [x] Documentation updated
- [x] **37/37 tools operational (100% coverage)**

---

## Build Order Recommendation

**Option 1: Serial (Safer)**:
Build one at a time, verify each works before moving to next.

**Option 2: Parallel (Faster)**:
Open 3-4 terminals and build multiple Docker images simultaneously:
- Terminal 1: Move Prover
- Terminal 2: Certora
- Terminal 3: Manticore
- Terminal 4: Echidna + Cairo + Vyper + Semgrep + Solhint

**Recommended**: Option 2 (parallel) to save time

---

## Dockerfile Locations Quick Reference

```
/Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/
├── vyper/                  # Vyper compiler + lint
├── solana-rust/           # Solana analyzers
├── move-prover/           # Move Prover ← BUILD THIS FIRST
├── movesmith/             # MoveSmith (optional)
├── cairo/                 # Cairo analyzer
├── certora/               # Certora verifier
├── echidna/               # Echidna fuzzer
├── manticore/             # Manticore symbolic execution
├── semgrep/               # Semgrep SAST
└── solhint/               # Solhint linter
```

---

## Next Steps

1. **You**: Start building Docker images (prioritize Move Prover first)
2. **Me**: Create executor classes while you build
3. **Both**: Test integration once builds complete
4. **Both**: Update documentation and create progress report

Let me know when you're ready to start, and I'll begin creating the executor classes!

---

**Last Updated**: October 18, 2025
**Status**: Ready to begin
**Target Completion**: Today (2-3 hours total with parallel work)
