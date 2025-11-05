# Scanner Status Determination - Edge Case Testing Guide

**Date**: 2025-11-05
**Related Fix**: tool-integration:0.2.4 + api-service:0.2.3
**Purpose**: Comprehensive testing guide for scanner status determination edge cases

## Overview

This guide provides step-by-step instructions for testing the scanner status determination fix, which distinguishes between false positive failures (Slither exit 255 with results) and true failures (network issues, no results posted).

## Prerequisites

- Kubernetes cluster running (minikube)
- All services deployed:
  - API Service: blocksecops-api-service:0.2.3
  - Tool Integration: tool-integration:0.2.4
  - PostgreSQL database
- Access to kubectl and psql commands
- Test contract with known vulnerabilities

## Test Environment Setup

### 1. Verify Deployed Versions

```bash
# Check API service version
kubectl get deployment api-service -n api-service-local -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: blocksecops-api-service:0.2.3

# Check tool-integration version
kubectl get deployment tool-integration -n tool-integration-local -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: tool-integration:0.2.4
```

### 2. Prepare Test Contract

Create a test contract with known vulnerabilities for Slither:

```solidity
// test-contract-vulnerable.sol
pragma solidity ^0.8.0;

contract VulnerableContract {
    address public owner;

    // Uninitialized state variable (Slither will flag this)
    uint256 public uninitializedValue;

    // Missing access control (Slither will flag this)
    function changeOwner(address newOwner) public {
        owner = newOwner;
    }

    // Reentrancy vulnerability (Slither will flag this)
    mapping(address => uint256) public balances;

    function withdraw() public {
        uint256 amount = balances[msg.sender];
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
        balances[msg.sender] = 0;
    }
}
```

### 3. Create Clean Test Contract

```solidity
// test-contract-clean.sol
pragma solidity ^0.8.0;

contract CleanContract {
    uint256 public value;

    constructor(uint256 initialValue) {
        value = initialValue;
    }

    function setValue(uint256 newValue) public {
        value = newValue;
    }
}
```

## Test Scenarios

---

## Test 1: Successful Scan with Findings (Slither Exit 255 - False Positive)

**Purpose**: Verify that scans with vulnerabilities are not marked as failed despite Slither exit 255

**Expected Result**: Scan status = "completed", vulnerabilities saved to database

### Steps:

1. **Upload vulnerable contract via API:**

```bash
# Get auth token first
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}' | jq -r '.access_token')

# Upload contract
CONTRACT_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "VulnerableContract",
    "source_code": "pragma solidity ^0.8.0; contract VulnerableContract { address public owner; uint256 public uninitializedValue; function changeOwner(address newOwner) public { owner = newOwner; } }",
    "language": "solidity",
    "compiler_version": "0.8.20"
  }' | jq -r '.id')

echo "Contract ID: $CONTRACT_ID"
```

2. **Trigger Slither scan:**

```bash
SCAN_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"$CONTRACT_ID\",
    \"scanner_ids\": [\"slither\"]
  }" | jq -r '.id')

echo "Scan ID: $SCAN_ID"
```

3. **Monitor Job execution:**

```bash
# Watch job status
kubectl get jobs -n tool-integration-local -w | grep $SCAN_ID

# Check job logs
JOB_NAME=$(kubectl get jobs -n tool-integration-local -o name | grep slither | grep $SCAN_ID | head -1)
kubectl logs -n tool-integration-local $JOB_NAME -f
```

4. **Verify result collector behavior:**

```bash
# Check result collector logs
kubectl logs -n tool-integration-local deployment/tool-integration --tail=50 | grep -A 5 "$SCAN_ID"

# Expected log output:
# ✅ "Job scan-slither-{id} marked as failed by Kubernetes"
# ✅ "Scan {id} has results in database despite Job failure"
# ✅ "Scanner successfully posted results before container exit"
# ✅ "Skipping failure status update"
```

5. **Verify database state:**

