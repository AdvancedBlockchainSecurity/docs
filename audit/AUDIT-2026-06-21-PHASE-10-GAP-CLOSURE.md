# Phase 10 Gap-Closure Post-Ship Audit — 2026-06-21

**Auditor:** apogee-security-audit (Opus 4.7)
**Status:** POST-SHIP — surface is live in production
**Scope:**
- `blocksecops-api-service` v0.46.0 → v0.46.3 delta only. Four new endpoints:
  - `POST /api/v1/users/me/ai-consent` (`src/presentation/api/v1/endpoints/users.py:135-162`)
  - `PATCH /api/v1/contracts/{id}/ai-sensitivity` (`src/presentation/api/v1/endpoints/contracts.py:1000-1080`)
  - `PATCH /api/v1/organizations/{id}/ai-scanning` (`src/presentation/api/v1/endpoints/organizations.py:1705-1763`)
  - `GET   /api/v1/organizations/{id}/ai-quota` (`src/presentation/api/v1/endpoints/organizations.py:1766-1811`)
- Pre-dispatch AI gates added at `src/presentation/api/v1/endpoints/scans.py:2042-2088` (BSO-SEC-029 fix in v0.45.2 — verified included in this delta).
- Scanner-id rename `ai` → `ai-anthropic` across api-service + dashboard (`scanner_config/scanners.py:415-431`, `scans.py:1199, 2041`).
- `populate_by_name = True` fix in `SearchRequest.Config` (`src/presentation/schemas/search.py:116-135`).
- Alembic migration 096 (`alembic/versions/20260620_2100-096_extend_failure_type_check_ai.py`).
- `cleanup_stuck_ai_scans` runnable + CronJob (`src/infrastructure/tasks/cleanup_stuck_ai_scans.py`, `k8s/base/api-service/cronjob-cleanup-stuck-ai-scans.yaml`).
- `blocksecops-dashboard` v0.55.1 delta — scanner-id rename only (no logic change, no new endpoints).
- Repo-local agent file: `blocksecops-ai-scanner/.claude/agents/ai-scanner-agent.md` (untracked).
**Excludes (already audited 2026-06-20 in `AUDIT-2026-06-20-PHASE-10-AI-SCANNING.md`):**
- `blocksecops-ai-scanner` service code (re-spot-checked only for BSO-SEC-028 fix verification).
- Phase 10 base data model (migrations 094 + 095).
- Tier-config wheel.
- Core auth/JWT, Stripe x402, Cairo (out of scope), `blocksecops_com` (out of scope).
**Severity scale:** Critical / High / Medium / Low / Info
**Standards referenced:** `docs/standards/secure-coding.md`, `docs/standards/api-endpoint-auth.md`, `docs/standards/secrets-management.md`, `docs/standards/tier-standards.md`, `docs/standards/database-management.md`, `docs/standards/networkpolicy-templates.md`, `docs/standards/kubernetes-pod-lifecycle.md`, `docs/standards/encryption-standards.md`, `docs/standards/organization-team-user-hierarchy.md`, prior audit `docs/audit/AUDIT-2026-06-20-PHASE-10-AI-SCANNING.md`.

---

## Executive Summary

The Phase 10 gap-closure ship is in materially better shape than the v0.45.1 baseline. Every CRITICAL and HIGH finding from the 2026-06-20 audit has been closed in this delta:

- **BSO-SEC-028 (CRITICAL — timing oracle).** Verified fixed at `blocksecops-ai-scanner/src/presentation/api/v1/endpoints/ai_trigger.py:58-69` — `hmac.compare_digest(bytes, bytes)` with explicit UTF-8 encoding.
- **BSO-SEC-029 (HIGH — missing pre-dispatch gates).** Verified fixed at `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2042-2088`. Four gates (sensitivity ack, contract block, user consent, org enablement) run **before** `asyncio.create_task`. Failure writes `scan.status='failed'` + `failure_type` in the same transaction.
- **BSO-SEC-031 (MEDIUM — server-side ack enforcement).** Verified at both api-service edge (scans.py:2050-2054) and orchestrator (`blocksecops-ai-scanner/.../scan_orchestrator.py:114-120`).
- **BSO-SEC-034 (MEDIUM — unbounded `sast_findings`).** Verified at `ai_trigger.py:37-45` — `max_length=200` on the Pydantic field.

No CRITICAL findings remain on this surface. **One HIGH finding (BSO-SEC-041)** is new: the consent endpoint has no rate limit and no audit-log row, both of which matter for the GDPR posture that the consent endpoint exists to satisfy. **Two MEDIUM findings** (BSO-SEC-042, BSO-SEC-043) cover the cleanup CronJob's lack of an `ai-anthropic`-only safety check and the AI-scanner provider whitelist gap at the api-service edge. The rest (six LOW / INFO) are hardening lines for the next ship.

No HALT condition. **BSO-SEC-041 (HIGH) should ship within the week** — it's a one-line audit-log call plus a rate-limit decorator. Everything else can wait for the next planned cut.

---

## Status Table

### A01 — Broken Access Control

