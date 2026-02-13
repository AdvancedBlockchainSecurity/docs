#!/bin/bash
# =============================================================================
# Comprehensive Scanner Audit Script
# =============================================================================
#
# Audits all 6 static analysis scanners by:
#   Phase 1: Running each Docker image directly against test contracts (baseline)
#   Phase 2: Running scans via the BlockSecOps platform API
#   Phase 3: Comparing results to identify pipeline failures
#
# Usage:
#   ./audit-scanners.sh                           # Full audit (all phases)
#   ./audit-scanners.sh --local-only              # Phase 1 only (Docker-based)
#   ./audit-scanners.sh --platform-only           # Phase 2+3 only (API-based)
#   ./audit-scanners.sh --scanner slither         # Test single scanner
#   ./audit-scanners.sh --contract Reentrancy.sol # Test single contract
#
# Output:
#   /tmp/scanner-audit/local/{scanner}/{contract}.json    - Local scan results
#   /tmp/scanner-audit/platform/{scanner}/{contract}.json - Platform scan results
#   /tmp/scanner-audit/report.md                          - Comparison report
#
# Prerequisites:
#   - Docker with access to scanner images (Harbor registry)
#   - jq, curl installed
#   - For Phase 2: Platform API accessible, valid credentials
#
# Reference:
#   docs/pipelines/scan-execution-pipeline.md  - How the platform runs scans
#   docs/pipelines/scanner-readiness-checklist.md - Scanner registration status
#
# Last Updated: February 12, 2026
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# =============================================================================
# COLORS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# =============================================================================
# CONFIGURATION
# =============================================================================
AUDIT_DIR="/tmp/scanner-audit"
CONTRACTS_DIR="/home/pwner/Git/vulnerable-smart-contract-examples/contracts/solidity"
REGISTRY="${REGISTRY:-harbor.blocksecops.local/blocksecops}"

# API Configuration
API_URL="${API_URL:-https://app.blocksecops.local/api/v1}"
SUPABASE_URL="https://huzjlpypdlelqnbjvxad.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1empscHlwZGxlbHFuYmp2eGFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4MTQ5MzYsImV4cCI6MjA3ODM5MDkzNn0.AabcSkKyi6HP3sLnTR7Bj-jZfgGgeSlEQZ0YRajC3i4"
TEST_EMAIL="jasonbrailowbizop@mail.com"
TEST_PASSWORD="TestPass123"

# Timeouts (seconds)
SCAN_TIMEOUT=180
PLATFORM_TIMEOUT=300
PLATFORM_POLL_INTERVAL=10

# Scanner image versions
declare -A SCANNER_IMAGES
SCANNER_IMAGES[slither]="scanner-slither:0.3.2"
SCANNER_IMAGES[aderyn]="scanner-aderyn:0.7.2"
SCANNER_IMAGES[semgrep]="scanner-semgrep:0.3.5"
SCANNER_IMAGES[solhint]="scanner-solhint:0.1.6"
SCANNER_IMAGES[wake]="scanner-wake:0.3.6"
SCANNER_IMAGES[soliditydefend]="scanner-soliditydefend:0.7.1"

ALL_SCANNERS=(slither aderyn semgrep solhint wake soliditydefend)

# Test contracts (from vulnerable-smart-contract-examples)
ALL_CONTRACTS=(
    Reentrancy.sol
    AccessControl.sol
    UncheckedCall.sol
    DenialOfService.sol
    TimestampDependence.sol
)

# =============================================================================
# ARGUMENT PARSING
# =============================================================================
LOCAL_ONLY=false
PLATFORM_ONLY=false
FILTER_SCANNERS=()
FILTER_CONTRACTS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --platform-only)
            PLATFORM_ONLY=true
            shift
            ;;
        --scanner)
            FILTER_SCANNERS+=("$2")
            shift 2
            ;;
        --contract)
            FILTER_CONTRACTS+=("$2")
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --timeout)
            SCAN_TIMEOUT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Comprehensive Scanner Audit"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --local-only          Skip Phase 2 (platform API scan)"
            echo "  --platform-only       Skip Phase 1 (local Docker scan)"
            echo "  --scanner NAME        Test single scanner (repeatable)"
            echo "  --contract FILE       Test single contract (repeatable)"
            echo "  --registry URL        Docker registry prefix (default: harbor.blocksecops.local/blocksecops)"
            echo "  --timeout SECS        Docker scan timeout (default: 180)"
            echo "  --help, -h            Show this help"
            echo ""
            echo "Scanners: ${ALL_SCANNERS[*]}"
            echo "Contracts: ${ALL_CONTRACTS[*]}"
            exit 0
            ;;
        *)
            echo "Unknown option: $1 (use --help for usage)"
            exit 1
            ;;
    esac
done

# Apply filters
if [ "${#FILTER_SCANNERS[@]}" -gt 0 ]; then
    SCANNERS=("${FILTER_SCANNERS[@]}")
else
    SCANNERS=("${ALL_SCANNERS[@]}")
fi

if [ "${#FILTER_CONTRACTS[@]}" -gt 0 ]; then
    CONTRACTS=("${FILTER_CONTRACTS[@]}")
else
    CONTRACTS=("${ALL_CONTRACTS[@]}")
fi

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[FAIL]${NC} $*"; }
log_header()  { echo -e "\n${CYAN}${BOLD}$*${NC}"; }
log_dim()     { echo -e "${DIM}$*${NC}"; }

timer_start() { date +%s; }
timer_elapsed() {
    local start=$1
    local now
    now=$(date +%s)
    echo $((now - start))
}

# Curl wrappers that follow redirects with auth
api_get() {
    curl -skL --location-trusted "$@"
}

api_post() {
    curl -skL --location-trusted -X POST "$@"
}

