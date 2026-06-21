# BYO AI Scanning (Phase 10, Migration 094/095) — feature tests

**Priority**: P1 — High
**Last tested**: 2026-06-21
**Endpoints**: `POST /api/v1/scans`, `GET /api/v1/scans/{id}`, `GET /api/v1/vulnerabilities`, `POST /api/v1/users/me/ai-consent`, `PATCH /api/v1/contracts/{id}/ai-sensitivity`, `PATCH /api/v1/organizations/{id}/ai-scanning`, `GET /api/v1/organizations/{id}/ai-quota`
**Scope**: AI-scanner dispatch, quota enforcement, failure-mode gating, dashboard rendering, gap-closure endpoints (v0.46.x)
**Cross-links:**
- Workflow: [`docs/workflows/ai-scan-trigger-workflow.md`](../workflows/ai-scan-trigger-workflow.md)
- Pipeline: [`docs/pipelines/ai-scanner-build-pipeline.md`](../pipelines/ai-scanner-build-pipeline.md)
- Kill-switch playbook: [`docs/playbooks/ai-cost-kill-switch.md`](../playbooks/ai-cost-kill-switch.md)
- Quota runbook: [`docs/playbooks/ai-quota-exhausted-runbook.md`](../playbooks/ai-quota-exhausted-runbook.md)
- Scanner reference: [`docs/scanners/ai-scanner.md`](../scanners/ai-scanner.md)
- DB migrations: migrations 094 and 095 (both additive)
- Smoke test: [`docs/standards/smoke-test.md`](../standards/smoke-test.md) — AI Scanner section

---

## What this feature does

Adds a managed-claude AI scanning path to the platform. Users with consent set and sufficient tier quota can submit a contract for AI analysis (`scanner_ids=["ai-anthropic"]`). The api-service dispatches asynchronously via fire-and-forget to `blocksecops-ai-scanner`, which calls Claude via the Apogee-managed key, validates the JSON output, and persists findings into the `vulnerabilities` table with `scanner_id = 'ai-anthropic'`. The dashboard renders AI findings with an **AIBadge** component (keyed on `scanner_id.startsWith('ai-')`) and confidence sub-pill.

Phase 1 ships managed-claude only. BYO providers (anthropic, openai, gemini) are wired but gated as Phase 2.

---

## Image versions that shipped together

