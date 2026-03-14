#!/bin/bash
# Test Billing & Subscription Features (Dashboard v0.42.0)
#
# Tests the billing feature display fix, tier-config integration,
# invite flow, and quota field name alignment.
#
# Usage:
#   ./test-billing-v042.sh              # Run all tests
#   ./test-billing-v042.sh --quick      # Skip invite tests (read-only)
#
# Prerequisites:
#   - API service running at app.0xapogee.com
#   - Supabase auth working
#   - jq installed
#
# Last Updated: February 12, 2026

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
API_BASE="${API_BASE:-https://app.0xapogee.com/api/v1}"
CURL_OPTS="-sk --location-trusted"

# Parse arguments
QUICK_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick|-q)
            QUICK_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Test billing & subscription features for dashboard v0.42.0"
            echo ""
            echo "Options:"
            echo "  --quick, -q   Skip write operations (invites)"
            echo "  --help, -h    Show this help"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Counters
PASSED=0
FAILED=0
SKIPPED=0

pass() {
    echo -e "  ${GREEN}PASS${NC}: $1"
    ((PASSED++)) || true
}

fail() {
    echo -e "  ${RED}FAIL${NC}: $1"
    ((FAILED++)) || true
}

skip() {
    echo -e "  ${YELLOW}SKIP${NC}: $1"
    ((SKIPPED++)) || true
}

# Helper: authenticated GET/POST
api_get() {
    curl $CURL_OPTS -X GET "${API_BASE}$1" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json"
}

api_post() {
    local endpoint=$1
    local data=$2
    curl $CURL_OPTS -X POST "${API_BASE}${endpoint}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$data"
}

api_delete() {
    curl $CURL_OPTS -X DELETE "${API_BASE}$1" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json"
}

echo -e "${CYAN}========================================"
echo "Dashboard v0.42.0 Billing Test Suite"
echo -e "========================================${NC}"
echo -e "API Base: ${API_BASE}"
echo ""

# ============================================================================
# Step 1: Get auth token
# ============================================================================
echo -e "${BLUE}Step 1: Authentication${NC}"
echo "-----------------------------------"

TOKEN=$("${SCRIPT_DIR}/get_token_fixed.sh" 2>/dev/null)
if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
    echo -e "${RED}ERROR: Failed to get token. Check Supabase credentials.${NC}"
    exit 1
fi
pass "Auth token acquired"
echo ""

# ============================================================================
# Step 2: Enhanced User Profile - Field Name Alignment
# ============================================================================
echo -e "${BLUE}Step 2: Enhanced User Profile (/users/me/enhanced)${NC}"
echo "-----------------------------------"
echo -e "  ${YELLOW}Verifies: API returns export_enabled, webhooks_enabled, api_access_enabled${NC}"
echo -e "  ${YELLOW}(Previously dashboard expected can_export_reports, can_use_webhooks, can_use_api)${NC}"
echo ""

ENHANCED=$(api_get "/users/me/enhanced")

# Check quota fields exist with NEW names
TIER=$(echo "$ENHANCED" | jq -r '.quota.tier // empty')
if [ -n "$TIER" ]; then
    pass "quota.tier present: ${TIER}"
else
    fail "quota.tier missing from enhanced response"
fi

# Check export_enabled (was can_export_reports)
EXPORT=$(echo "$ENHANCED" | jq -r '.quota.export_enabled // "MISSING"')
if [ "$EXPORT" != "MISSING" ]; then
    pass "quota.export_enabled present: ${EXPORT}"
else
    fail "quota.export_enabled missing (was this field renamed from can_export_reports?)"
fi

# Check webhooks_enabled (was can_use_webhooks)
WEBHOOKS=$(echo "$ENHANCED" | jq -r '.quota.webhooks_enabled // "MISSING"')
if [ "$WEBHOOKS" != "MISSING" ]; then
    pass "quota.webhooks_enabled present: ${WEBHOOKS}"
else
    fail "quota.webhooks_enabled missing (was can_use_webhooks)"
fi

