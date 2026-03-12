# Notification System Frontend

**Repository:** blocksecops-dashboard
**Version:** 0.19.0+
**Port:** 3000 (Dashboard via Traefik), 8003 (WebSocket)
**Status:** Production Ready
**Last Updated:** December 30, 2025

---

## Overview

The notification system provides real-time toast notifications and WebSocket integration for live scan updates. It consists of a toast notification UI system and WebSocket event handlers that display notifications when scans progress, complete, or detect vulnerabilities.

---

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│              Notification Service (Port 8003)               │
│  Namespace: notification-local                              │
│  WebSocket: wss://app.0xapogee.com/ws (server/prod)    │
│  Events: scan_progress, scan_completed, vulnerability_found │
└─────────────────────┬───────────────────────────────────────┘
                      │ WebSocket Messages
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                WebSocketManager (Singleton)                 │
│  Location: src/lib/websocket/WebSocketManager.ts            │
│  - Maintains persistent connection                          │
│  - Auto-reconnect with exponential backoff                  │
│  - Event subscription/unsubscription                        │
└─────────────────────┬───────────────────────────────────────┘
                      │ Event Callbacks
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                  useNotifications Hook                      │
│  Location: src/hooks/useNotifications.ts                    │
│  - Subscribes to WebSocket events                           │
│  - Maps events to toast notifications                       │
│  - Prevents duplicate notifications                         │
└─────────────────────┬───────────────────────────────────────┘
                      │ Toast API Calls
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                     ToastContext                            │
│  Location: src/contexts/ToastContext.tsx                    │
│  - Global toast state management                            │
│  - Auto-dismiss timers                                      │
│  - Max toast limit (5)                                      │
└─────────────────────┬───────────────────────────────────────┘
                      │ State Updates
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                   ToastContainer                            │
│  Location: src/components/common/ToastContainer.tsx         │
│  - Renders toast stack                                      │
│  - Animation transitions                                    │
│  - Dismissible actions                                      │
└─────────────────────────────────────────────────────────────┘
```

### Component Hierarchy

```
App.tsx
├── ToastProvider (context)
│   ├── Router
│   │   ├── QuotaProvider
│   │   │   ├── NotificationHandler (WebSocket subscriber)
│   │   │   └── AppContent (routes)
│   │   └── ToastContainer (UI)
```

---

## Components

### 1. ToastContext (`src/contexts/ToastContext.tsx`)

Global context for managing toast state.

**Exports:**
- `ToastProvider` - Context provider component
- `useToast` - Hook to access toast methods

**Toast Interface:**

```typescript
interface Toast {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message?: string;
  duration?: number;  // ms, 0 = persistent
  dismissible?: boolean;
  action?: {
    label: string;
    onClick: () => void;
  };
  timestamp: number;
}
```

**Context Methods:**

```typescript
interface ToastContextValue {
  toasts: Toast[];
  addToast: (options: ToastOptions) => string;
  removeToast: (id: string) => void;
  clearAll: () => void;
  // Convenience methods
  success: (title: string, message?: string, duration?: number) => string;
  error: (title: string, message?: string, duration?: number) => string;
  warning: (title: string, message?: string, duration?: number) => string;
  info: (title: string, message?: string, duration?: number) => string;
}
```

**Default Durations:**

| Type | Duration |
|------|----------|
| success | 4000ms |
| error | 6000ms |
| warning | 5000ms |
| info | 4000ms |

---

### 2. ToastContainer (`src/components/common/ToastContainer.tsx`)

Renders the toast notification UI.

**Props:**

```typescript
interface ToastContainerProps {
  position?: 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left';
}
```

**Visual Styling by Type:**

| Type | Icon | Background | Border |
|------|------|------------|--------|
| success | CheckCircle | `bg-green-50` | `border-green-200` |
| error | XCircle | `bg-red-50` | `border-red-200` |
| warning | AlertTriangle | `bg-yellow-50` | `border-yellow-200` |
| info | Info | `bg-blue-50` | `border-blue-200` |

**Features:**
- Dismissible via X button (if `dismissible: true`)
- Action button support (e.g., "View Results")
- Animation on enter/exit
- Auto-dismiss progress indicator

---

### 3. useNotifications Hook (`src/hooks/useNotifications.ts`)

Integrates WebSocket events with toast notifications.

**Parameters:**

```typescript
interface NotificationSettings {
  scanProgress: boolean;      // default: false (too noisy)
  scanCompletion: boolean;    // default: true
  vulnerabilities: boolean;   // default: true
  criticalOnly: boolean;      // default: false
  connectionStatus: boolean;  // default: true
}

