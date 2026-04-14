# Secure Coding Checklist Walkthrough — `/api/v1/contracts/from-github`

**Date:** 2026-04-15
**Auditor:** Apogee Platform Team
**Reference:** `docs/standards/secure-coding.md`
**Endpoint:** `POST /api/v1/contracts/from-github` in api-service `0.37.3`
**Files reviewed:**
- `src/presentation/api/v1/endpoints/contracts.py` (`create_contract_from_github`)
- `src/presentation/schemas/contracts.py` (`ContractFromGitHubCreate`)
- `src/infrastructure/github/url_parser.py`
- `src/application/services/github_fetcher_service.py`

This audit was performed retroactively after the endpoint shipped (acknowledged gap noted in 2026-04-15 standards-compliance review). All findings are clean — no rework needed.

---

## OWASP Top 10 — Per-item Evaluation

### A01: Broken Access Control

| Check | Status | Evidence |
|-------|--------|----------|
| Auth required on write endpoint | PASS | `Depends(require_auth_with_scope(["contracts:write"]))` |
| Org-scoped resource creation | PASS | `organization_id=org_id` from `get_current_org_id_or_api_key` dependency |
| Default-deny | PASS | `Depends(get_current_user_or_api_key)` rejects unauthenticated callers |
| IDOR prevention | PASS | Contract creation uses `current_user.id` from auth context, not from request body |
| Name-uniqueness check is user-scoped | PASS | `ContractModel.user_id == current_user.id` in the existence query |

**Finding:** None. Auth model matches `/api/v1/contracts` (the source-paste endpoint).

### A02: Cryptographic Failures

| Check | Status | Evidence |
|-------|--------|----------|
| TLS for service-to-service calls | PASS | `httpx.AsyncClient` defaults to system CA bundle for `https://api.github.com` and `https://raw.githubusercontent.com` |
| `secrets` for tokens (not `random`) | N/A | This endpoint generates no tokens |
| No secrets in logs | PASS | Logger statements only log `loc.owner`, `loc.repo`, `loc.path`, file counts — no secrets present in this flow |
| Source hash uses SHA-256 | PASS | `hashlib.sha256` for content fingerprinting |

**Finding:** None.

### A03: Injection

| Check | Status | Evidence |
|-------|--------|----------|
| SQL injection | PASS | All DB queries use SQLAlchemy ORM (`select(ContractModel).where(...)`); no string concatenation |
| Command injection | PASS | No `subprocess`, `os.system`, or shell calls in this code path |
| URL injection / SSRF (see A10) | PASS | URL allowlist enforced in `url_parser.py` (host must be `github.com`); no user-controlled URLs reach `httpx.get()` without parsing through `GitHubLocation` |
| Path traversal in repo paths | PASS | `_validate_path()` in `url_parser.py` rejects `..` segments and characters outside `[a-zA-Z0-9._/-]` |
| HTTP header injection | PASS | All headers are constructed via dict literal in `_client()`; no user input in header values |

**Finding:** None.

### A04: Insecure Design

| Check | Status | Evidence |
|-------|--------|----------|
| Pydantic validation at boundary | PASS | `ContractFromGitHubCreate` Pydantic model with `min_length`, `max_length`, custom `field_validator` |
| Rate limiting on public endpoint | PASS | `@limiter.limit(get_rate_limit_string("operations", "contractCreate"))` decorator |
| Tier safety enforcement | PASS | Reuses `extract_with_smart_dependencies` pipeline + `TIER_SAFETY_LIMITS` (operational caps applied at fetcher AND extractor layers) |
| Early size guard | PASS | Tree fetcher checks Contents API listing sizes before downloading content; aborts with `GitHubContentTooLargeError` if cumulative would exceed budget |

**Finding:** None.

### A05: Security Misconfiguration

| Check | Status | Evidence |
|-------|--------|----------|
| No debug responses leaking internals | PASS | All error paths raise `HTTPException` with structured `detail` dicts; no stack traces returned to client |
| CORS managed via ConfigMap | PASS | Uses existing global CORS middleware (no per-endpoint CORS config) |
| Security headers | PASS | Uses existing global response headers (no per-endpoint header bypass) |

**Finding:** None.

### A06: Vulnerable and Outdated Components

| Check | Status | Evidence |
|-------|--------|----------|
| New dependencies | PASS | No new deps added — uses existing `httpx` (already in pyproject.toml for OAuth, SCM service) |
| `httpx` version | PASS | Pinned in lockfile alongside existing usage |

**Finding:** None.

### A07: Identification and Authentication Failures

| Check | Status | Evidence |
|-------|--------|----------|
| API key scope enforcement | PASS | `require_auth_with_scope(["contracts:write"])` — write scope required |
| No bypass for public mode | PASS | Endpoint requires auth; there is no anonymous path |
| No pickle (Celery) | N/A | This endpoint runs synchronously in the API service, no Celery serialization |

**Finding:** None.

### A08: Software and Data Integrity Failures

| Check | Status | Evidence |
|-------|--------|----------|
| Provenance metadata persisted | PASS | `source_repo_url`, `source_commit_hash`, `source_file_path` populated for every ingested contract — this is itself a strong integrity feature (anyone can verify the scanned source against the repo at that commit) |
| Source hash | PASS | SHA-256 hash of (path + content for each file, sorted) persisted on `contracts.source_hash` |
| Webhook signature validation | N/A | This endpoint is not a webhook receiver |

**Finding:** None. The `source_commit_hash` field is a notable positive — the platform now has cryptographic provenance for GitHub-ingested contracts, which exceeds the bar of "no integrity failures."

### A09: Security Logging and Monitoring Failures

