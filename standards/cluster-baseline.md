# Cluster Baseline — Local Development Environment

**Version:** 1.0.0
**Last Updated:** February 28, 2026
**Status:** Active
**Cluster:** debian-server (single-node kubeadm)

## Overview

This document defines the expected healthy state of the local Kubernetes cluster. Use it as a reference during health audits, after deployments, and when troubleshooting. Any deviation from this baseline should be investigated.

---

## Node

| Property | Expected Value |
|----------|---------------|
| Node name | `debian-server` |
| K8s version | v1.32.x |
| Runtime | Docker 29.x |
| Status | Ready |
| CPU usage | < 30% |
| Memory usage | < 40% |
| Disk usage | < 80% |
| Taints | `node-role.kubernetes.io/control-plane:NoSchedule` (tolerated by all workloads) |

**Check:**
```bash
kubectl get nodes
kubectl top nodes
df -h /
```

---

## Namespaces (24)

### Application Namespaces (9)

| Namespace | Service | Expected Pods |
|-----------|---------|---------------|
| admin-portal-local | Admin Portal | 1 |
| api-service-local | API Service + Celery Worker | 2 |
| contract-parser-local | Contract Parser | 1 |
| dashboard-local | Dashboard | 1 |
| data-service-local | Data Service | 1 |
| intelligence-engine-local | Intelligence Engine | 1 |
| notification-local | Notification | 1 |
| orchestration-local | Orchestration (4 containers) | 1 |
| tool-integration-local | Tool Integration | 2 (HPA min) |

### Infrastructure Namespaces (9)

| Namespace | Service | Expected Pods |
|-----------|---------|---------------|
| cert-manager-local | cert-manager + cainjector + webhook | 3 |
| external-secrets-local | External Secrets + webhook | 2 (cert-controller scaled to 0) |
| harbor-local | Harbor (core, db, jobservice, nginx, portal, redis, registry) | 7 (5 Deployments + 2 StatefulSets) |
| monitoring-local | Prometheus + Prometheus Adapter | 2 (may be scaled to 0) |
| postgresql-local | PostgreSQL + postgres-exporter | 2 (StatefulSet + Deployment) |
| redis-local | Redis + redis-exporter | 2 |
| traefik-local | Traefik Ingress | 1 |
| vault-local | Vault | 1 (StatefulSet) |
| openclaw | OpenClaw Gateway + Ollama | 3 (gateway: 2 replicas, ollama: 1) |

### System Namespaces (6)

| Namespace | Purpose |
|-----------|---------|
| default | Empty (no workloads) |
| kube-system | CoreDNS (2), metrics-server (1) |
| kube-flannel | Flannel CNI (1 DaemonSet) |
| kube-node-lease | Node lease objects |
| kube-public | Public ConfigMaps |
| local-path-storage | Local path provisioner (1) |

**Total expected running pods: ~44-47** (varies with HPA scaling and monitoring state)

**Check:**
```bash
kubectl get pods -A --no-headers | grep -c Running
kubectl get pods -A --field-selector='status.phase!=Running' --no-headers  # Should be empty
```

---

## Deployments

### Application Deployments

| Namespace | Deployment | Replicas | revisionHistoryLimit | HPA |
|-----------|-----------|----------|---------------------|-----|
| admin-portal-local | admin-portal | 1 | 3 | No |
| api-service-local | api-service | 1 | 3 | No |
| api-service-local | celery-worker | 1 | 3 | No |
| contract-parser-local | contract-parser | 1 | 3 | No |
| dashboard-local | dashboard | 1 | 3 | No |
| data-service-local | data-service | 1 | 3 | Yes (min:1, max:3) |
| intelligence-engine-local | intelligence-engine | 1 | 3 | No |
| notification-local | notification | 1 | 3 | No |
| orchestration-local | orchestration | 1 | 3 | No |
| tool-integration-local | tool-integration | 2 | 3 | Yes (min:2, max:10) |

### Infrastructure Deployments

