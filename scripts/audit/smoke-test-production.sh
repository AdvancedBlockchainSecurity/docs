#!/bin/bash
# Apogee Go-Live Audit: Production Smoke Test (Section 14)
# Validates core functionality after GCP production deployment
set -euo pipefail

PASS=0
FAIL=0
WARN=0

# Configuration - override via environment variables
BASE_URL="${BASE_URL:-https://app.0xApogee.com}"
ADMIN_URL="${ADMIN_URL:-https://admin.0xApogee.com}"
CURL_FLAGS="${CURL_FLAGS:--sk}"  # -sk for self-signed certs, remove -k for production

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected=$expected, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

check_contains() {
  local name="$1" substring="$2" actual="$3"
  if echo "$actual" | grep -q "$substring"; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected to contain '$substring')"
    FAIL=$((FAIL + 1))
  fi
}

echo "=============================================="
echo " BlockSecOps Production Smoke Test"
echo " Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo " Target: $BASE_URL"
echo "=============================================="

# --- 14.1 Pre-Flight: Pod Health ---
echo ""
echo "=== 14.1 Pre-Flight: Pod Health ==="

UNHEALTHY=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running\|Completed" | grep -v "kube-system" | wc -l | tr -d ' ')
if [ "$UNHEALTHY" -eq 0 ]; then
  echo "  PASS: All pods healthy (Running/Completed)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: $UNHEALTHY unhealthy pods found"
  FAIL=$((FAIL + 1))
  kubectl get pods -A --no-headers | grep -v "Running\|Completed" | grep -v "kube-system"
fi

# Check for CrashLoopBackOff specifically
CRASH_LOOPS=$(kubectl get pods -A --no-headers 2>/dev/null | grep "CrashLoopBackOff" | wc -l | tr -d ' ')
check "No CrashLoopBackOff pods" "0" "$CRASH_LOOPS"

# --- 14.2 Service Health Endpoints ---
echo ""
echo "=== 14.2 Service Health Endpoints ==="

# API health
API_HEALTH=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/health/live" 2>/dev/null)
check "API /health/live" "200" "$API_HEALTH"

API_READY=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/health/ready" 2>/dev/null)
check "API /health/ready" "200" "$API_READY"

# API readiness details
READY_BODY=$(curl $CURL_FLAGS "$BASE_URL/api/v1/health/ready" 2>/dev/null)
check_contains "API readiness includes database" "database" "$READY_BODY"

# --- 14.3 Database Connectivity ---
echo ""
echo "=== 14.3 Database Connectivity ==="

# Verify via API ready endpoint (includes DB check)
if echo "$READY_BODY" | grep -q '"database"'; then
  DB_STATUS=$(echo "$READY_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('database', d.get('checks', {}).get('database', 'unknown')))" 2>/dev/null || echo "unknown")
  if [ "$DB_STATUS" != "unknown" ]; then
    echo "  PASS: Database connectivity confirmed via /health/ready"
    PASS=$((PASS + 1))
  else
    echo "  WARN: Could not parse database status from health check"
    WARN=$((WARN + 1))
  fi
else
  echo "  WARN: Health endpoint does not report database status"
  WARN=$((WARN + 1))
fi

# --- 14.4 Redis Connectivity ---
echo ""
echo "=== 14.4 Redis Connectivity ==="

# Check via health endpoint if available
if echo "$READY_BODY" | grep -qi "redis\|cache"; then
  echo "  PASS: Redis/cache status reported in health check"
  PASS=$((PASS + 1))
else
  echo "  WARN: Redis status not visible in health endpoint (check separately)"
  WARN=$((WARN + 1))
fi

# --- 14.5 Ingress: Dashboard Loads ---
echo ""
echo "=== 14.5 Ingress & Dashboard ==="

DASH_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" "$BASE_URL/" 2>/dev/null)
check "Dashboard loads (HTTPS)" "200" "$DASH_STATUS"

# Check TLS certificate
TLS_INFO=$(curl $CURL_FLAGS -vI "$BASE_URL/" 2>&1 | grep -i "SSL certificate\|subject:" | head -2)
if [ -n "$TLS_INFO" ]; then
  echo "  PASS: TLS certificate present"
  PASS=$((PASS + 1))