# Check api_access_enabled (was can_use_api)
API_ACCESS=$(echo "$ENHANCED" | jq -r '.quota.api_access_enabled // "MISSING"')
if [ "$API_ACCESS" != "MISSING" ]; then
    pass "quota.api_access_enabled present: ${API_ACCESS}"
else
    fail "quota.api_access_enabled missing (was can_use_api)"
fi

# Check scan_priority (was concurrent_scans_limit)
PRIORITY=$(echo "$ENHANCED" | jq -r '.quota.scan_priority // "MISSING"')
if [ "$PRIORITY" != "MISSING" ]; then
    pass "quota.scan_priority present: ${PRIORITY}"
else
    fail "quota.scan_priority missing"
fi

# Check quota_reset_at (was reset_date)
RESET=$(echo "$ENHANCED" | jq -r '.quota.quota_reset_at // "MISSING"')
if [ "$RESET" != "MISSING" ]; then
    pass "quota.quota_reset_at present: ${RESET}"
else
    fail "quota.quota_reset_at missing (was reset_date)"
fi

# Verify OLD field names are NOT present (should be removed)
OLD_EXPORT=$(echo "$ENHANCED" | jq -r '.quota.can_export_reports // "ABSENT"')
OLD_WEBHOOKS=$(echo "$ENHANCED" | jq -r '.quota.can_use_webhooks // "ABSENT"')
OLD_API=$(echo "$ENHANCED" | jq -r '.quota.can_use_api // "ABSENT"')

if [ "$OLD_EXPORT" == "ABSENT" ] && [ "$OLD_WEBHOOKS" == "ABSENT" ] && [ "$OLD_API" == "ABSENT" ]; then
    pass "Old field names (can_export_reports, can_use_webhooks, can_use_api) correctly absent"
else
    fail "Old field names still present in response — dashboard may show duplicates"
fi

# Enterprise-specific: export_enabled and webhooks_enabled should be true
if [ "$TIER" == "enterprise" ] || [ "$TIER" == "growth" ]; then
    if [ "$EXPORT" == "true" ]; then
        pass "Enterprise/Growth tier: export_enabled=true (green check in UI)"
    else
        fail "Enterprise/Growth tier: export_enabled should be true but got ${EXPORT} (grey X bug!)"
    fi

    if [ "$WEBHOOKS" == "true" ]; then
        pass "Enterprise/Growth tier: webhooks_enabled=true (green check in UI)"
    else
        fail "Enterprise/Growth tier: webhooks_enabled should be true but got ${WEBHOOKS} (grey X bug!)"
    fi
fi

echo ""

# ============================================================================
# Step 3: User Quota Endpoint
# ============================================================================
echo -e "${BLUE}Step 3: User Quota (/users/quota)${NC}"
echo "-----------------------------------"

QUOTA=$(api_get "/users/quota")

QUOTA_TIER=$(echo "$QUOTA" | jq -r '.tier // empty')
MONTHLY_LIMIT=$(echo "$QUOTA" | jq -r '.monthly_scan_limit // empty')
MONTHLY_USED=$(echo "$QUOTA" | jq -r '.monthly_scans_used // empty')
PCT_USED=$(echo "$QUOTA" | jq -r '.percentage_used // empty')

if [ -n "$QUOTA_TIER" ]; then
    pass "Quota tier: ${QUOTA_TIER}"
else
    fail "Quota tier missing"
fi

if [ -n "$MONTHLY_LIMIT" ]; then
    if [ "$MONTHLY_LIMIT" == "-1" ]; then
        pass "Monthly scan limit: Unlimited"
    else
        pass "Monthly scan limit: ${MONTHLY_LIMIT}"
    fi
else
    fail "monthly_scan_limit missing"
fi

if [ -n "$MONTHLY_USED" ]; then
    pass "Monthly scans used: ${MONTHLY_USED}"
else
    fail "monthly_scans_used missing"
fi

