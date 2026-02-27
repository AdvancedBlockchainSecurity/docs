# BlockSecOps Go-Live Audit Testing Checklist

**Version:** 1.0.0
**Created:** February 16, 2026
**Status:** Pre-Launch
**Purpose:** Cross-cutting, integration-level, and production-readiness validation for GCP launch

---

## Overview

This checklist consolidates all audit testing that must pass before going live on GCP production. The platform consists of 8+ microservices, 18 scanners, 4 pricing tiers, and integrations with Stripe, Supabase, GitHub/GitLab, Slack/Discord/Teams, and IDE plugins.

Existing feature-test specs (63+ files in `/docs/feature-tests/`) cover individual features. This document focuses on **cross-cutting, integration-level, and production-readiness validation**.

### Status Legend

| Symbol | Meaning |
|--------|---------|
| [ ] | Not tested |
| [x] | Passed |
| [!] | Failed |
| [~] | Partial / needs follow-up |

### Verification Approach

| Section | Method | Notes |
|---------|--------|-------|
| 1. Tier System & Quotas | Automated + Manual | Unit/integration test suites |
| 2. Scanner Integration | Automated + Manual | Scanner validation test suite |
| 3. Deduplication Pipeline | Automated | 25+ dedup tests |
| 4. Integrations Hub | Manual | OAuth flows require browser |
| 5. Payment & Billing | Manual | Stripe test mode |
| 6. Authentication & Authorization | Automated + Manual | Security test suite |
| 7. Kubernetes & Infrastructure | Infrastructure | `kubectl` inspection, policy tests |
| 8. Database Integrity | Automated | Alembic migrations, SQL verification |
| 9. Application Security | Automated + Manual | OWASP test suite |
| 10. Monitoring & Observability | Manual | GCP Cloud Console |
| 11. Intelligence Engine & ML | Automated + Manual | ML test suite |
| 12. End-to-End Workflows | Manual | Full workflow walkthroughs |
| 13. Performance & Load | Load testing | k6/locust |
| 14. Smoke Test (Production) | Automated script | `scripts/audit/smoke-test-production.sh` |

---

## 1. Tier System & Quota Enforcement

**Key files:** `blocksecops-shared/tier-config/tiers.json`, `blocksecops-api-service/src/` (quota middleware), Migration 056/058
**Automation:** `scripts/audit/01-tier-quota-tests.sh`
**Related specs:** [02-quota-system.md](../feature-tests/02-quota-system.md), [10-tier-upgrades.md](../feature-tests/10-tier-upgrades.md)

### 1.1 Scan Quota Limits

| # | Test | Tier | Limit | Expected Result | Status |
|---|------|------|-------|-----------------|--------|
| 1.1 | Developer tier: attempt scan beyond monthly limit | Developer | 3/month | Blocked with quota error (402) | [ ] |
| 1.2 | Team tier: attempt scan beyond monthly limit | Team | 15/month | Blocked with quota error (402) | [ ] |
| 1.3 | Growth tier: attempt scan beyond monthly limit | Growth | 50/month | Blocked with quota error (402) | [ ] |
| 1.4 | Enterprise tier: unlimited scans | Enterprise | Unlimited | No quota block | [ ] |

```bash
# Verify quota limits from tiers.json
cat blocksecops-shared/tier-config/tiers.json | \
  jq '.tiers[] | {name: .name, scans_per_month: .quotas.contracts_per_month}'
```

### 1.2 Feature Gate Enforcement

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 1.5 | Developer/Team tier: attempt API key creation | Denied (Growth+ only) | [ ] |
| 1.6 | Developer/Team tier: attempt service account creation | Denied (Growth+ only) | [ ] |
| 1.7 | Developer tier: attempt IDE token generation | Denied (Team+ only) | [ ] |

```bash
# Test API key creation denied for Developer tier
TOKEN="<developer-tier-token>"
curl -sk -X POST "https://app.0xapogee.com/api/v1/api-keys" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-key","scopes":["scans:read"]}'
# Expected: 403 with tier gate message
```

### 1.3 Tier Change Enforcement

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 1.8 | Tier downgrade mid-cycle: session invalidated, quotas updated | Immediate enforcement | [ ] |
| 1.9 | Tier upgrade mid-cycle: new features accessible immediately | No stale cache | [ ] |

```bash
# After tier change via Stripe webhook, verify:
# 1. Old session token returns 401
curl -sk "https://app.0xapogee.com/api/v1/users/me" \
  -H "Authorization: Bearer $OLD_TOKEN"
# Expected: 401

# 2. New login reflects updated tier
# Login and check tier in /users/me response
```

### 1.4 Database Constraints

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 1.10 | DB ENUM constraint: attempt invalid tier value via raw SQL | Rejected by DB | [ ] |
| 1.11 | Audit log immutability: attempt UPDATE/DELETE on audit_logs | Trigger blocks modification | [ ] |

```bash
# Test ENUM constraint (from psql)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "UPDATE users SET tier = 'invalid_tier' WHERE id = 'test-id';"
# Expected: ERROR: invalid input value for enum

# Test audit log immutability
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "DELETE FROM audit_logs WHERE id = (SELECT id FROM audit_logs LIMIT 1);"
# Expected: ERROR from trigger blocking modification
```

