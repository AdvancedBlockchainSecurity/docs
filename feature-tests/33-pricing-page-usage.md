# Feature Test: Pricing Page Usage Display

**Feature**: Pricing Page Subscription Alignment
**Version**: 0.23.1 (Dashboard)
**Date**: December 31, 2025
**Status**: Implemented

---

## Overview

The Pricing page now displays the authenticated user's current plan and usage statistics, aligning with the data shown on the Billing page. This helps users understand their current consumption while browsing pricing options.

## Test Cases

### TC-33.1: Anonymous User View

**Objective**: Verify anonymous users see standard pricing page without personalization

**Steps**:
1. Clear browser session/cookies
2. Navigate to http://127.0.0.1:3000/pricing

**Expected Results**:
- [ ] No CurrentPlanBanner displayed
- [ ] All tier cards show "Get Started" buttons
- [ ] No tier is highlighted as current
- [ ] Page renders normally with all tier options

---

### TC-33.2: Authenticated User - Current Plan Banner

**Objective**: Verify CurrentPlanBanner displays for logged-in users

**Prerequisites**:
- User authenticated with known tier and usage

**Steps**:
1. Log in to dashboard
2. Navigate to /pricing

**Expected Results**:
- [ ] CurrentPlanBanner appears below page header
- [ ] Banner shows correct tier badge (Free, Pro, Enterprise, etc.)
- [ ] Banner shows scan usage (e.g., "27 / 10,000 scans")
- [ ] Progress bar reflects usage percentage
- [ ] "Manage Plan" button visible
- [ ] Clicking "Manage Plan" navigates to /billing

---

### TC-33.3: Current Tier Card Highlighting

**Objective**: Verify user's current tier card is visually distinguished

**Prerequisites**:
- User authenticated with known tier

**Steps**:
1. Log in to dashboard
2. Navigate to /pricing
3. Locate user's current tier card

**Expected Results**:
- [ ] Current tier card has green ring border
- [ ] "YOUR PLAN" badge displayed above tier name
- [ ] Usage stats shown inline on card
- [ ] Progress bar on current tier card
- [ ] Button says "Manage Plan" (not "Get Started")

---

### TC-33.4: Developer Tier User View

**Objective**: Verify Developer tier users see appropriate display

**Prerequisites**:
- User on Developer tier (free) with some usage

**Steps**:
1. Log in as Developer tier user
2. Navigate to /pricing

**Expected Results**:
- [ ] CurrentPlanBanner shows "Developer" tier badge
- [ ] Usage shows "X / 3 scans" format
- [ ] Developer tier card highlighted
- [ ] Other tiers show upgrade options

---

### TC-33.5: Starter/Growth/Enterprise Tier User View

**Objective**: Verify Starter/Growth/Enterprise users see appropriate display

**Prerequisites**:
- User on Starter, Growth, or Enterprise tier

**Steps**:
1. Log in as Starter/Growth/Enterprise user
2. Navigate to /pricing

**Expected Results**:
- [ ] CurrentPlanBanner shows correct tier badge
- [ ] Usage shows appropriate format
- [ ] Correct tier card highlighted
- [ ] Lower tiers not highlighted

---

### TC-33.6: Unlimited Tier Display

**Objective**: Verify unlimited tiers display correctly

**Prerequisites**:
- User on tier with unlimited scans (e.g., Enterprise)

**Steps**:
1. Log in as user with unlimited scans
2. Navigate to /pricing

**Expected Results**:
- [ ] CurrentPlanBanner shows "Unlimited" badge
- [ ] Usage shows "X scans used" (no limit)
- [ ] No progress bar displayed (or always full/green)
- [ ] No near-limit/at-limit warnings

---

### TC-33.7: Near Limit Warning (80%+ Usage)

**Objective**: Verify warning display when near quota limit

**Prerequisites**:
- User with 80%+ quota usage (e.g., 3/3 scans on Developer tier, or 12/15 on Starter)

**Steps**:
1. Log in as user near limit
2. Navigate to /pricing

**Expected Results**:
- [ ] CurrentPlanBanner has yellow warning styling
- [ ] "Near Limit" badge displayed
- [ ] Progress bar is yellow
- [ ] Usage percentage shows correctly

---

### TC-33.8: At Limit Display (100% Usage)

