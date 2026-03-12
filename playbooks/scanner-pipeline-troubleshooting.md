# Playbook: Scanner Pipeline Troubleshooting

**Version:** 1.3.0
**Last Updated:** March 11, 2026

## Overview

This playbook covers diagnosing and fixing issues when scanner Jobs complete but produce 0 findings or fail to deliver results. Based on real-world fixes applied to 5 of 6 scanners in February 2026.

---

## Quick Diagnosis

```bash
# 1. Check if scanner Job completed
kubectl get jobs -n tool-integration-local -l scanner=<scanner-name>

# 2. Check scanner pod logs (before result collector cleans up)
kubectl logs -n tool-integration-local -l job-name=scan-<scanner>-<scan-id-prefix>

# 3. Check tool-integration logs for callback receipt
kubectl logs -n tool-integration-local deployment/tool-integration --tail=100 | grep "<scan-id>"

# 4. Check if results were forwarded to API service
kubectl logs -n tool-integration-local deployment/tool-integration --tail=100 | grep "POST.*results"
```

---

## Check Scan Error Message (v0.29.67+)

Failed scans now include an `error_message` field in the API response:

```bash
# Check error message via API
curl -sk https://app.0xapogee.local/api/v1/scans/{scan_id} \
  -H "Authorization: Bearer $TOKEN" | jq '{status, error_message}'
```

Common error messages:
- `"Scanners ['halmos'] require a project..."` — Scanner needs a multi-file project, not a single file
- `"Failed to trigger any scanners..."` — Tool-integration service is down
- `"Scanner triggering aborted after N failures"` — Multiple scanners failed to trigger
- `null` (on failed scan) — Legacy scan from before v0.29.67

---

## Common Issues

### Issue 1: Scanner Pod Exits with 0 Findings (UID Mismatch)

**Symptoms:**
- Scanner Job shows `status: completed`
- Pod logs show scanner ran but found nothing
- `scanner_results: null` in API response

**Root Cause:** K8s security context forces UID 1000, but Dockerfile creates user with UID 1001. Scanner can't write to directories owned by UID 1001.

**Diagnosis:**
```bash
# Check Dockerfile UID
grep -E 'useradd|adduser' scanner-images/<scanner>/Dockerfile

# Check K8s security context
grep -A5 'security_context' src/scanners/kubernetes_job_manager.py
```

**Fix:**
```bash
# In Dockerfile, change UID to 1000:
RUN useradd -m -u 1000 scanner  # Was: useradd -m -u 1001 scanner

# Rebuild and push
docker build -t harbor.blocksecops.local/blocksecops/scanner-<name>:<new-version> .
docker push harbor.blocksecops.local/blocksecops/scanner-<name>:<new-version>
```

---

### Issue 2: Callback POST Fails (Alpine DNS)

**Symptoms:**
- Scanner completes and finds vulnerabilities
- Log shows `Failed to post results (HTTP 000)`
- Only affects Alpine-based images (solhint, others)

**Root Cause:** Alpine's musl libc sends A and AAAA DNS queries on the same socket. CoreDNS processes them sequentially, causing the second query to time out.

**Diagnosis:**
```bash
# Test DNS from Alpine pod
kubectl run dns-test --image=alpine --rm -it -- sh -c "
  apk add --no-cache curl
  curl -v http://tool-integration.tool-integration-local.svc.cluster.local.:8005/health
"
```

**Fix:** Applied in `kubernetes_job_manager.py`:
```python
# 1. Add dnsConfig with single-request-reopen
dns_config=client.V1PodDNSConfig(
    options=[client.V1PodDNSConfigOption(name="single-request-reopen")]
),

# 2. Use trailing dot on FQDN in callback URLs
value=f"http://tool-integration.{self.namespace}.svc.cluster.local.:8005"
```

---

### Issue 3: Solhint Returns 0 Findings (stdout Pollution)

**Symptoms:**
- Solhint runs but `Solhint output is not valid JSON`
- 0 findings despite contracts having lint issues

**Root Cause:** Solhint prints debug messages to stdout before JSON:
```
A new version of Solhint is available: 6.0.3
isPublicLike :>>  false
comments.length :>>  0
[{"line":3,"column":1,"severity":"Warning",...}]
```

