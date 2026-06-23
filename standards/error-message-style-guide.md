# Customer-Facing Error Message Style Guide

**Part of:** [Platform Development Standards](./INDEX.md)
**Version:** 1.0.0
**Last Updated:** 2026-06-22
**Status:** Active
**Owners:** api-service team + dashboard team

## Purpose

When a customer hits an error, they need to know **what went wrong** and **what to do next**. Generic messages like *"Tool-integration service may be unavailable"* (when tool-integration is fine) or *"Not authorized"* (with no context) fail both criteria — they look like a bug, not a recoverable state, and leave the caller without a path forward.

This guide codifies the patterns we use across the platform so error messages are consistent, actionable, and trustworthy.

## The five rules

### 1. Name what went wrong specifically

The message must identify the actual rejection or failure mode — not the most-generic fallback.

| Anti-pattern | Pattern |
|---|---|
| `Failed to trigger any scanners. Tool-integration service may be unavailable.` | `AI scans require explicit sub-processor consent. Set ai_sensitivity_acknowledged=true on the scan request.` |
| `Not authorized` | `Not authorized to scan this contract. It belongs to a different organization than your current one — switch to that organization via the X-Organization-Id header or ask an org admin to grant access.` |
| `Contract not found` | `Contract 49ed4672-... (linked to scan e764da1d-...) not found. It may have been deleted while this scan was pending. Re-upload the contract to re-run the scan.` |

