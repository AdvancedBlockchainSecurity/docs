# Tier Upgrade Tests

**Priority**: P1 - High
**Last Updated**: March 13, 2026
**Related**: Freemium Model, Pricing Tiers, Migration 024, Migration 030, UpgradeBanner (v0.30.1)

---

## Tier Reference (4-Tier Model - March 2026)

| Tier | Price | Scans/Mo | Files/Scan | Team Members | Projects | API Calls |
|------|-------|----------|------------|--------------|----------|-----------|
| Developer | $0 | 3 | Unlimited | 2 | 3 | 0 (no API) |
| Starter | $199/mo | 25 | Unlimited | 5 | 15 | 0 (no API) |
| Growth | $499/mo | 75 | Unlimited | 25 | Unlimited | Unlimited |
| Enterprise | $1,499+/mo | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited |

---

## 1. Developer to Starter Upgrade

### 1.1 Upgrade Initiation
- [ ] Upgrade button visible on pricing page for Developer users
- [ ] Upgrade button visible in quota widget when near limit
- [ ] Clicking upgrade navigates to checkout/payment flow
- [ ] User tier shown as "Developer" before upgrade

### 1.2 Payment Processing
- [ ] Payment form loads correctly
- [ ] Valid payment method accepted ($199/month)
- [ ] Invalid payment method shows error
- [ ] Payment confirmation displayed

### 1.3 Post-Upgrade Verification
- [ ] User tier updated to "starter" in database
- [ ] Quota widget shows "Starter" tier label
- [ ] Scan limit increased to 25/month
- [ ] Files per scan now unlimited (-1)
- [ ] LoC per scan now unlimited (-1)
- [ ] Export enabled (PDF, JSON, SARIF)
- [ ] Projects limit increased to 15
- [ ] API access NOT enabled (Starter has no API access)
- [ ] Priority queue level updated (40)
- [ ] All 25+ scanners now accessible
- [ ] Team members limit increased to 5

### 1.4 Quota Preservation
- [ ] Existing monthly_scans_used count preserved
- [ ] New higher limit applied immediately
- [ ] User can scan if under new limit

---

## 2. Starter to Growth Upgrade

### 2.1 Upgrade Initiation
- [ ] "Upgrade to Growth" button visible for Starter users
- [ ] Upgrade benefits clearly shown (more users, full API access, webhooks, CI/CD)
- [ ] Price shown ($499/month)
- [ ] Clicking upgrade navigates to payment flow

### 2.2 Payment Processing
- [ ] Payment form loads correctly
- [ ] Price difference handled correctly
- [ ] Payment confirmation displayed

### 2.3 Post-Upgrade Verification
- [ ] User tier updated to "growth" in database
- [ ] Quota widget shows "Growth" tier label
- [ ] Scan limit increased to 75/month
- [ ] Files per scan remains unlimited (-1)
- [ ] Projects limit becomes unlimited (-1)
- [ ] API calls become unlimited (-1)
- [ ] Full API access enabled
- [ ] Priority queue level updated (25)
- [ ] Team management enabled (up to 25 members)
- [ ] Webhooks enabled
- [ ] Result retention increased to 365 days
- [ ] Continuous monitoring enabled

### 2.4 Team Features Expanded
- [ ] Team invite functionality expanded
- [ ] Can invite up to 24 additional members
- [ ] Full API access now available

---

## 3. Growth to Enterprise Upgrade

### 3.1 Upgrade Initiation
- [ ] "Upgrade to Enterprise" or "Contact Sales" button visible for Growth users
- [ ] Upgrade benefits clearly shown (unlimited, organizations, audit, SSO)
- [ ] Price shown ($1,499+/month or "Contact Sales")
- [ ] Clicking upgrade navigates to payment flow or contact form

### 3.2 Payment Processing
- [ ] Payment form loads correctly (or contact sales flow)
- [ ] Price difference handled correctly
- [ ] Payment confirmation displayed

### 3.3 Post-Upgrade Verification
- [ ] User tier updated to "enterprise" in database
- [ ] Quota widget shows "Enterprise" tier label
- [ ] Scan limit shows "Unlimited" (-1 in database)
- [ ] Files per scan shows "Unlimited" (-1 in database)
- [ ] Projects shows "Unlimited" (-1 in database)
- [ ] API calls shows "Unlimited" (-1 in database)
- [ ] Priority queue level updated (5)
- [ ] Team members unlimited
- [ ] Organizations feature enabled
- [ ] Audit logging enabled
- [ ] SSO/SAML enabled
- [ ] Result retention increased to 730 days (2 years)

---

## 4. Direct Upgrades to Enterprise