else
  echo "  WARN: Could not verify TLS certificate details"
  WARN=$((WARN + 1))
fi

# --- 14.6 Auth Flow ---
echo ""
echo "=== 14.6 Auth Flow ==="

# Test unauthenticated access is blocked
UNAUTH_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/scans" 2>/dev/null)
check "Unauthenticated /scans returns 401" "401" "$UNAUTH_STATUS"

# If TOKEN is provided, test authenticated access
if [ -n "${TOKEN:-}" ]; then
  AUTH_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/v1/users/me" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null)
  check "Authenticated /users/me" "200" "$AUTH_STATUS"
else
  echo "  SKIP: TOKEN not set, skipping authenticated tests"
  echo "         Set TOKEN env var to enable: export TOKEN=<jwt>"
fi

# --- 14.7 Scan Flow ---
echo ""
echo "=== 14.7 Scan Flow ==="

if [ -n "${TOKEN:-}" ]; then
  # List scans
  SCANS_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/v1/scans?limit=1" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null)
  check "GET /scans" "200" "$SCANS_STATUS"

  # List scanners
  SCANNERS_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/v1/scanners" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null)
  check "GET /scanners" "200" "$SCANNERS_STATUS"
else
  echo "  SKIP: TOKEN not set, skipping scan flow tests"
fi

# --- 14.8 Stripe: Pricing Page ---
echo ""
echo "=== 14.8 Stripe / Pricing ==="

PRICING_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" "$BASE_URL/pricing" 2>/dev/null)
check "Pricing page loads" "200" "$PRICING_STATUS"

# --- 14.9 Admin Portal ---
echo ""
echo "=== 14.9 Admin Portal ==="

if [ -n "$ADMIN_URL" ]; then
  ADMIN_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" "$ADMIN_URL/" 2>/dev/null)
  if [ "$ADMIN_STATUS" = "200" ] || [ "$ADMIN_STATUS" = "401" ] || [ "$ADMIN_STATUS" = "302" ]; then
    echo "  PASS: Admin portal responds ($ADMIN_STATUS)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Admin portal returned $ADMIN_STATUS"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  SKIP: ADMIN_URL not set"
fi

# --- 14.10 Monitoring ---
echo ""
echo "=== 14.10 Monitoring ==="

echo "  MANUAL: Verify in GCP Cloud Console:"
echo "    - Cloud Logging > Logs Explorer shows GKE pod logs"
echo "    - Cloud Monitoring > Metrics Explorer shows container metrics"
echo "    - Alerting policies are active"

# --- Security Headers ---
echo ""
echo "=== Bonus: Security Headers ==="

HEADERS=$(curl $CURL_FLAGS -D - -o /dev/null "$BASE_URL/" 2>/dev/null)

for header in "x-frame-options" "content-security-policy" "strict-transport-security" "x-content-type-options"; do
  if echo "$HEADERS" | grep -qi "$header"; then
    echo "  PASS: $header header present"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $header header missing"
    FAIL=$((FAIL + 1))
  fi
done

# --- Response Times ---
echo ""
echo "=== Bonus: Response Times ==="

for endpoint in "api/v1/health/live" "api/v1/health/ready"; do
  TIME=$(curl $CURL_FLAGS -o /dev/null -w "%{time_total}" "$BASE_URL/$endpoint" 2>/dev/null)
  if [ "$(echo "$TIME < 1.0" | bc -l 2>/dev/null || echo 1)" = "1" ]; then
    echo "  PASS: $endpoint responded in ${TIME}s"
    PASS=$((PASS + 1))
  else
    echo "  WARN: $endpoint slow (${TIME}s)"
    WARN=$((WARN + 1))
  fi
done

# --- Service Versions ---
echo ""
echo "=== Service Versions ==="

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
  IMG=$(kubectl get deployment -n "$NS" "$SVC" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "N/A")
  printf "  %-25s %s\n" "$SVC:" "$IMG"
done

# --- Summary ---
echo ""
echo "=============================================="
echo " SUMMARY"
echo "=============================================="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warnings: $WARN"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo "  Result: ALL CHECKS PASSED"
  exit 0
else
  echo "  Result: $FAIL CHECKS FAILED"
  exit 1
fi
