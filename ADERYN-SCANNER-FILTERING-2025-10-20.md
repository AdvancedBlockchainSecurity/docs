# Aderyn Scanner Filtering Implementation

**Date**: October 20, 2025
**Version**: blocksecops-orchestration 0.7.4
**Status**: ✅ Code Complete - Pending Testing
**Feature**: Scanner Filtering Based on Contract Type

---

## Summary

Implemented scanner filtering to prevent Aderyn from attempting to scan single-file contracts. Aderyn requires a full Foundry/Hardhat project structure and fails on single .sol files with "Not a directory" errors. The solution adds a database column to track contract type and filters scanners at runtime based on their requirements.

---

## Problem Statement

### Original Issue
When scanning contract `86f9a16f-7896-4115-b321-adf9db382682`, Aderyn scanner failed with:
```
Error making context: Not a directory (os error 20)
```

### Root Cause
- Aderyn is designed for Foundry/Hardhat projects with directory structure
- Contracts are mounted as single files via ConfigMap in Kubernetes
- Aderyn cannot process single .sol files - needs full project directory
- No mechanism to filter scanners based on compatibility

### Initial User Request
1. Add error message when user tries to scan single file with Aderyn
2. Add note to scanner selection modal

### Final Approach (Better Solution)
Remove Aderyn from single-file scans entirely - Aderyn should only be used when there's a full project directory.

---

## Implementation

### Architecture Decision

**Option 1** (Chosen): Add `is_project` column to contracts table
- ✅ Contract type is inherent property of the contract
- ✅ Database stores the truth, not passed as parameter
- ✅ Future features will also need this information
- ✅ Clean separation of concerns

**Option 2** (Rejected): Pass `is_project` as scan parameter
- ❌ Requires passing flag through multiple layers
- ❌ Not stored persistently
- ❌ Prone to inconsistency

### Database Schema Change

```sql
ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS is_project BOOLEAN NOT NULL DEFAULT FALSE;
```

**Migration Notes:**
- All existing contracts default to `FALSE` (single-file)
- Future project uploads will set to `TRUE`
- Column documented in `/Users/pwner/Git/ABS/docs/database/MANUAL-FIXES.md`

### Code Changes

#### 1. Database Model
**File:** `blocksecops-orchestration/src/blocksecops_orchestration/models/models.py`
**Lines:** 86-88

```python
is_project: Mapped[bool] = mapped_column(
    Boolean, nullable=False, default=False, server_default="false"
)
```

#### 2. Scanner Base Class
**File:** `blocksecops-orchestration/src/blocksecops_orchestration/scanners/base.py`
**Lines:** 36-39

```python
def __init__(self, scanner_id: str, timeout: int = 300, requires_project: bool = False):
    self.scanner_id = scanner_id
    self.timeout = timeout
    self.requires_project = requires_project  # True if scanner needs full project structure
```

#### 3. Aderyn Scanner Configuration
**File:** `blocksecops-orchestration/src/blocksecops_orchestration/scanners/solidity_scanners.py`
**Lines:** 366-376

```python
class AderynExecutor(ScannerExecutor):
    """
    Executor for Aderyn (Cyfrin) static analyzer.

    Note: Aderyn requires a full Foundry/Hardhat project structure and cannot
    analyze single Solidity files. It will be automatically excluded from
    single-file scans.
    """

    def __init__(self, timeout: int = 300):
        super().__init__(scanner_id="aderyn", timeout=timeout, requires_project=True)
```

#### 4. Scanner Filtering Logic
**File:** `blocksecops-orchestration/src/blocksecops_orchestration/tasks/scan_tasks_sync.py`
**Lines:** 181-210