```bash
# Check scan status
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT id, status, scanners_used FROM scans WHERE id = '$SCAN_ID';"

# Expected: status = 'completed', scanners_used = {slither}

# Check vulnerabilities
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT COUNT(*), scanner_id FROM vulnerabilities WHERE scan_id = '$SCAN_ID' GROUP BY scanner_id;"

# Expected: Multiple vulnerabilities with scanner_id = 'slither'
```

**Success Criteria:**
- ✅ Job marked as "Failed" by Kubernetes
- ✅ Scan status in database = "completed"
- ✅ Vulnerabilities saved to database
- ✅ Result collector logs show "has results in database despite Job failure"
- ✅ No failure status sent to API

---

## Test 2: Successful Scan without Findings (Clean Contract)

**Purpose**: Verify clean contracts with no vulnerabilities work correctly

**Expected Result**: Scan status = "completed", no vulnerabilities

### Steps:

1. **Upload clean contract:**

```bash
CLEAN_CONTRACT_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "CleanContract",
    "source_code": "pragma solidity ^0.8.0; contract CleanContract { uint256 public value; constructor(uint256 initialValue) { value = initialValue; } function setValue(uint256 newValue) public { value = newValue; } }",
    "language": "solidity",
    "compiler_version": "0.8.20"
  }' | jq -r '.id')
```

2. **Trigger scan:**

```bash
CLEAN_SCAN_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"$CLEAN_CONTRACT_ID\",
    \"scanner_ids\": [\"slither\"]
  }" | jq -r '.id')
```

3. **Monitor and verify:**

```bash
# Wait for completion
sleep 60

# Check status
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT id, status, scanners_used FROM scans WHERE id = '$CLEAN_SCAN_ID';"

# Expected: status = 'completed'

# Verify no vulnerabilities
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = '$CLEAN_SCAN_ID';"

# Expected: count = 0
```

**Success Criteria:**
- ✅ Job completes successfully (exit 0)
- ✅ Scan status = "completed"
- ✅ No vulnerabilities in database

---

## Test 3: True Failure - Scanner Cannot POST Results (Network Simulation)

**Purpose**: Verify true failures are properly detected and reported

**Expected Result**: Scan status = "failed", no vulnerabilities saved

### Method A: Simulate API Downtime

1. **Scale down API service temporarily:**

```bash
# Scale down API service
kubectl scale deployment api-service -n api-service-local --replicas=0

# Verify API is down
curl http://127.0.0.1:8000/health
# Expected: Connection refused
```

2. **Trigger scan (will fail to POST results):**

```bash
# Trigger scan via tool-integration directly
curl -X POST http://tool-integration-service.tool-integration-local.svc.cluster.local:8005/scans/test-scan-id/trigger \
  -H "Content-Type: application/json" \
  -d '{
    "contract_source": "pragma solidity ^0.8.0; contract Test { uint x; }",
    "compiler_version": "0.8.20"
  }'
```

3. **Monitor scanner job:**

```bash
# Watch job logs
kubectl logs -n tool-integration-local job/scan-slither-test-scan-id -f

# Expected: "Failed to post results (HTTP error)"
# Expected: Job exits with code 1
```

4. **Restore API and check result collector:**

```bash
# Restore API service
kubectl scale deployment api-service -n api-service-local --replicas=1

# Wait for API to be ready
sleep 30

# Check result collector logs
kubectl logs -n tool-integration-local deployment/tool-integration --tail=50 | grep "test-scan-id"

# Expected log output:
# ⚠️  "Job scan-slither-test-scan-id marked as failed by Kubernetes"
# ⚠️  "Scan test-scan-id has no results in database"
# ⚠️  "This is a true failure - scanner did not post results"
# ⚠️  "Sending failure status to API"
```

5. **Verify failure status:**

```bash
# Check scan status
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT id, status FROM scans WHERE id = 'test-scan-id';"

# Expected: status = 'failed'

# Verify no vulnerabilities
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = 'test-scan-id';"

# Expected: count = 0
```

**Success Criteria:**
- ✅ Scanner job fails to POST results
- ✅ Kubernetes marks Job as failed
- ✅ Result collector detects no results in database
- ✅ Scan status = "failed"
- ✅ Appropriate error message in scan record

