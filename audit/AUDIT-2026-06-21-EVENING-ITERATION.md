# Phase 2 Security Audit — 2026-06-21 (Evening Iteration Delta)

**Auditor:** apogee-security-audit
**Scope (delta only):**
- `blocksecops-ai-scanner` v0.2.7 — multi-file source loader in
  `src/application/services/scan_orchestrator.py` and the supporting
  `src/guardrails/prompt_injection.py` + `src/guardrails/output_validator.py`.
- `blocksecops-dashboard` v0.55.2 / v0.55.3 / v0.55.4 — independent AI
  section in `ScannerSelector.tsx`, dynamic scanner catalog in
  `BatchScanModal.tsx` and `pages/BatchScan.tsx`, implicit-consent send
  in `pages/ContractDetail.tsx`.
- `blocksecops-api-service` — only the AI dispatch + batch skip slices
  in `src/presentation/api/v1/endpoints/scans.py` (lines ~1180-1230 and
  ~2040-2130) that the dashboard changes interact with.
- User-local skill file `~/.claude/skills/apogee-assistant.md`.
- Out of scope: everything covered by `AUDIT-2026-06-21-PHASE-10-GAP-CLOSURE.md`
  (the full-platform audit earlier today). Last finding ID in baseline: BSO-SEC-047.
**Standards referenced:** `docs/standards/secure-coding.md` (A03/A04/A07),
`docs/standards/api-endpoint-auth.md`, `docs/standards/secrets-management.md`,
`feedback_trigger_scans_via_api.md`, `feedback_no_env_commits.md`,
`feedback_no_auto_scan_on_sync.md`.
**Severity scale:** Critical / High / Medium / Low / Info

## Executive Summary

The evening iteration is mostly clean. The multi-file AI source loader
is well-bounded by the existing `per_scan_input_token_cap` quota gate,
prompt-injection fences continue to escape user-controlled `file_path`
attributes correctly, and the dashboard's implicit-consent change is
gated client-side so `ai_sensitivity_acknowledged=true` is only sent
when AI is actually selected. The backend BSO-SEC-031 server-side
sensitivity gate still rejects `false`, so direct-API callers cannot
bypass via the same field.

One HIGH severity finding sits outside the platform repos: the
user-local `apogee-assistant` Claude Code skill embeds the live test
account password in plaintext, violating the standing
`feedback_trigger_scans_via_api.md` rule that the password is
session-only. Two MEDIUM forward-compat findings cover hardcoded
`ai-anthropic` literals that will mis-route Phase 2's `ai-openai` /
`ai-gemini` scanners. Three LOW findings cover multi-file path
normalization, missing uniqueness on `contract_files(contract_id, file_path)`,
and a small CDATA-fence over-aggressive escape.

**Severity counts:** 0 Critical / 1 High / 2 Medium / 3 Low / 1 Info
(7 findings, BSO-SEC-048 through BSO-SEC-054)

**Must-fix-now (any Critical or High):**
- BSO-SEC-048 — Remove plaintext `TestPass123` from
  `~/.claude/skills/apogee-assistant.md` line 11. Owner-local fix, not
  a deploy.

---

## Findings

### BSO-SEC-048 — Plaintext test-account password embedded in `apogee-assistant` skill
- **Severity:** High
- **CWE/OWASP:** CWE-798 (Use of Hard-coded Credentials); A07 Identification & Authentication Failures
- **Location:** `/home/pwner/.claude/skills/apogee-assistant.md:11`
- **Description:** The user-local skill file embeds the literal string
  `the password is \`TestPass123\` and is session-only — never persist it`.
  Documenting the rule and then persisting the credential in the same
  sentence inverts the rule. Anyone with read access to the user's home
  directory (including any agent or hook that reads the skills index,
  any backup, any rsync to a second machine, any future commit of the
  dotfiles) now has prod credentials for `jasonbrailowbizop@mail.com`
  against `https://app.0xapogee.com`.
- **Impact:** Compromise of the platform owner's test account — which
  has standing scan-trigger authorization and tenant data. Note that
  the same file pre-discloses the email, the prod base URL, the
  Supabase URL pattern, and the Supabase anon key fetch command, so an
  attacker who reads this file has a complete login recipe.
