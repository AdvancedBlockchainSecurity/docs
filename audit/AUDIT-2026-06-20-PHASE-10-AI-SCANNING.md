# Phase 10 BYO AI Scanning — Security Audit — 2026-06-20

**Auditor:** apogee-security-audit (Opus 4.7)
**Scope:**
- `blocksecops-ai-scanner` v0.2.4 (new repo): orchestrator, quota service, prompt fences, output validator, Anthropic adapter, internal-token endpoint, Dockerfile, NetworkPolicies, ExternalSecret, Workload Identity SA.
- `blocksecops-api-service` v0.45.1 delta: `ScanCreate` AI fields, the `asyncio.create_task` fire-and-forget AI dispatch branch in `scans.py`, the `service_url_ai_scanner` setting, and the new `api-service-to-ai-scanner` egress NetworkPolicy (base + GCP overlay).
- DB migrations 094 (ai_scan_metadata + consent columns) and 095 (byo_llm_keys).
- `blocksecops-dashboard` v0.55.0 delta: `AIScanOptions`, `AIBadge`, and the `ContractDetail` scan-trigger wiring.
- GCP secrets: `apogee-gcp-byo-kek` (new), `apogee-gcp-anthropic-api-key` (pre-existing, now consumed).
**Excludes (already audited or out of scope):** core auth/JWT plumbing, Stripe x402, Cairo/StarkNet, `blocksecops_com`.
**Severity scale:** Critical / High / Medium / Low / Info
**Standards referenced:** `docs/standards/api-endpoint-auth.md`, `docs/standards/secure-coding.md`, `docs/standards/encryption-standards.md`, `docs/standards/secrets-management.md`, `docs/standards/networkpolicy-templates.md`, `docs/standards/kubernetes-pod-lifecycle.md`, `docs/standards/tier-standards.md`, `docs/standards/organization-team-user-hierarchy.md`, `docs/security-audit/FIX-BSO-SEC-004-*.md` (internal-service-token timing-safe compare), `docs/audit/2026-06-19-bso-sec-021-resolution-and-cert-fix-verification.md`.

---

## Executive Summary

Phase 10 ships a generally well-architected first cut: defaults are restrictive at the schema layer (every consent column defaults False/NULL), the encryption columns for BYO keys are shaped correctly (LargeBinary ciphertext + 12-byte nonce + fingerprint, scope check constraint), the prompt-injection fence is non-trivial (CDATA boundary escape + XML attribute escape), and the output validator is strict (whitelisted severity/confidence, allowed-files set, line ≤ EOF). The Anthropic adapter does not leak keys in logs; the orchestrator does not log contract source.

However, the **first-week-on-the-wire surface has six FAILs and four WARNs that an attacker can chain into quota drain and information disclosure without authenticating to the LLM**, and one CRITICAL finding that breaks defense-in-depth on the new internal service. These are summarized in the Status Table and detailed in the Findings section; both files should ship together with the remediation patch this week.

The `byo_llm_keys` table is correctly modelled but **no API endpoint to create/list/revoke keys has been implemented yet** (BYO is Phase-2), so the at-rest encryption code path is not yet exercised — the `BYO_KEK` secret is loaded into the ai-scanner pod env but never read. That's not yet exploitable but is bad operational hygiene (live secret without a consumer) and is filed as Medium.

