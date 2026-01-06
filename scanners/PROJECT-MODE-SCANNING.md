# Project Mode Scanning

**Version:** 1.0.0
**Last Updated:** November 29, 2025
**Phase:** 3.2 - Project Structure Support
**Status:** Production Ready

---

## Overview

Project Mode enables scanning of complete Foundry and Hardhat projects with proper import resolution, remapping support, and multi-file analysis. This is essential for scanning contracts that depend on external libraries like OpenZeppelin.

---

## Supported Frameworks

| Framework | Config File | Remappings | Status |
|-----------|-------------|------------|--------|
| **Foundry** | `foundry.toml` | `remappings` array or `remappings.txt` | ✅ Full Support |
| **Hardhat** | `hardhat.config.js/ts` | `package.json` dependencies | ✅ Full Support |
| **Plain** | None | None | ✅ Single-file mode |

---

## Scanners with Project Mode

| Scanner | Foundry | Hardhat | Implementation |
|---------|---------|---------|----------------|
| **Slither** | ✅ | ✅ | `solidity_scanners.py:50-89` |
| **Aderyn** | ✅ | ❌ | `solidity_scanners.py:515-530` |
| **SolidityDefend** | ✅ | ✅ | `solidity_scanners.py:1537-1568` |
| **Echidna** | ✅ | ❌ | `solidity_scanners.py:338-377` |

---

## Architecture

### Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                      Upload Phase                                 │
├──────────────────────────────────────────────────────────────────┤
│  1. User uploads .zip/.tar.gz archive via POST /upload           │
│                                                                  │
│  2. ArchiveExtractor.extract_with_smart_dependencies()           │
│     ├── Extracts archive contents                                │
│     ├── FrameworkDetector.detect() → "foundry"|"hardhat"|"plain" │
│     ├── FoundryConfigParser.parse() → extracts remappings        │
│     └── DependencyResolver → extracts only imported files        │
│                                                                  │
│  3. Database Storage                                             │
│     ├── contracts.framework = "foundry"                          │
│     ├── contracts.framework_config = {"remappings": [...]}       │
│     └── project_files table with all files                       │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Scan Phase                                   │
├──────────────────────────────────────────────────────────────────┤
│  1. scan_tasks_sync.py loads from database                       │
│     ├── project_files list                                       │
│     ├── framework ("foundry")                                    │
│     └── framework_config (with remappings)                       │
│                                                                  │
│  2. ScannerOrchestrator creates ScannerContext                   │
│     ├── is_project = True                                        │
│     ├── project_files = [ProjectFile(...), ...]                  │
│     ├── framework = "foundry"                                    │
│     └── framework_config = {"remappings": [...]}                 │
│                                                                  │
│  3. ScannerExecutor.execute(context)                             │
│     a) context.write_project_files()                             │
│        → Writes all files to temp_dir preserving structure       │
│     b) context.write_foundry_config()                            │
│        → Creates foundry.toml with remappings                    │
│     c) Executes scanner on project root                          │
└──────────────────────────────────────────────────────────────────┘
```

---

## Config Parsing

### Foundry Config (`foundry.toml`)

**Location:** `blocksecops-api-service/src/infrastructure/storage/config_parsers/foundry.py`

**Parsed Fields:**
- `solc_version` - Solidity compiler version
- `src_dir` - Source directory (default: "src")
- `test_dir` - Test directory (default: "test")
- `out_dir` - Output directory (default: "out")
- `libs` - Library directories (default: ["lib"])
- `remappings` - Import remapping rules
- `optimizer_enabled` - Optimizer settings
- `evm_version` - Target EVM version

**Example foundry.toml:**
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.20"
remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "forge-std/=lib/forge-std/src/"
]
```

### Hardhat Config (`hardhat.config.js`)

**Location:** `blocksecops-api-service/src/infrastructure/storage/config_parsers/hardhat.py`

**Parsed Fields:**
- `solc_version` - Solidity compiler version
- `source_dir` - Source directory (default: "contracts")
- `test_dir` - Test directory (default: "test")
- `remappings` - Derived from package.json dependencies

**Automatic Remappings:**
```python
{
    "@openzeppelin/contracts/": "node_modules/@openzeppelin/contracts/",
    "@chainlink/contracts/": "node_modules/@chainlink/contracts/",
}
```

---

## Scanner Execution

### ScannerContext

**Location:** `blocksecops-orchestration/src/blocksecops_orchestration/scanners/base.py`

```python
@dataclass
class ScannerContext:
    scan_id: UUID
    contract_id: UUID
    contract_name: str
    source_code: Optional[str]
    temp_dir: Path
    timeout: int = 300

    # Project mode fields (Phase 3.2)
    is_project: bool = False
    project_files: Optional[List[ProjectFile]] = None
    framework: Optional[str] = None  # "foundry" | "hardhat" | "plain"
    framework_config: Optional[Dict[str, Any]] = None
    main_file_path: Optional[str] = None
```

### Key Methods

**write_project_files()** - Writes all project files to temp directory:
```python
def write_project_files(self) -> Path:
    for pf in self.project_files:
        file_path = self.temp_dir / pf.path
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(pf.content)
    return self.temp_dir
```