### 1.5 Quota Operations

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 1.12 | Monthly quota reset: verify cron resets `user_quotas` correctly | Counters reset to 0 | [ ] |
| 1.13 | Rate limiting per tier: Growth 300/min, 10k/hour enforced | 429 after threshold | [ ] |
| 1.14 | Concurrent scan limits per tier (1/2/5/custom) | Excess scans queued | [ ] |

```bash
# Verify rate limits from tiers.json
cat blocksecops-shared/tier-config/tiers.json | \
  jq '.tiers[] | {name: .name, rate_limits: .rate_limits}'

# Test rate limiting (requires rapid requests)
for i in $(seq 1 310); do
  curl -sk -o /dev/null -w "%{http_code}\n" \
    "https://app.0xapogee.com/api/v1/scans" \
    -H "Authorization: Bearer $GROWTH_TOKEN" &
done
wait
# Expected: 429 responses after 300 requests/minute
```

---

## 2. Scanner Integration & Execution

**Key files:** `blocksecops-tool-integration/scanner-images/`, `docs/feature-tests/22-scanner-validation.md`
**Related specs:** [22-scanner-validation.md](../feature-tests/22-scanner-validation.md), [13-vyper-rust-scanners.md](../feature-tests/13-vyper-rust-scanners.md)

### 2.1 Scanner Output Validation

| # | Test | Scanners | Expected Result | Status |
|---|------|----------|-----------------|--------|
| 2.1 | Each of 18 scanners: submit known-vulnerable contract | All 18 | Returns expected findings | [ ] |
| 2.2 | Solidity scanners: parseable output | Slither, Mythril, Semgrep, SolidityDefend, Solhint, Aderyn | All produce parseable output | [ ] |
| 2.3 | Vyper scanners: language detection and parsing | Vyper compiler, Slither-Vyper, Moccasin | Language correctly detected, results parsed | [ ] |
| 2.4 | Rust/Solana scanners: normalized output | Cargo audit, cargo-expand, Sol-azy, Sec3-Xray | Results normalized to common schema | [ ] |

```bash
# List available scanner images
ls blocksecops-tool-integration/scanner-images/

# Verify scanner metadata
curl -sk "https://app.0xapogee.com/api/v1/scanners" \
  -H "Authorization: Bearer $TOKEN" | jq '.[].name'
```

### 2.2 Scanner Execution Lifecycle

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 2.5 | Fuzzers (Echidna, Medusa, Halmos) require `requires_project: true` | Single-file upload blocked with clear error | [ ] |
| 2.6 | Scanner pod lifecycle: job created, runs, completes, cleaned up | No orphan pods after scan | [ ] |
| 2.7 | Scanner timeout: long-running scan hits timeout | Graceful timeout, auto-retry (per spec 58) | [ ] |
| 2.8 | Scanner failure: scanner crashes mid-execution | Error captured, other scanners unaffected | [ ] |
| 2.9 | ConfigMap source delivery: large contract (>1MB) | Delivered to scanner pod correctly | [ ] |

```bash
# Check for orphan scanner pods
kubectl get pods -A -l app=scanner-job --field-selector=status.phase!=Running
# Expected: No pods stuck in non-terminal states

# Verify scanner timeout configuration
kubectl get configmap scanner-metadata -n tool-integration-local -o json | \
  jq '.data | to_entries[] | {key: .key, timeout: (.value | fromjson | .timeout)}'
```

### 2.3 Scanner Configuration

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 2.10 | Scanner image versions: all images use immutable semantic version tags | No `:latest` tags in production | [ ] |
| 2.11 | Scanner selection: user selects subset of scanners | Only selected scanners execute | [ ] |
| 2.12 | 4naly3er (deprecated Dec 2025): not available in scanner list | Excluded from UI and API | [ ] |

```bash
# Verify no :latest tags in scanner images
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | \
  grep -i scanner | grep -c ":latest"
# Expected: 0

# Verify 4naly3er is excluded
curl -sk "https://app.0xapogee.com/api/v1/scanners" \
  -H "Authorization: Bearer $TOKEN" | jq '.[].name' | grep -i "4naly3er"
# Expected: no output
```

---

## 3. Deduplication Pipeline

**Key files:** `blocksecops-api-service/src/infrastructure/deduplication_maintenance.py`, `docs/feature-tests/24-cross-scanner-deduplication.md`
**Related specs:** [24-cross-scanner-deduplication.md](../feature-tests/24-cross-scanner-deduplication.md), [63-dedup-multilevel-matching-audit.md](../feature-tests/63-dedup-multilevel-matching-audit.md)

### 3.1 Cross-Scanner Deduplication

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 3.1 | Cross-scanner dedup: same vuln from Slither + Mythril | Grouped into single dedup group | [ ] |
| 3.2 | Fingerprint types: code, location, AST, semantic all generated | All 4 fingerprint columns populated | [ ] |
| 3.3 | Dedup on scan ingestion: automatic grouping at ingest time | No manual trigger needed | [ ] |

