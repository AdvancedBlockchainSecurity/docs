# Framework Support (Phase 3.2)

**Status**: COMPLETE - Phase 3.2 Fully Complete
**Start Date**: November 25, 2025
**Week 2 Completed**: November 25, 2025
**Week 3 Completed**: November 27, 2025
**Week 4 Completed**: November 27, 2025 (Documentation)

## Overview

Phase 3.2 enables Apogee to natively support Foundry and Hardhat project structures, allowing professional developers to upload their projects without flattening contracts or manual configuration.

## Components

### 1. Framework Detector

**File**: `src/infrastructure/storage/framework_detector.py`

Detects the framework type based on project files:

```python
from src.infrastructure.storage.framework_detector import FrameworkDetector, FrameworkType

# Detect framework from file list
files = ["foundry.toml", "src/Token.sol", "lib/forge-std/src/Test.sol"]
framework = FrameworkDetector.detect(files)
# Returns: FrameworkType.FOUNDRY
```

**Detection Priority**:
1. **Foundry** - `foundry.toml` present
2. **Hardhat** - `hardhat.config.js` or `hardhat.config.ts` present
3. **Plain** - Neither present (default)

### 2. Config Parsers

#### Foundry Config Parser

**File**: `src/infrastructure/storage/config_parsers/foundry.py`

Parses `foundry.toml` and `remappings.txt` files:

```python
from src.infrastructure.storage.config_parsers.foundry import FoundryConfigParser

config = FoundryConfigParser.parse(foundry_toml_content, remappings_content)

# Access parsed values
print(config.solc_version)      # "0.8.20"
print(config.src_dir)           # "src"
print(config.remappings)        # ["@openzeppelin/=lib/openzeppelin-contracts/"]
print(config.optimizer_enabled) # True
print(config.optimizer_runs)    # 200
```

**Parsed Fields**:
- `solc_version` - Solidity compiler version
- `src_dir` - Source directory (default: "src")
- `test_dir` - Test directory (default: "test")
- `out_dir` - Output directory (default: "out")
- `libs` - Library directories (default: ["lib"])
- `remappings` - Import remappings
- `optimizer_enabled` - Optimizer status
- `optimizer_runs` - Optimizer runs
- `via_ir` - Via IR compilation flag
- `evm_version` - EVM target version
- `ffi` - FFI enabled flag
- `fuzz_runs` - Fuzz test iterations
- `invariant_runs` - Invariant test iterations

#### Hardhat Config Parser

**File**: `src/infrastructure/storage/config_parsers/hardhat.py`

MVP regex-based parser for `hardhat.config.js`:

```python
from src.infrastructure.storage.config_parsers.hardhat import HardhatConfigParser

config = HardhatConfigParser.parse(hardhat_config_content, package_json_content)

# Access parsed values
print(config.solc_version)      # "0.8.20"
print(config.sources_path)      # "./contracts"
print(config.optimizer_enabled) # True
print(config.dependencies)      # {"@openzeppelin/contracts": "^5.0.0"}
```

**Parsed Fields**:
- `solc_version` - Solidity compiler version
- `sources_path` - Source directory
- `tests_path` - Test directory
- `optimizer_enabled` - Optimizer status
- `optimizer_runs` - Optimizer runs
- `evm_version` - EVM target version
- `dependencies` - npm dependencies from package.json

**Note**: Week 4 will implement a Node.js subprocess parser for full accuracy.

### 3. Import Remapper (Week 2)

**File**: `src/infrastructure/storage/import_remapper.py`

Resolves remapped imports (e.g., `@openzeppelin/`) to actual file paths:

```python
from src.infrastructure.storage.import_remapper import ImportRemapper

# Create remapper with Foundry remappings
remapper = ImportRemapper([
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "forge-std/=lib/forge-std/src/"
])

# Resolve an import path
resolved = remapper.resolve("@openzeppelin/contracts/token/ERC20/ERC20.sol")
# Returns: "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol"

# Extract imports from Solidity source
imports = remapper.extract_imports(solidity_source)
# Returns: List[ImportStatement]
```

**Key Features**:
- Longest-prefix matching for overlapping remappings
- Extracts all import types: simple, named, wildcard, aliased
- Factory methods: `from_foundry_config()`, `for_hardhat()`

### 4. Dependency Resolver (Week 2)

**File**: `src/infrastructure/storage/dependency_resolver.py`

Recursively resolves all dependencies, extracting only files that are actually imported:

```python
from src.infrastructure.storage.dependency_resolver import DependencyResolver

# Create resolver for Foundry project
resolver = DependencyResolver.for_foundry(
    base_path=Path("/path/to/project"),
    remappings=["@openzeppelin/=lib/openzeppelin-contracts/"],
    max_files=25  # Free tier limit
)

# Resolve dependencies from entry files
result = resolver.resolve_dependencies([Path("src/Token.sol")])

# result.dependencies - All resolved files
# result.user_files - User's source files only
# result.lib_files - Library files only
# result.truncated - True if file limit reached
# result.circular_imports - Detected circular imports
```