# =============================================================================
# JSON EXTRACTION
# =============================================================================
# Extracts valid JSON from scanner output that may contain banner text or
# trailing non-JSON content (e.g., soliditydefend's "Analysis complete:" text).
# Modifies the file in-place. Returns 0 if valid JSON was extracted.
extract_json_from_output() {
    local file=$1

    # Empty or missing file
    if [ ! -s "$file" ]; then
        echo '{}' > "$file"
        return 1
    fi

    # Already valid JSON
    if jq empty "$file" 2>/dev/null; then
        return 0
    fi

    # Use Python3 for robust extraction (handles banner prefix + trailing text)
    # Strategy: try both array and object extraction, keep the largest valid result
    python3 -c "
import json, sys

content = open(sys.argv[1]).read()
best = None
best_len = 0

for start_char, end_char in [('[', ']'), ('{', '}')]:
    # Try from each occurrence of start_char (not just the first)
    pos = 0
    while True:
        start = content.find(start_char, pos)
        if start == -1:
            break
        # Try the last matching end_char first, then work backward
        search_from = len(content)
        while True:
            end = content.rfind(end_char, start, search_from)
            if end == -1 or end <= start:
                break
            candidate = content[start:end+1]
            if len(candidate) <= best_len:
                break  # Can't beat current best from this start
            try:
                obj = json.loads(candidate)
                best = obj
                best_len = len(candidate)
                break  # Found valid JSON from this start, try next start
            except json.JSONDecodeError:
                search_from = end
        pos = start + 1

if best is not None:
    with open(sys.argv[1], 'w') as f:
        json.dump(best, f)
    sys.exit(0)
sys.exit(1)
" "$file" 2>/dev/null && return 0

    # Fallback: try line-based extraction (find first JSON line, validate)
    local line_num
    line_num=$(grep -n -m 1 -E '^\{|^\[' "$file" 2>/dev/null | cut -d: -f1) || true
    if [ -n "$line_num" ]; then
        local tmp
        tmp=$(mktemp)
        tail -n +"$line_num" "$file" > "$tmp"
        if jq empty "$tmp" 2>/dev/null; then
            mv "$tmp" "$file"
            return 0
        fi
        rm -f "$tmp"
    fi

    # Could not extract valid JSON
    echo '{}' > "$file"
    return 1
}

