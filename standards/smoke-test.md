# Platform Smoke Test Standards

**Version:** 4.0.0
**Last Updated:** March 10, 2026
**Status:** Active

## Overview

Smoke tests verify the platform is operational after deployments, upgrades, or service restarts. Run after every version bump or service restart. These tests are environment-agnostic and test the application layer only.

For GCP cluster infrastructure checks (Gateway, NetworkPolicy, TLS certificates, ESO, Cloud Armor), see [GCP Cluster Smoke Test](../gcp/smoke-test.md).

## Environment

| Setting | Value |
|---------|-------|
| **Platform URL** | `${PLATFORM_URL}` (e.g. `https://app.0xapogee.com`) |
| **Auth provider** | Supabase (external) |
| **Database** | PostgreSQL 15.4 (pgvector), database name `solidity_security`, user `blocksecops` |

## Pre-Flight Checks

Verify cluster health before smoke testing services:

```bash
ENV="${ENV:-prod}"

# 1. All pods running (expect empty output)
kubectl get pods -A --no-headers | grep -v "Running\|Completed" | grep -v "kube-system"

# 2. Core infrastructure pods
kubectl get pod -n postgresql-${ENV} postgresql-0 --no-headers
kubectl get pod -n redis-${ENV} -l app.kubernetes.io/name=redis --no-headers

# 3. Database accessible
kubectl exec -n postgresql-${ENV} postgresql-0 -- psql -U blocksecops -d solidity_security -c "SELECT 1;" 2>/dev/null

# 4. Version drift check (all services)
/home/pwner/Git/scripts/check-version-drift.sh
# Expected: all services show "OK" (source == kustomize == cluster)

# 5. Stale pod check (no Completed/Failed pods outside kube-system)
kubectl get pods -A --field-selector='status.phase!=Running' --no-headers | grep -v "kube-system"
# Expected: empty output

# 6. Stale ReplicaSet check
STALE_RS=$(kubectl get rs -A --no-headers | awk '$3==0 && $4==0' | wc -l)
echo "Stale ReplicaSets: $STALE_RS (warning if > 20)"

# 7. revisionHistoryLimit check (all managed deployments should be 3)
kubectl get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.revisionHistoryLimit}{"\n"}{end}' | \
  grep -v "kube-system\|gmp-system\|gke-managed\|external-secrets" | grep -v ": 3$"
# Expected: empty output
```

## Service Health Checks

### External Access (via Ingress)

```bash
PLATFORM_URL="${PLATFORM_URL:-app.0xapogee.com}"

# Dashboard - expect 200 with HTML
curl -s -o /dev/null -w "%{http_code}" "https://${PLATFORM_URL}/"

# API Service - expect JSON with status "healthy"
curl -s "https://${PLATFORM_URL}/api/v1/health/live"

# API Readiness - expect ready:true with database:true
curl -s "https://${PLATFORM_URL}/api/v1/health/ready"

# API OpenAPI docs - expect 200
curl -s -o /dev/null -w "%{http_code}" "https://${PLATFORM_URL}/docs"
```

### Internal Service Health (via kubectl exec)

Run from any pod in the cluster. The API service pod is a good choice:

```bash
ENV="${ENV:-prod}"

for check in \
  "tool-integration.tool-integration-${ENV}.svc.cluster.local:8005/health" \
  "orchestration.orchestration-${ENV}.svc.cluster.local:8004/health" \
  "notification.notification-${ENV}.svc.cluster.local:8003/health" \
  "intelligence-engine.intelligence-engine-${ENV}.svc.cluster.local:80/health" \
  "data-service.data-service-${ENV}.svc.cluster.local:80/health" \
  "contract-parser.contract-parser-${ENV}.svc.cluster.local:80/health" \
; do
  svc=$(echo "$check" | cut -d. -f1)
  echo -n "$svc: "
  kubectl exec -n api-service-${ENV} deployment/api-service -- \
    curl -s -m 5 "http://$check" 2>/dev/null | head -c 200
  echo ""
done
```

