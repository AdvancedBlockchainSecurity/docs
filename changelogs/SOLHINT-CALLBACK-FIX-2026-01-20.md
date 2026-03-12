# Solhint Scanner Callback Fix

**Date:** January 20, 2026
**Component:** blocksecops-tool-integration
**Scanner:** Solhint
**Image Version:** 0.1.3

---

## Summary

Fixed critical issue where Solhint scanner completed successfully but scan status remained "queued" in the database. The scanner was executing and producing results but was never POSTing them back to the tool-integration service.

---

## Problem Description

### Symptoms
- Solhint scanner jobs completed with "Completed" pod status
- Scan status remained "queued" indefinitely in the API/dashboard
- tool-integration logs showed: "Scanner containers POST results directly, so skipping log parsing"
- Results file written to `/output/solhint-results.json` but never transmitted

### Root Cause
The `solhint-scan` wrapper script was missing:
1. POST callback logic to send results to the tool-integration service
2. Proper handling of `CALLBACK_URL` environment variable (unbound variable with `set -u`)
3. `curl` package in the Docker image (Alpine-based)
4. Bug in `SOL_COUNT` calculation producing "0\n0" instead of "0"

---

## Fix Details

### 1. Added POST Callback Logic (`solhint-scan` lines 153-181)

```bash
# POST results to tool-integration service
if [ -n "${CALLBACK_URL:-}" ]; then
    log "Posting results to $CALLBACK_URL..."

    # Wrap results with scanner identifier
    WRAPPED_OUTPUT=$(mktemp)
    jq '. + {"scanner": "solhint"}' "$OUTPUT_FILE" > "$WRAPPED_OUTPUT"

    # POST to callback URL
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$CALLBACK_URL" \
        -H "Content-Type: application/json" \
        -d @"$WRAPPED_OUTPUT" || echo "000")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$RESPONSE" | head -n-1)

    # Cleanup temp file
    rm -f "$WRAPPED_OUTPUT"

    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        log "Results posted successfully (HTTP $HTTP_CODE)"
    else
        log "Failed to post results (HTTP $HTTP_CODE)"
        log "Response: $RESPONSE_BODY"
        exit 1
    fi
else
    log "Warning: CALLBACK_URL not set, results not posted"
fi
```

### 2. Fixed Unbound Variable Issue

Changed `if [ -n "$CALLBACK_URL" ]` to `if [ -n "${CALLBACK_URL:-}" ]` to handle potentially unset variable with bash's `set -u` option.

### 3. Fixed SOL_COUNT Calculation Bug

**Before (broken):**
```bash
SOL_COUNT=$(echo "$SOL_FILES" | grep -c "\.sol$" || echo "0")
# When no files: grep returns "0" but exit code 1, triggering || echo "0"
# Result: "0\n0" (two zeros)
```

**After (fixed):**
```bash
if [ -n "$SOL_FILES" ]; then
    SOL_COUNT=$(echo "$SOL_FILES" | wc -l | tr -d ' ')
else
    SOL_COUNT=0
fi
```

### 4. Dockerfile Changes

**Added curl to runtime dependencies:**
```dockerfile
RUN apk add --no-cache \
        bash \
        curl \
        jq \
        git
```

**Updated version labels to 0.1.3:**
```dockerfile
LABEL version="0.1.3"
```

---

## Files Changed

| File | Change |
|------|--------|
| `scanner-images/solhint/solhint-scan` | Added POST callback logic, fixed CALLBACK_URL check, fixed SOL_COUNT bug |
| `scanner-images/solhint/Dockerfile` | Added curl dependency, version 0.1.0 -> 0.1.3 |
| `k8s/overlays/local/scanner-versions-patch.yaml` | Updated SCANNER_IMAGE_SOLHINT to 0.1.3 |

---

## Data Flow (After Fix)

```
1. API Service -> Orchestration: Scan request
2. Orchestration -> tool-integration: Trigger scanner job
3. tool-integration -> K8s: Create scanner Job with CALLBACK_URL env var
4. Scanner Job runs:
   a. Solhint analyzes contracts
   b. Results formatted to JSON with "scanner": "solhint"
   c. curl POSTs results to CALLBACK_URL (tool-integration)
5. tool-integration -> API Service: Forward results
6. Dashboard: Displays scan as "completed"
```

---

## Testing

### Test Scan Results
- **Scan ID:** `8a04dc90-a280-4952-8928-f69dc799326e`
- **Contract:** VulnerableAMMPatterns-01
- **Status:** Completed in 10 seconds
- **Findings:** 0 (test contract had no linting issues)

### Verification
```bash
# Run scanner test
/home/pwner/Git/docs/scripts/test-scanners.sh solhint
# Result: All tests passed!

# Verify scan status
curl -sL "http://app.0xapogee.com/api/v1/scans/8a04dc90-a280-4952-8928-f69dc799326e" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.status'
# Result: "completed"

# Pod logs confirm callback success
kubectl logs -n tool-integration-local scan-solhint-8a04dc90-4lp2w
# Output includes: "Results posted successfully (HTTP 200)"
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1.3 | 2026-01-20 | Added curl dependency, fixed all bugs |
| 0.1.2 | 2026-01-20 | Fixed SOL_COUNT calculation bug |
| 0.1.1 | 2026-01-20 | Fixed CALLBACK_URL unbound variable |
| 0.1.0 | 2026-01-19 | Initial version (missing callback) |

---

## Deployment

```bash
# Build image
cd /home/pwner/Git/blocksecops-tool-integration/scanner-images
./build-kubeadm.sh solhint

# Push to Harbor
docker tag scanner-solhint:0.1.3 harbor.blocksecops.local/blocksecops/scanner-solhint:0.1.3
docker push harbor.blocksecops.local/blocksecops/scanner-solhint:0.1.3

# Update ConfigMap and restart tool-integration
kubectl apply -k /home/pwner/Git/blocksecops-tool-integration/k8s/overlays/local/
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

---

## Related Documentation

- Similar fix for SolidityDefend: `SOLIDITYDEFEND-RESULT-POSTING-FIX-2025-11-28.md`
- Scanner validation tests: `docs/feature-tests/22-scanner-validation.md`
- Scanner integration guide: `blocksecops-docs/scanners/SCANNER-INTEGRATION-GUIDE.md`

---

**Status:** Fixed and Verified
**Tested By:** test-scanners.sh solhint
