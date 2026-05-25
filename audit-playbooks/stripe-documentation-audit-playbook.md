# Stripe Documentation Audit Playbook

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Reusable, end-to-end audit of every Stripe-related documentation surface — drift detection (price IDs across `tiers.json` / `config.py` / dashboard types), broken links, code-reference verification, standards-conformance.
**Audience:** Operator (owner) — invokes the `apogee-documentation` agent and follows this procedure
**Audit Type:** documentation

---

## ⚠️ Mandatory End-to-End Execution

**This audit MUST be run from beginning to end without skipping any phase, even if it was executed recently.** Each phase produces evidence the next phase depends on. Skipping invalidates the audit report. If a phase fails, fix the underlying issue and re-run **from Phase 1** — do not patch and resume mid-audit.

When the owner says "run the Stripe documentation audit," every phase below runs.

---

## Overview

This playbook orchestrates a Stripe-scoped documentation audit using the `apogee-documentation` agent (see `docs/.claude/agents/apogee-documentation.md`). It catches drift between authoritative sources (`tiers.json`, `config.py`, dashboard types) and the docs that describe them, verifies that every code citation in Stripe docs still exists, checks for broken cross-links, and confirms each Stripe doc cites the relevant `docs/standards/` files.

Output is a documentation update report at `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-YYYY-MM-DD-stripe-audit.md` per the agent's output convention.

---

## Prerequisites

- [ ] Repos cloned and current: `blocksecops-api-service`, `blocksecops-shared`, `blocksecops-dashboard`, `docs`, `TaskDocs-BlockSecOps`
- [ ] Owner approval to invoke `apogee-documentation` agent (Rule 0)
- [ ] Read access to `tiers.json`, `config.py`, `stripe.d.ts`
- [ ] Markdown link checker available (`markdown-link-check` or equivalent)
- [ ] No edits to existing Stripe docs during the audit; this playbook only reports drift

---

## Standards Referenced

