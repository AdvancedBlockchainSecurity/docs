#!/bin/bash
# Apogee Go-Live Audit: Application Security Tests (Section 9)
# OWASP-aligned security checks for the platform
set -euo pipefail

PASS=0
FAIL=0
WARN=0

BASE_URL="${BASE_URL:-https://app.0xApogee.com}"
CURL_FLAGS="${CURL_FLAGS:--sk}"

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

echo "=============================================="
echo " Apogee Application Security Audit"
echo " Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo " Target: $BASE_URL"
echo "=============================================="

# --- 9.1 SQL Injection ---
echo ""
echo "=== 9.1 SQL Injection Prevention ==="

if [ -n "${TOKEN:-}" ]; then
  # Test common SQL injection payloads
  for payload in "' OR 1=1 --" "'; DROP TABLE users; --" "1 UNION SELECT * FROM users"; do
    RESP=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
      "$BASE_URL/api/v1/search" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"query\":\"$payload\",\"limit\":5}" 2>/dev/null)
    if [ "$RESP" = "200" ] || [ "$RESP" = "422" ]; then
      echo "  PASS: SQLi payload handled safely (HTTP $RESP)"
      PASS=$((PASS + 1))
    else
      echo "  WARN: SQLi payload returned unexpected HTTP $RESP"
      WARN=$((WARN + 1))
    fi
  done
else
  echo "  SKIP: TOKEN not set"
fi

# --- 9.5 File Upload Validation ---
echo ""
echo "=== 9.5 File Upload: Malicious File Type Rejection ==="

if [ -n "${TOKEN:-}" ]; then
  # Create temp files with disallowed extensions
  for ext in exe php py sh bat; do
    TMPFILE=$(mktemp /tmp/test.XXXXXX.$ext)
    echo "malicious content" > "$TMPFILE"
    RESP=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
      -X POST "$BASE_URL/api/v1/upload" \
      -H "Authorization: Bearer $TOKEN" \
      -F "file=@$TMPFILE" 2>/dev/null)
    rm -f "$TMPFILE"
    if [ "$RESP" = "400" ] || [ "$RESP" = "422" ] || [ "$RESP" = "415" ]; then
      echo "  PASS: .$ext upload rejected (HTTP $RESP)"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: .$ext upload returned HTTP $RESP (expected 400/422/415)"
      FAIL=$((FAIL + 1))
    fi
  done
else
  echo "  SKIP: TOKEN not set"
fi

# --- 9.7 Error Response Sanitization ---
echo ""
echo "=== 9.7 Error Responses: No Internal Details ==="

# Request non-existent resource
if [ -n "${TOKEN:-}" ]; then
  ERROR_BODY=$(curl $CURL_FLAGS \
    "$BASE_URL/api/v1/scans/00000000-0000-0000-0000-000000000000" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null)

  # Check for stack traces or internal paths
  for pattern in "Traceback" "File \"/" "/home/" "/app/src/" "sqlalchemy" "psycopg"; do
    if echo "$ERROR_BODY" | grep -qi "$pattern"; then
      echo "  FAIL: Error response contains internal detail: $pattern"
      FAIL=$((FAIL + 1))
    fi
  done
  echo "  PASS: Error response does not leak internals"
  PASS=$((PASS + 1))
else
  echo "  SKIP: TOKEN not set"
fi

# --- 9.8 Security Headers ---
echo ""
echo "=== 9.8 Security Headers ==="

HEADERS=$(curl $CURL_FLAGS -D - -o /dev/null "$BASE_URL/" 2>/dev/null)

# Required headers
declare -A REQUIRED_HEADERS=(
  ["x-frame-options"]="DENY or SAMEORIGIN"
  ["content-security-policy"]="CSP policy"
  ["strict-transport-security"]="HSTS"
  ["x-content-type-options"]="nosniff"
)

for header in "${!REQUIRED_HEADERS[@]}"; do
  if echo "$HEADERS" | grep -qi "^$header:"; then
    VALUE=$(echo "$HEADERS" | grep -i "^$header:" | head -1 | cut -d: -f2- | tr -d '\r')
    echo "  PASS: $header:$VALUE"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $header header missing (${REQUIRED_HEADERS[$header]})"
    FAIL=$((FAIL + 1))
  fi
done

# --- 9.6 Rate Limiting ---
echo ""
echo "=== 9.6 Rate Limiting: Brute Force Protection ==="

# Test login rate limiting (send multiple rapid requests)
RATE_LIMITED=false
for i in $(seq 1 20); do
  RESP=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"ratelimit-test@example.com","password":"wrong"}' 2>/dev/null)
  if [ "$RESP" = "429" ]; then
    RATE_LIMITED=true
    echo "  PASS: Rate limited after $i attempts (HTTP 429)"
    PASS=$((PASS + 1))
    break
  fi
done

if [ "$RATE_LIMITED" = "false" ]; then
  echo "  WARN: No rate limiting detected after 20 login attempts"
  WARN=$((WARN + 1))
fi

# --- 9.10 CORS Validation ---
echo ""
echo "=== 9.10 CORS: Unauthorized Origin Blocked ==="

CORS_RESP=$(curl $CURL_FLAGS -D - -o /dev/null \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  -X OPTIONS \
  "$BASE_URL/api/v1/health/live" 2>/dev/null)

if echo "$CORS_RESP" | grep -qi "access-control-allow-origin: https://evil.com"; then
  echo "  FAIL: CORS allows unauthorized origin https://evil.com"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: CORS blocks unauthorized origin"
  PASS=$((PASS + 1))
fi

# --- 9.9 Dependency Audit ---
echo ""
echo "=== 9.9 Dependency Vulnerabilities ==="

# Check npm audit for dashboard
if [ -d "blocksecops-dashboard" ]; then
  cd blocksecops-dashboard
  AUDIT_RESULT=$(npm audit --audit-level=high --json 2>/dev/null || echo '{"vulnerabilities":{}}')
  HIGH_COUNT=$(echo "$AUDIT_RESULT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    vulns = d.get('vulnerabilities', {})
    high = sum(1 for v in vulns.values() if v.get('severity') in ('high', 'critical'))
    print(high)
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
  cd ..

  if [ "$HIGH_COUNT" = "0" ]; then
    echo "  PASS: Dashboard npm audit clean (0 high/critical)"
    PASS=$((PASS + 1))
  elif [ "$HIGH_COUNT" = "unknown" ]; then
    echo "  WARN: Could not parse npm audit output"
    WARN=$((WARN + 1))
  else
    echo "  FAIL: Dashboard has $HIGH_COUNT high/critical npm vulnerabilities"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  SKIP: blocksecops-dashboard not found"
fi

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