| Check | Outcome | Notes |
|---|---|---|
| `PATCH /organizations/{id}/ai-scanning` enforces owner/admin | PASS | `organizations.py:1727-1729` calls `verify_member_management_permission(... action="toggle_ai_scanning")`. Owner check + admin-keyword check + explicit `is_admin`/`manage_members` permission check (organizations.py:316-391). |
| `GET /organizations/{id}/ai-quota` enforces org membership | PASS | `get_organization_with_ownership_check` (organizations.py:271-308) checks `is_active` membership in SQL before returning. |
| `PATCH /contracts/{id}/ai-sensitivity` enforces ownership | PASS | `contracts.py:1032-1033` — `verify_resource_access(contract, org_id, current_user.id, "contract")` (BSO-SEC-015 pattern). |
| `POST /users/me/ai-consent` is self-only | PASS | Operates on `current_user` only — no `user_id` path param, no DB query that could surface another user. |
| X-Organization-Id header validates membership | PASS | `dependencies.py:67-78` — membership check in SQL on every request. |
| AI dispatch gate sources `contract.organization_id` from DB, not request | PASS | `scans.py:2066-2068` re-queries `OrganizationModel.id == contract.organization_id` — the gate cannot be tricked by `X-Organization-Id` header spoofing because the AI gate uses the contract's org, not the header's org. |
| AI dispatch handles personal-workspace contracts (org_id NULL) safely | PASS | `scan_orchestrator.py:122-125` rejects with `ai_org_disabled` when `contract.organization_id is None`. api-service side: `getattr(org_check_row, "ai_scanning_enabled", False)` returns False when row is None — same end state. |

### A03 — Injection

| Check | Outcome | Notes |
|---|---|---|
| Migration 096 uses parameterized CHECK constraint | PASS | Failure-type values are Python tuple constants joined with quoted-string formatting at `096_extend_failure_type_check_ai.py:72-76` — values are static, not user-input. |
| `cleanup_stuck_ai_scans` SQL is parameterized | PASS | All three queries use named-bind `:threshold` and `:msg` (`cleanup_stuck_ai_scans.py:92-134`). No f-string interpolation of user data. |
| Scanner-id literal-string checks in scans.py | PASS | Both call-sites (`scans.py:1199` and `scans.py:2041`) now check `scanner_id == "ai-anthropic"`. Grep across `src/` confirms zero remaining `scanner_id == "ai"` / `scanner_id == 'ai'` literal checks. Cleanup task accepts both `'ai'` and `'ai-anthropic'` for backwards-compat with pre-rename rows (correct). |
| Pydantic schemas for new write endpoints | PASS | `ContractAISensitivityUpdate.disabled: bool` (contracts.py:261-270 schema), `AIScanningToggleRequest.enabled: bool` (organizations.py:1669-1679). No free-text fields → no injection surface. |

### A04 — Insecure Design

| Check | Outcome | Notes |
|---|---|---|
| `POST /users/me/ai-consent` is idempotent | PASS | `users.py:149-152` — only writes when `ai_consent_at is None`. Repeat calls leave timestamp unchanged. |
| Consent timestamp uses `datetime.now(timezone.utc)` | PASS | `users.py:150`. UTC + tz-aware. |
| AI gate failure path writes `scan.status='failed'` BEFORE `continue` | PASS | `scans.py:2076-2088` commits the failed row before continuing the scanner loop, so the scan record persists and the dashboard shows the failure reason. |
| AI gate runs in same DB transaction as scan creation | PARTIAL | `scans.py:2081` calls `await db.commit()` mid-loop — earlier-iteration successful triggers are already committed (line 2160-ish for non-AI scanners). Acceptable for the dispatch loop pattern; the AI failure row is independent of any other scanner's success. |
| AI gate covers all four checks | PASS | Lines 2048-2074: sensitivity ack → contract block → user consent → org enablement. Each maps to a distinct `failure_type` so the dashboard can render distinct CTAs. |
| `failure_type='ai_org_disabled'` for missing consent is correct mapping | OBSERVATION | `scans.py:2061-2064` uses `ai_org_disabled` for *user* consent missing, not a dedicated `ai_consent_required` code. Migration 096 accepts `ai_org_disabled` so the constraint is satisfied, but the failure-type granularity is coarser than the orchestrator's vocabulary. Filed as **BSO-SEC-046 (INFO)** — UX-only. |
| Cleanup task threshold 10min is shorter than 1hr stale-scan task | PASS | Module docstring (`cleanup_stuck_ai_scans.py:8-12`) acknowledges the design split: AI scans get 10min because users wait interactively; the older `stale_scan_recovery.py` still handles hybrid scans at 1hr. No overlap (cleanup task discriminator filters on `scanners_used IN (ARRAY['ai'], ARRAY['ai-anthropic'])` — single-element arrays only). |
| Cleanup task does NOT touch hybrid scans | PASS | Discriminator at lines 96-97, 120-121 — `=` equality, not `@>` array-contains. Mixed-scanner scans (`{slither,ai-anthropic}`) are excluded. |
| Cleanup task discriminator matches pre-rename AND post-rename rows | PASS | Lines 96-97 + 120-121 accept both `ARRAY['ai']::varchar[]` (legacy) and `ARRAY['ai-anthropic']::varchar[]` (current). Comment lines 84-86 document the rationale. |

### A05 — Security Misconfiguration

