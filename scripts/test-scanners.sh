#!/bin/bash
# Test scanner functionality via API
#
# This script tests the updated scanners (slither, aderyn, solhint) by:
# 1. Getting an API token from Supabase
# 2. Creating a test contract if needed
# 3. Running scans with each scanner
# 4. Verifying scan completion and results
#
# Usage:
#   ./test-scanners.sh                    # Test all updated scanners
#   ./test-scanners.sh slither            # Test specific scanner
#   ./test-scanners.sh --list-contracts   # List available contracts
#
# Last Updated: January 19, 2026

set -e

# Note: We use || true with arithmetic because ((x++)) returns exit code 1 when x is 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# API Configuration
API_URL="http://app.0xapogee.local/api/v1"

# Supabase Configuration (matches api-service configmap)
SUPABASE_URL="https://huzjlpypdlelqnbjvxad.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1empscHlwZGxlbHFuYmp2eGFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4MTQ5MzYsImV4cCI6MjA3ODM5MDkzNn0.AabcSkKyi6HP3sLnTR7Bj-jZfgGgeSlEQZ0YRajC3i4"

# Test credentials
TEST_EMAIL="jasonbrailowbizop@mail.com"
TEST_PASSWORD="TestPass123"

# Default scanners to test (the ones we just updated)
DEFAULT_SCANNERS=("slither" "aderyn" "solhint")

# Curl wrapper that follows redirects while preserving auth header
api_get() {
    curl -sL --location-trusted "$@"
}

api_post() {
    curl -sL --location-trusted -X POST "$@"
}

# Parse arguments
SCANNERS_TO_TEST=()
LIST_CONTRACTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --list-contracts|-l)
            LIST_CONTRACTS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options] [scanner1] [scanner2] ..."
            echo ""
            echo "Test scanner functionality via API."
            echo ""
            echo "Options:"
            echo "  --list-contracts, -l  List available contracts"
            echo "  --help, -h            Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                     # Test slither, aderyn, solhint"
            echo "  $0 slither             # Test only slither"
            echo "  $0 --list-contracts    # List contracts for scanning"
            exit 0
            ;;
        *)
            SCANNERS_TO_TEST+=("$1")
            shift
            ;;
    esac
done

