#!/bin/bash
# BlockSecOps Go-Live Audit: Master Runner
# Executes all automated audit scripts and produces a summary report
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${SCRIPT_DIR}/reports"
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/audit-report-${TIMESTAMP}.txt"

mkdir -p "$REPORT_DIR"

# Audit scripts in order
SCRIPTS=(
  "01-tier-quota-tests.sh"
  "06-auth-tests.sh"
  "07-k8s-security-audit.sh"
  "08-database-integrity.sh"
  "09-appsec-tests.sh"
  "smoke-test-production.sh"
)

TOTAL_PASS=0
TOTAL_FAIL=0
SECTION_RESULTS=()

echo "=============================================="
echo " BlockSecOps Go-Live Audit Suite"
echo " Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo " Report: $REPORT_FILE"
echo "=============================================="
echo ""

{
  echo "BlockSecOps Go-Live Audit Report"
  echo "================================"
  echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Runner: $(whoami)@$(hostname)"
  echo ""
} > "$REPORT_FILE"

for script in "${SCRIPTS[@]}"; do
  SCRIPT_PATH="${SCRIPT_DIR}/${script}"
  SECTION_NAME="${script%.sh}"

  if [ ! -f "$SCRIPT_PATH" ]; then
    echo "  SKIP: $script (not found)"
    continue
  fi

  echo "--- Running: $script ---"
  echo "" >> "$REPORT_FILE"
  echo "=== $SECTION_NAME ===" >> "$REPORT_FILE"

  set +e
  OUTPUT=$(bash "$SCRIPT_PATH" 2>&1)
  EXIT_CODE=$?
  set -e

  echo "$OUTPUT" >> "$REPORT_FILE"

  # Extract pass/fail counts
  SECT_PASS=$(echo "$OUTPUT" | grep "Passed:" | tail -1 | awk '{print $NF}' || echo "0")
  SECT_FAIL=$(echo "$OUTPUT" | grep "Failed:" | tail -1 | awk '{print $NF}' || echo "0")

  TOTAL_PASS=$((TOTAL_PASS + SECT_PASS))
  TOTAL_FAIL=$((TOTAL_FAIL + SECT_FAIL))

  if [ "$EXIT_CODE" -eq 0 ]; then
    echo "  PASS: $script (${SECT_PASS} passed)"
    SECTION_RESULTS+=("PASS: $SECTION_NAME")
  else
    echo "  FAIL: $script (${SECT_FAIL} failures)"
    SECTION_RESULTS+=("FAIL: $SECTION_NAME ($SECT_FAIL failures)")
  fi
  echo ""
done

# Final summary
echo ""
echo "=============================================="
echo " FINAL SUMMARY"
echo "=============================================="
echo ""

for result in "${SECTION_RESULTS[@]}"; do
  echo "  $result"
done

echo ""
echo "  Total Passed: $TOTAL_PASS"
echo "  Total Failed: $TOTAL_FAIL"
echo ""

if [ "$TOTAL_FAIL" -eq 0 ]; then
  echo "  OVERALL: ALL AUDIT SECTIONS PASSED"
  DECISION="GO"
else
  echo "  OVERALL: $TOTAL_FAIL TOTAL FAILURES - REVIEW REQUIRED"
  DECISION="NO-GO (review failures)"
fi

# Append summary to report
{
  echo ""
  echo "=============================================="
  echo " FINAL SUMMARY"
  echo "=============================================="
  echo ""
  for result in "${SECTION_RESULTS[@]}"; do
    echo "  $result"
  done
  echo ""
  echo "  Total Passed: $TOTAL_PASS"
  echo "  Total Failed: $TOTAL_FAIL"
  echo "  Decision: $DECISION"
  echo ""
  echo "  Report saved to: $REPORT_FILE"
} >> "$REPORT_FILE"

echo ""
echo "  Full report: $REPORT_FILE"