**Fix:** In `solhint-scan`:
```bash
# Capture raw output, extract only JSON line
timeout "$SOLHINT_TIMEOUT" solhint ... > "$SOLHINT_RAW" 2>/tmp/solhint-stderr.log
grep '^\[' "$SOLHINT_RAW" > "$SOLHINT_OUTPUT"

# Filter out conclusion entry (null ruleId)
jq '[.[] | select(.ruleId != null) | ...]'
```

---

### Issue 4: Slither Can't Find solc (HOME Not Set / emptyDir Shadows)

**Symptoms:**
- `PermissionError: [Errno 13] Permission denied: '/.solc-select'`
- Slither fails during compilation step
- Scanner pod stuck downloading solc from soliditylang.org

**Root Cause:** Two related issues:
1. When K8s overrides the user via `runAsUser: 1000`, the HOME env var is not set. solc-select defaults to `$HOME/.solc-select/`, which becomes `/.solc-select/`.
2. KJM mounts an `emptyDir` at `/home/scanner` for `readOnlyRootFilesystem` compliance, which shadows any solc binaries baked into `~/.solc-select/` during Docker build.

**Fix (v0.3.8):**
1. Add `ENV HOME=/home/scanner` to Dockerfile before `USER scanner`
2. Pre-install solc versions to `/opt/solc-select/artifacts` (survives emptyDir mount)
3. Add runtime seed step in `run-slither.sh` to copy from `/opt` to `$HOME/.solc-select/`

**Current state:** 18 solc versions (0.5.16–0.8.28) pre-installed in scanner-slither:0.3.8. Runtime seed completes in <1s.

---

### Issue 5: Scanner Reads Wrong Directory

**Symptoms:**
- Scanner runs but says "0 Solidity files found"
- Contracts are actually mounted at `/contracts`

**Root Cause:** Scanner entrypoint defaults to `/work` but K8s mounts contracts at `/contracts`.

**Fix:** Set `WORK_DIR=/contracts` in K8s Job environment:
```python
client.V1EnvVar(name="WORK_DIR", value="/contracts"),
```

---

### Issue 6: Semgrep Returns 0 Findings (No Internet)

**Symptoms:**
- Semgrep exits with code 7 or shows "No rules"
- Works locally but not in K8s cluster

**Root Cause:** Semgrep downloads rules from the Semgrep registry (p/smart-contracts, p/security-audit) at runtime. Air-gapped clusters can't reach the registry. The pre-cache approach (running semgrep during build) doesn't persist rules as files.

**Fix (applied in scanner-semgrep:0.3.5):** Download rules as local YAML files during Docker build:
```dockerfile
# Download rule packs as local YAML files for offline use
RUN curl -fsSL "https://semgrep.dev/c/p/smart-contracts" -o /rules/smart-contracts.yaml && \
    curl -fsSL "https://semgrep.dev/c/p/security-audit" -o /rules/security-audit.yaml

# Set ENV to use local files instead of registry
ENV SEMGREP_RULES="/rules/smart-contracts.yaml,/rules/security-audit.yaml"
ENV SEMGREP_SEND_METRICS=off
ENV SEMGREP_ENABLE_VERSION_CHECK=0
```

### Issue 7: Aderyn/Semgrep Callback Fails Intermittently

**Symptoms:** Scanner Job completes but no callback received by tool-integration. Occasional DNS resolution failures or connection timeouts.

**Root Cause:** The `curl` POST in the scanner entrypoint had no retry or timeout options. Transient DNS failures or K8s service routing delays cause a single-shot curl to fail.

**Fix (applied in scanner-aderyn:0.7.2 and scanner-semgrep:0.3.5):** Add curl resilience options:
```bash
curl -s -w "\n%{http_code}" -X POST "$CALLBACK_URL" \
    -H "Content-Type: application/json" \
    --connect-timeout 10 \
    --max-time 60 \
    --retry 3 \
    --retry-delay 2 \
    --retry-all-errors \
    -d @"$OUTPUT_FILE"
```

---

### Issue 10: Scanner Returns 0 Results Despite Completing (NetworkPolicy)

**Symptoms:**
- Scanner Jobs complete successfully (status: Completed)
- Scanner pod logs show analysis ran and found vulnerabilities
- Tool-integration receives NO callback (no POST logged)
- Database shows 0 vulnerabilities for the scan
- Other scans of the same contract previously had results

