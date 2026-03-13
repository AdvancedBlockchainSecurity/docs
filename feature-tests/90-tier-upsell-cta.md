# Tier Upsell & CTA Tests

**Priority**: P1 - High
**Last Updated**: March 12, 2026
**Related**: TierGate, Sidebar, Dashboard, Pricing, Quota Pre-Checks, v0.46.28+

---

## Overview

Tests for the tier upsell and conversion-optimized CTA system implemented in dashboard v0.46.28-v0.46.29. Covers sidebar lock icons, dashboard feature discovery, scan quota pre-checks, AI tier gates, and CI/CD tier split.

---

## 1. Sidebar Lock Icons

### 1.1 Developer Tier User
- [ ] Sidebar nav items for gated features show lock icon (LockClosedIcon)
- [ ] Locked items have muted text (reduced opacity)
- [ ] Locked items remain clickable (navigate to page with TierGate upgrade prompt)
- [ ] Items locked at Starter+: Intelligence Overview, Copilot, Code Review, Code Repair, Integrations
- [ ] Items locked at Growth+: Runtime Monitor, Alerts, Teams, Users, API Keys, Webhooks, Audit Logs
- [ ] Items locked at Enterprise: Organizations
- [ ] Ungated items (Dashboard, Contracts, Scans, Vulnerabilities, Settings, Pricing) have no lock

### 1.2 Starter Tier User
- [ ] Starter-gated items (Intelligence, Copilot, etc.) show NO lock
- [ ] Growth-gated items (Runtime Monitor, API Keys, etc.) still show lock
- [ ] Enterprise-gated items still show lock

### 1.3 Growth Tier User
- [ ] All Starter and Growth items unlocked (no lock icon)
- [ ] Only Enterprise-gated items show lock (Organizations)

### 1.4 Enterprise Tier User
- [ ] No lock icons on any nav item

### 1.5 Plan Badge in Sidebar Footer
- [ ] Current plan name displayed in sidebar footer
- [ ] Color-coded dot matches tier (gray=developer, blue=starter, purple=growth, gold=enterprise)
- [ ] "Upgrade" link shown for non-enterprise tiers
- [ ] "Upgrade" link navigates to /pricing
- [ ] Enterprise users see plan name only (no upgrade link)

---

## 2. Dashboard Feature Discovery

### 2.1 Developer Tier User
- [ ] Feature discovery section shown below quota bar
- [ ] Section title: "Unlock More Features"
- [ ] Shows 3 feature cards: AI Security Copilot, Automated Code Review, Integrations Hub
- [ ] Each card has icon, title, description, and tier badge
- [ ] Cards are clickable (navigate to gated page)
- [ ] Clicking card shows TierGate upgrade prompt with Starter pricing ($299/mo)

### 2.2 Starter Tier User
- [ ] Feature discovery section still shown (for Growth features)
- [ ] Shows different cards: Runtime Monitoring, API Access, Team Management
- [ ] Cards navigate to Growth-gated pages
- [ ] TierGate shows Growth pricing ($699/mo)

### 2.3 Growth+ Tier User
- [ ] Feature discovery section NOT shown
- [ ] Dashboard renders normally without upsell content

---

## 3. Scan Quota Pre-Checks

### 3.1 Contract Detail Page
- [ ] "Start Scan" button checks quota before submitting
- [ ] When quota exceeded: toast error shown (not a raw 403)
- [ ] Toast includes upgrade link to /pricing
- [ ] Scan NOT submitted when quota exceeded

### 3.2 Contracts List Page
- [ ] "Trigger Scan" action checks quota before submitting
- [ ] When quota exceeded: redirects to /pricing

### 3.3 Batch Scan Modal
- [ ] Quota warning banner shown inside modal
- [ ] Banner color: red (at limit), yellow (near limit), gray (ok)
- [ ] "Upgrade" link in banner navigates to /pricing
- [ ] Submit button disabled when quota exceeded (`!canCreateScan`)
- [ ] Submit button enabled when quota available

---

## 4. AI Action Tier Gates

