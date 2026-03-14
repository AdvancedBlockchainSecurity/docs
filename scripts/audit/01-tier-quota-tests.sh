#!/bin/bash
# Apogee Go-Live Audit: Tier System & Quota Enforcement (Section 1)
# Validates tier configuration, quota limits, and feature gates
set -euo pipefail

PASS=0
FAIL=0
WARN=0

BASE_URL="${BASE_URL:-https://app.0xApogee.com}"
CURL_FLAGS="${CURL_FLAGS:--sk}"
TIERS_JSON="${TIERS_JSON:-blocksecops-shared/tier-config/tiers.json}"

# Database connection
DB_NAMESPACE="${DB_NAMESPACE:-postgresql-local}"
DB_USER="${DB_USER:-blocksecops}"
DB_NAME="${DB_NAME:-solidity_security}"

psql_exec() {
  kubectl exec -n "$DB_NAMESPACE" postgresql-0 -- \
    psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "$1" 2>/dev/null
}

check() {
  local name="$1" expected="$2" actual="$3"
  actual=$(echo "$actual" | tr -d '[:space:]')
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (expected=$expected, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=============================================="
echo " Apogee Tier System & Quota Audit"
echo " Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================="

# --- Tier Configuration Validation ---
echo ""
echo "=== Tier Configuration (tiers.json) ==="

if [ ! -f "$TIERS_JSON" ]; then
  echo "  FAIL: tiers.json not found at $TIERS_JSON"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: tiers.json found"
  PASS=$((PASS + 1))

  # Verify 4 tiers exist
  TIER_COUNT=$(jq '.tiers | length' "$TIERS_JSON")
  check "4 tiers defined" "4" "$TIER_COUNT"

  # Verify tier names (tiers is an object with tier names as keys)
  TIER_NAMES=$(jq -r '.tiers | keys[]' "$TIERS_JSON" | sort | tr '\n' ',')
  check "Tier names" "developer,enterprise,growth,starter," "$TIER_NAMES"

  # Verify quota limits per tier
  echo ""
  echo "  Tier quota summary:"
  jq -r '.tiers | to_entries[] | "    \(.key): \(.value.quotas.monthlyContractLimit // "unlimited") scans/month"' "$TIERS_JSON"

  # Verify Developer tier limits
  DEV_SCANS=$(jq -r '.tiers.developer.quotas.monthlyContractLimit' "$TIERS_JSON")
  check "Developer scans/month = 3" "3" "$DEV_SCANS"

  # Verify Starter tier limits
  STARTER_SCANS=$(jq -r '.tiers.starter.quotas.monthlyContractLimit' "$TIERS_JSON")
  check "Starter scans/month = 25" "25" "$STARTER_SCANS"

  # Verify Growth tier limits
  GROWTH_SCANS=$(jq -r '.tiers.growth.quotas.monthlyContractLimit' "$TIERS_JSON")
  check "Growth scans/month = 50" "50" "$GROWTH_SCANS"

  # Verify rate limits exist for each tier
  echo ""
  echo "  Rate limit summary:"
  jq -r '.tiers | to_entries[] | "    \(.key): \(.value.rateLimits.webRequestsPerMinute // "N/A")/min, \(.value.rateLimits.apiRequestsPerHour // "N/A")/hour"' "$TIERS_JSON"

  # Verify Stripe product IDs are populated
  echo ""
  for tier in starter growth enterprise; do
    PRODUCT_ID=$(jq -r ".tiers.${tier}.stripe.productId // \"\"" "$TIERS_JSON")
    if [ -n "$PRODUCT_ID" ] && [ "$PRODUCT_ID" != "null" ] && [ "$PRODUCT_ID" != "" ]; then
      echo "  PASS: $tier has Stripe productId"
      PASS=$((PASS + 1))
    else
      echo "  WARN: $tier missing Stripe productId (may not be configured yet)"
      WARN=$((WARN + 1))
    fi
  done

  # Verify concurrent scan limits
  echo ""
  echo "  Concurrent scan limits:"
  jq -r '.tiers | to_entries[] | "    \(.key): \(.value.quotas.concurrentScansLimit // "N/A") concurrent"' "$TIERS_JSON"
fi

# --- 1.10 DB ENUM Constraint ---
echo ""
echo "=== 1.10 DB ENUM Constraints ==="

# Check tier ENUM type exists
TIER_ENUM=$(psql_exec "SELECT typname FROM pg_type WHERE typname LIKE '%tier%' AND typtype = 'e';" 2>/dev/null || echo "")
if [ -n "$TIER_ENUM" ]; then
  echo "  PASS: Tier ENUM type exists ($TIER_ENUM)"
  PASS=$((PASS + 1))

  # List valid values
  VALUES=$(psql_exec "SELECT string_agg(enumlabel, ', ' ORDER BY enumsortorder) FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = '$TIER_ENUM');" 2>/dev/null || echo "")
  echo "  INFO: Valid values: $VALUES"
else
  echo "  WARN: No tier ENUM type found (may use VARCHAR with CHECK constraint)"
  WARN=$((WARN + 1))
fi

# --- 1.11 Audit Log Immutability ---
echo ""
echo "=== 1.11 Audit Log Immutability ==="

# Check for protective triggers
TRIGGER_COUNT=$(psql_exec "
  SELECT COUNT(*)
  FROM information_schema.triggers
  WHERE event_object_table = 'audit_logs'
    AND (action_timing = 'BEFORE' OR action_timing = 'INSTEAD OF')
    AND (event_manipulation = 'UPDATE' OR event_manipulation = 'DELETE');
" 2>/dev/null || echo "0")

if [ "$(echo "$TRIGGER_COUNT" | tr -d '[:space:]')" -ge 1 ]; then
  echo "  PASS: Audit logs have UPDATE/DELETE protection triggers ($TRIGGER_COUNT)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: Audit logs missing UPDATE/DELETE protection triggers"
  FAIL=$((FAIL + 1))
fi

# --- 1.12 Quota Table ---
echo ""
echo "=== 1.12 User Quotas Table ==="

QUOTA_TABLE=$(psql_exec "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'user_quotas';" 2>/dev/null || echo "0")
if [ "$(echo "$QUOTA_TABLE" | tr -d '[:space:]')" = "1" ]; then
  echo "  PASS: user_quotas table exists"
  PASS=$((PASS + 1))

  # Check quota structure
  QUOTA_COLS=$(psql_exec "SELECT string_agg(column_name, ', ') FROM information_schema.columns WHERE table_name = 'user_quotas';" 2>/dev/null || echo "")
  echo "  INFO: Columns: $QUOTA_COLS"
else
  echo "  WARN: user_quotas table not found (quotas may be tracked differently)"
  WARN=$((WARN + 1))
fi

# --- Feature Gate Tests (require auth tokens) ---
echo ""
echo "=== Feature Gate Tests ==="

if [ -n "${DEVELOPER_TOKEN:-}" ]; then
  # 1.5: Developer tier can't create API keys
  API_KEY_RESP=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    -X POST "$BASE_URL/api/v1/api-keys" \
    -H "Authorization: Bearer $DEVELOPER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"audit-test","scopes":["scans:read"]}' 2>/dev/null)
  check "1.5 Developer can't create API keys" "403" "$API_KEY_RESP"
else
  echo "  SKIP: DEVELOPER_TOKEN not set (set to test feature gates)"
fi

if [ -n "${STARTER_TOKEN:-}" ]; then
  # 1.5: Starter tier can't create API keys
  API_KEY_RESP=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    -X POST "$BASE_URL/api/v1/api-keys" \
    -H "Authorization: Bearer $STARTER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"audit-test","scopes":["scans:read"]}' 2>/dev/null)
  check "1.5 Starter can't create API keys" "403" "$API_KEY_RESP"
else
  echo "  SKIP: STARTER_TOKEN not set"
fi

if [ -n "${GROWTH_TOKEN:-}" ]; then
  # Growth tier CAN create API keys
  API_KEY_RESP=$(curl $CURL_FLAGS -o /dev/null -w "%{http_code}" \
    -X POST "$BASE_URL/api/v1/api-keys" \
    -H "Authorization: Bearer $GROWTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"audit-test-growth","scopes":["scans:read"]}' 2>/dev/null)
  if [ "$API_KEY_RESP" = "200" ] || [ "$API_KEY_RESP" = "201" ]; then
    echo "  PASS: Growth tier CAN create API keys (HTTP $API_KEY_RESP)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: Growth tier can't create API keys (HTTP $API_KEY_RESP)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  SKIP: GROWTH_TOKEN not set"
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