**Expected responses:**

| Service | Response Contains |
|---------|-------------------|
| tool-integration | `"status":"healthy"` |
| orchestration | `"status":"healthy"` |
| notification | `"status":"healthy"` |
| intelligence-engine | `"status":"healthy"` |
| data-service | `"status":"healthy"` |
| contract-parser | `"status":"OK"` |

## Authenticated Endpoint Tests

### Get Auth Token

Auth uses Supabase. Get a token before running authenticated tests:

```bash
SUPABASE_URL="https://huzjlpypdlelqnbjvxad.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1empscHlwZGxlbHFuYmp2eGFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4MTQ5MzYsImV4cCI6MjA3ODM5MDkzNn0.AabcSkKyi6HP3sLnTR7Bj-jZfgGgeSlEQZ0YRajC3i4"

TOKEN=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"EMAIL","password":"PASSWORD"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
```

### Core Endpoints

All should return 200 with valid auth, 401 without:

```bash
PLATFORM_URL="${PLATFORM_URL:-app.0xapogee.com}"
AUTH="-H 'Authorization: Bearer $TOKEN'"

# Must return 200
curl $AUTH "https://${PLATFORM_URL}/api/v1/scans?limit=2"
curl $AUTH "https://${PLATFORM_URL}/api/v1/contracts?limit=2"
curl $AUTH "https://${PLATFORM_URL}/api/v1/vulnerabilities?limit=2"
curl $AUTH "https://${PLATFORM_URL}/api/v1/organizations"
curl $AUTH "https://${PLATFORM_URL}/api/v1/scanners"
curl $AUTH "https://${PLATFORM_URL}/api/v1/deduplication/groups"
curl $AUTH "https://${PLATFORM_URL}/api/v1/projects"

# Must return 401 without auth
curl -s -o /dev/null -w "%{http_code}" "https://${PLATFORM_URL}/api/v1/scans"
# Expected: 401

# Search (POST)
curl $AUTH -X POST -H "Content-Type: application/json" \
  -d '{"query":"reentrancy","limit":5}' \
  "https://${PLATFORM_URL}/api/v1/search"
```

### GitHub URL Ingest (POST /contracts/from-github)

Added 2026-04-16. Verifies the customer-facing "Import from GitHub" path end-to-end: URL parsing → GitHub fetch → language detection → contract persist. Use a small, stable public file so the smoke test doesn't burn the 60/hr anonymous GitHub rate limit.

```bash
PLATFORM_URL="${PLATFORM_URL:-app.0xapogee.com}"
SMOKE_CONTRACT_NAME="smoke-test-$(date +%s)"

# Happy path — expect 201 with contract.id, source_repo_url, source_commit_hash populated
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${SMOKE_CONTRACT_NAME}\",\"github_url\":\"https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol\"}" \
  "https://${PLATFORM_URL}/api/v1/contracts/from-github" | \
  python3 -c "
import sys,json
d=json.load(sys.stdin)
ok = d.get('id') and d.get('source_repo_url') and d.get('language')=='solidity'
print('PASS' if ok else f'FAIL: {d}')"

# Invalid URL — expect 400 with detail.error == 'invalid_github_url'
curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"bad-url-smoke","github_url":"https://example.com/not-github"}' \
  "https://${PLATFORM_URL}/api/v1/contracts/from-github"
# Expected: 400

# Cleanup the smoke-test contract so it doesn't accumulate
CONTRACT_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://${PLATFORM_URL}/api/v1/contracts?limit=1" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for c in d.get('contracts', []):
    if c.get('name','').startswith('smoke-test-'): print(c['id']); break")
[ -n "$CONTRACT_ID" ] && curl -s -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  "https://${PLATFORM_URL}/api/v1/contracts/$CONTRACT_ID" > /dev/null
```

**Dashboard-side smoke (manual, after any dashboard deploy):**

