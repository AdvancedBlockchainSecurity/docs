# Quota Management Frontend

**Repository:** blocksecops-dashboard
**Version:** 0.5.7+
**Port:** 3000
**Status:** ✅ Production Ready
**Last Updated:** February 12, 2026

---

## Overview

The quota management frontend provides users with visibility into their subscription limits and enforces quota restrictions at the UI level. It prevents users from submitting scans when their quota is exceeded and provides clear upgrade paths.

---

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Backend API                             │
│  GET /users/me/enhanced                                     │
│  Returns: user object with quota property                   │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    AuthContext                              │
│  Stores: user.quota from API response                       │
│  Updates: On login, session refresh, profile fetch          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    useQuota Hook                            │
│  Computes: derived quota state                              │
│  Exports: QuotaStatus interface                             │
└─────────────────┬───────────────────────────────────────────┘
                  │
          ┌───────┼───────┬───────────────┐
          ▼       ▼       ▼               ▼
       TopBar  Contract  Settings     Other
       Banner  Upload    QuotaCard    Components
               Modal
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `useQuota` | `src/hooks/useQuota.ts` | Quota state management hook |
| `TopBar` | `src/components/navigation/TopBar.tsx` | Quota warning banner |
| `ContractUploadModal` | `src/components/contracts/ContractUploadModal.tsx` | Scan submission with quota check |
| `QuotaUsageCard` | `src/components/settings/QuotaUsageCard.tsx` | Detailed quota display |
| `QuotaContext` | `src/contexts/QuotaContext.tsx` | HTTP 402 interception |

---

## useQuota Hook

### Interface

```typescript
interface QuotaStatus {
  // Basic quota info
  tier: string;
  scansUsed: number;
  scanLimit: number | null;
  scansRemaining: number | null;
  isUnlimited: boolean;

  // Usage percentage
  usagePercent: number;
  isNearLimit: boolean;  // >= 80%
  isAtLimit: boolean;    // >= 100%

  // File limits
  maxFilesPerScan: number | null;

  // Reset info
  resetDate: Date | null;
  daysUntilReset: number;

  // Can perform actions
  canCreateScan: boolean;

  // Tier features
  canUseWebhooks: boolean;
  canExportReports: boolean;
  canUsePrivateScanners: boolean;
}

// Hook return type
function useQuota(): QuotaStatus & {
  isLoading: boolean;
  refresh: () => void
};
```

### Usage Example

```typescript
import { useQuota } from '@/hooks/useQuota';

function MyScanComponent() {
  const quota = useQuota();

  if (quota.isLoading) {
    return <Spinner />;
  }

  return (
    <div>
      <p>Scans: {quota.scansUsed} / {quota.scanLimit ?? 'Unlimited'}</p>
      <p>Remaining: {quota.scansRemaining ?? 'Unlimited'}</p>

      <button
        disabled={!quota.canCreateScan}
        onClick={startScan}
      >
        {quota.canCreateScan ? 'Start Scan' : 'Quota Exceeded'}
      </button>
    </div>
  );
}
```

---

## UI Components

### 1. TopBar Quota Warning Banner

Shows a warning banner when user is running low on scans.

**Trigger Conditions:**
- User is authenticated
- Not loading
- Not unlimited tier
- 2 or fewer scans remaining

**Visual States:**
| Scans Remaining | Banner Color | Background | Text Color |
|-----------------|--------------|------------|------------|
| 0 | Red | `bg-red-100` | `text-red-800` |
| 1-2 | Yellow | `bg-yellow-100` | `text-yellow-800` |
| 3+ | Hidden | - | - |

**Location:** Above the main header, full width

**Actions:** "Upgrade" link navigates to `/settings`

---

### 2. ContractUploadModal Quota Status

Shows quota status inside the scan creation modal.

**Banner Location:** Below modal title, above form fields

**Visual States:**
| Usage | Banner Color | Border |
|-------|--------------|--------|
| < 80% | Blue | `border-blue-200` |
| 80-99% | Yellow | `border-yellow-200` |
| 100% | Red | `border-red-200` |
| Unlimited | Blue | `border-blue-200` |

