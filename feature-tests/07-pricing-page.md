# Pricing Page Tests

**Priority**: P2 - Medium
**Last Updated**: March 7, 2026
**Related**: Phase 3.1b Frontend, Migration 024, Migration 030

---

## 1. Pricing Page Display

### 1.1 Page Load
- [ ] Pricing page accessible at /pricing
- [ ] Page loads without errors
- [ ] All four tiers displayed (Developer, Team, Growth, Enterprise)
- [ ] Responsive on mobile/tablet/desktop

### 1.2 Developer Tier Card (Free)
- [ ] "Developer" label displayed
- [ ] Price shown ($0/month)
- [ ] Feature list:
  - [ ] 3 scans/month
  - [ ] Unlimited files per scan
  - [ ] Unlimited LoC per scan
  - [ ] 3 projects
  - [ ] All scanners (basic mode)
  - [ ] Community support
  - [ ] CI/CD Integration (CLI only)
  - [ ] No Integrations Hub
  - [ ] No API access
  - [ ] No export (dashboard view only)
  - [ ] 7-day retention
  - [ ] 2 team members (solo + 1)
- [ ] "Current Plan" indicator (if user is Developer)
- [ ] "Get Started" button (if not logged in)

### 1.3 Starter Tier Card ($299/mo)
- [ ] "Starter" label displayed with blue styling
- [ ] Price shown ($299/month)
- [ ] Feature list:
  - [ ] 15 scans/month
  - [ ] Unlimited files per scan
  - [ ] Unlimited LoC per scan
  - [ ] 10 projects
  - [ ] All 17+ scanners
  - [ ] No API access
  - [ ] Export enabled (PDF, JSON, SARIF)
  - [ ] 90-day retention
  - [ ] Up to 5 team members
  - [ ] Webhooks enabled
  - [ ] CI/CD Integration (CLI + Integrations Hub)
- [ ] "Upgrade to Starter" button (if user is Developer)
- [ ] "Current Plan" indicator (if user is Starter)

### 1.4 Growth Tier Card ($699/mo)
- [ ] "Growth" label displayed with purple styling
- [ ] "Popular" badge shown
- [ ] Price shown ($699/month)
- [ ] Feature list:
  - [ ] 50 scans/month
  - [ ] Unlimited files per scan
  - [ ] Unlimited LoC per scan
  - [ ] Unlimited projects
  - [ ] All scanners
  - [ ] Unlimited API calls
  - [ ] Full API access enabled
  - [ ] Webhooks enabled
  - [ ] CI/CD Integration (CLI)
  - [ ] Integrations Hub
  - [ ] Up to 15 team members
  - [ ] 180-day retention
  - [ ] Continuous monitoring
- [ ] "Upgrade to Growth" button (if user is Developer/Starter)
- [ ] "Current Plan" indicator (if user is Growth)

### 1.5 Enterprise Tier Card ($1,999+/mo)
- [ ] "Enterprise" label displayed with purple styling
- [ ] Price shown ($1,999+/month or "Contact Sales")
- [ ] Feature list:
  - [ ] Unlimited scans
  - [ ] Unlimited files per scan
  - [ ] Unlimited projects
  - [ ] Unlimited API calls
  - [ ] Organizations support
  - [ ] Audit logging
  - [ ] SSO/SAML integration
  - [ ] Custom policies
  - [ ] Unlimited team members
  - [ ] 730-day retention (2 years)
  - [ ] Dedicated support
  - [ ] 99.9% SLA
  - [ ] On-premise broker option
- [ ] "Contact Sales" button

---

## 2. Current Tier Highlighting

### 2.1 Logged In User
- [ ] Current tier card highlighted with border
- [ ] "Current Plan" badge shown on current tier
- [ ] Upgrade options visible for lower tiers
- [ ] Downgrade info available (if applicable)

### 2.2 Not Logged In
- [ ] All tiers shown equally
- [ ] Sign up prompts visible
- [ ] No "Current Plan" indicator

---

## 3. Feature Comparison Table

