# Platform Smoke Test Standards

**Version:** 1.7.0
**Last Updated:** February 28, 2026
**Status:** Active

## Overview

Smoke tests verify the platform is operational after deployments, upgrades, or infrastructure changes. Run after every version bump or service restart.

## Environment

| Setting | Value |
|---------|-------|
| **Server access** | `https://app.0xapogee.local` (Traefik with hostPort 80/443, HTTP redirects to HTTPS) |
| **Admin access** | `http://admin.0xapogee.local` (Traefik hostPort 80) |
| **Cluster type** | kubeadm with containerd |
| **Registry** | Harbor at `harbor.blocksecops.local` |
| **Auth provider** | Supabase (external) |
| **Database** | PostgreSQL 15.4, database name `solidity_security`, user `blocksecops` |
| **curl flag** | Use `-sk` for HTTPS (self-signed cert) |

## Pre-Flight Checks

Verify cluster health before smoke testing services:

```bash
# 1. All pods running
kubectl get pods --all-namespaces --no-headers | grep -v "Running\|Completed" | grep -v "kube-system"
# Expected: empty output (all pods running)

# 2. Core infrastructure pods
kubectl get pod -n postgresql-local postgresql-0 --no-headers
kubectl get pod -n redis-local -l app.kubernetes.io/name=redis --no-headers
kubectl get pod -n vault-local vault-0 --no-headers
kubectl get pod -n traefik-local -l app.kubernetes.io/name=traefik --no-headers

# 3. Vault unsealed
kubectl exec -n vault-local vault-0 -- vault status -format=json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if not d['sealed'] else 'SEALED')"

# 4. Database accessible
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "SELECT 1;" 2>/dev/null

# 5. Version drift check (all services)
/home/pwner/Git/scripts/check-version-drift.sh
# Expected: all services show "OK" (source == kustomize == cluster)

# 6. Stale pod check (no Completed/Failed pods outside kube-system)
kubectl get pods -A --field-selector='status.phase!=Running' --no-headers | grep -v "kube-system"
# Expected: empty output

# 7. Stale ReplicaSet check
STALE_RS=$(kubectl get rs -A --no-headers | awk '$3==0 && $4==0' | wc -l)
echo "Stale ReplicaSets: $STALE_RS (warning if > 20)"

# 8. revisionHistoryLimit check (all managed deployments should be 3)
kubectl get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.revisionHistoryLimit}{"\n"}{end}' | \
  grep -v "kube-system\|local-path\|external-secrets" | grep -v ": 3$"
# Expected: empty output (all managed deployments at 3)
```

## Service Health Checks

### External Access (via Traefik)

```bash
# Dashboard - expect 200 with HTML
curl -sk -o /dev/null -w "%{http_code}" https://app.0xapogee.local/

# API Service - expect JSON with status "healthy"
curl -sk https://app.0xapogee.local/api/v1/health/live

# API Readiness - expect ready:true with database:true
curl -sk https://app.0xapogee.local/api/v1/health/ready

# API OpenAPI docs - expect 200
curl -sk -o /dev/null -w "%{http_code}" https://app.0xapogee.local/docs

# Admin Portal - expect 200 with HTML (HTTP, not HTTPS)
curl -s -o /dev/null -w "%{http_code}" http://admin.0xapogee.local/
```

### Internal Service Health (via kubectl exec)

Run from any pod in the cluster. The API service pod is a good choice:

```bash
# All 6 internal services in one loop
for check in \
  "tool-integration.tool-integration-local.svc.cluster.local:8005/health" \
  "orchestration.orchestration-local.svc.cluster.local:8004/health" \
  "notification.notification-local.svc.cluster.local:8003/health" \
  "intelligence-engine.intelligence-engine-local.svc.cluster.local:80/health" \
  "data-service.data-service-local.svc.cluster.local:8001/health" \
  "contract-parser.contract-parser-local.svc.cluster.local:80/health" \
; do
  svc=$(echo "$check" | cut -d. -f1)
  echo -n "$svc: "
  kubectl exec -n api-service-local deployment/api-service -- \
    curl -s -m 5 "http://$check" 2>/dev/null | head -c 200
  echo ""
done
```

**Expected responses:**