- **Proof / Evidence:** Line 11:
  ```
  The owner's authorized test account is `jasonbrailowbizop@mail.com`; the password is `TestPass123` and is session-only — never persist it (per `feedback_trigger_scans_via_api.md`).
  ```
- **Recommended Fix:** Replace the password with a pointer to a
  password-manager entry or to a `kubectl get secret` retrieval the
  owner pastes in per-session. The skill should restate the rule
  ("password is session-only; ask the owner at session start") without
  ever rendering the value.
- **References:** `feedback_trigger_scans_via_api.md`,
  `docs/standards/secrets-management.md`, `feedback_no_env_commits.md`
  (same principle — secrets do not belong in files).

---

### BSO-SEC-049 — Hardcoded `scanner_id == "ai-anthropic"` batch-skip will not skip Phase 2 AI providers
- **Severity:** Medium
- **CWE/OWASP:** CWE-1188 (Insecure Default Initialization of Resource); A04 Insecure Design
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:1199` (batch dispatch path) and `:2041` (single-scan AI dispatch path)
- **Description:** Both AI-routing branches gate on the literal string
  `"ai-anthropic"`. Per `~/.claude/skills/apogee-assistant.md:138` Phase 2
  registers additional AI scanner IDs `ai-openai` and `ai-gemini`. When
  those land in the `SCANNERS` registry the dashboard will surface them
  (the `ScannerSelector.tsx:140` filter is the prefix `ai-`), users will
  select them, and the batch endpoint will **not** skip them — they will
  fall through to the `tool-integration` POST path with an unknown
  scanner ID. The single-scan endpoint will dispatch to
  `tool-integration` instead of `ai-scanner`. Both produce confusing
  user-facing failures and, worse, can pile up phantom Job dispatches
  to `tool-integration` that look like a misbehaving client.
- **Impact:** Future regression: malformed scanner routing the day BYO
  providers go live. Operational risk, not an immediate auth bypass.
- **Proof / Evidence:** scans.py:1199 `if scanner_id == "ai-anthropic":`
  and scans.py:2041 `if scanner_id == "ai-anthropic":`. Dashboard prefix
  check at `blocksecops-dashboard/src/components/scanner/ScannerSelector.tsx:140`:
  `scanners.filter((s) => s.id.startsWith('ai-'))`.
- **Recommended Fix:** Switch both call sites to `scanner_id.startswith("ai-")`
  to match the dashboard's prefix convention. The `ai_payload` builder
  can keep `provider="managed-claude"` as the default, but the
  scanner-ID match should be prefix-based so the routing is correct on
  the day Phase 2 lights up.
- **References:** `feedback_follow_existing_patterns.md` (UI uses
  prefix; backend must too), Phase 10 plan in
  `TaskDocs-BlockSecOps/phases/10-phase-10-byo-ai-scanning/`.

---

### BSO-SEC-050 — Dashboard BatchScanModal `ai_sensitivity_acknowledged` field is never sent on batch path
- **Severity:** Medium
- **CWE/OWASP:** CWE-862 (Missing Authorization); A04 Insecure Design
- **Location:** `blocksecops-dashboard/src/components/contracts/BatchScanModal.tsx:108-117` and `blocksecops-dashboard/src/pages/BatchScan.tsx:135-144`
- **Description:** Both batch-scan call sites send only
  `{contract_ids, scanner_ids, scan_type, priority}` to
  `createBatchScan`. They never pass `ai_sensitivity_acknowledged`. The
  api-service batch endpoint (`scans.py:1199`) currently swallows AI
  scanner selections silently, so this is not yet exploitable. But the
  Phase 2 lift-over plan adds AI to batch — at that point the
  api-service will receive batch requests with AI scanners but no
  consent flag and either (a) reject all of them as
  `ai_org_disabled` (silent UX failure for paying users) or (b)
  someone "fixes" the rejection by defaulting the flag to `true`
  server-side, which would silently bypass BSO-SEC-031.
- **Impact:** Forward-compat consent-bypass setup. Today: zero impact
  because of the batch skip at scans.py:1199. Tomorrow: a single
  one-line server-side "fix" away from a consent bypass.
- **Proof / Evidence:** `createBatchScan` payload shape in both files
  omits the field. The single-scan `ContractDetail.tsx:213-229` does
  send it conditionally, demonstrating the dashboard pattern.
- **Recommended Fix:** When batch AI lands in Phase 2, BatchScanModal
  must surface the same sub-processor confirmation UX as single-scan
  and propagate `ai_sensitivity_acknowledged` in the batch payload.
  Add a `data-testid="batch-ai-consent-confirmed"` for the regression
  suite. **Until then**, the batch endpoint must keep skipping AI
  entirely; do not "soft-enable" AI in batch without wiring this flag.
  Add a code comment on scans.py:1199 that the skip is load-bearing
  consent-gating.
- **References:** BSO-SEC-031 (sensitivity ack is server-enforced),
  `docs/standards/secure-coding.md` A04, `feedback_follow_existing_patterns.md`.

---

### BSO-SEC-051 — `contract_files(contract_id, file_path)` lacks a UNIQUE constraint
- **Severity:** Low
- **CWE/OWASP:** CWE-345 (Insufficient Verification of Data Authenticity); A08 Software & Data Integrity Failures
- **Location:** `blocksecops-api-service/alembic/versions/20251012_1500-001_initial_schema.py:97-110` (no unique index on `(contract_id, file_path)`); consumed at `blocksecops-ai-scanner/src/application/services/scan_orchestrator.py:146-160` and `:252`.
- **Description:** `contract_files` has only `ix_contract_files_contract_id`
  (non-unique). The multi-file loader builds
  `allowed_files = {path: content.count("\n") + 1 for path, content in files_payload}`
  — a dict comprehension that silently overwrites duplicate `file_path`
  keys with whichever row came last by the ORDER BY. If the upload path
  ever lets a malformed archive or attacker-crafted GitHub tree
  re-insert the same path twice (one short benign file, one giant or
  malicious file), the validator will accept LLM findings keyed to the
  short benign line count even though the LLM saw the long file. Today
  the upload paths in `contracts.py:856-865` do not de-dup either, so
  this is reachable.
- **Impact:** Low — the LLM still scans both files, the validator just
  measures line counts against the wrong row. Worst case: a true-line
  exceeding the short file's line count gets rejected (false negative),
  not a false positive. No data exfil, no consent bypass.
- **Proof / Evidence:** Schema definition at the initial migration
  shows only `op.create_index(... unique=False)`. Orchestrator at
  `scan_orchestrator.py:252` rebuilds the map by overwriting duplicates.
- **Recommended Fix:** Add a new Alembic migration creating
  `UNIQUE (contract_id, file_path)` on `contract_files` plus a backfill
  step that renames duplicates (suffix with row index) before applying
  the constraint. Update `docs/database/SCHEMA.md` in the same commit
  per Database Rule 4.
- **References:** `docs/standards/database-management.md` Rule 4;
  scan_orchestrator.py:146-160, 252.

---

### BSO-SEC-052 — `allowed_files` keys are not path-normalized, causing benign false negatives on LLM-emitted paths
- **Severity:** Low
- **CWE/OWASP:** CWE-1284 (Improper Validation of Specified Quantity in Input)
- **Location:** `blocksecops-ai-scanner/src/application/services/scan_orchestrator.py:142-160, 252`; cross-referenced with `blocksecops-ai-scanner/src/guardrails/output_validator.py` (`_validate_one`, file lookup `if file_path not in allowed_files`).
- **Description:** The orchestrator stuffs raw `contract_files.file_path`
  values into `allowed_files`. Uploaded paths may carry a leading `./`,
  inconsistent separator (`\\` vs `/` on Windows-archived ZIPs), or
  redundant slashes. The LLM will see these literal strings inside the
  `file_path="..."` XML attribute and is asked to echo them back in
  findings. It often normalizes (`./Token.sol` → `Token.sol`). The
  validator does an exact `file_path not in allowed_files` match
  (`output_validator.py` line ~155), so the validator rejects the
  finding with `error="file '<path>' not in the contract source"`.
- **Impact:** Silent false negatives — legitimate AI findings get
  dropped, the user pays input/output tokens, the scan returns 0
  findings. No security exposure, but undermines paid-feature value
  and could be mistaken for a model-quality issue.
- **Proof / Evidence:** No normalization between
  `scan_orchestrator.py:160` (push raw path into `files_payload`) and
  line 252 (build `allowed_files` keyed on raw path). Validator at
  `output_validator.py:_validate_one` uses `if file_path not in allowed_files`.
- **Recommended Fix:** Normalize once at orchestrator load:
  `normalized = posixpath.normpath(path).lstrip("./")`. Use the
  normalized key in both `files_payload` (so the fenced attribute
  matches) and `allowed_files`. Optionally accept either the raw or
  normalized form in the validator and map back to the canonical key.
- **References:** `output_validator.py` `_VALID_SEVERITY` block and
  the `if file_path not in allowed_files` branch.

---

### BSO-SEC-053 — `fence_sast_findings` CDATA escape is reachable via attacker-controlled SAST output
- **Severity:** Low
- **CWE/OWASP:** CWE-94 (Improper Control of Generation of Code); A03 Injection
- **Location:** `blocksecops-ai-scanner/src/guardrails/prompt_injection.py:53-62`
- **Description:** `fence_sast_findings` JSON-serializes the list and
  then string-replaces `]]>` with `]]]]><![CDATA[>`. The JSON
  serializer escapes `>` only as `>` when `ensure_ascii=True`, but
  the code passes `ensure_ascii=False`, so `]]>` can appear verbatim in
  string values inside the JSON (e.g. a Slither finding description
  that happens to contain `]]>`). The escape is in place and works,
  but: (a) the escape is single-pass — if a finding ALSO contains the
  literal `]]]]><![CDATA[>`, the escape produces a new `]]>` boundary
  that is NOT re-escaped (rare but pathological); and (b) the comment
  on line 60 says "shouldn't contain it" which is misleading because
  the source flag is `ensure_ascii=False`. The XML attribute path
  through `_escape_attr` (line 65-72) is correct.
- **Impact:** The single-pass behavior is theoretical — an attacker
  would need to control a SAST scanner's output and embed the exact
  multi-byte sequence in their contract to land it in a finding. Even
  then, the prompt injection only changes what context the LLM sees,
  not the orchestrator's flow. The output validator (whitelist of
  files, line ≤ EOF, severity enum) still rejects malformed findings.
- **Proof / Evidence:** Line 59: `json.dumps(findings, ..., ensure_ascii=False)`;
  line 61: single-pass `safe = payload.replace("]]>", "]]]]><![CDATA[>")`.
- **Recommended Fix:** Either (a) flip to `ensure_ascii=True` to
  eliminate the surface (`>` becomes `>` and the CDATA boundary
  is unreachable inside JSON strings); or (b) use a `while "]]>" in safe`
  loop so the escape is fixed-point; or (c) replace CDATA fencing for
  the SAST block with base64-encoded JSON and a tag rule in the system
  prompt.
- **References:** `docs/standards/secure-coding.md` A03; CWE-94.

---

### BSO-SEC-054 — Multi-file source loader does not enforce per-scan file count cap
- **Severity:** Low
- **CWE/OWASP:** CWE-770 (Allocation of Resources Without Limits or Throttling); A04 Insecure Design
- **Location:** `blocksecops-ai-scanner/src/application/services/scan_orchestrator.py:142-170`
- **Description:** The loader iterates **every** `.sol` row in
  `contract_files` for a given `contract_id`, with only the
  `per_scan_input_token_cap` (enforced by `quota_service.check_and_reserve`)
  as a backstop. Token-cap rejection happens, but by then the API has
  already round-tripped potentially MBs of source from Postgres to the
  ai-scanner pod, summed `len(c)` over all files, and built the
  `files_payload` list. A user who uploaded a 5,000-file vendored
  monorepo will hammer Postgres + memory on every triggered AI scan
  even though the scan will then be rejected for quota. Combined with
  no rate limit on `/scans/.../ai-trigger` retries beyond what the
  api-service edge provides, this is a cheap I/O amplification.
- **Impact:** Cost-of-attack against the ai-scanner pod for an
  authenticated user. Will not exfil data or bypass auth. Mitigated
  today by Cloudflare WAF + api-service rate limit + tier-based
  per-scan caps.
- **Proof / Evidence:** scan_orchestrator.py:146-160 fetches all rows
  before any size check; line 168-169 sums sizes only after the full
  payload has been materialized.
- **Recommended Fix:** Add a hard `MAX_FILES_PER_SCAN = 200` (or tier-
  configurable) early in the loader; return `ai_system_error` (or a
  new `ai_too_many_files`) before materializing the payload. Optionally
  add a `LIMIT` to the SQL query.
- **References:** `docs/standards/secure-coding.md` A04;
  `feedback_no_redundant_canaries.md` (cost-aware).

---

### BSO-SEC-055 — INFO: implicit-consent UX decision documented but not source-of-truth-linked
- **Severity:** Info
- **CWE/OWASP:** N/A (policy / audit-trail concern, not a vulnerability)
- **Location:** `blocksecops-dashboard/src/pages/ContractDetail.tsx:220-227`
- **Description:** The dashboard v0.55.4 dropped the explicit
  sub-processor consent checkbox in favor of implicit
  consent-by-action (clicking "Start Scan" with an AI scanner selected
  acknowledges the LLM sub-processor). This is the industry-norm UX
  (GitHub Copilot, Cursor, Codeium, etc. all use ToS-level
  disclosure plus action-as-consent). The inline code comment at
  line 224-226 does say
  `"Implicit consent: by clicking Start Scan with AI selected the user is acknowledging the LLM sub-processor"`,
  but the change is not yet reflected in the platform's published
  Terms of Service / Sub-processor List / Privacy Notice, and the
  audit log per BSO-SEC-041 (already noted in baseline) does not
  record the implicit-consent timestamp for AI scans.
- **Impact:** No technical impact. Legal posture only — if challenged
  under GDPR Art. 28 (sub-processor disclosure), Apogee needs a paper
  trail that (a) the ToS / privacy notice names the LLM provider and
  data-processing region; (b) the AI scan trigger writes an audit row
  with the timestamp, user_id, contract_id, and the consent surface
  shown (UI version / phrasing). The backend already enforces the
  server-side BSO-SEC-031 gate, so direct API callers cannot bypass.
- **Proof / Evidence:** `ContractDetail.tsx:213-229` — `includesAI`
  branch always sets `ai_sensitivity_acknowledged: true`. The flag
  is ONLY sent when AI is selected, which is the correct behavior
  (verified: line 213 `const includesAI = selectedScanners.includes('ai-anthropic')`
  gates the spread). Non-AI scans do NOT send the consent flag at all.
- **Recommended Fix (non-blocking, narrative):**
  1. Publish updated Terms of Service / Sub-processor List naming
     Anthropic as the AI sub-processor and the data region
     (`us-east-1` for direct Anthropic API).
  2. Wire BSO-SEC-041 audit rows for AI scan triggers to record
     `consent_surface: "implicit_via_scan_button_v0.55.4"`,
     `user_id`, `contract_id`, `scan_id`, `ts`.
  3. Leave the implicit-consent UX as-is — it matches industry norms
     and the owner has explicitly chosen it.
- **References:** `feedback_no_scope_creep_pre_customer.md` (this is
  pre-customer; don't over-engineer); BSO-SEC-041 baseline finding.

---

## Positive Observations

- **Server-side BSO-SEC-031 gate intact** (scan_orchestrator.py:114-120):
  the orchestrator still hard-rejects `sensitivity_acknowledged=False`,
  so a direct API caller cannot bypass via the same field even with
  the dashboard implicit-consent change.
- **Pre-dispatch gates at the api-service edge intact**
  (scans.py:2042-2088): all four gates (sensitivity ack, contract
  block, user consent, org enabled) execute **before**
  `asyncio.create_task(_fire_ai_trigger(...))` at line 2126.
  BSO-SEC-029 lesson held.
- **Internal-service-token comparison** still uses the canonical
  pattern via `settings.internal_service_key` injection (not in the
  diff to re-verify, but no regressions introduced in this iteration).
- **`fence_contract_source` `_escape_attr`** correctly escapes `&`,
  `"`, `<`, `>` for the user-supplied `file_path` XML attribute
  (prompt_injection.py:65-72), so a malicious `file_path` cannot break
  out of the attribute and inject sibling XML.
