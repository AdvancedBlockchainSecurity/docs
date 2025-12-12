# Scanner Effectiveness Dashboard

## Scanner Effectiveness Overview
**How to test**: Navigate to `/analytics/scanner-effectiveness`

- [ ] Page loads with scanner effectiveness data
- [ ] Shows list of scanners with their metrics
- [ ] Displays total findings per scanner
- [ ] Shows unique findings (not found by other scanners)
- [ ] Displays severity breakdown (Critical, High, Medium, Low)

## Scanner Metrics
**How to test**: Review the scanner cards/rows on the effectiveness page

- [ ] Each scanner shows:
  - [ ] Total scans run
  - [ ] Total findings detected
  - [ ] Unique findings count
  - [ ] Success rate percentage
  - [ ] Average scan time (if available)
- [ ] Scanners are sortable by metrics

## Scanner Overlap Matrix
**How to test**: View the overlap/comparison section

- [ ] Shows overlap between scanner pairs
- [ ] Displays shared findings count
- [ ] Displays overlap percentage
- [ ] Matrix is symmetric (A vs B = B vs A)

## Recommendations
**How to test**: Check for recommendations section

- [ ] System provides scanner combination recommendations
- [ ] Recommendations based on finding coverage
- [ ] Suggests optimal scanner combinations

---

## API Endpoints

### GET /api/v1/analytics/scanner-effectiveness
**How to test**:
```bash
curl "http://localhost:3000/api/v1/analytics/scanner-effectiveness" \
  -H "Authorization: Bearer $TOKEN"
```

- [ ] Returns `scanners` array with effectiveness metrics
- [ ] Returns `overlap_matrix` with scanner pair comparisons
- [ ] Returns `total_findings` count
- [ ] Returns `total_unique_findings` count
- [ ] Returns `recommendations` array
- [ ] Returns `generated_at` timestamp
- [ ] Returns 401 if not authenticated

### Response Schema Validation
**How to test**: Validate response structure

- [ ] Each scanner has `scanner_id` and `scanner_name`
- [ ] Each scanner has `total_findings` number
- [ ] Each scanner has `unique_findings` number
- [ ] Each scanner has severity counts (critical, high, medium, low, informational)
- [ ] Each scanner has `average_scan_time_seconds` (nullable)
- [ ] Each scanner has `total_scans` count
- [ ] Each scanner has `success_rate` percentage
- [ ] Each scanner has `patterns_detected` array

### Overlap Matrix Validation
**How to test**: Check overlap matrix structure

- [ ] Each item has `scanner_a` string
- [ ] Each item has `scanner_b` string
- [ ] Each item has `shared_findings` count
- [ ] Each item has `overlap_percentage` number (0-100)
