# RCA: Redis-0 and Orchestration Pods Pending

**Date:** 2026-03-10
**Severity:** Critical (Findings #3, #4)
**Status:** Resolved

## Symptoms

- `redis-0` (redis-prod) — Pending, cannot schedule
- `orchestration` (orchestration-prod) — Pending, cannot schedule
- Scheduler error: `0/2 nodes are available: 2 Insufficient cpu`
- Autoscaler: `max node group size reached, node(s) had untolerated taint {scanner: true}`
- Actual node CPU usage: 16% and 25% — cluster is NOT actually exhausted

## Root Cause

**Oversized CPU requests combined with a fixed node pool size.**

The Kubernetes scheduler allocates based on **resource requests**, not actual usage. Platform services were requesting far more CPU than they used, leaving no schedulable capacity despite 79% of actual CPU being idle.

### The Numbers

| Metric | Before Fix | After Fix |
|--------|-----------|-----------|
| Total CPU requests (platform services) | ~1900m | ~775m |
| Total CPU actual usage | ~180m | ~180m |
| Overcommit ratio | 10.5x | 4.3x |
| Free schedulable CPU (2 nodes) | 65m | ~1190m |

### CPU Requests vs Actual Usage (Before Fix)

| Service | CPU Request | Actual Usage | Over-provisioned |
|---------|-----------|-------------|-----------------|
| celery-worker | 250m | 132m | 1.9x |
| tool-integration (x2) | 200m each | 5-6m each | 33x |
| intelligence-engine | 200m | 3m | 67x |
| data-service | 200m | <2m | 100x |
| api-service | 200m | 2m | 100x |
| postgresql | 200m | 22m | 9x |
| contract-parser | 100m | <2m | 50x |
| orchestration (4 containers) | 650m | N/A (Pending) | N/A |
| dashboard (x2) | 50m each | 2m each | 25x |
| admin-portal | 50m | 2m | 25x |
| notification | 50m | <2m | 25x |

### Contributing Factors

1. **Default node pool `max_count = 2`** — same as `min_count`, autoscaling disabled
2. **GKE system pods reserve ~1900m** — nearly an entire e2-standard-2 node (kube-dns 540m, calico-typha 400m, calico-node 200m, kube-proxy 200m, fluentbit 210m, etc.)
3. **Scanner pool taint** — `scanner=true:NoSchedule` prevents non-scanner workloads from using those nodes

## Resolution

### 1. Right-sized CPU Requests

Updated GCP overlay patches across all service repos:

| Service | Old Request | New Request | File |
|---------|------------|-------------|------|
| api-service | 200m | 75m | `blocksecops-api-service/k8s/overlays/gcp/deployment-patch.yaml` |
| celery-worker | 250m | 150m | `blocksecops-api-service/k8s/overlays/gcp/deployment-celery-worker-patch.yaml` |
| tool-integration (x2) | 200m | 50m | `blocksecops-tool-integration/k8s/overlays/gcp/deployment-patch.yaml` |
| intelligence-engine | 200m | 50m | `blocksecops-intelligence-engine/k8s/overlays/gcp/deployment-patch.yaml` |
| data-service | 200m | 50m | `blocksecops-data-service/k8s/overlays/gcp/deployment-patch.yaml` |
| contract-parser | 100m | 25m | `blocksecops-contract-parser/k8s/overlays/gcp/deployment-patch.yaml` |
| dashboard (x2) | 50m | 25m | `blocksecops-dashboard/k8s/overlays/gcp/deployment-patch.yaml` |
| admin-portal | 50m | 25m | `blocksecops-admin-portal/k8s/overlays/gcp/deployment-patch.yaml` |
| notification | 50m | 25m | `blocksecops-notification/k8s/overlays/gcp/deployment-patch.yaml` |
| postgresql | 200m | 75m | `blocksecops-gcp-infrastructure/k8s/overlays/gcp/infrastructure/postgresql/statefulset-patch.yaml` |
| orchestration-worker | 250m | 100m | `blocksecops-orchestration/k8s/overlays/gcp/deployment-patch.yaml` |
| orchestration-beat | 100m | 50m | same |
| orchestration-monitor | 50m | 25m | same |
| orchestration-api | 250m | 100m | same |

**CPU limits were NOT changed** — only requests (reservations). Services can still burst to their limits when needed.

### 2. Enabled Autoscaling

Updated `terraform/environments/gcp/main.tf`:
- Default pool `max_count`: 2 → 4
- Autoscaler can now add nodes when real load increases

### 3. Added Monitoring Alerts

Two new alerts in Terraform to monitor for future right-sizing needs:

| Alert | Condition | Purpose |
|-------|-----------|---------|
| Container CPU > 80% of Request | `cpu/request_utilization > 0.8` for 5 min | Signals a request needs increasing |
| Node CPU Allocatable > 85% | `cpu/allocatable_utilization > 0.85` for 5 min | Safety net if autoscaler is slow |

## Verification

After applying changes:
- All pods Running (including previously Pending redis-0 and orchestration)
- Autoscaler temporarily scaled to 4 nodes during rollout; will scale back as old pods terminate
- No service disruption during rollout

## Findings Addressed

- Finding #3: Redis-0 Pending — **Resolved**
- Finding #4: Orchestration Pending — **Resolved**

## Lessons Learned

1. **Right-size requests based on observed usage**, not theoretical maximums — especially during initial deployment with zero load
2. **Never set `min_count = max_count`** unless you intentionally want to disable autoscaling
3. **GKE system pods on e2-standard-2** consume ~1900m in requests — nearly an entire node. Factor this into capacity planning.
4. **Monitor request utilization, not just actual utilization** — the scheduler only cares about requests