### 4.1 Upgrade Initiation (Any Tier)
- [ ] "Contact Sales" button visible for all users
- [ ] Contact form or email link works
- [ ] Sales inquiry submitted successfully
- [ ] User receives confirmation of inquiry

### 4.2 Admin-Applied Upgrade
- [ ] Admin can upgrade user to Enterprise from any tier
- [ ] User notified of upgrade via email
- [ ] Upgrade effective immediately

### 4.3 Post-Upgrade Verification
- [ ] User tier updated to "enterprise" in database
- [ ] Quota widget shows "Enterprise" tier label
- [ ] All limits show "Unlimited"
- [ ] Highest priority queue level applied (5)
- [ ] Team members limit is unlimited (-1)
- [ ] SSO/SAML feature enabled
- [ ] Custom policies feature enabled
- [ ] Result retention increased to 730 days (2 years)
- [ ] 99.9% SLA activated

---

## 5. Developer to Higher Tiers (Skip Upgrades)

### 5.1 Developer to Growth
- [ ] Direct upgrade path available
- [ ] No requirement to go through Starter first
- [ ] Full API access enabled immediately
- [ ] All Growth limits applied

### 5.2 Developer to Enterprise
- [ ] "Contact Sales" flow works
- [ ] Admin can apply Enterprise directly to Developer user
- [ ] All Enterprise features enabled

---

## 6. Upgrade Edge Cases

### 6.1 Mid-Cycle Upgrade
- [ ] Upgrade during billing cycle works
- [ ] Prorated charges applied correctly (if applicable)
- [ ] New limits effective immediately
- [ ] No gap in service

### 6.2 At Quota Limit Upgrade
- [ ] User at 3/3 scans (Developer tier) can initiate upgrade
- [ ] After upgrade to Starter, user shows 3/25
- [ ] After upgrade to Enterprise, user shows 3/Unlimited
- [ ] User can scan immediately after upgrade
- [ ] No scan loss during upgrade

### 6.3 At Team Limit Upgrade
- [ ] Team user with 5/5 team members can upgrade
- [ ] After upgrade to Growth, shows 5/25
- [ ] Can immediately invite more members

### 6.4 Failed Payment Recovery
- [ ] Failed payment shows clear error
- [ ] User remains on current tier
- [ ] Retry payment option available
- [ ] No partial upgrade state

### 6.5 Concurrent Usage During Upgrade
- [ ] In-progress scans continue during upgrade
- [ ] API calls in flight complete successfully
- [ ] No data loss during tier transition

---

## 7. Upgrade UI/UX

### 7.1 Upgrade Prompts
- [ ] Scan quota exceeded shows upgrade prompt
- [ ] Project quota exceeded shows upgrade prompt
- [ ] File limit exceeded shows upgrade prompt
- [ ] API access denied (Developer) shows upgrade to Growth prompt
- [ ] API quota exceeded shows upgrade prompt
- [ ] Team invite blocked shows upgrade prompt
- [ ] Feature gated shows upgrade prompt with required tier
- [ ] All prompts link to pricing page
- [ ] Sidebar locked nav items navigate to page with TierGate upgrade prompt
- [ ] Dashboard feature discovery cards navigate to gated page with upgrade prompt
- [ ] Scan quota pre-check (ContractDetail) shows toast error with upgrade link
- [ ] Scan quota pre-check (ContractsList) redirects to /pricing
- [ ] Batch scan modal disables submit and shows quota warning when at limit
- [ ] TierGate shows next-tier pricing (not required-tier pricing)

### 7.2 Confirmation Flow
- [ ] Upgrade confirmation modal shown
- [ ] Current tier displayed
- [ ] New tier benefits listed
- [ ] Price clearly shown
- [ ] Cancel option available
- [ ] Terms/conditions link if applicable

### 7.3 Success State
- [ ] Success message displayed after upgrade
- [ ] Dashboard immediately reflects new tier
- [ ] Quota widget updates to new limits
- [ ] Email confirmation sent
- [ ] New features highlighted/introduced

---

## 8. UpgradeBanner Component (v0.30.1)

### 8.1 Banner Display
- [ ] UpgradeBanner appears at top of dashboard (below TopBar)
- [ ] Shows for all authenticated users except Enterprise tier
- [ ] Displays gradient background (indigo to purple)
- [ ] Shows sparkles icon on left
- [ ] Message shows "Upgrade to {next tier} to unlock more features"
- [ ] Shows up to 3 feature highlights for next tier (desktop only)
- [ ] Price badge visible (e.g., "$199/mo")
- [ ] "View Plans" button links to /pricing

### 8.2 Tier-Based Messaging
- [ ] Developer user sees: "Upgrade to Starter..."
- [ ] Starter user sees: "Upgrade to Growth..."
- [ ] Growth user sees: "Upgrade to Enterprise..."
- [ ] Enterprise user: Banner NOT shown