# =============================================================================
# FINDING COUNT EXTRACTION
# =============================================================================
# Extracts finding count from raw scanner JSON (Phase 1 local output)
count_local_findings() {
    local scanner=$1
    local json_file=$2

    if [ ! -s "$json_file" ]; then
        echo "0"
        return
    fi

    local count
    case $scanner in
        slither)
            # Slither: { "results": { "detectors": [...] } }
            count=$(jq -r '(.results.detectors // []) | length' "$json_file" 2>/dev/null) || count=0
            ;;
        aderyn)
            # Aderyn: { "issue_count": { "high": N, "low": N } }
            count=$(jq -r '((.issue_count.high // 0) + (.issue_count.low // 0))' "$json_file" 2>/dev/null) || count=0
            ;;
        semgrep)
            # Semgrep: { "results": [...] }
            count=$(jq -r '(.results // []) | length' "$json_file" 2>/dev/null) || count=0
            ;;
        solhint)
            # Solhint: flat array [...] or [ { "filePath": ..., "messages": [...] } ]
            # Filter out the conclusion object (has "conclusion" key, no "ruleId")
            count=$(jq -r '
                if type == "array" then
                    if (length > 0) and (.[0] | has("messages")) then
                        [.[].messages[]] | length
                    else
                        [.[] | select(has("ruleId") or has("line"))] | length
                    end
                else 0 end
            ' "$json_file" 2>/dev/null) || count=0
            ;;
        wake)
            # Wake: detections.json — array of detection objects, each with
            # detector_name, impact, confidence, etc.
            count=$(jq -r '
                if type == "array" then length
                elif type == "object" then
                    [to_entries[].value | if type == "array" then .[] else . end] | length
                else 0 end
            ' "$json_file" 2>/dev/null) || count=0
            ;;
        soliditydefend)
            # SolidityDefend: { "findings": [...] } or root array
            count=$(jq -r '
                if type == "array" then length
                elif has("findings") then (.findings // []) | length
                elif has("vulnerabilities") then (.vulnerabilities // []) | length
                else 0 end
            ' "$json_file" 2>/dev/null) || count=0
            ;;
        *)
            count=0
            ;;
    esac

    # Ensure numeric
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        count=0
    fi
    echo "$count"
}

# Extracts finding count from platform API scan response (Phase 2)
count_platform_findings() {
    local json_file=$1

    if [ ! -s "$json_file" ]; then
        echo "0"
        return
    fi

    local critical high medium low
    critical=$(jq -r '.critical_count // 0' "$json_file" 2>/dev/null) || critical=0
    high=$(jq -r '.high_count // 0' "$json_file" 2>/dev/null) || high=0
    medium=$(jq -r '.medium_count // 0' "$json_file" 2>/dev/null) || medium=0
    low=$(jq -r '.low_count // 0' "$json_file" 2>/dev/null) || low=0

    echo $((critical + high + medium + low))
}

# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================
preflight_checks() {
    log_header "Pre-flight Checks"
    local errors=0

    # Check required tools
    for tool in docker jq curl; do
        if command -v "$tool" &>/dev/null; then
            log_dim "  $tool: $(command -v "$tool")"
        else
            log_error "$tool is not installed"
            ((errors++)) || true
        fi
    done

    # Check contracts directory
    if [ -d "$CONTRACTS_DIR" ]; then
        local found=0
        for contract in "${CONTRACTS[@]}"; do
            if [ -f "$CONTRACTS_DIR/$contract" ]; then
                ((found++)) || true
            else
                log_error "Contract not found: $CONTRACTS_DIR/$contract"
                ((errors++)) || true
            fi
        done
        log_dim "  Contracts: $found/${#CONTRACTS[@]} found"
    else
        log_error "Contracts directory not found: $CONTRACTS_DIR"
        ((errors++)) || true
    fi

    # Check Docker images (Phase 1)
    if [ "$PLATFORM_ONLY" != true ]; then
        log_info "Checking Docker images..."
        for scanner in "${SCANNERS[@]}"; do
            local image="${REGISTRY}/${SCANNER_IMAGES[$scanner]}"
            if docker image inspect "$image" &>/dev/null; then
                log_dim "  $scanner: $image"
            else
                log_warn "$scanner image not found locally: $image"
                log_info "  Attempting docker pull..."
                if docker pull "$image" &>/dev/null; then
                    log_success "  Pulled $image"
                else
                    log_error "  Cannot pull $image — $scanner will be skipped in Phase 1"
                fi
            fi
        done
    fi

    # Check API health (Phase 2)
    if [ "$LOCAL_ONLY" != true ]; then
        log_info "Checking platform API..."
        local health
        health=$(api_get "$API_URL/health/ready" 2>/dev/null) || true
        if echo "$health" | jq -e '.ready == true' &>/dev/null; then
            log_dim "  API: healthy"
        else
            log_warn "Platform API not reachable at $API_URL — Phase 2 will be skipped"
            if [ "$PLATFORM_ONLY" = true ]; then
                log_error "Cannot run in --platform-only mode without API access"
                ((errors++)) || true
            fi
        fi
    fi

    # Create output directories
    mkdir -p "$AUDIT_DIR"/{local,platform}
    for scanner in "${SCANNERS[@]}"; do
        mkdir -p "$AUDIT_DIR/local/$scanner"
        mkdir -p "$AUDIT_DIR/platform/$scanner"
    done

    if [ "$errors" -gt 0 ]; then
        log_error "$errors pre-flight check(s) failed"
        exit 1
    fi
    log_success "Pre-flight checks passed"
}

# =============================================================================
# PHASE 1: LOCAL DOCKER SCAN FUNCTIONS
# =============================================================================

run_local_slither() {
    local contract=$1 output_file=$2 image=$3
    # solc-select fails with HTTP 403 (GitHub rate limiting), so we use Foundry's
    # forge to install solc into ~/.svm/ and then pass --solc to slither directly
    timeout "$SCAN_TIMEOUT" docker run --rm \
        -v "$CONTRACTS_DIR":/contracts:ro \
        --entrypoint /bin/sh \
        "$image" \
        -c "mkdir -p /tmp/project/src && \
            cp /contracts/${contract} /tmp/project/src/ && \
            cd /tmp/project && \
            git init -q 2>/dev/null && \
            forge init --no-commit --force . >/dev/null 2>/dev/null && \
            rm -f src/Counter.sol test/Counter.t.sol script/Counter.s.sol 2>/dev/null; \
            forge build >/dev/null 2>/dev/null; \
            SOLC_BIN=\$(find ~/.svm -name 'solc-*' -type f 2>/dev/null | head -1); \
            if [ -n \"\$SOLC_BIN\" ]; then \
                slither /contracts/${contract} --solc \"\$SOLC_BIN\" --json /tmp/r.json 2>/dev/null; \
            fi; \
            cat /tmp/r.json 2>/dev/null" \
        > "$output_file" 2>/dev/null || true
    extract_json_from_output "$output_file" || true
}

run_local_aderyn() {
    local contract=$1 output_file=$2 image=$3
    timeout "$SCAN_TIMEOUT" docker run --rm \
        -v "$CONTRACTS_DIR":/contracts:ro \
        --entrypoint /bin/sh \
        "$image" \
        -c "mkdir -p /tmp/project/src && \
            cp /contracts/${contract} /tmp/project/src/ && \
            cd /tmp/project && \
            git init -q 2>/dev/null && \
            forge init --no-commit --force . 2>/dev/null && \
            rm -f src/Counter.sol test/Counter.t.sol script/Counter.s.sol 2>/dev/null; \
            aderyn . -o /tmp/r.json 2>/dev/null; \
            cat /tmp/r.json 2>/dev/null" \
        > "$output_file" 2>/dev/null || true
    extract_json_from_output "$output_file" || true
}

run_local_semgrep() {
    local contract=$1 output_file=$2 image=$3
    timeout "$SCAN_TIMEOUT" docker run --rm \
        -v "$CONTRACTS_DIR":/contracts:ro \
        --entrypoint /bin/sh \
        "$image" \
        -c "semgrep --config=p/smart-contracts --json /contracts/${contract} 2>/dev/null || echo '{\"results\":[]}'" \
        > "$output_file" 2>/dev/null || true
    extract_json_from_output "$output_file" || true
}

run_local_solhint() {
    local contract=$1 output_file=$2 image=$3
    # solhint requires a .solhint.json config; the image doesn't bundle one at a
    # fixed path, so we create one with the recommended ruleset
    timeout "$SCAN_TIMEOUT" docker run --rm \
        -v "$CONTRACTS_DIR":/contracts:ro \
        --entrypoint /bin/sh \
        "$image" \
        -c "mkdir -p /tmp/work && \
            cp /contracts/${contract} /tmp/work/ && \
            cd /tmp/work && \
            echo '{\"extends\": \"solhint:recommended\"}' > .solhint.json && \
            solhint --formatter json '${contract}' 2>/dev/null; true" \
        > "$output_file" 2>/dev/null || true
    extract_json_from_output "$output_file" || true
}

run_local_wake() {
    local contract=$1 output_file=$2 image=$3
    # wake init/compile write log messages to stdout (not stderr), so we must
    # redirect both stdout and stderr to /dev/null for setup commands.
    # wake detect --export json writes JSON to .wake/detections.json
    timeout "$SCAN_TIMEOUT" docker run --rm \
        -v "$CONTRACTS_DIR":/contracts:ro \
        --entrypoint /bin/sh \
        "$image" \
        -c "mkdir -p /tmp/work && \
            cp /contracts/${contract} /tmp/work/ && \
            cd /tmp/work && \
            wake init --force >/dev/null 2>/dev/null && \
            wake compile >/dev/null 2>/dev/null; \
            wake detect --export json all >/dev/null 2>/dev/null; \
            cat .wake/detections.json 2>/dev/null || echo '[]'" \
        > "$output_file" 2>/dev/null || true
    extract_json_from_output "$output_file" || true
}

run_local_soliditydefend() {
    local contract=$1 output_file=$2 image=$3
    # SolidityDefend may prefix JSON output with a banner; extract_json handles it
    timeout "$SCAN_TIMEOUT" docker run --rm \
        -v "$CONTRACTS_DIR":/contracts:ro \
        --entrypoint /bin/sh \
        "$image" \
        -c "soliditydefend -f json /contracts/${contract} 2>/dev/null || true" \
        > "$output_file" 2>/dev/null || true
    extract_json_from_output "$output_file" || true
}

# Dispatch to scanner-specific function
run_local_scan() {
    local scanner=$1 contract=$2
    local output_dir="$AUDIT_DIR/local/$scanner"
    local output_file="$output_dir/${contract%.sol}.json"
    local image="${REGISTRY}/${SCANNER_IMAGES[$scanner]}"

    # Verify image is available
    if ! docker image inspect "$image" &>/dev/null; then
        log_error "$scanner: image not available ($image)"
        echo '{"error": "image_not_found"}' > "$output_file"
        return 1
    fi

    case $scanner in
        slither)         run_local_slither "$contract" "$output_file" "$image" ;;
        aderyn)          run_local_aderyn "$contract" "$output_file" "$image" ;;
        semgrep)         run_local_semgrep "$contract" "$output_file" "$image" ;;
        solhint)         run_local_solhint "$contract" "$output_file" "$image" ;;
        wake)            run_local_wake "$contract" "$output_file" "$image" ;;
        soliditydefend)  run_local_soliditydefend "$contract" "$output_file" "$image" ;;
        *)
            log_error "Unknown scanner: $scanner"
            return 1
            ;;
    esac
}