- **Output validator whitelist intact**: allowed-files map +
  `line ≤ EOF` + severity enum (`output_validator.py` `_VALID_SEVERITY`)
  still gate every emitted finding. The multi-file loader correctly
  feeds the per-file line counts into `allowed_files`.
- **Dashboard consent send is conditionally gated**
  (`ContractDetail.tsx:213` `const includesAI = ...`): the spread
  `...(includesAI ? {ai_mode, ai_provider, ai_sensitivity_acknowledged: true} : {})`
  ensures the flag is **only** sent when AI is in the selection — the
  audit's "false consent on non-AI scans" failure mode does not exist.
- **`/scanners` catalog endpoint rate-limited**
  (api-service `endpoints/scanners.py` uses `limiter.limit(get_rate_limit_string("general", "default"))`).
  Dashboard's switch from hardcoded to dynamic does not introduce
  a new DoS surface.
- **`per_scan_input_token_cap` rejects multi-file balloons**
  (`ai-scanner/src/application/services/quota_service.py:124-129`
  with the `PER_SCAN_INPUT_CAP_EXCEEDED` failure_type). A user
  cannot drain quota via a 50 MB monorepo upload.
- **Batch endpoint correctly fails closed for AI** today
  (scans.py:1199 `if scanner_id == "ai-anthropic": continue` with a
  WARN log). Until BatchScanModal wires consent, the skip is
  load-bearing — see BSO-SEC-050.