### 8.3 Feature Highlights per Tier

**Starter tier highlights shown to Developer users:**
- [ ] Quality Gates
- [ ] CI/CD Integration
- [ ] Team Collaboration (5 users)

**Growth tier highlights shown to Starter users:**
- [ ] Full API Access
- [ ] 100 AI Explanations/month
- [ ] Up to 25 team members

**Enterprise tier highlights shown to Growth users:**
- [ ] Unlimited AI
- [ ] SSO/SAML
- [ ] Custom SLAs
- [ ] Project Access Control
- [ ] Unlimited team members

### 8.4 Dismissal Behavior
- [ ] X button visible on right side
- [ ] Click X dismisses banner
- [ ] Banner stays hidden for 7 days (default)
- [ ] After 7 days, banner reappears
- [ ] Dismissal stored in localStorage as timestamp
- [ ] Storage key: `upgrade-banner-dismissed:{userId}` (scoped by user ID since v0.42.0)
- [ ] Different users on same browser have independent dismissal state

### 8.5 Persistence Verification
```javascript
// Check localStorage (replace {userId} with actual user UUID)
localStorage.getItem('upgrade-banner-dismissed:{userId}')
// Returns timestamp (e.g., "1736784000000") or null

// Force banner to reappear (testing)
localStorage.removeItem('upgrade-banner-dismissed:{userId}')

// Legacy unscoped key is cleaned up on logout (v0.42.0)
// localStorage.removeItem('upgrade-banner-dismissed')
```

### 8.6 Configuration Props
- [ ] `storageKey` - Custom key for multiple banners
- [ ] `reappearAfterDays` - Days before reappearing (default: 7)
- [ ] `targetTier` - Override auto-detected next tier
- [ ] `message` - Custom message text
- [ ] `highlightFeature` - Single feature to highlight

### 8.7 Global Placement
- [ ] Banner appears on ALL authenticated pages
- [ ] Located in App.tsx AppContent component
- [ ] Positioned after TopBar, before main content
- [ ] Only renders when `isAuthenticated` is true

---

## 9. API Upgrade Responses

### 9.1 Tier Check Endpoint
- [ ] GET /api/v1/users/me/quota returns correct tier
- [ ] Response includes all quota fields:
  - tier
  - monthly_scan_limit
  - monthly_scans_used
  - max_files_per_scan
  - max_projects
  - monthly_api_calls_limit
  - monthly_api_calls_used
  - max_team_members
  - result_retention_days
  - quota_reset_at
- [ ] Response updates immediately after upgrade

### 9.2 Quota Exceeded Responses

**Scan Quota (402)**:
```json
{
  "detail": "Monthly scan limit reached (10/10). Upgrade to Starter for 100 scans/month.",
  "current_tier": "developer",
  "upgrade_url": "/pricing"
}
```

**API Access Denied (403)**:
```json
{
  "detail": "API access not available on Developer tier. Upgrade to Growth for full API access.",
  "current_tier": "developer",
  "required_tier": "growth"
}
```

**API Quota Exceeded (429)**:
```json
{
  "detail": "API call limit reached (1000/month). Resets 2026-02-01. Upgrade for more calls.",
  "current_tier": "starter",
  "upgrade_url": "/pricing"
}
```

**Team Seat Limit (403)**:
```json
{
  "detail": "Team seat limit reached (5/5). Upgrade to Growth for 25 seats.",
  "current_tier": "starter",
  "required_tier": "growth"
}
```

---

## 10. x402 Credits as Alternative to Upgrade

### 10.1 Credits Purchase Option
- [ ] "Buy Credits" option visible when at scan limit
- [ ] Credits page accessible from upgrade prompts
- [ ] Can purchase credits without subscription upgrade
- [ ] Credits bypass monthly scan limit

### 10.2 Credits Display
- [ ] Current credit balance shown
- [ ] Credit pricing tiers displayed:
  - Micro (1-5 files, 4K LoC): $3.00
  - Small (6-25 files, 20K LoC): $7.00
  - Medium (26-100 files, 75K LoC): $15.00
  - Large (100+ files, Unlimited LoC): $25.00
- [ ] USDC payment option works

---

## Test Notes

_Record upgrade test results here:_

```
[Date] | [Upgrade Path] | [Result] | [Notes]
2026-01-03 | Migration 024 | Success | All tiers migrated correctly
```

---

**Related Documentation**:
- Pricing Tiers Specification: `TaskDocs-Apogee/phases/FREEMIUM-MODEL/PRICING-TIERS-SPECIFICATION.md`
- Quota System Tests: `docs/feature-tests/02-quota-system.md`
- Pricing Page Tests: `docs/feature-tests/07-pricing-page.md`