1. Open `https://${PLATFORM_URL}/contracts` and click **Upload Contract**
2. Click the **GitHub URL** tab
3. Paste a blob URL (e.g. the OpenZeppelin ERC20.sol URL above)
4. Give it a name and click **Import from GitHub**
5. Confirm the modal closes and the contract appears in the list with language auto-detected

Expected failure modes to spot-check:
- Non-GitHub URL (e.g. `https://example.com/foo`) → "Enter a valid GitHub URL" client-side error
- Malformed GitHub URL (missing blob/tree segment) → same client-side error
- Valid URL but private repo → server returns 403 with "Use the GitHub OAuth integration" — message renders verbatim in the red banner

## Database Checks

```bash
ENV="${ENV:-prod}"

# Table count (expect ~88)
kubectl exec -n postgresql-${ENV} postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';"

# Key record counts
kubectl exec -n postgresql-${ENV} postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT 'users' as tbl, COUNT(*) FROM users
   UNION ALL SELECT 'scans', COUNT(*) FROM scans
   UNION ALL SELECT 'vulnerabilities', COUNT(*) FROM vulnerabilities
   UNION ALL SELECT 'contracts', COUNT(*) FROM contracts
   UNION ALL SELECT 'vulnerability_patterns', COUNT(*) FROM vulnerability_patterns;"

# SSL connections active
kubectl exec -n postgresql-${ENV} postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT COUNT(*) AS ssl_connections FROM pg_stat_ssl WHERE ssl = true;"
```

## Deployed Version Check

```bash
ENV="${ENV:-prod}"

for ns_svc in \
  "api-service-${ENV}/api-service" \
  "dashboard-${ENV}/dashboard" \
  "admin-portal-${ENV}/admin-portal" \
  "tool-integration-${ENV}/tool-integration" \
  "orchestration-${ENV}/orchestration" \
  "notification-${ENV}/notification" \
  "intelligence-engine-${ENV}/intelligence-engine" \
  "data-service-${ENV}/data-service" \
  "contract-parser-${ENV}/contract-parser" \
; do
  NS=$(echo "$ns_svc" | cut -d/ -f1)
  SVC=$(echo "$ns_svc" | cut -d/ -f2)
  IMG=$(kubectl get deployment -n "$NS" "$SVC" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  printf "  %-25s %s\n" "$SVC:" "$IMG"
done
```

### CronJob Version Drift Check

CronJobs must use the same image version as their parent Deployment. If `kubectl apply -k` is missed after a version bump, CronJobs silently run old code.

```bash
echo "=== CronJob Version Drift Check ==="
for ns in $(kubectl get cronjob -A --no-headers 2>/dev/null | awk '{print $1}' | sort -u); do
  for cj in $(kubectl get cronjob -n "$ns" --no-headers 2>/dev/null | awk '{print $1}'); do
    CJ_IMG=$(kubectl get cronjob -n "$ns" "$cj" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null)
    CJ_TAG=$(echo "$CJ_IMG" | rev | cut -d: -f1 | rev)
    IMG_NAME=$(echo "$CJ_IMG" | rev | cut -d: -f2- | rev)
    DEP_TAG=$(kubectl get deployment -n "$ns" -o jsonpath="{range .items[*]}{.spec.template.spec.containers[0].image}{'\n'}{end}" 2>/dev/null | grep "$IMG_NAME" | rev | cut -d: -f1 | rev)
    if [ -n "$DEP_TAG" ] && [ "$CJ_TAG" != "$DEP_TAG" ]; then
      echo "  DRIFT: $ns/$cj CronJob=$CJ_TAG Deployment=$DEP_TAG"
    elif [ -n "$DEP_TAG" ]; then
      echo "  OK:    $ns/$cj = $CJ_TAG"
    else
      echo "  INFO:  $ns/$cj = $CJ_TAG (no matching deployment)"
    fi
  done
done
```

## Encryption Check

```bash
PLATFORM_URL="${PLATFORM_URL:-app.0xapogee.com}"

# Encryption service configured (application-level)
curl -s "https://${PLATFORM_URL}/api/v1/health/ready" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('PASS' if d.get('checks',{}).get('encryption') else 'FAIL: encryption not configured')"
```