**Reference incident:** [ADV-16](https://linear.app/advanced-blockchain-security/issue/ADV-16) — generic "tool-integration unavailable" 503 was returned for AI consent gate rejections.

### 2. Tell the caller what to do next

Every error should suggest a concrete next action: a header to set, a value to add, a different endpoint, or an explicit "contact support with X" path. If there's no action the caller can take, the error is probably a 500 — say so and tell them what to do.

| Anti-pattern | Pattern |
|---|---|
| `User quota not found. Please contact support.` | `User quota record missing. Try signing out and back in. If this persists, contact support@0xapogee.com with user-prefix=66f28736 so we can rebuild your quota row.` |
| `Method not allowed` (no follow-up) | `This endpoint only accepts GET. Did you mean POST /api/v1/scans?` |

### 3. Be honest about who/what is unavailable

If the cause is genuinely infra (timeout, connect error, unhandled exception), say so. If the cause is the caller's input or state, say THAT. Do not default to "infra is down" — that erodes trust when infra is actually fine.

| Status code | When |
|---|---|
| `4xx` | Caller can fix by changing input (tier, consent, payload, headers, contract state) |
| `503` | Genuine infra failure — tool-integration timeout, ai-scanner unreachable, database lock |
| `500` | Unexpected — log full context, return safe summary, point to support |

**Reference pattern:** the `failure_details` map in `scans.py:create_scan` ([ADV-16](https://linear.app/advanced-blockchain-security/issue/ADV-16)). Per-scanner metadata is collected at each reject point; the final response chooses 4xx or 503 based on whether every failure is caller-fixable.

### 4. Avoid silent empty results

A list endpoint that returns `{"total": 0, "items": []}` when there ARE rows is the worst case — the caller sees "no data" and stops looking. Either:

- Return the rows and let the caller filter
- Return a structured response that explains why rows are excluded
- Document the default filter loudly in the OpenAPI description

**Reference incident:** [ADV-17](https://linear.app/advanced-blockchain-security/issue/ADV-17) — `/scans/{id}/vulnerabilities` defaulted `include_duplicates=False`, returning empty when cross-scan dedup had flipped every row to `is_primary=False`. Fix: flip the default; the per-scan endpoint should return all of that scan's findings by default.

### 5. Don't leak more than the endpoint already leaks

For authorization failures, info-disclosure matters. The general rule:

- If existence is already disclosed by a 404 path elsewhere (e.g. `Contract X not found`), the 403 message CAN say "belongs to a different organization" — adds no new disclosure
- If existence is NOT disclosed (e.g. the endpoint never reveals 404), keep the 403 generic
- Never name the actual owning user/org in the message; "a different user" or "a different organization" is fine

## Concrete patterns from the platform

### Tier-gate rejection

```python
elif get_ai_scan_tier(getattr(current_user, "tier", None)) is None:
    ai_gate_failure = (
        "ai_tier_gated",
        "AI scanning requires Starter tier or higher. Upgrade your plan to enable ai-anthropic.",
    )
```

`failure_type` is a machine-readable enum the dashboard can switch on; the message is the human copy.

### Quota exhausted (structured detail)

```python
raise HTTPException(
    status_code=status.HTTP_402_PAYMENT_REQUIRED,
    detail={
        "error": "quota_exceeded",
        "message": f"Monthly scan limit reached ({user_quota.monthly_scan_limit} scans). Upgrade your plan or wait for reset.",
        "tier": user_quota.tier,
        "scans_used": user_quota.monthly_scans_used,
        "scan_limit": user_quota.monthly_scan_limit,
        "scans_remaining": 0,
    },
)
```

Best-in-class: machine-readable error code + human message + numeric context + tier info. The dashboard renders an upgrade banner with the right tier highlighted.

### Authorization with context

```python
if contract.organization_id != org_id:
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail=(
            "Not authorized to scan this contract. It belongs to a "
            "different organization than your current one — switch "
            "to that organization via the X-Organization-Id header "
            "or ask an org admin to grant access."
        ),
    )
```

### Internal error with support handoff

```python
if not user_quota:
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail=(
            "User quota record missing. Try signing out and back in. "
            "If this persists, contact support@0xapogee.com with "
            f"user-prefix={str(current_user.id)[:8]} so we can "
            "rebuild your quota row."
        ),
    )
```

Eight-char prefix is enough to triage without leaking the full UUID.

## Anti-patterns to refuse in code review

- `"Internal server error"` — what kind? Bubble the safe summary up.
- `"Bad request"` — which field? What value would have been valid?
- `"Not authorized"` (no follow-up) — auth to what? On whose behalf?
- `"X service unavailable"` when X is fine — diagnose first, message accordingly.
- `f"Foo {bar}"` with no interpolation (the f-prefix is a typo) — the f-prefix is a load-bearing artifact; lint for it.
- Wrapping every exception in `get_safe_error_detail(e, "doing thing")` then returning the same opaque "Error doing thing" — `get_safe_error_detail` is for SAFE summarization of unexpected errors; expected error paths should have specific messages.
- Returning `{"detail": "Failed"}` when you have the actual failure_type in scope — pass it through (structured dict detail OR specific text).

## How to test error messages

**Source-inspection tests** (preferred for endpoint-string regressions):

```python
def test_quota_not_found_message_includes_support_handoff(scans_src):
    """The 500 quota-not-found message must give the caller an
    actionable path (sign out, then support contact). ADV-18."""
    assert "support@0xapogee.com" in scans_src
    assert "user-prefix=" in scans_src
```

**Integration tests** (when the message depends on runtime state):

```python
async def test_ai_scan_without_consent_returns_specific_message(client, user):
    resp = await client.post("/scans", json={
        "contract_id": str(uuid4()),
        "scanner_ids": ["ai-anthropic"],
    })
    assert resp.status_code == 400
    assert "ai_sensitivity_acknowledged=true" in resp.json()["detail"]
```

The structural tests catch a refactor that silently reverts; the integration tests catch the wiring. Both are cheap — write both.

## Logging discipline (companion to the user-facing message)

Every user-facing error message should have a matching structured log line so ops can correlate:

```python
logger.warning(
    "ai_scan_gate_rejected",
    extra={
        "scan_id": str(scan.id),
        "scanner_id": scanner_id,
        "failure_type": ft,
        "reason": msg[:200],
    },
)
```

The log message identifier (`ai_scan_gate_rejected`) is a stable string for log queries; the `extra` dict carries the per-event context. Don't put PII in the log; redact emails to first-letter+domain if needed.

## Related standards

- [Secure Coding Standards](./secure-coding.md) — error handling section (no stack traces, no SQL errors in responses)
- [API Endpoint Authentication](./api-endpoint-auth.md) — 403 vs 404 disclosure rules
- [BSO-SEC-LOG-003](../audit/) — `get_safe_error_detail` for safe error summarization

## Reference incidents

- **[ADV-16](https://linear.app/advanced-blockchain-security/issue/ADV-16)** (2026-06-22) — ai-anthropic dispatch returned "Tool-integration may be unavailable" when the actual cause was the AI consent gate. Fixed in api-service v0.46.6 with `failure_details` map.
- **[ADV-17](https://linear.app/advanced-blockchain-security/issue/ADV-17)** (2026-06-22) — `/scans/{id}/vulnerabilities` returned empty when scan counts > 0 because of a silent default-filter on `is_primary`. Fixed in v0.46.7.
- **[ADV-18](https://linear.app/advanced-blockchain-security/issue/ADV-18)** (2026-06-22) — broader sweep that this standard codifies. scans.py is the first endpoint cleaned up; follow-up tickets cover other endpoint files + dashboard side.

## Open follow-ups (tracked under ADV-18)

- Sweep `contracts.py`, `vulnerabilities.py`, `auth*.py`, `admin/*.py` for the same patterns
- Dashboard surfacing of scanner-level failure reasons (consume `scan.failure_type` and `failure_details` on render)
- Lint rule for `f"..."` strings with no `{}` interpolation
