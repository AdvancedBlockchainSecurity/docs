# Playbook: Ship with Linear (/ship)

**Version:** 1.0.0
**Last Updated:** 2026-06-21
**Status:** Active
**Cross-reference:** `/home/pwner/Git/.claude/commands/ship.md` (runtime skill), `docs/workflows/ship-cycle-workflow.md`

---

## Overview

The `/ship` skill runs the Apogee full ship cycle: it discovers or creates Linear tickets for each work item, then walks eight sequential phases — changelog, security audit, test coverage, documentation update, standards verification, commit/PR/merge, and deploy/verify — before closing the Linear tickets as Done.

This playbook tells the operator what to expect at each phase, where approval gates fall, how to handle partial failures, and how to backfill Linear tickets for changes that shipped before /ship existed.

---

## Prerequisites

- Claude Code session open with the `Advanced Blockchain Security` Linear workspace accessible (the `plugin:linear:linear` MCP server must be loaded — verify with `/reload-plugins`)
- Pending changes in one or more repos under `~/Git/`
- `gh` CLI authenticated and pointing at the correct GitHub user
- `kubectl` context set to the GCP cluster (`kubectl config current-context`)
- Test account credentials available as `$TEST_PASSWORD` (session-only — never hardcode per `feedback_trigger_scans_via_api.md`)

---

## Invoking /ship

```
/ship
```

No arguments are required. The skill reads the current state of the working tree across all repos under `~/Git/` and determines what needs to ship.

If you want to scope the run to a specific change or set of repos, describe the scope in plain text before running `/ship` so the skill can narrow its Phase 0 ticket enumeration.

---

## Phase-by-Phase Reference

### Phase 0 — Linear Ticket Discovery / Creation

**What happens:** The skill enumerates all work items in the current cycle. For each, it searches Linear for an existing ticket before creating a new one. Every ticket receives a Priority, at least one `type:*` label, at least one `repo:*` label, `source:ship-cycle`, and `phase:in-progress`.

**Operator action:** Review the ticket map the skill prints:

```
| Work item | Linear ticket | Priority | Project |
|---|---|---|---|
| Fix X | ADV-42 | P2 High | Apogee Core Platform |
```

Confirm coverage looks correct. If a work item is missing or a ticket maps to the wrong project, tell the skill before it proceeds to Phase 1. This is the cheapest point to correct the ticket structure.

**Gate:** The skill pauses for operator confirmation of the ticket map.

---

### Phase 1 — Changelog

**What happens:** An entry is appended to `~/Git/CHANGELOG.md` with today's date. Each bullet maps to a Linear ticket and ends with `(ADV-NNN)`. A comment is posted to each affected ticket.

**Operator action:** Review the changelog entry the skill outputs. Confirm it accurately describes the changes before the skill continues.

**Gate:** The skill outputs the entry for review. If you spot an error, correct the skill's output in chat — it will rewrite the entry before proceeding.

---

### Phase 2 — Security Audit

**What happens:** The skill audits all changed code for secrets, input validation gaps, auth boundary violations, XSS/injection risks, supply chain additions, external URL additions, consent gate compliance (BSO-SEC-031), inter-service auth (HMAC timing-safe compare per BSO-SEC-028), and hardcoded scanner/model lists. It writes a dated audit report to `docs/audit/AUDIT-YYYY-MM-DD-<scope>.md`.

**Operator action:** None required unless the skill surfaces a FAIL or WARN.

- **FAIL** — the skill fixes the issue in the working tree and continues. Review the fix in the final diff.
- **WARN** — the skill continues but opens a new Linear ticket (`source:audit`, `sev:*`, appropriate priority). You can choose to fix the WARN now or defer it.

**If the skill finds a new issue not on a Phase 0 ticket:** A new ticket is created automatically. The skill will print the new ADV-NNN and wait for acknowledgment before continuing.

---

### Phase 3 — Test Coverage

**What happens:** For each changed service or module, the skill confirms that unit tests exist for all new/changed functions and regression tests exist for any bug fix. It writes missing tests, then runs the test suite locally (never against GCP — per `feedback_local_not_gcp.md`).

**Operator action:** None required unless tests fail.

- **Test failure:** The skill investigates whether the code or the test is wrong, fixes the correct one, and re-runs. It will report what it changed.
- **No test suite for a repo:** The skill notes this explicitly rather than silently skipping.