| Service | Response Contains |
|---------|-------------------|
| tool-integration | `"status":"healthy"` |
| orchestration | `"status":"alive"` |
| notification | `"status":"alive"` |
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

**Note:** Test user emails use `.local` domain but Supabase requires valid email domains for new signups. Use existing accounts.

### Core Endpoints

All should return 200 with valid auth, 401 without:

```bash
AUTH="-H 'Authorization: Bearer $TOKEN'"

# Must return 200
curl -sk $AUTH "https://app.0xapogee.local/api/v1/scans?limit=2"
curl -sk $AUTH "https://app.0xapogee.local/api/v1/contracts?limit=2"
curl -sk $AUTH "https://app.0xapogee.local/api/v1/vulnerabilities?limit=2"
curl -sk $AUTH "https://app.0xapogee.local/api/v1/organizations"
curl -sk $AUTH "https://app.0xapogee.local/api/v1/scanners"
curl -sk $AUTH "https://app.0xapogee.local/api/v1/deduplication/groups"
curl -sk $AUTH "https://app.0xapogee.local/api/v1/projects"

# Must return 401 without auth
curl -sk -o /dev/null -w "%{http_code}" "https://app.0xapogee.local/api/v1/scans"
# Expected: 401

# Search (POST)
curl -sk $AUTH -X POST -H "Content-Type: application/json" \
  -d '{"query":"reentrancy","limit":5}' \
  "https://app.0xapogee.local/api/v1/search"
```

### Regression Tests (v0.27.0+)

These tests verify specific bug fixes. Expected behaviors after deploying v0.27.0:

```bash
# A1: Info severity removed — expect 422 (not 500)
curl -sk $AUTH "https://app.0xapogee.local/api/v1/deduplication/groups?severity=info"

# A2: Pending status mapped — expect 200 (mapped to queued) or 422 (not 500)
curl -sk $AUTH "https://app.0xapogee.local/api/v1/scans?status=pending"

# A3: Invalid severity validation — expect 422 (not 500)
curl -sk $AUTH "https://app.0xapogee.local/api/v1/deduplication/groups?severity=INVALID"

# A4: Audit logs — expect 200 or 403 (not 500)
curl -sk $AUTH "https://app.0xapogee.local/api/v1/audit-logs"

# A6: Scanner effectiveness — expect 200 with populated data
curl -sk $AUTH "https://app.0xapogee.local/api/v1/analytics/scanner-effectiveness"
```

## Database Checks

```bash
# Table count (expect ~88)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';"

# Key record counts
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT 'users' as tbl, COUNT(*) FROM users
   UNION ALL SELECT 'scans', COUNT(*) FROM scans
   UNION ALL SELECT 'vulnerabilities', COUNT(*) FROM vulnerabilities
   UNION ALL SELECT 'contracts', COUNT(*) FROM contracts
   UNION ALL SELECT 'vulnerability_patterns', COUNT(*) FROM vulnerability_patterns;"

# Verify no info severity in patterns (post-migration)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM vulnerability_patterns WHERE severity IN ('info', 'informational');"
# Expected: 0
```

## Deployed Version Check

```bash
# Check all service image tags
for ns_svc in \
  "api-service-local/api-service" \
  "dashboard-local/dashboard" \
  "admin-portal-local/admin-portal" \
  "tool-integration-local/tool-integration" \
  "orchestration-local/orchestration" \
  "notification-local/notification" \
  "intelligence-engine-local/intelligence-engine" \
  "data-service-local/data-service" \
  "contract-parser-local/contract-parser" \
; do
  NS=$(echo "$ns_svc" | cut -d/ -f1)
  SVC=$(echo "$ns_svc" | cut -d/ -f2)
  IMG=$(kubectl get deployment -n "$NS" "$SVC" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  printf "  %-25s %s\n" "$SVC:" "$IMG"
done
```

### CronJob Version Drift Check

**CRITICAL:** CronJobs must use the same image version as their parent Deployment. If `kubectl apply -k` is missed after a version bump, CronJobs silently run old code while Deployments may appear updated.