```bash
# Verify dedup groups exist
curl -sk "https://app.0xapogee.com/api/v1/deduplication/groups?limit=5" \
  -H "Authorization: Bearer $TOKEN" | jq '.total, .items[0].finding_count'

# Verify fingerprint columns are populated
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT
    COUNT(*) AS total_vulns,
    COUNT(code_fingerprint) AS has_code_fp,
    COUNT(location_fingerprint) AS has_location_fp,
    COUNT(ast_fingerprint) AS has_ast_fp,
    COUNT(semantic_fingerprint) AS has_semantic_fp
  FROM vulnerability_fingerprints;"
```

### 3.2 Maintenance Operations

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 3.4 | Stale group cleanup: groups >90 days with no activity | Cleaned by maintenance job | [ ] |
| 3.5 | Low-confidence group marking: groups below threshold | Flagged for review | [ ] |
| 3.6 | Duplicate group merge: two groups with overlapping fingerprints | Merged into canonical group | [ ] |
| 3.7 | CronJob execution: 6-hour schedule, 18 concurrent tasks | All tasks complete without deadlock | [ ] |
| 3.8 | Error isolation: one task fails, others continue | No cascade failure (per spec 61) | [ ] |

```bash
# Verify dedup maintenance CronJob
kubectl get cronjob -A | grep dedup
# Expected: dedup-maintenance CronJob with 6-hour schedule

# Check most recent maintenance job completion
kubectl get jobs -A -l app=dedup-maintenance --sort-by=.status.startTime | tail -3
```

### 3.3 Advanced Deduplication

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 3.9 | Pattern frequency recalculation after new scan data | Updated statistics reflect new data | [ ] |
| 3.10 | ML re-ranking: intelligence engine reorders dedup groups | Confidence scores updated | [ ] |
| 3.11 | Multilevel matching: exact + fuzzy + semantic levels | Correct grouping at each level (per spec 63) | [ ] |

---

## 4. Integrations Hub

**Key files:** `TaskDocs-BlockSecOps/PLAN-2026-01-23-UNIFIED-INTEGRATIONS-HUB.md`, `docs/feature-tests/44-platform-integrations.md`, `docs/feature-tests/45-integrations-hub.md`
**Related specs:** [44-platform-integrations.md](../feature-tests/44-platform-integrations.md), [45-integrations-hub.md](../feature-tests/45-integrations-hub.md)

### 4.1 VCS Integrations (OAuth)

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 4.1 | GitHub OAuth: connect, list repos, disconnect | Full lifecycle works | [ ] |
| 4.2 | GitLab OAuth: connect, list repos, disconnect | Full lifecycle works | [ ] |
| 4.3 | Bitbucket OAuth: connect, list repos, disconnect | Full lifecycle works | [ ] |
| 4.4 | Jenkins CI/CD: OAuth token exchange, trigger build | Pipeline triggered | [ ] |

### 4.2 Issue Tracking

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 4.5 | JIRA (Enterprise only): OAuth, create issue from finding | Issue created with vuln details | [ ] |
| 4.6 | JIRA: non-Enterprise tier attempts connection | Denied with tier gate message | [ ] |

### 4.3 ChatOps / Notification Channels

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 4.7 | Slack webhook: test notification delivery | Message received in channel | [ ] |
| 4.8 | Discord webhook: test notification delivery | Message received in channel | [ ] |
| 4.9 | Teams webhook: test notification delivery | Message received in channel | [ ] |

```bash
# Test notification channel delivery
curl -sk -X POST "https://app.0xapogee.com/api/v1/notifications/channels/{channel_id}/test" \
  -H "Authorization: Bearer $TOKEN"
# Expected: 200 with delivery confirmation
```

### 4.4 IDE & Service Accounts

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 4.10 | IDE token generation (Team+): create, display once, use | Token works for IDE auth | [ ] |
| 4.11 | IDE token: attempt to retrieve token value after creation | Only prefix shown | [ ] |
| 4.12 | Service account (Growth+ admin-only): CRUD lifecycle | Key with `bso_sa_` prefix created | [ ] |
| 4.13 | Service account auth: `X-Service-Account-Key` header | Authenticated and scoped | [ ] |
| 4.14 | Service account rate limits: configurable per/min, per/hour | 429 after threshold | [ ] |

### 4.5 UI Navigation

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 4.15 | Tab navigation: `/integrations?tab=chatops` redirect from old `/notification-channels` | Redirect with banner | [ ] |
| 4.16 | Webhook message history: view past deliveries | History displayed with status | [ ] |

---

## 5. Payment & Billing (Stripe)

**Key files:** `TaskDocs-BlockSecOps/phases/08a-phase-8a-stripe-billing-invoices/`, `docs/feature-tests/37-stripe-billing.md`
**Related specs:** [37-stripe-billing.md](../feature-tests/37-stripe-billing.md), [52-dual-payment-options.md](../feature-tests/52-dual-payment-options.md)

### 5.1 Subscription Lifecycle

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 5.1 | New subscription: Developer -> Team upgrade via Stripe Checkout | Tier updated, session invalidated | [ ] |
| 5.2 | Subscription upgrade: Team -> Growth | Immediate feature unlock | [ ] |
| 5.3 | Subscription downgrade: Growth -> Team | API keys/service accounts revoked | [ ] |

### 5.2 Webhook Security

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 5.4 | Stripe webhook signature verification: valid signature | Event processed | [ ] |
| 5.5 | Stripe webhook: invalid/tampered signature | Rejected with 400 | [ ] |
| 5.6 | Stripe webhook: tier metadata validation | Tier matches Stripe product | [ ] |