# Use default scanners if none specified
if [ ${#SCANNERS_TO_TEST[@]} -eq 0 ]; then
    SCANNERS_TO_TEST=("${DEFAULT_SCANNERS[@]}")
fi

echo -e "${CYAN}========================================"
echo "Apogee Scanner Test Suite"
echo -e "========================================${NC}"
echo ""

# Step 1: Get API Token
echo -e "${BLUE}Step 1: Getting API token...${NC}"
TOKEN=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\"}" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo -e "${RED}ERROR: Failed to get token${NC}"
    echo "Please verify test credentials or check Supabase connection"
    exit 1
fi
echo -e "${GREEN}✓ Token acquired${NC}"
echo ""

# Export token for reuse
export API_TOKEN="$TOKEN"

# Step 2: List contracts if requested
if [ "$LIST_CONTRACTS" = true ]; then
    echo -e "${BLUE}Available contracts:${NC}"
    api_get "${API_URL}/contracts" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.contracts[] | "\(.id) - \(.name) (\(.language))"'
    exit 0
fi

# Step 3: Get a test contract
echo -e "${BLUE}Step 2: Finding test contract...${NC}"
CONTRACT_RESPONSE=$(api_get "${API_URL}/contracts?limit=10" \
    -H "Authorization: Bearer ${TOKEN}")

# Find a Solidity contract for testing (response is wrapped in .contracts)
CONTRACT_ID=$(echo "$CONTRACT_RESPONSE" | jq -r '[.contracts[] | select(.language == "solidity")] | first | .id // empty')

if [ -z "$CONTRACT_ID" ]; then
    echo -e "${YELLOW}No Solidity contracts found. Creating test contract...${NC}"

    # Create a simple test contract
    CONTRACT_RESPONSE=$(api_post "${API_URL}/contracts" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "ScannerTestContract",
            "language": "solidity",
            "source_code": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\ncontract ScannerTest {\n    address public owner;\n    mapping(address => uint256) public balances;\n    \n    constructor() {\n        owner = msg.sender;\n    }\n    \n    // Potential reentrancy vulnerability for testing\n    function withdraw(uint256 amount) external {\n        require(balances[msg.sender] >= amount, \"Insufficient balance\");\n        (bool success, ) = msg.sender.call{value: amount}(\"\");\n        require(success, \"Transfer failed\");\n        balances[msg.sender] -= amount;\n    }\n    \n    function deposit() external payable {\n        balances[msg.sender] += msg.value;\n    }\n    \n    // Missing access control\n    function setOwner(address newOwner) external {\n        owner = newOwner;\n    }\n}"
        }')

    CONTRACT_ID=$(echo "$CONTRACT_RESPONSE" | jq -r '.id // empty')

    if [ -z "$CONTRACT_ID" ]; then
        echo -e "${RED}ERROR: Failed to create test contract${NC}"
        echo "$CONTRACT_RESPONSE" | jq .
        exit 1
    fi
    echo -e "${GREEN}✓ Created test contract: ${CONTRACT_ID}${NC}"
else
    CONTRACT_NAME=$(echo "$CONTRACT_RESPONSE" | jq -r "[.contracts[] | select(.id == \"$CONTRACT_ID\")] | first | .name")
    echo -e "${GREEN}✓ Using existing contract: ${CONTRACT_NAME} (${CONTRACT_ID})${NC}"
fi
echo ""

# Step 4: Test each scanner
echo -e "${BLUE}Step 3: Testing scanners...${NC}"
echo ""

RESULTS=()
PASSED=0
FAILED=0

for scanner in "${SCANNERS_TO_TEST[@]}"; do
    echo -e "${CYAN}----------------------------------------"
    echo -e "Testing: ${scanner}"
    echo -e "----------------------------------------${NC}"

    # Create scan
    SCAN_RESPONSE=$(api_post "${API_URL}/scans" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"contract_id\": \"${CONTRACT_ID}\",
            \"scanner_ids\": [\"${scanner}\"]
        }")

    SCAN_ID=$(echo "$SCAN_RESPONSE" | jq -r '.id // empty')

    if [ -z "$SCAN_ID" ]; then
        echo -e "${RED}✗ Failed to create scan${NC}"
        echo "$SCAN_RESPONSE" | jq .
        RESULTS+=("${scanner}:FAILED:Could not create scan")
        ((FAILED++)) || true
        continue
    fi

    echo -e "  Scan ID: ${SCAN_ID}"
    echo -e "  Waiting for completion..."

    # Poll for completion (max 5 minutes)
    MAX_WAIT=300
    INTERVAL=10
    ELAPSED=0

    while [ $ELAPSED -lt $MAX_WAIT ]; do
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))

        STATUS_RESPONSE=$(api_get "${API_URL}/scans/${SCAN_ID}" \
            -H "Authorization: Bearer ${TOKEN}")

        STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // "unknown"')

        if [ "$STATUS" == "completed" ]; then
            CRITICAL=$(echo "$STATUS_RESPONSE" | jq -r '.critical_count // 0')
            HIGH=$(echo "$STATUS_RESPONSE" | jq -r '.high_count // 0')
            MEDIUM=$(echo "$STATUS_RESPONSE" | jq -r '.medium_count // 0')
            LOW=$(echo "$STATUS_RESPONSE" | jq -r '.low_count // 0')
            VULN_COUNT=$((CRITICAL + HIGH + MEDIUM + LOW))
            echo -e "${GREEN}  ✓ Completed in ${ELAPSED}s${NC}"
            echo -e "    Vulnerabilities: ${CRITICAL} critical, ${HIGH} high, ${MEDIUM} medium, ${LOW} low (total: ${VULN_COUNT})"
            RESULTS+=("${scanner}:PASSED:${VULN_COUNT} vulns (${CRITICAL}C/${HIGH}H/${MEDIUM}M/${LOW}L)")
            ((PASSED++)) || true
            break
        elif [ "$STATUS" == "failed" ]; then
            ERROR=$(echo "$STATUS_RESPONSE" | jq -r '.error // "Unknown error"')
            echo -e "${RED}  ✗ Scan failed: ${ERROR}${NC}"
            RESULTS+=("${scanner}:FAILED:${ERROR}")
            ((FAILED++)) || true
            break
        else
            echo -e "    Status: ${STATUS} (${ELAPSED}s elapsed)"
        fi
    done

    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo -e "${RED}  ✗ Timeout waiting for scan completion${NC}"
        RESULTS+=("${scanner}:TIMEOUT:Exceeded ${MAX_WAIT}s")
        ((FAILED++)) || true
    fi

    echo ""
done

# Summary
echo -e "${CYAN}========================================"
echo "Test Summary"
echo -e "========================================${NC}"
echo ""

for result in "${RESULTS[@]}"; do
    scanner=$(echo "$result" | cut -d':' -f1)
    status=$(echo "$result" | cut -d':' -f2)
    details=$(echo "$result" | cut -d':' -f3-)

    if [ "$status" == "PASSED" ]; then
        echo -e "${GREEN}✓ ${scanner}: ${details}${NC}"
    else
        echo -e "${RED}✗ ${scanner}: ${status} - ${details}${NC}"
    fi
done

echo ""
echo -e "Passed: ${GREEN}${PASSED}${NC} / Failed: ${RED}${FAILED}${NC}"
echo ""

# Verify scanner versions in ConfigMap
echo -e "${BLUE}Verifying ConfigMap versions...${NC}"
echo ""
kubectl get configmap scanner-versions -n tool-integration-local \
    -o jsonpath='{.data.SCANNER_METADATA}' | jq -r '
    "  slither:  " + .slither.version,
    "  aderyn:   " + .aderyn.version,
    "  solhint:  " + .solhint.version'
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