- `docs/standards/documentation-standards.md`
- `docs/standards/blocksecops-style-guide.md`
- `docs/standards/api-endpoint-auth.md` (must be cited by Stripe security/functionality docs)
- `docs/standards/secure-coding.md` (must be cited by Stripe security docs)
- `docs/standards/encryption-standards.md` (must be cited by Stripe security docs)
- `docs/standards/secrets-management.md` (must be cited by Stripe security docs)
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-03-01-F12-HSTS-FIX.md` — example of the agent's output format
- `docs/audit/comprehensive-audit-2026-03-15.md`
- The most recent `docs/audit/YYYY-MM-DD-stripe-*` reports — for cross-link verification

---

## Stripe Doc Surface (audit scope)

The 14 existing Stripe-mentioning docs (do **not** edit; only audit):

**Workflows:**
- `docs/workflows/stripe-dashboard-purchase-workflow.md`
- `docs/workflows/billing-subscription-workflow.md`
- `docs/workflows/subscription-workflow.md`
- `docs/workflows/tier-purchasing-workflow.md`
- `docs/workflows/tier-upgrading-workflow.md`
- `docs/workflows/referral-system-workflow.md`

**Pipelines:**
- `docs/pipelines/billing-feature-pipeline.md`
- `docs/pipelines/subscription-pipeline.md`
- `docs/pipelines/referral-system-pipeline.md`

**Playbooks:**
- `docs/playbooks/stripe-dashboard-purchase-playbook.md`
- `docs/playbooks/stripe-payment-setup.md`
- `docs/playbooks/stripe-test-subscriptions.md`
- `docs/playbooks/adjust-pricing.md`
- `docs/playbooks/referral-system.md`

**Pricing:** `docs/pricing/pricing-tiers.md`, `docs/pricing/x402-credits.md`
**Feature tests:** `docs/feature-tests/37-stripe-billing.md`, `docs/feature-tests/52-dual-payment-options.md`
**Standards:** `docs/standards/tier-standards.md`

Plus the new audit suite (`docs/audit-playbooks/stripe-*.md`, `docs/audit-workflows/stripe-*.md`, `docs/audit-pipelines/stripe-*.md`).

---

## Phase 1: Drift Detection (sources of truth ↔ docs)

### 1.1 Three-way price ID match

| # | Test | Expected | Status |
|---|------|----------|--------|
| 1.1.1 | Each subscription price ID in `blocksecops-shared/tier-config/tiers.json` matches the env var name in `blocksecops-api-service/src/infrastructure/config.py` | One-to-one mapping | [ ] |
| 1.1.2 | Each price ID name documented in `docs/pricing/pricing-tiers.md` matches `tiers.json` | Match | [ ] |
| 1.1.3 | Dashboard `src/types/stripe.d.ts` exposes the same price ID enum/keys | Match | [ ] |
| 1.1.4 | Each credit package in `tiers.json` has a Stripe price ID and is referenced in `docs/pricing/x402-credits.md` | Match | [ ] |
| 1.1.5 | Tier amounts in `docs/pricing/pricing-tiers.md` ($199/$499/$1,499 monthly; $2,028/$5,028 annual) match `tiers.json` | Match | [ ] |

**Verification:** `docs/audit-pipelines/stripe-documentation-audit-pipeline.md` Phase 1.

**Evidence to capture:** Diff table — drift items become `TaskDocs-BlockSecOps/` tickets, not in-place edits.

---

## Phase 2: Broken-link Sweep

### 2.1 Cross-doc link integrity

| # | Test | Expected | Status |
|---|------|----------|--------|
| 2.1.1 | Run markdown link check across every Stripe-mentioning doc above | Zero broken internal links | [ ] |
| 2.1.2 | Every `docs/workflows/*stripe*.md` link to `docs/playbooks/*` resolves | Match | [ ] |
| 2.1.3 | Every `docs/playbooks/*stripe*.md` link to `docs/pipelines/*` resolves | Match | [ ] |
| 2.1.4 | Every link in the new `docs/audit-{playbooks,workflows,pipelines}/stripe-*.md` files resolves | Match | [ ] |
| 2.1.5 | External links (Stripe docs, OWASP) returned 200 in last sweep OR are documented as known-stable | Each external link annotated | [ ] |

**Evidence to capture:** Link checker output; broken-link list with source file:line.

---

## Phase 3: Code-reference Verification

### 3.1 Every `file:line` citation in Stripe docs still exists

| # | Test | Expected | Status |
|---|------|----------|--------|
| 3.1.1 | Extract every `repo/path:line` and `repo/path` reference from Stripe docs | List produced | [ ] |
| 3.1.2 | For each `path:line`, the file exists and the cited line is plausibly the cited content (function/class name match) | Resolves | [ ] |
| 3.1.3 | For each `path` (no line), the file exists | Resolves | [ ] |
| 3.1.4 | References to `stripe_service.py`, `stripe_webhook.py`, `billing.py`, `payments.py`, `models.py` all resolve | Resolves | [ ] |
| 3.1.5 | References to webhook event names match the 6 events handled in `stripe_webhook.py` | Match | [ ] |

**Evidence to capture:** Reference table; unresolved citations filed as drift.

---

## Phase 4: Standards-conformance

### 4.1 Stripe docs cite required standards

| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.1.1 | Every Stripe security-relevant doc cites `docs/standards/api-endpoint-auth.md` | Citation present | [ ] |
| 4.1.2 | Every Stripe security-relevant doc cites `docs/standards/secure-coding.md` | Citation present | [ ] |
| 4.1.3 | Stripe secret-handling docs cite `docs/standards/secrets-management.md` and `docs/standards/encryption-standards.md` | Citations present | [ ] |
| 4.1.4 | Stripe pricing docs cite `docs/standards/tier-standards.md` | Citation present | [ ] |
| 4.1.5 | Stripe deployment-related docs cite `docs/standards/docker-image-versioning.md` (Dashboard build args section) and `docs/standards/kustomize-standards.md` | Citations present | [ ] |
| 4.1.6 | Stripe DB-touching docs cite `docs/standards/database-management.md` | Citation present | [ ] |

**Evidence to capture:** Citation matrix; missing citations filed as drift.

---

## Phase 5: Style & Format Conformance

### 5.1 Docs match documentation standards

| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.1.1 | Every Stripe doc has frontmatter (Version, Last Updated, Status) per `documentation-standards.md` | Present | [ ] |
| 5.1.2 | Headings use `##` hierarchy without skipped levels | Conforms | [ ] |
| 5.1.3 | Code blocks specify language fences | Conforms | [ ] |
| 5.1.4 | No Cairo references (per `feedback_no_cairo.md`) — flag any as cleanup | Cleanup tickets filed | [ ] |
| 5.1.5 | No `blocksecops_com` references in audit scope (per `feedback_com_out_of_scope.md`) | Conforms | [ ] |

---

## Audit Report Template

Copy this into `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-YYYY-MM-DD-stripe-audit.md`.

```markdown
# Stripe Documentation Audit — YYYY-MM-DD

**Author:** apogee-documentation
**Scope:** Every Stripe-mentioning doc under docs/ (workflows, pipelines, playbooks, pricing, feature-tests, standards/tier-standards.md, audit-playbooks/, audit-workflows/, audit-pipelines/). Plus three-way drift check against tiers.json / config.py / dashboard types.
**Standards referenced:** see Standards Referenced section of `docs/audit-playbooks/stripe-documentation-audit-playbook.md`

## Executive Summary
<2–4 sentences>

## Phase-by-phase Results
| Phase | Outcome | Drift Count |
|-------|---------|-------------|
| 1 Drift detection | Pass/Fail | N |
| 2 Broken links | Pass/Fail | N |
| 3 Code references | Pass/Fail | N |
| 4 Standards conformance | Pass/Fail | N |
| 5 Style & format | Pass/Fail | N |

## Drift Items (filed as separate tickets)
| ID | Source doc | Drift type | Recommended fix | Ticket |
|----|------------|------------|-----------------|--------|
| 1 | <doc> | <e.g., stale price ID> | <fix> | <TaskDocs-BlockSecOps/...> |

## Citation Matrix Gaps
| Doc | Missing citation | Priority |
|-----|------------------|----------|
| ... | ... | ... |

## Follow-ups
- [ ] <actionable item tied to owner>
```

---

## Failure Handling

If any phase fails:
1. Stop. Do not advance.
2. File each drift item as a separate ticket in `TaskDocs-BlockSecOps/` (do not edit Stripe docs in-line during this audit).
3. Owner approves each fix individually (per `feedback_gitops_each_step_approval.md`).
4. After fixes are merged, re-run the **full** audit from Phase 1.

---

## Related Docs

- `docs/audit-playbooks/stripe-full-audit-playbook.md` — orchestrator
- `docs/audit-pipelines/stripe-documentation-audit-pipeline.md` — exact commands per phase
- `docs/.claude/agents/apogee-documentation.md`
- `docs/standards/documentation-standards.md`
- `docs/standards/blocksecops-style-guide.md`