```bash
# Test webhook with Stripe CLI (test mode)
stripe trigger customer.subscription.updated \
  --override customer.subscription.updated:metadata.tier=team

# Verify webhook endpoint
curl -sk -X POST "https://app.0xapogee.com/api/v1/billing/webhook" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: invalid_signature" \
  -d '{"type":"test"}'
# Expected: 400
```

### 5.3 Billing Operations

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 5.7 | Invoice generation and retrieval | Invoice accessible to user | [ ] |
| 5.8 | Payment failure: card declined | Graceful error, no tier change | [ ] |
| 5.9 | Subscription cancellation | Downgrade to Developer at period end | [ ] |
| 5.10 | x402 pay-per-scan (if enabled): USDC payment flow | Credit applied, scan allowed | [ ] |
| 5.11 | Pricing page: correct tier features and prices displayed | Matches `tiers.json` | [ ] |

```bash
# Verify pricing data matches tiers.json
curl -sk "https://app.0xapogee.com/api/v1/pricing" | \
  jq '.tiers[] | {name: .name, price: .pricing.monthly}'

# Cross-check with tiers.json
cat blocksecops-shared/tier-config/tiers.json | \
  jq '.tiers[] | {name: .name, price: .pricing.monthly}'
```

---

## 6. Authentication & Authorization

**Key files:** `docs/feature-tests/01-authentication.md`, `docs/feature-tests/47-api-keys-security.md`, `docs/standards/api-endpoint-auth.md`
**Automation:** `scripts/audit/06-auth-tests.sh`
**Related specs:** [01-authentication.md](../feature-tests/01-authentication.md), [47-api-keys-security.md](../feature-tests/47-api-keys-security.md)

### 6.1 Login Methods

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 6.1 | Supabase JWT login: email/password | Token issued, session created | [ ] |
| 6.2 | OAuth login: Google, GitHub, Microsoft, Discord | All providers work | [ ] |
| 6.3 | Wallet auth: MetaMask, WalletConnect, Phantom (Solana) | Signature verified, session created | [ ] |
| 6.4 | HS256 fallback: when Supabase unavailable | Local JWT auth works | [ ] |

```bash
# Test Supabase login
SUPABASE_URL="https://huzjlpypdlelqnbjvxad.supabase.co"
SUPABASE_KEY="<anon-key>"

TOKEN=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}' | \
  jq -r '.access_token')

# Verify token works
curl -sk "https://app.0xapogee.com/api/v1/users/me" \
  -H "Authorization: Bearer $TOKEN" | jq '.tier'
```

### 6.2 API Key Authentication

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 6.5 | API key auth: `X-API-Key` header (Growth+) | Authenticated, `last_used_at` updated | [ ] |
| 6.6 | API key expiration: expired key used | Rejected with 401 | [ ] |
| 6.7 | API key refresh: old key immediately invalidated | Old key fails, new key works | [ ] |
| 6.8 | API key soft delete: deactivated key used | Rejected | [ ] |

```bash
# Test API key authentication
curl -sk "https://app.0xapogee.com/api/v1/scans" \
  -H "X-API-Key: bso_<key>"
# Expected: 200 with scan results

# Test expired key
curl -sk -o /dev/null -w "%{http_code}" \
  "https://app.0xapogee.com/api/v1/scans" \
  -H "X-API-Key: bso_expired_key"
# Expected: 401
```

### 6.3 Session & Authorization Security

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 6.9 | Session invalidation on tier change | Must re-login | [ ] |
| 6.10 | CORS: requests from unauthorized origins | Blocked | [ ] |
| 6.11 | HttpOnly cookie: not accessible via JavaScript | XSS-safe | [ ] |
| 6.12 | Scope-based authorization: user accesses resource outside scope | 403 Forbidden | [ ] |

```bash
# Test CORS from unauthorized origin
curl -sk -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  -X OPTIONS \
  "https://app.0xapogee.com/api/v1/health/live" \
  -D - 2>/dev/null | grep -i "access-control"
# Expected: No Access-Control-Allow-Origin for evil.com

# Test scope enforcement
curl -sk -X DELETE "https://app.0xapogee.com/api/v1/scans/some-id" \
  -H "X-API-Key: bso_readonly_key"
# Expected: 403 Forbidden (key only has read scope)
```

---

## 7. Kubernetes & Infrastructure Security

**Key files:** `blocksecops-gcp-infrastructure/k8s/`, `docs/feature-tests/51-kubernetes-security.md`, `docs/standards/kubernetes-pod-lifecycle.md`
**Automation:** `scripts/audit/07-k8s-security-audit.sh`
**Related specs:** [51-kubernetes-security.md](../feature-tests/51-kubernetes-security.md)

### 7.1 Pod Security

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 7.1 | All 8 services: `runAsNonRoot: true`, `runAsUser: 1000` | Pod spec verified | [ ] |
| 7.2 | All containers: `readOnlyRootFilesystem`, `drop ALL` capabilities | Security context enforced | [ ] |
| 7.3 | Seccomp profile: `RuntimeDefault` on all pods | Profile applied | [ ] |

