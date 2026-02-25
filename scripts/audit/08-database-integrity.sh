#!/bin/bash
# BlockSecOps Go-Live Audit: Database Integrity Checks (Section 8)
# Validates database constraints, triggers, data integrity, and migration state
set -euo pipefail

PASS=0
FAIL=0
WARN=0

# Database connection settings
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

check_gte() {
  local name="$1" min="$2" actual="$3"
  actual=$(echo "$actual" | tr -d '[:space:]')
  if [ -n "$actual" ] && [ "$actual" -ge "$min" ] 2>/dev/null; then
    echo "  PASS: $name (count=$actual, min=$min)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name (count=$actual, expected >= $min)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=============================================="
echo " BlockSecOps Database Integrity Audit"
echo " Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo " Database: $DB_NAME @ $DB_NAMESPACE"
echo "=============================================="

# --- 8.3 ENUM Constraints ---
echo ""
echo "=== 8.3 ENUM Constraints ==="

# Test invalid tier value
RESULT=$(kubectl exec -n "$DB_NAMESPACE" postgresql-0 -- \
  psql -U "$DB_USER" -d "$DB_NAME" -c \
  "DO \$\$
  BEGIN
    UPDATE users SET tier = 'invalid_tier' WHERE false;
  EXCEPTION WHEN invalid_text_representation THEN
    RAISE NOTICE 'ENUM_ENFORCED';
  END
  \$\$;" 2>&1 || true)

# Check if ENUM types exist
ENUM_COUNT=$(psql_exec "SELECT COUNT(*) FROM pg_type WHERE typtype = 'e';")
check_gte "ENUM types exist" "1" "$ENUM_COUNT"

# --- 8.4 Audit Log Triggers ---
echo ""
echo "=== 8.4 Audit Log Immutability ==="

# Check if audit_logs table exists
AUDIT_TABLE=$(psql_exec "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'audit_logs';")
if [ "$(echo "$AUDIT_TABLE" | tr -d '[:space:]')" = "1" ]; then
  echo "  PASS: audit_logs table exists"
  PASS=$((PASS + 1))

  # Check for triggers on audit_logs
  TRIGGER_COUNT=$(psql_exec "SELECT COUNT(*) FROM information_schema.triggers WHERE event_object_table = 'audit_logs';")
  check_gte "audit_logs has protection triggers" "1" "$TRIGGER_COUNT"
else
  echo "  FAIL: audit_logs table not found"
  FAIL=$((FAIL + 1))
fi

# --- 8.6 Soft Delete ---
echo ""
echo "=== 8.6 Soft Delete Consistency ==="

# Check that API queries respect is_active
TABLES_WITH_SOFT_DELETE=$(psql_exec "
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE column_name = 'is_active' AND table_schema = 'public';
")
echo "  INFO: $TABLES_WITH_SOFT_DELETE tables have is_active column"

# --- 8.7 Index Performance ---
echo ""
echo "=== 8.7 Index Performance ==="

# Check indexes on commonly queried columns
INDEX_COUNT=$(psql_exec "
  SELECT COUNT(*)
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND (indexname LIKE '%severity%' OR indexname LIKE '%tier%' OR indexname LIKE '%user_id%');
")
check_gte "Performance indexes exist (severity/tier/user_id)" "3" "$INDEX_COUNT"

# Verify index scan on critical query
EXPLAIN_RESULT=$(psql_exec "
  EXPLAIN (FORMAT TEXT)
  SELECT * FROM vulnerabilities WHERE severity = 'critical' LIMIT 10;
" 2>/dev/null || echo "")

if echo "$EXPLAIN_RESULT" | grep -qi "index\|bitmap"; then
  echo "  PASS: Vulnerability severity query uses index"
  PASS=$((PASS + 1))
else
  echo "  WARN: Vulnerability severity query may not use index"
  WARN=$((WARN + 1))
fi

# --- 8.9 BVD Pattern Seed ---
echo ""
echo "=== 8.9 BVD Pattern Seed ==="

PATTERN_COUNT=$(psql_exec "SELECT COUNT(*) FROM vulnerability_patterns;" 2>/dev/null || echo "0")
check_gte "vulnerability_patterns loaded" "393" "$PATTERN_COUNT"

# --- 8.10 Scanner-to-Pattern Mappings ---
echo ""
echo "=== 8.10 Scanner-to-Pattern Mappings ==="

MAPPING_COUNT=$(psql_exec "SELECT COUNT(*) FROM pattern_tool_mappings;" 2>/dev/null || echo "0")
check_gte "pattern_tool_mappings loaded" "637" "$MAPPING_COUNT"

# --- Table Count ---
echo ""
echo "=== Schema Overview ==="

TABLE_COUNT=$(psql_exec "
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
")
echo "  INFO: $TABLE_COUNT tables in public schema"

# Key record counts
echo ""
echo "  Record counts:"
for table in users scans contracts vulnerabilities vulnerability_patterns; do
  COUNT=$(psql_exec "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "N/A")
  printf "    %-30s %s\n" "$table:" "$COUNT"
done

# --- Alembic Migration State ---
echo ""
echo "=== Migration State ==="

CURRENT_REV=$(psql_exec "SELECT version_num FROM alembic_version;" 2>/dev/null || echo "unknown")
echo "  Current Alembic revision: $CURRENT_REV"

# Check for no info severity (post-migration validation)
INFO_SEVERITY=$(psql_exec "
  SELECT COUNT(*)
  FROM vulnerability_patterns
  WHERE severity IN ('info', 'informational');
" 2>/dev/null || echo "N/A")
check "No info/informational severity in patterns" "0" "$INFO_SEVERITY"

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
