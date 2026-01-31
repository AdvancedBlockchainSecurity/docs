#!/bin/bash
# Test Intelligence API Endpoints
# Tests semantic search, CVE enrichment, and NVD integration

set -e

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
API_BASE="${API_BASE:-http://app.blocksecops.local/api/v1}"

# Get auth token
echo "Getting auth token..."
TOKEN=$("${SCRIPT_DIR}/get_token_fixed.sh")
if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo "ERROR: Failed to get token"
    exit 1
fi
echo "Token obtained successfully"
echo ""

# Helper function to make authenticated requests
# Uses --location-trusted to preserve auth headers through redirects
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3

    if [ -n "$data" ]; then
        curl -s --location-trusted -X "$method" "${API_BASE}${endpoint}" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -s --location-trusted -X "$method" "${API_BASE}${endpoint}" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json"
    fi
}

echo "============================================"
echo "Testing Intelligence Endpoints"
echo "API Base: $API_BASE"
echo "============================================"
echo ""

# Test 1: Intelligence Stats
echo "1. Testing GET /intelligence/stats"
echo "-----------------------------------"
RESULT=$(api_call GET "/intelligence/stats")
echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
echo ""

# Test 2: List Exploits
echo "2. Testing GET /intelligence/exploits"
echo "--------------------------------------"
RESULT=$(api_call GET "/intelligence/exploits?limit=5")
echo "$RESULT" | jq '.items | length' 2>/dev/null && echo "exploits returned" || echo "$RESULT"
echo ""

# Test 3: List CVEs
echo "3. Testing GET /intelligence/cves"
echo "----------------------------------"
RESULT=$(api_call GET "/intelligence/cves?limit=5")
echo "$RESULT" | jq '.items | length' 2>/dev/null && echo "CVEs returned" || echo "$RESULT"
echo ""

# Test 4: Semantic Search
echo "4. Testing POST /intelligence/search"
echo "-------------------------------------"
RESULT=$(api_call POST "/intelligence/search" '{"query": "reentrancy attack on lending protocol", "top_k": 5}')
echo "$RESULT" | jq '{exploits_count: (.exploits | length), cves_count: (.cves | length)}' 2>/dev/null || echo "$RESULT"
echo ""

# Test 5: CVE Enrichment with SWC ID
echo "5. Testing POST /intelligence/enrich (SWC-107)"
echo "-----------------------------------------------"
RESULT=$(api_call POST "/intelligence/enrich" '{"swc_id": "SWC-107", "include_related": true}')
echo "$RESULT" | jq '{swc_id, cves_count: (.cves | length), category}' 2>/dev/null || echo "$RESULT"
echo ""

# Test 6: CVE Enrichment with CWE ID
echo "6. Testing POST /intelligence/enrich (CWE-841)"
echo "-----------------------------------------------"
RESULT=$(api_call POST "/intelligence/enrich" '{"cwe_id": "CWE-841"}')
echo "$RESULT" | jq '{cwe_id, cves_count: (.cves | length), category}' 2>/dev/null || echo "$RESULT"
echo ""

# Test 7: SWC to CVE Mapping
echo "7. Testing GET /intelligence/swc-mapping"
echo "-----------------------------------------"
RESULT=$(api_call GET "/intelligence/swc-mapping")
echo "$RESULT" | jq '.mappings | length' 2>/dev/null && echo "SWC mappings with CVEs" || echo "$RESULT"
echo ""

# Test 8: Specific SWC Mapping
echo "8. Testing GET /intelligence/swc-mapping?swc_id=SWC-101"
echo "--------------------------------------------------------"
RESULT=$(api_call GET "/intelligence/swc-mapping?swc_id=SWC-101")
echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
echo ""

# Test 9: Fetch CVE from NVD (known CVE)
echo "9. Testing GET /intelligence/nvd/CVE-2018-10299"
echo "------------------------------------------------"
RESULT=$(api_call GET "/intelligence/nvd/CVE-2018-10299")
echo "$RESULT" | jq '{cve_id, severity, cvss_score}' 2>/dev/null || echo "$RESULT"
echo ""

# Test 10: Recent Smart Contract CVEs
echo "10. Testing GET /intelligence/nvd/recent/smart-contracts"
echo "---------------------------------------------------------"
RESULT=$(api_call GET "/intelligence/nvd/recent/smart-contracts?days=90&limit=5")
echo "$RESULT" | jq 'length' 2>/dev/null && echo "recent CVEs returned" || echo "$RESULT"
echo ""

# Test 11: Invalid CVE ID (should return 400)
echo "11. Testing GET /intelligence/nvd/INVALID-CVE (should fail)"
echo "------------------------------------------------------------"
RESULT=$(api_call GET "/intelligence/nvd/INVALID-CVE")
echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
echo ""

# Test 12: Invalid SWC ID (should return 400)
echo "12. Testing POST /intelligence/enrich with invalid SWC (should fail)"
echo "---------------------------------------------------------------------"
RESULT=$(api_call POST "/intelligence/enrich" '{"swc_id": "INVALID"}')
echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
echo ""

echo "============================================"
echo "Tests Complete"
echo "============================================"
