# Stripe Documentation Audit Pipeline

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Sequenced technical/automation steps that the documentation audit playbook orchestrates — drift detection (`tiers.json` ↔ `config.py` ↔ dashboard types ↔ docs), broken-link checking, code-reference resolution, standards-conformance grep.
**Audience:** `apogee-documentation` agent + operator
**Audit Type:** documentation (technical sequence)

---

## ⚠️ Mandatory End-to-End Execution

**This pipeline MUST be executed from beginning to end without skipping any step, even if it was run recently.** Each step's output (drift list, broken link list) feeds the report. Skipping invalidates results. If a step fails or surfaces drift, file the drift items as tickets and re-run **from Phase 1** of `docs/audit-playbooks/stripe-documentation-audit-playbook.md` after fixes are merged.

---

## Overview

This pipeline is the technical companion to `docs/audit-playbooks/stripe-documentation-audit-playbook.md`. The playbook describes *what* to audit and *why*; this pipeline describes *how* — exact `jq` / `grep` / link-checker commands.

This pipeline is **read-only**. Drift items are filed as `TaskDocs-BlockSecOps/` tickets per the `apogee-documentation` agent convention; existing Stripe docs are not edited during the audit.

---

## Prerequisites

See `docs/audit-playbooks/stripe-documentation-audit-playbook.md` Prerequisites. Plus:

- [ ] `jq` installed
- [ ] `markdown-link-check` (or equivalent) installed
- [ ] All repos cloned and current

---

## Standards Referenced

- `docs/standards/documentation-standards.md`
- `docs/standards/blocksecops-style-guide.md`
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-03-01-F12-HSTS-FIX.md` — agent output format reference

---

## Phase 1 — Drift Detection

### 1.1 Three-way price ID check

```bash
# 1.1.1 tiers.json price IDs
echo "=== tiers.json subscription price IDs ==="
jq -r '.tiers[] | select(.stripe_price_ids != null) | .id as $tier | .stripe_price_ids | to_entries[] | "\($tier).\(.key) = \(.value)"' \
  /home/pwner/Git/blocksecops-shared/tier-config/tiers.json

# config.py env var names
echo "=== config.py STRIPE_PRICE_* fields ==="
grep -nE "stripe_price_[a-z_]+" /home/pwner/Git/blocksecops-api-service/src/infrastructure/config.py

# Dashboard types
echo "=== dashboard stripe.d.ts price exports ==="
grep -nE "STRIPE_PRICE_|priceId" /home/pwner/Git/blocksecops-dashboard/src/types/stripe.d.ts 2>/dev/null

# Manual diff: each tiers.json entry should have a config.py field and a dashboard reference
```

### 1.2 Credit packages

```bash
echo "=== tiers.json credit packages ==="
jq -r '.credit_packages[]? | "\(.id): price=\(.stripe_price_id) credits=\(.credits)"' \
  /home/pwner/Git/blocksecops-shared/tier-config/tiers.json

echo "=== docs/pricing/x402-credits.md packages mentioned ==="
grep -nE "stripe_price|credits|package" /home/pwner/Git/docs/pricing/x402-credits.md
```

### 1.3 Tier amounts

```bash
echo "=== tiers.json amounts ==="
jq -r '.tiers[] | {id, monthly: .pricing.monthly_usd, annual: .pricing.annual_usd}' \
  /home/pwner/Git/blocksecops-shared/tier-config/tiers.json

echo "=== docs/pricing/pricing-tiers.md amounts ==="
grep -nE "\\\$[0-9,]+" /home/pwner/Git/docs/pricing/pricing-tiers.md | head -30
```

**Capture:** Drift table with source-of-truth value vs documented value per row.

---

## Phase 2 — Broken-link Sweep

```bash
# 2.1 Run markdown-link-check across the Stripe doc surface
DOCS=(
  /home/pwner/Git/docs/workflows/stripe-dashboard-purchase-workflow.md
  /home/pwner/Git/docs/workflows/billing-subscription-workflow.md
  /home/pwner/Git/docs/workflows/subscription-workflow.md
  /home/pwner/Git/docs/workflows/tier-purchasing-workflow.md
  /home/pwner/Git/docs/workflows/tier-upgrading-workflow.md
  /home/pwner/Git/docs/workflows/referral-system-workflow.md
  /home/pwner/Git/docs/pipelines/billing-feature-pipeline.md
  /home/pwner/Git/docs/pipelines/subscription-pipeline.md
  /home/pwner/Git/docs/pipelines/referral-system-pipeline.md
  /home/pwner/Git/docs/playbooks/stripe-dashboard-purchase-playbook.md
  /home/pwner/Git/docs/playbooks/stripe-payment-setup.md
  /home/pwner/Git/docs/playbooks/stripe-test-subscriptions.md
  /home/pwner/Git/docs/playbooks/adjust-pricing.md
  /home/pwner/Git/docs/playbooks/referral-system.md
  /home/pwner/Git/docs/pricing/pricing-tiers.md
  /home/pwner/Git/docs/pricing/x402-credits.md
  /home/pwner/Git/docs/feature-tests/37-stripe-billing.md
  /home/pwner/Git/docs/feature-tests/52-dual-payment-options.md
  /home/pwner/Git/docs/standards/tier-standards.md
)
for d in "${DOCS[@]}"; do
  echo "=== $d ==="
  markdown-link-check -q "$d" 2>&1 | grep -E "FILE:|✖|→ Status:"
