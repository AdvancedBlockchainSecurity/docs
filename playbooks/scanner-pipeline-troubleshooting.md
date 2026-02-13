# Playbook: Scanner Pipeline Troubleshooting

**Version:** 1.0.0
**Last Updated:** February 12, 2026

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

### Issue 4: Slither Can't Find solc (HOME Not Set)

**Symptoms:**
- `PermissionError: [Errno 13] Permission denied: '/.solc-select'`
- Slither fails during compilation step

**Root Cause:** When K8s overrides the user via `runAsUser: 1000`, the HOME env var is not set. solc-select defaults to `$HOME/.solc-select/`, which becomes `/.solc-select/`.

**Fix:** Add `ENV HOME=/home/scanner` to Dockerfile before `USER scanner`.

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

## Scanner Image Version Reference

| Scanner | Image | Version | Base | UID |
|---------|-------|---------|------|-----|
| slither | scanner-slither | 0.3.2 | python:3.11-slim | 1000 |
| aderyn | scanner-aderyn | 0.7.2 | debian:bookworm-slim | 1000 |
| semgrep | scanner-semgrep | 0.3.5 | python:3.11-slim | 1000 |
| solhint | scanner-solhint | 0.1.6 | node:20-alpine | 1000 (node) |
| wake | scanner-wake | 0.3.6 | python:3.11-slim | 1000 |
| soliditydefend | scanner-soliditydefend | 0.7.1 | python:3.11-slim | 1000 |

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

## Related Documentation

- [Scanner Upgrade Playbook](./upgrade-scanner-image.md)
- [Scanner Data Audit](./scanner-data-audit.md)
- [Smart Contract Scanning Workflow](../workflows/smart-contract-scanning-workflow.md)
- [Feature Test: Scanner Pipeline E2E](../feature-tests/62-scanner-pipeline-e2e.md)
