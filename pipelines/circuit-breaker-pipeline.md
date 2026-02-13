# Circuit Breaker Pipeline

Frontend circuit breaker implementation for the admin portal (`admin.blocksecops.local`), mirroring the backend `circuit_breaker.py` pattern for resilient API communication.

## Overview

```
Admin Portal (React)
  │
  ├── API Request
  │     │
  │     ▼
  │  [Auth JWT Injection]
  │     │
  │     ▼
  │  [Circuit Breaker Check]  ─── OPEN ───► CircuitOpenError (fast-fail)
  │     │                                        │
  │     │ CLOSED/HALF_OPEN                       ▼
  │     ▼                               React Query cache
  │  [Axios HTTP Request]               serves stale data
  │     │
  │     ▼
  │  [Backend API Service]
  │     │
  │     ▼
  │  [Circuit Breaker Record]
  │     │  Success → recordSuccess()
  │     │  5xx/Network/Timeout → recordFailure()
  │     │  4xx → pass through (client error, not service health)
  │     ▼
  │  [401 Token Refresh]
  │     │
  │     ▼
  │  Response to UI
```

## Service

| Property       | Value                                      |
| -------------- | ------------------------------------------ |
| Portal         | `blocksecops-admin-portal`                 |
| Port           | 5173 (dev), 3001 (preview)                 |
| Technology     | React 18 / TypeScript / Axios / TanStack Query |
| Compliance     | BSO-SEC-RES-001 through BSO-SEC-RES-004    |
| Backend Mirror | `src/infrastructure/resilience/circuit_breaker.py` |

## Trigger

Every HTTP request through the admin portal's `apiClient` axios instance automatically passes through the circuit breaker interceptor chain.

## Pipeline Phases

### Phase 1: URL Resolution

Each request URL is mapped to a **service group** based on path prefix:

| URL Pattern                  | Service Group    |
| ---------------------------- | ---------------- |
| `/admin/users/*`             | `core`           |
| `/admin/organizations/*`     | `core`           |
| `/admin/audit/*`             | `core`           |
| `/admin/emergency/*`         | `core`           |
| `/admin/auth/*`              | `core`           |
| `/admin/system/*`            | `system`         |
| `/admin/purchases/*`         | `purchases`      |
| `/intelligence/*`            | `intelligence`   |
| `/deduplication/*`           | `intelligence`   |
| `/ml/*`                      | `ml`             |
| `/vulnerabilities/*`         | `vulnerabilities` |
| `/admin/support/*`           | `support`        |
| `/admin/scan-monitoring/*`   | `scanMonitoring` |

Requests to unmapped paths bypass the circuit breaker entirely.

### Phase 2: Circuit State Check (Request Interceptor)

```
CLOSED     → Allow request
OPEN       → Check recovery timeout
               ├── Timeout elapsed → Transition to HALF_OPEN, allow request
               └── Timeout not elapsed → Reject with CircuitOpenError
HALF_OPEN  → Check probe count
               ├── Under limit → Allow request (increment counter)
               └── At limit → Reject with CircuitOpenError
```

### Phase 3: Response Recording

| Response Type           | Action              |
| ----------------------- | ------------------- |
| 2xx success             | `recordSuccess()`   |
| 5xx server error        | `recordFailure()`   |
| Network error           | `recordFailure()`   |
| Timeout (ECONNABORTED)  | `recordFailure()`   |
| 4xx client error        | No action           |
| CircuitOpenError        | No action (pass-through) |

### Phase 4: State Transitions

```
CLOSED ──[failures >= threshold]──► OPEN
  ▲                                    │
  │                                    │ [recovery timeout + jitter elapsed]
  │                                    ▼
  └──[successes >= halfOpenMaxCalls]── HALF_OPEN
                                       │
                                       │ [any failure]
                                       ▼
                                      OPEN (jitter regenerated)
```

### Phase 5: Graceful Degradation

When a circuit opens:

1. `CircuitOpenError` is thrown immediately (no network request)
2. React Query retries are suppressed for circuit-open errors
3. React Query serves stale cached data if available
4. Toast notification warns admin which service is degraded
5. `Promise.allSettled` patterns in dashboard continue working — only the affected service group fails

## Configuration

| Service Group    | Failure Threshold | Recovery Timeout | Half-Open Max Calls |
| ---------------- | -----------------:| ----------------:| -------------------:|
| `core`           |                 8 |              30s |                   3 |
| `system`         |                 5 |              30s |                   3 |
| `purchases`      |                 5 |              30s |                   3 |
| `intelligence`   |                 5 |              30s |                   3 |
| `ml`             |                 3 |              45s |                   3 |
| `vulnerabilities`|                 5 |              30s |                   3 |
| `support`        |                 5 |              30s |                   3 |
| `scanMonitoring` |                 5 |              30s |                   3 |

**Jitter (BSO-SEC-RES-004)**: Recovery timeout includes a random 0-20% jitter per circuit instance, regenerated each time the circuit re-opens. This prevents thundering herd when multiple browser tabs recover simultaneously.

## Files

| File                                                | Purpose                              |
| --------------------------------------------------- | ------------------------------------ |
| `src/lib/circuitBreaker.ts`                         | Core engine, state machine, registry |
| `src/lib/api/circuitBreakerInterceptor.ts`          | Axios interceptor integration        |
| `src/hooks/useCircuitBreaker.ts`                    | React hooks for UI subscription      |
| `src/components/common/CircuitBreakerPanel.tsx`     | System page status widget            |
| `src/lib/api/client.ts`                             | Modified: interceptor installation   |
| `src/App.tsx`                                       | Modified: retry logic, toast listener|
| `src/pages/AdminSystem.tsx`                         | Modified: panel placement            |

## Security Compliance

| Requirement      | Implementation                                                          |
| ---------------- | ----------------------------------------------------------------------- |
| BSO-SEC-RES-001  | No sensitive data in circuit state snapshots (no URLs, tokens, headers) |
| BSO-SEC-RES-002  | No console logging of request/response details                          |
| BSO-SEC-RES-003  | Graceful degradation: stale data served, per-group isolation            |
| BSO-SEC-RES-004  | Random 0-20% jitter on recovery timeout, regenerated per re-open        |

## Related Pipelines

- [Scanner Job Execution Pipeline](scanner-job-execution-pipeline.md) — backend scanner orchestration
- [Scan Timeout & Retry Workflow](../workflows/scan-timeout-retry-workflow.md) — backend retry/timeout handling
- [Intelligence Pipeline](intelligence-pipeline.md) — intelligence engine data flow
