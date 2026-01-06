# Pricing Page Tests

**Priority**: P2 - Medium
**Last Updated**: January 3, 2026
**Related**: Phase 3.1b Frontend, Migration 024

---

## 1. Pricing Page Display

### 1.1 Page Load
- [ ] Pricing page accessible at /pricing
- [ ] Page loads without errors
- [ ] All five tiers displayed (Free, Developer, Startup, Professional, Enterprise)
- [ ] Responsive on mobile/tablet/desktop

### 1.2 Free Tier Card
- [ ] "Free" label displayed
- [ ] Price shown ($0/month)
- [ ] Feature list:
  - [ ] 10 scans/month
  - [ ] 25 files per scan
  - [ ] 1 MB file limit (5 MB archives)
  - [ ] 3 projects
  - [ ] Basic scanners
  - [ ] Community support
  - [ ] No API access
  - [ ] 1 user (solo)
- [ ] "Current Plan" indicator (if user is Free)
- [ ] "Get Started" button (if not logged in)

### 1.3 Developer Tier Card
- [ ] "Developer" label displayed with green styling
- [ ] Price shown ($199/month)
- [ ] Feature list:
  - [ ] 100 scans/month
  - [ ] 50 files per scan
  - [ ] 5 MB file limit (25 MB archives)
  - [ ] 5 projects
  - [ ] All 17+ scanners
  - [ ] 1,000 API calls/month
  - [ ] 90-day retention
  - [ ] 1 user (solo)
- [ ] "Upgrade to Developer" button (if user is Free)
- [ ] "Current Plan" indicator (if user is Developer)

### 1.4 Startup Tier Card
- [ ] "Startup" label displayed with blue styling
- [ ] "Popular" badge shown
- [ ] Price shown ($999/month)
- [ ] Feature list:
  - [ ] 500 scans/month
  - [ ] 100 files per scan
  - [ ] 10 MB file limit (50 MB archives)
  - [ ] 20 projects
  - [ ] All scanners
  - [ ] 10,000 API calls/month
  - [ ] Webhooks enabled
  - [ ] Up to 10 team members
  - [ ] 180-day retention
- [ ] "Upgrade to Startup" button (if user is Free/Developer)
- [ ] "Current Plan" indicator (if user is Startup)

### 1.5 Professional Tier Card
- [ ] "Professional" label displayed with indigo styling
- [ ] Price shown ($2,499/month)
- [ ] Feature list:
  - [ ] Unlimited scans
  - [ ] Unlimited files per scan
  - [ ] Unlimited projects
  - [ ] Unlimited API calls
  - [ ] Organizations support
  - [ ] Audit logging
  - [ ] Up to 25 team members
  - [ ] 365-day retention
  - [ ] Priority support
- [ ] "Upgrade to Professional" button
- [ ] "Current Plan" indicator (if user is Professional)

### 1.6 Enterprise Tier Card
- [ ] "Enterprise" label displayed with purple styling
- [ ] "Custom" or "Contact Sales" pricing
- [ ] Feature list:
  - [ ] Unlimited everything
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
- [ ] Six columns: Free, Developer, Startup, Professional, Enterprise, x402 Pay-Per-Scan
- [ ] Correct styling for each tier column:
  - [ ] Free: Gray
  - [ ] Developer: Green
  - [ ] Startup: Blue
  - [ ] Professional: Indigo
  - [ ] Enterprise: Purple
  - [ ] x402: Emerald
- [ ] Checkmarks/values accurate per tier

### 3.2 Limit Comparison
Features to verify in matrix:
- [ ] Monthly Scans: 10 / 100 / 500 / Unlimited / Unlimited / Pay per scan
- [ ] Team Members: 1 / 1 / 10 / 25 / Unlimited / 1
- [ ] Projects: 3 / 5 / 20 / Unlimited / Unlimited / 5
- [ ] API Calls/Month: None / 1,000 / 10,000 / Unlimited / Unlimited / 1,000
- [ ] Files/Scan: 25 / 50 / 100 / Unlimited / Unlimited / 50
- [ ] Result Retention: 30 days / 90 days / 180 days / 365 days / 730 days / 90 days
- [ ] All Scanners: Basic / Yes / Yes / Yes / Yes / Yes
- [ ] API Access: No / Yes / Yes / Yes / Yes / Yes
- [ ] Webhooks: No / No / Yes / Yes / Yes / Yes
- [ ] Teams: No / No / Yes / Yes / Yes / No
- [ ] Organizations: No / No / No / Yes / Yes / No
- [ ] SSO/SAML: No / No / No / No / Yes / No
- [ ] Audit Logs: No / No / No / Yes / Yes / No

---

## 4. Upgrade Flow

### 4.1 Upgrade Buttons
- [ ] Free -> Developer: "Upgrade to Developer" button works
- [ ] Free -> Startup: "Upgrade to Startup" button works
- [ ] Developer -> Startup: "Upgrade to Startup" button works
- [ ] Developer -> Professional: "Upgrade to Professional" button works
- [ ] Startup -> Professional: "Upgrade to Professional" button works
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
- [ ] Small tier shown ($1.00 for 1-10 files)
- [ ] Medium tier shown ($3.00 for 11-50 files)
- [ ] Large tier shown ($5.00 for 51-100 files)

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
