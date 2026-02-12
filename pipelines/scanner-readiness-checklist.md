# Scanner Readiness Checklist

Operational checklist for verifying any scanner (new or existing) is production-ready.

## Pre-Integration Checklist

### 1. Executor Implementation

- [ ] Executor class exists in `scanners/solidity_scanners.py` (or language-specific file)
- [ ] `scanner_id` property returns a unique, lowercase identifier
- [ ] `is_available()` checks for the tool binary using `shutil.which()` or equivalent
- [ ] `execute()` returns a `ScannerResult` with stdout, stderr, exit_code
- [ ] Timeout is respected via `context.timeout` (no hardcoded values)
- [ ] Compiler/tool versions are derived from contract pragmas, not hardcoded

### 2. Parser Implementation

- [ ] Parser class exists in `parsers/solidity_parsers.py` (or language-specific file)
- [ ] `scanner_id` property matches the executor's `scanner_id` exactly
- [ ] `parse()` converts raw output to a list of structured findings
- [ ] Each finding has: title, severity, description, and source location
- [ ] Parser handles empty output and malformed JSON gracefully

### 3. Registry Registration

- [ ] Executor class is imported in `scanners/registry.py`
- [ ] `self.register(<ExecutorClass>())` is called in `_register_default_scanners()`
- [ ] Parser class is imported in `parsers/registry.py`
- [ ] `self.register(<ParserClass>())` is called in `_register_default_parsers()`

### 4. Default Execution List

- [ ] Scanner ID appears in `requested_scanners` list in `tasks/scan_tasks_sync.py`
- [ ] If intentionally excluded from defaults, reason is documented in a code comment

### 5. Testing

- [ ] Scanner ID is included in `EXPECTED_SOLIDITY_SCANNERS` in `test_registry_completeness.py`
- [ ] Scanner ID is included in `DEFAULT_SOLIDITY_SCANNER_LIST` in `test_registry_completeness.py`
- [ ] Integration tests in `test_all_scanners.py` include the scanner ID in parametrized lists
- [ ] `expected_scanners` set and count assertion in `test_all_scanners_registered` are updated

### 6. Infrastructure

- [ ] Tool binary or Docker image is available in the orchestration container
- [ ] Tool version is pinned in `Dockerfile` or `requirements.txt`
- [ ] Resource limits (memory, CPU, timeout) are configured appropriately

### 7. Frontend (if applicable)

- [ ] Scanner ID is added to `VALID_SCANNERS` in the frontend config
- [ ] Display label is added to `SCANNER_LABELS` mapping
- [ ] Scanner appears in the UI scanner selection dropdown

## Current Scanner Status Matrix

| Scanner | ID | Executor | Parser | Exec Reg | Parser Reg | Default List | Status |
|---------|----|----------|--------|----------|------------|--------------|--------|
| Slither | `slither` | Yes | Yes | Yes | Yes | Yes | OK |
| Aderyn | `aderyn` | Yes | Yes | Yes | Yes | Yes | OK |
| Solhint | `solhint` | Yes | Yes | Yes | Yes | Yes | OK |
| SolidityDefend | `soliditydefend` | Yes | Yes | Yes | Yes | Yes | OK |
| Semgrep | `semgrep` | Yes | Yes | Yes | Yes | Yes | OK |
| Wake | `wake` | Yes | Yes | Yes | Yes | Yes | OK |
| Mythril | `mythril` | Yes | Yes | Yes | Yes | Yes | OK |
| Echidna | `echidna` | Yes | Yes | Yes | Yes | Yes | OK |
| Halmos | `halmos` | Yes | Yes | Yes | Yes | Yes | OK |
| Medusa | `medusa` | Yes | Yes | Yes | Yes | Yes | OK |
| Foundry Fuzz | `foundry-fuzz` | Yes | Yes | Yes | Yes | Yes | OK |
| 4naly3er | `4naly3er` | Yes | Yes | Yes | Yes | Yes | OK |

## Adding a New Scanner

1. Implement executor and parser classes following existing patterns
2. Walk through every item in this checklist
3. Run `pytest tests/unit/scanners/test_registry_completeness.py -v` to verify registrations
4. Run integration tests to verify end-to-end execution
5. Update the status matrix above
