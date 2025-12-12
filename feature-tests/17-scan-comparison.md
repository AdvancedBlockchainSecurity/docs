# Scan Comparison & Export

## Compare Two Scans
**How to test**: Navigate to `/scans/compare` or click "Compare" button on scan results

- [ ] Select two completed scans from the same contract
- [ ] Summary shows: New, Fixed, Unchanged vulnerability counts
- [ ] Vulnerability list displays with status badges (New/Fixed/Unchanged)
- [ ] Severity breakdown shows counts per severity level

## Scan Selection
**How to test**: Use the scan dropdowns on comparison page

- [ ] Dropdowns show only completed scans
- [ ] Scan entries show date and scanner used
- [ ] Selecting one scan filters the other dropdown to same contract

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