No HALT condition is triggered (the deployment isn't unsafe for the small managed-Claude beta), but **BSO-SEC-028 (timing-safe compare) and BSO-SEC-029 (server-side AI consent pre-check in api-service) should ship before any external customer touches the AI scanner.**

---

## Status Table

### A03 — Injection

| Check | Outcome | Notes |
|---|---|---|
| LLM input fenced (CDATA + boundary escape) | PASS | `src/guardrails/prompt_injection.py:34-50` correctly wraps in `<contract_source><![CDATA[…]]></contract_source>` and escapes the `]]>` boundary as `]]]]><![CDATA[>`. System prompt rule 1 (line 5) instructs the model to treat the block as data. |
| XML-attribute injection (language / compiler_version / file_path) | PASS | `_escape_attr` at lines 65-72 escapes `&`, `"`, `<`, `>`. Inputs come from DB columns and a server-constructed `file_label` (`f"contract_{contract.id}.sol"`) — `contract.id` is a UUID, so user-controlled attribute injection is not reachable. |
| `sast_findings` fenced safely | PASS | `fence_sast_findings` (lines 53-62) JSON-serializes the list and CDATA-fences. **WARN — BSO-SEC-035** below: size is not bounded. |
| Output validator strict (severity/confidence/files/line range) | PASS | `src/guardrails/output_validator.py:127-194`. `allowed_files` map rejects findings against files not given to the LLM; line-count cap rejects beyond-EOF references; severity/confidence whitelisted; SWC regex enforced; title/description/recommendation length-bounded. |
| Raw SQL parameterized | PASS | All four raw `text(...)` calls in `quota_service.py` and `scan_orchestrator.py` use `:name` binding. No f-string interpolation of user data into SQL. |
| String-concatenation SQL paths | PASS | Scanner-id is `f"ai-{result.provider}"` — `result.provider` is `self.provider_name` (a class-level constant `"anthropic"`) not user input. Detector-id (`f.category`) comes from the validator's `category_normalized` which is `.strip()[:64]` of an LLM-supplied string and is bound, not interpolated, so it's parameter-safe. |
| `sast_findings` request-body shape validated | **FAIL — BSO-SEC-034** | The Pydantic schema is `list[dict[str, Any]]` with `default_factory=list`. No `max_length`, no per-item shape check, no recursion-depth limit. Any caller (currently just api-service over X-Internal-Service-Token, but a token leak makes it any caller) can dispatch a 10 MB payload of arbitrary JSON, which gets JSON-serialized into the LLM prompt and counted against the org's input quota. |

### A04 — Insecure Design

| Check | Outcome | Notes |
|---|---|---|
| `users.ai_consent_at` default NULL | PASS | Migration 094 line 64. |
| `organizations.ai_scanning_enabled` default false | PASS | Migration 094 lines 67-74. |
| `contracts.ai_processing_disabled` default false (visible-default = AI-allowed) | PASS (intentional) | Per phase plan: contracts default to AI-allowed; per-contract opt-out is the user/UX path. Backed by org-level `ai_scanning_enabled` defaulting false, so the overall gate is opt-in. |
| Consent checked server-side (in ai-scanner orchestrator) | PASS | `scan_orchestrator.py:107-127`: org found, contract not AI-disabled, user has consent. |
| **Consent checked server-side BEFORE dispatch (in api-service)** | **FAIL — BSO-SEC-029** | `scans.py:2041-2082` dispatches to ai-scanner with **zero pre-check** of `org.ai_scanning_enabled`, `user.ai_consent_at`, `contract.ai_processing_disabled`, or tier. An authenticated user with `scans:create` scope can spam `POST /scans { scanner_ids: ["ai"] }` and force a network round-trip, DB read, and quota lookup at the ai-scanner for every dispatch — even when org has AI disabled. Combined with the per-user `scanCreate` rate-limit (high enough for normal use) this is a quota-bypass and DoS amplifier on the new service. Per `api-endpoint-auth.md` and `secure-coding.md` § A04, defence-in-depth requires the **first** authenticated boundary to gate. |
| Per-contract sensitivity tag (`ai_processing_disabled`) enforced | PASS | Orchestrator line 107. |
| Sensitivity-acknowledged checkbox enforced (UI only) | **WARN — BSO-SEC-031** | UI gate `ContractDetail.tsx:213-216` prevents submit without ack, but the value is sent as `ai_sensitivity_acknowledged` (default `False` per Pydantic) and the **server never rejects on this field** — it's only persisted to `ai_scan_metadata.sensitivity_acknowledged` for the audit trail. A non-browser caller (CLI, BYO integration) can dispatch without ack. If GDPR/LATAM posture requires explicit per-scan ack, this is non-compliant. |
| Defaults restrictive | PASS | All four consent/quota columns default to "off" or 0. |
| Tier gate (developer/free blocked from AI) at server | PARTIAL | The ai-scanner `quota_service.check_and_reserve` enforces tier (`tier_cfg.managed_claude_allowed`), but the api-service still **dispatches** to ai-scanner first. Same root cause as BSO-SEC-029. |

### A05 — Security Misconfiguration

| Check | Outcome | Notes |
|---|---|---|
| Default-deny NetworkPolicy on ai-scanner | PASS | `k8s/base/ai-scanner/networkpolicy.yaml:8-17`. |
| Egress allowlist to LLM providers | PASS (with caveat) | `networkpolicy-to-llm-providers.yaml`: `0.0.0.0/0:443` with private-range + 169.254.0.0/16 excludes. Doc rationale at lines 1-13 acknowledges this is wider than the postgres egress and explains why (rotating CDN IPs). **WARN — BSO-SEC-033** below: this also excludes the canonical IMDSv2 IP (good) but missing 169.254.169.254/32 split. |
| Egress allowlist to PostgreSQL | PASS | `networkpolicy-to-postgresql.yaml`. |
| DNS egress | PASS | `networkpolicy-to-dns.yaml` matches the working api-service pattern (port-only, no selector — required for GKE NodeLocal DNSCache). |
| Workload Identity SA bound to least-privilege GSA | PASS (per-config; not verified in cluster) | `serviceaccount-patch.yaml` annotates `apogee-ai-scanner@…iam.gserviceaccount.com`. Out-of-band binding via `gcloud iam service-accounts add-iam-policy-binding` — not visible in repo; trusting deployment doc per Rule 0. |
| Pod security context (non-root, RO-FS, drop ALL caps, seccomp RuntimeDefault) | PASS | `k8s/base/ai-scanner/deployment.yaml:33-66`. |
| `revisionHistoryLimit: 3` | PASS | Line 12. Per `kubernetes-pod-lifecycle.md`. |
| `imagePullPolicy: Always` + pinned digest in Dockerfile | PASS | `Dockerfile:11, 43` pinned to `python:3.13-slim@sha256:f50f56f1471fc430b394ee75fc826be2d212e35d85ed1171ac79abbba485dce9` (same digest as api-service v0.45.1 — supply-chain parity). |
| OCI image labels | PASS | `Dockerfile:49-55`. |
| AI_SCANNING_DISABLED kill switch wired (env + /ready) | PASS | `main.py:40-48` startup log; `health.py:37-46` 503 on /ready; `ai_trigger.py:71-75` 503 at endpoint. Three independent gates — good defense-in-depth. |
| Kill switch wiring tested end-to-end | OBSERVATION | Out of static-audit scope; cluster verification per `feedback_test_before_fixing.md` is owner-driven. |
| **NetworkPolicy ingress-patch overwrites instead of merging — drops Prometheus scrape** | **FAIL — BSO-SEC-030** | The base `ai-scanner-ingress` policy at `k8s/base/ai-scanner/networkpolicy.yaml:19-50` allows TWO ingress sources: api-service (port 8000) and monitoring (port 9090). The GCP overlay patch at `k8s/overlays/gcp/networkpolicy-ingress-patch.yaml:16-33` is a **strategic merge that lists both rules again** — so it works correctly by coincidence. However, the kustomization patch target (`networkpolicy-ingress-patch.yaml`) is a full-spec replacement, not a JSON-patch add; if the next developer removes the monitoring rule from the overlay (thinking it inherits from base), Prometheus loses scrape access. The overlay file should use `kustomize patch` with explicit op directives, or both base+overlay should be kept literally in sync. |
| **Base NetworkPolicy hardcodes `api-service-prod` namespace** | **FAIL — BSO-SEC-032** | `k8s/base/ai-scanner/networkpolicy.yaml:36` references `kubernetes.io/metadata.name: api-service-prod` in the base. This breaks the "base = environment-agnostic" Kustomize convention (`docs/standards/kustomize-standards.md`). A `kubectl apply -k k8s/base` (or any overlay that doesn't patch this rule) targets the production api-service namespace from a local environment. Today this is harmless because no local overlay exists, but it sets a footgun for the next overlay author. |
| Read-only root filesystem | PASS | Container `securityContext.readOnlyRootFilesystem: true` + `/tmp` emptyDir mount. |
| Resource limits set | PASS | 500m CPU / 768Mi memory limit. Tight enough that a runaway prompt-build can't exhaust node memory. |
| `/internal/docs` / `/internal/openapi.json` exposed in production? | PASS | `main.py:30-33` gates both behind `ENVIRONMENT != "production"`. |

### A07 — Authentication Failures

| Check | Outcome | Notes |
|---|---|---|
| **X-Internal-Service-Token comparison is timing-safe** | **FAIL — BSO-SEC-028 (CRITICAL)** | `src/presentation/api/v1/endpoints/ai_trigger.py:55-61` uses plain `!=` on strings: `x_internal_service_token != expected`. Python string equality short-circuits at the first mismatching byte. This is a textbook timing oracle — the very bug `secrets.compare_digest` was added to the stdlib to prevent, and the same bug BSO-SEC-004 fixed in api-service two years ago (see `src/infrastructure/auth/internal_service_auth.py:100`). The ai-scanner is reachable from any pod in the cluster that resolves to the api-service namespace label (and any pod that can spoof that label inside its own namespace). |
| Header name parity with api-service | OBSERVATION | api-service uses `X-Internal-Service-Key` header (`internal_service_auth.py:39`), ai-scanner uses `X-Internal-Service-Token` (`ai_trigger.py:55`). Same secret value, different header name. Not a security bug, but a parity inconsistency that the next developer will trip over. |
| Token rotation possible | PASS (mechanically) | Secret pulled from `apogee-gcp-internal-service-key` via ExternalSecret; rotating the GCP Secret Manager value + restarting both api-service and ai-scanner rotates it. **Caveat:** the api-service and ai-scanner read it from a single env var; there's no overlap window — a rotation will 401 in-flight requests. Acceptable for an internal-only path. |
| AuthN required on `/scans/{scan_id}/ai-trigger` | PASS | `Depends(_verify_internal_token)` at line 68. |
| AuthN required on `/health/*` and `/internal/*` | PASS (intentional) | Health is public per K8s probe convention; internal docs are environment-gated. |
| Production missing-key startup fail | PARTIAL | The ai-scanner just checks `expected = os.getenv("INTERNAL_SERVICE_KEY", "")` per-request and rejects empty. If the secret is misconfigured, EVERY request 401s (no silent-allow). api-service has explicit `config.py` validator that fails startup in production (`config.py:462-477`). The ai-scanner has **no equivalent startup validator** — a misconfigured production deployment serves 401 to every dispatch until ops notice. |

### A08 — Software & Data Integrity Failures

| Check | Outcome | Notes |
|---|---|---|
| Pinned base image SHAs | PASS | `python:3.13-slim@sha256:f50f56f1…` in both builder and runtime stages. |
| OCI labels populated via `--build-arg` | PASS | Dockerfile lines 49-55; phase plan confirms build will pass SERVICE_VERSION/BUILD_DATE/VCS_REF (per `feedback_docker_build_args.md`). |
| Wheel bundling provenance (`blocksecops_tier_config-1.4.0-…whl`) | **WARN — BSO-SEC-036** | `Dockerfile:33` copies `blocksecops_tier_config-1.4.0-py3-none-any.whl` from the repo root and installs it. The wheel is committed to Git as a binary blob with no SHA-256 verification in the Dockerfile, no `--require-hashes` pip flag, and no manifest pointing back to the `blocksecops-shared` source tag. If the wheel is regenerated for any reason, there's no verifiable trace back to source. Per `dependency-management.md`, internal wheels should at minimum have a checksum check in the Dockerfile RUN line. |
| Immutable image tags | PASS (per registry config) | Tag immutability is registry-side; the v0.2.4 newTag in `kustomization.yaml:40` is consistent with `pyproject.toml` (per `feedback_follow_standards.md` — not yet verified in this audit since it's a fresh repo). |
| Wheel source pinned in `requirements/base.txt` | OBSERVATION | The wheel is installed via the Dockerfile, not pinned in requirements/. That's fine for now but means `pip-audit` / `pip-licenses` won't see it. |

### A09 — Security Logging Failures

| Check | Outcome | Notes |
|---|---|---|
| Contract source NEVER logged | PASS | `scan_orchestrator.py` reads `source = contract.source_code` (line 131) and never passes it to a logger; the only log lines (`ai_quota_reserved`, `ai_quota_refunded`, `ai_scan_failed`) carry IDs and token counts. |
| API key NEVER logged | PASS | `anthropic.py` only logs nothing; `_build_adapter` reads the env directly into the SDK constructor. AnthropicProvider stores `self._client` not `self._key`. |
| LLM token usage logged | PASS | `quota_service.py:193-203` logs reservation; `_record_failure` logs failure; api-service side logs token counts in `_fire_ai_trigger`'s success branch (`scans.py:2061-2072`). |
| Cost recorded for audit | PASS | `_calc_cost_micros` persists into `ai_scan_metadata.cost_usd_micros`. |
| Refused / safety-blocked outcomes logged | PASS | Orchestrator records `failure_type=ai_safety_blocked` + reason; refused reason capped at 500 chars before persisting (output_validator.py:104). |
| **No structured request-id / correlation-id propagated from api-service** | **WARN — BSO-SEC-037** | The api-service `_fire_ai_trigger` extra-logs use `scan_id`, but the request itself doesn't pass a `X-Request-Id` or `X-Correlation-Id` header. Cross-service log correlation in an incident requires manually joining on scan_id. Not a security finding in isolation, but matters during incident response on this surface. |
| Refused reason length cap | PASS | 500-char cap in validator. |
| `error_message` cap before persistence | PASS | `_record_failure` line 409: `message[:2000]`. |

### A10 — SSRF

| Check | Outcome | Notes |
|---|---|---|
| api-service → ai-scanner POST URL is internal-cluster only | PASS | `service_url_ai_scanner` config defaults to `http://ai-scanner.ai-scanner-local.svc.cluster.local:8000` (`config.py:210-213`); GCP overlay (`configmap-patch.yaml:35`) sets `http://ai-scanner.ai-scanner-prod.svc.cluster.local:8000`. The setting is not user-controllable. NetworkPolicy `api-service-to-ai-scanner` (base + GCP patch) restricts egress to that cluster pod/namespace. |
| AI scanner egress restricted to public LLM providers only (no internal probe path) | PARTIAL | `networkpolicy-to-llm-providers.yaml` correctly excludes 10/8, 172.16/12, 192.168/16, **and 169.254.0.0/16** (covers the GCP metadata endpoint). Good. But the kustomization stacks egress with `to-postgresql` (allowed) and `to-llm-providers`. There is no egress to api-service or any other internal service — the ai-scanner cannot call back into the platform, which prevents an SSRF-from-LLM-output attack since the orchestrator doesn't follow URLs anyway. |

### Encryption (encryption-standards.md)

| Check | Outcome | Notes |
|---|---|---|
| `byo_llm_keys.encrypted_key` is `LargeBinary` with separate 12-byte `encryption_nonce` | PASS | Migration 095 lines 80-91. Comments correctly note "AES-256-GCM ciphertext", "12-byte random nonce, regenerated per encryption". |
| `key_fingerprint` for UI display only (last 4 chars + provider) | PASS | Migration 095 lines 92-97. |
| KEK kept in Vault / Secret Manager (`BYO_KEK` ExternalSecret) | PASS (config-side) | `k8s/overlays/gcp/externalsecret.yaml:25-27` syncs `apogee-gcp-byo-kek` → env `BYO_KEK`. |
| **AES-256-GCM encrypt/decrypt code path implemented** | **FAIL — BSO-SEC-033** | The `BYO_KEK` env var is loaded into the pod via ExternalSecret and is never read anywhere in the codebase (`grep -rn 'BYO_KEK' src/` → zero hits). There is no `byo_keys` service, no encrypt/decrypt helper, no `cryptography.hazmat.primitives.ciphers.aead.AESGCM` usage. The `BYOLLMKeyModel` is wired in `models.py` but the `_build_adapter` function explicitly errors out with `"BYO providers not yet supported in Phase 1"` (`scan_orchestrator.py:336-339`). **Loading secret material into a pod that doesn't use it violates the principle of least privilege** — if the ai-scanner pod is ever compromised, the attacker exfils a KEK that maps to nothing today but will tomorrow be used to decrypt every customer's BYO key. Either remove the secret from the ExternalSecret until Phase 2, or implement the encrypt/decrypt service now so the secret is exercised by tests on day one. |
| Soft-delete via `revoked_at` | PASS | Migration 095 lines 119-123. |
| Partial unique index on active key per (scope, provider) | PASS | Lines 158-171. Correct use of `postgresql_where`. |
| Scope exclusivity check (org XOR user) | PASS | Line 143: `(organization_id IS NOT NULL) <> (user_id IS NOT NULL)`. |
| TLS to LLM provider (api.anthropic.com) | PASS | Anthropic SDK uses HTTPS by default; NetworkPolicy only permits TCP/443. |
| TLS to PostgreSQL | PASS | asyncpg default `ssl=prefer`; server-side `hostssl` enforcement per `project_postgresql_ssl_fix.md`. |
| Plaintext key never persisted | PASS (by design) | No code path persists plaintext. |

### Tier Boundaries (tier-standards.md)

| Check | Outcome | Notes |
|---|---|---|
| Per-tier per-scan input cap | PASS | `quota_service.py:124-132` rejects with `ai_token_cap_exceeded` if `estimated_input_tokens > tier_cfg.per_scan_input_token_cap`. |
| Per-tier monthly input + output budget | PASS | Lines 136-148: single atomic `UPDATE … WHERE … <= cap RETURNING …`. The reservation is conservative (input estimate + 5000 output cap). |
| Concurrent-scan race resolution | PASS | The atomic UPDATE ... RETURNING means N parallel scans against the same org cannot collectively exceed the cap — losers get 0 rows back and are rejected with `ai_quota_exceeded`. |
| Free / developer tier blocked at server | PARTIAL | The orchestrator rejects `managed_claude_allowed=False` tiers (line 96-101) but, as flagged in BSO-SEC-029, only AFTER api-service dispatched. |
| BYO tier gate (`tier_cfg.byo_allowed`) | PASS | Lines 102-107 + 108-113 (per-provider allowlist). |
| Mode gate (`tier_cfg.modes`) | PASS | Lines 116-121. |
| Refund unused tokens on success | PASS | `refund_unused` is called with actual tokens and clamps refund to ≥ 0. |
| Refund all on system error / network failure | PASS | `refund_all` calls `refund_unused(actual_input=0, actual_output=0)`. |
| Refund partial on `safety_blocked` (charge input, refund output) | PASS | `scan_orchestrator.py:189-198` correctly charges input on safety-blocked, refunds output. |
| Refund on `ai_output_invalid` (LLM jailbreak attempt) | PASS | Lines 217-230: refunds unused, persists metadata, marks failed. |

### Secrets (secrets-management.md)

| Check | Outcome | Notes |
|---|---|---|
| No hardcoded secrets in code/manifests | PASS | Grepped repo for `sk_*`, `ghp_*`, `AKIA*`, `whsec_*`, base-64 looking 32-byte literals — zero hits. |
| `.env` is gitignored | PASS | `.gitignore` lines 51-53 list `.env`, `.env.local`, `.env.*.local`. `git ls-files` shows zero `.env*` tracked. |
| Secrets pulled via ExternalSecret | PASS | `externalsecret.yaml` syncs DATABASE_URL, INTERNAL_SERVICE_KEY, APOGEE_ANTHROPIC_KEY, BYO_KEK. |
| Production secret-validation at startup | **WARN — BSO-SEC-038** | api-service has `config.py:462-477` that fails startup in production if INTERNAL_SERVICE_KEY is missing/placeholder. The ai-scanner has no equivalent — it silently 401s every request. Symmetry with api-service should be added. |
| `apogee-gcp-byo-kek` exists but loaded into a pod that never uses it | **FAIL** | See BSO-SEC-033 above. |

### NetworkPolicy (networkpolicy-templates.md)

| Check | Outcome | Notes |
|---|---|---|
| ai-scanner pods covered by default-deny | PASS | Base policy with empty `podSelector: {}` + both policyTypes. |
| Explicit ingress allowlist | PASS (caveats above) | api-service:8000 + monitoring:9090. |
| Explicit egress allowlist (DNS, PostgreSQL, LLM providers) | PASS | Three policies in the GCP overlay. |
| api-service NetworkPolicy adds egress to ai-scanner | PASS | `blocksecops-api-service/k8s/base/api-service/networkpolicy.yaml:568-592` + GCP overlay patch at `networkpolicy-ai-scanner-patch.yaml`. |
| Egress allowlist uses `protocol:` | PASS | All ports specify TCP. |
| Egress to LLM providers correctly excludes RFC1918 + 169.254 (metadata) | PASS | `networkpolicy-to-llm-providers.yaml:31-37`. |
| **Celery-worker egress to ai-scanner** | OBSERVATION | Celery worker pod selector `app.kubernetes.io/name: celery-worker` doesn't have an egress rule to ai-scanner. Today celery isn't a caller (api-service dispatches inline via `asyncio.create_task`), but if AI dispatch ever moves to Celery (which it should, per the comment at `scans.py:3001` about `asyncio.create_task` sharing the event loop), celery will need its own ai-scanner egress. Filed as Info for forward-tracking. |

### GDPR / LATAM Posture

| Check | Outcome | Notes |
|---|---|---|
| Sensitivity flag (`contract.ai_processing_disabled`) checked server-side | PASS | Orchestrator line 107. |
| Sub-processor consent (`user.ai_consent_at`) enforced before LLM call | PASS | Orchestrator line 124. |
| Per-scan sensitivity ack persisted | PASS | `ai_scan_metadata.sensitivity_acknowledged` populated. |
| Per-scan sensitivity ack ENFORCED at server (not just persisted) | **WARN — BSO-SEC-031** | See A04 row above. Field is persisted but never rejected when False — a non-browser caller can dispatch with `sensitivity_acknowledged: false` and the scan still runs. |
| Org admin opt-in (`organizations.ai_scanning_enabled`) | PASS | Enforced in quota_service. |
| GDPR Right-to-Erasure path for byo_llm_keys | PASS (by schema) | Migration 095 comment line 26-27 documents soft-delete via `revoked_at`; hard-delete reserved for RtE. ORM CASCADE on `users` / `organizations` delete handles transitive cleanup. |
| Audit log writes on `ai_consent_at` change / org-enable | **WARN — BSO-SEC-039** | The grep for `audit_log` / `AuditLog` in the ai-scanner returns zero hits. The api-service `consent.py` handles ToS consent audit-logs, but no endpoint currently writes `users.ai_consent_at` (it's a column with no writer in this audit's scope — likely a UI/API gap that lands later this week). When that endpoint ships it MUST write an `AuditLogModel` row. Filed as forward-tracking. |

### Cost-of-Attack Analysis

| Check | Outcome | Notes |
|---|---|---|
| **Attacker authenticated with `scans:create` scope can drain org AI budget?** | NO (under cap) | Quota service caps per-scan and monthly. An attacker who exhausts the monthly cap doesn't get to call the LLM, but DOES burn one `INSERT INTO scans` + `UPDATE … RETURNING` round-trip per attempt before being rejected (see BSO-SEC-029). |
| Attacker can bypass per-contract sensitivity? | NO | Server-side check at orchestrator line 107. |
| Attacker can spam dispatches to ai-scanner even when org has AI disabled? | **YES — BSO-SEC-029** | Per the FAIL above: api-service dispatches without checking `ai_scanning_enabled`, so each `POST /scans { scanner_ids: ["ai"] }` costs one full ai-scanner orchestrator round-trip (HTTP + 2 SELECTs + the conditional UPDATE) per attempt, rate-limited only by the generic `scanCreate` slowapi rule. Combine with 10k cheap contract uploads and a botnet and you have a sustained ~req/s burn on the new service. |
| 5xx on ai-scanner causes scan to be stuck "queued" forever? | PARTIAL | The api-service uses `asyncio.create_task` (fire-and-forget) with a 180s httpx timeout. On timeout/5xx, the **api-service log** has the failure but the **scan row** stays at `status='queued'` because the ai-scanner never gets to write the failure row. **WARN — BSO-SEC-040** below. |
| Attacker can leak prompt to extract Apogee's system-prompt IP? | LOW RISK | The fence escapes the CDATA boundary, and the system prompt rule 1 instructs the model to treat the source as data. Anthropic's safety filter is one additional layer. Some leakage of the system prompt via creative inputs is plausible but no findings are persisted unless they validate, and the system prompt itself is non-proprietary security guidance. Acceptable risk for v0.1. |

---

## Findings

### BSO-SEC-028 — Internal-service-token comparison is not constant-time (timing attack)

- **Severity:** CRITICAL
- **CWE/OWASP:** CWE-208 (Observable Timing Discrepancy), CWE-203 (Observable Discrepancy), OWASP A07:2021 (Identification and Authentication Failures).
- **Location:** `blocksecops-ai-scanner/src/presentation/api/v1/endpoints/ai_trigger.py:55-61` (`_verify_internal_token`).
- **Description:** The check `if not expected or x_internal_service_token != expected:` uses Python string `!=`, which short-circuits at the first mismatching byte. An attacker who can issue many requests against `/scans/{scan_id}/ai-trigger` can perform a side-channel timing attack to extract the shared secret byte-by-byte. The same bug was fixed in api-service two years ago (BSO-SEC-004); the fix used `secrets.compare_digest`.
- **Impact:** A timing oracle on the shared secret allows recovery of `INTERNAL_SERVICE_KEY`, which then grants:
  1. Unauthenticated dispatch of AI scans against any scan_id (drain org AI quota, drain Apogee's managed-Claude bill).
  2. Spoofing of api-service in cross-service calls (the same secret is shared across tool-integration, orchestration, scans dispatch, admin/system).
  3. Future ability to dispatch BYO-key-using scans once Phase 2 ships, which would charge customer LLM accounts.
  Reachability: the ai-scanner ingress NetworkPolicy allows any pod in the api-service namespace with `app: api-service` label, and any pod in the monitoring namespace. An attacker who can deploy to api-service namespace (or compromise an api-service pod) can mount the attack from inside the cluster.
- **Proof / Evidence:**
  ```python
  # ai-scanner: vulnerable
  def _verify_internal_token(x_internal_service_token: str = Header(...)) -> None:
      expected = os.getenv("INTERNAL_SERVICE_KEY", "")
      if not expected or x_internal_service_token != expected:  # ← short-circuits
          raise HTTPException(...)

  # api-service: correct (already fixed in BSO-SEC-004)
  # internal_service_auth.py:100
  if not secrets.compare_digest(x_internal_service_key, settings.internal_service_key):
      ...
  ```
- **Recommended Fix:**
  ```python
  import secrets
  def _verify_internal_token(x_internal_service_token: str = Header(...)) -> None:
      expected = os.getenv("INTERNAL_SERVICE_KEY", "")
      if not expected:
          raise HTTPException(status_code=503, detail="Internal-service auth not configured")
      if not secrets.compare_digest(x_internal_service_token, expected):
          raise HTTPException(status_code=401, detail="Invalid or missing X-Internal-Service-Token")
  ```
  Add a startup validator in `main.py` that fails-fast in production if `INTERNAL_SERVICE_KEY` is missing or in the `_INSECURE_SECRET_VALUES` list (mirror `config.py:462-477` from api-service).
  Add a regression test that asserts `secrets.compare_digest` is called (or, better, parametrized test that all-bytes-correct returns 200 and one-byte-wrong returns 401 — purely for the contract, since timing-difference cannot be reliably asserted in unit tests).
- **References:** CWE-208; `docs/security-audit/FIX-BSO-SEC-004-*.md`; `blocksecops-api-service/src/infrastructure/auth/internal_service_auth.py:99-109` (canonical fix); Python `secrets.compare_digest` docs.

---

### BSO-SEC-029 — api-service dispatches AI scans without server-side consent / org-opt-in / tier pre-check

- **Severity:** HIGH
- **CWE/OWASP:** CWE-285 (Improper Authorization), CWE-840 (Business Logic Errors), OWASP A04:2021 (Insecure Design).
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2041-2082`.
- **Description:** When `scanner_ids` includes `"ai"`, the create_scan endpoint fires off `_fire_ai_trigger(...)` via `asyncio.create_task` without first checking:
  - `organizations.ai_scanning_enabled` (org opt-in)
  - `users.ai_consent_at` (sub-processor consent)
  - `contracts.ai_processing_disabled` (per-contract sensitivity)
  - Tier eligibility (managed-claude vs BYO)
  - `ai_sensitivity_acknowledged` request field

  All those checks happen at the ai-scanner orchestrator (lines 107-127 + the quota service), which is correct as defense-in-depth, but defense-in-depth requires the FIRST authenticated boundary to also enforce. Per `api-endpoint-auth.md` and `secure-coding.md` § A04, the api-service is that boundary.
- **Impact:**
  1. **Quota / DoS amplifier on ai-scanner.** An authenticated user with `scans:create` (any tier, including free) can spam `POST /scans { scanner_ids: ["ai"] }` against contracts in their org and force a full dispatch round-trip per attempt — even when their org has AI disabled. Each attempt costs: 1 httpx round-trip from api-service, 1 ai-scanner FastAPI request, ~4 DB SELECTs (scan, contract, org, user), 1 conditional UPDATE on organizations. Throttled only by the generic `scanCreate` slowapi rule.
  2. **Quota leakage.** A free-tier user can confirm whether their org has AI scanning enabled by observing the failure_type returned on `/scans/{id}` — the orchestrator's `failure_type` distinguishes `ai_org_disabled` from other failures. This is a minor information disclosure but maps directly to whether the customer pays for the AI add-on.
  3. **Cost-of-attack model violation.** The Phase 10 plan in `TaskDocs-BlockSecOps/phases/10-phase-10-byo-ai-scanning/` explicitly calls out "10k contract upload + AI dispatch" as an attack scenario; the orchestrator-only check defends against the LLM-cost portion but not the platform-cost portion.
- **Proof / Evidence:**
  ```python
  # scans.py:2041-2082 — AI branch, no pre-check
  if scanner_id == "ai":
      ai_payload = {
          "mode": getattr(scan_data, "ai_mode", None) or "structured",
          "provider": getattr(scan_data, "ai_provider", None) or "managed-claude",
          "sensitivity_acknowledged": bool(getattr(scan_data, "ai_sensitivity_acknowledged", False)),
          "sast_findings": [],
      }
      ai_url = f"{settings.service_url_ai_scanner}/scans/{scan.id}/ai-trigger"
      ai_headers = {"X-Internal-Service-Token": settings.internal_service_key}

      async def _fire_ai_trigger(...): ...
      asyncio.create_task(_fire_ai_trigger(str(scan.id), ai_url, ai_payload, ai_headers))
      successful_triggers.append(scanner_id)
      continue
  ```
- **Recommended Fix:** Before the `asyncio.create_task` call, add:
  ```python
  # Load org + user once (org may already be in scope; user is current_user)
  org_query = select(OrganizationModel).where(OrganizationModel.id == contract.organization_id)
  org_row = (await db.execute(org_query)).scalar_one_or_none()
  if not org_row or not org_row.ai_scanning_enabled:
      scan.status = "failed"
      scan.failure_type = "ai_org_disabled"
      scan.error_message = "AI scanning is not enabled for your organization. Ask your org admin."
      await db.commit()
      raise HTTPException(status_code=403, detail=scan.error_message)
  if not current_user.ai_consent_at:
      scan.status = "failed"
      scan.failure_type = "ai_consent_required"
      scan.error_message = "You have not acknowledged the AI sub-processor disclosure."
      await db.commit()
      raise HTTPException(status_code=403, detail=scan.error_message)
  if contract.ai_processing_disabled:
      scan.status = "failed"
      scan.failure_type = "ai_contract_blocked"
      scan.error_message = "This contract is flagged 'no AI processing'."
      await db.commit()
      raise HTTPException(status_code=403, detail=scan.error_message)
  if not scan_data.ai_sensitivity_acknowledged:
      scan.status = "failed"
      scan.failure_type = "ai_sensitivity_ack_required"
      scan.error_message = "Per-scan sensitivity acknowledgement is required."
      await db.commit()
      raise HTTPException(status_code=400, detail=scan.error_message)
  ```
  Wrap in a helper `_validate_ai_dispatch_preconditions(current_user, contract, org, scan_data)` so it's not duplicated. Keep the orchestrator-side check as defense-in-depth (do NOT remove it).
- **References:** OWASP A04 (Insecure Design — "Use threat modeling … defense in depth"); `docs/standards/secure-coding.md` § A04; `docs/standards/api-endpoint-auth.md` (auth at the boundary).

---

### BSO-SEC-030 — NetworkPolicy ingress-patch fully replaces base rules; future overlay edits will silently drop Prometheus scrape

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-1059 (Insufficient Technical Documentation), CWE-693 (Protection Mechanism Failure — partial).
- **Location:**
  - `blocksecops-ai-scanner/k8s/base/ai-scanner/networkpolicy.yaml:19-50` (base)
  - `blocksecops-ai-scanner/k8s/overlays/gcp/networkpolicy-ingress-patch.yaml:1-33` (overlay)
  - `blocksecops-ai-scanner/k8s/overlays/gcp/kustomization.yaml:20-23` (patch target)
- **Description:** The kustomize patch target for `ai-scanner-ingress` is configured as a `kustomize.patches` entry (strategic merge), which for NetworkPolicy's `ingress: []` field MERGES BY POSITION, not by name. The overlay file currently re-lists both rules (api-service + monitoring), so today the merged result is correct. However, the next overlay developer who edits this patch — for example to change the api-service port or the namespace label — will see two rules and may delete the monitoring rule thinking it's inherited from base. The base IS the source of truth for the monitoring rule, but the patch shape is "full ingress replacement", and there's nothing in the file telling the developer that.
- **Impact:** A maintenance trap. Today: PASS. After the first overlay edit by someone unfamiliar: silent drop of Prometheus scrape → `prometheus-fastapi-instrumentator` metrics stop being collected → alerting blind spot on the new AI scanner just as it starts seeing customer traffic.
- **Proof / Evidence:** See files referenced above. The overlay duplicates the base ingress rules verbatim.
- **Recommended Fix:** Either:
  1. **(Preferred)** Convert the patch to a JSON-patch (RFC 6902) that adds only the namespace-name change, so the monitoring rule remains in the base file and is the only declaration. Example:
     ```yaml
     # kustomization.yaml
     patches:
       - target:
           kind: NetworkPolicy
           name: ai-scanner-ingress
         patch: |-
           - op: replace
             path: /spec/podSelector/matchLabels
             value:
               app: ai-scanner
     ```
  2. Or, add a comment at the top of `networkpolicy-ingress-patch.yaml` explicitly stating "This file FULLY REPLACES base ingress; the monitoring rule must remain here."
- **References:** `docs/standards/kustomize-standards.md`; `docs/standards/networkpolicy-templates.md`; Kustomize strategic-merge docs.

---

### BSO-SEC-031 — `ai_sensitivity_acknowledged` is persisted but never enforced server-side

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-840 (Business Logic Errors), GDPR Art. 7 (Conditions for consent).
- **Location:**
  - `blocksecops-api-service/src/presentation/schemas/scans.py:38-41` (request field, default False)
  - `blocksecops-ai-scanner/src/application/services/scan_orchestrator.py:295` (persisted to `ai_scan_metadata.sensitivity_acknowledged`)
- **Description:** The per-scan sensitivity acknowledgement is collected by the dashboard (`AIScanOptions` checkbox) and gated client-side at `ContractDetail.tsx:213-216` (`alert` + early return if unchecked). But the server never rejects on `ai_sensitivity_acknowledged=False`. A non-browser caller (CLI, API integration, malicious user inspecting the network call and dropping the field) can dispatch with the field absent or False, and the scan still runs. The persisted `sensitivity_acknowledged=False` row becomes the audit trail showing the user did NOT acknowledge — which is the WRONG direction for a GDPR audit (the absence of a "yes" doesn't prove the user was even shown the disclosure).
- **Impact:** GDPR / LATAM data-processing posture: the sub-processor disclosure is a compliance control. A control that's enforced only in JavaScript is not enforced.
- **Proof / Evidence:**
  ```python
  # ai_trigger.py:32-34
  sensitivity_acknowledged: bool = Field(
      False,
      description="User explicitly acknowledged AI sub-processor disclosure for this contract.",
  )
  # scan_orchestrator.py: no `if not sensitivity_acknowledged: return _record_failure(...)` anywhere
  ```
- **Recommended Fix:** Reject at both api-service (per BSO-SEC-029 above) and ai-scanner:
  ```python
  # ai-scanner: in run_ai_scan, after user.ai_consent_at check
  if not sensitivity_acknowledged:
      return await _record_failure(
          session, scan, "ai_sensitivity_ack_required",
          "Per-scan sensitivity acknowledgement is required."
      )
  ```
  And add `failure_type=ai_sensitivity_ack_required` to the failure-type whitelist used by the dashboard label renderer.
- **References:** GDPR Art. 7(1) "controller shall be able to demonstrate that the data subject has consented"; OWASP A04 Insecure Design.

---

### BSO-SEC-032 — Base NetworkPolicy hardcodes production namespace `api-service-prod`

- **Severity:** LOW
- **CWE/OWASP:** CWE-1188 (Insecure Default Initialization of Resource).
- **Location:** `blocksecops-ai-scanner/k8s/base/ai-scanner/networkpolicy.yaml:36`.
- **Description:** The base ingress rule for `ai-scanner-ingress` uses `kubernetes.io/metadata.name: api-service-prod` in the from-namespace selector. Per `kustomize-standards.md`, base manifests must be environment-agnostic; environment-specific values belong in overlays. Currently the GCP overlay also includes the same value, and there's no local overlay yet, so the bug is latent.
- **Impact:** A future "local" overlay author who copies the GCP overlay structure and forgets to patch this rule will configure the local ai-scanner to accept traffic only from a production-namespace label — meaning local api-service can't reach local ai-scanner, breaking dev. Worse, if someone names the production namespace `api-service` (matching the base label by accident), the rule silently allows cross-environment traffic.
- **Proof / Evidence:** File reference above.
- **Recommended Fix:** Replace the namespace label in the base with a placeholder that fails closed if not patched:
  ```yaml
  # base/networkpolicy.yaml
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: __PATCH_ME_API_SERVICE_NS__
        podSelector:
          matchLabels:
            app: api-service
  ```
  Or move the entire from-rule to overlays; in base, ingress is empty (default-deny — fail closed in base, allow in overlay). This is cleaner.
- **References:** `docs/standards/kustomize-standards.md` § base vs overlay.

---

### BSO-SEC-033 — `BYO_KEK` secret material loaded into pod env without any code consumer (least-privilege violation)

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-272 (Least Privilege Violation), CWE-922 (Insecure Storage of Sensitive Information — adjacent).
- **Location:**
  - `blocksecops-ai-scanner/k8s/overlays/gcp/externalsecret.yaml:25-27` (loads `apogee-gcp-byo-kek` → env `BYO_KEK`)
  - `blocksecops-ai-scanner/src/` (zero usage of `BYO_KEK`, no AES-GCM helper, no decrypt path)
  - `scan_orchestrator.py:336-339` (`raise AIProviderError(message="BYO providers not yet supported in Phase 1 — use managed-claude", kind="provider_error")`)
- **Description:** The Phase 10 plan reserves the BYO Key Encryption Key for AES-256-GCM encryption of customer LLM API keys stored in `byo_llm_keys.encrypted_key`. The ExternalSecret correctly syncs `apogee-gcp-byo-kek` from GCP Secret Manager into the pod's env as `BYO_KEK`. But the ai-scanner code has no AES-GCM helper, no encrypt/decrypt service, no test, and no caller — BYO providers explicitly raise an error in `_build_adapter`. The KEK is just sitting in the pod env.
- **Impact:** A live KEK in the pod env is a juicy target for any container escape, supply-chain compromise, or accidental log exposure — and it protects no data today (no BYO key has been encrypted yet). When Phase 2 lands and BYO keys start flowing in, the KEK has already been live in production for weeks. Two failure modes:
  1. KEK leaks before Phase 2 → must rotate KEK before Phase 2 ships → all the Phase-2-encrypted keys are immediately undecryptable (no key history). Cost: customer key-re-entry storm.
  2. The Phase-2 dev assumes "the KEK is in the env, just use it" and doesn't write the same defensive checks (key length, base64 decode, AESGCM construction) that the encryption-standards doc requires.
- **Proof / Evidence:**
  ```bash
  grep -rn "BYO_KEK\|AESGCM\|aes_gcm" /home/pwner/Git/blocksecops-ai-scanner/src/
  # → only the module docstring "Mirror of api-service migration 095. AES-256-GCM encrypted."
  ```
- **Recommended Fix (pick one, not both):**
  - **(A)** Remove the `BYO_KEK` entry from the ExternalSecret until Phase 2 lands. Easy revert: re-add the entry when the encryption service is implemented in the same PR.
  - **(B)** Implement the BYO encryption service NOW, even if `_build_adapter` still rejects BYO providers. The service surface:
    ```python
    # src/infrastructure/security/byo_key_crypto.py
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    import os, base64
    class BYOKeyCrypto:
        def __init__(self) -> None:
            kek_b64 = os.getenv("BYO_KEK", "")
            kek = base64.urlsafe_b64decode(kek_b64) if kek_b64 else b""
            if len(kek) != 32:
                raise RuntimeError("BYO_KEK must decode to exactly 32 bytes (AES-256)")
            self._aead = AESGCM(kek)
        def encrypt(self, plaintext: str) -> tuple[bytes, bytes]:
            nonce = os.urandom(12)
            ct = self._aead.encrypt(nonce, plaintext.encode("utf-8"), None)
            return ct, nonce
        def decrypt(self, ciphertext: bytes, nonce: bytes) -> str:
            return self._aead.decrypt(nonce, ciphertext, None).decode("utf-8")
    ```
    Add a startup check in `main.py` that constructs `BYOKeyCrypto()` and fails-fast on misconfigured KEK. Add unit tests with deterministic vectors. Now the KEK is exercised on every pod start.
- **References:** `docs/standards/encryption-standards.md` § 2 (AES-256-GCM); `docs/standards/secrets-management.md` § least-privilege.

---

### BSO-SEC-034 — `sast_findings` request body is unbounded — `list[dict[str, Any]]` with no `max_length`

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-770 (Allocation of Resources Without Limits), CWE-400 (Uncontrolled Resource Consumption).
- **Location:** `blocksecops-ai-scanner/src/presentation/api/v1/endpoints/ai_trigger.py:36-43`.
- **Description:** The `sast_findings` field accepts an arbitrarily large list of arbitrarily shaped dicts. A caller can pass tens of MB of JSON, which is then JSON-serialized inside `fence_sast_findings` (allocates 2x the size as a Python string), embedded into `user_prompt`, and counted against the org's input token reservation. FastAPI's default `Request` body size limit (typically 1 MB unless overridden) provides some protection, but uvicorn defaults to 16 MB body and the ai-scanner doesn't override.
- **Impact:**
  1. **Quota inflation.** An attacker with the internal-service-token can drain an org's `monthly_input_tokens` budget with a single dispatch — the orchestrator's token estimate is `len(source)//4 + 1500`, but the actual input tokens (after the fenced SAST findings are added) can be vastly higher than the estimate. The atomic UPDATE check uses the conservative estimate, so the org's monthly cap is enforced against the estimate, not the actual. Refund uses the actual, so the difference goes against the org's monthly cap with no recovery.
  2. **Memory pressure on the ai-scanner pod.** 768Mi limit + a multi-megabyte string allocation = OOMKilled. NetworkPolicy makes the recovery clean (pod restart) but the kill switch UX is the same as a real outage.
- **Proof / Evidence:**
  ```python
  # ai_trigger.py:36-43
  sast_findings: list[dict[str, Any]] = Field(
      default_factory=list,
      description="..."
  )  # no max_length, no per-item shape, no recursion depth
  ```
  api-service today passes `"sast_findings": []` (line 2046 of scans.py — placeholder), so today's wire is safe; but the schema permits anything.
- **Recommended Fix:**
  ```python
  from pydantic import Field, conlist

  class SASTFinding(BaseModel):
      # Shape mirrors what api-service will eventually pass —
      # match VulnerabilityModel essentials.
      title: str = Field(..., max_length=200)
      severity: str = Field(..., pattern="^(critical|high|medium|low|info)$")
      file_path: str = Field(..., max_length=500)
      line_number: int = Field(..., ge=0, le=1_000_000)
      detector_id: str | None = Field(None, max_length=200)
      class Config:
          extra = "forbid"

  class AITriggerRequest(BaseModel):
      ...
      sast_findings: list[SASTFinding] = Field(
          default_factory=list,
          max_length=500,
          description="...",
      )
  ```
  And cap the serialized size in `fence_sast_findings`:
  ```python
  def fence_sast_findings(findings: list[dict]) -> str:
      payload = json.dumps(findings, ...)
      if len(payload) > 100_000:  # 100 KiB cap
          payload = payload[:100_000] + "...truncated..."
      ...
  ```
- **References:** OWASP A05 / A04; `docs/standards/secure-coding.md`.

---

### BSO-SEC-035 — `fence_sast_findings` JSON serialization could embed control characters

- **Severity:** LOW
- **CWE/OWASP:** CWE-74 (Improper Neutralization of Special Elements — Injection).
- **Location:** `blocksecops-ai-scanner/src/guardrails/prompt_injection.py:53-62`.
- **Description:** `json.dumps(..., ensure_ascii=False)` permits Unicode control characters (U+0000–U+001F other than the JSON-reserved \b\f\n\r\t\") to flow through into the LLM prompt body. Some control chars are interpreted by the model as whitespace, but specific sequences (RTL override U+202E, BOM U+FEFF, zero-width joiner) have been observed in prompt-injection research to nudge LLM behavior. The fence's CDATA wrapping treats them as data, but the model's attention layer still processes them.
- **Impact:** A SAST finding crafted to contain a prompt-injection payload using control-character tricks can attempt to nudge the LLM's output. The output validator catches malformed output (not in `allowed_files`, beyond-EOF lines, invalid severity), so the exploit upside is small. Combined with the size attack in BSO-SEC-034, it's a hardening line.
- **Recommended Fix:** Use `ensure_ascii=True` (default) when serializing untrusted findings. This is safe — the LLM has no trouble with `‮` style escapes:
  ```python
  payload = json.dumps(findings, separators=(",", ":"), ensure_ascii=True)
  ```
- **References:** OWASP A03; LLM prompt-injection research literature.

---

### BSO-SEC-036 — Internal wheel `blocksecops_tier_config-1.4.0-…whl` installed without checksum verification

- **Severity:** LOW
- **CWE/OWASP:** CWE-353 (Missing Support for Integrity Check), CWE-494 (Download of Code Without Integrity Check — partial; here it's checked-in but not verified).
- **Location:** `blocksecops-ai-scanner/Dockerfile:33-35`.
- **Description:** The internal tier-config wheel is committed to the repo and installed at build time:
  ```dockerfile
  COPY blocksecops_tier_config-1.4.0-py3-none-any.whl /tmp/
  RUN pip install --user /tmp/blocksecops_tier_config-1.4.0-py3-none-any.whl
  ```
  There is no SHA-256 check, no `--require-hashes` constraint, and no Git tag pointing back to the `blocksecops-shared` source revision that produced this wheel. A malicious PR could replace the wheel binary with a backdoored copy and the Docker build would silently install it.
- **Impact:** Tier-config drives all per-tier quota/provider/mode decisions in the AI quota service — a tampered wheel could grant arbitrary providers or unlimited tokens to a tier. Source provenance is currently human-tracked via PR review only.
- **Recommended Fix:**
  ```dockerfile
  COPY blocksecops_tier_config-1.4.0-py3-none-any.whl /tmp/
  RUN echo "<expected-sha256>  /tmp/blocksecops_tier_config-1.4.0-py3-none-any.whl" | sha256sum -c - \
      && pip install --user /tmp/blocksecops_tier_config-1.4.0-py3-none-any.whl
  ```
  Document the expected SHA-256 in `blocksecops-shared` release notes and commit it alongside the wheel. Even better: publish the wheel to an internal PyPI / Artifact Registry Python repo and pin in `requirements/base.txt` with `--require-hashes`.
- **References:** `docs/standards/dependency-management.md`; `docs/standards/docker-base-images.md` § supply-chain hardening.

---

### BSO-SEC-037 — No request-id / correlation-id propagated from api-service → ai-scanner

- **Severity:** INFO (operational hardening)
- **CWE/OWASP:** N/A (not a vulnerability; observability gap with incident-response impact).
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2049` (ai_headers construction).
- **Description:** Cross-service log correlation requires a shared id. The api-service does not pass `X-Request-Id` or `X-Correlation-Id` to the ai-scanner, and the ai-scanner doesn't read one either. Today logs are correlatable only by `scan_id`, which works for the happy path but fails during multi-scan incident analysis.
- **Recommended Fix:** Pass a UUID per request:
  ```python
  ai_headers = {
      "X-Internal-Service-Token": settings.internal_service_key,
      "X-Request-Id": str(uuid4()),
  }
  ```
  And in ai-scanner, read it and include it in `logger.info(..., extra={"request_id": ...})`.
- **References:** `docs/audit/2026-06-19-bso-sec-021-resolution-and-cert-fix-verification.md` "Posture Drift Observation" (operational logging).

---

### BSO-SEC-038 — ai-scanner has no startup validator that fails-fast on missing INTERNAL_SERVICE_KEY in production

- **Severity:** LOW
- **CWE/OWASP:** CWE-1188 (Insecure Default Initialization), CWE-453 (Insecure Default Variable Initialization).
- **Location:** `blocksecops-ai-scanner/src/main.py:38-48` (startup hook).
- **Description:** api-service has `config.py:462-477` that fails startup in production if INTERNAL_SERVICE_KEY is empty or matches a known-insecure placeholder. The ai-scanner has no equivalent — if the ExternalSecret breaks or someone deploys without the secret, the ai-scanner happily serves 401s to every request, looking healthy to liveness probes (which hit `/health/live`, not the auth path).
- **Impact:** Silent outage. Detected only by AI scans failing in user view (after the api-service fire-and-forget already returned 201 Created).
- **Recommended Fix:** Add a startup check:
  ```python
  @app.on_event("startup")
  async def startup() -> None:
      kill_switch = os.getenv("AI_SCANNING_DISABLED", "false").lower() == "true"
      key = os.getenv("INTERNAL_SERVICE_KEY", "")
      env = os.getenv("ENVIRONMENT", "unknown")
      if env == "production" and (not key or key.lower() in {"changeme", "placeholder", "dev", "local"}):
          raise RuntimeError("INTERNAL_SERVICE_KEY missing or placeholder in production")
      logger.info("ai_scanner_startup", extra={...})
  ```
- **References:** `blocksecops-api-service/src/infrastructure/config.py:462-477` (canonical pattern).

---

### BSO-SEC-039 — AI consent column (`users.ai_consent_at`) has no writer endpoint yet, and no audit-log write planned

- **Severity:** INFO (forward-tracking)
- **CWE/OWASP:** N/A (gap finding; will become a real finding when the endpoint lands).
- **Location:** Migration 094 adds `users.ai_consent_at`; no `POST /users/me/ai-consent` or similar endpoint in `blocksecops-api-service/src/presentation/api/v1/endpoints/`.
- **Description:** The phase plan expects users to "acknowledge the AI sub-processor disclosure" before AI scans run. The schema supports this, but there's no API to write the value, and no audit-log row planned to record who acked / when / from which IP. When the writer endpoint lands, it MUST:
  1. Be `require_auth_with_scope(...)` per `api-endpoint-auth.md`.
  2. Be rate-limited (no spam-clicking consent on/off).
  3. Write an `AuditLogModel` row with the IP, user-agent, and timestamp — same pattern as `consent.py` does for ToS consent.
- **Recommended Fix:** File a Phase-10-follow-up ticket. Verify the endpoint design before merge.
- **References:** `docs/standards/api-endpoint-auth.md`; `docs/standards/organization-team-user-hierarchy.md`.

---

### BSO-SEC-040 — AI dispatch is fire-and-forget; ai-scanner timeout or 5xx leaves scan stuck at `status='queued'`

- **Severity:** MEDIUM
- **CWE/OWASP:** CWE-754 (Improper Check for Unusual or Exceptional Conditions), CWE-636 (Not Failing Securely).
- **Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2051-2078`.
- **Description:** The api-service dispatches the AI scan via `asyncio.create_task(_fire_ai_trigger(...))` with a 180-second httpx timeout. On timeout, network failure, or ai-scanner 5xx, the api-service log records the failure but the **scan row** stays at `status='queued'` forever — because the ai-scanner orchestrator never got to write the `failure_type=ai_system_error` row.
- **Impact:**
  1. Customer scan UX: stuck-queued scans confuse the dashboard's status label (which can't distinguish "queued and being processed" from "queued and abandoned").
  2. The api-service's quota counter (`UserQuotaModel.monthly_scans_used`) is NOT incremented at scan-creation time (per the comment at scans.py:1877-1879), so abandoned scans don't burn user quota. Good.
  3. The ai-scanner's `organizations.ai_input_tokens_used` IS reserved before the LLM call — if the dispatch never reaches the ai-scanner, the reservation never happens. Good.
  4. But if the ai-scanner crashes mid-flight AFTER reservation and BEFORE `_record_failure`, the reservation is never refunded (no orphan cleanup). Tokens are silently consumed.
- **Recommended Fix (one or both):**
  - **(Short term)** In `_fire_ai_trigger`'s exception path, write the scan row to `status='failed', failure_type='ai_dispatch_failed'`:
    ```python
    except Exception as e:
        logger.error(f"AI scanner dispatch background-task failed for scan {scan_id_str}: {e}")
        async with get_async_session() as session:
            await session.execute(
                text("UPDATE scans SET status='failed', failure_type='ai_dispatch_failed', error_message=:msg WHERE id=:sid AND status='queued'"),
                {"msg": str(e)[:2000], "sid": scan_id_str},
            )
            await session.commit()
    ```
  - **(Medium term)** Move AI dispatch to the Celery worker per the comment at `scans.py:2997-3001`. The same fix that was applied to dedup ("completely isolates from the API event loop") applies word-for-word to AI dispatch, which is a 30-120s LLM call. The event-loop sharing of `asyncio.create_task` is a known anti-pattern for long-running work in FastAPI.
  - **(Long term)** Add a Celery beat task that scans for `status='queued' AND created_at < now() - interval '5 minutes' AND 'ai' = ANY(scanners_used)` and marks them failed.
- **References:** `scans.py:2997-3001` (same lesson learned for dedup); BSO-STABILITY-001 / BSO-ARCH-001.

---

## Positive Observations

1. **Schema defaults are restrictive end-to-end** (org-enabled false, user-consent NULL, contract-disabled false → opt-in everywhere). The migration comment explicitly cites `secure-coding.md § A04`. This is exactly the right posture for a new processing surface.
2. **Atomic UPDATE … RETURNING for quota reservation** is the correct pattern; race-free across concurrent scans. Disambiguation between "org not opted in" and "monthly cap hit" via a second SELECT is correct (the failure types map to different dashboard UI).
3. **Prompt injection defense is layered:** XML+CDATA fence, boundary escape, attribute escape, then the system-prompt rule 1 explicitly tells the model to treat the source as data. Then the output validator rejects malformed output. Three layers — that's the right architecture.
4. **Output validator is strict:** allowed-files set, line ≤ EOF, severity whitelist, SWC regex, length caps on every text field. This will catch jailbreak-induced garbage cleanly.
5. **Refund semantics are correct in every branch** (full refund on system error, partial on safety-blocked, unused-portion on success/output-invalid). The math (`max(0, …)`, `GREATEST(0, …)` in SQL) is defensive against double-refund races.
6. **Pinned base image digest matches api-service.** Supply-chain parity. `python:3.13-slim@sha256:f50f56f1…` is the same digest both services use.
7. **OCI labels + read-only root + drop-ALL caps + non-root user + seccomp RuntimeDefault** — full house on container hardening.
8. **Kill switch is wired in three places** (env-var startup log, `/ready` probe, endpoint-level 503). Operationally easy: flip a ConfigMap key + rollout restart. No code changes needed.
9. **`ai-scanner` does not have any egress path back to api-service or other internal services** — limits blast radius from a hypothetical LLM-output SSRF attack. The metadata IP (169.254.169.254) is correctly excluded from the LLM-providers egress.
10. **Cost is recorded per-scan (`cost_usd_micros`)** with a clear path to billing reconciliation. The ON CONFLICT clause for metadata upserts correctly updates cost on the UPDATE branch as well.

---

## Follow-ups

- [ ] **BSO-SEC-028 CRITICAL** — patch `secrets.compare_digest` into ai-scanner `_verify_internal_token`. Ship before any external customer sees the AI scanner. **Owner: ai-scanner service owner.**
- [ ] **BSO-SEC-029 HIGH** — add server-side AI pre-check in api-service `create_scan` (org-enabled, consent, contract-disabled, tier, sensitivity-ack). **Owner: api-service service owner.**
- [ ] **BSO-SEC-030 MEDIUM** — convert overlay `networkpolicy-ingress-patch.yaml` to a JSON-patch, OR add an explicit "this replaces base" comment header. **Owner: ai-scanner / infra.**
- [ ] **BSO-SEC-031 MEDIUM** — enforce `ai_sensitivity_acknowledged` at the server (in BOTH api-service pre-check and ai-scanner orchestrator); add `ai_sensitivity_ack_required` failure_type to the dashboard label renderer. **Owner: api-service + ai-scanner + dashboard.**
- [ ] **BSO-SEC-032 LOW** — move the api-service-prod namespace label out of base NetworkPolicy and into the GCP overlay only. **Owner: ai-scanner / infra.**
- [ ] **BSO-SEC-033 MEDIUM** — either remove `BYO_KEK` from the ExternalSecret until Phase 2, or implement the BYO encryption service this sprint. Add a startup validator that constructs `BYOKeyCrypto()` so the KEK is exercised on every pod start. **Owner: ai-scanner.**
- [ ] **BSO-SEC-034 MEDIUM** — bound `sast_findings`: typed Pydantic model, `max_length=500`, serialized-payload cap of 100 KiB in `fence_sast_findings`. **Owner: ai-scanner.**
- [ ] **BSO-SEC-035 LOW** — set `ensure_ascii=True` in `fence_sast_findings` JSON dump. **Owner: ai-scanner.**
- [ ] **BSO-SEC-036 LOW** — add SHA-256 checksum verification to the `blocksecops_tier_config` wheel install in Dockerfile. **Owner: ai-scanner / blocksecops-shared.**
- [ ] **BSO-SEC-037 INFO** — propagate `X-Request-Id` from api-service → ai-scanner; log in both. **Owner: api-service + ai-scanner.**
- [ ] **BSO-SEC-038 LOW** — add startup validator to ai-scanner `main.py` that fails-fast on missing/placeholder `INTERNAL_SERVICE_KEY` in production. **Owner: ai-scanner.**
- [ ] **BSO-SEC-039 INFO** — when the `ai_consent_at` writer endpoint is implemented, ensure it uses `require_auth_with_scope`, is rate-limited, and writes an `AuditLogModel` row with IP + user-agent. **Owner: api-service.**
- [ ] **BSO-SEC-040 MEDIUM** — short-term: write `failure_type=ai_dispatch_failed` in `_fire_ai_trigger`'s exception path. Medium-term: move AI dispatch to Celery (same pattern as the dedup fix at `scans.py:2997-3001`). Long-term: stale-scan reaper. **Owner: api-service.**

---

**Generated:** 2026-06-20 (apogee-security-audit / Opus 4.7)
**Related TaskDoc:** `~/Git/TaskDocs-BlockSecOps/phases/10-phase-10-byo-ai-scanning/SECURITY-FOLLOWUPS-2026-06-20.md`