| Component | Version | Notes |
|---|---|---|
| blocksecops-ai-scanner | **0.2.7** | Multi-file Hardhat/Foundry support (PR #6); orchestrator queries `contract_files` when `source_code` empty + `is_multi_file=true` |
| blocksecops-api-service | **0.46.2** | Scan request schema extended; fire-and-forget dispatch; permission gates; gap-closure endpoints (consent, sensitivity, org ai-scanning, quota); `cleanup_stuck_ai_scans` Celery beat task (BSO-SEC-040); scanner catalog ID renamed `ai` → `ai-anthropic`; search filter `scanner_ids` alias fixed |
| blocksecops-shared (tier-config) | **1.4.0** | `aiScan` block added; `AIScanConfig`, `AIScanTier`, `AIScanOverage` models |
| blocksecops-dashboard | **0.55.4** | Independent AI Scanning section above SAST (PR #228); batch scan refactor with dynamic scanner list and amber AI-skip notice (PR #230); implicit consent model replacing per-scan checkbox (PR #231) |

---

## Preconditions

All happy-path and most failure-path tests require the following to be true before each test:

| Precondition | How to verify | How to set |
|---|---|---|
| User has `ai_consent_at` set | `SELECT ai_consent_at FROM users WHERE email='jasonbrailowbizop@mail.com';` — must be non-null | Accept the AI consent prompt in the dashboard, or `UPDATE users SET ai_consent_at=NOW() WHERE email='jasonbrailowbizop@mail.com';` |
| Org has `ai_scanning_enabled=true` | `SELECT ai_scanning_enabled FROM organizations WHERE id='<org-id>';` | `UPDATE organizations SET ai_scanning_enabled=true WHERE id='<org-id>';` |
| Contract has `ai_processing_disabled=false` (default) | `SELECT ai_processing_disabled FROM contracts WHERE id='<contract-id>';` | Default false; set `true` to test `ai_contract_blocked` failure |
| Tier has `aiScan` budget remaining | `SELECT ai_input_tokens_used, ai_quota_reset_at FROM organizations WHERE id='<org-id>';` | Reset: `UPDATE organizations SET ai_input_tokens_used=0, ai_output_tokens_used=0 WHERE id='<org-id>';` |
| `AI_SCANNING_DISABLED` env var is `false` or unset in ai-scanner pod | `kubectl exec -n ai-scanner-prod deployment/ai-scanner -- printenv AI_SCANNING_DISABLED` | `kubectl set env deployment/ai-scanner -n ai-scanner-prod AI_SCANNING_DISABLED=false && kubectl rollout restart deployment/ai-scanner -n ai-scanner-prod` |

### Get a token (reused across all tests)

```bash
SUPABASE_URL="https://huzjlpypdlelqnbjvxad.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1empscHlwZGxlbHFuYmp2eGFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4MTQ5MzYsImV4cCI6MjA3ODM5MDkzNn0.AabcSkKyi6HP3sLnTR7Bj-jZfgGgeSlEQZ0YRajC3i4"
PLATFORM_URL="https://app.0xapogee.com"

TOKEN=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"jasonbrailowbizop@mail.com","password":"TestPass123"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
echo "TOKEN acquired: ${TOKEN:0:20}..."
```

### Reference contracts

Two contracts are used across the test matrix:

| Variable | Contract ID | Description |
|---|---|---|
| `CONTRACT_ID` | `3cd9e3ac-082d-450c-a888-bd85009c63e8` | Single-file Solidity contract; Phase 10 baseline (8 findings) |
| `MULTIFILE_CONTRACT_ID` | `0d0c1935` | Hardhat-echidna project with 3 `.sol` files including `EchidnaBuggy.sol`; used for multi-file happy path (test A4) |

```bash
CONTRACT_ID="3cd9e3ac-082d-450c-a888-bd85009c63e8"
MULTIFILE_CONTRACT_ID="0d0c1935"
```

---

## Test matrix

### A. Happy path (managed-claude, structured mode)

#### A1 — Dispatch and poll

**Setup:** All preconditions met. `CONTRACT_ID` set to a Solidity contract the test account owns.

```bash
# Dispatch AI scan
SCAN_RESP=$(curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"${CONTRACT_ID}\",
    \"scanner_ids\": [\"ai\"],
    \"ai_provider\": \"managed-claude\",
    \"ai_mode\": \"structured\",
    \"ai_sensitivity_acknowledged\": true
  }")
echo "$SCAN_RESP" | python3 -m json.tool

SCAN_ID=$(echo "$SCAN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scan_id',''))")
echo "SCAN_ID: $SCAN_ID"
```

**Pass criteria (immediate response):**
- HTTP 202
- `scan_id` present (non-empty UUID)
- `status` is `"queued"` or `"running"`

```bash
# Poll until completed (max ~2 minutes for managed-claude)
for i in $(seq 1 24); do
  STATUS=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "${PLATFORM_URL}/api/v1/scans/${SCAN_ID}" | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
  echo "[$i] status: $STATUS"
  [ "$STATUS" = "completed" ] && break
  [ "$STATUS" = "failed" ] && echo "FAIL: scan failed" && break
  sleep 5
done
```

**Pass criteria (after completion):**
- `status` reaches `"completed"`
- `scanner_ids` in the scan record contains `"ai-anthropic"` (the catalog ID as of v0.46.2)
- Finding count > 0 for the reference contract (8 findings observed in baseline e2e run)

#### A2 — Findings have correct scanner_id and metadata

```bash
FINDINGS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "${PLATFORM_URL}/api/v1/vulnerabilities?scan_id=${SCAN_ID}&limit=20")
echo "$FINDINGS" | python3 -c "
import sys,json
d=json.load(sys.stdin)
vulns=d.get('vulnerabilities', d) if isinstance(d,dict) else d
for v in vulns:
    sid=v.get('scanner_id','')
    conf=v.get('confidence','')
    assert sid == 'ai-anthropic' or sid.startswith('ai-anthropic-'), f'scanner_id must be ai-anthropic or ai-anthropic-* prefix: {sid}'
    assert conf in ('high','medium','low',''), f'unexpected confidence: {conf}'
    print(f'  OK: {sid} | severity={v.get(\"severity\")} | confidence={conf}')
print('PASS: all findings have ai- scanner_id')
"
```

**Pass criteria:**
- All findings have `scanner_id = 'ai-anthropic'` (or an `ai-anthropic-` prefixed variant)
- `confidence` is one of `high`, `medium`, `low`
- `severity` is one of `critical`, `high`, `medium`, `low`, `informational`

#### A3 — ai_scan_metadata populated

```bash
# Check DB directly for metadata
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "SELECT scan_id, model, mode, input_tokens, output_tokens, cost_usd_micros, prompt_version
   FROM ai_scan_metadata WHERE scan_id='${SCAN_ID}';"
```

**Pass criteria:**
- Row exists in `ai_scan_metadata` for `${SCAN_ID}`
- `model` is non-null (e.g. `claude-sonnet-4-6`)
- `input_tokens > 0` and `output_tokens > 0`
- `cost_usd_micros > 0`
- `prompt_version` is non-null

#### A4 — Multi-file Hardhat/Foundry project (ai-scanner v0.2.7)

**Purpose:** Verify the orchestrator correctly assembles context from `contract_files` when `contract.source_code` is empty and `is_multi_file=true`.

**Fixture:** Contract `0d0c1935` (hardhat-echidna project, 3 `.sol` files including `EchidnaBuggy.sol`). This is the contract that surfaced the multi-file gap via failed scan `369548e9-c019-45e7-931d-30ab71adefac` and was fixed in ai-scanner v0.2.7 (PR #6).

**Setup:** All standard preconditions met. Use `MULTIFILE_CONTRACT_ID` from the reference contracts table.

```bash
# Dispatch AI scan against multi-file contract
MFSCAN_RESP=$(curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"${MULTIFILE_CONTRACT_ID}\",
    \"scanner_ids\": [\"ai-anthropic\"],
    \"ai_provider\": \"managed-claude\",
    \"ai_mode\": \"structured\",
    \"ai_sensitivity_acknowledged\": true
  }")
echo "$MFSCAN_RESP" | python3 -m json.tool

MFSCAN_ID=$(echo "$MFSCAN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scan_id',''))")
echo "MFSCAN_ID: $MFSCAN_ID"

# Poll
for i in $(seq 1 24); do
  STATUS=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "${PLATFORM_URL}/api/v1/scans/${MFSCAN_ID}" | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
  echo "[$i] status: $STATUS"
  [ "$STATUS" = "completed" ] && break
  [ "$STATUS" = "failed" ] && echo "FAIL: scan failed" && break
  sleep 5
done
```

**Pass criteria:**
- HTTP 202 with `scan_id`
- Scan reaches `status = "completed"` (not `failed`)
- Finding count >= 1 (baseline: scan `daee7c9d-6388-4cf2-8d2e-c7bcc72ee1c5` returned 1 finding in ~10 seconds)
- Findings have `scanner_id = 'ai-anthropic'` and reference file paths from the project (e.g., `EchidnaBuggy.sol`)

**Regression guard:** If this scan fails with `ai_output_invalid` or returns 0 findings while status is `completed`, the `contract_files` assembly path may have regressed. Check ai-scanner logs for "source_code empty, querying contract_files" to confirm the multi-file path was taken.

**Live verification evidence:** Scan `daee7c9d-6388-4cf2-8d2e-c7bcc72ee1c5` confirmed live on 2026-06-21.

---

### B. Failure paths (one acceptance test per failure_type)

All failure-path tests expect the scan to reach `status=failed` with a specific `failure_type` in the response. After each test reset the changed precondition back to its normal value.

#### B1 — ai_org_disabled

**Setup:** Set `ai_scanning_enabled=false` for the org.

```bash
ORG_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "${PLATFORM_URL}/api/v1/organizations" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if isinstance(d,list) else d.get('id',''))")

kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "UPDATE organizations SET ai_scanning_enabled=false WHERE id='${ORG_ID}';"

curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\":\"${CONTRACT_ID}\",\"scanner_ids\":[\"ai-anthropic\"],\"ai_provider\":\"managed-claude\",\"ai_mode\":\"structured\",\"ai_sensitivity_acknowledged\":true}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); ft=d.get('detail',{}).get('failure_type') or d.get('failure_type'); print('PASS: ai_org_disabled' if ft=='ai_org_disabled' else f'FAIL: got {d}')"
```

**Pass criteria:** Response contains `failure_type: "ai_org_disabled"` (either in 4xx body or scan record).

**Teardown:**
```bash
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "UPDATE organizations SET ai_scanning_enabled=true WHERE id='${ORG_ID}';"
```

#### B2 — ai_contract_blocked

**Setup:** Mark the contract as sensitive.

```bash
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "UPDATE contracts SET ai_processing_disabled=true WHERE id='${CONTRACT_ID}';"

curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\":\"${CONTRACT_ID}\",\"scanner_ids\":[\"ai-anthropic\"],\"ai_provider\":\"managed-claude\",\"ai_mode\":\"structured\",\"ai_sensitivity_acknowledged\":true}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); ft=d.get('detail',{}).get('failure_type') or d.get('failure_type'); print('PASS: ai_contract_blocked' if ft=='ai_contract_blocked' else f'FAIL: got {d}')"
```

**Pass criteria:** Response contains `failure_type: "ai_contract_blocked"`.

**Teardown:**
```bash
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "UPDATE contracts SET ai_processing_disabled=false WHERE id='${CONTRACT_ID}';"
```

#### B3 — ai_quota_exceeded

**Setup:** Set `ai_input_tokens_used` to just below the org's monthly cap (check `tiers.json` for the current limit for the test account's tier), then dispatch a scan.

```bash
# Exhaust the monthly budget by setting usage to a very large number
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "UPDATE organizations SET ai_input_tokens_used=9999999999 WHERE id='${ORG_ID}';"

RESP=$(curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\":\"${CONTRACT_ID}\",\"scanner_ids\":[\"ai-anthropic\"],\"ai_provider\":\"managed-claude\",\"ai_mode\":\"structured\",\"ai_sensitivity_acknowledged\":true}")

echo "$RESP" | python3 -c "
import sys,json; d=json.load(sys.stdin)
ft=d.get('detail',{}).get('failure_type') or d.get('failure_type')
# quota is checked inside ai-scanner so we may get a queued scan that then fails
if ft=='ai_quota_exceeded':
    print('PASS: ai_quota_exceeded (pre-dispatch gate)')
else:
    sid=d.get('scan_id')
    print(f'Check scan {sid} for failure_type=ai_quota_exceeded after polling')
"
```

**Pass criteria:** Either the dispatch request is rejected immediately with `failure_type: "ai_quota_exceeded"`, or the resulting scan transitions to `failed` with that failure_type. Poll the scan record if needed.

**Teardown:**
```bash
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "UPDATE organizations SET ai_input_tokens_used=0, ai_output_tokens_used=0 WHERE id='${ORG_ID}';"
```

#### B4 — ai_token_cap_exceeded

**Setup:** This failure type occurs when the contract source exceeds the per-scan input token cap (`perScanInputTokenCap` in `tiers.json` for the test account's tier). Use an oversized contract or temporarily lower the cap via a direct DB override if the ai-scanner reads it from the DB rather than the wheel.

```bash
# If the cap is configurable per-org via DB, set it very low to force the failure:
# (check ai-scanner source for the cap field; if it reads from tiers.json baked in the image,
# use an oversized contract instead)
curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\":\"${CONTRACT_ID}\",\"scanner_ids\":[\"ai-anthropic\"],\"ai_provider\":\"managed-claude\",\"ai_mode\":\"structured\",\"ai_sensitivity_acknowledged\":true}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('scan_id','(no scan_id — gate fired pre-dispatch)'))"
```

**Pass criteria:** Scan reaches `failed` with `failure_type: "ai_token_cap_exceeded"`. The `ai_scan_metadata` row (if created) should show `input_tokens` at or near the cap value and `cost_usd_micros=0` (no charge if rejected before LLM call).

**Note:** If the per-scan cap cannot be triggered with available test contracts, document this as a deferred E2E gap and verify the cap-enforcement code path via unit test in `blocksecops-ai-scanner/tests/unit/test_quota.py` instead.

#### B5 — ai_safety_blocked

**Setup:** This failure type is triggered when the Anthropic API returns a safety refusal. It cannot be deterministically forced against the managed-claude path without a specially crafted contract. If a test fixture exists in `blocksecops-ai-scanner/tests/fixtures/safety-blocked/`, use it; otherwise treat this as a unit-test-covered path and skip the E2E trigger.

**Pass criteria (if E2E is possible):** Scan reaches `failed` with `failure_type: "ai_safety_blocked"`. No `vulnerabilities` rows inserted for this scan. `ai_scan_metadata` row records partial token usage if the call was made before refusal.

**Unit test fallback:** `blocksecops-ai-scanner/tests/unit/test_output_validator.py` — confirm a safety-refusal HTTP 400 from the Anthropic mock produces the correct failure_type.

#### B6 — ai_output_invalid

**Setup:** This failure type fires when the LLM returns JSON that fails schema validation. Trigger via unit test (inject a malformed response through the provider mock) or by deploying a test build of ai-scanner with a prompt that deliberately elicits malformed output.

**Pass criteria:** `failure_type: "ai_output_invalid"`. No `vulnerabilities` rows inserted for this scan. `ai_scan_metadata.output_tokens` may be non-zero (model did produce output — it just failed validation).

**Unit test reference:** `blocksecops-ai-scanner/tests/unit/test_output_validator.py` — invalid JSON, hallucinated line numbers out of source range, missing required fields.

#### B7 — ai_provider_error

**Setup:** Trigger a provider 5xx by temporarily setting `AI_SCANNING_DISABLED=true` on the ai-scanner pod (which causes `/health/ready` to return 503, and api-service maps a 503 from ai-scanner to `ai_provider_error`) OR use a test build that mocks a 500 from the Anthropic endpoint.

```bash
# Kill-switch approach: api-service fire-and-forget dispatch sees 503 and writes ai_provider_error
kubectl set env deployment/ai-scanner -n ai-scanner-prod AI_SCANNING_DISABLED=true
kubectl rollout restart deployment/ai-scanner -n ai-scanner-prod
kubectl rollout status deployment/ai-scanner -n ai-scanner-prod --timeout=60s

RESP=$(curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\":\"${CONTRACT_ID}\",\"scanner_ids\":[\"ai-anthropic\"],\"ai_provider\":\"managed-claude\",\"ai_mode\":\"structured\",\"ai_sensitivity_acknowledged\":true}")
echo "$RESP" | python3 -m json.tool

SCAN_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scan_id',''))")

# Poll for failure
for i in $(seq 1 12); do
  RESULT=$(curl -s -H "Authorization: Bearer $TOKEN" "${PLATFORM_URL}/api/v1/scans/${SCAN_ID}")
  STATUS=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
  FT=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('failure_type',''))")
  echo "[$i] status=$STATUS failure_type=$FT"
  [ "$STATUS" = "failed" ] && break
  sleep 5
done

echo "$FT" | grep -q "ai_provider_error" && echo "PASS: ai_provider_error" || echo "FAIL: expected ai_provider_error, got $FT"
```

**Pass criteria:** Scan reaches `failed` with `failure_type: "ai_provider_error"`.

**Teardown (mandatory):**
```bash
kubectl set env deployment/ai-scanner -n ai-scanner-prod AI_SCANNING_DISABLED=false
kubectl rollout restart deployment/ai-scanner -n ai-scanner-prod
kubectl rollout status deployment/ai-scanner -n ai-scanner-prod --timeout=60s
# Confirm ready
kubectl exec -n api-service-prod deployment/api-service -- \
  curl -s -o /dev/null -w "%{http_code}" -m 5 \
  "http://ai-scanner.ai-scanner-prod.svc.cluster.local:8000/health/ready"
# Expected: 200
```

#### B8 — ai_key_invalid (managed-claude only; BYO is Phase 2)

**Setup:** The Apogee-managed key is rotated at the infrastructure level. This failure type fires when the key in the ai-scanner pod's Vault-injected secret is revoked or expired. Test by temporarily overriding the key env var with a known-invalid value in a non-production environment only.

**Pass criteria:** Scan reaches `failed` with `failure_type: "ai_key_invalid"`. No cost incurred (Anthropic rejects at auth stage). Alert fires via the ai-key-invalid monitoring rule (check `docs/scanners/ai-scanner.md` for the alert reference).

**Note:** Do not test this against production — it requires replacing the live Anthropic key. This is a unit-test-covered path in `blocksecops-ai-scanner/tests/unit/test_provider_adapter.py`.

#### B9 — ai_system_error

Three sub-cases, all produce `failure_type: "ai_system_error"`:

**B9a — DB connection lost mid-scan:** Inject a transient DB failure via `kubectl exec postgresql-0 -- psql ... -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name='ai-scanner';"` during an in-flight scan. The ai-scanner's retry logic should attempt once and then write the failure record.

**B9b — ai-scanner pod crash mid-scan:** `kubectl delete pod -n ai-scanner-prod -l app.kubernetes.io/name=ai-scanner --grace-period=0` during an in-flight scan. The fire-and-forget design means api-service does not retry; the scan stays in `running` until the `cleanup_stuck_ai_scans` Celery beat task (BSO-SEC-040, ships in api-service v0.46.0) transitions it to `failed`.

**B9c — Fire-and-forget hung past 10 minutes (BSO-SEC-040):** The `cleanup_stuck_ai_scans` Celery beat task (5-minute interval) and companion `ai-scan-cleanup` CronJob in `api-service-prod` are deployed as of api-service v0.46.0. Both transition scans stuck in `running` for `> 10 minutes` to `failed` with `failure_type: "ai_system_error"`.

```bash
# Check for BSO-SEC-040 cleanup mechanism
kubectl get cronjob -n api-service-prod | grep -i stale
# OR check for a background task in api-service that handles this
kubectl exec -n api-service-prod deployment/api-service -- \
  grep -r "BSO-SEC-040\|ai_system_error\|stale.*running" /app/src/ 2>/dev/null | head -20
```

**Pass criteria for B9c:** A scan that has been in `running` for more than 10 minutes is automatically transitioned to `failed` with `failure_type: "ai_system_error"`. Verify by:

```bash
# Manually age a scan for testing (set created_at back in time)
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "UPDATE scans SET created_at=NOW()-INTERVAL '11 minutes', updated_at=NOW()-INTERVAL '11 minutes'
   WHERE id='${SCAN_ID}' AND status='running';"
# Then trigger the cleanup task or wait for the CronJob to run
```

---

### C. Security gate verification

#### C1 — BSO-SEC-031: ai_sensitivity_acknowledged=false must be rejected at the API layer

As of dashboard v0.55.4, the frontend always sends `ai_sensitivity_acknowledged: true` when AI is in `scanner_ids` (implicit consent model). The backend gate (BSO-SEC-031) remains active as defense in depth and must reject requests where `ai_sensitivity_acknowledged` is `false` or absent at the API level. This test exercises the API directly, bypassing the dashboard.

```bash
# Test: sensitivity_acknowledged explicitly false
RESP=$(curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"${CONTRACT_ID}\",
    \"scanner_ids\": [\"ai\"],
    \"ai_provider\": \"managed-claude\",
    \"ai_mode\": \"structured\",
    \"ai_sensitivity_acknowledged\": false
  }")
echo "$RESP" | python3 -c "
import sys,json; d=json.load(sys.stdin)
ft=d.get('detail',{}).get('failure_type') or d.get('failure_type') or str(d.get('detail',''))
print('PASS: gate fires' if ft=='ai_org_disabled' or 'sensitivity' in ft.lower() or 'consent' in ft.lower() else f'FAIL: expected gate rejection, got {d}')
"

# Test: ai_sensitivity_acknowledged field omitted entirely
RESP2=$(curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"contract_id\": \"${CONTRACT_ID}\",
    \"scanner_ids\": [\"ai\"],
    \"ai_provider\": \"managed-claude\",
    \"ai_mode\": \"structured\"
  }")
echo "$RESP2" | python3 -c "
import sys,json; d=json.load(sys.stdin)
code=d.get('status_code',200)
# Either 4xx HTTP or scan created but immediately failed with gate failure_type
print('Result:', d.get('failure_type') or d.get('detail') or 'check HTTP status')
"
```

**Pass criteria:** Both requests are rejected before dispatching to ai-scanner. The response includes either:
- HTTP 422 (validation error — `ai_sensitivity_acknowledged` required)
- HTTP 400 or 403 with `failure_type: "ai_org_disabled"` or similar sensitivity-gate failure_type

No scan record should be created, OR if a scan record is created it must immediately reach `failed` without dispatching to the ai-scanner pod.

#### C2 — Unauthenticated request rejected

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\":\"${CONTRACT_ID}\",\"scanner_ids\":[\"ai-anthropic\"],\"ai_sensitivity_acknowledged\":true}"
# Expected: 401
```

**Pass criteria:** HTTP 401, no scan created.

---

### D. Quota accounting

#### D1 — Token usage is recorded after scan

After a successful AI scan, verify that `organizations.ai_input_tokens_used` has increased.

```bash
# Capture before
BEFORE=$(kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -t -c \
  "SELECT ai_input_tokens_used FROM organizations WHERE id='${ORG_ID}';" | tr -d ' ')

# Run a scan (reuse steps from A1)
# ... (dispatch and poll as in A1)

# Capture after
AFTER=$(kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -t -c \
  "SELECT ai_input_tokens_used FROM organizations WHERE id='${ORG_ID}';" | tr -d ' ')

python3 -c "
before=$BEFORE; after=$AFTER
delta=after-before
print(f'Before: {before}')
print(f'After:  {after}')
print(f'Delta:  {delta}')
assert delta > 0, 'FAIL: ai_input_tokens_used did not increase'
print('PASS: token usage recorded')
"
```

#### D2 — Refund matches actual usage

The delta in `organizations.ai_input_tokens_used` must equal `ai_scan_metadata.input_tokens` for the scan.

```bash
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "SELECT
     am.scan_id,
     am.input_tokens AS metadata_input_tokens,
     am.output_tokens AS metadata_output_tokens,
     ($AFTER - $BEFORE) AS org_delta_input_tokens
   FROM ai_scan_metadata am
   WHERE am.scan_id='${SCAN_ID}';"
```

**Pass criteria:** `metadata_input_tokens` equals `org_delta_input_tokens`. Any mismatch indicates a reservation/commit accounting bug.

---

### E. Cost reconciliation

#### E1 — cost_usd_micros matches Sonnet 4.6 rates

Sonnet 4.6 pricing at Phase 10 ship: **$3.00 per 1M input tokens**, **$15.00 per 1M output tokens**.

```bash
kubectl exec postgresql-0 -n postgresql-prod -- psql -U blocksecops -d solidity_security -c \
  "SELECT
     scan_id,
     input_tokens,
     output_tokens,
     cost_usd_micros,
     ROUND((input_tokens::numeric / 1000000 * 3.00 + output_tokens::numeric / 1000000 * 15.00) * 1000000) AS expected_cost_usd_micros
   FROM ai_scan_metadata
   WHERE scan_id='${SCAN_ID}';"
```

**Pass criteria:** `cost_usd_micros` matches `expected_cost_usd_micros` within a 1% tolerance (rounding in integer arithmetic). A large discrepancy indicates a pricing constant mismatch in the ai-scanner service.

---

### F. Dashboard rendering

These tests are owner-driven browser checks against the production dashboard. Run after any dashboard or ai-scanner deploy.

| # | Contract | What to verify |
|---|---|---|
| F1 | `3cd9e3ac-082d-450c-a888-bd85009c63e8` (reference contract) | AI findings appear in the findings list. Each finding card or row shows the **AIBadge** pill (labeled "AI" or similar). |
| F2 | Same contract, AI findings with varying confidence | Confidence sub-pill renders correctly: green or solid for `high`, amber for `medium`, outline/muted for `low`. |
| F3 | Scanner picker for any contract | The **AI Scanning** section (indigo accent, "Apogee AI" badge) renders **above** the Static Analysis section. Selecting "AI (Claude Sonnet)" shows `AIScanOptions` with mode and provider dropdowns. BYO options are disabled with "Phase 2" label. No AI scanners appear inside the Static Analysis section. |
| F4 | Scanner picker — BYO providers | Clicking a disabled BYO option does not submit a scan. A tooltip or label explains Phase 2. |
| F5 | Contract list or contract detail | No AI-specific UI elements appear on non-AI scans (badge must not bleed into SAST-only results). |
| F6 | Scanner picker — consent disclosure | The per-scan consent checkbox is absent. A one-line italic disclosure reads "Note: starting an AI scan sends the contract source to the LLM sub-processor." The disclosure appears at the top of the `AIScanOptions` panel. |
| F7 | Batch scan modal | The AI Scanning section renders above SAST scanners. An amber notice reads "Batch scanning skips AI scanners in Phase 1 — they only run on single-contract scans." (`data-testid="batch-ai-skip-notice"` present). The scan count display and Start button count use SAST-only selection (`selectedNonAiCount`). |
| F8 | Batch scan modal — scanner list | Scanner list is loaded dynamically from `GET /api/v1/scanners` (`useQuery(['scanners'], listScanners)`) rather than a hardcoded list. |

**Browser-side smoke check:** Navigate to `https://app.0xapogee.com/contracts/3cd9e3ac-082d-450c-a888-bd85009c63e8/scans` → locate the AI scan run (scan `eccb1121-f424-48fa-9798-4bc64c048f80` from the Phase 10 baseline) → confirm 8 findings with AIBadge pills.

**Implicit consent live verification:** Scan `3622a074-9b56-4031-a314-a8f14ed648b4` was triggered via the v0.55.4 dashboard (no consent checkbox) and completed in ~30 seconds with 7 findings (2 high, 4 medium, 1 low), $0.047 cost. Confirmed `ai_scan_metadata.sensitivity_acknowledged = true`.

---

### G. Phase 1 limitations (regression guard)

These tests confirm that Phase 1 boundaries are enforced and have not inadvertently been opened.

#### G1 — BYO providers are non-functional (return ai_provider_error)

```bash
for PROVIDER in "anthropic" "openai" "gemini"; do
  RESP=$(curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"contract_id\":\"${CONTRACT_ID}\",\"scanner_ids\":[\"ai-anthropic\"],\"ai_provider\":\"${PROVIDER}\",\"ai_mode\":\"structured\",\"ai_sensitivity_acknowledged\":true}")
  FT=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('failure_type') or d.get('detail',{}).get('failure_type','?'))" 2>/dev/null || echo "check scan record")
  echo "Provider $PROVIDER: failure_type=$FT"
done
```

**Pass criteria:** Each BYO provider either returns `failure_type: "ai_provider_error"` immediately, or the resulting scan transitions to `failed` with that failure_type. No BYO provider should produce findings.

#### G2 — Vyper/Move contracts are skipped by AI scanner

**Pass criteria:** Submitting `scanner_ids=["ai-anthropic"]` against a non-Solidity contract (language=vyper or language=move in the contracts table) results in either:
- Dispatch rejected with a meaningful failure_type (e.g. `ai_unsupported_language`)
- OR scan completed with 0 findings and a note in `ai_scan_metadata` indicating the contract was skipped

Verify by uploading a Vyper file and running an AI-only scan.

#### G3 — Batch AI dispatch is silently skipped

```bash
# AI in a batch: the ai scanner_id must be ignored server-side
RESP=$(curl -s -X POST "${PLATFORM_URL}/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\":\"${CONTRACT_ID}\",\"scanner_ids\":[\"slither\",\"ai-anthropic\"],\"ai_provider\":\"managed-claude\",\"ai_mode\":\"structured\",\"ai_sensitivity_acknowledged\":true}")
echo "$RESP" | python3 -m json.tool
```

**Pass criteria:** Either the request is rejected (HTTP 400 with a clear message that AI cannot be batched with SAST), or the scan proceeds for `slither` only with a server-side warning logged and no AI dispatch. The response must not include a 500.

---

## How to reproduce the Phase 10 baseline e2e run

This reproduces the live verification run that confirmed Phase 10 was production-ready.

```bash
# Reference contract: 3cd9e3ac-082d-450c-a888-bd85009c63e8
# Reference scan: eccb1121-f424-48fa-9798-4bc64c048f80 (8 findings, 37s, ~$0.052)
# To re-run:

TOKEN=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${SUPABASE_KEY}" -H "Content-Type: application/json" \
  -d '{"email":"jasonbrailowbizop@mail.com","password":"TestPass123"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")

RESP=$(curl -s -X POST "https://app.0xapogee.com/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "contract_id": "3cd9e3ac-082d-450c-a888-bd85009c63e8",
    "scanner_ids": ["ai-anthropic"],
    "ai_provider": "managed-claude",
    "ai_mode": "structured",
    "ai_sensitivity_acknowledged": true
  }')
SCAN_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scan_id',''))")
echo "Scan dispatched: $SCAN_ID"

# Poll
for i in $(seq 1 24); do
  R=$(curl -s -H "Authorization: Bearer $TOKEN" "https://app.0xapogee.com/api/v1/scans/${SCAN_ID}")
  STATUS=$(echo "$R" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))")
  echo "[$i] $STATUS"
  [ "$STATUS" = "completed" ] && break
  [ "$STATUS" = "failed" ] && echo "FAIL" && break
  sleep 5
done

# Check finding count (expect 8 for the reference contract)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://app.0xapogee.com/api/v1/vulnerabilities?scan_id=${SCAN_ID}&limit=20" | \
  python3 -c "
import sys,json
d=json.load(sys.stdin)
vulns=d.get('vulnerabilities',d) if isinstance(d,dict) else d
print(f'Findings: {len(vulns)}')
for v in vulns:
    print(f'  {v.get(\"severity\")}/{v.get(\"confidence\")} — {v.get(\"title\",\"\")[:60]}')
"
```

**Expected:** 8 findings, all with `scanner_id` starting with `ai-`, mix of high/medium confidence.

---

## Owner test contracts on production

| Contract ID | Name | Purpose |
|---|---|---|
| `3cd9e3ac-082d-450c-a888-bd85009c63e8` | (Phase 10 reference contract) | Baseline: 8 AI findings in Phase 10 e2e verification (scan `eccb1121`) |
| `0d0c1935` | hardhat-echidna project | Multi-file test fixture: 3 `.sol` files including `EchidnaBuggy.sol`; used for A4 |

---

## Known limitations

- **BYO provider E2E not verified** — anthropic/openai/gemini adapters return `ai_provider_error` in Phase 1. Verification deferred to Phase 2.
- **Batch AI dispatch** — `scanner_ids=["ai-anthropic","slither"]` is not supported; the AI scanner_id is silently skipped. Dashboard displays an amber notice in the batch modal (ships in v0.55.3).
- **Org opt-in UI** — `organizations.ai_scanning_enabled` can now be toggled via `PATCH /api/v1/organizations/{id}/ai-scanning` (ships in v0.46.0); no dashboard settings-page toggle exists yet (Phase 2).
- **Quota meter widget** — monthly token-usage indicator on the dashboard deferred to Phase 2. The `GET /api/v1/organizations/{id}/ai-quota` endpoint (v0.46.0) is available for programmatic checks.
- **B4 (ai_token_cap_exceeded) E2E** — may require a contract larger than available test fixtures; verify via unit test if E2E is not feasible.
- **B5 (ai_safety_blocked) E2E** — cannot be deterministically triggered against managed-claude without a specially crafted fixture; verify via unit test.
- **BYO_KEK not mounted** — `BYO_KEK` removed from ai-scanner ExternalSecret for Phase 1; BYO key decryption is not functional until Phase 2.
