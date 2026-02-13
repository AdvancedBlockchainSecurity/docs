# Dashboard v0.42.1 - Duplicate Contract 409 Handling Fix

**Date:** February 13, 2026
**Component:** blocksecops-dashboard
**Type:** Bug Fix
**Priority:** High
**Status:** Complete

---

## Summary

Fixed the 409 duplicate contract name error not showing the DuplicateContractModal. Users saw a generic "Upload Failed: Request failed with status code 409" instead of the rename/overwrite modal.

## Root Cause

FastAPI's `HTTPException` wraps the error payload in a `detail` field, producing:

```json
{"detail": {"error": "contract_name_exists", "message": "...", "existing_contract": {...}}}
```

The dashboard's `isContractConflictError()` type guard checked `response.data.error` instead of `response.data.detail.error`, so it never matched, and the generic error handler ran instead of showing the DuplicateContractModal.

## Changes Made

### 1. Type Guard Fix (`src/lib/api/contracts.ts`)

**Before:**
```typescript
axiosError.response?.data?.error === 'contract_name_exists'
```

**After:**
```typescript
axiosError.response?.data?.detail?.error === 'contract_name_exists'
```

### 2. Error Handlers (`src/components/contracts/ContractUploadModal.tsx`)

Both `createContractMutation` and `uploadFileMutation` `onError` handlers updated:

**Before:**
```typescript
const conflictData = error.response.data;
```

**After:**
```typescript
const conflictData = error.response.data.detail;
```

## Files Modified

| File | Change |
|------|--------|
| `src/lib/api/contracts.ts` | Fixed `isContractConflictError()` type guard to check `data.detail.error` |
| `src/components/contracts/ContractUploadModal.tsx` | Fixed both `onError` handlers to read from `data.detail` |
| `package.json` | Version bump 0.42.0 → 0.42.1 |
| `k8s/overlays/local/kustomization.yaml` | newTag 0.42.0 → 0.42.1 |

## Verification

1. Upload a contract with a name that already exists
2. DuplicateContractModal should appear with "Rename" and "Overwrite" tabs
3. Choosing "Rename" appends `_2` to the name and retries
4. Confirmed working: `VulnerableAccountManagement_2` uploaded successfully via rename flow

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.8.0 / 0.22.0 | 2025-12-31 | Initial duplicate contract handling implementation |
| 0.42.1 | 2026-02-13 | Fix type guard to handle FastAPI `detail` wrapper |