| Namespace | Deployment | Replicas | revisionHistoryLimit |
|-----------|-----------|----------|---------------------|
| cert-manager-local | cert-manager | 1 | 3 |
| cert-manager-local | cert-manager-cainjector | 1 | 3 |
| cert-manager-local | cert-manager-webhook | 1 | 3 |
| external-secrets-local | external-secrets | 1 | N/A (Helm-managed) |
| external-secrets-local | external-secrets-cert-controller | 0 | N/A (Helm-managed) |
| external-secrets-local | external-secrets-webhook | 1 | N/A (Helm-managed) |
| harbor-local | harbor-core | 1 | 3 |
| harbor-local | harbor-jobservice | 1 | 3 |
| harbor-local | harbor-nginx | 1 | 3 |
| harbor-local | harbor-portal | 1 | 3 |
| harbor-local | harbor-registry | 1 | 3 |
| monitoring-local | prometheus | 0-1 | 3 |
| monitoring-local | prometheus-adapter | 0-1 | 3 |
| postgresql-local | postgres-exporter | 1 | 3 |
| redis-local | redis | 1 | 3 |
| redis-local | redis-exporter | 1 | 3 |
| traefik-local | traefik | 1 | 3 |

### System Deployments (not managed by platform)

| Namespace | Deployment | Replicas | revisionHistoryLimit |
|-----------|-----------|----------|---------------------|
| kube-system | coredns | 2 | 10 (K8s default) |
| kube-system | metrics-server | 1 | 10 (K8s default) |
| local-path-storage | local-path-provisioner | 1 | 10 (K8s default) |

**Validation:**
```bash
# Verify all managed deployments have revisionHistoryLimit: 3
kubectl get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.revisionHistoryLimit}{"\n"}{end}' | \
  grep -v "kube-system\|local-path\|external-secrets" | \
  grep -v ": 3$"
# Output should be empty (all managed deployments at 3)
```

---

## StatefulSets

| Namespace | StatefulSet | Replicas | Purpose |
|-----------|-----------|----------|---------|
| harbor-local | harbor-database | 1 | Harbor PostgreSQL |
| harbor-local | harbor-redis | 1 | Harbor Redis |
| postgresql-local | postgresql | 1 | Platform PostgreSQL |
| vault-local | vault | 1 | HashiCorp Vault |

---

## CronJobs

| Namespace | CronJob | Schedule | Expected Duration |
|-----------|---------|----------|-------------------|
| api-service-local | deduplication-maintenance | `0 2 * * 0` (Sun 02:00 UTC) | ~23 minutes |

**Check:**
```bash
kubectl get cronjobs -A
kubectl get jobs -A --sort-by=.status.startTime | tail -5
```

---

## HPAs

| Namespace | HPA | Min | Max | Metrics | Expected Status |
|-----------|-----|-----|-----|---------|-----------------|
| data-service-local | data-service-hpa | 1 | 3 | CPU (75%), Memory (85%), custom (database_connections_active) | ScalingActive on CPU/Memory |
| tool-integration-local | tool-integration-hpa | 2 | 10 | CPU (75%), Memory (85%), custom (tool_execution_queue_length) | ScalingActive on CPU/Memory |
| openclaw | openclaw-gateway | 2 | 5 | CPU (70%) | ScalingActive |

**Note:** Custom metrics (`database_connections_active`, `tool_execution_queue_length`) require Prometheus + prometheus-adapter to be running and services to expose `/metrics` endpoints. These are not yet implemented; HPAs function using CPU/Memory fallback. The same service-level `/metrics` implementation is required for GCP (GKE Metrics Adapter / Cloud Monitoring replaces prometheus-adapter, but the application metrics are the same).

**Check:**
```bash
kubectl get hpa -A
# All HPAs should show "ScalingActive: True" in conditions
```

---

## Certificates

| Namespace | Certificate | Secret | Expected Status |
|-----------|------------|--------|-----------------|
| cert-manager-local | local-ca-certificate | local-ca-secret | True (Ready) |
| cert-manager-local | local-wildcard-certificate | local-wildcard-tls | True (Ready) |
| external-secrets-local | external-secrets-webhook | external-secrets-webhook | True (Ready) |
| harbor-local | harbor-tls | harbor-tls-secret | True (Ready) |
| openclaw | openclaw-certificate | openclaw-tls | True (Ready) |
| postgresql-local | postgresql-certificate | postgresql-tls | True (Ready) |
| redis-local | redis-certificate | redis-tls | True (Ready) |
| traefik-local | app-tls | app-tls-secret | True (Ready) |

**Check:**
```bash
kubectl get certificates -A
# All should show READY: True
```

