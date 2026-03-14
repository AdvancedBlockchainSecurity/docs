# Go-Live Audit Scripts

Automated test scripts for the Apogee GCP production launch audit.

**Full checklist:** [`docs/audits/GO-LIVE-AUDIT-TESTING-CHECKLIST.md`](../../docs/audits/GO-LIVE-AUDIT-TESTING-CHECKLIST.md)

## Scripts

| Script | Section | Description |
|--------|---------|-------------|
| `run-all-audits.sh` | All | Master runner, executes all scripts and generates report |
| `06-auth-tests.sh` | 6 | JWT login, API key auth, CORS, scope enforcement |
| `07-k8s-security-audit.sh` | 7 | Pod security contexts, NetworkPolicies, resource limits, image tags |
| `08-database-integrity.sh` | 8 | ENUM constraints, audit triggers, indexes, BVD patterns, migrations |
| `09-appsec-tests.sh` | 9 | SQL injection, file upload, security headers, CORS, dependencies |
| `smoke-test-production.sh` | 14 | Pod health, service endpoints, TLS, auth, dashboard, Stripe |
| `k6-api-load-test.js` | 13 | k6 load test for API response times and error rates |

## Usage

### Run all audits

```bash
cd /home/pwner/Git
./scripts/audit/run-all-audits.sh
```

Reports are saved to `scripts/audit/reports/`.

### Run individual scripts

```bash
# Kubernetes security
./scripts/audit/07-k8s-security-audit.sh

# Database integrity
./scripts/audit/08-database-integrity.sh

# Production smoke test
BASE_URL=https://app.0xapogee.com ./scripts/audit/smoke-test-production.sh
```

### Environment variables

| Variable | Used By | Description |
|----------|---------|-------------|
| `BASE_URL` | All HTTP scripts | Platform URL (default: `https://app.0xapogee.com`) |
| `ADMIN_URL` | smoke-test | Admin portal URL |
| `CURL_FLAGS` | All HTTP scripts | curl flags (default: `-sk`) |
| `TOKEN` | auth, smoke, appsec | JWT token for authenticated tests |
| `API_KEY` | auth | API key for key-based auth tests |
| `SUPABASE_URL` | auth | Supabase project URL |
| `SUPABASE_KEY` | auth | Supabase anon key |
| `TEST_EMAIL` | auth | Test user email |
| `TEST_PASSWORD` | auth | Test user password |
| `DB_NAMESPACE` | database | K8s namespace for PostgreSQL (default: `postgresql-local`) |
| `DB_USER` | database | Database user (default: `blocksecops`) |
| `DB_NAME` | database | Database name (default: `solidity_security`) |

> **Note:** Tier quota and billing tests have been consolidated into pytest tests
> in `blocksecops-api-service/tests/`. See `tests/unit/test_tier_config_validation.py`,
> `tests/integration/test_billing_api.py`, and `tests/regression/test_billing_plans_match_tiers_json.py`.
> For production tier verification, use the Python audit script at
> `docs/audits/scripts/audit-tier-v4.py`.

### Load testing

```bash
k6 run --env BASE_URL=https://app.0xapogee.com \
       --env TOKEN=<jwt_token> \
       scripts/audit/k6-api-load-test.js
```