# =============================================================================
# PHASE 1: LOCAL DOCKER SCAN
# =============================================================================
phase1_local_docker_scan() {
    log_header "========================================="
    log_header "Phase 1: Local Docker Scan (baseline)"
    log_header "========================================="
    echo ""
    log_info "Running ${#SCANNERS[@]} scanners against ${#CONTRACTS[@]} contracts"
    log_info "Timeout per scan: ${SCAN_TIMEOUT}s"
    echo ""

    local total=$((${#SCANNERS[@]} * ${#CONTRACTS[@]}))
    local current=0
    local pass_count=0
    local fail_count=0
    local phase1_start
    phase1_start=$(timer_start)

    # Results array for summary
    declare -a LOCAL_RESULTS=()

    for scanner in "${SCANNERS[@]}"; do
        for contract in "${CONTRACTS[@]}"; do
            ((current++)) || true
            local contract_name="${contract%.sol}"
            printf "${DIM}[%2d/%d]${NC} %-16s x %-22s " "$current" "$total" "$scanner" "$contract"

            local scan_start
            scan_start=$(timer_start)

            if run_local_scan "$scanner" "$contract"; then
                local elapsed
                elapsed=$(timer_elapsed "$scan_start")
                local output_file="$AUDIT_DIR/local/$scanner/${contract_name}.json"
                local count
                count=$(count_local_findings "$scanner" "$output_file")

                if [ "$count" -gt 0 ]; then
                    echo -e "${GREEN}${count} findings${NC} (${elapsed}s)"
                    ((pass_count++)) || true
                else
                    echo -e "${YELLOW}0 findings${NC} (${elapsed}s)"
                fi
                LOCAL_RESULTS+=("${scanner}|${contract}|${count}|${elapsed}|ok")
            else
                local elapsed
                elapsed=$(timer_elapsed "$scan_start")
                echo -e "${RED}ERROR${NC} (${elapsed}s)"
                ((fail_count++)) || true
                LOCAL_RESULTS+=("${scanner}|${contract}|0|${elapsed}|error")
            fi
        done
    done

    local phase1_elapsed
    phase1_elapsed=$(timer_elapsed "$phase1_start")
    echo ""
    log_header "Phase 1 Summary"
    echo ""

    # Print results table
    printf "${BOLD}%-16s %-22s %8s %6s %8s${NC}\n" "Scanner" "Contract" "Findings" "Time" "Status"
    printf "%-16s %-22s %8s %6s %8s\n" "----------------" "----------------------" "--------" "------" "--------"

    for result in "${LOCAL_RESULTS[@]}"; do
        IFS='|' read -r r_scanner r_contract r_count r_time r_status <<< "$result"
        local r_name="${r_contract%.sol}"
        local status_color="$GREEN"
        local status_text="OK"
        if [ "$r_status" = "error" ]; then
            status_color="$RED"
            status_text="ERROR"
        elif [ "$r_count" = "0" ]; then
            status_color="$YELLOW"
            status_text="WARN"
        fi
        printf "%-16s %-22s %8s %5ss ${status_color}%8s${NC}\n" \
            "$r_scanner" "$r_name" "$r_count" "$r_time" "$status_text"
    done

    echo ""
    log_info "Phase 1 completed in ${phase1_elapsed}s"
    log_info "Scans with findings: $pass_count / $total"
    if [ "$fail_count" -gt 0 ]; then
        log_warn "Scan errors: $fail_count"
    fi

    # Store results for Phase 3
    printf '%s\n' "${LOCAL_RESULTS[@]}" > "$AUDIT_DIR/local/results.txt"
}

# =============================================================================
# PHASE 2: PLATFORM API SCAN
# =============================================================================

# Authenticate with Supabase and return JWT token
get_api_token() {
    local token
    token=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
        -H "apikey: ${SUPABASE_ANON_KEY}" \
        -H 'Content-Type: application/json' \
        -d "{\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\"}" | jq -r '.access_token')

    if [ "$token" = "null" ] || [ -z "$token" ]; then
        return 1
    fi
    echo "$token"
}

# Create a contract via the API, return contract ID
create_api_contract() {
    local token=$1 contract=$2
    local contract_name="AuditTest-${contract%.sol}-$(date +%Y%m%d-%H%M%S)"
    local source_json
    source_json=$(jq -Rs . < "$CONTRACTS_DIR/$contract")

    local response
    response=$(api_post "$API_URL/contracts" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$contract_name\",
            \"language\": \"solidity\",
            \"source_code\": $source_json
        }")

    local contract_id
    contract_id=$(echo "$response" | jq -r '.id // empty')
    if [ -z "$contract_id" ]; then
        log_error "Failed to create contract: $(echo "$response" | jq -r '.detail // .message // "unknown error"')"
        return 1
    fi
    echo "$contract_id"
}

# Trigger a scan and return scan ID
trigger_api_scan() {
    local token=$1 contract_id=$2 scanner=$3

    local response
    response=$(api_post "$API_URL/scans" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"contract_id\": \"$contract_id\",
            \"scanner_ids\": [\"$scanner\"]
        }")

    local scan_id
    scan_id=$(echo "$response" | jq -r '.id // empty')
    if [ -z "$scan_id" ]; then
        log_error "Failed to create scan: $(echo "$response" | jq -r '.detail // .message // "unknown error"')"
        return 1
    fi
    echo "$scan_id"
}

# Poll scan until completion, return status
poll_api_scan() {
    local token=$1 scan_id=$2 output_file=$3
    local elapsed=0

    while [ "$elapsed" -lt "$PLATFORM_TIMEOUT" ]; do
        sleep "$PLATFORM_POLL_INTERVAL"
        elapsed=$((elapsed + PLATFORM_POLL_INTERVAL))

        local response
        response=$(api_get "$API_URL/scans/$scan_id" \
            -H "Authorization: Bearer $token")

        local status
        status=$(echo "$response" | jq -r '.status // "unknown"')

        case $status in
            completed)
                echo "$response" > "$output_file"
                echo "completed"
                return 0
                ;;
            failed)
                echo "$response" > "$output_file"
                echo "failed"
                return 0
                ;;
            queued|pending|running|in_progress)
                # Still running, continue polling
                ;;
            *)
                # Unknown status, save and report
                echo "$response" > "$output_file"
                echo "$status"
                return 0
                ;;
        esac
    done

    echo "timeout"
    return 1
}

