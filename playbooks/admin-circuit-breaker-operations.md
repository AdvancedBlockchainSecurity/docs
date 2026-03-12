# Playbook: Admin Circuit Breaker Operations

Version: 1.0
Last Updated: 2026-02-13
Audience: Platform Administrators, Support Engineers

---

## Overview

This playbook covers monitoring, troubleshooting, and manually recovering circuit breakers in the admin portal. Circuit breakers protect the portal from repeatedly calling degraded backend services. When a circuit opens, the portal fast-fails requests and serves cached data instead.

> **Note**: Circuit breakers are client-side (browser). Each admin's browser has its own independent circuit state. Resetting one admin's browser does not affect others.

## Prerequisites

- Platform admin or super admin role
- Access to `admin.0xapogee.com`
- MFA verified

## Quick Reference

| Action                       | Location                                | When to Use                                    |
| ---------------------------- | --------------------------------------- | ---------------------------------------------- |
| View circuit status          | `/system` → Circuit Breakers panel      | Routine monitoring                             |
| Force reset a circuit        | `/system` → Force Reset button          | After confirming backend recovery              |
| Check which service is down  | Toast notification + Circuit panel      | When warning toast appears                     |
| Reset all circuits           | Refresh browser tab                     | Full reset needed                              |

---

## Monitoring Circuit Breaker Status

### Via System Page

1. Navigate to **System** in the admin sidebar
2. Locate the **Circuit Breakers** panel (below Overall Health)
3. Review the grid of service group cards:

| Card Color | State     | Meaning                                    |
| ---------- | --------- | ------------------------------------------ |
| Green      | Healthy   | Normal operation, no failures               |
| Red        | Open      | Service down, requests blocked              |
| Yellow     | Recovering| Probing with limited requests               |

4. Check the summary header for overall health: `(6/8 healthy)`

### Via Toast Notifications

When a circuit opens, a warning toast appears automatically:

> *"Intelligence Engine is experiencing issues. Requests are paused and will retry automatically."*

When a circuit recovers:

> *"Intelligence Engine has recovered and is operating normally."*

---

## Troubleshooting Open Circuits

### Step 1: Identify the Affected Service

1. Check which card is red in the Circuit Breakers panel
2. Map the service group to backend services:

| Service Group    | Backend Services Affected                          |
| ---------------- | -------------------------------------------------- |
| Core Services    | User management, organizations, audit logs, auth   |
| System           | System health, configuration                       |
| Purchases        | Transactions, subscriptions, purchase stats        |
| Intelligence     | Intelligence stats, deduplication, scanner metrics  |
| ML Models        | Model stats, training data, retraining             |
| Vulnerabilities  | Vulnerability data and statistics                  |
| Support          | Support tickets                                    |
| Scan Monitoring  | Stale scans, scan retry/fail operations            |

### Step 2: Verify Backend Health

1. Check the **Service Health** section on the same System page
2. Look for the corresponding backend service status
3. If the backend shows "Healthy" but the circuit is open, the issue may have been transient

### Step 3: Force Reset (If Backend is Healthy)

1. Confirm the backend service has recovered (check Service Health panel or backend logs)
2. Click **Force Reset** on the open circuit card
3. Verify the card turns green
4. Navigate to a page that uses that service group to confirm requests succeed

> **Warning**: Do not force reset if the backend is still unhealthy. The circuit will re-open immediately after the threshold is reached again, and you'll generate unnecessary load on the degraded service.

### Step 4: If Issue Persists

If the circuit keeps re-opening after reset:

1. Check backend pod health:
   ```bash
   kubectl get pods -n blocksecops -l app=blocksecops-api-service
   ```

2. Check backend logs for errors:
   ```bash
   kubectl logs -n blocksecops deployment/blocksecops-api-service --tail=50
   ```

3. Check if the issue is network-related (ingress, DNS):
   ```bash
   kubectl get ingress -n blocksecops
   ```

4. Escalate to the infrastructure team if the issue is at the cluster level

---

## Circuit Breaker Thresholds

Understanding when circuits trip:

| Service Group    | Failures to Trip | Recovery Wait | Why Different?                     |
| ---------------- | ----------------:| -------------:| ---------------------------------- |
| Core Services    |                8 |         30-36s | DB-backed, more tolerant of blips  |
| ML Models        |                3 |         45-54s | External service, fail fast        |
| All Others       |                5 |         30-36s | Default balanced threshold         |

**What counts as a failure:**
- HTTP 500, 502, 503, 504 responses
- Network errors (server unreachable)
- Request timeouts (30s default)

**What does NOT count:**
- HTTP 400, 401, 403, 404, 429 (client errors)
- Successful responses with error data in body

---

## Common Scenarios

### Scenario: Backend Deployment Rolling Update

During a rolling update, some pods may briefly return 502/503:

1. If failures stay under threshold: no circuit trip, transparent to admin
2. If threshold reached: circuit opens, portal shows cached data
3. After deployment completes: circuit auto-recovers after 30-36s
4. No action needed — automatic recovery handles this

### Scenario: Database Connection Pool Exhaustion

Core services may fail with 500 errors:

1. Circuit opens for `core` group (threshold: 8 failures)
2. User management, audit logs, and organization pages show cached data
3. Other service groups (ML, Intelligence) remain unaffected
4. Fix: Scale API pods or investigate connection leak
5. After fix: circuit auto-recovers or force reset

### Scenario: Intelligence Engine OOM Kill

1. Circuit opens for `intelligence` group after 5 failures
2. Dashboard intelligence widgets show stale data
3. Other dashboard sections continue loading fresh data
4. Fix: Restart intelligence engine pod, check memory limits
5. After fix: wait 30-36s for auto-recovery

---

## Related Documentation

- [Circuit Breaker Pipeline](../pipelines/circuit-breaker-pipeline.md)
- [Circuit Breaker Workflow](../workflows/circuit-breaker-workflow.md)
- [Admin Emergency Operations](admin-emergency-operations.md)
- [Admin Portal Deployment](admin-portal-deployment.md)

## Checklist

### Pre-Reset
- [ ] Confirmed backend service is healthy
- [ ] Checked Service Health panel for current status
- [ ] Identified root cause of original failures

### Post-Reset
- [ ] Circuit card turned green
- [ ] Navigated to affected page to verify data loads
- [ ] Monitored for 5 minutes to ensure circuit stays closed
- [ ] Documented incident if it was unexpected