```bash
# Automated check — run scripts/audit/07-k8s-security-audit.sh
# Or manually:
for ns in api-service-local orchestration-local tool-integration-local dashboard-local \
          data-service-local intelligence-engine-local notification-local contract-parser-local; do
  echo "=== $ns ==="
  kubectl get deployment -n $ns -o json | jq '
    .items[0].spec.template.spec | {
      runAsNonRoot: .securityContext.runAsNonRoot,
      runAsUser: .securityContext.runAsUser,
      seccomp: .securityContext.seccompProfile.type
    }'
done
```

### 7.2 Network Security

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 7.4 | NetworkPolicies: default deny-all + explicit allow rules | Inter-service traffic restricted | [ ] |
| 7.5 | NetworkPolicy: unauthorized service-to-service call | Blocked by policy | [ ] |

```bash
# Verify NetworkPolicies exist for all namespaces
for ns in api-service-local orchestration-local tool-integration-local dashboard-local \
          data-service-local intelligence-engine-local notification-local contract-parser-local; do
  COUNT=$(kubectl get networkpolicy -n $ns --no-headers 2>/dev/null | wc -l)
  echo "$ns: $COUNT NetworkPolicies"
done
# Expected: At least 1 per namespace (default-deny + allow rules)
```

### 7.3 Deployment Configuration

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 7.6 | `revisionHistoryLimit: 3` on all deployments | No stale ReplicaSets accumulate | [ ] |
| 7.7 | Traefik ingress: routes correctly to all services | All endpoints reachable | [ ] |
| 7.8 | TLS termination: HTTPS enforced, valid certificates | No mixed content | [ ] |
| 7.9 | Resource limits: CPU/memory set on all containers | No unbounded resource usage | [ ] |

```bash
# Check revisionHistoryLimit
for ns in api-service-local orchestration-local tool-integration-local dashboard-local \
          data-service-local intelligence-engine-local notification-local contract-parser-local; do
  LIMIT=$(kubectl get deployment -n $ns -o jsonpath='{.items[0].spec.revisionHistoryLimit}' 2>/dev/null)
  DEPLOY=$(kubectl get deployment -n $ns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ "$LIMIT" == "3" ]; then
    echo "PASS: $ns/$DEPLOY revisionHistoryLimit=$LIMIT"
  else
    echo "FAIL: $ns/$DEPLOY revisionHistoryLimit=$LIMIT (expected 3)"
  fi
done

# Check resource limits on all containers
kubectl get pods -A -o json | jq '
  .items[] | select(.metadata.namespace | test("-local$")) |
  .spec.containers[] | {
    namespace: .name,
    cpu_limit: .resources.limits.cpu,
    mem_limit: .resources.limits.memory
  } | select(.cpu_limit == null or .mem_limit == null)'
# Expected: empty output (all have limits)
```

### 7.4 Data & Image Security

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 7.10 | PersistentVolume: PostgreSQL data survives pod restart | Data intact after restart | [ ] |
| 7.11 | Secrets: stored in GCP Secret Manager, not in manifests | No plaintext secrets in Git | [ ] |
| 7.12 | Image pull: all images from private Artifact Registry | No public registry pulls | [ ] |
| 7.13 | Pod disruption budget: rolling update doesn't cause downtime | Zero-downtime deploy | [ ] |

```bash
# Check for plaintext secrets in Git
grep -r "password\|secret\|api_key\|token" \
  blocksecops-gcp-infrastructure/k8s/ \
  --include="*.yaml" --include="*.yml" | \
  grep -v "secretKeyRef\|ExternalSecret\|SecretStore\|#\|kind: Secret" | \
  grep -v "\.md:" | head -20
# Expected: No plaintext credential values

# Check image registries
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | \
  sort -u | grep -v "gcr.io\|harbor.0xapogee\|registry.k8s.io"
# Expected: No unexpected public registries
```

---

## 8. Database Integrity & Migrations

**Key files:** `docs/standards/database-management.md`, Alembic migrations in `blocksecops-api-service`
**Automation:** `scripts/audit/08-database-integrity.sh`

### 8.1 Migration Integrity

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 8.1 | All Alembic migrations: run forward from empty DB | Clean schema created | [ ] |
| 8.2 | Migration rollback: downgrade last 3 migrations | Clean rollback, no data loss | [ ] |

```bash
# Verify all migrations applied
cd blocksecops-api-service
alembic heads
alembic current

# Count migrations
ls -1 alembic/versions/*.py | wc -l
```

### 8.2 Constraint Enforcement

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 8.3 | ENUM constraints: invalid tier/status values rejected | DB-level enforcement | [ ] |
| 8.4 | Audit log triggers: INSERT works, UPDATE/DELETE blocked | Append-only verified | [ ] |
| 8.5 | Foreign key cascades: delete org -> cascades correctly | Related records cleaned | [ ] |
| 8.6 | Soft delete consistency: `is_active=false` excludes from queries | No ghost data in results | [ ] |

```bash
# Test ENUM constraints
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "INSERT INTO audit_logs (id, user_id, action, details, created_at)
   VALUES (gen_random_uuid(), gen_random_uuid(), 'test', '{}', NOW());"
# Expected: Success (INSERT allowed)

kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "UPDATE audit_logs SET action = 'tampered' WHERE id = (SELECT id FROM audit_logs LIMIT 1);"
# Expected: ERROR (trigger blocks UPDATE)
```