**write_foundry_config()** - Creates foundry.toml with remappings:
```python
def write_foundry_config(self) -> None:
    config = self.framework_config or {}
    remappings = config.get("remappings", [])

    lines = [
        "[profile.default]",
        f'src = "{config.get("src", "src")}"',
        "out = 'out'",
        "libs = ['lib']",
        f'solc_version = "{config.get("solc_version", "0.8.20")}"',
    ]

    if remappings:
        remapping_lines = ", ".join(f'"{r}"' for r in remappings)
        lines.append(f"remappings = [{remapping_lines}]")

    foundry_toml.write_text("\n".join(lines) + "\n")
```

---

## Scanner-Specific Implementation

### SlitherExecutor

```python
if is_project_mode:
    context.write_project_files()

    if context.framework == "foundry":
        context.write_foundry_config()
    elif context.framework == "hardhat":
        context.write_hardhat_config()

    command = ["slither", str(context.temp_dir), "--json", "-"]
```

### SolidityDefendExecutor

```python
if is_project_mode:
    context.write_project_files()

    if context.framework == "foundry":
        context.write_foundry_config()
    elif context.framework == "hardhat":
        context.write_hardhat_config()

    command = [
        "soliditydefend",
        "-p", str(context.temp_dir),
        "-f", "json",
        "--no-exit-code",
    ]

    if context.framework and context.framework != "plain":
        command.extend(["--framework", context.framework])
```

### AderynExecutor

```python
if is_project_mode:
    context.write_project_files()
    context.write_foundry_config()  # Aderyn requires foundry.toml

    command = ["aderyn", str(context.temp_dir), "-o", str(output_file)]
```

---

## Database Schema

### contracts table

| Column | Type | Description |
|--------|------|-------------|
| `framework` | VARCHAR | "foundry", "hardhat", or "plain" |
| `framework_config` | JSONB | Config with remappings, solc version, etc. |
| `main_file_path` | VARCHAR | Path to primary contract file |

### project_files table

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `contract_id` | UUID | FK to contracts |
| `file_path` | VARCHAR | Relative path (e.g., "src/Token.sol") |
| `content` | TEXT | File content |
| `file_type` | VARCHAR | "source", "library", "config" |
| `is_main_file` | BOOLEAN | True for primary contract |
| `created_at` | TIMESTAMPTZ | Creation timestamp |

---

## Remappings

### Common Remapping Patterns

**OpenZeppelin:**
```
@openzeppelin/=lib/openzeppelin-contracts/
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
```

**Forge Standard Library:**
```
forge-std/=lib/forge-std/src/
```

**Solmate:**
```
solmate/=lib/solmate/src/
```

**Hardhat (node_modules):**
```
@openzeppelin/contracts/=node_modules/@openzeppelin/contracts/
@chainlink/contracts/=node_modules/@chainlink/contracts/
```

### How Remappings Are Applied

1. **Upload**: `FoundryConfigParser` extracts remappings from `foundry.toml`
2. **Storage**: Stored in `contracts.framework_config` JSON field
3. **Scan**: `write_foundry_config()` writes remappings to temp `foundry.toml`
4. **Execution**: Scanner reads `foundry.toml` and resolves imports

---

## Troubleshooting

### Import Resolution Errors

**Symptom:** Scanner fails with "Source not found" errors

**Causes:**
- Missing remappings in foundry.toml
- Library files not extracted
- Incorrect remapping paths

**Solution:**
1. Check `framework_config` in database contains remappings
2. Verify library files are in `project_files` table
3. Check remapping paths match actual file locations

### Framework Not Detected

**Symptom:** Contract treated as single-file when it's a project

**Causes:**
- foundry.toml/hardhat.config.js not in archive root
- Archive structure incorrect

**Solution:**
1. Ensure config file is at archive root
2. Check FrameworkDetector logs for detection results

### Missing Dependencies

**Symptom:** Only main contract extracted, not libraries

**Causes:**
- DependencyResolver couldn't resolve imports
- Import paths use unsupported remapping format

**Solution:**
1. Verify remappings in foundry.toml
2. Check import statements match remapping patterns

---

## Testing

### Manual Testing Checklist

- [ ] Upload Foundry project with OpenZeppelin imports
- [ ] Verify framework detected as "foundry"
- [ ] Verify remappings extracted correctly
- [ ] Run scan with Slither
- [ ] Run scan with SolidityDefend
- [ ] Run scan with Aderyn
- [ ] Verify no import resolution errors
- [ ] Verify vulnerability findings include correct file paths

### Test Project Structure

```
my-project/
├── foundry.toml
├── src/
│   └── MyToken.sol (imports @openzeppelin/contracts/token/ERC20/ERC20.sol)
├── lib/
│   └── openzeppelin-contracts/
│       └── contracts/
│           └── token/
│               └── ERC20/
│                   └── ERC20.sol
└── test/
    └── MyToken.t.sol
```

---

## Related Documentation

- [Scanner README](README.md)
- [Scanner Integration Guide](SCANNER-INTEGRATION-GUIDE.md)
- [Archive Extractor](../../blocksecops-api-service/src/infrastructure/storage/archive_extractor.py)
- [Config Parsers](../../blocksecops-api-service/src/infrastructure/storage/config_parsers/)
- [Scanner Executors](../../blocksecops-orchestration/src/blocksecops_orchestration/scanners/solidity_scanners.py)

---

## Version History

### v1.0.0 (November 29, 2025)
- Initial documentation
- Foundry support verified
- Hardhat support verified
- Slither, Aderyn, SolidityDefend, Echidna project mode confirmed