done

# 2.2 New audit suite link check
for d in /home/pwner/Git/docs/audit-playbooks/stripe-*.md \
         /home/pwner/Git/docs/audit-workflows/stripe-*.md \
         /home/pwner/Git/docs/audit-pipelines/stripe-*.md; do
  echo "=== $d ==="
  markdown-link-check -q "$d" 2>&1 | grep -E "FILE:|✖"
done
```

**Capture:** Broken-link list with source file:line.

---

## Phase 3 — Code-reference Resolution

```bash
# 3.1 Extract every "repo/path:line" and "repo/path" reference from Stripe docs
echo "=== References in Stripe doc surface ==="
grep -hnE 'blocksecops-[a-z-]+/[a-zA-Z0-9_./-]+\.(py|ts|tsx|json|yaml|md)(:[0-9]+)?' "${DOCS[@]}" \
  /home/pwner/Git/docs/audit-playbooks/stripe-*.md \
  /home/pwner/Git/docs/audit-workflows/stripe-*.md \
  /home/pwner/Git/docs/audit-pipelines/stripe-*.md \
  | sort -u > /tmp/stripe_doc_refs.txt
wc -l /tmp/stripe_doc_refs.txt

# 3.2 For each reference, check the file exists
while IFS= read -r line; do
  ref=$(echo "$line" | grep -oE 'blocksecops-[a-z-]+/[a-zA-Z0-9_./-]+\.(py|ts|tsx|json|yaml|md)' | head -1)
  [ -z "$ref" ] && continue
  full="/home/pwner/Git/$ref"
  [ -f "$full" ] || echo "MISSING: $ref (cited at $line)"
done < /tmp/stripe_doc_refs.txt

# 3.3 Webhook event names — must match handler implementation
echo "=== Webhook event names in docs ==="
grep -hoE "(checkout\.session\.completed|customer\.subscription\.(updated|deleted)|invoice\.payment_(succeeded|failed)|customer\.updated)" \
  "${DOCS[@]}" | sort -u

echo "=== Events handled in stripe_webhook.py ==="
grep -oE '"(checkout\.session\.completed|customer\.subscription\.[a-z]+|invoice\.payment_[a-z]+|customer\.updated)"' \
  /home/pwner/Git/blocksecops-api-service/src/presentation/api/v1/endpoints/stripe_webhook.py 2>/dev/null | sort -u
# Expected: doc set ⊆ implementation set (no docs reference unhandled events)
```

**Capture:** Missing-reference list; webhook event coverage diff.

---

## Phase 4 — Standards-conformance

```bash
REQUIRED=(
  "docs/standards/api-endpoint-auth.md"
  "docs/standards/secure-coding.md"
  "docs/standards/encryption-standards.md"
  "docs/standards/secrets-management.md"
  "docs/standards/tier-standards.md"
  "docs/standards/database-management.md"
)

for d in "${DOCS[@]}"; do
  echo "=== $d ==="
  for std in "${REQUIRED[@]}"; do
    if grep -q "$std" "$d"; then
      echo "  [x] $std"
    else
      echo "  [ ] $std (MISSING)"
    fi
  done
done
```

**Capture:** Citation matrix; missing-citation list per doc.

---

## Phase 5 — Style & Format Conformance

```bash
# 5.1.1 Frontmatter
for d in "${DOCS[@]}"; do
  if ! head -10 "$d" | grep -qE "(^\\*\\*Version:|^Version:)"; then
    echo "MISSING-FRONTMATTER: $d"
  fi
done

# 5.1.2 Skipped heading levels
for d in "${DOCS[@]}"; do
  awk '/^#{1,6} / { lvl=length($0)-length(ltrim($0,"#")); if (lvl > prev+1 && prev>0) print FILENAME":"NR" skipped level "prev"->"lvl; prev=lvl }' "$d"
done

# 5.1.3 Code-block language fences
grep -nE '^\`\`\`$' "${DOCS[@]}" 2>/dev/null
# Expected: zero matches (every fence should specify language)

# 5.1.4 Cairo references (cleanup tickets)
grep -lEi "cairo|starknet" "${DOCS[@]}" 2>/dev/null

# 5.1.5 blocksecops_com out-of-scope references
grep -lEi "blocksecops_com|blocksecops\.com" "${DOCS[@]}" 2>/dev/null
```

**Capture:** Style violation list per doc.

---

## Output

Pipeline does not produce its own report. Evidence is consumed by `stripe-documentation-audit-playbook.md` and embedded in `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-YYYY-MM-DD-stripe-audit.md` per the documentation agent's output convention.

---

## Failure Handling

If any step surfaces drift:
1. **Do not edit Stripe docs in-line during the audit.** File each drift item as a separate ticket in `TaskDocs-BlockSecOps/`.
2. Owner approves each fix individually (per `feedback_gitops_each_step_approval.md`).
3. After fixes are merged, re-run the **full** audit from Phase 1 of the playbook.

---

## Related Docs

- `docs/audit-playbooks/stripe-documentation-audit-playbook.md`
- `docs/.claude/agents/apogee-documentation.md`
- `docs/standards/documentation-standards.md`
- `docs/standards/blocksecops-style-guide.md`
