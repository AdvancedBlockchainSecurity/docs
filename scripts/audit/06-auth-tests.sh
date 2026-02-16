#!/bin/bash
# BlockSecOps Go-Live Audit: Authentication & Authorization (Section 6)
# Validates auth methods, API key security, session management, and CORS
set -euo pipefail

PASS=0
FAIL=0
WARN=0

BASE_URL="${BASE_URL:-https://app.blocksecops.com}"
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
echo " BlockSecOps Authentication & Authorization Audit"
echo " Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo " Target: $BASE_URL"
echo "=============================================="

# --- 6.1 Supabase JWT Login ---
echo ""
echo "=== 6.1 Supabase JWT Login ==="

if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_KEY:-}" ] && [ -n "${TEST_EMAIL:-}" ] && [ -n "${TEST_PASSWORD:-}" ]; then
  LOGIN_RESP=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\"}" 2>/dev/null)

  TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
  if [ -n "$TOKEN" ]; then
    echo "  PASS: Supabase login successful, JWT received"
    PASS=$((PASS + 1))

    # Test authenticated endpoint
    ME_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
      "$BASE_URL/api/v1/users/me" \
      -H "Authorization: Bearer $TOKEN" 2>/dev/null)
    check "JWT accepted by API" "200" "$ME_STATUS"
  else
    echo "  FAIL: Supabase login failed"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  SKIP: Supabase credentials not set"
  echo "         Set: SUPABASE_URL, SUPABASE_KEY, TEST_EMAIL, TEST_PASSWORD"
fi

# --- 6.5 API Key Auth ---
echo ""
echo "=== 6.5 API Key Authentication ==="

if [ -n "${API_KEY:-}" ]; then
  API_KEY_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/v1/scans?limit=1" \
    -H "X-API-Key: $API_KEY" 2>/dev/null)
  check "API key auth works" "200" "$API_KEY_STATUS"
else
  echo "  SKIP: API_KEY not set"
fi

# --- 6.6 Expired API Key ---
echo ""
echo "=== 6.6 Expired API Key Rejection ==="

EXPIRED_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
  "$BASE_URL/api/v1/scans" \
  -H "X-API-Key: bso_expired_invalid_key_12345" 2>/dev/null)
check "Invalid API key rejected" "401" "$EXPIRED_STATUS"

# --- 6.10 CORS ---
echo ""
echo "=== 6.10 CORS Enforcement ==="

# Test unauthorized origin
CORS_RESP=$(curl $CURL_FLAGS -s -D - -o /dev/null \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  -X OPTIONS \
  "$BASE_URL/api/v1/health/live" 2>/dev/null)

if echo "$CORS_RESP" | grep -qi "access-control-allow-origin: https://evil.com"; then
  echo "  FAIL: CORS allows https://evil.com"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: CORS blocks https://evil.com"
  PASS=$((PASS + 1))
fi

# Test authorized origin
CORS_VALID=$(curl $CURL_FLAGS -s -D - -o /dev/null \
  -H "Origin: https://app.blocksecops.com" \
  -H "Access-Control-Request-Method: GET" \
  -X OPTIONS \
  "$BASE_URL/api/v1/health/live" 2>/dev/null)

if echo "$CORS_VALID" | grep -qi "access-control-allow-origin"; then
  echo "  PASS: CORS allows authorized origin"
  PASS=$((PASS + 1))
else
  echo "  WARN: CORS response missing for authorized origin"
  WARN=$((WARN + 1))
fi

# --- 6.12 Scope-Based Authorization ---
echo ""
echo "=== 6.12 Scope-Based Authorization ==="

# Unauthenticated access should be blocked
UNAUTH_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
  "$BASE_URL/api/v1/scans" 2>/dev/null)
check "Unauthenticated request blocked" "401" "$UNAUTH_STATUS"

# Access to admin endpoints without admin role
if [ -n "${TOKEN:-}" ]; then
  ADMIN_STATUS=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    "$BASE_URL/api/v1/admin/users" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null)
  if [ "$ADMIN_STATUS" = "403" ] || [ "$ADMIN_STATUS" = "404" ]; then
    echo "  PASS: Non-admin can't access admin endpoints (HTTP $ADMIN_STATUS)"
    PASS=$((PASS + 1))
  else
    echo "  WARN: Admin endpoint returned HTTP $ADMIN_STATUS (expected 403 or 404)"
    WARN=$((WARN + 1))
  fi
fi

# --- Cookie Security ---
echo ""
echo "=== 6.11 Cookie Security ==="

COOKIE_HEADERS=$(curl $CURL_FLAGS -D - -o /dev/null "$BASE_URL/" 2>/dev/null | grep -i "set-cookie" || echo "")
if [ -n "$COOKIE_HEADERS" ]; then
  if echo "$COOKIE_HEADERS" | grep -qi "httponly"; then
    echo "  PASS: Cookies have HttpOnly flag"
    PASS=$((PASS + 1))
  else
    echo "  WARN: Cookies may not have HttpOnly flag"
    WARN=$((WARN + 1))
  fi

  if echo "$COOKIE_HEADERS" | grep -qi "secure"; then
    echo "  PASS: Cookies have Secure flag"
    PASS=$((PASS + 1))
  else
    echo "  WARN: Cookies may not have Secure flag"
    WARN=$((WARN + 1))
  fi
else
  echo "  INFO: No Set-Cookie headers on root page (auth cookies set on login)"
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
