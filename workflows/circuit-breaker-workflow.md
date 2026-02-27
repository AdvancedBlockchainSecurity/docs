# Circuit Breaker Workflow

Last Updated: 2026-02-13
Status: Active
Portal Version: 0.4.0

## Overview

The admin portal circuit breaker provides per-service-group failure isolation for API calls from `admin.0xapogee.local`. When a backend service experiences sustained failures, the circuit breaker stops sending requests to that service, allowing it to recover while the portal continues operating with stale cached data.

```
                    ┌──────────────────────────────┐
                    │                              │
         success    │         CLOSED               │
       ┌───────────►│  (normal operation)          │
       │            │  failures reset on success   │
       │            │                              │
       │            └──────────┬───────────────────┘
       │                       │ failures >= threshold
       │                       ▼
       │            ┌──────────────────────────────┐
       │            │                              │
       │            │          OPEN                │
       │            │  (requests fast-fail)         │
       │            │  recovery timer running       │
       │            │  jitter: 0-20%               │
       │            │                              │
       │            └──────────┬───────────────────┘
       │                       │ recovery timeout elapsed
       │                       ▼
       │            ┌──────────────────────────────┐
       │            │                              │
       │            │       HALF_OPEN              │
       └────────────│  (limited probe requests)    │
                    │  max 3 concurrent probes     │
                    │                              │
                    └──────────┬───────────────────┘
                               │ any failure
                               ▼
                    ┌──────────────────────────────┐
                    │          OPEN                │
                    │  (jitter regenerated)         │
                    └──────────────────────────────┘
```

## Services Involved

| Service              | Role                                     | Port  |
| -------------------- | ---------------------------------------- | ----- |
| Admin Portal         | Circuit breaker host (client-side)       | 5173  |
| API Service          | Backend gateway routed through CB        | 8000  |
| Intelligence Engine  | ML/AI API (separate service group)       | 8002  |
| Tool Integration     | Scanner orchestration                    | 8005  |

## Automatic Recovery Flow

### Phase 1: Failure Detection

When the axios response interceptor receives a 5xx, network error, or timeout, it calls `recordFailure()` on the circuit breaker for that service group. The failure counter increments.

4xx responses (400, 401, 403, 404, 429) are **not** counted as service failures — they represent client errors, not backend health issues.

### Phase 2: Circuit Opens

When the failure count reaches the threshold (default 5, varies by group), the circuit transitions to OPEN:

1. All subsequent requests to that service group are immediately rejected with `CircuitOpenError`
2. No HTTP request is sent over the network
3. React Query suppresses retries for circuit-open errors
4. React Query serves stale cached data from the last successful response
5. A warning toast appears: *"[Service Name] is experiencing issues. Requests are paused and will retry automatically."*

### Phase 3: Recovery Timeout

The circuit remains OPEN for `recoveryTimeout * (1 + jitter)` milliseconds:

| Group            | Base Timeout | Jitter Range | Effective Range |
| ---------------- | -----------: | -----------: | --------------: |
| Default          |          30s |       0-20%  |        30-36s   |
| `ml`             |          45s |       0-20%  |        45-54s   |

Jitter is regenerated each time the circuit re-opens (BSO-SEC-RES-004) to prevent thundering herd across browser tabs.

### Phase 4: Half-Open Probing

After the timeout elapses, the next `shouldAllowRequest()` call transitions to HALF_OPEN. Up to 3 probe requests are allowed through:

- If all 3 succeed → circuit transitions to CLOSED, failure count resets
- If any probe fails → circuit immediately re-opens with new jitter

### Phase 5: Recovery

On successful recovery:

1. Circuit transitions to CLOSED
2. Success toast: *"[Service Name] has recovered and is operating normally."*
3. React Query background refetches resume normally
4. Circuit Breaker Panel on `/system` page updates to green

## Manual Admin Recovery

### Via System Page

1. Navigate to `/system` in the admin portal
2. Locate the **Circuit Breakers** panel (between Overall Health and Core Components)
3. Find the service group showing **Open** (red card)
4. Click **Force Reset** to immediately close the circuit
5. Verify the card turns green (**Healthy**)

### Via Browser Console (Emergency)

```javascript
// Access the circuit breaker registry
import { getCircuitBreaker } from './src/lib/circuitBreaker';
const cb = getCircuitBreaker('intelligence');
cb.reset();
```

> **Note**: Force reset bypasses the recovery flow. Only use when you've confirmed the backend service has recovered.

## Monitoring

The Circuit Breaker Panel on the `/system` page shows:

- Per-group card with color-coded state (green/red/yellow)
- Failure count for each group
- Time since last failure
- Half-open probe progress (successes/attempts)
- Summary header: "(N/M healthy)"

## Race Condition Safety

| Scenario                          | Protection                                          |
| --------------------------------- | --------------------------------------------------- |
| Multiple tabs opening same circuit | Jitter prevents synchronized recovery probes        |
| Rapid failures during HALF_OPEN   | First failure immediately re-opens circuit          |
| Success during failure burst       | Success resets failure count in CLOSED state         |
| State change during render         | React hooks subscribe via listener + 5s polling     |

## Related Documentation

- [Circuit Breaker Pipeline](../pipelines/circuit-breaker-pipeline.md) — technical pipeline details
- [Scan Timeout & Retry Workflow](scan-timeout-retry-workflow.md) — backend retry handling
- [Admin Emergency Operations](../playbooks/admin-emergency-operations.md) — emergency playbook