phase2_platform_api_scan() {
    log_header "========================================="
    log_header "Phase 2: Platform API Scan"
    log_header "========================================="
    echo ""

    # Authenticate
    log_info "Authenticating with Supabase..."
    local token
    token=$(get_api_token) || {
        log_error "Authentication failed — cannot run Phase 2"
        return 1
    }
    log_success "Token acquired"
    echo ""

    local total=$((${#SCANNERS[@]} * ${#CONTRACTS[@]}))
    local current=0
    local phase2_start
    phase2_start=$(timer_start)

    declare -a PLATFORM_RESULTS=()

    # Create contracts first (one per test contract, reused across scanners)
    declare -A CONTRACT_IDS=()
    log_info "Creating test contracts..."
    for contract in "${CONTRACTS[@]}"; do
        local contract_id
        contract_id=$(create_api_contract "$token" "$contract") || {
            log_error "Cannot create $contract — skipping"
            continue
        }
        CONTRACT_IDS[$contract]="$contract_id"
        log_dim "  $contract -> $contract_id"
    done
    echo ""

    log_info "Running ${#SCANNERS[@]} scanners against ${#CONTRACTS[@]} contracts via API"
    echo ""

    for scanner in "${SCANNERS[@]}"; do
        for contract in "${CONTRACTS[@]}"; do
            ((current++)) || true
            local contract_name="${contract%.sol}"
            printf "${DIM}[%2d/%d]${NC} %-16s x %-22s " "$current" "$total" "$scanner" "$contract"

            local scan_start
            scan_start=$(timer_start)

            # Check contract was created
            local contract_id="${CONTRACT_IDS[$contract]:-}"
            if [ -z "$contract_id" ]; then
                echo -e "${RED}SKIP (no contract)${NC}"
                PLATFORM_RESULTS+=("${scanner}|${contract}|0|0|skip")
                continue
            fi

            # Trigger scan
            local scan_id
            scan_id=$(trigger_api_scan "$token" "$contract_id" "$scanner") || {
                local elapsed
                elapsed=$(timer_elapsed "$scan_start")
                echo -e "${RED}FAIL (trigger)${NC} (${elapsed}s)"
                PLATFORM_RESULTS+=("${scanner}|${contract}|0|${elapsed}|trigger_error")
                continue
            }

            # Poll for completion
            local output_file="$AUDIT_DIR/platform/$scanner/${contract_name}.json"
            local scan_status
            scan_status=$(poll_api_scan "$token" "$scan_id" "$output_file") || scan_status="timeout"

            local elapsed
            elapsed=$(timer_elapsed "$scan_start")

            case $scan_status in
                completed)
                    local count
                    count=$(count_platform_findings "$output_file")
                    local plat_status
                    plat_status=$(jq -r '.status // "unknown"' "$output_file" 2>/dev/null)
                    if [ "$count" -gt 0 ]; then
                        echo -e "${GREEN}${count} findings${NC} (${elapsed}s)"
                    else
                        echo -e "${YELLOW}0 findings${NC} [status=$plat_status] (${elapsed}s)"
                    fi
                    PLATFORM_RESULTS+=("${scanner}|${contract}|${count}|${elapsed}|completed")
                    ;;
                failed)
                    local error_msg
                    error_msg=$(jq -r '.error // "unknown"' "$output_file" 2>/dev/null)
                    echo -e "${RED}FAILED: ${error_msg}${NC} (${elapsed}s)"
                    PLATFORM_RESULTS+=("${scanner}|${contract}|0|${elapsed}|failed")
                    ;;
                timeout)
                    echo -e "${RED}TIMEOUT${NC} (${elapsed}s)"
                    PLATFORM_RESULTS+=("${scanner}|${contract}|0|${elapsed}|timeout")
                    ;;
                *)
                    echo -e "${RED}${scan_status}${NC} (${elapsed}s)"
                    PLATFORM_RESULTS+=("${scanner}|${contract}|0|${elapsed}|${scan_status}")
                    ;;
            esac
        done
    done

    local phase2_elapsed
    phase2_elapsed=$(timer_elapsed "$phase2_start")
    echo ""
    log_info "Phase 2 completed in ${phase2_elapsed}s"

    # Store results for Phase 3
    printf '%s\n' "${PLATFORM_RESULTS[@]}" > "$AUDIT_DIR/platform/results.txt"
}