```bash
# Check CronJob images match Deployment images
echo "=== CronJob Version Drift Check ==="
for ns in $(kubectl get cronjob -A --no-headers 2>/dev/null | awk '{print $1}' | sort -u); do
  for cj in $(kubectl get cronjob -n "$ns" --no-headers 2>/dev/null | awk '{print $1}'); do
    CJ_IMG=$(kubectl get cronjob -n "$ns" "$cj" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null)
    CJ_TAG=$(echo "$CJ_IMG" | rev | cut -d: -f1 | rev)
    # Find matching deployment by image name
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

## Encryption & Security Checks

```bash
# Encryption service configured (readiness endpoint includes encryption check)
curl -sk https://app.0xapogee.local/api/v1/health/ready | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('PASS' if d.get('checks',{}).get('encryption') else 'FAIL: encryption not configured')"

# Vault unsealed
kubectl exec -n vault-local vault-0 -- vault status -format=json 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('PASS' if not d['sealed'] else 'FAIL: Vault sealed')"

# All ExternalSecrets synced
UNSYNCED=$(kubectl get externalsecret -A --no-headers 2>/dev/null | grep -v "SecretSynced" | wc -l)
echo "ExternalSecrets unsynced: $UNSYNCED (expected: 0)"
```

## Scan Health Checks

```bash
# No scans stuck in queued/running for >1 hour (stale scan check)
STALE=$(kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM scans WHERE status IN ('queued','running') AND created_at < NOW() - INTERVAL '1 hour';" 2>/dev/null | tr -d ' ')
echo "Stale scans: $STALE (expected: 0)"

# No failed scans without error_message
MISSING_ERR=$(kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM scans WHERE status='failed' AND error_message IS NULL;" 2>/dev/null | tr -d ' ')
echo "Failed scans missing error_message: $MISSING_ERR (expected: 0)"
```

## Infrastructure Health Checks

```bash
# Harbor health (registry should be under memory limit)
HARBOR_MEM=$(kubectl top pod -n harbor-local -l app=harbor --no-headers 2>/dev/null | awk '{print $3}' | head -1)
echo "Harbor registry memory: $HARBOR_MEM"

# Prometheus and adapter running (required for HPA custom metrics)
PROM=$(kubectl get pod -n monitoring-local -l app=prometheus --no-headers -o custom-columns=S:.status.phase 2>/dev/null | head -1)
ADAPTER=$(kubectl get pod -n monitoring-local -l app=prometheus-adapter --no-headers -o custom-columns=S:.status.phase 2>/dev/null | head -1)
echo "Prometheus: ${PROM:-NOT FOUND}  Adapter: ${ADAPTER:-NOT FOUND}"

# HPA status (check all HPAs can read metrics)
kubectl get hpa -A --no-headers 2>/dev/null | while read ns name _ _ _ _ _; do
  CONDS=$(kubectl get hpa -n "$ns" "$name" -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}' 2>/dev/null)
  echo "  HPA $ns/$name: ScalingActive=$CONDS"
done
```

## WebSocket Health Check

**Important:** WebSocket upgrade requires HTTP/1.1. When testing with `curl`, force HTTP/1.1 to avoid false negatives from HTTP/2 ALPN negotiation:

```bash
# CORRECT: Force HTTP/1.1 for WebSocket upgrade
curl -sk --http1.1 -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -o /dev/null -w "%{http_code}" \
  https://app.0xapogee.local/ws/
# Expected: 101 (Switching Protocols)

# WRONG: Default curl may negotiate HTTP/2 via ALPN, which does not support
# the Connection: Upgrade header → returns 404 (false negative)
curl -sk -H "Connection: Upgrade" -H "Upgrade: websocket" \
  https://app.0xapogee.local/ws/
# May return 404 even though WebSocket is working
```

**For reliable WebSocket testing, use a proper WebSocket client:**
```bash
# Python websockets library
python3 -c "
import asyncio, websockets, ssl
async def test():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    async with websockets.connect('wss://app.0xapogee.local/ws/', ssl=ctx) as ws:
        print('WebSocket connected successfully')
asyncio.run(test())
"
```

## Quick Full Smoke Test Script

Run all checks in one script:

```bash
#!/bin/bash
# Platform smoke test — run after any deployment
set -euo pipefail

PASS=0
FAIL=0
WARN=0

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
check "PostgreSQL running" "Running" "$(kubectl get pod -n postgresql-local postgresql-0 --no-headers -o custom-columns=S:.status.phase 2>/dev/null)"
check "Redis running" "Running" "$(kubectl get pod -n redis-local -l app.kubernetes.io/name=redis --no-headers -o custom-columns=S:.status.phase 2>/dev/null | head -1)"
check "Vault running" "Running" "$(kubectl get pod -n vault-local vault-0 --no-headers -o custom-columns=S:.status.phase 2>/dev/null)"
check "Traefik running" "Running" "$(kubectl get pod -n traefik-local -l app.kubernetes.io/name=traefik --no-headers -o custom-columns=S:.status.phase 2>/dev/null)"

echo ""
echo "=== External Access ==="
check "Dashboard HTTPS" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.local/ 2>/dev/null)"
check "API health" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.local/api/v1/health/live 2>/dev/null)"
check "API ready" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.local/api/v1/health/ready 2>/dev/null)"
check "Admin portal" "200" "$(curl -s -o /dev/null -w '%{http_code}' http://admin.0xapogee.local/ 2>/dev/null)"