**Root Cause:** In namespaces with `default-deny-all` NetworkPolicy, scanner pods (label `app: scanner`) have no egress rule allowing them to POST results to tool-integration on port 8005. The `tool-integration-network-policy` only applies to pods with `app: tool-integration`, not scanner pods. Scanner pods can resolve DNS (via `allow-dns` policy) but cannot make HTTP connections.

**Diagnosis:**
```bash
# Check if scanner pods have egress NetworkPolicy
kubectl get networkpolicy -n tool-integration-<env> -o wide | grep scanner

# Verify scanner pod labels
kubectl get pods -n tool-integration-<env> -l app=scanner -o wide

# Check if tool-integration allows ingress from scanner pods
kubectl describe networkpolicy tool-integration-network-policy -n tool-integration-<env> | grep -A5 scanner

# Test connectivity from a scanner-labeled pod
kubectl run nettest --image=busybox --labels="app=scanner" -n tool-integration-<env> --rm -it -- \
  wget -qO- --timeout=5 http://tool-integration.tool-integration-<env>.svc.cluster.local.:8005/health || echo "BLOCKED"
```

**Fix (applied in v0.5.26):**
1. Added `k8s/base/scanner-network-policy.yaml` — grants scanner pods egress for DNS (port 53) and tool-integration callback (port 8005)
2. Added ingress rule to `tool-integration-network-policy` (base and all overlays) allowing traffic FROM `app: scanner` pods on port 8005
3. Both policies must exist: egress from scanner pods AND ingress to tool-integration from scanner pods

**Verification:**
```bash
# Confirm scanner NetworkPolicy exists
kubectl get networkpolicy scanner-network-policy -n tool-integration-<env>

# Confirm tool-integration accepts scanner ingress
kubectl describe networkpolicy tool-integration-network-policy -n tool-integration-<env> | grep -A3 "app: scanner"

# Run regression tests
pytest tests/regression/test_scanner_network_policy.py -v
```

**Prevention:** 10 regression tests in `tests/regression/test_scanner_network_policy.py` verify:
- Scanner NetworkPolicy exists and targets correct pods
- DNS and callback egress rules present
- Ingress from scanner pods allowed in base, GCP, and local overlays
- KJM pod template label matches NetworkPolicy selector
- CALLBACK_URL port matches NetworkPolicy allowed port

---

## Scanner Image Version Reference

| Scanner | Image | Version | Base | UID |
|---------|-------|---------|------|-----|
| slither | scanner-slither | 0.3.8 | python:3.11-slim | 1000 |
| aderyn | scanner-aderyn | 0.7.3 | debian:bookworm-slim | 1000 |
| semgrep | scanner-semgrep | 0.3.8 | python:3.11-slim | 1000 |
| solhint | scanner-solhint | 0.1.8 | node:20-alpine | 1000 (node) |
| wake | scanner-wake | 0.3.8 | python:3.11-slim | 1000 |
| soliditydefend | scanner-soliditydefend | 0.9.1 | debian:bookworm-slim | 1000 |

---

## Verification Commands

```bash
# Check all scanner image versions in ConfigMap
kubectl get configmap scanner-versions -n tool-integration-local -o yaml | grep SCANNER_IMAGE

# Check tool-integration default images
kubectl exec -n tool-integration-local deployment/tool-integration -- python3 -c "
from src.scanners.kubernetes_job_manager import KubernetesJobManager
print(KubernetesJobManager.default_images)
"

# Trigger a test scan
SCAN_ID=$(python3 -c 'import uuid; print(uuid.uuid4())')
kubectl exec -n tool-integration-local deployment/tool-integration -- python3 -c "
import requests
resp = requests.post('http://localhost:8005/scans/$SCAN_ID/trigger?scanner=solhint', json={
    'contract_source': 'pragma solidity ^0.8.0; contract Test { function f() public {} }',
    'contract_name': 'Test.sol'
})
print(resp.json())
"

# Watch for results
kubectl logs -n tool-integration-local deployment/tool-integration -f | grep "$SCAN_ID"
```

---

### Issue 8: 409 Conflict on Job Creation (Stale Jobs)