### 8.3 Performance & Data

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 8.7 | Index performance: tier + security alert queries use indexes | EXPLAIN shows index scan | [ ] |
| 8.8 | Backup and restore: take backup, destroy, restore | Full recovery verified | [ ] |
| 8.9 | BVD pattern seed: `vulnerability_patterns.json` loaded (393+ patterns) | All patterns in DB | [ ] |
| 8.10 | Scanner-to-pattern mappings: 637 mappings present | Count matches expected | [ ] |
| 8.11 | CloudSQL proxy: connection from GKE pods | Authenticated DB access works | [ ] |

```bash
# Verify BVD patterns loaded
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM vulnerability_patterns;"
# Expected: >= 393

# Verify scanner-to-pattern mappings
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM pattern_tool_mappings;"
# Expected: >= 637

# Verify index usage for common queries
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "EXPLAIN (ANALYZE, FORMAT TEXT)
   SELECT * FROM vulnerabilities WHERE severity = 'critical' LIMIT 10;"
# Expected: Index Scan or Bitmap Index Scan
```

---

## 9. Application Security (OWASP)

**Key files:** `docs/feature-tests/28-webapp-security.md`, `docs/feature-tests/29-application-security.md`
**Automation:** `scripts/audit/09-appsec-tests.sh`
**Related specs:** [28-webapp-security.md](../feature-tests/28-webapp-security.md), [29-application-security.md](../feature-tests/29-application-security.md)

### 9.1 Injection & XSS

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 9.1 | SQL injection: parameterized queries on all endpoints | No injection possible | [ ] |
| 9.2 | XSS: no `localStorage` auth tokens (removed in v0.45.8) | Tokens in HttpOnly cookies only | [ ] |
| 9.3 | CSRF: state-changing requests require valid token | Forged requests rejected | [ ] |

```bash
# Test SQL injection on search endpoint
curl -sk -X POST "https://app.0xapogee.com/api/v1/search" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"test'\'' OR 1=1 --","limit":5}'
# Expected: Normal response (parameterized), no data leak
```

### 9.2 Input Validation & Upload Security

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 9.4 | Input validation: chat textarea maxLength=4000 enforced | Oversized input rejected | [ ] |
| 9.5 | File upload: malicious file types rejected | Only .sol/.vy/.rs/.zip allowed | [ ] |

```bash
# Test oversized input
python3 -c "import json; print(json.dumps({'query': 'A'*5000}))" | \
  curl -sk -X POST "https://app.0xapogee.com/api/v1/search" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @-
# Expected: 422 validation error

# Test malicious file upload
echo "malicious" > /tmp/test.exe
curl -sk -X POST "https://app.0xapogee.com/api/v1/upload" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/tmp/test.exe"
# Expected: 422 or 400 (invalid file type)
rm /tmp/test.exe
```

### 9.3 Rate Limiting & Error Handling

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 9.6 | Rate limiting: brute force login attempts | Throttled after N attempts | [ ] |
| 9.7 | Error responses: no stack traces or internal details leaked | Generic error messages | [ ] |

```bash
# Test error response doesn't leak internals
curl -sk "https://app.0xapogee.com/api/v1/scans/nonexistent-id" \
  -H "Authorization: Bearer $TOKEN" | jq '.detail'
# Expected: Generic "Not found" message, no stack trace or internal paths
```

### 9.4 Security Headers & Dependencies

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 9.8 | Security headers: CSP, X-Frame-Options, HSTS | All headers present | [ ] |
| 9.9 | Dependency vulnerabilities: `npm audit` / `pip audit` clean | No critical/high CVEs | [ ] |
| 9.10 | WebSocket auth: reconnect passes stored token (fixed in v0.45.8) | Authenticated WS connection | [ ] |
| 9.11 | Non-null assertion removal: 11 assertions replaced with fallbacks | No runtime crashes on null | [ ] |

```bash
# Check security headers
curl -sk -D - "https://app.0xapogee.com/" 2>/dev/null | \
  grep -iE "^(x-frame-options|content-security-policy|strict-transport-security|x-content-type-options):"
# Expected: All 4 headers present

# Check npm audit (dashboard)
cd blocksecops-dashboard && npm audit --audit-level=high 2>/dev/null
# Expected: 0 high/critical vulnerabilities

# Check pip audit (API service)
cd blocksecops-api-service && pip audit 2>/dev/null
# Expected: 0 high/critical vulnerabilities
```

---

## 10. Monitoring, Alerting & Observability (GCP Stack)

**Key files:** `blocksecops-gcp-infrastructure/terraform/`, `blocksecops-admin-portal/` (circuit breaker), `docs/feature-tests/59-admin-portal-v0.4.0.md`
**Related specs:** [59-admin-portal-v0.4.0.md](../feature-tests/59-admin-portal-v0.4.0.md)

### 10.1 Health Endpoints

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 10.1 | Health endpoints: `/health` on all 8 services | 200 OK with status details | [ ] |

```bash
# Check all service health endpoints (see smoke-test.md for full script)
curl -sk "https://app.0xapogee.com/api/v1/health/live" | jq '.status'
curl -sk "https://app.0xapogee.com/api/v1/health/ready" | jq '.status'
# Expected: "healthy" / "ready"
```