### Method B: Simulate with Modified Scanner Image

1. **Create test scanner image that fails to POST:**

```bash
# Create modified run-slither.sh that skips POST
cat > /tmp/run-slither-fail.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# ... (normal slither execution)

# Simulate POST failure
echo "Simulating POST failure - NOT posting results"
exit 1  # Exit with failure
EOF

# Build test image
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/slither
cp /tmp/run-slither-fail.sh run-slither-fail.sh

# Create test Dockerfile
cat > Dockerfile.test << 'EOF'
FROM python:3.11-slim
RUN pip install slither-analyzer==0.11.3 solc-select==1.0.4
RUN solc-select install 0.8.20 && solc-select use 0.8.20
WORKDIR /contracts
COPY run-slither-fail.sh /app/run-slither.sh
RUN chmod +x /app/run-slither.sh
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["/app/run-slither.sh"]
EOF

# Build test image
export DOCKER_TLS_VERIFY="1" DOCKER_HOST="tcp://127.0.0.1:55604" DOCKER_CERT_PATH="/Users/pwner/.minikube/certs" MINIKUBE_ACTIVE_DOCKERD="minikube"
docker build -t scanner-slither:test-fail -f Dockerfile.test .
```

2. **Temporarily update ConfigMap to use test image:**

```bash
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge \
  -p '{"data":{"SCANNER_IMAGE_SLITHER":"scanner-slither:test-fail"}}'

# Restart tool-integration to pick up change
kubectl rollout restart deployment/tool-integration -n tool-integration-local
kubectl rollout status deployment/tool-integration -n tool-integration-local
```

3. **Trigger scan and verify failure:**

```bash
TEST_FAIL_SCAN_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"$CONTRACT_ID\",
    \"scanner_ids\": [\"slither\"]
  }" | jq -r '.id')

# Wait for job to fail
sleep 90

# Verify it's marked as failed
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT id, status FROM scans WHERE id = '$TEST_FAIL_SCAN_ID';"

# Expected: status = 'failed'
```

4. **Restore original scanner image:**

```bash
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge \
  -p '{"data":{"SCANNER_IMAGE_SLITHER":"scanner-slither:0.2.2"}}'

kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

**Success Criteria:**
- ✅ Scanner fails to POST results
- ✅ Job marked as failed
- ✅ Result collector detects no results
- ✅ Scan status = "failed"

---

## Test 4: API Verification Endpoint Timeout/Error Handling

**Purpose**: Test result collector behavior when API is unreachable during verification

**Expected Result**: Safe default - marks scan as failed

### Steps:

1. **Create a scan that will fail (using test image from Test 3):**

```bash
# Use test-fail scanner image
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge \
  -p '{"data":{"SCANNER_IMAGE_SLITHER":"scanner-slither:test-fail"}}'

kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

2. **Scale down API service right before result collector polls:**

```bash
# Trigger scan
TIMEOUT_SCAN_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"$CONTRACT_ID\",
    \"scanner_ids\": [\"slither\"]
  }" | jq -r '.id')

# Wait for job to complete (fail)
sleep 45

# Scale down API BEFORE result collector polls (60s interval)
kubectl scale deployment api-service -n api-service-local --replicas=0

# Wait for result collector to poll
sleep 20

# Check logs
kubectl logs -n tool-integration-local deployment/tool-integration --tail=30 | grep "$TIMEOUT_SCAN_ID"

# Expected:
# ⚠️  "Timeout checking results for scan {id}. Assuming no results."
# OR
# ⚠️  "Failed to check results for scan {id}: HTTP {code}. Assuming no results."
```

3. **Restore API and verify safe default behavior:**

```bash
kubectl scale deployment api-service -n api-service-local --replicas=1
sleep 30

# Check scan was marked as failed (safe default)
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT id, status FROM scans WHERE id = '$TIMEOUT_SCAN_ID';"

# Expected: status = 'failed'
```

4. **Cleanup:**

