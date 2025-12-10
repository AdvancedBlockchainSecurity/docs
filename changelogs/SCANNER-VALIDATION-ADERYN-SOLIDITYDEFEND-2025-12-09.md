# Scanner Validation: Aderyn & SolidityDefend - December 9, 2025

## Summary

Validated end-to-end scanner pipeline for Aderyn and SolidityDefend scanners. Both scanners are now working correctly with proper vulnerability parsing and result storage.

---

## Issue Background

### Aderyn Confidence Field Fix (Previous Session)

**Problem:** Aderyn scanner results were causing HTTP 422 validation errors when posting to the API service.

**Root Cause:** The Aderyn parser was passing the `confidence` field as a string (`"high"`, `"low"`) instead of a float (0.9, 0.5) as expected by the API schema.

**Fix Applied:** Updated the Aderyn parser to convert string confidence values to floats:
- `"high"` → `0.9`
- `"medium"` → `0.7`
- `"low"` → `0.5`
- Default → `0.5`

**File:** `blocksecops-tool-integration/src/parsers/aderyn_parser.py`

---

## Validation Test Results

### Test Environment

- **Platform:** Minikube local cluster
- **Access:** Via Traefik ingress (port 3000) following production parity principle
- **Contract ID:** `0edcc9c5-04fb-4bae-824f-bc68f6d95727`

### Scanner Test Results

| Scanner | Scan ID | Status | Critical | High | Medium | Low | Total |
|---------|---------|--------|----------|------|--------|-----|-------|
| **Aderyn** | `fe4ab956-35f2-4316-9bfa-c31599c7f762` | completed | 3 | 0 | 8 | 0 | 11 |
| **SolidityDefend** | `efdb20ad-702d-44c9-8cbd-3823d61f14cc` | completed | 0 | 6 | 4 | 2 | 12 |

### Verification Details

**Aderyn Scanner:**
- Scanner job created and executed in Kubernetes
- AderynParser found 11 vulnerabilities
- Results posted with HTTP 200 OK (no more 422 errors)
- Vulnerability counts stored correctly in database

**SolidityDefend Scanner:**
- Scanner job created and executed in Kubernetes
- SolidityDefendParser found 12 vulnerabilities
- Results posted with HTTP 200 OK
- Vulnerability counts stored correctly in database

---

## Technical Details

### Services Involved

1. **API Service** - Receives scan requests and stores results
2. **Tool Integration** - Orchestrates scanner job execution
3. **Scanner Jobs** - Kubernetes Jobs running scanner containers
4. **Parsers** - Convert scanner-specific output to standardized format

### Data Flow (Verified Working)

```
Dashboard/API → Tool Integration → Kubernetes Job → Scanner Container
                                                         ↓
                                                  POST results.json
                                                         ↓
            Tool Integration ← Scanner Parser ← Raw Results
                    ↓
            POST /api/v1/scans/{id}/results (HTTP 200)
                    ↓
               Database Storage
```

### Parser Validation

Both parsers are correctly:
- Extracting vulnerability metadata
- Converting severity levels to standard format
- Converting confidence values to floats
- Including required fields (title, description, file_path, line_number, etc.)

---

## Test Scripts Created

Location: `/tmp/`

| Script | Purpose |
|--------|---------|
| `create_aderyn_scan_traefik.sh` | Create Aderyn scan via Traefik |
| `create_soliditydefend_scan.sh` | Create SolidityDefend scan via Traefik |
| `check_scan_traefik.sh` | Check scan status via Traefik |
| `check_soliditydefend_scan.sh` | Check SolidityDefend scan results |

---

## Quota System Note

During testing, encountered quota exceeded error. The `user_quotas` table tracks monthly scan usage:

```sql
-- Reset user quota for testing
UPDATE user_quotas SET monthly_scans_used = 0 WHERE user_id = '<user_id>';
```

Quota is tracked in the `user_quotas.monthly_scans_used` column, not directly in the `scans` table.

---

## Verification Commands

```bash
# Check tool-integration logs for scanner processing
kubectl logs -n tool-integration-local deploy/tool-integration --tail=50 | grep -E "(Parser found|Posted.*vulnerabilities|HTTP)"

# Verify scan results via API
curl -s "http://127.0.0.1:3000/api/v1/scans/{scan_id}" \
  -H "Authorization: Bearer $TOKEN" | jq '{status, critical_count, high_count, medium_count, low_count}'

# Check database for stored vulnerabilities
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c \
  "SELECT scanner_id, COUNT(*) FROM vulnerabilities WHERE scan_id = '{scan_id}' GROUP BY scanner_id;"
```

---

## Related Documentation

- **Scanner Workflow Troubleshooting:** `/Users/pwner/Git/ABS/blocksecops-docs/scanners/SCANNER-WORKFLOW-TROUBLESHOOTING.md`
- **Scanner Integration Guide:** `/Users/pwner/Git/ABS/blocksecops-docs/scanners/SCANNER-INTEGRATION-GUIDE.md`
- **Local Development Standards:** `/Users/pwner/Git/ABS/docs/standards/local-development-setup.md`

---

## Next Steps

1. Continue testing remaining scanners (Slither, Wake, Mythril, etc.)
2. Investigate any scanners with 0 findings for vulnerable contracts
3. Add automated integration tests for scanner validation

---

**Document Owner:** Platform Development Team
**Created:** December 9, 2025