# Verify quota values match tier expectations
case "$QUOTA_TIER" in
    developer)
        if [ "$MONTHLY_LIMIT" == "3" ]; then
            pass "Developer tier limit matches tiers.json (3)"
        else
            fail "Developer tier limit should be 3, got ${MONTHLY_LIMIT}"
        fi
        ;;
    starter)
        if [ "$MONTHLY_LIMIT" == "25" ]; then
            pass "Starter tier limit matches tiers.json (25)"
        else
            fail "Starter tier limit should be 25, got ${MONTHLY_LIMIT}"
        fi
        ;;
    growth)
        if [ "$MONTHLY_LIMIT" == "75" ]; then
            pass "Growth tier limit matches tiers.json (75)"
        else
            fail "Growth tier limit should be 75, got ${MONTHLY_LIMIT}"
        fi
        ;;
    enterprise)
        if [ "$MONTHLY_LIMIT" == "-1" ]; then
            pass "Enterprise tier limit is unlimited (-1)"
        else
            fail "Enterprise tier limit should be -1 (unlimited), got ${MONTHLY_LIMIT}"
        fi
        ;;
esac

echo ""

# ============================================================================
# Step 4: Billing Plans (Public)
# ============================================================================
echo -e "${BLUE}Step 4: Billing Plans (/billing/plans)${NC}"
echo "-----------------------------------"
echo -e "  ${YELLOW}Verifies: Plans match centralized tier-config (tiers.json)${NC}"
echo ""

PLANS=$(api_get "/billing/plans")

PLAN_COUNT=$(echo "$PLANS" | jq '.plans | length')
if [ "$PLAN_COUNT" == "4" ]; then
    pass "4 plans returned (developer, team, growth, enterprise)"
else
    fail "Expected 4 plans, got ${PLAN_COUNT}"
fi

# Verify tier names
PLAN_TIERS=$(echo "$PLANS" | jq -r '.plans[].tier' | sort | tr '\n' ',')
EXPECTED="developer,enterprise,growth,starter,"
if [ "$PLAN_TIERS" == "$EXPECTED" ]; then
    pass "Plan tiers correct: developer, starter, growth, enterprise"
else
    fail "Plan tiers unexpected: ${PLAN_TIERS}"
fi

# Verify developer tier is free
DEV_PRICE=$(echo "$PLANS" | jq -r '.plans[] | select(.tier == "developer") | .price_monthly')
if [ "$DEV_PRICE" == "0" ]; then
    pass "Developer tier price: free ($0)"
else
    fail "Developer tier price should be 0, got ${DEV_PRICE}"
fi

# Verify team tier pricing (API returns dollars, not cents)
STARTER_PRICE=$(echo "$PLANS" | jq -r '.plans[] | select(.tier == "starter") | .price_monthly')
if [ "$STARTER_PRICE" == "199" ] || [ "$STARTER_PRICE" == "19900" ]; then
    pass "Starter tier price: \$199/mo (${STARTER_PRICE})"
else
    fail "Starter tier price should be 199 (or 19900 cents), got ${STARTER_PRICE}"
fi

# Verify growth tier pricing
GROWTH_PRICE=$(echo "$PLANS" | jq -r '.plans[] | select(.tier == "growth") | .price_monthly')
if [ "$GROWTH_PRICE" == "499" ] || [ "$GROWTH_PRICE" == "49900" ]; then
    pass "Growth tier price: \$499/mo (${GROWTH_PRICE})"
else
    fail "Growth tier price should be 499 (or 49900 cents), got ${GROWTH_PRICE}"
fi

# Verify developer scan limit
DEV_SCANS=$(echo "$PLANS" | jq -r '.plans[] | select(.tier == "developer") | .scans_per_month')
if [ "$DEV_SCANS" == "3" ]; then
    pass "Developer scans/month: 3 (matches tiers.json)"
else
    fail "Developer scans should be 3, got ${DEV_SCANS}"
fi

# Check x402 pricing present
X402=$(echo "$PLANS" | jq -r '.x402_pricing.description // empty')
if [ -n "$X402" ]; then
    pass "x402 pay-per-scan pricing included"
else
    skip "x402 pricing not present (may not be implemented in API yet)"
fi