**Key Features**:
- Recursive transitive dependency resolution
- Circular import detection and handling
- Tier-based file limit enforcement (Free=25, Pro=100, Enterprise=unlimited)
- Smart filtering: 200+ file OpenZeppelin → ~12 files extracted

### 5. Archive Extractor Integration

**File**: `src/infrastructure/storage/archive_extractor.py`

The `ArchiveExtractor` class now supports framework-aware extraction:

```python
from src.infrastructure.storage.archive_extractor import ArchiveExtractor
from pathlib import Path

# Extract with framework detection
result = ArchiveExtractor.extract_with_framework(
    file_path=Path("/path/to/archive.zip"),
    temp_dir=Path("/tmp/extract"),
    include_dependencies=False  # Week 2 will add dependency extraction
)

# Access results
print(result.framework)     # FrameworkType.FOUNDRY
print(result.config)        # {"solc_version": "0.8.20", ...}
print(result.main_file_path) # "src/Token.sol"
print(len(result.files))    # Number of extracted files
```

**ExtractedArchive Fields**:
- `files` - List of `ExtractedFile` objects
- `framework` - Detected `FrameworkType`
- `config` - Parsed framework configuration (dict)
- `main_file_path` - Path to main contract file
- `config_files` - Dict of config file contents

#### Smart Dependency Extraction (Week 2)

```python
# Extract with smart dependency filtering
result = ArchiveExtractor.extract_with_smart_dependencies(
    file_path=Path("/path/to/archive.zip"),
    temp_dir=Path("/tmp/extract"),
    max_files=25  # Tier-based limit
)

# Only imported files are extracted, not entire lib/
# OpenZeppelin project (200+ files) → ~12 files extracted
```

### 6. Database Schema

**Migration**: `alembic/versions/20251125_1813-add_framework_support_columns.py`

Added columns to `contracts` table:
- `framework` (VARCHAR(50)) - Framework type: 'foundry', 'hardhat', 'plain'
- `framework_config` (JSONB) - Parsed framework configuration

**Index**: Partial index on `framework` column for efficient queries:
```sql
CREATE INDEX idx_contracts_framework ON contracts (framework)
WHERE framework IS NOT NULL;
```

### 7. SQLAlchemy Model

**File**: `src/infrastructure/database/models.py`

```python
class ContractModel(Base):
    # ... existing fields ...

    # Framework support fields (Phase 3.2)
    framework: Mapped[Optional[str]] = mapped_column(
        String(50), nullable=True, index=True
    )
    framework_config: Mapped[Optional[Dict[str, Any]]] = mapped_column(
        JSONB, nullable=True
    )
```

## API Response Enhancement

**Contract GET Response** (after Phase 3.2 complete):
```json
{
  "id": "uuid",
  "name": "MyToken",
  "framework": "foundry",
  "framework_config": {
    "solc_version": "0.8.20",
    "src_dir": "src",
    "remappings": [
      "@openzeppelin/=lib/openzeppelin-contracts/",
      "forge-std/=lib/forge-std/src/"
    ]
  },
  "is_multi_file": true,
  "file_count": 25,
  "main_file_path": "src/Token.sol"
}
```

## Phase 3.2 Timeline

### Week 1: Framework Detection & Config Parsing (COMPLETE)
- [x] FrameworkDetector implementation
- [x] FoundryConfigParser implementation
- [x] HardhatConfigParser MVP (regex-based)
- [x] Database migration
- [x] Model updates
- [x] Test project samples

### Week 2: Import Resolution & Dependencies (COMPLETE)
- [x] ImportRemapper implementation
- [x] DependencyResolver with smart filtering
- [x] Recursive import resolution
- [x] Tier-based file count enforcement
- [x] Unit tests (46 tests passing)
- [x] Upload endpoint integration
- [x] FileUploadResponse schema updated with framework fields
- [x] Archive extractor tests updated (42 tests passing)
- [x] API response includes framework and framework_config

### Week 3: Dashboard UI & Bug Fixes (COMPLETE)
- [x] Dashboard FrameworkBadge component for contracts list
- [x] Framework badge shows: Foundry (orange), Hardhat (yellow), Single File (gray)
- [x] API ContractResponse schema updated with `framework`, `framework_config`, `is_project` fields
- [x] Bug fix: Archive extractor now excludes `__MACOSX` metadata directories
- [x] Bug fix: Test directory filtering now only skips actual `test/` directories, not paths containing "test"
- [x] ContractDetail page layout padding fix
- [x] Slither executor for Foundry/Hardhat mode
- [x] Aderyn executor for Foundry support
- [x] Echidna executor for project-based fuzzing
- [x] Orchestration service v0.8.1 deployed with multi-file project support
- [x] E2E test passed: Foundry project scan completed successfully