### 3.1 Feature Matrix Display
- [ ] "Detailed Feature Comparison" section visible
- [ ] All features listed in rows
- [ ] Five columns: Developer, Team, Growth, Enterprise, x402 Pay-Per-Scan
- [ ] Correct styling for each tier column:
  - [ ] Developer: Gray
  - [ ] Team: Green
  - [ ] Growth: Blue
  - [ ] Enterprise: Purple
  - [ ] x402: Emerald
- [ ] Checkmarks/values accurate per tier

### 3.2 Limit Comparison
Features to verify in matrix:
- [ ] Monthly Scans: 3 / 15 / 50 / Unlimited / Pay per scan
- [ ] Team Members: 2 / 5 / 15 / Unlimited / 1
- [ ] Projects: 3 / 10 / Unlimited / Unlimited / 5
- [ ] API Calls/Month: None / None / Unlimited / Unlimited / Per tier
- [ ] Files/Scan: Unlimited / Unlimited / Unlimited / Unlimited / Per tier
- [ ] LoC/Scan: Unlimited / Unlimited / Unlimited / Unlimited / Per tier
- [ ] Result Retention: 7 days / 90 days / 180 days / 365 days / 90 days
- [ ] All Scanners: Yes / Yes / Yes / Yes / Yes
- [ ] API Access: No / No / Yes (Full) / Yes / Yes
- [ ] Webhooks: No / Yes / Yes / Yes / Yes
- [ ] Teams: No / Yes / Yes / Yes / No
- [ ] Organizations: No / No / No / Yes / No
- [ ] SSO/SAML: No / No / No / Yes / No
- [ ] Audit Logs: No / No / No / Yes / No

---

## 4. Upgrade Flow

### 4.1 Upgrade Buttons
- [ ] Developer -> Starter: "Upgrade to Starter" button works
- [ ] Developer -> Growth: "Upgrade to Growth" button works
- [ ] Starter -> Growth: "Upgrade to Growth" button works
- [ ] Starter -> Enterprise: "Contact Sales" button works
- [ ] Growth -> Enterprise: "Upgrade to Enterprise" button works
- [ ] Any tier -> Enterprise: "Contact Sales" button works

### 4.2 Current Plan Banner
- [ ] Shows current tier name with badge
- [ ] Shows usage statistics (scans used / limit)
- [ ] Shows usage percentage bar
- [ ] "Near Limit" warning at 80%
- [ ] "Limit Reached" warning at 100%
- [ ] "Manage Plan" button links to billing

### 4.3 At-Limit CTA
- [ ] "Buy Credits" button visible when at limit
- [ ] "Upgrade" button visible when at limit
- [ ] Both navigate correctly

---

## 5. x402 Pay-Per-Scan Section

### 5.1 x402 Banner Display
- [ ] x402 Pay-Per-Scan section visible below subscription cards
- [ ] Green gradient background styling
- [ ] USDC coin icon displayed
- [ ] "Buy Credits with USDC" button present

### 5.2 Pricing Tiers Display
- [ ] Micro tier shown ($3.00 for 1-5 files, 4K LoC max)
- [ ] Small tier shown ($7.00 for 6-25 files, 20K LoC max)
- [ ] Medium tier shown ($15.00 for 26-100 files, 75K LoC max)
- [ ] Large tier shown ($25.00 for 100+ files, Unlimited LoC)

### 5.3 Navigation
- [ ] "Buy Credits with USDC" button navigates to /credits
- [ ] Button responsive on mobile

---

## 6. Navigation

- [ ] Link to pricing in header/footer
- [ ] Link to pricing in sidebar (BILLING section)
- [ ] Back navigation works
- [ ] Deep link to /pricing works
- [ ] Tier section anchors work (e.g., #tier-developer)

---

## 7. CTA Section

- [ ] "Need help choosing a plan?" section visible
- [ ] "Contact Sales" button works
- [ ] "Back to Dashboard" button works
- [ ] Blue-purple gradient background

---

## 8. FAQ Section (if present)

- [ ] FAQ section displays below CTA
- [ ] Common pricing questions answered
- [ ] Accordion/expandable format works

---

## Test Notes

_Record pricing page test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