```python
# Filter scanner IDs based on contract type
requested_scanners = ["slither", "solhint", "echidna", "aderyn"]
registry = get_scanner_registry()

# Remove scanners that require project structure if this is a single-file contract
scanner_ids = []
if not contract.is_project:
    for scanner_id in requested_scanners:
        executor = registry.get(scanner_id)
        if executor and not executor.requires_project:
            scanner_ids.append(scanner_id)
        elif executor and executor.requires_project:
            logger.info(
                "scanner_skipped_single_file",
                scanner_id=scanner_id,
                scan_id=scan_id,
                reason="Scanner requires full project structure, contract is single-file",
            )
else:
    # For project-based contracts, all scanners are available
    scanner_ids = requested_scanners

logger.info(
    "executing_scanner_orchestrator",
    scan_id=scan_id,
    contract_id=str(contract.id),
    contract_name=contract.name,
    is_project=contract.is_project,
    scanners=scanner_ids,
)
```

#### 5. API Schema Updates
**File:** `blocksecops-orchestration/src/blocksecops_orchestration/api/schemas/scanner.py`
**Line:** 15

```python
requires_project: bool = Field(..., description="Whether scanner requires full project structure (not compatible with single files)")
```

**File:** `blocksecops-orchestration/src/blocksecops_orchestration/api/routes/scanners.py`
**Lines:** 110, 151

```python
scanner_info = ScannerInfo(
    scanner_id=scanner_id,
    name=metadata["name"],
    description=metadata["description"],
    finding_types=metadata["finding_types"],
    is_available=is_available,
    requires_project=executor.requires_project,  # Added
    timeout=executor.timeout,
)
```

---

## Testing

### Manual Testing Steps

1. **Deploy Updated Service**
   ```bash
   # Build Docker image
   cd /Users/pwner/Git/ABS/blocksecops-orchestration
   docker build -t blocksecops-orchestration:0.7.4 .

   # Load to minikube
   minikube image load blocksecops-orchestration:0.7.4

   # Apply manifests
   kubectl apply -k k8s/overlays/local/orchestration/

   # Wait for rollout
   kubectl rollout status -n orchestration-local deployment/orchestration
   ```

2. **Verify API Schema**
   ```bash
   kubectl exec -n orchestration-local deployment/orchestration -c orchestration-api -- \
     curl -s http://localhost:8004/api/v1/scanners | jq '.scanners[] | select(.scanner_id=="aderyn")'

   # Expected output should include:
   # "requires_project": true
   ```

3. **Trigger Scan on Single-File Contract**
   - Navigate to http://127.0.0.1:3000/contracts/86f9a16f-7896-4115-b321-adf9db382682
   - Configure new scan
   - Verify Aderyn is NOT in the list of scanners that execute

4. **Check Worker Logs**
   ```bash
   kubectl logs -n orchestration-local deployment/orchestration -c orchestration-worker --tail=50 | grep scanner_skipped

   # Expected log entry:
   # scanner_skipped_single_file scanner_id=aderyn reason="Scanner requires full project structure, contract is single-file"
   ```

5. **Verify Scan Completes Successfully**
   - Check that scan completes with only: slither, solhint, echidna
   - Verify no Aderyn pods are created
   - Confirm no "Not a directory" errors

---

## Files Modified

### Backend (blocksecops-orchestration)
1. `src/blocksecops_orchestration/models/models.py` - Added `is_project` column
2. `src/blocksecops_orchestration/scanners/base.py` - Added `requires_project` parameter
3. `src/blocksecops_orchestration/scanners/solidity_scanners.py` - Marked Aderyn with `requires_project=True`
4. `src/blocksecops_orchestration/tasks/scan_tasks_sync.py` - Scanner filtering logic
5. `src/blocksecops_orchestration/api/schemas/scanner.py` - API schema update
6. `src/blocksecops_orchestration/api/routes/scanners.py` - API route update
7. `k8s/overlays/local/orchestration/kustomization.yaml` - Version bump to 0.7.4

### Documentation
1. `/Users/pwner/Git/ABS/docs/database/MANUAL-FIXES.md` - Database schema change documented
2. `/Users/pwner/Git/ABS/docs/ADERYN-SCANNER-FILTERING-2025-10-20.md` - This file

### Frontend (blocksecops-dashboard) - Future Work
1. `src/components/contract/CodeQualityPanel.tsx` - Will need updates to show scanner compatibility

---

## Impact