function useNotifications(settings?: Partial<NotificationSettings>);
```

**WebSocket Event Handlers:**

| Event | Behavior |
|-------|----------|
| `connection_status` | Shows "Connected" or "Disconnected" toast |
| `scan_progress` | Shows progress at 25%, 50%, 75%, 100% milestones |
| `scan_completed` | Shows completion with vulnerability summary, action button to view results |
| `vulnerability_found` | Shows alert with severity-based styling |

**Duplicate Prevention:**

The hook maintains a `Set` of shown notification IDs to prevent duplicate toasts when:
- WebSocket reconnects and replays events
- Component re-renders
- Same event received multiple times

**Returns:**

```typescript
{
  notifyScanStarted: (scanId: string, contractName?: string) => void;
  notifyScanFailed: (scanId: string, error?: string) => void;
  notifyExportComplete: (filename: string) => void;
  notifyError: (title: string, message?: string) => void;
  notifySuccess: (title: string, message?: string) => void;
  notifyWarning: (title: string, message?: string) => void;
  notifyInfo: (title: string, message?: string) => void;
}
```

---

### 4. useNotify Hook (`src/hooks/useNotifications.ts`)

Simplified hook for manual notifications without WebSocket subscription.

**Usage:**

```typescript
import { useNotify } from '@/hooks/useNotifications';

function MyComponent() {
  const notify = useNotify();

  const handleAction = async () => {
    notify.info('Starting', 'Processing your request...');
    try {
      await performAction();
      notify.success('Complete', 'Action completed successfully');
    } catch (error) {
      notify.error('Failed', error.message);
    }
  };

  return <button onClick={handleAction}>Do Action</button>;
}
```

**Available Methods:**

| Method | Use Case |
|--------|----------|
| `success(title, message?)` | Operation completed |
| `error(title, message?)` | Error occurred |
| `warning(title, message?)` | Warning condition |
| `info(title, message?)` | General information |
| `scanStarted(scanId, contractName?)` | Scan initiated |
| `scanCompleted(scanId, vulnCount)` | Scan finished |
| `scanFailed(error?)` | Scan error |
| `exportComplete(filename)` | File exported |
| `exportFailed(error?)` | Export error |
| `actionComplete(action)` | Generic action success |
| `actionFailed(action, error?)` | Generic action failure |

---

### 5. NotificationHandler (`src/components/common/NotificationHandler.tsx`)

Global component that initializes WebSocket notification subscription.

**Placement:** Inside `ToastProvider`, outside route components

**Behavior:**
- Only active when user is authenticated
- Initializes `useNotifications` with default settings
- Renders nothing (returns `null`)

---

## WebSocket Events

### Event Types

**ScanProgressData:**
```typescript
interface ScanProgressData {
  scan_id: string;
  progress: number;      // 0-100
  message?: string;
}
```

**ScanCompletedData:**
```typescript
interface ScanCompletedData {
  scan_id: string;
  status: string;
  total_vulnerabilities: number;
  critical_count?: number;
  high_count?: number;
  medium_count?: number;
  low_count?: number;
}
```

**VulnerabilityFoundData:**
```typescript
interface VulnerabilityFoundData {
  scan_id: string;
  vulnerability_id: string;
  title?: string;
  severity: string;
}
```

### Severity to Toast Type Mapping

| Severity | Toast Type |
|----------|------------|
| critical | error |
| high | warning |
| medium | info |
| low | info |

---

## Auto-Refresh Feature

### Location

`src/pages/DashboardAnalytics.tsx`

### Configuration

```typescript
const AUTO_REFRESH_INTERVAL = 30000; // 30 seconds
```

### UI Elements

| Element | Location | Description |
|---------|----------|-------------|
| Toggle switch | Header right side | Enable/disable auto-refresh |
| "Live" indicator | Header | Green dot when enabled |
| "Last updated" | Header | Time since last fetch |

### Implementation

```typescript
// State
const [autoRefreshEnabled, setAutoRefreshEnabled] = useState(true);
const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

// React Query with conditional refetch
const { data, refetch, dataUpdatedAt } = useQuery({
  queryKey: ['analytics'],
  queryFn: fetchAnalytics,
  refetchInterval: autoRefreshEnabled ? AUTO_REFRESH_INTERVAL : false,
  refetchIntervalInBackground: false,
});

// Update timestamp on data change
useEffect(() => {
  if (dataUpdatedAt) {
    setLastUpdated(new Date(dataUpdatedAt));
  }
}, [dataUpdatedAt]);