---

### Phase 4 — Documentation Update

**What happens:** The skill walks 12 documentation surfaces in priority order:
1. `docs/standards/` — confirm compliance; add/amend if the change creates a new rule
2. `docs/database/SCHEMA.md` — update if any Alembic migration ran (required in the same PR per database-management.md Rule 4)
3. `docs/workflows/` — update if user-visible flow changed; add new doc for new features
4. `docs/pipelines/` — update if build args, image tags, or NetworkPolicy changed
5. `docs/playbooks/` — update if any operational command or recovery procedure changed
6. `docs/scanners/` — update if any scanner version bumped or scanner added/removed
7. `docs/feature-tests/` — update existing acceptance criteria or add a new numbered file
8. `docs/audit/` — confirm Phase 2 audit report is present
9. `docs/` (general) — fix architecture, intelligence, getting-started drift
10. `TaskDocs-BlockSecOps/` — append a dated iteration to the appropriate `phases/NN-.../IMPLEMENTATION-SUMMARY-YYYY-MM-DD.md`
11. `blocksecops-docs/` — public-safe content only; skip internal details
12. Per-repo READMEs — bump version numbers, add a dated section

**Delegation:** If more than 3 doc files need updating, the skill delegates the sweep to the `apogee-documentation` agent.

**Operator action:** None required unless the skill surfaces a doc gap it cannot resolve. Unresolvable gaps are filed as new Linear follow-up tickets.

---

### Phase 5 — Standards Verification

**What happens:** The skill reads the relevant standard files directly and checks all changed repos against the full standards matrix: version-control conventions, semver bumps, OCI labels, SCHEMA.md same-PR rule, auth patterns, encryption, NetworkPolicy, tier enforcement, dependency health, no build scripts, no BuildKit builders, no hardcoded platform stats, brand naming, no staged `.env` files.

**Operator action:** None required for PASS checks. FIXED checks appear in the standards report — review them in the final diff.

---

### Phase 6 — Commit, PR, and Merge

**What happens:** For each repo with uncommitted changes, the skill stages specific files (never `git add -A`), commits with a conventional commit message that ends with `Refs: ADV-NNN`, pushes to a feature branch named `ship/<topic>-YYYYMMDD`, opens a PR, and posts the PR URL to the Linear ticket (updating the ticket to `phase:in-review`).

**Merge gate (mandatory per `feedback_test_before_merge.md`):** The skill surfaces an explicit gate in chat before calling `gh pr merge`. The PR must not be merged until the operator confirms the live deploy works. The typical flow:

1. Skill opens the PR and pauses.
2. Operator manually deploys (or lets the skill handle deploy in Phase 7 first on a staging namespace) and confirms the change looks correct.
3. Operator replies "merge" or "approved."
4. Skill merges the PR, updates the Linear ticket to `phase:merged`, and runs `git checkout main && git pull`.

**What the skill will NOT do:** It will never merge without operator confirmation, and it will never add Claude/Claude Code/Anthropic attribution to commits, PRs, or ticket comments.

---

### Phase 7 — Deploy, Verify, and Close

**What happens:**

1. Deploy: `kubectl apply -k k8s/overlays/gcp/` for each changed service.
2. Wait for rollout: `kubectl rollout status deployment/<svc> -n <ns>-prod --timeout=180s`.
3. Verify live: `curl https://app.0xapogee.com/api/v1/health/live` (checks deployed version), then an end-to-end action as the test account (`jasonbrailowbizop@mail.com`, password via `$TEST_PASSWORD`).
4. If verify passes: Linear tickets are set to `Done`, `phase:verified` is applied, and a closing comment with live evidence (version, scan ID, curl output) is posted.
5. If verify fails: the ticket stays open at `phase:merged`. The skill reports what failed and presents a fix-forward or rollback decision.

**Rollback procedure (if Phase 7 verify fails):**

```bash
# Roll back the deployment
kubectl rollout undo deployment/<service-name> -n <namespace>-prod

# Confirm rollback
kubectl rollout status deployment/<service-name> -n <namespace>-prod --timeout=120s

# Verify previous version is live
curl -s https://app.0xapogee.com/api/v1/health/live | jq '.version'
```

The Linear ticket must remain open (not closed) until a successful re-deploy is verified.

---

## Handling Partial Failures

