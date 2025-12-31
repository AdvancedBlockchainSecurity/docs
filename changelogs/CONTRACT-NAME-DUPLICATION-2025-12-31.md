# Contract Name Duplication Handling

**Date**: December 31, 2025
**API Version**: 0.8.0
**Dashboard Version**: 0.22.0

## Summary

Implemented duplicate contract name detection with user-friendly resolution options. When uploading or creating a contract with a name that already exists for the user, the system now returns a 409 CONFLICT response, and the dashboard displays a modal offering to rename or overwrite the existing contract.

## Changes

### Backend (blocksecops-api-service)

#### New Endpoint
- **GET /api/v1/contracts/check-name** - Check if contract name exists for current user
  - Query param: `name` (required, min 1 character)
  - Returns: `{exists: bool, existing_contract: ExistingContractInfo | null}`

#### Modified Endpoints
- **POST /api/v1/contracts** - Now returns 409 CONFLICT if name exists
- **POST /api/v1/upload** - Now returns 409 CONFLICT if contract_name exists

#### New Schemas
- `ExistingContractInfo` - Contract info for conflict responses
- `ContractNameCheckResponse` - Response schema for check-name endpoint

### Frontend (blocksecops-dashboard)

#### New Components
- `DuplicateContractModal.tsx` - Modal for handling duplicate name conflicts
  - Tabbed interface: Rename / Overwrite
  - Rename: Suggests `{name}_2`, validates input
  - Overwrite: Warning about deleting existing contract and scans

#### Modified Components
- `ContractUploadModal.tsx` - Integrated duplicate detection
  - Catches 409 responses from mutations
  - Shows DuplicateContractModal on conflict
  - Handles rename retry and overwrite (delete + retry) flows

#### New API Types
- `ExistingContractInfo` interface
- `ContractConflictError` interface
- `isContractConflictError()` type guard function

## Technical Details

### Conflict Detection
- Per-user uniqueness scope (same name allowed for different users)
- Server-side validation (backend is source of truth)
- Check performed before contract creation in both endpoints

### Overwrite Strategy
- Delete existing contract first
- Cascade delete removes associated scans and vulnerabilities
- Then retry original upload/create operation

### 409 Response Format
```json
{
  "error": "contract_name_exists",
  "message": "A contract named 'ContractName' already exists",
  "existing_contract": {
    "id": "uuid",
    "name": "ContractName",
    "created_at": "2025-12-31T00:00:00Z",
    "status": "uploaded",
    "is_multi_file": false,
    "file_count": 1
  }
}
```

## Files Modified

### Backend
| File | Change |
|------|--------|
| `src/presentation/schemas/contracts.py` | Added ExistingContractInfo, ContractNameCheckResponse |
| `src/presentation/api/v1/endpoints/contracts.py` | Added check-name endpoint, 409 check in create |
| `src/presentation/api/v1/endpoints/upload.py` | Added 409 check before contract creation |

### Frontend
| File | Change |
|------|--------|
| `src/components/contracts/DuplicateContractModal.tsx` | NEW - Resolution modal |
| `src/components/contracts/ContractUploadModal.tsx` | Integrated duplicate handling |
| `src/lib/api/contracts.ts` | Added conflict types and helper |

## Testing

See feature test document: `/docs/feature-tests/32-contract-name-duplication.md`

## Deployment

- API Service: Image tag 0.8.0
- Dashboard: Image tag 0.22.0
- Kustomization files updated with new versions
