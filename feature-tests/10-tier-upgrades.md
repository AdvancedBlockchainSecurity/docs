# Tier Upgrade Tests

**Priority**: P1 - High
**Last Updated**: January 13, 2026
**Related**: Freemium Model, Pricing Tiers, Migration 024, Migration 030, UpgradeBanner (v0.30.1)

---

## Tier Reference

| Tier | Price | Scans/Mo | Files/Scan | Users | Projects | API Calls/Mo |
|------|-------|----------|------------|-------|----------|--------------|
| Free | $0 | 3 | 5 | 1 | 3 | 0 (no API) |
| Developer | $189/mo | 100 | Unlimited | 1 | 5 | 1,000 |
| Startup | $489/mo | 500 | Unlimited | 10 | 20 | 10,000 |
| Professional | $1,956/mo | Unlimited | Unlimited | 25 | Unlimited | Unlimited |
| Enterprise | Custom | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited |

---

## 1. Free to Developer Upgrade

### 1.1 Upgrade Initiation
- [ ] Upgrade button visible on pricing page for Free users
- [ ] Upgrade button visible in quota widget when near limit
- [ ] Clicking upgrade navigates to checkout/payment flow
- [ ] User tier shown as "Free" before upgrade

### 1.2 Payment Processing
- [ ] Payment form loads correctly
- [ ] Valid payment method accepted ($189/month)
- [ ] Invalid payment method shows error
- [ ] Payment confirmation displayed

### 1.3 Post-Upgrade Verification
- [ ] User tier updated to "developer" in database
- [ ] Quota widget shows "Developer" tier label
- [ ] Scan limit increased to 100/month
- [ ] Files per scan now unlimited (-1)
- [ ] LoC per scan now unlimited (-1)
- [ ] File size limit increased to 5 MB single / 25 MB archive
- [ ] Export enabled (PDF, JSON, SARIF)
- [ ] Projects limit increased to 5
- [ ] API access enabled (1,000 calls/month)
- [ ] Priority queue level updated (40)
- [ ] All 17+ scanners now accessible

### 1.4 Quota Preservation
- [ ] Existing monthly_scans_used count preserved
- [ ] New higher limit applied immediately
- [ ] User can scan if under new limit

---

## 2. Developer to Startup Upgrade

### 2.1 Upgrade Initiation
- [ ] "Upgrade to Startup" button visible for Developer users
- [ ] Upgrade benefits clearly shown (team features, webhooks, CI/CD)
- [ ] Price shown ($489/month)
- [ ] Clicking upgrade navigates to payment flow

### 2.2 Payment Processing
- [ ] Payment form loads correctly
- [ ] Price difference handled correctly
- [ ] Payment confirmation displayed

### 2.3 Post-Upgrade Verification
- [ ] User tier updated to "startup" in database
- [ ] Quota widget shows "Startup" tier label
- [ ] Scan limit increased to 500/month
- [ ] Files per scan remains unlimited (-1)
- [ ] File size limit increased to 10 MB single / 50 MB archive
- [ ] Projects limit increased to 20
- [ ] API calls increased to 10,000/month
- [ ] Priority queue level updated (25)
- [ ] Team management enabled (up to 10 members)
- [ ] Webhooks enabled
- [ ] Result retention increased to 180 days

### 2.4 Team Features Unlocked
- [ ] Team invite functionality now available
- [ ] Can invite up to 9 additional members
- [ ] Basic RBAC enabled

---

## 3. Startup to Professional Upgrade

### 3.1 Upgrade Initiation
- [ ] "Upgrade to Professional" button visible for Startup users
- [ ] Upgrade benefits clearly shown (unlimited, organizations, audit)
- [ ] Price shown ($1,956/month)
- [ ] Clicking upgrade navigates to payment flow

### 3.2 Payment Processing
- [ ] Payment form loads correctly
- [ ] Price difference handled correctly
- [ ] Payment confirmation displayed

### 3.3 Post-Upgrade Verification
- [ ] User tier updated to "professional" in database
- [ ] Quota widget shows "Professional" tier label
- [ ] Scan limit shows "Unlimited" (-1 in database)
- [ ] Files per scan shows "Unlimited" (-1 in database)
- [ ] Projects shows "Unlimited" (-1 in database)
- [ ] API calls shows "Unlimited" (-1 in database)
- [ ] Priority queue level updated (10)
- [ ] Team increased to 25 members max
- [ ] Organizations feature enabled
- [ ] Audit logging enabled
- [ ] Result retention increased to 365 days

---

## 4. Professional to Enterprise Upgrade

### 4.1 Upgrade Initiation
- [ ] "Contact Sales" button visible for Professional users
- [ ] Contact form or email link works
- [ ] Sales inquiry submitted successfully
- [ ] User receives confirmation of inquiry

