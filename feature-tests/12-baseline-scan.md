# Baseline Scan Feature Tests

**Priority**: P2 - Medium
**Last Tested**: April 21, 2026
**Endpoints**: `PUT`, `GET`, `DELETE /api/v1/contracts/{contract_id}/baseline`
**Related**: `GET /api/v1/scans/compare` (unchanged by this feature; just gains a persistent default baseline per contract)

---

## Background

A contract's **baseline scan** is the scan future scans are compared against. The existing `/api/v1/scans/compare` endpoint has always performed the diff; until migration 088, the customer had to remember which scan was their reference point and pass it as a query param every time. This feature persists that choice.

Persisted on the `contracts` table:

- `baseline_scan_id` — UUID FK to `scans.id`, ON DELETE SET NULL, nullable.
- `baseline_marked_at` — TIMESTAMPTZ nullable.

Only **completed** scans can be marked as baselines (a queued or failed scan has no findings to compare against). Deleting the baseline scan auto-clears the pointer via the FK.

---

## 1. Mark as Baseline (PUT)

### 1.1 Happy path
- [ ] Owner has a contract with at least one `completed` scan
- [ ] `PUT /api/v1/contracts/{contract_id}/baseline` with body `{"scan_id": "<scan_uuid>"}` → HTTP 200
- [ ] Response body contains `contract_id`, `baseline_scan_id`, `baseline_marked_at` (ISO 8601), `scan_status="completed"`, `scan_completed_at`
- [ ] `GET` same endpoint immediately after → HTTP 200 with the same baseline
- [ ] Dashboard `ScanResults` page on that scan shows a green "Baseline ✓" pill

### 1.2 Scan not found
- [ ] `PUT` with a random UUID (`00000000-0000-0000-0000-000000000000`) → HTTP 404, `{"detail": "Scan not found for this contract"}`

### 1.3 Scan belongs to a different contract (existence non-leak)
- [ ] `PUT` with a valid `scan_id` that belongs to a DIFFERENT contract owned by the same user → HTTP 404 (same message as 1.2, no leakage)
- [ ] `PUT` with a valid `scan_id` that belongs to a different organization → HTTP 404 (no leakage)

### 1.4 Scan is not completed
- [ ] `PUT` with a `queued`, `running`, or `failed` scan's id → HTTP 422 with `detail` containing the scan's actual status

### 1.5 Ownership
- [ ] `PUT` on a contract the current user does not own → HTTP 403
- [ ] `PUT` without `Authorization` header → HTTP 401
- [ ] `PUT` with an API key that has `contracts:read` but not `contracts:write` → HTTP 403 with scope-mismatch detail

### 1.6 Overwrite existing baseline
- [ ] Set baseline to scan A (HTTP 200)
- [ ] Set baseline to scan B (HTTP 200) — response shows `baseline_scan_id=B`
- [ ] `GET` returns B's id, not A's. `baseline_marked_at` reflects the second call.

---

## 2. Get Baseline (GET)

### 2.1 No baseline set
- [ ] Contract with no baseline → `GET` returns HTTP 404 with `{"detail": "No baseline scan set for this contract"}`

### 2.2 Ownership
- [ ] `GET` on a contract the user does not own → HTTP 403
- [ ] `GET` without auth → HTTP 401

---

## 3. Clear Baseline (DELETE)

### 3.1 Idempotent clear
- [ ] `DELETE` when a baseline is set → HTTP 204, subsequent `GET` returns 404
- [ ] `DELETE` again when no baseline is set → HTTP 204 (idempotent, no 404)

### 3.2 Ownership
- [ ] `DELETE` on a contract the user does not own → HTTP 403
- [ ] `DELETE` with an API key missing `contracts:write` → HTTP 403

---

## 4. FK cascade behavior

### 4.1 ON DELETE SET NULL
- [ ] Contract has scan S marked as baseline
- [ ] Delete scan S via `DELETE /api/v1/scans/{S}` → succeeds (not blocked by the FK)
- [ ] `GET /api/v1/contracts/{contract_id}/baseline` → HTTP 404 (baseline auto-cleared)
- [ ] `contracts.baseline_scan_id` in the DB is NULL
- [ ] `contracts.baseline_marked_at` is left as-is (audit trail — when the now-orphan baseline was set)

---

## 5. Compare endpoint integration (regression)

### 5.1 Compare with persisted baseline
- [ ] Contract has baseline scan B set
- [ ] Visit `ScanResults` page for a different completed scan C on the same contract
- [ ] "Compare to baseline" link automatically carries `scanA=B&scanB=C` (not just `scanB=C`)
- [ ] Clicking it lands on the compare page with B as "baseline" column pre-populated

### 5.2 Compare without persisted baseline
- [ ] Contract has no baseline set
- [ ] "Compare to baseline" link carries only `scanB=C`; compare page prompts the user to pick a scan A

### 5.3 `GET /api/v1/scans/compare?scan_id_a=<old>&scan_id_b=<new>` still works unchanged
- [ ] The endpoint signature is untouched — both query params still required, both still accept any valid scan UUID regardless of baseline status

---

## 6. Dashboard UI

### 6.1 Button visibility
- [ ] On a completed scan's detail page, the "Mark as baseline" button is visible
- [ ] On a queued/running/failed scan's detail page, the button is NOT rendered (the PUT would 422 anyway)

### 6.2 Toggle semantics
- [ ] Click "Mark as baseline" → button flips to green "Baseline ✓"
- [ ] Click "Baseline ✓" → cleared, button flips back to "Mark as baseline"
- [ ] Navigating to the scan that IS currently the baseline shows the "Baseline ✓" pill immediately

### 6.3 Network errors
- [ ] If the PUT fails (network/500), the button remains in the previous state and no optimistic toggle remains stuck

---

## Related Tests

- **Unit coverage** (in `blocksecops-api-service`):
  - `tests/unit/presentation/test_baseline_scan.py` — 26 tests covering ORM relationship disambiguation, migration 088 shape, endpoint structure, scope enforcement, ownership, status guard, 404-collapse for existence non-leak, idempotent DELETE, and `/scans/compare` regression guard
- **Related playbook**: none yet — baseline operations are self-service via the dashboard; no operator runbook required