```bash
# Restore normal scanner image
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge \
  -p '{"data":{"SCANNER_IMAGE_SLITHER":"scanner-slither:0.2.2"}}'

kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

**Success Criteria:**
- ✅ API verification times out or fails
- ✅ Result collector logs show timeout/error
- ✅ Uses safe default: assumes no results
- ✅ Scan marked as "failed"

---

## Test 5: Multiple Scanners - Mixed Success/Failure

**Purpose**: Verify behavior when running multiple scanners with different outcomes

**Expected Result**: Each scanner's status determined independently

### Steps:

1. **Trigger scan with multiple scanners:**

```bash
MULTI_SCAN_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"$CONTRACT_ID\",
    \"scanner_ids\": [\"slither\", \"wake\"]
  }" | jq -r '.id')
```

2. **Monitor both jobs:**

```bash
# Watch both jobs
kubectl get jobs -n tool-integration-local -w | grep $MULTI_SCAN_ID

# Check slither job
kubectl logs -n tool-integration-local job/scan-slither-$MULTI_SCAN_ID

# Check wake job
kubectl logs -n tool-integration-local job/scan-wake-$MULTI_SCAN_ID
```

3. **Verify both scanners' results:**

```bash
# Wait for both to complete
sleep 90

# Check scan status
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT id, status, scanners_used FROM scans WHERE id = '$MULTI_SCAN_ID';"

# Check vulnerabilities from both scanners
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "SELECT scanner_id, COUNT(*) FROM vulnerabilities WHERE scan_id = '$MULTI_SCAN_ID' GROUP BY scanner_id;"

# Expected: Both slither and wake vulnerabilities present
```

**Success Criteria:**
- ✅ Both scanner jobs execute
- ✅ Both post results independently
- ✅ Scan status reflects completion of all scanners
- ✅ Vulnerabilities from both scanners saved
- ✅ Each scanner's exit code handled independently

---

## Test 6: Race Condition - Scanner Posts Then Immediately Crashes

**Purpose**: Verify results are preserved even if scanner crashes after posting

**Expected Result**: Scan status = "completed", results saved

### Steps:

1. **Modify scanner to crash after posting:**

```bash
cat > /tmp/run-slither-crash.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# ... (normal execution and POST)

# POST results
curl -X POST "$CALLBACK_URL" -H "Content-Type: application/json" -d @"$OUTPUT_FILE"

# Simulate immediate crash
kill -9 $$
EOF

# Build and deploy test image (similar to Test 3)
```

2. **Trigger scan and verify:**

```bash
# Scan will have results posted but job marked as failed
# Result collector should detect results exist and NOT mark as failed
```

**Success Criteria:**
- ✅ Job marked as failed by Kubernetes (crashed)
- ✅ Results exist in database
- ✅ Result collector detects results
- ✅ Scan status = "completed"

---

## Automated Test Script

Create a comprehensive test script to run all scenarios:

```bash
#!/bin/bash
# scanner-status-edge-case-tests.sh

set -e

echo "========================================="
echo "Scanner Status Edge Case Testing Suite"
echo "========================================="
echo ""

# Get auth token
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}' | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "❌ Failed to get auth token"
    exit 1
fi

echo "✅ Authenticated successfully"
echo ""

# Test 1: Successful scan with findings
echo "Test 1: Successful scan with findings (Slither exit 255)"
echo "--------------------------------------------------------"

CONTRACT_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "VulnerableContract",
    "source_code": "pragma solidity ^0.8.0; contract VulnerableContract { address public owner; uint256 public uninitializedValue; function changeOwner(address newOwner) public { owner = newOwner; } }",
    "language": "solidity",
    "compiler_version": "0.8.20"
  }' | jq -r '.id')

SCAN_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"$CONTRACT_ID\",
    \"scanner_ids\": [\"slither\"]
  }" | jq -r '.id')

echo "Scan ID: $SCAN_ID"
echo "Waiting for scan to complete..."
sleep 90

STATUS=$(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -t -c \
  "SELECT status FROM scans WHERE id = '$SCAN_ID';" | xargs)

if [ "$STATUS" == "completed" ]; then
    echo "✅ Test 1 PASSED: Scan status = completed"