### 4.2 Admin-Applied Upgrade
- [ ] Admin can upgrade user to Enterprise
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

## 5. Free to Higher Tiers (Skip Upgrades)

### 5.1 Free to Startup
- [ ] Direct upgrade path available
- [ ] No requirement to go through Developer first
- [ ] Team features enabled immediately
- [ ] All Startup limits applied

### 5.2 Free to Professional
- [ ] Direct upgrade path available
- [ ] Unlimited features enabled immediately
- [ ] Organizations and audit logging available

### 5.3 Free to Enterprise
- [ ] "Contact Sales" flow works
- [ ] Admin can apply Enterprise directly to Free user
- [ ] All Enterprise features enabled

---

## 6. Upgrade Edge Cases

### 6.1 Mid-Cycle Upgrade
- [ ] Upgrade during billing cycle works
- [ ] Prorated charges applied correctly (if applicable)
- [ ] New limits effective immediately
- [ ] No gap in service

### 6.2 At Quota Limit Upgrade
- [ ] User at 3/3 scans (Free tier) can initiate upgrade
- [ ] After upgrade to Developer, user shows 3/100
- [ ] After upgrade to Professional, user shows 3/Unlimited
- [ ] User can scan immediately after upgrade
- [ ] No scan loss during upgrade

### 6.3 At Team Limit Upgrade
- [ ] Startup user with 10/10 team members can upgrade
- [ ] After upgrade to Professional, shows 10/25
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
- [ ] API access denied (Free) shows upgrade to Developer prompt
- [ ] API quota exceeded shows upgrade prompt
- [ ] Team invite blocked shows upgrade prompt
- [ ] Feature gated shows upgrade prompt with required tier
- [ ] All prompts link to pricing page

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
- [ ] Price badge visible (e.g., "$189/mo")
- [ ] "View Plans" button links to /pricing

### 8.2 Tier-Based Messaging
- [ ] Free user sees: "Upgrade to Developer..."
- [ ] Developer user sees: "Upgrade to Startup..."
- [ ] Startup user sees: "Upgrade to Professional..."
- [ ] Professional user sees: "Upgrade to Enterprise..."
- [ ] Enterprise user: Banner NOT shown

### 8.3 Feature Highlights per Tier

**Developer tier highlights shown to Free users:**
- [ ] Quality Gates
- [ ] CI/CD Integration
- [ ] Priority Support

**Startup tier highlights shown to Developer users:**
- [ ] Team Collaboration
- [ ] 100 AI Explanations/month
- [ ] Advanced Analytics

**Professional tier highlights shown to Startup users:**
- [ ] 500 AI Explanations/month
- [ ] Custom Integrations
- [ ] Dedicated Support

**Enterprise tier highlights shown to Professional users:**
- [ ] Unlimited AI
- [ ] SSO/SAML
- [ ] Custom SLAs
- [ ] Project Access Control

### 8.4 Dismissal Behavior
- [ ] X button visible on right side
- [ ] Click X dismisses banner
- [ ] Banner stays hidden for 7 days (default)
- [ ] After 7 days, banner reappears
- [ ] Dismissal stored in localStorage as timestamp
- [ ] Storage key: `upgrade-banner-dismissed`

### 8.5 Persistence Verification
```javascript
// Check localStorage
localStorage.getItem('upgrade-banner-dismissed')
// Returns timestamp (e.g., "1736784000000") or null

// Force banner to reappear (testing)
localStorage.removeItem('upgrade-banner-dismissed')
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
  "detail": "Monthly scan limit reached (3/3). Upgrade to Developer for 100 scans/month.",
  "current_tier": "free",
  "upgrade_url": "/pricing"
}
```

**API Access Denied (403)**:
```json
{
  "detail": "API access not available on Free tier. Upgrade to Developer.",
  "current_tier": "free",
  "required_tier": "developer"
}
```

**API Quota Exceeded (429)**:
```json
{
  "detail": "API call limit reached (1000/month). Resets 2026-02-01. Upgrade for more calls.",
  "current_tier": "developer",
  "upgrade_url": "/pricing"
}
```

**Team Seat Limit (403)**:
```json
{
  "detail": "Team seat limit reached (10/10). Upgrade to Professional for 25 seats.",
  "current_tier": "startup",
  "required_tier": "professional"
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
- Pricing Tiers Specification: `TaskDocs-BlockSecOps/phases/FREEMIUM-MODEL/PRICING-TIERS-SPECIFICATION.md`
- Quota System Tests: `docs/feature-tests/02-quota-system.md`
- Pricing Page Tests: `docs/feature-tests/07-pricing-page.md`
