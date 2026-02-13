# Feature Test: Contract Name Duplication Handling

**Feature**: Duplicate Contract Name Resolution
**Version**: 0.8.0 (API), 0.22.0 (Dashboard)
**Date**: December 31, 2025
**Status**: Implemented

---

## Overview

When a user uploads or creates a contract with a name that already exists for their account, the system now detects the conflict and presents options to either rename the new contract or overwrite the existing one.

## Test Cases

### TC-32.1: Check Name Endpoint

**Objective**: Verify GET /contracts/check-name returns correct availability status

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)

# Test with non-existing name
curl -s "http://localhost:8000/api/v1/contracts/check-name?name=UniqueContractName" \
  -H "Authorization: Bearer $TOKEN" | jq

# Test with existing name
curl -s "http://localhost:8000/api/v1/contracts/check-name?name=ExistingContract" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] Non-existing name returns `{"exists": false, "existing_contract": null}`
- [ ] Existing name returns `{"exists": true, "existing_contract": {...}}`
- [ ] `existing_contract` contains: id, name, created_at, status, is_multi_file, file_count

---

### TC-32.2: 409 Conflict on POST /contracts

**Objective**: Verify creating contract with duplicate name returns 409 CONFLICT

**Prerequisites**:
- User authenticated
- Existing contract named "TestContract"

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)

# Create contract with existing name
curl -s -X POST "http://localhost:8000/api/v1/contracts" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "TestContract", "source_code": "contract Test {}"}' | jq
```

**Expected Results**:
- [ ] HTTP Status: 409 CONFLICT
- [ ] Response contains `error: "contract_name_exists"`
- [ ] Response contains `message` explaining conflict
- [ ] Response contains `existing_contract` with id, name, created_at, status

---

### TC-32.3: 409 Conflict on File Upload

**Objective**: Verify uploading file with duplicate contract name returns 409 CONFLICT

**Prerequisites**:
- User authenticated
- Existing contract named "MyContract"

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)

# Upload file with existing contract name
curl -s -X POST "http://localhost:8000/api/v1/upload?contract_name=MyContract&network=ethereum" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test.sol" | jq
```

**Expected Results**:
- [ ] HTTP Status: 409 CONFLICT
- [ ] Response structure matches POST /contracts conflict response

---

### TC-32.4: Duplicate Modal Display

**Objective**: Verify DuplicateContractModal appears on conflict

**Prerequisites**:
- User authenticated
- Existing contract in account

**Steps**:
1. Open Dashboard at http://127.0.0.1:3000
2. Navigate to Contracts page
3. Click "Upload Contract"
4. Select a file or enter source code
5. Use a contract name that already exists
6. Click Upload/Create

**Expected Results**:
- [ ] Modal appears with title "Contract Name Already Exists"
- [ ] Two tabs visible: "Rename" and "Overwrite"
- [ ] Existing contract info displayed (name, created date, status)
- [ ] Rename tab shows suggested name (original + "_2")
- [ ] Overwrite tab shows warning about deleting existing contract

---

### TC-32.5: Rename Flow

**Objective**: Verify rename functionality works correctly

**Prerequisites**:
- DuplicateContractModal displayed

**Steps**:
1. In modal, ensure "Rename" tab is active
2. Modify suggested name to a unique name
3. Click "Upload with New Name"

**Expected Results**:
- [ ] Upload proceeds with new name
- [ ] Contract created successfully
- [ ] Original contract remains unchanged
- [ ] Modal closes
- [ ] Success toast displayed

---

### TC-32.6: Overwrite Flow

**Objective**: Verify overwrite functionality deletes old contract and creates new

**Prerequisites**:
- DuplicateContractModal displayed
- Existing contract has associated scans (optional)

**Steps**:
1. In modal, click "Overwrite" tab
2. Read warning message
3. Click "Overwrite Existing"

**Expected Results**:
- [ ] Original contract deleted
- [ ] Associated scans deleted (cascade)
- [ ] New contract created with same name
- [ ] Modal closes
- [ ] Success toast displayed
- [ ] Contract list shows only new contract

---

### TC-32.7: Cancel Flow

**Objective**: Verify cancel closes modal without action

**Steps**:
1. Trigger duplicate name conflict
2. When modal appears, click "Cancel" or backdrop

**Expected Results**:
- [ ] Modal closes
- [ ] No contract created
- [ ] Original contract unchanged
- [ ] Upload form reset

---

### TC-32.8: Archive Upload Conflict

**Objective**: Verify archive uploads check contract name, not file names

**Prerequisites**:
- Existing contract named "MyProject"

**Steps**:
1. Create ZIP archive with multiple .sol files
2. Upload with contract_name="MyProject"

**Expected Results**:
- [ ] 409 CONFLICT returned
- [ ] Conflict is on contract_name, not individual file names
- [ ] Modal shows existing project info

---

### TC-32.9: Per-User Uniqueness

**Objective**: Verify contract names are unique per user, not globally

**Prerequisites**:
- User A has contract named "SharedName"
- User B authenticated

**Steps**:
1. Log in as User B
2. Create contract named "SharedName"

**Expected Results**:
- [ ] Contract created successfully (no conflict)
- [ ] User A's contract unchanged
- [ ] Both users can have same contract name

---

### TC-32.10: Empty Name Validation

**Objective**: Verify empty names rejected before duplicate check

**Steps**:
```bash
curl -s "http://localhost:8000/api/v1/contracts/check-name?name=" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] HTTP Status: 422 Validation Error
- [ ] Error message about minimum length requirement

---

## API Reference

### GET /api/v1/contracts/check-name

Check if a contract name already exists for the current user.

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| name | string | Yes | Contract name to check (min 1 character) |

**Response (200)**:
```json
{
  "exists": true,
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

### POST /api/v1/contracts (409 Response)

**Response (409 CONFLICT)**:
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

### POST /api/v1/upload (409 Response)

Same response structure as POST /contracts.

---

## Frontend Components

### DuplicateContractModal

Location: `blocksecops-dashboard/src/components/contracts/DuplicateContractModal.tsx`

**Props**:
| Prop | Type | Description |
|------|------|-------------|
| isOpen | boolean | Controls modal visibility |
| onClose | () => void | Called when modal dismissed |
| onRename | (newName: string) => void | Called with new name |
| onOverwrite | () => void | Called to overwrite existing |
| existingContract | ExistingContractInfo | Existing contract details |
| proposedName | string | Original conflicting name |
| isProcessing | boolean | Shows loading state |

---

## User Flow Diagram

```
User uploads contract
        |
        v
Backend checks for existing name
        |
   [Name exists?]
    /         \
   No         Yes
   |           |
   v           v
Create      Return 409
Contract    CONFLICT
   |           |
   v           v
Success    Show Modal
          /    |    \
      Rename  Cancel  Overwrite
        |       |        |
        v       v        v
    Retry    Close    Delete old
    upload   modal    + Retry
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.8.0 / 0.22.0 | 2025-12-31 | Initial implementation |
| 0.42.1 | 2026-02-13 | Fix `isContractConflictError()` type guard: check `response.data.detail.error` instead of `response.data.error` (FastAPI wraps HTTPException in `detail` field). Fix both `onError` handlers in `ContractUploadModal.tsx` to read from `data.detail`. Verified with `VulnerableAccountManagement_2` rename flow. |