# =============================================================================
# PHASE 3: COMPARISON REPORT
# =============================================================================
phase3_comparison_report() {
    log_header "========================================="
    log_header "Phase 3: Comparison Report"
    log_header "========================================="
    echo ""

    local report_file="$AUDIT_DIR/report.md"
    local has_local=false
    local has_platform=false

    [ -f "$AUDIT_DIR/local/results.txt" ] && has_local=true
    [ -f "$AUDIT_DIR/platform/results.txt" ] && has_platform=true

    # Build lookup tables from results files
    declare -A LOCAL_COUNTS=()
    declare -A LOCAL_STATUS=()
    declare -A PLATFORM_COUNTS=()
    declare -A PLATFORM_STATUS=()

    if [ "$has_local" = true ]; then
        while IFS='|' read -r scanner contract count time status; do
            local key="${scanner}|${contract}"
            LOCAL_COUNTS[$key]="$count"
            LOCAL_STATUS[$key]="$status"
        done < "$AUDIT_DIR/local/results.txt"
    fi

    if [ "$has_platform" = true ]; then
        while IFS='|' read -r scanner contract count time status; do
            local key="${scanner}|${contract}"
            PLATFORM_COUNTS[$key]="$count"
            PLATFORM_STATUS[$key]="$status"
        done < "$AUDIT_DIR/platform/results.txt"
    fi

    # Determine comparison status for each pair
    declare -A COMPARISON=()
    local pass=0 fail=0 check=0 warn=0 error=0

    for scanner in "${SCANNERS[@]}"; do
        for contract in "${CONTRACTS[@]}"; do
            local key="${scanner}|${contract}"
            local local_count="${LOCAL_COUNTS[$key]:-N/A}"
            local plat_count="${PLATFORM_COUNTS[$key]:-N/A}"
            local local_stat="${LOCAL_STATUS[$key]:-N/A}"
            local plat_stat="${PLATFORM_STATUS[$key]:-N/A}"
            local verdict

            if [ "$local_stat" = "error" ] || [ "$local_stat" = "N/A" ]; then
                if [ "$plat_stat" = "N/A" ]; then
                    verdict="ERROR"
                    ((error++)) || true
                elif [ "$plat_count" != "N/A" ] && [ "$plat_count" -gt 0 ] 2>/dev/null; then
                    verdict="PASS"
                    ((pass++)) || true
                else
                    verdict="ERROR"
                    ((error++)) || true
                fi
            elif [ "$plat_stat" = "N/A" ]; then
                # Platform not run, only local results
                if [ "$local_count" -gt 0 ] 2>/dev/null; then
                    verdict="LOCAL_ONLY"
                else
                    verdict="WARN"
                    ((warn++)) || true
                fi
            elif [ "$local_count" -gt 0 ] 2>/dev/null && [ "$plat_count" = "0" ]; then
                # Local found findings but platform shows 0 — pipeline bug
                verdict="FAIL"
                ((fail++)) || true
            elif [ "$local_count" = "0" ] && [ "$plat_count" = "0" ]; then
                # Neither found anything
                verdict="WARN"
                ((warn++)) || true
            elif [ "$plat_count" -ge "$local_count" ] 2>/dev/null; then
                # Platform found same or more
                verdict="PASS"
                ((pass++)) || true
            elif [ "$plat_count" -gt 0 ] 2>/dev/null && [ "$plat_count" -lt "$local_count" ] 2>/dev/null; then
                # Platform found fewer
                verdict="CHECK"
                ((check++)) || true
            else
                verdict="PASS"
                ((pass++)) || true
            fi

            COMPARISON[$key]="$verdict"
        done
    done

    # Print ASCII comparison table
    if [ "$has_local" = true ] && [ "$has_platform" = true ]; then
        printf "\n${BOLD}%-16s %-22s %7s %7s  %-8s${NC}\n" "Scanner" "Contract" "Local" "Platform" "Verdict"
        printf "%-16s %-22s %7s %7s  %-8s\n" "----------------" "----------------------" "-------" "--------" "--------"

        for scanner in "${SCANNERS[@]}"; do
            for contract in "${CONTRACTS[@]}"; do
                local key="${scanner}|${contract}"
                local contract_name="${contract%.sol}"
                local lc="${LOCAL_COUNTS[$key]:-N/A}"
                local pc="${PLATFORM_COUNTS[$key]:-N/A}"
                local verdict="${COMPARISON[$key]}"

                local color
                case $verdict in
                    PASS)       color="$GREEN" ;;
                    FAIL)       color="$RED" ;;
                    CHECK)      color="$YELLOW" ;;
                    WARN)       color="$YELLOW" ;;
                    ERROR)      color="$RED" ;;
                    *)          color="$NC" ;;
                esac

                printf "%-16s %-22s %7s %8s  ${color}%-8s${NC}\n" \
                    "$scanner" "$contract_name" "$lc" "$pc" "$verdict"
            done
        done
    elif [ "$has_local" = true ]; then
        printf "\n${BOLD}%-16s %-22s %7s  %-8s${NC}\n" "Scanner" "Contract" "Local" "Status"
        printf "%-16s %-22s %7s  %-8s\n" "----------------" "----------------------" "-------" "--------"

        for scanner in "${SCANNERS[@]}"; do
            for contract in "${CONTRACTS[@]}"; do
                local key="${scanner}|${contract}"
                local contract_name="${contract%.sol}"
                local lc="${LOCAL_COUNTS[$key]:-0}"
                local ls="${LOCAL_STATUS[$key]:-error}"
                local color
                if [ "$ls" = "error" ]; then
                    color="$RED"
                elif [ "$lc" = "0" ]; then
                    color="$YELLOW"
                else
                    color="$GREEN"
                fi
                printf "%-16s %-22s ${color}%7s${NC}  %-8s\n" \
                    "$scanner" "$contract_name" "$lc" "$ls"
            done
        done
    fi

    # Summary
    echo ""
    if [ "$has_local" = true ] && [ "$has_platform" = true ]; then
        log_header "Verdict Summary"
        echo -e "  ${GREEN}PASS${NC}  : $pass  — Platform >= Local (working correctly)"
        echo -e "  ${RED}FAIL${NC}  : $fail  — Local found findings, platform shows 0 (pipeline bug!)"
        echo -e "  ${YELLOW}CHECK${NC} : $check — Platform found fewer than local (possible parsing issue)"
        echo -e "  ${YELLOW}WARN${NC}  : $warn  — Neither found anything (scanner may not detect this vuln type)"
        echo -e "  ${RED}ERROR${NC} : $error — Scan failed to run"
    fi

    # Generate Markdown report
    generate_markdown_report "$report_file" "$has_local" "$has_platform"
    echo ""
    log_success "Report saved to $report_file"
}