### Before Fix
- ❌ Aderyn attempted to scan all contracts
- ❌ Scans failed with "Not a directory" error
- ❌ Failed scan pods left in Error state
- ❌ Confusing user experience
- ❌ Wasted compute resources

### After Fix
- ✅ Aderyn automatically excluded from single-file contracts
- ✅ Only compatible scanners execute
- ✅ Clean scanner filtering with proper logging
- ✅ No failed pods or confusing errors
- ✅ Future-proof for project upload feature

### Scanner Compatibility Matrix

| Scanner | Single File | Project |
|---------|-------------|---------|
| Slither | ✅ | ✅ |
| Solhint | ✅ | ✅ |
| Echidna | ✅ | ✅ |
| Aderyn  | ❌ | ✅ |

---

## Future Work

### Phase 1: Dashboard Integration (Immediate)
1. Update `ScannerSelector` component to read `requires_project` from API
2. Show compatibility badge on each scanner
3. Disable/hide incompatible scanners for single-file contracts
4. Add tooltip explaining requirements

### Phase 2: Project Upload Feature
1. Add `/api/v1/contracts/upload-project` endpoint
2. Accept `.zip` or `.tar.gz` containing full project
3. Validate project structure (foundry.toml, hardhat.config.js, etc.)
4. Set `is_project=true` for uploaded projects
5. Store project files appropriately (S3/local storage)

### Phase 3: Additional Scanners
1. Identify other scanners that require project structure
2. Mark them with `requires_project=True`
3. Update documentation
4. Examples: Foundry's `forge test`, Hardhat's security plugins

### Phase 4: Enhanced Validation
1. Detect contract type automatically from upload
2. Validate project structure before setting `is_project=true`
3. Provide user feedback on project structure issues

---

## Migration Path

### For New Deployments
The `is_project` column will be created automatically by SQLAlchemy when the updated model is deployed.

### For Existing Deployments
Run the SQL migration documented in `/Users/pwner/Git/ABS/docs/database/MANUAL-FIXES.md`:

```bash
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "ALTER TABLE contracts ADD COLUMN IF NOT EXISTS is_project BOOLEAN NOT NULL DEFAULT FALSE;"
```

### Verification
```bash
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name = 'contracts' AND column_name = 'is_project';"
```

---

## API Changes

### New Field in Scanner Response

**Endpoint:** `GET /api/v1/scanners`

**Response:**
```json
{
  "total": 11,
  "available": 11,
  "scanners": [
    {
      "scanner_id": "aderyn",
      "name": "Aderyn",
      "description": "Cyfrin Rust-based static analyzer for Solidity",
      "finding_types": ["VULNERABILITY"],
      "is_available": true,
      "requires_project": true,  // NEW FIELD
      "timeout": 300
    }
  ]
}
```

---

## Logging

### New Log Events

1. **Scanner Skipped (Single-File)**
   ```json
   {
     "event": "scanner_skipped_single_file",
     "scanner_id": "aderyn",
     "scan_id": "...",
     "reason": "Scanner requires full project structure, contract is single-file"
   }
   ```

2. **Scanner Orchestrator Start (Enhanced)**
   ```json
   {
     "event": "executing_scanner_orchestrator",
     "scan_id": "...",
     "contract_id": "...",
     "contract_name": "...",
     "is_project": false,  // NEW FIELD
     "scanners": ["slither", "solhint", "echidna"]
   }
   ```

---

## References

### Related Documents
- [Platform Development Standards](/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md)
- [Database Manual Fixes](/Users/pwner/Git/ABS/docs/database/MANUAL-FIXES.md)
- [Phase 5 Celery Integration](/Users/pwner/Git/ABS/docs/PHASE-5-CELERY-INTEGRATION-2025-10-21.md)

### External Documentation
- [Aderyn Documentation](https://github.com/Cyfrin/aderyn)
- [Foundry Book](https://book.getfoundry.sh/)
- [Hardhat Documentation](https://hardhat.org/docs)

---

**Status**: ✅ Code Complete
**Version**: 0.7.4
**Next Step**: Build, deploy, and test
**Date Completed**: October 20, 2025
