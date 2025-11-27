# Tier Upgrade Tests

**Priority**: P1 - High
**Last Tested**: _Not yet tested_
**Related**: Freemium Model, Pricing Tiers

---

## 1. Free to Pro Upgrade

### 1.1 Upgrade Initiation
- [ ] Upgrade button visible on pricing page for Free users
- [ ] Upgrade button visible in quota widget when near limit
- [ ] Clicking upgrade navigates to checkout/payment flow
- [ ] User tier shown as "Free" before upgrade

### 1.2 Payment Processing
- [ ] Payment form loads correctly
- [ ] Valid payment method accepted
- [ ] Invalid payment method shows error
- [ ] Payment confirmation displayed

### 1.3 Post-Upgrade Verification
- [ ] User tier updated to "Pro" in database
- [ ] Quota widget shows "Pro" tier label
- [ ] Scan limit increased to 100/month
- [ ] File limit increased to 100 per scan
- [ ] File size limit increased to 5 MB
- [ ] Priority queue level updated
- [ ] All scanners now accessible

### 1.4 Quota Preservation
- [ ] Existing scans_used count preserved
- [ ] New higher limit applied immediately
- [ ] User can scan if under new limit

---

## 2. Free to Enterprise Upgrade

### 2.1 Upgrade Initiation
- [ ] "Contact Sales" button visible for Enterprise tier
- [ ] Contact form or email link works
- [ ] Sales inquiry submitted successfully

### 2.2 Admin-Applied Upgrade
- [ ] Admin can upgrade user to Enterprise
- [ ] User notified of upgrade

### 2.3 Post-Upgrade Verification
- [ ] User tier updated to "Enterprise" in database
- [ ] Quota widget shows "Enterprise" tier label
- [ ] Scan limit shows "Unlimited"
- [ ] File limit shows "Unlimited"
- [ ] File size limit increased to 10 MB
- [ ] Highest priority queue level applied
- [ ] All scanners including custom accessible
- [ ] SLA features enabled

---

## 3. Pro to Enterprise Upgrade

### 3.1 Upgrade Initiation
- [ ] "Contact Sales" or upgrade option visible for Pro users
- [ ] Contact form pre-fills user info
- [ ] Sales inquiry submitted successfully

### 3.2 Post-Upgrade Verification
- [ ] User tier updated to "Enterprise" in database
- [ ] Quota widget shows "Enterprise" tier label
- [ ] All Enterprise features enabled
- [ ] Priority queue upgraded
- [ ] Existing project data preserved

---

## 4. Upgrade Edge Cases

### 4.1 Mid-Cycle Upgrade
- [ ] Upgrade during billing cycle works
- [ ] Prorated charges applied correctly (if applicable)
- [ ] New limits effective immediately

### 4.2 At Quota Limit Upgrade
- [ ] User at 10/10 scans can upgrade
- [ ] After upgrade, user can scan (now 10/100)
- [ ] No scan loss during upgrade

### 4.3 Failed Payment Recovery
- [ ] Failed payment shows clear error
- [ ] User remains on current tier
- [ ] Retry payment option available
- [ ] No partial upgrade state

---

## 5. Upgrade UI/UX

### 5.1 Upgrade Prompts
- [ ] Quota exceeded shows upgrade prompt
- [ ] File limit exceeded shows upgrade prompt
- [ ] Feature gated shows upgrade prompt
- [ ] All prompts link to pricing/upgrade page

### 5.2 Confirmation Flow
- [ ] Upgrade confirmation modal shown
- [ ] New tier benefits displayed
- [ ] Price clearly shown
- [ ] Cancel option available

### 5.3 Success State
- [ ] Success message displayed after upgrade
- [ ] Dashboard reflects new tier
- [ ] Email confirmation sent (if applicable)

---

## 6. API Upgrade Responses

### 6.1 Tier Check Endpoint
- [ ] GET /api/v1/user/tier returns correct tier
- [ ] Response includes all tier limits
- [ ] Response updates immediately after upgrade

### 6.2 Quota Exceeded Response
- [ ] 402 response includes upgrade_url
- [ ] Response includes current tier
- [ ] Response includes required tier for action

---

## Test Notes

_Record upgrade test results here:_

```
[Date] | [Upgrade Path] | [Result] | [Notes]
```