### Week 4: Hardhat Enhancement & Documentation (COMPLETE)
- [ ] Node.js subprocess Hardhat parser - **Deferred to future enhancement**
- [ ] Plugin detection support - **Deferred to future enhancement**
- [x] User documentation created:
  - `guides/uploading-foundry-projects.md`
  - `guides/uploading-hardhat-projects.md`
  - `guides/framework-support-matrix.md`
- [x] Dashboard UI framework badges (moved to Week 3, completed)

## Dashboard UI Components (Week 3)

### FrameworkBadge Component

**File**: `blocksecops-dashboard/src/components/contracts/FrameworkBadge.tsx`

Displays the framework type in the contracts list:

```tsx
import FrameworkBadge from '../components/contracts/FrameworkBadge';

// Usage in contracts list
<FrameworkBadge
  framework={contract.framework}  // 'foundry' | 'hardhat' | 'plain' | null
  fileCount={contract.file_count}
  showFileCount={true}
/>
```

**Visual Styles**:
- **Foundry**: Orange badge with anvil icon
- **Hardhat**: Yellow badge with helmet icon
- **Single File**: Gray badge with file icon (shown for all single-file contracts)

### Contract Type Display

The "Type" column in the contracts list now shows:
- Framework badge for multi-file projects (Foundry/Hardhat)
- "Single File" badge for single-file contracts
- File count displayed for multi-file projects (e.g., "Foundry (2 files)")

### API Schema Updates

**ContractResponse** now includes:
```python
class ContractResponse(BaseModel):
    # ... existing fields ...
    is_project: bool = False          # Alias for is_multi_file
    framework: Optional[str] = None   # 'foundry', 'hardhat', 'plain'
    framework_config: Optional[Dict[str, Any]] = None
```

**Frontend Contract Interface**:
```typescript
interface Contract {
  // ... existing fields ...
  is_project?: boolean;
  framework?: 'foundry' | 'hardhat' | 'plain' | null;
  framework_config?: FrameworkConfig;
}
```

## Test Projects

Sample projects for testing are located at:
- `/Users/pwner/Git/ABS/TaskDocs-Apogee/phases/03-phase-3.2-project-structure-support/test-projects/foundry-sample/`
- `/Users/pwner/Git/ABS/TaskDocs-Apogee/phases/03-phase-3.2-project-structure-support/test-projects/hardhat-sample/`

## Dependencies

**New Python Dependency**:
```
tomli>=2.0.1,<3.0.0  # TOML parser for foundry.toml
```

## Related Documentation

- Phase 3.2 README: `/Users/pwner/Git/ABS/TaskDocs-Apogee/phases/03-phase-3.2-project-structure-support/README.md`
- Implementation Plan: `/Users/pwner/Git/ABS/TaskDocs-Apogee/phases/03-phase-3.2-project-structure-support/IMPLEMENTATION-PLAN.md`
- Database Schema: `/Users/pwner/Git/ABS/docs/database/SCHEMA.md`

---

**Document Version**: 1.5.0
**Last Updated**: November 27, 2025 (Phase 3.2 Complete)
**Author**: Engineering Team

## Changelog

### v1.5.0 (November 27, 2025)
- Phase 3.2 fully complete
- Week 4 documentation created:
  - `guides/uploading-foundry-projects.md` - User guide for Foundry uploads
  - `guides/uploading-hardhat-projects.md` - User guide for Hardhat uploads
  - `guides/framework-support-matrix.md` - Scanner compatibility matrix
- Node.js subprocess Hardhat parser deferred to future enhancement
- Plugin detection support deferred to future enhancement

### v1.4.0 (November 27, 2025)
- Week 3 completed: Scanner Integration & Dashboard UI
- Orchestration service v0.8.1 deployed with multi-file project support
- E2E test passed: Foundry project scan completed successfully
- All scanner executors updated for project mode
- Phase 3.2 core functionality complete (Week 4: documentation only)

### v1.3.0 (November 26, 2025)
- Week 3 started: Dashboard UI & Bug Fixes
- Added FrameworkBadge component documentation
- Added API schema updates for framework fields
- Documented bug fixes:
  - Archive extractor excludes `__MACOSX` directories
  - Test directory filtering fixed (only skips actual test/ directories)
  - ContractDetail page padding fix
- Updated timeline: Dashboard UI badges moved from Week 4 to Week 3 (completed)

### v1.2.0 (November 25, 2025)
- Week 2 fully complete
- Upload endpoint integrated with smart dependency extraction
- FileUploadResponse schema includes framework and framework_config fields
- Archive extractor tests updated for Phase 3.2 (42 tests)
- Total unit tests: 88 (46 Week 2 + 42 archive extractor)
- Feature test checklists created at `/docs/feature-tests/`

### v1.1.0 (November 25, 2025)
- Added ImportRemapper documentation
- Added DependencyResolver documentation
- Added extract_with_smart_dependencies() method
- Updated Week 2 task status to CORE COMPLETE
- 46 unit tests passing

### v1.0.0 (November 25, 2025)
- Initial documentation with Week 1 components
- Framework detection, config parsers, database schema
