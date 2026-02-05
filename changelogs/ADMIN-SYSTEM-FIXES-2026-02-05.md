# Admin System Page Bug Fixes

## Version Changes - February 5, 2026

**Date:** 2026-02-05
**Components:** blocksecops-admin-portal (0.1.11 -> 0.1.12), scanner-semgrep (0.3.1 -> 0.3.2)
**Type:** Bug Fix
**Priority:** High
**Status:** Complete

---

## Summary

Fixed two bugs on the Admin System page:
1. API Service response time showing "-" instead of actual millisecond value
2. Semgrep scanner showing "Degraded" status due to malformed JSON in callback results

---

## Issue 1: API Service Response Time Not Displayed

### Symptoms
- Admin System page Platform Services table showed "-" for API Service response time
- All other services displayed response times correctly

### Root Cause
In `AdminSystem.tsx`, when `isApiService` was true, the code extracted `status` from `apiHealth` but never assigned `responseTime`:

```typescript
// BEFORE (bug)
if (isApiService && apiHealth) {
  status = apiHealth.status || 'unknown';
  // responseTime never set!
} else if (serviceHealth) {
  status = serviceHealth.status;
  responseTime = serviceHealth.response_time_ms;
}
```

### Fix
Added the missing assignment:

```typescript
// AFTER (fixed)
if (isApiService && apiHealth) {
  status = apiHealth.status || 'unknown';
  responseTime = apiHealth.response_time_ms;  // Added
} else if (serviceHealth) {
  status = serviceHealth.status;
  responseTime = serviceHealth.response_time_ms;
}
```

### Files Modified
| File | Change |
|------|--------|
| `blocksecops-admin-portal/src/pages/AdminSystem.tsx` (line 342) | Added `responseTime = apiHealth.response_time_ms` |
| `blocksecops-admin-portal/package.json` | Version 0.1.11 -> 0.1.12 |
| `blocksecops-admin-portal/k8s/overlays/local/kustomization.yaml` | newTag 0.1.6 -> 0.1.12 |

---

## Issue 2: Semgrep "Degraded" Status (JSON Generation Bug)

### Symptoms
- Admin System page showed Semgrep as "Degraded" with 2 failed jobs
- Scanner job logs showed: `ERROR: Failed to post results to callback URL (HTTP 500)`
- Tool-integration returned: `{"detail":"Expecting value: line 1 column 155 (char 154)"}`

### Root Cause
The `semgrep-scan` wrapper script had a JSON generation bug when Semgrep found zero findings:

1. When Semgrep produces empty results, `$FINDINGS` could become an empty string
2. The validation `jq empty` on an empty string returns exit code 0 (passes silently)
3. `$(echo "" | jq 'length')` produces **no output** (not "0") but exits 0
4. The heredoc JSON output became `"total_findings": ,` (invalid JSON at char ~154)
5. Tool-integration service failed to parse this invalid JSON (HTTP 500)
6. Scanner job marked as failed, retried, failed again
7. More failures than successes triggered "degraded" status

### Reproduction
```bash
# Original validation passes on empty string (bug)
FINDINGS=""
echo "$FINDINGS" | jq empty 2>/dev/null  # Exit code: 0 (no error!)

# Resulting invalid JSON
echo "\"total_findings\": $(echo "" | jq 'length'),"
# Output: "total_findings": ,    <-- invalid!
```

### Fix
Three changes to `scanner-images/semgrep/semgrep-scan`:

**1. Empty string guard in validation (line 151):**
```bash
# BEFORE
if ! echo "$FINDINGS" | jq empty 2>/dev/null; then

# AFTER
if [ -z "$FINDINGS" ] || ! echo "$FINDINGS" | jq empty 2>/dev/null; then
```

**2. Pre-computed total findings with fallback (new lines 170-174):**
```bash
TOTAL_FINDINGS=$(echo "$FINDINGS" | jq 'length' 2>/dev/null || echo "0")
if [ -z "$TOTAL_FINDINGS" ]; then
    TOTAL_FINDINGS=0
fi
```

**3. Use pre-computed variable in JSON output (line 187) and log (line 203):**
```bash
# BEFORE (inline subshell that could return empty)
"total_findings": $(echo "$FINDINGS" | jq 'length'),

# AFTER (pre-computed with guaranteed fallback)
"total_findings": $TOTAL_FINDINGS,
```

### Files Modified
| File | Change |
|------|--------|
| `blocksecops-tool-integration/scanner-images/semgrep/semgrep-scan` | JSON generation bug fix |
| `blocksecops-tool-integration/scanner-images/semgrep/Dockerfile` | Version label 0.3.0 -> 0.3.2 |
| `blocksecops-tool-integration/scanner-images/build-all.sh` | Semgrep version 0.3.0 -> 0.3.2 |
| `blocksecops-tool-integration/k8s/overlays/local/scanner-versions-patch.yaml` | scanner-semgrep:0.3.1 -> 0.3.2 |

---

## Deployment Steps

### Admin Portal (0.1.12)
```bash
cd /home/pwner/Git/blocksecops-admin-portal
VERSION=0.1.12
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  --build-arg VITE_ENVIRONMENT=local \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/admin-portal:${VERSION} .

docker push harbor.blocksecops.local/blocksecops/admin-portal:${VERSION}
kubectl apply -k k8s/overlays/local/
```

### Scanner Semgrep (0.3.2)
```bash
cd /home/pwner/Git/blocksecops-tool-integration/scanner-images/semgrep

docker build -t harbor.blocksecops.local/blocksecops/scanner-semgrep:0.3.2 .
docker push harbor.blocksecops.local/blocksecops/scanner-semgrep:0.3.2

kubectl apply -k /home/pwner/Git/blocksecops-tool-integration/k8s/overlays/local/
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

---

## Verification

### API Service Response Time
1. Access Admin System page at `http://admin.blocksecops.local/system`
2. Verify "API Service" row shows a response time value (e.g., "5ms") instead of "-"

### Semgrep Status
1. `kubectl get jobs -n tool-integration-local -l scanner=semgrep` - no failed jobs
2. `kubectl exec -n tool-integration-local deploy/tool-integration -- curl -s http://localhost:8005/scanners/health | jq '.scanners.semgrep.status'` - should show "available"
3. Admin System page shows Semgrep as "Available" instead of "Degraded"

---

## Lessons Learned

1. **Empty string vs null in shell**: `jq empty` on an empty string returns exit 0, not an error. Always check `[ -z "$VAR" ]` before piping to jq.
2. **Inline subshells in heredocs**: Avoid `$(command)` inside heredoc JSON generation. Pre-compute values with fallbacks.
3. **Property extraction consistency**: When extracting data from API responses, ensure all relevant fields are assigned in every branch of conditional logic.

---

## Related Documentation

- [Admin System Health Fixes (2026-02-05)](../../TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-02-05-ADMIN-SYSTEM-HEALTH-FIXES.md)
- [Admin Portal Dashboard (2026-02-04)](ADMIN-PORTAL-DASHBOARD-2026-02-04.md)
- [Semgrep Troubleshooting Checklist](../../TaskDocs-BlockSecOps/scanners/semgrep/semgrep-troubleshooting-checklist.md)
- [Docker Image Versioning Standards](../standards/docker-image-versioning.md)
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.1.12 | 2026-02-05 | Fix API Service response time display |
| 0.3.2 | 2026-02-05 | Fix Semgrep JSON generation for empty results |

---

**Maintained By:** BlockSecOps Team
**Status:** Complete