---

## ExternalSecrets

| Namespace | ExternalSecret | Store | Expected Status |
|-----------|---------------|-------|-----------------|
| api-service-local | api-service-secret | vault-backend | SecretSynced: True |
| data-service-local | data-service-secrets | vault-backend | SecretSynced: True |
| intelligence-engine-local | intelligence-engine-secrets | vault-backend | SecretSynced: True |
| notification-local | notification-secrets | vault-backend | SecretSynced: True |
| orchestration-local | orchestration-secrets | vault-backend | SecretSynced: True |
| postgresql-local | postgresql-secret | vault-backend | SecretSynced: True |
| redis-local | redis-secret | vault-backend | SecretSynced: True |

**Check:**
```bash
kubectl get externalsecrets -A
# All should show STATUS: SecretSynced, READY: True
```

---

## NetworkPolicies

Every application namespace must have:
1. `default-deny-all` — Blocks all traffic by default
2. Service-specific ingress rules
3. Service-specific egress rules (DNS, databases, other services)

**Expected count: 60+** (varies as services are added)

| Namespace | Expected Policies |
|-----------|-------------------|
| api-service-local | default-deny-all + 15 service-specific |
| contract-parser-local | default-deny-all + 4 |
| dashboard-local | default-deny-all + 2 |
| data-service-local | default-deny-all + 5 |
| intelligence-engine-local | default-deny-all + 6 |
| notification-local | default-deny-all + 5 |
| orchestration-local | 1 (combined) |
| tool-integration-local | 1 (combined) |
| openclaw | default-deny-all + 8 |
| postgresql-local | default-deny-all |
| redis-local | default-deny-all |
| vault-local | default-deny-all |

**Note:** Infrastructure namespaces (harbor, traefik, cert-manager, monitoring) do **not** have NetworkPolicies yet. This is tracked as future work.

**Check:**
```bash
kubectl get networkpolicy -A --no-headers | wc -l
# Expected: 60+
```

---

## IngressRoutes (Traefik)

| Namespace | IngressRoute | Host Match | Routes To |
|-----------|-------------|------------|-----------|
| dashboard-local | dashboard-server | `app.0xapogee.local` (excl /api/v1, /ws) | dashboard:3000 |
| api-service-local | api-service-server | `app.0xapogee.local` && `/api/v1` | api-service:8000 |
| notification-local | notification-websocket | `app.0xapogee.local` && `/ws` | notification:8003 |
| admin-portal-local | admin-portal-ingressroute-server | `admin.0xapogee.local` | admin-portal:3000 / api-service:8000 |
| tool-integration-local | tool-integration-server | `app.0xapogee.local` && `/api/v1/tool-integration` | tool-integration:8005 |
| harbor-local | harbor-server | `harbor.blocksecops.local` | harbor:80 |
| traefik-local | app-http-redirect | `app.0xapogee.local` (HTTP) | Redirect to HTTPS |

**Check:**
```bash
kubectl get ingressroute -A
```

---

## Service Versions

See [Docker Image Versioning](./docker-image-versioning.md) for the authoritative version table.

**Quick version check:**
```bash
# Compare running images to expected versions
for ns in api-service-local dashboard-local data-service-local intelligence-engine-local notification-local orchestration-local tool-integration-local contract-parser-local admin-portal-local; do
  svc=$(echo $ns | sed 's/-local$//')
  image=$(kubectl get deployment $svc -n $ns -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  echo "$svc: $image"
done
```

---

## Resource Thresholds

| Metric | Warning | Critical | Check Command |
|--------|---------|----------|---------------|
| Node CPU | > 50% | > 80% | `kubectl top nodes` |
| Node Memory | > 60% | > 85% | `kubectl top nodes` |
| Disk usage | > 75% | > 90% | `df -h /` |
| Stale ReplicaSets (0 replicas) | > 20 | > 40 | `kubectl get rs -A \| awk '$3==0 && $4==0' \| wc -l` |
| Non-running pods | Any | — | `kubectl get pods -A --field-selector='status.phase!=Running'` |
| Failed CronJobs | 2 consecutive | 3 consecutive | `kubectl get jobs -A --sort-by=.status.startTime` |
| Certificate expiry | < 30 days | < 7 days | `kubectl get certificates -A` |
| ExternalSecret sync age | > 5 min | > 15 min | `kubectl get externalsecrets -A` |