### 4.1 Economic Security Panel — AI Explain
- [ ] "Explain" button wrapped in TierGate (starter, preview mode)
- [ ] Developer tier: button shows preview overlay with lock badge
- [ ] Starter+ tier: button fully functional

### 4.2 Previously Verified AI Gates (from prior audit)
- [ ] Vulnerability Detail AI Analysis — gated at Starter (preview)
- [ ] PoC Exploit generation — gated at Growth (preview)
- [ ] Invariant generation — gated at Growth (preview)
- [ ] Collaborative Comments — gated at Enterprise (preview)
- [ ] Vulnerability Assignments — gated at Enterprise (preview)

---

## 5. TierGate Pricing Accuracy

### 5.1 Next-Tier Pricing (Not Required-Tier Pricing)
- [ ] Developer user sees Starter pricing ($299/mo) for Starter-gated features
- [ ] Developer user sees Starter pricing ($299/mo) for Growth-gated features (next step up)
- [ ] Starter user sees Growth pricing ($699/mo) for Growth-gated features
- [ ] Growth user sees Enterprise pricing ($1,999+/mo) for Enterprise-gated features

### 5.2 Full-Page Block Mode
- [ ] Gated page shows upgrade prompt with plan name, price, and feature list
- [ ] "View Plans" button links to /pricing
- [ ] Back navigation works

### 5.3 Preview Mode (Inline)
- [ ] Greyed overlay with lock badge
- [ ] Hover tooltip shows required tier
- [ ] Content beneath is visible but not interactive

---

## 6. CI/CD Tier Split

### 6.1 Pricing Page Feature Comparison
- [ ] "CI/CD Integration (CLI)" row shows checkmark for ALL tiers
- [ ] "Integrations Hub" row shows checkmark only for Starter, Growth, Enterprise
- [ ] Developer tier shows no checkmark for Integrations Hub

### 6.2 Tier Config Consistency
- [ ] `tiers.json` has `cicdIntegration: true` for all tiers
- [ ] `tiers.json` has `cicdDashboard: false` for developer, `true` for starter/growth/enterprise
- [ ] TypeScript `TierFeatures` interface includes `cicdDashboard: boolean`
- [ ] Python `TierFeatures` model includes `cicd_dashboard` field
- [ ] JSON schema includes `cicdDashboard` in required properties

---

## 7. Cross-Tier Smoke Test

### 7.1 Full Journey — Developer Tier
1. [ ] Log in as developer user
2. [ ] Sidebar shows lock icons on 13 gated items
3. [ ] Dashboard shows feature discovery cards
4. [ ] Click locked nav item → see upgrade prompt (Starter $299/mo)
5. [ ] Try scan at quota limit → toast error with upgrade link
6. [ ] Visit vulnerability detail → AI buttons show preview gates
7. [ ] Pricing page → CI/CD rows correct (CLI for all, Hub for starter+)

### 7.2 Full Journey — Starter Tier
1. [ ] Log in as starter user
2. [ ] Sidebar locks only on Growth+ and Enterprise items
3. [ ] Dashboard shows Growth feature discovery cards
4. [ ] Integrations Hub accessible (no TierGate)
5. [ ] AI Explain works (starter+)
6. [ ] PoC Exploit gated (growth+)

### 7.3 Full Journey — Growth Tier
1. [ ] Log in as growth user
2. [ ] Only Organizations locked in sidebar
3. [ ] No feature discovery section on dashboard
4. [ ] All AI features work except Enterprise-only features

### 7.4 Full Journey — Enterprise Tier
1. [ ] Log in as enterprise user
2. [ ] No locks anywhere
3. [ ] No feature discovery section
4. [ ] All features accessible

---

## Test Notes

_Record tier upsell test results here:_

```
[Date] | [Tier] | [Test] | [Result] | [Notes]
```

---

**Related Documentation**:
- Implementation Summary: `TaskDocs-BlockSecOps/implementation-summaries/2026-03-12-tier-upsell-cta-audit.md`
- Tier Standards: `docs/standards/tier-standards.md`
- Tier Upgrades Tests: `docs/feature-tests/10-tier-upgrades.md`
- Pricing Page Tests: `docs/feature-tests/07-pricing-page.md`