## Scan Health Checks

```bash
ENV="${ENV:-prod}"

# No scans stuck in queued/running for >1 hour
STALE=$(kubectl exec -n postgresql-${ENV} postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM scans WHERE status IN ('queued','running') AND created_at < NOW() - INTERVAL '1 hour';" 2>/dev/null | tr -d ' ')
echo "Stale scans: $STALE (expected: 0)"

# No failed scans without error_message
MISSING_ERR=$(kubectl exec -n postgresql-${ENV} postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM scans WHERE status='failed' AND error_message IS NULL;" 2>/dev/null | tr -d ' ')
echo "Failed scans missing error_message: $MISSING_ERR (expected: 0)"
```

### Scanner Image Health

```bash
# Verify scanner ConfigMap is loaded
kubectl get configmap scanner-versions -n tool-integration-prod -o jsonpath='{.data.SCANNER_IMAGE_SLITHER}'
# Expected: scanner-slither:0.3.8 (or current version)

# Verify scanner image is pullable (quick spot-check)
kubectl run scanner-smoke-test --image=$(kubectl get configmap scanner-versions -n tool-integration-prod -o jsonpath='{.data.SCANNER_REGISTRY}')/$(kubectl get configmap scanner-versions -n tool-integration-prod -o jsonpath='{.data.SCANNER_IMAGE_SLITHER}') \
  --restart=Never --rm -it -n tool-integration-prod --command -- bash -c 'ls /opt/solc-select/artifacts/ 2>/dev/null | wc -l && echo "solc versions pre-installed"'
# Expected: 18 solc versions pre-installed

# Verify no scanner jobs stuck
kubectl get jobs -n tool-integration-prod -l app=scanner --field-selector status.successful=0 --no-headers | wc -l
# Expected: 0 (or very few in-progress)
```

## WebSocket Health Check

WebSocket upgrade requires HTTP/1.1. Force it with curl to avoid false negatives from HTTP/2 ALPN:

```bash
PLATFORM_URL="${PLATFORM_URL:-app.0xapogee.com}"

curl --http1.1 -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -o /dev/null -w "%{http_code}" \
  "https://${PLATFORM_URL}/ws"
# Expected: 101 (Switching Protocols)
# Note: Do NOT use trailing slash — /ws/ returns 404 from FastAPI
```

## Quick Full Smoke Test Script

Run all checks in one script:

