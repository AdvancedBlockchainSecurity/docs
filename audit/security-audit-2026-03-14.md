# Security Audit — 2026-03-14

Audit scope: codebase, Kustomize, images, database, ports, auth, secrets, encryption, versioning against `docs/standards/`.

## Passing

| Standard | Status |
|----------|--------|
| revisionHistoryLimit: 3 (all 9 deployments) | PASS |
| Pod/container security contexts | PASS |
| includeSelectors: false | PASS |
| Dockerfile security (non-root, multi-stage, OCI labels) | PASS |
| No hardcoded secrets in source | PASS |
| Port assignments (no conflicts) | PASS |
| Auth endpoints (write endpoints use require_auth_with_scope) | PASS |
| No secrets in ConfigMaps | PASS |
| Database SSL (asyncpg + hostssl) | PASS |
| CORS (config-driven, no wildcard) | PASS |
| Rate limiting (fails closed in production) | PASS |
| Celery (JSON-only, no pickle) | PASS |
| JWT (HS256, 60-min expiry) | PASS |

## Findings

### F1 — Version drift: admin-portal (HIGH) — FIXED
- `k8s/base/admin-portal/kustomization.yaml` had `0.1.0`, package.json is `0.7.12`
- `k8s/overlays/local/kustomization.yaml` had `0.7.11`
- Fix: updated both to `0.7.12`

### F2 — Version drift: dashboard (HIGH) — FIXED
- `k8s/base/dashboard/kustomization.yaml` had `0.46.32`, package.json is `0.46.36`
- Fix: updated to `0.46.36`

### F3 — Missing NetworkPolicy: shared (HIGH) — FIXED
- `k8s/base/solidity-security-shared/` had no NetworkPolicy
- Fix: created `networkpolicy.yaml` with default-deny, ingress from platform services, egress to DNS only

### F4 — Image tag `:latest` in dashboard base (MEDIUM) — FIXED
- `k8s/base/dashboard/deployment.yaml` used `:latest` and `imagePullPolicy: Never`
- Fix: removed `:latest` (kustomization handles tag), changed to `IfNotPresent`

### F5 — Image tag `:latest` in shared base (MEDIUM) — FIXED
- `k8s/base/solidity-security-shared/deployment.yaml` used `:latest`
- Fix: removed `:latest`

### F6 — tool-integration NetworkPolicy (FALSE POSITIVE)
- File exists as `network-policy.yaml` (hyphenated), audit searched for `networkpolicy.yaml`

## Dependency Vulnerabilities

### Python (pip-audit)

| Package | CVE | Fix Version |
|---------|-----|-------------|
| urllib3 2.3.0 | CVE-2026-21441 | 2.6.3 |
| wheel 0.46.1 | CVE-2026-24049 | 0.46.2 |

### Rust (cargo audit)

| Crate | Advisory | Fix |
|-------|----------|-----|
| bytes (contract-parser) | RUSTSEC-2026-0007 — integer overflow in BytesMut::reserve | Upgrade to >=1.11.1 |
| pyo3 0.22.6 (shared) | RUSTSEC-2025-0020 — buffer overflow in PyString::from_object | Upgrade to >=0.24.1 |

### JavaScript (npm audit)

| Package | Severity | Service |
|---------|----------|---------|
| axios 1.0.0-1.13.4 | HIGH — DoS via __proto__ | admin-portal |
| dompurify 3.1.3-3.3.1 | MODERATE — XSS | dashboard |
| elliptic | HIGH — risky crypto implementation | dashboard (via @solana/wallet-adapter) |

## Remediation Priority

1. `pip install --upgrade urllib3 wheel` (system packages)
2. `npm audit fix` in admin-portal (axios)
3. `npm audit fix` in dashboard (dompurify)
4. `cargo update -p bytes` in contract-parser
5. Upgrade pyo3 to 0.24.1+ in shared/rust/Cargo.toml
6. Dashboard elliptic — transitive via @solana/wallet-adapter-wallets, requires upstream fix or `npm audit fix --force`
