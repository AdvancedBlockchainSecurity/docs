# Tier Upgrade Tests

**Priority**: P1 - High
**Last Updated**: January 3, 2026
**Related**: Freemium Model, Pricing Tiers, Migration 024

---

## Tier Reference

| Tier | Price | Scans/Mo | Users | Projects | API Calls/Mo |
|------|-------|----------|-------|----------|--------------|
| Free | $0 | 10 | 1 | 3 | 0 (no API) |
| Developer | $199/mo | 100 | 1 | 5 | 1,000 |
| Startup | $999/mo | 500 | 10 | 20 | 10,000 |
| Professional | $2,499/mo | Unlimited | 25 | Unlimited | Unlimited |
| Enterprise | Custom | Unlimited | Unlimited | Unlimited | Unlimited |

---

## 1. Free to Developer Upgrade

### 1.1 Upgrade Initiation
- [ ] Upgrade button visible on pricing page for Free users
- [ ] Upgrade button visible in quota widget when near limit
- [ ] Clicking upgrade navigates to checkout/payment flow
- [ ] User tier shown as "Free" before upgrade

### 1.2 Payment Processing
- [ ] Payment form loads correctly
- [ ] Valid payment method accepted ($199/month)
- [ ] Invalid payment method shows error
- [ ] Payment confirmation displayed

### 1.3 Post-Upgrade Verification
- [ ] User tier updated to "developer" in database
- [ ] Quota widget shows "Developer" tier label
- [ ] Scan limit increased to 100/month
- [ ] Files per scan increased to 50
- [ ] File size limit increased to 5 MB single / 25 MB archive
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
- [ ] Upgrade benefits clearly shown (team features, webhooks)
- [ ] Price shown ($999/month)
- [ ] Clicking upgrade navigates to payment flow

### 2.2 Payment Processing
- [ ] Payment form loads correctly
- [ ] Price difference handled correctly
- [ ] Payment confirmation displayed

### 2.3 Post-Upgrade Verification
- [ ] User tier updated to "startup" in database
- [ ] Quota widget shows "Startup" tier label
- [ ] Scan limit increased to 500/month
- [ ] Files per scan increased to 100
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
- [ ] Price shown ($2,499/month)
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
- [ ] User at 10/10 scans can initiate upgrade
- [ ] After upgrade to Developer, user shows 10/100
- [ ] After upgrade to Professional, user shows 10/Unlimited
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

## 8. API Upgrade Responses

### 8.1 Tier Check Endpoint
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

### 8.2 Quota Exceeded Responses

**Scan Quota (402)**:
```json
{
  "detail": "Monthly scan limit reached (10/10). Upgrade to Developer for 100 scans/month.",
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

## 9. x402 Credits as Alternative to Upgrade

### 9.1 Credits Purchase Option
- [ ] "Buy Credits" option visible when at scan limit
- [ ] Credits page accessible from upgrade prompts
- [ ] Can purchase credits without subscription upgrade
- [ ] Credits bypass monthly scan limit

### 9.2 Credits Display
- [ ] Current credit balance shown
- [ ] Credit pricing tiers displayed:
  - Small (1-10 files): $1.00
  - Medium (11-50 files): $3.00
  - Large (51-100 files): $5.00
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
