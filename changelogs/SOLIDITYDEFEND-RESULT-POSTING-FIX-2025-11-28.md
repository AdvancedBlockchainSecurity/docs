# SolidityDefend Scanner Result Posting Fix

**Date:** November 28, 2025
**Component:** blocksecops-tool-integration
**Scanner:** SolidityDefend
**Image Version:** 0.2.6

---

## Summary

Fixed critical issue where SolidityDefend scanner successfully detected vulnerabilities (47 findings) but results were not appearing in the dashboard. The scanner was correctly parsing and formatting results but missing the HTTP POST to send them to the tool-integration service.

---

## Problem Description

### Symptoms
- SolidityDefend scanner jobs completed successfully
- Job logs showed 47 vulnerabilities detected (correct)
- Dashboard showed "no findings" for completed scans
- tool-integration service logs showed: "Scanner containers POST results directly, so skipping log parsing"

### Root Cause
The `soliditydefend-scan` wrapper script was missing:
1. `CALLBACK_URL` and `SCAN_ID` environment variable handling
2. `curl` POST logic to send results to the tool-integration service
3. `curl` package in the Docker image runtime dependencies

Other scanners (wake, slither, semgrep) have this POST logic, but SolidityDefend was initially integrated without it.

---

## Fix Details

### 1. Script Changes (`soliditydefend-scan`)

**Added environment variables (lines 10-11):**
```bash
CALLBACK_URL="${CALLBACK_URL:-}"
SCAN_ID="${SCAN_ID:-}"
```

**Added validation (lines 13-19):**
```bash
if [ -z "$CALLBACK_URL" ] || [ -z "$SCAN_ID" ]; then
    echo "ERROR: CALLBACK_URL and SCAN_ID environment variables are required"
    echo "CALLBACK_URL: ${CALLBACK_URL:-'not set'}"
    echo "SCAN_ID: ${SCAN_ID:-'not set'}"
    exit 1
fi
```

**Added curl POST logic (lines 200-217):**
```bash
# Post results to callback URL
echo ""
echo "Posting results to $CALLBACK_URL..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$CALLBACK_URL" \
    -H "Content-Type: application/json" \
    -d @"$OUTPUT_FILE" || echo "000")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo "✓ Results posted successfully (HTTP $HTTP_CODE)"
    echo "Response: $RESPONSE_BODY"
else
    echo "✗ Failed to post results (HTTP $HTTP_CODE)"
    echo "Response: $RESPONSE_BODY"
fi
```

### 2. Dockerfile Changes

**Added curl to runtime dependencies (line 71):**
```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*
```

**Updated version labels to 0.2.6:**
```dockerfile
LABEL version="0.2.6"
LABEL scanner.image.version="0.2.6"
```

---

## Files Changed

| File | Change |
|------|--------|
| `blocksecops-tool-integration/scanner-images/soliditydefend/soliditydefend-scan` | Added CALLBACK_URL, SCAN_ID env vars and curl POST logic |
| `blocksecops-tool-integration/scanner-images/soliditydefend/Dockerfile` | Added curl dependency, updated version to 0.2.6 |

---

## Data Flow (After Fix)

```
1. API Service → Orchestration: Scan request
2. Orchestration → tool-integration: Trigger scanner job
3. tool-integration → K8s: Create scanner Job with CALLBACK_URL, SCAN_ID env vars
4. Scanner Job runs:
   a. SolidityDefend analyzes contracts
   b. Results formatted to JSON
   c. curl POSTs results to CALLBACK_URL (tool-integration)
5. tool-integration → API Service: Forward vulnerabilities
6. Dashboard: Displays findings
```

---

## Testing

### Test Scan Results
- **Scan ID:** `a0b46f01-929d-4421-addc-cb4bfa3a690e`
- **Contract:** VulnerableToken.sol (Foundry project)
- **Findings:** 47 vulnerabilities detected and displayed in dashboard
- **Dashboard URL:** http://127.0.0.1:3000/scans/a0b46f01-929d-4421-addc-cb4bfa3a690e

### Verification Steps
1. Built `scanner-soliditydefend:0.2.6` image
2. Triggered scan via dashboard
3. Confirmed job logs show POST success
4. Verified vulnerabilities appear in dashboard

---

## Related Issues Fixed in Session

### Prior Fixes (from context recovery)
1. **jq shell quoting issue** - Fixed `//` null coalescing operator by using file-based jq filter with `'JQEOF'` heredoc
2. **Version string control characters** - Fixed by extracting version with `grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+'`
3. **User quota reset** - Reset `monthly_scans_used` for test user

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.2.6 | 2025-11-28 | Added curl POST logic and curl dependency |
| 0.2.5 | 2025-11-28 | Fixed version string extraction |
| 0.2.4 | 2025-11-28 | Fixed jq shell quoting with file-based filter |
| 0.2.3 | 2025-11-28 | Initial jq filter fix attempt |
| 0.2.2 | 2025-11-26 | Previous stable version |

---

## Deployment

```bash
# Build image (in minikube context)
eval $(minikube docker-env)
cd blocksecops-tool-integration/scanner-images/soliditydefend
docker build --no-cache -t scanner-soliditydefend:0.2.6 .
docker tag scanner-soliditydefend:0.2.6 scanner-soliditydefend:latest

# Verify image
docker images scanner-soliditydefend
```

---

**Status:** ✅ Fixed and Verified
**Tested By:** User confirmation via dashboard