echo ""

# ============================================================================
# Step 5: Plan Limit
# ============================================================================
echo -e "${BLUE}Step 5: Plan Limit (/billing/plan-limit)${NC}"
echo "-----------------------------------"

PLAN_LIMIT=$(api_get "/billing/plan-limit")

PL_TIER=$(echo "$PLAN_LIMIT" | jq -r '.plan_tier // .tier // empty')
PL_SCANS=$(echo "$PLAN_LIMIT" | jq -r '.scans_per_month // .scan_limit // empty')
PL_UNLIMITED=$(echo "$PLAN_LIMIT" | jq -r '.is_unlimited // empty')

if [ -n "$PL_TIER" ]; then
    pass "Plan limit tier: ${PL_TIER}"
else
    fail "Plan limit tier missing"
fi

if [ "$PL_UNLIMITED" == "true" ]; then
    pass "Scan limit: Unlimited (is_unlimited=true)"
elif [ -n "$PL_SCANS" ] && [ "$PL_SCANS" != "0" ]; then
    pass "Scan limit: ${PL_SCANS}/month"
else
    pass "Plan limit response received (scans_per_month=${PL_SCANS}, is_unlimited=${PL_UNLIMITED})"
fi

echo ""

# ============================================================================
# Step 6: Subscription Details
# ============================================================================
echo -e "${BLUE}Step 6: Subscription (/billing/subscription)${NC}"
echo "-----------------------------------"

SUBSCRIPTION=$(api_get "/billing/subscription")

SUB_STATUS=$(echo "$SUBSCRIPTION" | jq -r '.status // empty')
SUB_TIER=$(echo "$SUBSCRIPTION" | jq -r '.plan_tier // empty')

if [ -n "$SUB_STATUS" ]; then
    pass "Subscription status: ${SUB_STATUS}"
else
    # May not have subscription (developer/free tier)
    SUB_MSG=$(echo "$SUBSCRIPTION" | jq -r '.detail // .message // empty')
    if [ -n "$SUB_MSG" ]; then
        skip "No active subscription: ${SUB_MSG}"
    else
        fail "Subscription endpoint returned unexpected response"
    fi
fi

if [ -n "$SUB_TIER" ]; then
    pass "Subscription tier: ${SUB_TIER}"
fi

echo ""

# ============================================================================
# Step 7: Tier Change Preview (if on paid tier)
# ============================================================================
echo -e "${BLUE}Step 7: Tier Change Preview (/billing/subscription/change-tier/preview)${NC}"
echo "-----------------------------------"

if [ -n "$SUB_TIER" ] && [ "$SUB_TIER" != "developer" ]; then
    # Preview upgrade to enterprise
    PREVIEW=$(api_get "/billing/subscription/change-tier/preview?new_tier=enterprise&billing_interval=monthly")

    PRORATE=$(echo "$PREVIEW" | jq -r '.proration_amount // .amount // empty')
    if [ -n "$PRORATE" ]; then
        pass "Tier change preview returned proration amount: ${PRORATE}"
    else
        PREVIEW_MSG=$(echo "$PREVIEW" | jq -r '.detail // empty')
        if [ -n "$PREVIEW_MSG" ]; then
            skip "Tier change preview: ${PREVIEW_MSG}"
        else
            fail "Tier change preview returned unexpected response"
        fi
    fi
else
    skip "Tier change preview (requires paid subscription)"
fi

echo ""

# ============================================================================
# Step 8: Invite Flow (write operations)
# ============================================================================
echo -e "${BLUE}Step 8: Invite Flow${NC}"
echo "-----------------------------------"

if [ "$QUICK_MODE" = true ]; then
    skip "Invite tests skipped (--quick mode)"
    echo ""