echo ""
echo "=== Internal Services ==="
for svc_url in \
  "tool-integration|tool-integration.tool-integration-local.svc.cluster.local:8005/health" \
  "orchestration|orchestration.orchestration-local.svc.cluster.local:8004/api/v1/health/live" \
  "notification|notification.notification-local.svc.cluster.local:8003/api/v1/health/live" \
  "intelligence|intelligence-engine.intelligence-engine-local.svc.cluster.local:80/health" \
  "data-service|data-service.data-service-local.svc.cluster.local:8001/health" \
  "contract-parser|contract-parser.contract-parser-local.svc.cluster.local:80/health" \
; do
  svc=$(echo "$svc_url" | cut -d'|' -f1)
  url=$(echo "$svc_url" | cut -d'|' -f2)
  resp=$(kubectl exec -n api-service-local deployment/api-service -- curl -s -m 5 "http://$url" 2>/dev/null)
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
DB_OK=$(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -t -c "SELECT 1;" 2>/dev/null | tr -d ' ')
check "Database query" "1" "$DB_OK"

echo ""
echo "=== Encryption & Secrets ==="
ENC_OK=$(curl -sk https://app.0xapogee.local/api/v1/health/ready 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('checks',{}).get('encryption') else 'false')" 2>/dev/null)
check "Encryption configured" "true" "$ENC_OK"

VAULT_OK=$(kubectl exec -n vault-local vault-0 -- vault status -format=json 2>/dev/null | python3 -c "import sys,json; print('unsealed' if not json.load(sys.stdin)['sealed'] else 'sealed')" 2>/dev/null)
check "Vault unsealed" "unsealed" "$VAULT_OK"

UNSYNCED=$(kubectl get externalsecret -A --no-headers 2>/dev/null | grep -v "SecretSynced" | wc -l | tr -d ' ')
check "ExternalSecrets synced" "0" "$UNSYNCED"

echo ""
echo "=== Scan Health ==="
STALE=$(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -t -c "SELECT COUNT(*) FROM scans WHERE status IN ('queued','running') AND created_at < NOW() - INTERVAL '1 hour';" 2>/dev/null | tr -d ' ')
check "No stale scans" "0" "$STALE"

MISSING_ERR=$(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -t -c "SELECT COUNT(*) FROM scans WHERE status='failed' AND error_message IS NULL;" 2>/dev/null | tr -d ' ')
check "Failed scans have error_message" "0" "$MISSING_ERR"

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
| After infrastructure changes (Traefik, Vault, etc.) | Yes |
| Daily (morning check) | Recommended |
| After cluster reboot | Yes |

**Pre-smoke-test:** Run the version drift checker first to catch stale deploys:

```bash
/home/pwner/Git/scripts/check-version-drift.sh
```

---

**See Also:**
- [Testing & Deployment](./testing-deployment.md) — Build and deploy workflow
- [Service Availability](./service-availability.md) — Service access patterns
- [Docker Image Versioning](./docker-image-versioning.md) — Version bump workflow
- [Build Workflow](./build-workflow.md) — Deploy script and drift checker