---

## Health Check Script

Quick cluster health validation against this baseline:

```bash
#!/bin/bash
# cluster-health-check.sh — Validate cluster against baseline

echo "=== Node ==="
kubectl get nodes -o wide
kubectl top nodes
echo ""

echo "=== Disk ==="
df -h / | awk 'NR==2 {print "Usage: "$5, ($5+0 > 80 ? "⚠ WARNING" : "OK")}'
echo ""

echo "=== Pod Status ==="
total=$(kubectl get pods -A --no-headers | grep -c Running)
echo "Running pods: $total (expected: 44-47)"
non_running=$(kubectl get pods -A --field-selector='status.phase!=Running' --no-headers 2>/dev/null | wc -l)
echo "Non-running pods: $non_running (expected: 0)"
echo ""

echo "=== Stale ReplicaSets ==="
stale=$(kubectl get rs -A --no-headers | awk '$3==0 && $4==0' | wc -l)
echo "Stale ReplicaSets: $stale (warning if > 20)"
echo ""

echo "=== revisionHistoryLimit ==="
bad=$(kubectl get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.revisionHistoryLimit}{"\n"}{end}' | \
  grep -v "kube-system\|local-path\|external-secrets" | grep -v ": 3$" | grep -v ": 2$")
if [ -z "$bad" ]; then
  echo "All managed deployments have revisionHistoryLimit set: OK"
else
  echo "⚠ Deployments missing or wrong revisionHistoryLimit:"
  echo "$bad"
fi
echo ""

echo "=== Certificates ==="
kubectl get certificates -A --no-headers | awk '{print $1"/"$2": "$3}'
echo ""

echo "=== ExternalSecrets ==="
kubectl get externalsecrets -A --no-headers | awk '{print $1"/"$2": "$5" "$6}'
echo ""

echo "=== HPAs ==="
kubectl get hpa -A --no-headers
echo ""

echo "=== Non-Running Pods (detail) ==="
kubectl get pods -A --field-selector='status.phase!=Running' --no-headers 2>/dev/null || echo "None"
```

---

## Baseline Update Process

This document must be updated when:

1. A new service is added to the cluster
2. A service is removed from the cluster
3. Namespace structure changes
4. HPA configuration changes
5. New certificates or ExternalSecrets are added
6. NetworkPolicy coverage changes
7. IngressRoute topology changes
8. Resource thresholds are revised based on operational experience

---

## Known Deviations from Baseline

Track known deviations here until they are resolved:

| Deviation | Since | Reason | Tracked In |
|-----------|-------|--------|------------|
| HPA custom metrics unavailable | Feb 2026 | Services don't expose /metrics endpoints yet | Tracked |
| Infrastructure namespaces lack NetworkPolicies | Since inception | Not yet implemented | CLUSTER-HEALTH-AUDIT-2026-02-22.md |

### Resolved Deviations

| Deviation | Resolved | Resolution |
|-----------|----------|------------|
| Application deployments at revisionHistoryLimit: 2 | Feb 28, 2026 | Re-applied kustomize overlays (now 3) |
| Infrastructure deployments at revisionHistoryLimit: 10 | Feb 28, 2026 | Merged PR #28 + kubectl patch |
| WebSocket IngressRoute wrong port | Feb 28, 2026 | Fixed notification to single-port architecture (PR #44) |
| 48 stale ReplicaSets | Feb 28, 2026 | Deleted + revisionHistoryLimit prevents recurrence |
| 3 Completed harbor pods | Feb 28, 2026 | Deleted + revisionHistoryLimit: 3 on all harbor deployments |
| Stale `notification` IngressRoute conflict | Feb 28, 2026 | Deleted manually-applied IngressRoute from cluster |

---

## Related Documentation

- [Kubernetes Pod Lifecycle Standards](./kubernetes-pod-lifecycle.md)
- [Docker Image Versioning](./docker-image-versioning.md)
- [Smoke Test](./smoke-test.md)
- [Port Forwarding / Service Access](./port-forwarding.md)
- [RCA: Stale Pods & ReplicaSets](../../TaskDocs-BlockSecOps/RCA-2026-02-28-STALE-PODS-REPLICASETS.md)
