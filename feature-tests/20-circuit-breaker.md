# Circuit Breaker (Admin Portal)

**Priority**: P1
**Last Tested**: Not yet tested — scheduled for UI testing phase

## 1. Circuit State Machine

### 1.1 CLOSED State (Normal Operation)
- [ ] Requests pass through normally when circuit is CLOSED
- [ ] Failure count increments on 5xx responses
- [ ] Failure count increments on network errors
- [ ] Failure count increments on timeout errors
- [ ] Failure count resets to 0 on successful response
- [ ] 4xx responses do NOT increment failure count
- [ ] Circuit remains CLOSED below failure threshold

### 1.2 CLOSED → OPEN Transition
- [ ] Circuit opens when failure count reaches threshold (default: 5)
- [ ] Core services threshold is 8
- [ ] ML models threshold is 3
- [ ] Toast warning appears when circuit opens
- [ ] Circuit Breaker Panel card turns red

### 1.3 OPEN State (Blocking)
- [ ] Requests are immediately rejected with CircuitOpenError
- [ ] No HTTP request is sent to backend
- [ ] Error message shows "This service is temporarily unavailable. Please try again shortly."
- [ ] React Query does not retry circuit-open errors
- [ ] React Query serves stale cached data
- [ ] Other service groups remain unaffected

### 1.4 OPEN → HALF_OPEN Transition
- [ ] After recovery timeout elapses, next request triggers transition
- [ ] Default recovery timeout is 30s (+ 0-20% jitter)
- [ ] ML models recovery timeout is 45s (+ 0-20% jitter)
- [ ] Circuit Breaker Panel card turns yellow

### 1.5 HALF_OPEN State (Probing)
- [ ] Up to 3 probe requests are allowed through
- [ ] Probe requests carry valid auth tokens
- [ ] Additional requests beyond 3 are blocked
- [ ] Panel shows probe progress (successes/attempts)

### 1.6 HALF_OPEN → CLOSED Recovery
- [ ] After 3 successful probes, circuit transitions to CLOSED
- [ ] Success toast appears: "[Service] has recovered"
- [ ] Circuit Breaker Panel card turns green
- [ ] Failure count resets to 0
- [ ] Normal operation resumes

### 1.7 HALF_OPEN → OPEN Regression
- [ ] Any failure during HALF_OPEN immediately re-opens circuit
- [ ] Jitter is regenerated on re-open
- [ ] Warning toast appears again
- [ ] Panel card returns to red

## 2. Service Group Isolation

### 2.1 Independent Groups
- [ ] Tripping `intelligence` circuit does not affect `core` requests
- [ ] Tripping `ml` circuit does not affect `purchases` requests
- [ ] Multiple circuits can be open simultaneously
- [ ] Dashboard loads partially when some groups are down

### 2.2 URL Mapping
- [ ] `/admin/users/*` routes map to `core` group
- [ ] `/admin/system/*` routes map to `system` group
- [ ] `/admin/purchases/*` routes map to `purchases` group
- [ ] `/intelligence/*` routes map to `intelligence` group
- [ ] `/ml/*` routes map to `ml` group
- [ ] `/vulnerabilities/*` routes map to `vulnerabilities` group
- [ ] `/admin/support/*` routes map to `support` group
- [ ] `/admin/scan-monitoring/*` routes map to `scanMonitoring` group
- [ ] Unknown paths bypass circuit breaker

## 3. Admin Override

### 3.1 Force Reset
- [ ] Force Reset button appears only on OPEN circuits
- [ ] Clicking Force Reset transitions circuit to CLOSED
- [ ] Failure count resets to 0
- [ ] Panel card immediately turns green
- [ ] Subsequent requests pass through normally

### 3.2 Browser Refresh
- [ ] Refreshing the browser tab resets all circuit states
- [ ] No persistent state across page reloads

## 4. UI Integration

### 4.1 Toast Notifications
- [ ] Warning toast on circuit open (8s duration)
- [ ] Recovery toast on circuit close (5s duration)
- [ ] Toast includes human-readable service group name
- [ ] Duplicate open toasts are suppressed for same group
- [ ] Toasts appear for all service groups

### 4.2 Circuit Breaker Panel (System Page)
- [ ] Panel appears between Overall Health and Core Components sections
- [ ] Panel is hidden when no circuits have been activated
- [ ] Panel shows after navigating to dashboard (which triggers API calls)
- [ ] Summary header shows healthy/total count
- [ ] Cards are color-coded: green (CLOSED), red (OPEN), yellow (HALF_OPEN)
- [ ] Failure count displayed on cards with failures
- [ ] "Last failure: Xs ago" shown for circuits with failures
- [ ] Half-open probe progress shown during recovery

### 4.3 Error Messages
- [ ] CircuitOpenError shows user-friendly message, not technical details
- [ ] No stack traces or internal paths exposed
- [ ] No service group names exposed in error messages to end users

## 5. React Query Integration

### 5.1 Retry Suppression
- [ ] React Query does NOT retry when error is CircuitOpenError
- [ ] React Query DOES retry (once) for normal errors
- [ ] Mutation errors are not retried regardless

### 5.2 Stale Data
- [ ] Dashboard widgets show stale data when their service group is down
- [ ] Last successful data remains visible
- [ ] Stale data indicator is present (if applicable)
- [ ] Background refetch resumes after circuit recovery

## 6. Security (BSO-SEC-RES Compliance)

### 6.1 No Sensitive Data Leakage
- [ ] Circuit breaker snapshots contain no URLs
- [ ] Circuit breaker snapshots contain no tokens or credentials
- [ ] Console has no debug logging of request/response data
- [ ] Error messages are generic, not implementation-specific

### 6.2 Jitter (Thundering Herd Prevention)
- [ ] Recovery timeout includes random 0-20% jitter
- [ ] Jitter is regenerated when circuit re-opens
- [ ] Multiple browser tabs do not synchronize recovery

## Test Notes

| Date | Tester | Scenario | Result | Notes |
| ---- | ------ | -------- | ------ | ----- |
|      |        |          |        |       |
