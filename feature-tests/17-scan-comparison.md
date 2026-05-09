# Scan Comparison & Export

**Last Tested**: May 9, 2026 (dashboard 0.53.5 — contract-scoped baseline picker)

## Compare Two Scans
**How to test**: Navigate to `/scans/compare` or click "Compare" button on scan results

- [ ] Select two completed scans from the same contract
- [ ] Summary shows: New, Fixed, Unchanged vulnerability counts
- [ ] Vulnerability list displays with status badges (New/Fixed/Unchanged)
- [ ] Severity breakdown shows counts per severity level

## Scan Selection
**How to test**: Use the scan dropdowns on comparison page

- [ ] Dropdowns show only completed scans of the **same contract** as the scan pinned in the URL — NOT all scans across all contracts
- [ ] Scan entries show date and scanner used
- [ ] Selecting one scan does NOT change the contract scope (both dropdowns are pre-scoped to the active contract)

### Contract-scoped baseline picker (2026-05-09, dashboard 0.53.5)

The page reads `?scanA=<id>` / `?scanB=<id>` from the URL, fetches each scan record by ID independently of any list query (`getScan` from `src/lib/api/scans.ts`), and derives the active contract from whichever scan is pinned. The candidate list is server-side filtered via `GET /api/v1/scans?contract_id=<UUID>` — scoping no longer depends on whether the pinned scans happen to be in the user's top-100-most-recent slice.

- [ ] Open `/scans/compare?scanB=<some-old-scan-id>` where the user has more than 100 newer completed scans across other contracts. Baseline dropdown still scopes to the right contract (regression: pre-0.53.5 it would show ALL the user's scans because the pinned scan wasn't in the top-100 fetched).
- [ ] Network tab: only ONE `GET /api/v1/scans?…&contract_id=<UUID>&status=completed&limit=100` fires per active contract.
- [ ] Open `/scans/compare` with no query params: amber CTA banner reads "Open this page from a specific scan or contract to start a comparison — the baseline picker is scoped to one contract at a time. [Pick a contract →]"; both dropdowns disabled.
- [ ] Open `/scans/compare?scanA=<id>` (only scanA, no scanB): scanA loads, contract_id is derived from scanA, scanB dropdown is scoped to the same contract.
- [ ] When the contract has only one completed scan, the baseline dropdown shows the empty-state copy "No other scans available for this contract."
- [ ] The picked scan IS NOT listed as its own counterpart option (current scan B is excluded from the scan A dropdown, and vice versa).

## Vulnerability Diff
**How to test**: Compare two scans with different findings

- [ ] "New" vulnerabilities appear in green (in newer scan only)
- [ ] "Fixed" vulnerabilities appear in red (in older scan only)
- [ ] "Unchanged" vulnerabilities show in both scans
- [ ] Click vulnerability to see details from both scans

## Export Reports
**How to test**: Go to any scan results page, click Export button

- [ ] PDF export downloads a file
- [ ] CSV export downloads a file
- [ ] JSON export downloads a file
- [ ] SARIF export downloads a file
- [ ] Exported files contain vulnerability data

---

## API Endpoints

### GET /api/v1/scans/compare
**How to test**:
```bash
curl "http://localhost:3000/api/v1/scans/compare?scan_id_a=<ID_A>&scan_id_b=<ID_B>" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns comparison with `new_vulnerabilities`, `fixed_vulnerabilities`, `unchanged_vulnerabilities` counts
- [ ] Returns `vulnerabilities` array with status for each
- [ ] Returns `summary_by_severity` breakdown
- [ ] Returns 400 if scan_id_a or scan_id_b missing
- [ ] Returns 404 if scan not found
- [ ] Returns 403 if scan belongs to another user

### GET /api/v1/scans/:id/export
**How to test**:
```bash
# PDF
curl "http://localhost:3000/api/v1/scans/<SCAN_ID>/export?format=pdf" \
  -H "Authorization: Bearer $TOKEN" -o report.pdf

# CSV
curl "http://localhost:3000/api/v1/scans/<SCAN_ID>/export?format=csv" \
  -H "Authorization: Bearer $TOKEN" -o report.csv

# JSON
curl "http://localhost:3000/api/v1/scans/<SCAN_ID>/export?format=json" \
  -H "Authorization: Bearer $TOKEN" -o report.json

# SARIF
curl "http://localhost:3000/api/v1/scans/<SCAN_ID>/export?format=sarif" \
  -H "Authorization: Bearer $TOKEN" -o report.sarif
```

- [ ] PDF format returns valid PDF file
- [ ] CSV format returns valid CSV file
- [ ] JSON format returns valid JSON file
- [ ] SARIF format returns valid SARIF file