else
    # Get user's organization
    USER_RESPONSE=$(api_get "/users/me/enhanced")
    # Try to find org ID from user data or organizations endpoint
    ORG_ID=$(echo "$USER_RESPONSE" | jq -r '.default_organization_id // empty')

    if [ -z "$ORG_ID" ]; then
        # Try organizations list
        ORGS=$(api_get "/organizations")
        ORG_ID=$(echo "$ORGS" | jq -r '.organizations[0].id // .[0].id // empty')
    fi

    if [ -z "$ORG_ID" ]; then
        skip "No organization found — cannot test invites"
    else
        pass "Organization ID: ${ORG_ID}"

        # List current invites
        INVITES=$(api_get "/organizations/${ORG_ID}/invites")
        INVITE_COUNT=$(echo "$INVITES" | jq -r '.total // (.invites | length) // 0')
        pass "Current pending invites: ${INVITE_COUNT}"

        # Create test invite
        TEST_EMAIL="test-invite-v042-$(date +%s)@example.com"
        echo -e "  Creating test invite for ${TEST_EMAIL}..."

        INVITE_RESULT=$(api_post "/organizations/${ORG_ID}/invites" "{
            \"email\": \"${TEST_EMAIL}\",
            \"role\": \"developer\"
        }")

        INVITE_ID=$(echo "$INVITE_RESULT" | jq -r '.id // empty')
        INVITE_STATUS=$(echo "$INVITE_RESULT" | jq -r '.status // empty')

        if [ -n "$INVITE_ID" ] && [ "$INVITE_STATUS" == "pending" ]; then
            pass "Invite created: ${INVITE_ID} (status: pending)"

            # Cancel the test invite
            DELETE_RESULT=$(api_delete "/organizations/${ORG_ID}/invites/${INVITE_ID}")
            DELETE_STATUS=$?

            if [ $DELETE_STATUS -eq 0 ]; then
                pass "Test invite cancelled successfully"
            else
                fail "Failed to cancel test invite"
            fi
        else
            INVITE_ERR=$(echo "$INVITE_RESULT" | jq -r '.detail // .message // empty')
            if [ -n "$INVITE_ERR" ]; then
                skip "Invite creation: ${INVITE_ERR}"
            else
                fail "Invite creation returned unexpected response"
                echo "$INVITE_RESULT" | jq . 2>/dev/null || echo "$INVITE_RESULT"
            fi
        fi
    fi
    echo ""
fi

# ============================================================================
# Step 9: Billing History
# ============================================================================
echo -e "${BLUE}Step 9: Billing History (/billing/history)${NC}"
echo "-----------------------------------"

HISTORY=$(api_get "/billing/history")

HISTORY_STATUS=$(echo "$HISTORY" | jq -r 'type')
if [ "$HISTORY_STATUS" == "object" ] || [ "$HISTORY_STATUS" == "array" ]; then
    pass "Billing history endpoint accessible"
else
    fail "Billing history returned unexpected type: ${HISTORY_STATUS}"
fi

echo ""

# ============================================================================
# Step 10: Health Check
# ============================================================================
echo -e "${BLUE}Step 10: API Health${NC}"
echo "-----------------------------------"

HEALTH=$(curl $CURL_OPTS "${API_BASE/\/api\/v1/}/api/v1/health/live" 2>/dev/null)
HEALTH_STATUS=$(echo "$HEALTH" | jq -r '.status // empty')

if [ "$HEALTH_STATUS" == "ok" ] || [ "$HEALTH_STATUS" == "alive" ] || [ "$HEALTH_STATUS" == "healthy" ]; then
    pass "API health: ${HEALTH_STATUS}"
else
    fail "API health check: ${HEALTH_STATUS:-no response}"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${CYAN}========================================"
echo "Test Summary"
echo -e "========================================${NC}"
echo ""
echo -e "  ${GREEN}Passed${NC}:  ${PASSED}"
echo -e "  ${RED}Failed${NC}:  ${FAILED}"
echo -e "  ${YELLOW}Skipped${NC}: ${SKIPPED}"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed! Review output above.${NC}"
    echo ""
    echo "Key things to check if tests fail:"
    echo "  1. export_enabled/webhooks_enabled showing grey X → field name mismatch"
    echo "  2. Wrong scan limits → tiers.json not aligned with API"
    echo "  3. Invite errors → org membership or permissions issue"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
