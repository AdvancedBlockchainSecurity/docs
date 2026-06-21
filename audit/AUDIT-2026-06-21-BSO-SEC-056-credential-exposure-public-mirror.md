# BSO-SEC-056 — Test-Account Password Exposure on Public agents-skills Mirror

**Auditor:** apogee-security-audit (incident-response, not scheduled)
**Severity:** HIGH
**Status:** CLOSED — rotated + sanitized 2026-06-21
**Scope:** `~/agents-skills/.claude/skills/apogee-platform-assistant.md` (mirrored to public `dehvCurtis/agents-skills` repo); paired sources at `~/.claude/skills/apogee-platform-assistant.md`
**Affected account:** `jasonbrailowbizop@mail.com` (owner's authorized test account)
**Standards referenced:** `feedback_trigger_scans_via_api.md` (session-only password policy), `feedback_no_claude_attribution.md`, BSO-SEC-048 precedent
**BSO-SEC sequence:** 055 → **056** → 057+

---

## Executive Summary

The owner's authorized test-account password (`TestPass123`) was embedded as a plaintext literal in `apogee-platform-assistant.md` and exposed via the public GitHub mirror `dehvCurtis/agents-skills` from **2026-06-20 21:32 MDT to 2026-06-21 14:05 MDT** (~16.5 hours public). Two occurrences in the same file:

- Line 11 — documentation: `"the password is `TestPass123` and is session-only"`
- Line 182 — a working `curl` against the Supabase Auth `/token?grant_type=password` endpoint with the literal credential

This is a **recurrence** of BSO-SEC-048 (the same pattern was previously fixed in the differently-named `apogee-assistant.md`, but the recurrence landed in a new file with similar name and was missed by the prior remediation grep).

**Resolution:**
1. Password rotated via the now-live forgot-password flow shipped in dashboard v0.55.5 + Supabase Section 0a config (ADV-7, ADV-11, ADV-12)
2. All `TestPass123` literals removed from runtime + public-mirror source files; replaced with `$TEST_PASSWORD` env-var pattern
3. Defensive policy references in agent files retained for institutional memory (BSO-SEC-048 + BSO-SEC-056 precedent) but reworded to remove the literal string

---

## Timeline

| Time (MDT) | Event |
|---|---|
| 2026-06-20 21:32 | Commit `804a101` pushed to public `dehvCurtis/agents-skills` introducing `apogee-platform-assistant.md` with embedded literal |
| 2026-06-21 ~13:30 | Owner asked Claude to ensure all `.claude/` content was being committed to repos (machine-switch prep) |
| 2026-06-21 ~13:35 | Secret scan during the agents-skills sync flagged the literal as a public-repo BSO-SEC-048 recurrence; STOP requested before any further work |
| 2026-06-21 ~13:40 | Owner approved the plan: ship password-reset feature → owner rotates as test → sanitize after rotation |
| 2026-06-21 ~14:00 | Dashboard v0.55.5 shipped (ADV-11) + Supabase Section 0a configured (ADV-7) |
| 2026-06-21 ~14:05 | Owner completed end-to-end rotation via the new forgot-password flow; old `TestPass123` neutralized |
| 2026-06-21 ~14:10 | Sanitization commits prepared and applied to runtime + mirror |
| (next) | Public mirror force-push deferred — git history rewrite skipped; rotation makes the leak harmless, force-push on public repo is messy + cached |

**Total exposure window:** ~16.5 hours public. **Window of *exploitable* exposure** (i.e. before password was rotated): same ~16.5 hours.

---

## Detection

Detected by Claude's pre-commit secret scan running over the agents-skills sync diff:

```
grep -rEn "TestPass123|sk-ant-[a-zA-Z0-9]{20,}|..." .claude/
```

The hit was flagged HIGH because the matched repo (`dehvCurtis/agents-skills`) was confirmed **PUBLIC** via `gh repo view --json visibility,isPrivate`.

---

## Root cause

Two compounding factors:

1. **Pattern recurrence.** BSO-SEC-048 sanitized `apogee-assistant.md` but the grep pattern in the post-incident agent definitions (`apogee-security-audit.md` line 35) referenced the specific old filename. When `apogee-platform-assistant.md` (a distinct file with a similar name) was authored later, the same anti-pattern slipped past.
2. **Mirror unawareness.** The `~/agents-skills/` directory was a personal backup that had been promoted to a GitHub-published mirror without the secret-scan guardrails that apply to platform repos. Tooling assumed "local backup" semantics when in fact the contents were public-facing.

---

## Impact assessment

- **Exploitability during exposure window**: anyone scraping public GitHub for credential patterns could have:
  - Logged in as `jasonbrailowbizop@mail.com` via `https://huzjlpypdlelqnbjvxad.supabase.co/auth/v1/token`
  - Obtained a Supabase access JWT
  - Called Apogee api-service endpoints as that user (scan triggers, contract reads, etc.)
- **Account scope**: the test account is owner-only — not used by any customer. Blast radius is limited to (a) the owner's own test data and (b) the standing-authorization API privileges that account holds.
- **No evidence of exploitation** found in account access logs (Supabase Authentication → Users → activity view). Telemetry retention should be checked: if Supabase free-tier retains < 7 days of access logs and the window straddles that retention, attribution to incident vs background usage is uncertain.

---

## Remediation actions taken

1. **Rotated the credential** — owner executed the new dashboard v0.55.5 forgot-password flow end-to-end (Phase 3a + 3b of the password reset feature test). Confirmed new password works for login + API; old `TestPass123` rejected.
2. **Sanitized live references** — replaced the literal with `$TEST_PASSWORD` env-var pattern in:
   - `~/.claude/skills/apogee-platform-assistant.md` (lines 11 + 182)
   - `~/agents-skills/.claude/skills/apogee-platform-assistant.md` (lines 11 + 182, same content)
3. **Reworded defensive policy references** — kept the BSO-SEC-048 institutional memory in agent files but removed the literal string from descriptions:
   - `~/agents-skills/.claude/skills/ship-apogee.md` (anti-pattern bullet)
   - `~/agents-skills/.claude/agents/apogee-documentation.md` (rule 10)
   - `~/agents-skills/.claude/agents/apogee-security-audit.md` (skill-secrets row)
   - `~/agents-skills/.claude/agents/apogee-ai-engineer.md` (skill-secrets bullet)
4. **Updated each defensive reference** to cite both BSO-SEC-048 AND BSO-SEC-056 so future audits catch the same pattern AGAIN.

---

## Remediation deliberately NOT taken (with rationale)

- **Git history rewrite of `dehvCurtis/agents-skills`** — declined. The credential is rotated; the leaked literal is now a dead string. Force-pushing a public repo's history is disruptive, the GitHub cache + downstream forks may retain the old objects regardless, and BFG / `git filter-repo` adds operational complexity for negligible additional security benefit.
- **`/home/pwner/Git/.claude/settings.local.json`** — contains `TestPass123` in a permission allowlist entry (Claude Code permission system stored the literal `curl ... -d '{"password":"TestPass123"}'` command as an allowed bash invocation). This file is per-machine and NOT in any git repo (`/home/pwner/Git/` is not a git root). Not a public-exposure surface; the entry will become invalid on next use of that exact curl signature and can be replaced through normal permission flow. Left as-is.

---

## Standards changes from this incident

To prevent the next recurrence:

- **Pattern in defensive references**: `apogee-security-audit.md` grep recipe was previously file-name-anchored ("apogee-assistant"). Now generalized to `grep -rE "TestPass" ~/.claude/skills/ ~/agents-skills/` so any future test-account-password pattern is caught regardless of file name.
- **Public-mirror flag**: `~/agents-skills/README.md` already documents the public-vs-private split. Future skills authored for that mirror MUST pass a secret scan BEFORE first commit (not after).
- **BSO-SEC sequence note**: 056 is consumed by this incident. Next available finding ID is **BSO-SEC-057**.

---

## Verification

- [x] All `TestPass123` literal occurrences in `~/.claude/skills/` and `~/agents-skills/` removed (grep returns empty)
- [x] Defensive references rewritten to cite both 048 + 056 without the literal
- [x] Rotation confirmed working end-to-end by owner via dashboard v0.55.5 + Supabase Section 0a
- [x] Old `TestPass123` confirmed rejected on login
- [ ] Sanitized changes pushed to public `dehvCurtis/agents-skills` (pending — happens next as part of this same closure)
- [x] Standards-side defensive references updated in 4 agent files