- **No new uses of `==` for token compare introduced** in this
  iteration (`hmac.compare_digest` pattern from BSO-SEC-028 still
  holds; the diff does not touch the internal-token compare code).

---

## Follow-ups

- [ ] **OWNER — BSO-SEC-048**: Edit `~/.claude/skills/apogee-assistant.md`
      line 11 to remove the literal `TestPass123`. Replace with
      "ask the owner at session start" or a `pass` / 1Password CLI
      pointer. Today.
- [ ] **api-service — BSO-SEC-049**: Switch `scanner_id == "ai-anthropic"`
      to `scanner_id.startswith("ai-")` at scans.py:1199 and :2041.
      Land BEFORE Phase 2 BYO providers register `ai-openai` /
      `ai-gemini`.
- [ ] **api-service comment — BSO-SEC-050**: Add a one-line comment
      on scans.py:1199 noting the AI skip is load-bearing for batch
      consent-gating. Plus a Phase 2 TODO comment that BatchScanModal
      must wire `ai_sensitivity_acknowledged` before the skip is
      lifted.
- [ ] **api-service migration — BSO-SEC-051**: Alembic migration
      adding `UNIQUE (contract_id, file_path)` on `contract_files`,
      with dedup backfill. SCHEMA.md updated in the same commit.
- [ ] **ai-scanner — BSO-SEC-052**: Normalize file paths via
      `posixpath.normpath(path).lstrip("./")` at scan_orchestrator.py
      load time. Use normalized key for both fence and `allowed_files`.
- [ ] **ai-scanner — BSO-SEC-053**: Flip `fence_sast_findings` to
      `ensure_ascii=True`, OR loop the CDATA escape to fixed point.
- [ ] **ai-scanner — BSO-SEC-054**: Add `MAX_FILES_PER_SCAN` early-
      exit in scan_orchestrator.py loader; emit `ai_system_error`
      with a tier-aware message.
- [ ] **legal / docs — BSO-SEC-055** (narrative): Publish updated ToS
      + Sub-processor List naming Anthropic + region; wire BSO-SEC-041
      audit-row schema to record `consent_surface` for implicit AI
      consent.