```bash
#!/bin/bash
# Platform smoke test — run after any deployment
set -euo pipefail

PLATFORM_URL="${PLATFORM_URL:-app.0xapogee.com}"
ENV="${ENV:-prod}"

PASS=0
FAIL=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $name"
    ((PASS++))
  else
    echo "  FAIL: $name (expected=$expected, got=$actual)"
    ((FAIL++))
  fi
}

echo "=== Pre-Flight ==="
check "PostgreSQL running" "Running" "$(kubectl get pod -n postgresql-${ENV} postgresql-0 --no-headers -o custom-columns=S:.status.phase 2>/dev/null)"
check "Redis running" "Running" "$(kubectl get pod -n redis-${ENV} -l app.kubernetes.io/name=redis --no-headers -o custom-columns=S:.status.phase 2>/dev/null | head -1)"

echo ""
echo "=== External Access ==="
check "Dashboard HTTPS" "200" "$(curl -s -o /dev/null -w '%{http_code}' "https://${PLATFORM_URL}/" 2>/dev/null)"
check "API health" "200" "$(curl -s -o /dev/null -w '%{http_code}' "https://${PLATFORM_URL}/api/v1/health/live" 2>/dev/null)"
check "API ready" "200" "$(curl -s -o /dev/null -w '%{http_code}' "https://${PLATFORM_URL}/api/v1/health/ready" 2>/dev/null)"

echo ""
echo "=== Internal Services ==="
for svc_url in \
  "tool-integration|tool-integration.tool-integration-${ENV}.svc.cluster.local:8005/health" \
  "orchestration|orchestration.orchestration-${ENV}.svc.cluster.local:8004/health" \
  "notification|notification.notification-${ENV}.svc.cluster.local:8003/health" \
  "intelligence-engine|intelligence-engine.intelligence-engine-${ENV}.svc.cluster.local:80/health" \
  "data-service|data-service.data-service-${ENV}.svc.cluster.local:80/health" \
  "contract-parser|contract-parser.contract-parser-${ENV}.svc.cluster.local:80/health" \
; do
  svc=$(echo "$svc_url" | cut -d'|' -f1)
  url=$(echo "$svc_url" | cut -d'|' -f2)
  resp=$(kubectl exec -n api-service-${ENV} deployment/api-service -- curl -s -m 5 "http://$url" 2>/dev/null)
  if echo "$resp" | grep -q '"status"'; then
    echo "  PASS: $svc"
    ((PASS++))
  else
    echo "  FAIL: $svc"
    ((FAIL++))
  fi
done

echo ""
echo "=== Database ==="
DB_OK=$(kubectl exec -n postgresql-${ENV} postgresql-0 -- psql -U blocksecops -d solidity_security -t -c "SELECT 1;" 2>/dev/null | tr -d ' ')
check "Database query" "1" "$DB_OK"

echo ""
echo "=== Encryption ==="
ENC_OK=$(curl -s "https://${PLATFORM_URL}/api/v1/health/ready" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('checks',{}).get('encryption') else 'false')" 2>/dev/null)
check "Encryption configured" "true" "$ENC_OK"

echo ""
echo "=== Scan Health ==="
STALE=$(kubectl exec -n postgresql-${ENV} postgresql-0 -- psql -U blocksecops -d solidity_security -t -c "SELECT COUNT(*) FROM scans WHERE status IN ('queued','running') AND created_at < NOW() - INTERVAL '1 hour';" 2>/dev/null | tr -d ' ')
check "No stale scans" "0" "$STALE"

MISSING_ERR=$(kubectl exec -n postgresql-${ENV} postgresql-0 -- psql -U blocksecops -d solidity_security -t -c "SELECT COUNT(*) FROM scans WHERE status='failed' AND error_message IS NULL;" 2>/dev/null | tr -d ' ')
check "Failed scans have error_message" "0" "$MISSING_ERR"

echo ""
echo "=== GitHub URL Ingest ==="
# Requires $TOKEN set — skip if unset
if [ -n "${TOKEN:-}" ]; then
  GH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"bad-url-smoke","github_url":"https://example.com/not-github"}' \
    "https://${PLATFORM_URL}/api/v1/contracts/from-github" 2>/dev/null)
  check "Invalid GitHub URL rejected" "400" "$GH_CODE"
else
  echo "  SKIP: GitHub URL ingest (TOKEN not set)"
fi

echo ""
echo "=== Summary ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
[ "$FAIL" -eq 0 ] && echo "  Result: ALL CHECKS PASSED" || echo "  Result: $FAIL CHECKS FAILED"
```

## When to Run

| Event | Required |
|-------|----------|
| After docker build + push + kubectl apply | Yes |
| After `kubectl rollout restart` | Yes |
| After database migration | Yes |
| After infrastructure changes | Yes |
| Daily (morning check) | Recommended |
| After cluster reboot | Yes |

**Pre-smoke-test:** Run the version drift checker first to catch stale deploys:

```bash
/home/pwner/Git/scripts/check-version-drift.sh
```

---

**See Also:**
- [GCP Cluster Smoke Test](../gcp/smoke-test.md) — Infrastructure-specific checks (Gateway, ESO, TLS, NetworkPolicy, Cloud Armor)
- [Testing & Deployment](./testing-deployment.md) — Build and deploy workflow
- [Service Availability](./service-availability.md) — Service access patterns
- [Docker Image Versioning](./docker-image-versioning.md) — Version bump workflow
- [Build Workflow](./build-workflow.md) — Deploy script and drift checker
