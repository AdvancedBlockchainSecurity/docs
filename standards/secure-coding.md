# Secure Coding Standards

**Version:** 1.0.0
**Last Updated:** February 24, 2026
**Status:** Active

## Overview

All Apogee code MUST follow security-first development practices. Every line of code is written with the assumption that it will be attacked. Security is not a phase or an afterthought -- it is a mandatory property of every commit, PR, and deployment.

**Violations of these standards are considered CRITICAL and block merge.**

---

## Core Principle

> **No code ships with known vulnerabilities.** If a vulnerability is discovered during development, review, or testing, it MUST be fixed before merge. There are no exceptions.

---

## 1. OWASP Top 10 Prevention

All code MUST be hardened against the OWASP Top 10 vulnerabilities:

### A01: Broken Access Control

- Enforce authorization checks on every endpoint (not just authentication)
- Use `require_auth_with_scope()` for write endpoints (see [API Endpoint Auth](./api-endpoint-auth.md))
- Authorization MUST be enforced in SQL WHERE clauses, not Python filtering (BSO-SEC-015)
- Default deny: if no explicit permission grants access, deny it
- Validate that users can only access their own resources (IDOR prevention)

```python
# WRONG: Fetches resource without ownership check
@router.get("/scans/{scan_id}")
async def get_scan(scan_id: UUID, user=Depends(get_current_user)):
    return await db.get(Scan, scan_id)

# CORRECT: Ownership check in query
@router.get("/scans/{scan_id}")
async def get_scan(scan_id: UUID, user=Depends(get_current_user)):
    scan = await db.query(Scan).filter(
        Scan.id == scan_id,
        Scan.owner_id == user.id
    ).first()
    if not scan:
        raise HTTPException(status_code=404)
    return scan
```

### A02: Cryptographic Failures

- Use `secrets` module for token/key generation (never `random`)
- Hash passwords with bcrypt (cost factor >= 12)
- Use TLS for all service-to-service communication
- Never log secrets, tokens, API keys, or passwords
- Store secrets in Vault, never in Git (see [Secrets Management](./secrets-management.md))

### A03: Injection

- **SQL Injection**: Use parameterized queries or ORM (SQLAlchemy). Never concatenate user input into SQL strings
- **Command Injection**: Never pass user input to `subprocess`, `os.system`, or shell commands. Use allowlists for permitted values
- **XSS**: Sanitize all user-supplied content before rendering. Use framework auto-escaping (React JSX, Jinja2 autoescape)
- **Template Injection**: Never render user input as template code

```python
# WRONG: SQL injection
query = f"SELECT * FROM scans WHERE name = '{user_input}'"

# CORRECT: Parameterized query
query = select(Scan).where(Scan.name == user_input)
```

```python
# WRONG: Command injection
subprocess.run(f"scanner {user_input}", shell=True)

# CORRECT: Allowlist + no shell
ALLOWED_SCANNERS = frozenset({"slither", "aderyn", "semgrep"})
if scanner_name not in ALLOWED_SCANNERS:
    raise ValueError(f"Unknown scanner: {scanner_name}")
subprocess.run(["scanner", scanner_name], shell=False)
```

### A04: Insecure Design

- Validate all inputs at system boundaries (API endpoints, file uploads, webhook receivers)
- Use Pydantic models for request validation
- Enforce rate limiting on authentication and public endpoints
- Implement account lockout after repeated failed attempts

### A05: Security Misconfiguration

- No debug mode in production (`DEBUG=False`)
- Remove default credentials before deployment
- Disable unnecessary HTTP methods
- Set security headers: `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`
- CORS origins managed via ConfigMap, never hardcoded (see [Core Development Rules](./core-development-rules.md))

### A06: Vulnerable and Outdated Components

- Use latest stable versions of all dependencies (see [Dependency Management](./dependency-management.md))
- No deprecated or retired packages
- Run dependency audit monthly (`pip-audit`, `npm audit`)
- Pin dependency versions in lockfiles

### A07: Identification and Authentication Failures

- Use JWT with short expiration for session tokens
- Enforce strong password requirements
- API keys MUST be scoped (see [API Endpoint Auth](./api-endpoint-auth.md))
- Celery tasks use JSON serialization only -- never pickle (BSO-SEC-TASK-001)

### A08: Software and Data Integrity Failures

- Verify checksums on downloaded binaries and base images
- Use immutable Docker image tags (see [Docker Image Versioning](./docker-image-versioning.md))
- Validate webhook signatures before processing payloads
- Use signed commits in production branches

### A09: Security Logging and Monitoring Failures

- Log all authentication events (login, logout, failed attempts)
- Log authorization failures
- Sanitize error messages before logging (BSO-SEC-RES-001, BSO-SEC-RES-002)
- Never log sensitive data (passwords, tokens, PII)

### A10: Server-Side Request Forgery (SSRF)