generate_markdown_report() {
    local report_file=$1
    local has_local=$2
    local has_platform=$3

    cat > "$report_file" <<'HEADER'
# Scanner Audit Report

HEADER
    echo "**Date:** $(date '+%Y-%m-%d %H:%M:%S')" >> "$report_file"
    echo "**Scanners:** ${SCANNERS[*]}" >> "$report_file"
    echo "**Contracts:** ${CONTRACTS[*]}" >> "$report_file"
    echo "" >> "$report_file"

    # Legend
    cat >> "$report_file" <<'LEGEND'
## Verdict Key

| Verdict | Meaning |
|---------|---------|
| **PASS** | Platform >= Local findings (working correctly) |
| **FAIL** | Local found findings but platform shows 0 (pipeline bug) |
| **CHECK** | Platform found fewer than local (possible parsing issue) |
| **WARN** | Neither found anything (scanner may not detect this vuln type) |
| **ERROR** | Scan failed to run |

LEGEND

    # Local results table
    if [ "$has_local" = true ]; then
        echo "## Phase 1: Local Docker Scan Results" >> "$report_file"
        echo "" >> "$report_file"
        echo "| Scanner | Contract | Findings | Status |" >> "$report_file"
        echo "|---------|----------|----------|--------|" >> "$report_file"

        while IFS='|' read -r scanner contract count time status; do
            local contract_name="${contract%.sol}"
            echo "| $scanner | $contract_name | $count | $status |" >> "$report_file"
        done < "$AUDIT_DIR/local/results.txt"
        echo "" >> "$report_file"
    fi

    # Platform results table
    if [ "$has_platform" = true ]; then
        echo "## Phase 2: Platform API Scan Results" >> "$report_file"
        echo "" >> "$report_file"
        echo "| Scanner | Contract | Findings | Status |" >> "$report_file"
        echo "|---------|----------|----------|--------|" >> "$report_file"

        while IFS='|' read -r scanner contract count time status; do
            local contract_name="${contract%.sol}"
            echo "| $scanner | $contract_name | $count | $status |" >> "$report_file"
        done < "$AUDIT_DIR/platform/results.txt"
        echo "" >> "$report_file"
    fi

    # Comparison table
    if [ "$has_local" = true ] && [ "$has_platform" = true ]; then
        echo "## Phase 3: Comparison" >> "$report_file"
        echo "" >> "$report_file"
        echo "| Scanner | Contract | Local | Platform | Verdict |" >> "$report_file"
        echo "|---------|----------|-------|----------|---------|" >> "$report_file"

        for scanner in "${SCANNERS[@]}"; do
            for contract in "${CONTRACTS[@]}"; do
                local key="${scanner}|${contract}"
                local contract_name="${contract%.sol}"
                local lc="${LOCAL_COUNTS[$key]:-N/A}"
                local pc="${PLATFORM_COUNTS[$key]:-N/A}"
                local verdict="${COMPARISON[$key]:-N/A}"
                local marker=""
                if [ "$verdict" = "FAIL" ]; then
                    marker=" :red_circle:"
                fi
                echo "| $scanner | $contract_name | $lc | $pc | **$verdict**$marker |" >> "$report_file"
            done
        done
        echo "" >> "$report_file"

        # Failures section
        local has_failures=false
        for scanner in "${SCANNERS[@]}"; do
            for contract in "${CONTRACTS[@]}"; do
                local key="${scanner}|${contract}"
                if [ "${COMPARISON[$key]:-}" = "FAIL" ]; then
                    has_failures=true
                    break 2
                fi
            done
        done

        if [ "$has_failures" = true ]; then
            echo "## Pipeline Failures (FAIL)" >> "$report_file"
            echo "" >> "$report_file"
            echo "These scanner/contract pairs found vulnerabilities locally but returned 0 on the platform." >> "$report_file"
            echo "This indicates a bug in the scan pipeline (orchestration, job creation, callback, or result ingestion)." >> "$report_file"
            echo "" >> "$report_file"

            for scanner in "${SCANNERS[@]}"; do
                for contract in "${CONTRACTS[@]}"; do
                    local key="${scanner}|${contract}"
                    if [ "${COMPARISON[$key]:-}" = "FAIL" ]; then
                        local contract_name="${contract%.sol}"
                        local lc="${LOCAL_COUNTS[$key]:-0}"
                        echo "### $scanner x $contract_name" >> "$report_file"
                        echo "" >> "$report_file"
                        echo "- **Local findings:** $lc" >> "$report_file"
                        echo "- **Platform findings:** 0" >> "$report_file"
                        echo "- **Local results:** \`$AUDIT_DIR/local/$scanner/${contract_name}.json\`" >> "$report_file"
                        echo "- **Platform results:** \`$AUDIT_DIR/platform/$scanner/${contract_name}.json\`" >> "$report_file"
                        echo "" >> "$report_file"
                        echo "**Investigation steps:**" >> "$report_file"
                        echo "1. Check scan status: \`jq '.status' $AUDIT_DIR/platform/$scanner/${contract_name}.json\`" >> "$report_file"
                        echo "2. Check scanner_results: \`jq '.scanner_results' $AUDIT_DIR/platform/$scanner/${contract_name}.json\`" >> "$report_file"
                        echo "3. Check orchestration logs: \`kubectl logs -n orchestration-local -l app.kubernetes.io/name=orchestration --tail=100\`" >> "$report_file"
                        echo "4. Check scanner K8s job: \`kubectl get jobs -n tool-integration-local -l scanner=$scanner\`" >> "$report_file"
                        echo "" >> "$report_file"
                    fi
                done
            done
        fi
    fi

    # Diagnostic tips
    cat >> "$report_file" <<'DIAGNOSTIC'
## Diagnostic Reference

### Pipeline Flow
```
POST /scans → API Service → Orchestration → K8s Job (scanner container) → Callback → Result Processing
```

### Common Failure Points
| Symptom | Likely Cause | Check |
|---------|-------------|-------|
| status: null, scanner_results: [] | Orchestration never ran | orchestration pod logs |
| status: completed, 0 findings | Parser failed to extract findings | orchestration parser logs |
| status: failed | Scanner container crashed | K8s Job logs, events |
| status: queued (stuck) | Job not created or callback failed | tool-integration logs |

### Files to Investigate
| Component | Where |
|-----------|-------|
| Orchestrator | `blocksecops-orchestration/src/blocksecops_orchestration/scanners/orchestrator.py` |
| Scanner executors | `blocksecops-orchestration/src/blocksecops_orchestration/scanners/solidity_scanners.py` |
| Result parsers | `blocksecops-orchestration/src/blocksecops_orchestration/parsers/solidity_parsers.py` |
| Scanner images | `blocksecops-tool-integration/scanner-images/*/` |
| K8s Job creation | `blocksecops-tool-integration/` |
DIAGNOSTIC
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo -e "${CYAN}${BOLD}"
    echo "========================================================"
    echo "  BlockSecOps Comprehensive Scanner Audit"
    echo "========================================================"
    echo -e "${NC}"
    echo "  Scanners:  ${SCANNERS[*]}"
    echo "  Contracts: ${CONTRACTS[*]}"
    echo "  Mode:      $([ "$LOCAL_ONLY" = true ] && echo "local-only" || ([ "$PLATFORM_ONLY" = true ] && echo "platform-only" || echo "full audit"))"
    echo "  Output:    $AUDIT_DIR/"
    echo ""

    preflight_checks

    # Phase 1: Local Docker Scan
    if [ "$PLATFORM_ONLY" != true ]; then
        phase1_local_docker_scan
    fi

    # Phase 2: Platform API Scan
    if [ "$LOCAL_ONLY" != true ]; then
        phase2_platform_api_scan || log_warn "Phase 2 had errors (see above)"
    fi

    # Phase 3: Comparison Report
    phase3_comparison_report

    echo ""
    log_header "Audit Complete"
    echo "  Results:   $AUDIT_DIR/"
    echo "  Report:    $AUDIT_DIR/report.md"
    echo ""

    # Exit with failure if any FAIL verdicts found
    if [ -f "$AUDIT_DIR/platform/results.txt" ] && [ -f "$AUDIT_DIR/local/results.txt" ]; then
        # Re-parse results to check for pipeline failures
        local failures=false
        declare -A EXIT_LOCAL=()
        declare -A EXIT_PLAT=()
        while IFS='|' read -r s c count rest; do
            EXIT_LOCAL["${s}|${c}"]="$count"
        done < "$AUDIT_DIR/local/results.txt"
        while IFS='|' read -r s c count rest; do
            EXIT_PLAT["${s}|${c}"]="$count"
        done < "$AUDIT_DIR/platform/results.txt"
        for key in "${!EXIT_LOCAL[@]}"; do
            local lc="${EXIT_LOCAL[$key]:-0}"
            local pc="${EXIT_PLAT[$key]:-0}"
            if [ "$lc" -gt 0 ] 2>/dev/null && [ "$pc" = "0" ]; then
                failures=true
                break
            fi
        done
        if [ "$failures" = true ]; then
            log_error "Pipeline failures detected — see report for details"
            exit 1
        fi
    fi
}

main "$@"
