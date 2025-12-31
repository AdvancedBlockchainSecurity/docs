# Pricing Page Usage Display

**Date**: December 31, 2025
**Dashboard Version**: 0.23.0 → 0.23.1

## Summary

Aligned the Pricing page (`/pricing`) with subscription data from the Billing page (`/billing`). Previously, the Pricing page only showed static tier limits without user context. Now, authenticated users see their current plan and usage directly on the pricing page.

## Changes

### New Component

**`src/components/pricing/CurrentPlanBanner.tsx`**

A banner component that displays at the top of the pricing page for authenticated users:
- Current tier badge (Free, Pro, Enterprise, Enterprise Broker)
- Scan usage with progress bar (e.g., "27 / 10,000 scans")
- Usage percentage visualization
- Quota reset date
- "Manage Plan" button linking to /billing
- Warning states for near-limit (80%+) and at-limit (100%)
- Upgrade CTAs when at limit

### Modified Files

**`src/pages/Pricing.tsx`**
- Integrated `useQuota` hook to access user quota data
- Added `CurrentPlanBanner` component for authenticated users
- Highlighted current tier card with:
  - "YOUR PLAN" badge
  - Green ring border
  - Inline usage stats with progress bar
  - "Manage Plan" button (instead of "Get Started")
- Added scroll-to anchor IDs for tier cards (`tier-free`, `tier-pro`, etc.)

**`src/hooks/useNotifications.ts`** (v0.23.1)
- Fixed spurious "Connected"/"Disconnected" toast notifications on page load
- Added state tracking to only show connection status changes after initial connection
- "Disconnected" only shows if previously connected
- "Reconnected" shows on reconnection (not initial connection)

## Technical Details

### Data Flow

```
AuthContext → user.quota → useQuota hook → Pricing page
                                         → CurrentPlanBanner
```

The implementation reuses the existing `useQuota` hook which derives computed values from `AuthContext.user.quota`. No additional API calls are needed.

### useQuota Hook Values Used

| Value | Type | Description |
|-------|------|-------------|
| tier | string | Current subscription tier |
| scansUsed | number | Scans used this period |
| scanLimit | number \| null | Monthly scan limit (-1 = unlimited) |
| isUnlimited | boolean | Whether tier has unlimited scans |
| usagePercent | number | Percentage of quota used |
| isNearLimit | boolean | True if usage >= 80% |
| isAtLimit | boolean | True if usage >= 100% |
| resetDate | Date \| null | Next quota reset date |

### Notification Fix Logic

```typescript
// State tracking
const hasConnectedOnce = useRef<boolean>(false);
const wasConnected = useRef<boolean>(false);

// Connected: Only show on REconnection
if (wasConnected.current) {
  toast.success('Reconnected', 'Real-time updates resumed');
}

// Disconnected: Only show if was previously connected
if (hasConnectedOnce.current && wasConnected.current) {
  toast.warning('Disconnected', 'Real-time updates paused...');
}
```

## UI Behavior

### Anonymous Users
- See standard pricing page with no banner
- All tier cards show "Get Started" buttons

### Authenticated Users
- See CurrentPlanBanner at top with usage summary
- Current tier card highlighted with green ring and "YOUR PLAN" badge
- Current tier shows inline usage stats
- Current tier button says "Manage Plan" instead of "Get Started"

### Edge Cases

| Case | Behavior |
|------|----------|
| Unlimited tier | Shows "Unlimited" badge, no progress bar |
| Near limit (80%+) | Yellow warning styling |
| At limit (100%) | Red styling, upgrade CTAs displayed |
| WebSocket fails initially | No toasts (expected on page load) |
| WebSocket reconnects | "Reconnected" toast only after disconnect |

## Files Modified

| File | Change |
|------|--------|
| `src/components/pricing/CurrentPlanBanner.tsx` | NEW - Usage banner component |
| `src/pages/Pricing.tsx` | Integrated banner and tier highlighting |
| `src/hooks/useNotifications.ts` | Fixed noisy connection toasts |
| `k8s/overlays/local/kustomization.yaml` | Version bump to 0.23.1 |

## Deployment

- Dashboard: 0.22.0 → 0.23.0 → 0.23.1
- No API changes required
- No database migrations needed
