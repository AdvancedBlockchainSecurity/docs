# Platform Smoke Test Standards

**Version:** 1.0.0
**Last Updated:** February 6, 2026
**Status:** Active

## Overview

Smoke tests verify the platform is operational after deployments, upgrades, or infrastructure changes. Run after every version bump or service restart.

## Environment

| Setting | Value |
|---------|-------|
| **Server access** | `https://app.blocksecops.local` (Traefik with hostPort 80/443, HTTP redirects to HTTPS) |
| **Admin access** | `http://admin.blocksecops.local` (Traefik hostPort 80) |
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
```

## Service Health Checks

### External Access (via Traefik)

```bash
# Dashboard - expect 200 with HTML
curl -sk -o /dev/null -w "%{http_code}" https://app.blocksecops.local/

# API Service - expect JSON with status "healthy"
curl -sk https://app.blocksecops.local/api/v1/health/live

# API Readiness - expect ready:true with database:true
curl -sk https://app.blocksecops.local/api/v1/health/ready

# API OpenAPI docs - expect 200
curl -sk -o /dev/null -w "%{http_code}" https://app.blocksecops.local/docs

# Admin Portal - expect 200 with HTML (HTTP, not HTTPS)
curl -s -o /dev/null -w "%{http_code}" http://admin.blocksecops.local/
```

### Internal Service Health (via kubectl exec)

Run from any pod in the cluster. The API service pod is a good choice:

```bash
# All 6 internal services in one loop
for check in \
  "tool-integration.tool-integration-local.svc.cluster.local:8005/health" \
  "orchestration.orchestration-local.svc.cluster.local:8004/api/v1/health/live" \
  "notification.notification-local.svc.cluster.local:8003/api/v1/health/live" \
  "intelligence-engine.intelligence-engine-local.svc.cluster.local:80/health" \
  "data-service.data-service-local.svc.cluster.local:8001/" \
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
| data-service | `"status":"running"` |
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
curl -sk $AUTH "https://app.blocksecops.local/api/v1/scans?limit=2"
curl -sk $AUTH "https://app.blocksecops.local/api/v1/contracts?limit=2"
curl -sk $AUTH "https://app.blocksecops.local/api/v1/vulnerabilities?limit=2"
curl -sk $AUTH "https://app.blocksecops.local/api/v1/organizations"
curl -sk $AUTH "https://app.blocksecops.local/api/v1/scanners"
curl -sk $AUTH "https://app.blocksecops.local/api/v1/deduplication/groups"
curl -sk $AUTH "https://app.blocksecops.local/api/v1/projects"

# Must return 401 without auth
curl -sk -o /dev/null -w "%{http_code}" "https://app.blocksecops.local/api/v1/scans"
# Expected: 401

# Search (POST)
curl -sk $AUTH -X POST -H "Content-Type: application/json" \
  -d '{"query":"reentrancy","limit":5}' \
  "https://app.blocksecops.local/api/v1/search"
```

### Regression Tests (v0.27.0+)

These tests verify specific bug fixes. Expected behaviors after deploying v0.27.0:

```bash
# A1: Info severity removed — expect 422 (not 500)
curl -sk $AUTH "https://app.blocksecops.local/api/v1/deduplication/groups?severity=info"

# A2: Pending status mapped — expect 200 (mapped to queued) or 422 (not 500)
curl -sk $AUTH "https://app.blocksecops.local/api/v1/scans?status=pending"

# A3: Invalid severity validation — expect 422 (not 500)
curl -sk $AUTH "https://app.blocksecops.local/api/v1/deduplication/groups?severity=INVALID"

# A4: Audit logs — expect 200 or 403 (not 500)
curl -sk $AUTH "https://app.blocksecops.local/api/v1/audit-logs"

# A6: Scanner effectiveness — expect 200 with populated data
curl -sk $AUTH "https://app.blocksecops.local/api/v1/analytics/scanner-effectiveness"
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

**Current versions (as of February 12, 2026):**

| Service | Version |
|---------|---------|
| api-service | 0.28.20 |
| dashboard | 0.42.0 |
| admin-portal | 0.4.0 |
| tool-integration | 0.3.22 |
| orchestration | 0.9.13 |
| notification | 0.1.2 |
| intelligence-engine | 0.3.0 |
| data-service | 0.2.0 |
| contract-parser | 0.2.0 |

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
check "Dashboard HTTPS" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.blocksecops.local/ 2>/dev/null)"
check "API health" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.blocksecops.local/api/v1/health/live 2>/dev/null)"
check "API ready" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.blocksecops.local/api/v1/health/ready 2>/dev/null)"
check "Admin portal" "200" "$(curl -s -o /dev/null -w '%{http_code}' http://admin.blocksecops.local/ 2>/dev/null)"

echo ""
echo "=== Internal Services ==="
for svc_url in \
  "tool-integration|tool-integration.tool-integration-local.svc.cluster.local:8005/health" \
  "orchestration|orchestration.orchestration-local.svc.cluster.local:8004/api/v1/health/live" \
  "notification|notification.notification-local.svc.cluster.local:8003/api/v1/health/live" \
  "intelligence|intelligence-engine.intelligence-engine-local.svc.cluster.local:80/health" \
  "data-service|data-service.data-service-local.svc.cluster.local:8001/" \
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

---

**See Also:**
- [Testing & Deployment](./testing-deployment.md) — Build and deploy workflow
- [Port Forwarding / Service Access](./port-forwarding.md) — Service URLs and ports
- [Docker Image Versioning](./docker-image-versioning.md) — Version bump workflow
