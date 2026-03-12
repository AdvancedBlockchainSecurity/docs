# Code Snippet Lazy Extraction Verification

**Priority**: P1 - High
**Date**: February 18, 2026
**Services**: api-service (0.28.40)

---

## Overview

Vulnerabilities with `line_number` but no valid `code_snippet` now have their code context extracted lazily on the first GET request to the vulnerability detail endpoint. The extracted snippet is persisted to the database, so subsequent requests serve it directly.

---

## Test 1: Code Snippet Appears on Vulnerability Detail (P1)

**Validates:** Lazy extraction populates code_snippet for vulnerabilities that had NULL.

1. Navigate to `https://app.0xapogee.com/vulnerabilities/5bd16f06-1d70-401d-905d-c6876504509c`
2. **Expected:** Code Location section shows a 5-line source code window with an arrow marker on the target line
3. **Expected:** Format includes line numbers (e.g. `  45: uint256 balance = ...` with `-> 47: msg.sender.call{value: ...}`)

```bash
# API check
curl -sk https://app.0xapogee.com/api/v1/vulnerabilities/5bd16f06-1d70-401d-905d-c6876504509c \
  -H "Authorization: Bearer $TOKEN" | jq '.code_snippet'
# Should return a non-null string with line numbers and arrow marker
```

- [x] Code Location section visible on vulnerability detail page
- [x] Snippet shows 5-line context window with arrow marker

---

## Test 2: Snippet Persisted to Database (P1)

**Validates:** After first view, code_snippet is stored in the vulnerabilities table.

```sql
SELECT code_snippet FROM vulnerabilities
WHERE id = '5bd16f06-1d70-401d-905d-c6876504509c';
-- Should return non-null value after first page view
```

- [x] code_snippet column populated after first GET request

---

## Test 3: Invalid line:col Patterns Rejected (P1)

**Validates:** Scanners that store "669:16" as code_snippet get corrected.

1. Find a vulnerability where scanner stored a bare `line:col` pattern
2. View the vulnerability detail page
3. **Expected:** The `line:col` string is replaced with an actual code context window

```bash
# Check for remaining line:col patterns in database
psql -h 127.0.0.1 -U postgres -d solidity_security -c "
  SELECT id, code_snippet FROM vulnerabilities
  WHERE code_snippet ~ '^\d+:\d+$'
  LIMIT 5;
"
# Should return 0 rows after vulnerabilities have been viewed
```

- [ ] No bare `line:col` patterns remain after viewing affected vulnerabilities

---

## Test 4: Multi-File Contract Support (P2)

**Validates:** Code snippet extraction works for contracts with multiple files (uses ContractFileModel).

1. Find a vulnerability from a multi-file contract where `file_path` is set
2. View the vulnerability detail page
3. **Expected:** Code snippet extracted from the correct file (matched by `file_path`)

- [ ] Multi-file contract vulnerability shows correct code snippet from correct file

---

## Test 5: Deployment Stability (P0)

**Validates:** The kustomize env conflict fix resolved the deployment blocker.

```bash
# Verify no env conflict in rendered manifests
kubectl kustomize k8s/overlays/local/ | grep -A4 "DASHBOARD_BASE_URL"
# Should show only valueFrom (no hardcoded value)

# Verify pod is running
kubectl -n api-service-local get pods
# api-service pod should be 1/1 Running with 0.28.40 image
```

- [x] `kubectl apply -k` succeeds
- [x] Pod running with 0.28.40 image
- [x] Health endpoint returns version 0.28.40