else
    echo "❌ Test 1 FAILED: Scan status = $STATUS (expected: completed)"
fi

echo ""

# Test 2: Clean contract (no findings)
echo "Test 2: Clean contract (no vulnerabilities)"
echo "--------------------------------------------"

CLEAN_CONTRACT_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "CleanContract",
    "source_code": "pragma solidity ^0.8.0; contract CleanContract { uint256 public value; constructor(uint256 initialValue) { value = initialValue; } }",
    "language": "solidity",
    "compiler_version": "0.8.20"
  }' | jq -r '.id')

CLEAN_SCAN_ID=$(curl -s -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"$CLEAN_CONTRACT_ID\",
    \"scanner_ids\": [\"slither\"]
  }" | jq -r '.id')

echo "Scan ID: $CLEAN_SCAN_ID"
echo "Waiting for scan to complete..."
sleep 90

CLEAN_STATUS=$(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -t -c \
  "SELECT status FROM scans WHERE id = '$CLEAN_SCAN_ID';" | xargs)

if [ "$CLEAN_STATUS" == "completed" ]; then
    echo "✅ Test 2 PASSED: Clean contract scan status = completed"
else
    echo "❌ Test 2 FAILED: Scan status = $CLEAN_STATUS (expected: completed)"
fi

echo ""
echo "========================================="
echo "Test Suite Complete"
echo "========================================="
```

## Monitoring and Verification

### Key Log Patterns

**False Positive (Slither exit 255 with results):**
```
INFO: Job scan-slither-{id} marked as failed by Kubernetes
INFO: Scan {id} has results in database despite Job failure
INFO: Scanner successfully posted results before container exit
INFO: Skipping failure status update
```

**True Failure (no results):**
```
WARNING: Job scan-slither-{id} marked as failed by Kubernetes
WARNING: Scan {id} has no results in database
WARNING: This is a true failure - scanner did not post results
WARNING: Sending failure status to API
```

### Database Queries

```sql
-- Check scan status distribution
SELECT status, COUNT(*)
FROM scans
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY status;

-- Check for scans with results but marked failed (should be 0)
SELECT s.id, s.status, COUNT(v.id) as vuln_count
FROM scans s
LEFT JOIN vulnerabilities v ON s.id = v.scan_id
WHERE s.status = 'failed'
  AND s.created_at > NOW() - INTERVAL '1 hour'
GROUP BY s.id, s.status
HAVING COUNT(v.id) > 0;

-- Check result collector verification calls
-- (Would need custom metrics/logging)
```

## Success Metrics

After running all tests, verify:

1. ✅ **False Positive Rate = 0%**: No scans with vulnerabilities marked as "failed"
2. ✅ **True Failure Detection = 100%**: All scans without results properly marked as "failed"
3. ✅ **API Verification Uptime**: Check verification endpoint response times < 100ms
4. ✅ **No Data Loss**: All posted vulnerabilities preserved in database
5. ✅ **Proper Logging**: All scenarios logged with appropriate severity

## Rollback Testing

Test rollback procedure:

```bash
# Rollback to previous versions
kubectl set image deployment/tool-integration tool-integration=tool-integration:0.2.3 -n tool-integration-local
kubectl set image deployment/api-service api-service=blocksecops-api-service:0.2.2 -n api-service-local

# Verify old behavior returns (scans marked as failed incorrectly)

# Roll forward again
kubectl set image deployment/tool-integration tool-integration=tool-integration:0.2.4 -n tool-integration-local
kubectl set image deployment/api-service api-service=blocksecops-api-service:0.2.3 -n api-service-local
```

## Cleanup

After testing:

```bash
# Remove test contracts and scans
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "DELETE FROM vulnerabilities WHERE scan_id IN (SELECT id FROM scans WHERE created_at > NOW() - INTERVAL '2 hours');"

kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d blocksecops -c \
  "DELETE FROM scans WHERE created_at > NOW() - INTERVAL '2 hours';"

# Remove test jobs
kubectl delete jobs -n tool-integration-local --all

# Verify services are healthy
kubectl get pods -n api-service-local
kubectl get pods -n tool-integration-local
```