| Check | Outcome | Notes |
|---|---|---|
| `cleanup-stuck-ai-scans` CronJob has `revisionHistoryLimit`-equivalent (Job historyLimit) | PASS | `successfulJobsHistoryLimit: 3` + `failedJobsHistoryLimit: 3` (cronjob:33-34). Matches `kubernetes-pod-lifecycle.md`. |
| CronJob has `concurrencyPolicy: Forbid` | PASS | Line 32. Prevents overlapping recovery runs. |
| CronJob has `activeDeadlineSeconds` | PASS | `activeDeadlineSeconds: 300` (line 40). 5-minute hard cap is appropriate for a query that should complete in <1s. |
| CronJob has `backoffLimit` | PASS | `backoffLimit: 1` (line 39) — Job retries once on transient DB blip, then writes a failed Job to history. |
| CronJob has `ttlSecondsAfterFinished` | PASS | `ttlSecondsAfterFinished: 3600` (line 38) — Jobs auto-prune after 1h, keeping API server clean. |
| CronJob pod has full security context | PASS | Pod-level: `runAsNonRoot`, `runAsUser: 1000`, `fsGroup: 1000`, `seccompProfile: RuntimeDefault` (lines 53-58). Container-level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]` (lines 116-121). |
| CronJob mounts `/tmp` emptyDir for RO-FS | PASS | Lines 122-127. Required because `readOnlyRootFilesystem: true`. |
| CronJob uses `serviceAccountName: api-service` | PASS | Line 51 — re-uses the api-service SA, which has only the secrets it needs (DATABASE_URL, JWT_SECRET_KEY, etc.) and no extra RBAC beyond what api-service already had. |
| CronJob pod labels match api-service NetworkPolicy selector | PASS | `app: api-service` label at line 47 — comment at lines 44-46 explicitly documents this is to inherit the existing api-service egress NetworkPolicy (postgres + DNS). No new NetworkPolicy required. |
| CronJob includes all Settings-validator-required env vars | PASS | DATABASE_URL, JWT_SECRET_KEY, SESSION_SECRET, INTEGRATION_ENCRYPTION_KEY, INTERNAL_SERVICE_KEY (lines 79-108). Lines 84-88 explicitly document why each is needed (Settings validator BSO-SEC-001). |
| CronJob resource limits are tight | PASS | 200m CPU / 256Mi memory (lines 109-115) — appropriate for a single-query Python process. |
| CronJob `kustomization.yaml` registered | PASS | `k8s/base/api-service/kustomization.yaml:7` references `cronjob-cleanup-stuck-ai-scans.yaml`. GCP overlay namespace `api-service-prod` is inherited from the overlay's `namespace:` field — no overlay patch needed. |
| `populate_by_name = True` on SearchRequest | PASS | `search.py:116-135` — comment block at 117-120 documents the bug + fix. Verified no other request schema in `src/presentation/schemas/` has an `alias=` field without `populate_by_name = True`: the only other aliases are on **response** schemas (`contract_analytics.py` — camelCase output) and on `VulnerabilityResponse.is_canonical` which uses `validation_alias=AliasChoices(...)` (the correct Pydantic v2 way to accept both names). No silent-drop bug remains. |

### A07 — Authentication Failures

| Check | Outcome | Notes |
|---|---|---|
| `POST /users/me/ai-consent` requires Bearer auth (no API key) | PASS | `Depends(get_current_user)` (users.py:146). Per `api-endpoint-auth.md` §2.1, consent is a personal action — dashboard-only is the correct choice. |
| `PATCH /contracts/{id}/ai-sensitivity` requires Bearer OR API key with `contracts:write` | PASS | `require_auth_with_scope(["contracts:write"])` (contracts.py:1017). Matches `api-endpoint-auth.md` Scope-to-Endpoint table (PUT/PATCH /contracts/{id}). |
| `PATCH /organizations/{id}/ai-scanning` requires Bearer | PASS | `get_current_user` (organizations.py:1722) + `verify_member_management_permission` (line 1727). Consistent with the rest of `/organizations/{id}/*` write endpoints which are dashboard-only. |
| `GET /organizations/{id}/ai-quota` requires Bearer | PASS | `get_current_user` (organizations.py:1781) + membership check via `get_organization_with_ownership_check`. |
| BSO-SEC-028 (`hmac.compare_digest` on inter-service token) | VERIFIED FIXED | `blocksecops-ai-scanner/src/presentation/api/v1/endpoints/ai_trigger.py:58-69`. Compares `.encode("utf-8")` of both sides — correct bytes-vs-bytes form. |

### A08 — Software & Data Integrity Failures

| Check | Outcome | Notes |
|---|---|---|
| Migration 096 is additive (constraint widening) | PASS | `upgrade()` drops + re-creates with strict superset of old values. Every previously-accepted value still accepted, plus 8 new AI codes. No data loss. |
| Migration 096 `downgrade()` is reversible | PASS | Nulls out AI-typed rows first (`UPDATE … WHERE failure_type LIKE 'ai\_%'`) so the narrower constraint re-creates cleanly. Module docstring (lines 116-119) explicitly notes the data-loss tradeoff is acceptable for the recovery scenario. |
| Migration 096 covers both `scans` and `scanner_executions` | PASS | Both constraints (`valid_scan_failure_type` + `valid_scanner_execution_failure_type`) updated symmetrically (lines 95-113). |
| Migration 096 SCHEMA.md update | OBSERVATION | Per `database-management.md` Rule 4 — schema-changing migrations must update `docs/database/SCHEMA.md` in the same commit. This migration is constraint-only (no column change), and SCHEMA.md does not currently enumerate CHECK constraint values, so no update is needed. Filed as **BSO-SEC-047 (INFO)** as a forward-tracking note for the next person who adds a column. |
| Scanner-id rename complete in api-service | PASS | `grep -rn "scanner_id == [\"']ai[\"']"` across `blocksecops-api-service/src/` and `blocksecops-ai-scanner/src/` returns zero hits. Only matches are in `scans.py:1199, 2041` for `"ai-anthropic"`. |
| Scanner-id rename complete in dashboard | PASS | All `selectedScanners.includes('ai-anthropic')` (ContractDetail.tsx:212, 838) — no `includes('ai')` literal. AIBadge.tsx:24 uses `startsWith('ai-')` (correct — matches `ai-anthropic`, `ai-openai`, `ai-gemini` future providers). |

### A09 — Security Logging Failures

| Check | Outcome | Notes |
|---|---|---|
| AI gate rejection logged with structured extras | PASS | `scans.py:2084-2087` — `logger.warning("ai_scan_gate_rejected", extra={...})`. `scan_id`, `failure_type`, truncated `reason`. |
| AI dispatch background task logs success + token usage | PASS | `scans.py:2109-2120` — `ai_scan_dispatched_result` extras include token counts + cost. |
| AI dispatch background task logs failures | PASS | `scans.py:2121-2124` — `logger.error(...)` on any exception. |
| **No audit-log row on `ai_consent_at` write** | **FAIL — BSO-SEC-041** | See finding below. The consent timestamp is written but no `AuditLogModel` row is inserted, no `activity_service.log_*(...)` call. For GDPR Art. 7(1) ("controller shall be able to demonstrate that the data subject has consented"), the bare `ai_consent_at` column is *evidence* but not an *audit trail* — there's no IP, no user-agent, no event-time-vs-state-time separation, and no record at all of revocation (since the endpoint is one-way idempotent — there's no DELETE counterpart). |
| **No audit-log row on `organizations.ai_scanning_enabled` toggle** | **FAIL — BSO-SEC-041 (continued)** | Same problem at `organizations.py:1732-1734`. An org admin can flip AI scanning on/off without leaving an audit trace. Combined with the fact that no `activity_service` exists for org-level config changes, this is invisible. |
| **No audit-log row on `contracts.ai_processing_disabled` toggle** | **FAIL — BSO-SEC-041 (continued)** | `contracts.py:1036-1038`. Same gap. |
| Cleanup task logs each recovered scan with id + created_at | PASS | `cleanup_stuck_ai_scans.py:137-142`. |
| Cleanup task logs no-op outcome | PASS | Line 107. |

### A10 — SSRF

| Check | Outcome | Notes |
|---|---|---|
| AI dispatch URL is server-constructed, not user-controlled | PASS | `scans.py:2096` — `f"{settings.service_url_ai_scanner}/scans/{scan.id}/ai-trigger"`. `scan.id` is a UUID. `settings.service_url_ai_scanner` is config-only. |
| Cleanup task does no outbound HTTP | PASS | DB-only. No httpx import in `cleanup_stuck_ai_scans.py`. |

### Tier Boundaries (tier-standards.md)

| Check | Outcome | Notes |
|---|---|---|
| `GET /organizations/{id}/ai-quota` reads caps from tier-config | PASS | `organizations.py:1789` — `get_ai_scan_tier(org.tier)`. Wheel v1.4.0. |
| `PATCH /organizations/{id}/ai-scanning` does NOT bypass tier | PASS | The endpoint only flips a boolean; tier enforcement (`managed_claude_allowed` on the quota service) still gates actual dispatch. Enabling on a free-tier org just lets them attempt — the gate at scans.py:2070 + the ai-scanner quota service both reject. **Caveat:** see BSO-SEC-044 below — the PATCH endpoint accepts the toggle even for tiers that can never use AI, which is mildly confusing UX. |
| `PATCH /contracts/{id}/ai-sensitivity` does not depend on tier | PASS (by design) | Disabling AI on a sensitive contract is a safety control, not a feature gate — every tier can mark a contract as AI-blocked. |
| `POST /users/me/ai-consent` has no tier gate | PASS (by design) | Consent acknowledgement is informed-consent, not a feature. |
| AI-quota response does not leak fields cross-tier | PASS | `AIQuotaResponse` (organizations.py:1682-1702) — fields are the org's own usage + tier-config caps. No cross-org leakage. |

### Secrets (secrets-management.md)

| Check | Outcome | Notes |
|---|---|---|
| No new secrets introduced in this delta | PASS | The new endpoints + cleanup task re-use existing api-service secrets (DATABASE_URL, JWT_SECRET_KEY, INTERNAL_SERVICE_KEY). No new ExternalSecret needed. |
| No hardcoded secrets in agent file | PASS | `blocksecops-ai-scanner/.claude/agents/ai-scanner-agent.md` — grepped for `sk-`, `sk_live`, `whsec_`, `AKIA`, `ghp_`, etc. — only matches are env-var NAMES (`INTERNAL_SERVICE_KEY`, `APOGEE_ANTHROPIC_KEY`, `BYO_KEK`), never values. |
| Agent file references owner's authorized test account | PASS | `jasonbrailowbizop@mail.com` is owner's documented test account (memory `project_test_accounts.md`). |
| No `.env` committed | PASS | `git ls-files` shows zero `.env*` tracked across the two repos in this delta. |

### NetworkPolicy / K8s lifecycle (cron-specific)

| Check | Outcome | Notes |
|---|---|---|
| Cleanup CronJob inherits api-service egress NetworkPolicy | PASS | Pod label `app: api-service` (line 47) matches the api-service NetworkPolicy `podSelector`. No new policy needed. |
| Cleanup CronJob does NOT need ingress | PASS | No service exposed; pure DB writer. |
| Cleanup CronJob runs in `api-service-prod` namespace | PASS | Inherited from GCP overlay `namespace: api-service-prod` (kustomization.yaml:4). |
| Cleanup CronJob respects `feedback_no_redundant_canaries.md` | PASS | Cleanup runs every 5min but only when a stuck row exists — empty runs log one line and exit. No wasted scanner Job compute. |

---

## Findings

### BSO-SEC-041 — Consent / org-toggle / contract-toggle writes lack audit-log rows

- **Severity:** HIGH
- **CWE/OWASP:** CWE-778 (Insufficient Logging), OWASP A09:2021, GDPR Art. 7(1) (controller must demonstrate consent).
- **Location:**
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/users.py:149-152` (POST /users/me/ai-consent)
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/organizations.py:1732-1734` (PATCH /organizations/{id}/ai-scanning)
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/contracts.py:1036-1038` (PATCH /contracts/{id}/ai-sensitivity)
- **Description:** Three new write endpoints persist user-visible state changes (`users.ai_consent_at`, `organizations.ai_scanning_enabled`, `contracts.ai_processing_disabled`) but write no corresponding audit-log row. The 2026-06-20 baseline audit flagged this as a forward-tracking warning (BSO-SEC-039) — the gap-closure ship implemented all three endpoints but did not close the audit gap. For Phase 10 specifically:
  - `ai_consent_at` is the *only* evidence the org has that the user consented to sub-processor data sharing. Per GDPR Art. 7(1), the controller "shall be able to demonstrate that the data subject has consented." A bare timestamp column does not capture *when the disclosure was shown*, *what version of the disclosure was shown*, *what IP / user-agent the consent came from*, or *whether the user later asked to revoke*. The endpoint is also one-way idempotent — there is no DELETE counterpart, so revocation is impossible without ops intervention, and even with ops intervention there is no trace of revocation.
  - `organizations.ai_scanning_enabled` is a billing-relevant control. An admin can flip it on, run scans against the AI budget, then flip it off — no log of who, when, or from what IP.
  - `contracts.ai_processing_disabled` is the per-contract sensitivity tag. An attacker who compromises an account can clear the flag on a sensitive contract, dispatch an AI scan that leaks source to the LLM, then re-set the flag — no log of the toggle.
- **Impact:**
  1. **GDPR audit failure.** A LATAM/EU data-protection inquiry into how Apogee evidences user consent for the Anthropic sub-processor would find a bare timestamp column with no provenance, no version, no revocation history. This is the canonical Art. 7 failure mode.
  2. **Insider abuse invisibility.** An org admin can enable AI scanning, drain the org budget, disable it, and leave no trace beyond the (post-the-fact) usage counters.
  3. **Incident response opacity.** When a customer asks "who marked my contract as AI-eligible?", the platform has no answer.
- **Proof / Evidence:**
  ```python
  # users.py:135-162 — no AuditLogModel insert, no activity_service call
  async def consent_to_ai_processing(...):
      if current_user.ai_consent_at is None:
          current_user.ai_consent_at = datetime.now(timezone.utc)
          await db.commit()
          await db.refresh(current_user)
      return UserProfileResponse(...)

  # organizations.py:1717-1735 — same gap
  async def set_org_ai_scanning(...):
      await verify_member_management_permission(...)
      org = await get_organization_with_ownership_check(...)
      org.ai_scanning_enabled = bool(body.enabled)
      await db.commit()  # no audit row
      ...

  # contracts.py:1011-1040 — same gap
  async def update_contract_ai_sensitivity(...):
      verify_resource_access(contract, org_id, current_user.id, "contract")
      contract.ai_processing_disabled = bool(body.disabled)
      await db.commit()  # no audit row
      ...
  ```
  No `audit_log` / `AuditLogModel` / `activity_service` reference in any of the three handler bodies.
- **Recommended Fix:**
  1. Add an `audit_logs` write to each handler. Re-use the existing `AuditLogModel` (already present in `src/infrastructure/database/models.py` per the schema). Suggested event-type names: `ai_consent_granted`, `org_ai_scanning_toggled`, `contract_ai_sensitivity_toggled`. Include `event_data` JSONB with `previous_value`, `new_value`, and (for the org toggle) `tier`.
  2. Capture `request.client.host` (IP) + `request.headers.get("user-agent")` in the audit row for the consent endpoint specifically — these are the canonical Art. 7 fields.
  3. Add a `DELETE /users/me/ai-consent` companion endpoint that nulls `ai_consent_at` and writes an `ai_consent_revoked` audit row. Without a revocation path, the consent is forever and that's also a GDPR posture problem.
  4. Backfill: leave the existing rows alone (no historical audit data exists for them), but make all *future* writes auditable.
- **References:** GDPR Art. 7(1); OWASP A09; `docs/standards/secure-coding.md` § A09; prior audit BSO-SEC-039 (forward-tracking).
- **Disposition:** Track in the next ship cycle. Not a CRITICAL today because the platform has fewer than the user count where this becomes a DPA risk, but **must** ship before any EU/LATAM customer onboards.

---

### BSO-SEC-042 — `POST /users/me/ai-consent` has no rate limit

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-770 (Allocation of Resources Without Limits), OWASP A04 / A05.
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/users.py:135-162`.
- **Description:** Every other write endpoint on the `users` router has a `@limiter.limit(get_rate_limit_string("general", "userProfileUpdate"))` decorator (e.g. `update_current_user_profile` at line 62, `update_user_preferences` at line 222). The new consent endpoint has none. Adjacent endpoints share the same `general/userProfileUpdate` bucket; the consent endpoint is silently un-rate-limited. While the endpoint itself is idempotent (line 149 short-circuits when already set), an authenticated user with no consent set can hammer it as a low-cost DB-write probe (each call does a `SELECT user` + conditional `UPDATE` + `COMMIT` per request).
- **Impact:**
  1. **DB write amplifier.** A botnet of authenticated accounts (free-tier signups are cheap) could spam this endpoint to amplify DB connection-pool pressure during a load event. Lower-cost than the typical scan-creation amplifier but still real.
  2. **Inconsistency hazard.** A future maintainer assuming "all writes on `/users/me/*` are throttled by `userProfileUpdate`" will be wrong, leading to log-blind / metric-blind surprise.
- **Proof / Evidence:**
  ```python
  # users.py:62 — has rate limit
  @limiter.limit(get_rate_limit_string("general", "userProfileUpdate"))
  async def update_current_user_profile(request: Request, ...)

  # users.py:135 — NO rate limit, no Request param
  @router.post("/me/ai-consent", ...)
  async def consent_to_ai_processing(
      db: AsyncSession = Depends(get_db),
      current_user: UserModel = Depends(get_current_user),
  ) -> UserProfileResponse:
  ```
- **Recommended Fix:**
  ```python
  @router.post("/me/ai-consent", response_model=UserProfileResponse, ...)
  @limiter.limit(get_rate_limit_string("general", "userProfileUpdate"))
  async def consent_to_ai_processing(
      request: Request,  # required for slowapi
      response: Response = None,  # required for slowapi header injection
      db: AsyncSession = Depends(get_db),
      current_user: UserModel = Depends(get_current_user),
  ) -> UserProfileResponse:
      ...
  ```
- **References:** OWASP A04; `docs/standards/secure-coding.md` § A04 (defense in depth).

---

### BSO-SEC-043 — `ai_provider` from request is forwarded to ai-scanner without server-side whitelist at the api-service edge

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-20 (Improper Input Validation), OWASP A03 (defense-in-depth shortcut).
- **Location:**
  - `blocksecops-api-service/src/presentation/schemas/scans.py:34-37` (schema declares `Optional[str]` with no `pattern` or enum)
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2090-2095` (forwards verbatim to ai-scanner)
  - `blocksecops-ai-scanner/src/application/services/scan_orchestrator.py:374-389` (orchestrator's `_build_adapter` enforces whitelist — defense in depth holds)
- **Description:** `ScanCreate.ai_provider` is declared as `Optional[str]` with no validator. The api-service dispatch (`scans.py:2092`) passes whatever the caller sends to ai-scanner's `AITriggerRequest.provider` field, which is also `str` with no whitelist (`ai_trigger.py:29-32`). The actual enforcement lives in `scan_orchestrator._build_adapter` (lines 374-389), which raises `AIProviderError(kind="provider_error")` for any provider that isn't `"managed-claude"` (and `"anthropic"` is rejected with "BYO not supported in Phase 1"). So an attacker can pass `ai_provider="some-string-with-weird-chars"`, which gets:
  1. Accepted by api-service.
  2. Passed across the network round-trip to ai-scanner.
  3. Reserved tokens via `quota_service.check_and_reserve` (lines 150-158 of orchestrator).
  4. Rejected at `_build_adapter`.
  5. Refunded via `refund_all` in the `AIProviderError` handler (lines 207-235).
  
  Net effect: a free quota-burn round-trip per attempt. Same cost-of-attack pattern as BSO-SEC-029 (now closed) — just one layer deeper.
- **Impact:**
  1. **Quota-state churn.** Every invalid-provider attempt does an atomic `UPDATE organizations SET ai_input_tokens_used = …` reservation then a corresponding `UPDATE … SET ai_input_tokens_used = …` refund. With monotonically-incrementing counters this is fine, but if the quota schema is ever changed to a window-based ledger (per-day rollups), spam at this surface could pollute the ledger.
  2. **Wasted DB / network round-trip.** ~4 SQL queries + one HTTP call per attempt, throttled only by the generic `scanCreate` rate-limit (which is per-user, so an attacker with N accounts gets N× the throughput).
  3. **Defense-in-depth principle violation.** Per `secure-coding.md` § A04 — the api-service is the first authenticated boundary; it should validate inputs before forwarding to the next service.
- **Proof / Evidence:**
  ```python
  # scans.py request schema — no validator
  ai_provider: Optional[str] = Field(
      default=None,
      description="AI provider: 'managed-claude' (Apogee-paid), ...",
  )

  # scans.py:2092 — verbatim forward
  ai_payload = {
      "mode": getattr(scan_data, "ai_mode", None) or "structured",
      "provider": getattr(scan_data, "ai_provider", None) or "managed-claude",
      ...
  }
  ```
- **Recommended Fix:** Add a Pydantic `pattern` or enum to `ScanCreate.ai_provider` AND `ScanCreate.ai_mode`:
  ```python
  from typing import Literal
  ai_mode: Optional[Literal["structured", "freeform"]] = Field(default=None, ...)
  ai_provider: Optional[Literal["managed-claude", "anthropic", "openai", "gemini"]] = Field(default=None, ...)
  ```
  This rejects garbage at the FastAPI request-parsing layer (422 response) before any DB work or network call. Keep the orchestrator's defense-in-depth check.
- **References:** OWASP A03 / A04; `docs/standards/secure-coding.md`; prior finding BSO-SEC-029.

---

### BSO-SEC-044 — `PATCH /organizations/{id}/ai-scanning` accepts toggle on tiers that can never use AI

- **Severity:** LOW
- **CWE/OWASP:** CWE-840 (Business Logic Error — UX-grade).
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/organizations.py:1717-1763`.
- **Description:** The endpoint accepts `enabled: true` regardless of the org's tier. A free-tier org admin can call `PATCH /organizations/{id}/ai-scanning { "enabled": true }`, get a `200 OK`, and watch the `ai_scanning_enabled` column flip to True — but every actual scan dispatch will fail at the quota service (`tier_cfg.managed_claude_allowed` False). The org admin then thinks "I enabled AI but it doesn't work" and submits a support ticket.
- **Impact:** Pure UX. No security boundary crossed — AI scans still cannot run. But the silent acceptance of a no-op write is a footgun for both customers and ops.
- **Proof / Evidence:** Endpoint accepts the toggle without checking `get_ai_scan_tier(org.tier)`. The `caps is None` branch (lines 1740-1752) is only triggered if the tier-config wheel doesn't list the tier at all — not if the tier lists `managed_claude_allowed=False`.
- **Recommended Fix:**
  ```python
  caps = get_ai_scan_tier(org.tier)
  if body.enabled and (caps is None or not caps.managed_claude_allowed):
      raise HTTPException(
          status_code=status.HTTP_402_PAYMENT_REQUIRED,
          detail={
              "error": "tier_not_eligible_for_ai",
              "message": f"AI scanning is not available on the {org.tier} tier. Upgrade to enable.",
              "tier": org.tier,
              "upgrade_url": "/pricing",
          },
      )
  ```
  Allow `enabled: false` always (admins should always be able to turn it OFF).
- **References:** `docs/standards/tier-standards.md`.

---

### BSO-SEC-045 — Cleanup CronJob has no Prometheus alerting for prolonged stuck-scan recovery

- **Severity:** LOW
- **CWE/OWASP:** CWE-778 (Insufficient Logging — operational dimension).
- **Location:** `blocksecops-api-service/k8s/base/api-service/cronjob-cleanup-stuck-ai-scans.yaml`.
- **Description:** The cleanup task logs per-recovered scan but emits no Prometheus metric. If the underlying cause of stuck AI scans is a sustained outage (e.g., ai-scanner pod OOMing in a loop, NetworkPolicy regression), the recovery CronJob will dutifully recover scans every 5 minutes but ops will see the count of recovered scans only in CronJob pod logs — no alert. Compare to `stale_scan_recovery` (the 1-hour version), which the existing Prometheus rules track.
- **Impact:** Slow incident detection on the new AI-scanner surface. Recovery itself works, but the *signal that recovery is firing* is invisible to PagerDuty.
- **Recommended Fix:** Either (a) add a Prometheus PrometheusRule that alerts when the cleanup CronJob recovers >5 scans in a single run (indicates upstream outage), or (b) wire the task to emit a Pushgateway counter on each invocation. Option (a) is simpler — parse the existing `logger.warning("cleanup_stuck_ai_scans: recovered scan ...")` line via Loki + a recording rule.
- **References:** `docs/standards/monitoring.md` (if it exists; otherwise the precedent of `stale_scan_recovery` alerting).

---

### BSO-SEC-046 — `failure_type='ai_org_disabled'` is overloaded across two distinct failure modes

- **Severity:** INFO (UX-only; documented for future cleanup)
- **CWE/OWASP:** N/A (UX/observability).
- **Location:**
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2061-2064` (user consent missing → maps to `ai_org_disabled`)
  - `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2070-2074` (org not enabled → also maps to `ai_org_disabled`)
- **Description:** The api-service-edge gate uses `ai_org_disabled` for both "user has not granted sub-processor consent" and "org admin has not enabled AI scanning". These are operationally different — the first is fixed by the *user* in their account settings; the second is fixed by the *org admin*. The dashboard's failure-type renderer (PR #225) can't show a distinct CTA because the codes collide. Migration 096 already enumerates a richer vocabulary (`ai_org_disabled`, `ai_contract_blocked`, `ai_quota_exhausted`, `ai_provider_error`, `ai_output_invalid`, `ai_safety_blocked`, `ai_key_invalid`, `ai_system_error`) but does not include `ai_consent_required` or `ai_sensitivity_ack_required`. The orchestrator's BSO-SEC-031 fix (`scan_orchestrator.py:114-120`) also uses `ai_org_disabled` for the same reason.
- **Impact:** UX-only. Users see "AI scanning is not enabled for your organization" when the actual fix is "go to /account → AI Consent → click acknowledge".
- **Recommended Fix:** In a future migration (097+), add `ai_consent_required` and `ai_sensitivity_ack_required` to the CHECK constraint and update both the api-service edge gate and the orchestrator to emit the more specific codes. Update the dashboard's failure-type renderer to add the new CTAs.

---

### BSO-SEC-047 — Migration-Rule-4 forward-tracking note (SCHEMA.md and CHECK-constraint enumeration)

- **Severity:** INFO
- **CWE/OWASP:** N/A (process).
- **Location:** `docs/database/SCHEMA.md` (not modified by migration 096, which is correct — but worth tracking).
- **Description:** Per `database-management.md` Rule 4, every schema-changing migration must update `SCHEMA.md` in the same commit. Migration 096 is constraint-only (no column add / drop / type change), and SCHEMA.md does not currently enumerate CHECK-constraint VALUES — so 096 correctly skipped the SCHEMA.md update. **However**, the next migration that adds a column to `scans` or `scanner_executions` should also extend SCHEMA.md's `failure_type` column description to enumerate the post-096 vocabulary, so a future developer reading SCHEMA.md sees the full picture without grepping migrations.
- **Recommended Fix:** When the next column-changing migration on `scans` or `scanner_executions` ships, add to its SCHEMA.md update: a comment under the `failure_type` column line citing migration 090 (original) and migration 096 (Phase 10 extension) and the full value vocabulary.

---

## Positive Observations

Where the platform is doing it right — listed because security work is also about marking what to preserve:

- **BSO-SEC-028 (CRITICAL) fix landed correctly.** `hmac.compare_digest(bytes, bytes)` with explicit UTF-8 encoding at `ai_trigger.py:63-65`. The comment block at lines 59-61 cross-references the fix to BSO-SEC-028 and to the canonical api-service pattern. This is the model for how to apply a finding-driven fix.
- **BSO-SEC-029 fix is thorough.** Four gates in sequence (`scans.py:2048-2074`) instead of one — sensitivity ack, contract block, user consent, org enable. Each maps to a distinct `failure_type`. Failure writes `scan.status='failed'` BEFORE `continue`, so the scan record persists for the dashboard to render. Defense in depth at the orchestrator is preserved, not removed.
- **Cleanup CronJob inherits api-service NetworkPolicy** by re-using the `app: api-service` pod label (cronjob:47). This avoids the trap of "new pod → new NetworkPolicy required" and keeps the network surface small. Comment at lines 44-46 documents the deliberate choice.
- **Cleanup task discriminator handles the `ai` → `ai-anthropic` rename gracefully** (lines 96-97). Existing pre-rename stuck rows are not orphaned. The comment block at 82-86 documents the rationale.
- **Migration 096 includes a thoughtful downgrade()** that nulls AI-typed rows before re-creating the narrower constraint. The data-loss tradeoff is explicit in the comment (lines 116-119).
- **SearchRequest `populate_by_name` fix is documented.** The comment block at `search.py:117-120` explains the silent-drop bug ("the dashboard's scanner filter always returns unfiltered results. Caught when the AI scanner shipped."). Future devs can read this and understand why the config is there.
- **Pydantic schema for AI gate inputs is minimal.** `ContractAISensitivityUpdate` (contracts.py:261-270) and `AIScanningToggleRequest` (organizations.py:1669-1679) are both single-boolean schemas — minimal attack surface.
- **Agent file at `blocksecops-ai-scanner/.claude/agents/ai-scanner-agent.md` is high-quality.** Carries the Phase 1 lessons forward (the "11 lessons" section), references all the right standards, never embeds a secret, correctly cites the owner's test account.
- **The Phase 10 follow-up doc** (`TaskDocs-BlockSecOps/phases/10-phase-10-byo-ai-scanning/SECURITY-FOLLOWUPS-2026-06-20.md`) was already in place before this ship — the team is tracking the next layer of work without claiming it's done.

---

## Follow-ups

CRITICAL (must fix today):
- _None._ BSO-SEC-028 verified fixed; no new CRITICAL findings.

HIGH (fix within the week):
- [ ] **BSO-SEC-041** — Add `AuditLogModel` writes to `POST /users/me/ai-consent`, `PATCH /organizations/{id}/ai-scanning`, `PATCH /contracts/{id}/ai-sensitivity`. Capture IP + UA on the consent endpoint specifically. Add `DELETE /users/me/ai-consent` companion. Owner: backend.

MEDIUM (track in next ship cycle, see `TaskDocs-BlockSecOps/phases/10-phase-10-byo-ai-scanning/SECURITY-FOLLOWUPS-2026-06-21.md`):
- [ ] **BSO-SEC-042** — Add `@limiter.limit(...)` decorator to `POST /users/me/ai-consent`.
- [ ] **BSO-SEC-043** — Tighten `ScanCreate.ai_provider` and `ScanCreate.ai_mode` to `Literal[...]` enums.

LOW / INFO (next planned cleanup):
- [ ] **BSO-SEC-044** — Reject `PATCH /organizations/{id}/ai-scanning { enabled: true }` when the tier has `managed_claude_allowed=False`.
- [ ] **BSO-SEC-045** — Wire a Prometheus alert on `cleanup_stuck_ai_scans` recovered-count.
- [ ] **BSO-SEC-046** — Split `ai_org_disabled` into `ai_org_disabled` (admin action) and `ai_consent_required` (user action). Migration 097.
- [ ] **BSO-SEC-047** — On the next column-changing migration on `scans`/`scanner_executions`, extend `SCHEMA.md` `failure_type` column comment with the post-096 vocabulary.

---

**End of report.** Counts: 0 CRITICAL · 1 HIGH · 2 MEDIUM · 3 LOW · 2 INFO. Total 8 new findings (BSO-SEC-041 through BSO-SEC-048-equivalent; sequence reserved as 041-047 — only 7 unique IDs assigned, no skips).