**Symptoms:**
- `Request failed with status code 409` when uploading a contract
- Scanner Job creation fails with `ApiException(409)`
- Retries of the same scan always fail

**Root Cause:** Job names previously used `scan_id[:8]` (only 4 bytes of entropy from the UUID). This caused collisions between different scans and 409 Conflict errors when retrying the same scan (stale Job with the same truncated name still exists).

**Fix (applied in kubernetes_job_manager.py):**
1. Job names now use the full scan_id: `scan-{scanner}-{scan_id}` (max 59 chars, under K8s 63-char limit)
2. ConfigMap names use the full scan_id: `scan-{scan_id}-source` (max 48 chars)
3. Job creation handles 409 with a proper poll-based wait loop:

```python
except ApiException as e:
    if e.status == 409:
        self.delete_job(job_name, propagation_policy="Background")
        for attempt in range(10):
            time.sleep(2)
            try:
                self.batch_v1.read_namespaced_job(name=job_name, namespace=self.namespace)
            except ApiException as check_err:
                if check_err.status == 404:
                    break  # Job is gone
                raise
        # Recreate the Job
        self.batch_v1.create_namespaced_job(namespace=self.namespace, body=job)
```

**Verification:**
```bash
# Check job naming uses full scan_id (no truncation)
grep 'job_name.*scan_id' src/scanners/kubernetes_job_manager.py

# Run regression tests
pytest tests/regression/test_job_name_collision.py -v
```

---

### Issue 9: Failed Callback Results Lost (No Dead-Letter)

**Symptoms:**
- Scanner completes and sends results, but API service is temporarily down
- Results forwarded by tool-integration get HTTP 5xx from api-service
- Results are lost with only an error log entry

**Fix (applied in main.py and dead_letter.py):**
- Added `DeadLetterStore` that persists failed forwarding payloads to `/tmp/dead-letters/`
- Failed forwards are automatically dead-lettered with scan_id, scanner, payload, and error
- Management endpoints:
  - `GET /api/v1/dead-letters` - List pending entries
  - `POST /api/v1/dead-letters/{id}/retry` - Retry forwarding
  - `DELETE /api/v1/dead-letters/{id}` - Discard entry
- Dead-letter count appears in `/health` response

**Verification:**
```bash
# Check dead-letter queue
curl -s http://127.0.0.1:8005/api/v1/dead-letters | jq .count
```

---

## Operational Improvements (February 2026)

### Readiness Endpoint

The `/ready` endpoint was missing from `main.py` despite being configured in the K8s readiness probe. Now implemented with checks for:
- `job_manager` initialization
- `collector_task` liveness (background polling running)

Returns HTTP 503 with reasons when not ready.

### Structured JSON Logging

Logging switched from plain-text to structured JSON format with correlation IDs:
```json
{"ts": "2026-02-12 19:44:12", "level": "INFO", "logger": "src.main", "msg": "...", "request_id": "abc-123", "scan_id": "def-456"}
```

`X-Request-ID` header is propagated through requests and returned in responses. `scan_id` is extracted from URL paths automatically.

### Prometheus Alerting Rules

New `PrometheusRule` (`k8s/base/prometheus-rules.yaml`) with alerts:
- `ScannerHighFailureRate` - >25% failure rate over 15 minutes
- `ScannerPipelineStalled` - Triggers sent but no callbacks received
- `JobConflictRateHigh` - High 409 Conflict rate
- `CallbackForwardingFailure` - API forwarding failing >10%
- `ScannerJobStuck` - Jobs running >15 minutes

### Port Fixes

Fixed mismatched ports in base K8s manifests:
- `deployment.yaml`: Prometheus annotation `8001` corrected to `9090`
- `ingress.yaml`: Backend service port `8001` corrected to `8005`
- `network-policy.yaml`: Ingress rules `8000` corrected to `8005`

---

## Related Documentation

- [Scanner Upgrade Playbook](./upgrade-scanner-image.md)
- [Scanner Data Audit](./scanner-data-audit.md)
- [Smart Contract Scanning Workflow](../workflows/smart-contract-scanning-workflow.md)
- [Feature Test: Scanner Pipeline E2E](../feature-tests/62-scanner-pipeline-e2e.md)
