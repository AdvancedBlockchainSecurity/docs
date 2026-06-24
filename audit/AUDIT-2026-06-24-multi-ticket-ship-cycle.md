# Security audit — 2026-06-24 multi-ticket ship cycle

**Scope**: 5 PRs across 4 repos closing ADV-20, ADV-21, ADV-22, ADV-24, ADV-25.
**Date**: 2026-06-24
**Reviewer**: ship-cycle Phase 2

## Audited diffs

| Ticket | Repo | Branch / PR | Surface |
|---|---|---|---|
| ADV-25 | docs | `docs/stale-fixes-ai-scanner-tier-20260623` / [#490](https://github.com/AdvancedBlockchainSecurity/docs/pull/490) | Markdown only |
| ADV-22 | api-service | `chore/adv-22-ruff-f541-lint` / [#390](https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service/pull/390) | `pyproject.toml` + lint cleanup |
| ADV-20 | api-service | `feat/adv-20-endpoint-message-sweep` / [#391](https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service/pull/391) | HTTPException message strings |
| ADV-21 | dashboard | `feat/adv-21-scanner-failure-type-ui` / [#234](https://github.com/AdvancedBlockchainSecurity/blocksecops-dashboard/pull/234) | React component + TS types |
| ADV-24 | 0xapogee_com | `feat/favicon-4point-star` / [#58](https://github.com/AdvancedBlockchainSecurity/0xapogee_com/pull/58) | Static SVG |

## Findings

### 1. Secrets — PASS
`git diff` across all 4 code PRs filtered for `password|secret|token|api[_-]?key|sk_live|sk_test|sk-ant-`: no matches in newly added lines (false positives in pre-existing imports filtered).

No `.env` files staged in any branch (verified via `git status` on each).

### 2. Input validation — PASS (N/A)
No new user-facing inputs introduced. ADV-20 only modifies existing HTTPException string contents. ADV-21 renders data already validated server-side. ADV-22 + ADV-25 are config / docs only.

### 3. Auth boundaries — PASS (N/A)
No new endpoints. No `require_auth_with_scope()` removed or relaxed. All 3 `vulnerabilities.py` 403 sites in ADV-20 retain their existing tier + org-scope authorization logic; only the user-facing message is rewritten.

### 4. XSS / injection — PASS
- Dashboard ADV-21: All scanner failure data rendered via `{scannerId}` / `{badgeText}` JSX expressions. React auto-escapes. No `dangerouslySetInnerHTML`, no `innerHTML`, no `eval`, no `new Function`.
- API ADV-20: HTTPException `detail=(...)` strings interpolate only `contract_id` / `vuln_id` UUIDs (validated by Pydantic at the route layer). 8-char prefix per ADV-18 rule #5 — no full UUID leakage.

### 5. Supply chain — PASS
No new `npm` / `pip` / `cargo` dependencies added.

### 6. External URLs — PASS
No new `fetch()` calls. Only string content changes in existing endpoint handlers.

### 7. Implicit/explicit consent gates — PASS (N/A)
No changes to consent enforcement (BSO-SEC-031). ADV-16's existing `ai_consent_missing` failure type is now properly surfaced in the dashboard label map (improvement, not a regression).

### 8. Inter-service auth — PASS (N/A)
No changes to HMAC token paths (BSO-SEC-028).

### 9. Dynamic registry anti-pattern — PASS
- `scanFailureLabels.ts` (ADV-21) is a hardcoded enum-to-label map. **This is intentional** — UI labels are i18n-style display strings, not platform configuration. The enum itself is owned by api-service; the dashboard map mirrors it. Same pattern as existing `scanStatusLabels.ts`.

### 10. Favicon SVG — PASS
`public/favicon.svg`: 29 lines, no `<script>`, no event handlers (`onload` / `onerror`), no `javascript:` protocol references. Pure path + gradient definitions.

## Verdict

**PASS** — all 5 PRs cleared. No FAIL, no WARN.

## BSO-SEC sequence

No new findings discovered. Continues from BSO-SEC-056 (credential exposure public mirror, 2026-06-21).

## Closure references

- ADV-25 PR #490 — documentation only, no security surface
- ADV-22 PR #390 — lint guard against an entire class of bugs (F541), defensive
- ADV-20 PR #391 — message clarity improvement, no auth/behavior change
- ADV-21 PR #234 — auto-escaped UI rendering, dependent on api-service v0.46.6+ data
- ADV-24 PR #58 — static asset, sanitized SVG