**Objective**: Verify display when at quota limit

**Prerequisites**:
- User at 100% quota (e.g., 3/3 scans on Developer tier)

**Steps**:
1. Log in as user at limit
2. Navigate to /pricing

**Expected Results**:
- [ ] CurrentPlanBanner has red warning styling
- [ ] "Limit Reached" badge displayed
- [ ] Progress bar is red
- [ ] Upgrade CTA section visible
- [ ] "Buy Credits" and "Upgrade to Starter" buttons displayed

---

### TC-33.9: Quota Reset Date Display

**Objective**: Verify quota reset date is shown

**Prerequisites**:
- User with limited tier and known reset date

**Steps**:
1. Log in to dashboard
2. Navigate to /pricing

**Expected Results**:
- [ ] Reset date displayed (e.g., "Quota resets on Jan 15, 2026")
- [ ] Date format is readable (Month Day, Year)
- [ ] Not displayed for unlimited tiers

---

### TC-33.10: WebSocket Notification Behavior

**Objective**: Verify no spurious connect/disconnect toasts on page load

**Steps**:
1. Clear browser session
2. Log in to dashboard
3. Navigate to /pricing
4. Observe toast notifications

**Expected Results**:
- [ ] No "Connected" toast on page load
- [ ] No "Disconnected" toast on page load
- [ ] Console may show WebSocket activity, but no user-facing toasts
- [ ] Only show connection toasts on actual state changes after initial connection

---

### TC-33.11: Scroll to Tier on Upgrade Click

**Objective**: Verify "Upgrade to Starter" scrolls to Starter tier card

**Prerequisites**:
- User at limit with upgrade CTAs visible

**Steps**:
1. Navigate to /pricing as at-limit user
2. Click "Upgrade to Starter" button in CurrentPlanBanner

**Expected Results**:
- [ ] Page scrolls to Starter tier card
- [ ] Scroll is smooth animation
- [ ] Starter tier card is visible in viewport

---

### TC-33.12: Credits Navigation

**Objective**: Verify "Buy Credits" navigates correctly

**Prerequisites**:
- User at limit with upgrade CTAs visible

**Steps**:
1. Navigate to /pricing as at-limit user
2. Click "Buy Credits" button

**Expected Results**:
- [ ] Navigates to /credits page
- [ ] Credits page loads correctly

---

## UI Reference

### CurrentPlanBanner Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  YOUR CURRENT PLAN                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [Icon] Your Current Plan                                 │  │
│  │        [Free] [Near Limit] (if applicable)               │  │
│  │                                           [Manage Plan →]│  │
│  │                                                          │  │
│  │ 8 / 10 scans                                    80% used │  │
│  │ [████████████████████░░░░░]                              │  │
│  │ Quota resets on Jan 15, 2026                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Tier Card Highlighting

```
┌─────────────────────┐     ┌─────────────────────┐
│                     │     │ ═══════════════════ │ ← Green ring
│     DEVELOPER       │     │     YOUR PLAN       │
│                     │     │      STARTER        │
│     3 scans/mo      │     │    8 / 15           │ ← Usage stats
│                     │     │   [████░░░░░░░░░░]  │ ← Progress bar
│   [Get Started]     │     │    [Manage Plan]    │
└─────────────────────┘     └─────────────────────┘
```

---

## API Reference

### Data Source

The Pricing page uses data from the existing `/users/me/enhanced` endpoint via the `useQuota` hook:

```json
{
  "quota": {
    "tier": "developer",
    "monthly_scan_limit": 3,
    "monthly_scans_used": 2,
    "scans_remaining": 1,
    "percentage_used": 66.7,
    "quota_reset_at": "2026-04-01T00:00:00Z"
  }
}
```

### useQuota Hook Interface

```typescript
interface QuotaStatus {
  tier: string;
  scansUsed: number;
  scanLimit: number | null;
  scansRemaining: number;
  isUnlimited: boolean;
  usagePercent: number;
  isNearLimit: boolean;  // >= 80%
  isAtLimit: boolean;    // >= 100%
  resetDate: Date | null;
}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.23.0 | 2025-12-31 | Initial implementation of CurrentPlanBanner and tier highlighting |
| 0.23.1 | 2025-12-31 | Fixed WebSocket notification toasts on page load |