### 10.2 GCP Cloud Logging & Monitoring

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 10.2 | Google Cloud Logging: GKE pod logs collected automatically | Logs visible in Cloud Console | [ ] |
| 10.3 | Cloud Logging: log-based queries filter by service/severity | Structured log search works | [ ] |
| 10.4 | Google Cloud Monitoring: GKE metrics (CPU, memory, pod restarts) | Metrics dashboards render data | [ ] |
| 10.5 | Cloud Monitoring alerting policies: service down, high error rate, scan backlog | Alerts fire correctly | [ ] |
| 10.6 | Log-based metrics: custom metrics derived from application logs | Metrics created and queryable | [ ] |

**Manual verification steps:**
1. Open GCP Cloud Console > Logging > Logs Explorer
2. Query: `resource.type="k8s_container" resource.labels.namespace_name="api-service"`
3. Verify structured JSON logs with severity levels
4. Open Cloud Monitoring > Metrics Explorer
5. Query GKE metrics: `kubernetes.io/container/cpu/usage_time`
6. Verify alerting policies exist for: service down, error rate > threshold, scan queue depth

### 10.3 Circuit Breaker (Admin Portal)

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 10.7 | Circuit breaker: open/half-open/closed transitions | Toast notifications shown | [ ] |
| 10.8 | Circuit breaker: per-service-group isolation (8 groups) | One group failure doesn't cascade | [ ] |
| 10.9 | Circuit breaker: force reset from admin | Service group recovers | [ ] |

### 10.4 External Monitoring

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 10.10 | Dependency monitor: external service health tracked | Degradation detected | [ ] |
| 10.11 | Uptime checks: external HTTPS probes on `app.0xapogee.com` | Downtime detected within SLA | [ ] |

---

## 11. Intelligence Engine & ML

**Key files:** `blocksecops-intelligence-engine/`, `docs/feature-tests/27-ai-ml-features.md`, `docs/feature-tests/50-ai-invariant-generation.md`
**Related specs:** [27-ai-ml-features.md](../feature-tests/27-ai-ml-features.md), [50-ai-invariant-generation.md](../feature-tests/50-ai-invariant-generation.md)

### 11.1 ML Predictions

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 11.1 | False positive prediction: known FP contract submitted | ML flags as likely FP | [ ] |
| 11.2 | Risk scoring: scan produces unbounded risk score | Score calculated, level assigned | [ ] |
| 11.3 | Vulnerability classification: pattern matched to BVD code | Correct category assigned | [ ] |

```bash
# Test risk scoring
curl -sk "https://app.0xapogee.com/api/v1/statistics/risk" \
  -H "Authorization: Bearer $TOKEN" | jq '.projects[0] | {risk_score, risk_level}'
# Expected: risk_score (number), risk_level (CRITICAL/HIGH/MEDIUM/LOW)
```

### 11.2 Fingerprinting & Analysis

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 11.4 | Fingerprinting strategies: ASM, ENC, EVT, L2, Semantic | All strategies produce output | [ ] |
| 11.5 | RLHF feedback loop: user confirms/rejects FP prediction | Model feedback recorded | [ ] |
| 11.6 | Model versioning: rollback to previous model | Previous model serves requests | [ ] |

### 11.3 AI Features

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 11.7 | AI inline explanations (Claude API): vulnerability detail page | Explanation rendered | [ ] |
| 11.8 | Prompt injection prevention: malicious input in contract comments | Sanitized before LLM call | [ ] |
| 11.9 | ML data consent: GDPR opt-in/out tracked | Consent state respected | [ ] |

```bash
# Test prompt injection prevention
curl -sk -X POST "https://app.0xapogee.com/api/v1/upload" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test-contracts/prompt-injection.sol"
# Verify no prompt injection in AI explanation output

# Test GDPR consent
curl -sk "https://app.0xapogee.com/api/v1/users/me/consent" \
  -H "Authorization: Bearer $TOKEN" | jq '.ml_data_consent'
```

---

## 12. End-to-End Workflows

**Manual testing required for all items in this section.**

### 12.1 Core Workflows

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 12.1 | Full scan lifecycle: upload -> select scanners -> scan -> results -> dedup -> report | Complete flow, no errors | [ ] |
| 12.2 | Multi-scanner comparison: same contract, all Solidity scanners | Comparison view renders, dedup works | [ ] |
| 12.3 | CI/CD pipeline: GitHub Action triggers scan, quality gate evaluates | Pass/fail badge returned | [ ] |
| 12.4 | New user onboarding: register -> free tier -> first scan -> upgrade | Smooth flow with correct gates | [ ] |
| 12.5 | Enterprise workflow: org admin -> add users -> assign roles -> RBAC enforced | Permission boundaries hold | [ ] |

### 12.2 Integration Workflows

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 12.6 | Notification flow: scan completes -> webhook fires -> Slack message | End-to-end delivery | [ ] |
| 12.7 | IDE workflow: generate token -> configure VS Code -> trigger scan -> view results | Full IDE loop works | [ ] |
| 12.8 | Admin workflow: admin portal -> view users -> change tier -> verify enforcement | Admin actions propagate | [ ] |