// Refresh on visibility change
useEffect(() => {
  const handleVisibilityChange = () => {
    if (document.visibilityState === 'visible' && autoRefreshEnabled) {
      refetch();
    }
  };
  document.addEventListener('visibilitychange', handleVisibilityChange);
  return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
}, [autoRefreshEnabled, refetch]);
```

### Time Formatting

```typescript
function formatTimeAgo(date: Date): string {
  const seconds = Math.floor((new Date().getTime() - date.getTime()) / 1000);
  if (seconds < 60) return 'Just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  return `${hours}h ago`;
}
```

---

## Local Development Setup

### Required Port-Forwards

```bash
# Primary: Traefik for dashboard access
kubectl port-forward -n traefik-local svc/traefik 3000:80 &

# Optional: Notification service for WebSocket
kubectl port-forward -n notification-local svc/notification 8003:8003 &
```

### Testing Notifications

```bash
# 1. Verify notification service is running
kubectl get pods -n notification-local

# 2. Test HTTP endpoint
curl http://127.0.0.1:8003/
# Expected: {"message":"Solidity Security Notification Service",...}

# 3. Test WebSocket (using websocat or similar)
# For pure local dev:
websocat ws://127.0.0.1:8003/ws/
# For server/staging with TLS:
websocat wss://app.0xapogee.com/ws --insecure

# 4. In browser console, check WebSocket connection
# Look for: [WebSocket] Connected to notification service
```

### Environment Configuration

WebSocket URL is configured in `src/utils/env.ts`:

```typescript
export const envConfig = {
  websocket: {
    enabled: import.meta.env.VITE_WS_ENABLED !== 'false',
    // Use wss:// for server/staging/production. ws://localhost acceptable for pure local dev.
    url: import.meta.env.VITE_WS_URL || 'wss://localhost:8003/ws',
  },
};
```

---

## Troubleshooting

### Toasts Not Appearing

1. **Check provider hierarchy:**
   ```tsx
   // App.tsx must have this structure
   <ToastProvider>
     <Router>
       <NotificationHandler />
       <AppContent />
       <ToastContainer />
     </Router>
   </ToastProvider>
   ```

2. **Check browser console for errors**

3. **Verify toast context is accessible:**
   ```typescript
   const toast = useToast();
   toast.success('Test', 'This should appear');
   ```

### WebSocket Not Connecting

1. **Check port-forward:**
   ```bash
   lsof -i :8003 | grep LISTEN
   ```

2. **Check service health:**
   ```bash
   curl http://127.0.0.1:8003/api/v1/health/ready
   ```

3. **Check browser console:**
   - Look for WebSocket connection errors
   - Check for CORS issues

4. **Restart port-forward:**
   ```bash
   pkill -f "port-forward.*8003"
   kubectl port-forward -n notification-local svc/notification 8003:8003 &
   ```

### Duplicate Notifications

1. **Check component mounting:**
   - Ensure `NotificationHandler` is only mounted once
   - Check for `StrictMode` double-mounting in development

2. **Check WebSocket reconnection:**
   - Rapid reconnections can replay events
   - Check `shownNotifications` Set in useNotifications

### Auto-Refresh Not Working

1. **Check toggle state:**
   ```typescript
   console.log('autoRefreshEnabled:', autoRefreshEnabled);
   ```

2. **Check React Query configuration:**
   ```typescript
   console.log('refetchInterval:', autoRefreshEnabled ? AUTO_REFRESH_INTERVAL : false);
   ```

3. **Check visibility state:**
   ```typescript
   console.log('visibilityState:', document.visibilityState);
   ```

---

## Related Documentation

- [Dashboard Development Standards](/Users/pwner/Git/ABS/docs/standards/dashboard-development.md)
- [Port-Forwarding Standards](/Users/pwner/Git/ABS/docs/standards/port-forwarding.md)
- [Quota Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/quota-frontend.md)
- [Project Contracts Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/project-contracts-frontend.md)
- [WebSocket Manager](/Users/pwner/Git/ABS/blocksecops-dashboard/src/lib/websocket/WebSocketManager.ts)

---

## Version History

### v0.19.0 (December 30, 2025)
**Type:** MINOR (Build System)
**Changes:**
- Dashboard now uses production build (`serve -s dist`) instead of dev server
- Supabase credentials passed as Docker build args (not hardcoded)
- Added build arg validation in Dockerfile
- Updated to serve static assets via Nginx/serve
- See [frontend-build-env.md](/docs/standards/frontend-build-env.md) for build workflow

### v0.5.9 (November 29, 2025)
**Type:** MINOR (New Feature)
**Changes:**
- Added ToastContext for global notification state
- Added ToastContainer component with animations
- Added useNotifications hook for WebSocket integration
- Added useNotify hook for manual notifications
- Added NotificationHandler global component
- Added auto-refresh toggle to DashboardAnalytics
- Added "Live" indicator and "Last updated" timestamp
- Added visibility-based data refresh
