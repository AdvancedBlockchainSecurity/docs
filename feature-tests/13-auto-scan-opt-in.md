# Per-Repo Auto-Scan Opt-In Tests

**Priority**: P2 - Medium
**Last Tested**: April 21, 2026
**Endpoint**: `PATCH /api/v1/integrations/{integration_id}/repositories/{repo_id}`
**UI**: `ConnectedRepositoriesList.tsx` under the GitHub App BYO integration card

---

## Background

Per BYO-GitHub-App policy, auto-scanning is **off by default** — customers opt in per repo. Three flags persist on `integration_repositories`:

- `auto_scan_enabled` — master switch, default `FALSE`
- `scan_on_push` — trigger on push to default branch (default `TRUE`, inert while master is off)
- `scan_on_pr` — trigger on PR open/update (default `TRUE`, inert while master is off)

The webhook dispatcher (tracked under task #151) only acts when `auto_scan_enabled = TRUE` AND the relevant sub-flag is `TRUE`.

---

## 1. Default state

### 1.1 Fresh-synced repo defaults to off
- [ ] Import a repo via the GitHub App wizard
- [ ] `GET /api/v1/integrations/{integration_id}/repositories` → each repo's `auto_scan_enabled: false`
- [ ] UI: the "Auto-scan" checkbox is unchecked on each repo row
- [ ] UI: "on push" and "on PR" checkboxes are visually disabled (grayed out, `opacity-40`, `cursor-not-allowed`)

---

## 2. Toggle master switch

### 2.1 Enable auto-scan
- [ ] Click the "Auto-scan" checkbox → becomes checked
- [ ] `PATCH /api/v1/integrations/{integration_id}/repositories/{repo_id}` body `{"auto_scan_enabled": true}` fires (DevTools Network)
- [ ] "on push" and "on PR" checkboxes become enabled (full opacity, clickable)

### 2.2 Disable auto-scan
- [ ] Uncheck "Auto-scan" → `PATCH` with `{"auto_scan_enabled": false}` fires
- [ ] "on push" and "on PR" become disabled again. Their checked state is preserved (not reset) — customer can re-enable master without re-toggling sub-flags

---

## 3. Sub-flag toggles

### 3.1 Toggle on-push
- [ ] With master ON, click "on push" → becomes checked/unchecked
- [ ] `PATCH` body contains only `{"scan_on_push": <bool>}` (not the other two flags)

### 3.2 Toggle on-PR
- [ ] Same as 3.1 for `scan_on_pr`

### 3.3 Sub-toggles respect master
- [ ] With master OFF, clicking the "on push" checkbox has no effect (disabled, no PATCH fires)
- [ ] Same for "on PR"

---

## 4. Authorization

### 4.1 Non-owner cannot PATCH
- [ ] Call `PATCH` as a user with only `integrations:read` → HTTP 403
- [ ] Call `PATCH` without auth → HTTP 401

### 4.2 API-key scope enforcement
- [ ] API key with `integrations:write` → PATCH succeeds
- [ ] API key with only `integrations:read` → HTTP 403 scope-mismatch

---

## 5. Persistence

### 5.1 Reload
- [ ] Set `auto_scan_enabled=true`, `scan_on_push=true`, `scan_on_pr=false` on repo A
- [ ] Reload the page
- [ ] The three checkboxes reflect the saved values

### 5.2 Cross-session
- [ ] Sign out, sign back in → same state

---

## 6. Existing tests (unchanged)

- `GET /api/v1/integrations/{integration_id}/repositories` response shape is untouched
- The "Sync now" button on each repo row still works (`POST /{integration_id}/repositories/{repo_id}/sync`)
- Existing component tests for sync-status badge and empty state still pass

---

## Related Tests

- **Unit coverage** (in `blocksecops-dashboard`):
  - `tests/components/integrations/ConnectedRepositoriesList.test.tsx` — 9 tests (4 pre-existing sync/empty-state tests + 5 new toggle tests covering renders, master-off-disables-subs, master-on-enables-subs, PATCH payload for master, PATCH payload for scan_on_push)
- **Related**:
  - Task #151 webhook dispatcher — consumes these flags; not yet implemented
  - `feature-tests/12-baseline-scan.md` — sister "per-contract state" UI pattern