### 12.3 Resilience Workflows

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 12.9 | Disaster recovery: kill API service pod -> auto-restart -> no data loss | Self-healing verified | [ ] |
| 12.10 | WebSocket real-time: scan progress updates stream to dashboard | Live progress shown | [ ] |

```bash
# Test pod self-healing
kubectl delete pod -n api-service-local -l app.kubernetes.io/name=api-service
# Wait for replacement pod
kubectl wait --for=condition=Ready pod -n api-service-local -l app.kubernetes.io/name=api-service --timeout=120s
# Verify API is responsive
curl -sk "https://app.0xapogee.com/api/v1/health/live" | jq '.status'
# Expected: "healthy"
```

---

## 13. Performance & Load

**Requires dedicated load testing tooling (k6, locust, or similar).**

### 13.1 Concurrency & Response Times

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 13.1 | Concurrent scans: tier max concurrent scans running simultaneously | All complete without interference | [ ] |
| 13.2 | API response time: key endpoints < 500ms p95 | SLA met | [ ] |
| 13.3 | Dashboard load time: initial page < 3s | Acceptable UX | [ ] |
| 13.4 | Scanner pod scheduling: 10 scans queued simultaneously | Pods scheduled, no starvation | [ ] |

### 13.2 Infrastructure Under Load

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 13.5 | Database connection pool: under sustained load | No connection exhaustion | [ ] |
| 13.6 | Redis cache: cache hit rate under normal operation | > 80% hit rate | [ ] |
| 13.7 | Large contract scan: 5000+ line Solidity file | Completes within timeout | [ ] |
| 13.8 | Dedup maintenance CronJob: with 10k+ vulnerabilities in DB | Completes within 6-hour window | [ ] |

```bash
# Example k6 load test for API response times
# k6 run scripts/audit/k6-api-load-test.js

# Quick response time check
for endpoint in "health/live" "scans?limit=1" "contracts?limit=1" "vulnerabilities?limit=1"; do
  TIME=$(curl -sk -o /dev/null -w "%{time_total}" \
    "https://app.0xapogee.com/api/v1/$endpoint" \
    -H "Authorization: Bearer $TOKEN")
  echo "$endpoint: ${TIME}s"
done
```

---

## 14. Smoke Test (Production Deployment)

**Reference:** `/docs/standards/smoke-test.md`
**Automation:** `scripts/audit/smoke-test-production.sh`

### 14.1 Pre-Flight

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 14.1 | Pre-flight: all pods Running, no CrashLoopBackOff | All pods healthy | [ ] |
| 14.2 | Service health: all `/health` endpoints respond | 200 OK across services | [ ] |
| 14.3 | Database connectivity: API service connects to CloudSQL | Queries succeed | [ ] |
| 14.4 | Redis connectivity: cache operations work | SET/GET succeed | [ ] |

```bash
# Run full smoke test
# ./scripts/audit/smoke-test-production.sh

# Quick pod health check
kubectl get pods -A --no-headers | grep -v "Running\|Completed" | grep -v "kube-system"
# Expected: empty output
```

### 14.2 Core Functionality

| # | Test | Expected Result | Status |
|---|------|-----------------|--------|
| 14.5 | Ingress: `app.0xapogee.com` resolves and loads dashboard | HTTPS, valid cert | [ ] |
| 14.6 | Auth flow: login via Supabase, receive JWT | Authenticated session | [ ] |
| 14.7 | Scan flow: upload + scan + results displayed | End-to-end works | [ ] |
| 14.8 | Stripe: pricing page loads, checkout redirects | Payment flow accessible | [ ] |
| 14.9 | Admin portal: accessible to admin users only | RBAC enforced | [ ] |
| 14.10 | Monitoring: Google Cloud Logging + Monitoring show live data | Observability confirmed | [ ] |

```bash
# Check HTTPS and certificate
curl -sI "https://app.0xapogee.com" | head -5
# Expected: HTTP/2 200, valid TLS

# Check all health endpoints
for svc in "api/v1/health/live" "api/v1/health/ready"; do
  STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://app.0xapogee.com/$svc")
  echo "$svc: $STATUS"
done
# Expected: All 200
```

---

## Sign-Off

### Test Execution Log

| Date | Tester | Sections | Result | Notes |
|------|--------|----------|--------|-------|
| | | | | |

### Final Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Engineering Lead | | | [ ] Approved |
| Security Lead | | | [ ] Approved |
| QA Lead | | | [ ] Approved |
| Product Owner | | | [ ] Approved |

### Go/No-Go Decision

- [ ] All P0 (Critical) tests pass
- [ ] All P1 (High) tests pass or have documented exceptions
- [ ] No unresolved security findings (Critical/High)
- [ ] Monitoring and alerting confirmed operational
- [ ] Rollback plan documented and tested
- [ ] On-call rotation established

**Decision:** [ ] GO / [ ] NO-GO

**Date:** _______________

---

## Related Documents

- [Smoke Test Standards](../standards/smoke-test.md)
- [Compliance Checklist](../standards/compliance-checklist.md)
- [API Security Audit](./2026-02-07_API_Security_Audit.md)
- [Kubernetes Security Tests](../feature-tests/51-kubernetes-security.md)
- [Feature Tests Index](../feature-tests/README.md)
- [Production Security Checklist](../security/production-security-checklist.md)