- Validate and allowlist all outbound URLs
- Block requests to internal/private IP ranges from user-supplied URLs
- Use URL parsing libraries, never string matching, for validation

---

## 2. Input Validation Rules

All external input MUST be validated before use:

| Input Source | Validation Required |
|---|---|
| API request body | Pydantic model with field validators |
| Query parameters | Type-checked, range-validated |
| Path parameters | UUID format or allowlist |
| File uploads | Size limits, type validation, path traversal checks |
| Webhook payloads | Signature verification + schema validation |
| Environment variables | Validated at startup, fail fast on invalid values |

### Validation Principles

1. **Validate early**: At the system boundary, before any processing
2. **Fail closed**: Reject anything that doesn't match expected format
3. **Allowlist over denylist**: Define what IS allowed, not what ISN'T
4. **Validate on the server**: Never trust client-side validation alone

---

## 3. Output Encoding Rules

All output MUST be properly encoded for its context:

| Context | Encoding |
|---|---|
| HTML | Framework auto-escaping (React JSX, Jinja2) |
| JSON API responses | Standard JSON serialization (no raw HTML) |
| SQL | Parameterized queries (SQLAlchemy ORM) |
| Shell commands | Argument lists (no shell=True) |
| Log messages | Sanitized via `sanitize_error_message()` |
| URLs | `urllib.parse.quote()` |

---

## 4. Secrets and Sensitive Data

- Secrets MUST be stored in HashiCorp Vault (see [Secrets Management](./secrets-management.md))
- Never commit secrets to Git (`.env`, API keys, passwords, certificates)
- Use `.env.example` with placeholder values for documentation
- Rotate compromised secrets immediately
- API keys displayed to users MUST be masked after creation (show only last 4 characters)

---

## 5. Frontend Security

### React/TypeScript Applications

- Use `DOMPurify` for any user-generated HTML content
- Never use `dangerouslySetInnerHTML` with unsanitized input
- Validate URLs before rendering links or redirects (prevent javascript: protocol)
- Use `HttpOnly`, `Secure`, `SameSite=Strict` cookie flags
- Implement CSP (Content Security Policy) headers
- Sanitize error messages before displaying to users (no stack traces, internal paths)

```typescript
// WRONG: Unvalidated redirect
window.location.href = userProvidedUrl;

// CORRECT: Validate URL scheme
const url = new URL(userProvidedUrl);
if (!['https:', 'http:'].includes(url.protocol)) {
    throw new Error('Invalid URL');
}
```

---

## 6. API Security

- All endpoints MUST use HTTPS (TLS 1.2+)
- Authentication required on all endpoints except health checks
- Rate limiting on all public-facing endpoints
- Request size limits enforced
- Response bodies MUST NOT leak internal details (stack traces, file paths, SQL errors)
- Use correlation IDs for request tracing, not internal identifiers

---

## 7. Container and Infrastructure Security

- Run containers as non-root user
- Use read-only root filesystem where possible
- Set `securityContext` on all pods (see [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md))
- Apply NetworkPolicies for network isolation (default-deny)
- Scan images for vulnerabilities before deployment
- Use multi-stage Docker builds to minimize attack surface

---

## 8. Code Review Security Checklist

Before approving any PR, verify:

- [ ] No hardcoded secrets, tokens, or credentials
- [ ] All user input validated and sanitized
- [ ] SQL queries use parameterized statements or ORM
- [ ] No `shell=True` in subprocess calls
- [ ] No `eval()`, `exec()`, or dynamic code execution with user input
- [ ] Authentication and authorization enforced on new endpoints
- [ ] Error messages don't leak internal details
- [ ] Dependencies are up to date with no known CVEs
- [ ] File operations validate paths (no traversal)
- [ ] Logging doesn't include sensitive data
- [ ] CORS configuration is restrictive and correct

---

## 9. Security Tags Reference

| Tag | Description |
|---|---|
| `BSO-SEC-CODE-001` | All input validated at system boundary |
| `BSO-SEC-CODE-002` | No injection vulnerabilities (SQL, command, XSS) |
| `BSO-SEC-CODE-003` | Secrets never in code or logs |
| `BSO-SEC-CODE-004` | Authorization enforced on every endpoint |
| `BSO-SEC-CODE-005` | Output properly encoded for context |
| `BSO-SEC-CODE-006` | Dependencies free of known CVEs |
| `BSO-SEC-CODE-007` | Containers run with least privilege |

---

## Related Documentation

- [Security Standards](./security-standards.md) - Circuit breakers, archive extraction, task security
- [API Endpoint Authentication](./api-endpoint-auth.md) - Auth and scope enforcement
- [Secrets Management](./secrets-management.md) - Vault and secret handling
- [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md) - Security contexts and NetworkPolicies
- [Dependency Management](./dependency-management.md) - Keeping dependencies secure
- [Compliance Checklist](./compliance-checklist.md) - Daily compliance checks