**Button States:**
| Quota Status | Button | Text | Style |
|--------------|--------|------|-------|
| Can scan | Enabled | "Start Scan" | Blue |
| At limit | Disabled | "Quota Exceeded" | Gray, cursor-not-allowed |

---

### 3. QuotaUsageCard (Settings Page)

Comprehensive quota display in user settings.

**Sections:**
1. **Header** - Tier badge (Free, Pro, Enterprise)
2. **Usage Stats** - Progress bars for Scans, API Calls, Storage
3. **Reset Info** - Days until quota reset
4. **Plan Features** - Feature availability checkmarks
5. **Upgrade CTA** - Upgrade button (hidden for Enterprise)

**Progress Bar Colors:**
| Usage | Bar Color |
|-------|-----------|
| < 80% | Blue (`bg-blue-500`) |
| 80-99% | Yellow (`bg-yellow-500`) |
| 100% | Red (`bg-red-500`) |

---

## Tier Configuration

### Limits by Tier

| Tier | Monthly Scans | Max Files/Scan | Storage | API Calls |
|------|---------------|----------------|---------|-----------|
| Free | 10 | 25 | 1 GB | 1,000 |
| Pro | Unlimited | 100 | 50 GB | 50,000 |
| Enterprise | Unlimited | Unlimited | Unlimited | Unlimited |

### Feature Availability

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| Private Scanners | ❌ | ✅ | ✅ |
| Export Reports | ❌ | ✅ | ✅ |
| Webhooks | ❌ | ✅ | ✅ |
| API Access | ✅ | ✅ | ✅ |
| Priority Queue | ❌ | ✅ | ✅ |

---

## HTTP 402 Handling

The `QuotaContext` provides an Axios interceptor that catches HTTP 402 (Payment Required) responses and displays the `QuotaExceededModal`.

### Flow

```
1. User submits scan request
2. API returns HTTP 402 (quota exceeded)
3. Axios interceptor catches response
4. QuotaContext shows QuotaExceededModal
5. User clicks "Upgrade" → navigates to /settings
6. Or clicks "Close" → modal dismissed
```

### QuotaExceededModal

**Location:** `src/components/common/QuotaExceededModal.tsx`

**Content:**
- Warning icon
- "Quota Limit Reached" title
- Explanation text
- Current usage display
- "Upgrade Now" button (primary)
- "Close" button (secondary)

---

## Quota API Response

### From GET /users/me/enhanced

```json
{
  "id": "uuid",
  "email": "user@example.com",
  "tier": "developer",
  "quota": {
    "tier": "developer",
    "monthly_scan_limit": 3,
    "monthly_scans_used": 1,
    "scans_remaining": 2,
    "percentage_used": 33.3,
    "max_files_per_scan": 5,
    "webhooks_enabled": false,
    "export_enabled": false,
    "api_access_enabled": false,
    "scan_priority": 50,
    "quota_reset_at": "2026-02-01T00:00:00Z"
  }
}
```

---

## Debugging

### Console Logs

The `useQuota` hook outputs debug logs:

```javascript
[useQuota] user: {id: '...', email: '...', ...}
[useQuota] user.quota: {tier: 'developer', monthly_scan_limit: 3, ...}
[useQuota] isInitializing: false
[useQuota] Quota data found: {tier: 'developer', ...}
[useQuota] scanLimit: 10 scansUsed: 7
```

### Common Issues

1. **Quota not showing**: Check AuthContext user.quota is populated
2. **Banner not appearing**: Verify scansRemaining <= 2 and not unlimited
3. **Settings page crash**: Ensure null-safe defaults for all quota properties

---

## Related Documentation

- [Session Documentation](/Users/pwner/Git/ABS/TaskDocs-Apogee/DOCUMENTATION-UPDATE-2025-11-25-SESSION-3.md)
- [Phase 3.1b Tier Features](/Users/pwner/Git/ABS/TaskDocs-Apogee/phases/)
- [Authentication Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/authentication-frontend.md)
- [Notification Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/notification-frontend.md)
- [Project Contracts Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/project-contracts-frontend.md)
- [Dashboard Development Standards](/Users/pwner/Git/ABS/docs/standards/dashboard-development.md)