If a phase fails mid-way (e.g. a test suite crashes, a network error interrupts the Linear API call), the skill will report the failure and the state it was in. To recover:

1. **Identify the last completed phase** from the chat output.
2. **Do not re-run `/ship` from scratch** — this would duplicate Phase 0 ticket creation. Instead, resume from the failed phase explicitly:
   - For Phase 1–5: manually carry out the remaining step, then tell the skill which phase to continue from.
   - For Phase 6 (commit/PR): check `git status` in each repo; commit any remaining changes manually following the conventional commit format with `Refs: ADV-NNN`.
   - For Phase 7 (deploy): run the `kubectl apply` and `kubectl rollout status` commands manually; update the Linear ticket state via the Linear UI or via `mcp__plugin_linear_linear__save_issue`.

3. **Clean up duplicate artifacts if Phase 0 ran twice:**
   - If two tickets were created for the same work item: keep the first one; cancel the duplicate via the Linear UI or `mcp__plugin_linear_linear__save_issue({id: "ADV-NNN", state: "Canceled"})`.

---

## Backfilling Linear Tickets for Pre-/ship Changes

If a change shipped before the /ship cycle existed (e.g. anything before 2026-06-21), you can create retroactive tickets to give the work a Linear record.

**When to backfill:** When the owner explicitly asks for a Linear record of historical work (e.g. for a phase completion report, an audit trail, or to link a TaskDocs entry to a ticket).

**When NOT to backfill:** Do not backfill speculatively. Only create retroactive tickets on explicit request.

**How to backfill:**

1. Identify the historical work items (from TaskDocs, CHANGELOG.md, or git log).
2. For each work item, call `mcp__plugin_linear_linear__save_issue` with:
   - `state: "Done"` (the work is already merged and deployed)
   - `labels: [..., "phase:verified"]` (already verified in production)
   - `source: "source:audit"` or `"source:user-report"` as appropriate (NOT `source:ship-cycle` — that label is for work shipped through the /ship cycle)
   - `priority`: use the decision tree in the runtime skill
3. Post a comment on each backfilled ticket with the relevant TaskDocs link, deploy date, and git commit SHA.
4. Do NOT open PRs or attempt to retroactively stage/commit already-merged code.

---

## Useful Commands During a Ship Run

```bash
# Check which repos have uncommitted changes
cd /home/pwner/Git
for repo in */; do
  if git -C "$repo" rev-parse --git-dir > /dev/null 2>&1; then
    status=$(git -C "$repo" status --short)
    if [ -n "$status" ]; then
      echo "=== $repo ==="; echo "$status"
    fi
  fi
done

# Check current kubectl context
kubectl config current-context

# Live service version check
curl -s https://app.0xapogee.com/api/v1/health/live | jq '.version'

# Check rollout status for a service
kubectl rollout status deployment/api-service -n blocksecops-prod --timeout=180s
```

---

## Common Problems

| Problem | Cause | Resolution |
|---------|-------|-----------|
| Phase 0 creates a duplicate ticket | Previous run was interrupted before Phase 0 completed | Cancel the duplicate via Linear UI; retain the first ticket |
| Phase 6 gate never appears | PR failed to open (gh auth, branch already exists) | Check `gh auth status`; delete the stale branch if needed: `git push origin --delete ship/<topic>` |
| Phase 7 rollout times out | Image pull slow or pod OOMKilled | `kubectl describe pod -n <ns>-prod -l app=<svc>` to diagnose; increase timeout or fix the pod issue before re-deploying |
| Linear comment fails with "invalid newlines" | Escape sequences used instead of real newlines | The MCP server requires real newlines in markdown strings — the skill handles this, but if posting manually, use actual line breaks |
| Test account password not available | `$TEST_PASSWORD` not set in session | Set it for the session: `export TEST_PASSWORD=<value>` — never hardcode in any file |

---

## Related Documents

- `/home/pwner/Git/.claude/commands/ship.md` — runtime skill (authoritative, all phase logic)
- `docs/workflows/ship-cycle-workflow.md` — sequence diagrams and ticket lifecycle
- `docs/standards/version-control-standards.md` — commit format, PR requirements, Linear ticket reference
- `docs/standards/core-development-rules.md` — Rule 0 (GitOps requires owner approval)
- `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-06-21-LINEAR-INTEGRATION-AND-SHIP-V2.md` — dated change record for the /ship V2 rollout
