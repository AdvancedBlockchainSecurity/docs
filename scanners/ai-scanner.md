# AI Scanner

**Service:** `blocksecops-ai-scanner`
**Version:** 0.2.4 (2026-06-20)
**Tier availability:** `starter` (managed-claude, limited quota), `growth` (managed-claude, standard quota), `enterprise` (managed-claude, high quota + BYO providers in Phase 2)
**scanner_id:** `ai` (prefix used in dispatch; findings tagged `ai-<provider>-<model>` e.g. `ai-managed-claude-sonnet-4-6`)
**Phase 1 status:** Managed-claude path live. BYO providers (anthropic, openai, gemini) return `ai_provider_error` and are marked Phase 2 in the dashboard.

---

## What it does

The AI scanner sends a contract's source code, import graph, existing SAST findings, and a dedup fingerprint to an LLM with an Apogee-owned structured prompt. The model reasons over the full semantic context — something SAST rule engines cannot do — and returns a JSON array of findings that go through the same output validation, FP model triage, and `vulnerabilities` table insertion as every other scanner.

The scanner is not a replacement for SAST tools. It is a complement that catches vulnerabilities requiring multi-step reasoning:

| Category | Example | Why SAST misses it |
|---|---|---|
| Oracle staleness under specific access patterns | Chainlink price feed consumed only on stale side-effect paths | Requires tracing economic context, not just call graphs |
| Vault inflation / share-price manipulation | ERC-4626 vault where direct `transfer()` to vault inflates share price before the first depositor | Multi-contract interaction; SAST sees no dangerous call |
| MEV front-running | Swap function with predictable slippage tolerance readable from pending-tx calldata | Requires understanding of mempool economics |
| Unprotected initialization | `initialize()` callable by anyone after deployment | Access-control check present but on wrong function variant |
| Specification drift | Contract behavior diverges from NatSpec invariants | Requires reading prose and code together |

---

## Confidence scoring

Each AI finding has a `confidence` field set by the output schema validator based on the model's self-reported certainty and the validator's structural checks:

| Confidence level | Numeric threshold | Meaning |
|---|---|---|
| `high` | 0.95 | Model expressed high certainty; line numbers verified; finding matches a known vulnerability pattern in the dedup fingerprint corpus |
| `medium` | 0.70 | Model expressed moderate certainty or finding is a novel pattern not in the dedup corpus |
| `low` | 0.40 | Model hedged significantly, or line numbers required clamping to be valid, or the finding could not be cross-referenced with SAST output |

Confidence does not map directly to severity. A `low`-confidence `critical` finding still appears in the findings list and is routed to the FP model — the confidence field informs the reviewer, it does not suppress the finding.

---

## Integration with the FP triage model

AI findings enter the FP pipeline identically to SAST findings:

1. `vulnerabilities` row inserted with `scanner_id` prefix `ai-`.
2. The FP classifier scores the finding using its existing 30+ features. AI findings tend to have higher lexical novelty (lower n-gram match with training data) — the classifier currently treats this as a mild signal toward "review needed" rather than FP.
3. The finding appears in the dashboard's finding list with an **AI badge** (rendered by `AIBadge` component when `scanner_id.startsWith('ai-')`).
4. Reviewers can triage, suppress, or accept exactly as with SAST findings.

The ML review queue (`docs/pipelines/ml-review-queue-pipeline.md`) handles AI findings without special casing. Flagging a finding as a confirmed FP or TP adds it to the next FP-model training batch.

---

## Prompt versioning

Prompts live in `src/prompts/` and are versioned independently of the service (e.g. `solidity/v1/structured.md`). The prompt version is stored in `ai_scan_metadata.prompt_version` so historical scans remain attributable to the exact prompt that ran. Prompt changes require a code review and version bump in `src/prompts/` — they do not require a full service release, but the service must be redeployed to pick them up.

---

## What the AI scanner does not do

- It does not replace Slither, Aderyn, SolidityDefend, or other SAST scanners. Run both.
- It does not scan Vyper or Move contracts in Phase 1 (Solidity prompt only).
- It does not stream findings in real time (Phase 4 roadmap).
- It does not accept user-supplied prompts. Prompts are Apogee IP.
- It does not run on contracts with `ai_processing_disabled=true`.

---

## Token cost reference (Phase 1, managed-claude)

Live measurement from the Phase 10 e2e verification scan (contract `3cd9e3ac-082d-450c-a888-bd85009c63e8`, 8 findings, 37s wall):

| Metric | Value |
|---|---|
| Model | claude-sonnet-4-6 |
| Approximate cost | $0.052 per scan |
| Wall time | 37s |

Costs vary with contract size. The per-tier `perScanInputTokenCap` in `tiers.json` bounds the maximum cost per individual scan.

---

## Cross-references

- `docs/workflows/ai-scan-trigger-workflow.md` — end-to-end trigger flow and failure modes
- `docs/pipelines/ai-scanner-build-pipeline.md` — build, deploy, NetworkPolicy
- `docs/playbooks/ai-cost-kill-switch.md` — emergency cost control
- `docs/playbooks/ai-quota-exhausted-runbook.md` — quota triage
- `docs/database/SCHEMA.md` — `ai_scan_metadata` and `byo_llm_keys` tables
- `blocksecops-ai-scanner/README.md` — operator reference
