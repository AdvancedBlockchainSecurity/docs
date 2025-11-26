# Pricing Page Tests

**Priority**: P2 - Medium
**Last Tested**: _Not yet tested_
**Related**: Phase 3.1b Frontend

---

## 1. Pricing Page Display

### 1.1 Page Load
- [ ] Pricing page accessible at /pricing
- [ ] Page loads without errors
- [ ] All three tiers displayed
- [ ] Responsive on mobile/tablet/desktop

### 1.2 Free Tier Card
- [ ] "Free" label displayed
- [ ] Price shown ($0/month)
- [ ] Feature list:
  - [ ] 10 scans/month
  - [ ] 25 files per scan
  - [ ] 1 MB file limit
  - [ ] Basic scanners
  - [ ] Community support
- [ ] "Current Plan" indicator (if user is Free)
- [ ] "Get Started" button (if not logged in)

### 1.3 Pro Tier Card
- [ ] "Pro" label displayed
- [ ] Price shown ($X/month)
- [ ] Feature list:
  - [ ] 100 scans/month
  - [ ] 100 files per scan
  - [ ] 5 MB file limit
  - [ ] All scanners
  - [ ] Priority queue
  - [ ] Email support
- [ ] "Upgrade" button (if user is Free)
- [ ] "Current Plan" indicator (if user is Pro)

### 1.4 Enterprise Tier Card
- [ ] "Enterprise" label displayed
- [ ] "Contact Sales" or custom pricing
- [ ] Feature list:
  - [ ] Unlimited scans
  - [ ] Unlimited files
  - [ ] 10 MB file limit
  - [ ] All scanners + custom
  - [ ] Highest priority
  - [ ] Dedicated support
  - [ ] SLA guarantee
- [ ] "Contact Sales" button

---

## 2. Current Tier Highlighting

### 2.1 Logged In User
- [ ] Current tier card highlighted
- [ ] "Current Plan" badge shown
- [ ] Upgrade options visible for lower tiers
- [ ] Downgrade info available (if applicable)

### 2.2 Not Logged In
- [ ] All tiers shown equally
- [ ] Sign up prompts visible
- [ ] No "Current Plan" indicator

---

## 3. Feature Comparison

### 3.1 Feature Matrix (if present)
- [ ] All features listed in rows
- [ ] Tiers in columns
- [ ] Checkmarks/values accurate
- [ ] Tooltips explain features

### 3.2 Limit Comparison
- [ ] Scan limits clearly shown
- [ ] File limits clearly shown
- [ ] Size limits clearly shown
- [ ] Scanner access clearly shown

---

## 4. Upgrade Flow

### 4.1 Upgrade Button
- [ ] "Upgrade" button visible for Free users
- [ ] Button links to upgrade page/checkout
- [ ] Stripe/payment integration works (if live)

### 4.2 Contact Sales
- [ ] Enterprise "Contact Sales" button works
- [ ] Opens email/form
- [ ] Pre-fills relevant info

---

## 5. Navigation

- [ ] Link to pricing in header/footer
- [ ] Back navigation works
- [ ] Deep link to /pricing works

---

## Test Notes

_Record pricing page test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