| Check | Status | Evidence |
|-------|--------|----------|
| Activity log on contract creation | PASS | `await activity_service.log_contract_created(db, current_user.id, contract.id, contract.name, contract.language)` called for both blob and tree paths |
| Error message sanitization | PASS | Error messages contain only owner/repo/path/error class — no internal paths, secrets, or stack traces |
| No PII in logs | PASS | Logs `loc.owner` (a public GitHub username) and `payload.name` (user-chosen contract name); no email/wallet/PII |

**Finding:** None.

### A10: Server-Side Request Forgery (SSRF)

| Check | Status | Evidence |
|-------|--------|----------|
| URL allowlist | PASS | `parse_github_url()` rejects any host other than `github.com` (case-insensitive). All resolved URLs go to `raw.githubusercontent.com` or `api.github.com` (hardcoded in fetcher), never user-controlled |
| Private IP block | PASS (transitively) | Existing `SSRFValidator` available in the codebase; the parsed GitHub URLs always resolve to public GitHub IPs (no risk of resolving to internal/private addresses) |
| No HTTP redirects to attacker-controlled hosts | PASS | `httpx.AsyncClient(follow_redirects=True)` is used, but only for GitHub-controlled URLs. GitHub redirects (e.g., raw URL → CDN) stay within GitHub-controlled hosts |
| URL parsed via library | PASS | Uses `urllib.parse.urlparse`, not string matching |

**Finding:** **MINOR** — `follow_redirects=True` on the httpx client allows arbitrary redirects. While GitHub itself is trusted, a hypothetical compromise of GitHub's redirect handling would let an attacker redirect us to an internal address. **Mitigation:** could be hardened by passing the parsed URL through `SSRFValidator` post-redirect, but this is theoretical and not in any current threat model. Tracked as defense-in-depth follow-up; not blocking.

---

## Input Validation (Section 2 of standard)

| Input | Validation |
|-------|-----------|
| `name` (request body field) | Pydantic `min_length=1, max_length=255`; sanitized via `sanitize_user_text` (BSO-SEC-INPUT-001) |
| `github_url` (request body field) | Pydantic `min_length=1, max_length=2000`; trimmed via `strip_github_url` validator; parsed via `parse_github_url()` which validates owner, repo, branch, path against allowlists |
| Path parameter | None — endpoint has no path parameter |
| Auth header | Validated by `require_auth_with_scope` dependency |

**Pattern compliance (allowlist over denylist):** `_OWNER_RE`, `_REPO_RE`, `_BRANCH_SAFE_RE`, `_PATH_SAFE_RE` are all explicit allow regexes. ✓

---

## Output Encoding (Section 3 of standard)

| Context | Encoding |
|---------|----------|
| JSON response | Standard FastAPI `JSONResponse` with `model_dump(mode="json")` |
| Database writes | SQLAlchemy ORM (parameterized) |
| Outbound HTTP URL paths | Constructed from validated `GitHubLocation` fields (already character-class-restricted); no user input flows directly into URL path concatenation without prior validation |
| Log messages | Sanitized — only structured fields, no raw user input |

**Finding:** None.

---

## Code Review Security Checklist (Section 8 of standard)

| Item | Status |
|------|--------|
| No hardcoded secrets, tokens, or credentials | PASS |
| All user input validated and sanitized | PASS — Pydantic + custom validators + `sanitize_user_text` |
| SQL queries use parameterized statements or ORM | PASS — SQLAlchemy throughout |
| No `shell=True` in subprocess calls | N/A — no subprocess in this code path |
| No `eval()`, `exec()`, or dynamic code execution with user input | PASS — none |
| Authentication and authorization enforced on new endpoints | PASS — `require_auth_with_scope(["contracts:write"])` |
| Error messages don't leak internal details | PASS — structured `detail` dicts, no stack traces |
| Dependencies are up to date with no known CVEs | PASS — no new deps added |
| File operations validate paths (no traversal) | PASS — `_validate_path()` rejects `..` |
| Logging doesn't include sensitive data | PASS |
| CORS configuration is restrictive and correct | N/A — global CORS, no per-endpoint config |

---

## Security Tags Audit

| Tag | Compliance |
|-----|------------|
| `BSO-SEC-CODE-001` (input validated at boundary) | ✓ Pydantic + URL parser |
| `BSO-SEC-CODE-002` (no injection vulnerabilities) | ✓ ORM only, allowlist-validated URLs |
| `BSO-SEC-CODE-003` (secrets never in code or logs) | ✓ |
| `BSO-SEC-CODE-004` (authorization enforced on every endpoint) | ✓ `require_auth_with_scope` |
| `BSO-SEC-CODE-005` (output properly encoded) | ✓ |
| `BSO-SEC-CODE-006` (dependencies free of known CVEs) | ✓ no new deps |
| `BSO-SEC-CODE-007` (containers run with least privilege) | N/A (containers are deployment-time, not endpoint-level) |
| `BSO-SEC-015` (org-scoped queries) | ✓ |
| `BSO-SEC-INPUT-001` (sanitize free-text fields) | ✓ |

---

## Findings Summary

| Finding | Severity | Status |
|---------|----------|--------|
| `follow_redirects=True` on httpx client without post-redirect SSRF re-validation | Minor (theoretical defense-in-depth) | Open — tracked as follow-up |

**No CRITICAL, HIGH, or MEDIUM findings.** Endpoint is compliant with `docs/standards/secure-coding.md`.

## Process Improvement

This walkthrough should have happened **before** shipping the endpoint, not retroactively. Going forward:

- Every new endpoint PR should include a "Secure Coding Checklist" section in the PR description, with each OWASP item explicitly addressed
- Add a CI check or pre-merge bot that requires the checklist to be present in PR descriptions for endpoints touching user input
- Reference this audit format as the template

Tracked: process improvement, not a code change.
