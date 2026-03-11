# GCP Cluster Smoke Test

**Version:** 1.0.0
**Last Updated:** March 10, 2026
**Status:** Active

## Overview

Infrastructure smoke test for the GCP production cluster. Tests GKE-specific resources: Gateway, NetworkPolicy, External Secrets Operator, TLS certificates, Cloud Armor, node pools, and Workload Identity. Includes cluster audit for resource hygiene and log checks for operational issues.

For platform and service health checks (API endpoints, database, auth, WebSocket), see [Platform Smoke Test](../standards/smoke-test.md).

## Cluster Info

| Setting | Value |
|---------|-------|
| **GCP Project** | `project-8a2657b9-d96c-4c0a-a69` |
| **Cluster** | `apogee-production-gke` |
| **Region** | `us-west1` |
| **Node Subnet** | `10.0.0.0/20` |
| **Pod CIDR** | `10.1.0.0/16` |
| **Service CIDR** | `10.2.0.0/20` |
| **Master CIDR** | `172.16.0.0/28` |
| **Namespace suffix** | `-prod` |

### Production Namespaces

`api-service-prod`, `dashboard-prod`, `admin-portal-prod`, `tool-integration-prod`, `orchestration-prod`, `notification-prod`, `intelligence-engine-prod`, `data-service-prod`, `contract-parser-prod`, `postgresql-prod`, `redis-prod`, `ingress-prod`, `external-secrets-prod`, `cert-manager`

---

## Node & Cluster Health

```bash
# Node status (all should be Ready)
kubectl get nodes

# Node pool sizing
kubectl get nodes -o custom-columns='NAME:.metadata.name,CPU:.status.capacity.cpu,MEM:.status.capacity.memory,ZONE:.metadata.labels.topology\.kubernetes\.io/zone'

# System pod overhead (kube-system, gmp-system)
kubectl get pods -n kube-system --no-headers | wc -l
kubectl get pods -n gmp-system --no-headers | wc -l
```

---

## Networking

### GKE Gateway

```bash
# Gateway programmed
kubectl get gateway -n ingress-prod apogee-gateway
kubectl get gateway -n ingress-prod apogee-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
# Expected: True

# HTTPRoutes attached
kubectl get httproute -n ingress-prod
```

### Cloud Armor WAF

```bash
# GCPBackendPolicy count (one per backend service)
kubectl get gcpbackendpolicy -A --no-headers | wc -l
# Expected: 4

# Verify Cloud Armor policy attached
kubectl get gcpbackendpolicy -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.default.securityPolicy}{"\n"}{end}'
```

### SSL Policy

```bash
# Verify TLS 1.2+ minimum
gcloud compute ssl-policies list --project=project-8a2657b9-d96c-4c0a-a69 --format='table(name,minTlsVersion,profile)'
```

### Cloud NAT

```bash
# NAT router running
gcloud compute routers list --project=project-8a2657b9-d96c-4c0a-a69 --format='table(name,region,network)'

# NAT config
gcloud compute routers nats list --router=apogee-router --region=us-west1 --project=project-8a2657b9-d96c-4c0a-a69
```

### HTTP to HTTPS Redirect

```bash
# Should return 301 redirect to HTTPS
curl -s -o /dev/null -w "%{http_code}" "http://app.0xapogee.com/"
# Expected: 301
```

---

## Secrets & Identity

### ClusterSecretStore

```bash
# ClusterSecretStore valid
kubectl get clustersecretstore gcp-secret-manager -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].status}'
# Expected: Valid: True
```

### ExternalSecrets

```bash
# All ExternalSecrets synced (9 expected)
kubectl get externalsecret -A --no-headers
kubectl get externalsecret -A --no-headers | wc -l
# Expected: 9

# Any unsynced?
kubectl get externalsecret -A --no-headers | grep -v "SecretSynced"
# Expected: empty output

# No orphaned ExternalSecrets in non-existent namespaces
for ns in $(kubectl get externalsecret -A --no-headers | awk '{print $1}' | sort -u); do
  kubectl get namespace "$ns" &>/dev/null || echo "ORPHAN: ExternalSecret in non-existent namespace $ns"
done
```

### Workload Identity

```bash
# ESO service account has Workload Identity annotation
kubectl get sa -n external-secrets-prod external-secrets-sa -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'
# Expected: eso-secrets-accessor@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com

# GCP SA has secretAccessor role
gcloud projects get-iam-policy project-8a2657b9-d96c-4c0a-a69 \
  --flatten="bindings[].members" \
  --filter="bindings.members:eso-secrets-accessor AND bindings.role:roles/secretmanager.secretAccessor" \
  --format='table(bindings.role,bindings.members)'
```

---

## TLS Certificates

```bash
# All certificates Ready
kubectl get certificates -A
# Expected: all Ready=True

# Certificate details (CA, postgresql-tls, redis-tls)
for cert in $(kubectl get certificates -A --no-headers | awk '{print $1"/"$2}'); do
  NS=$(echo "$cert" | cut -d/ -f1)
  NAME=$(echo "$cert" | cut -d/ -f2)
  READY=$(kubectl get certificate -n "$NS" "$NAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  EXPIRY=$(kubectl get certificate -n "$NS" "$NAME" -o jsonpath='{.status.notAfter}')
  echo "$cert: Ready=$READY Expires=$EXPIRY"
done

# Certificate expiry warning (< 30 days)
kubectl get certificates -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.status.notAfter}{"\n"}{end}'
```

---

## NetworkPolicy

### Default-Deny

```bash
# Default-deny exists in all -prod namespaces
for ns in $(kubectl get ns --no-headers | awk '{print $1}' | grep '\-prod$'); do
  DENY=$(kubectl get networkpolicy -n "$ns" default-deny-all --no-headers 2>/dev/null | wc -l)
  if [ "$DENY" -eq 0 ]; then
    echo "MISSING: default-deny-all in $ns"
  else
    echo "OK: default-deny-all in $ns"
  fi
done
```

### ESO Metadata Server Egress

The GKE metadata server (`169.254.169.254:80`) is DNATed internally via iptables before Calico evaluates the packet. The NetworkPolicy uses port-only restriction (no `to:` block) for metadata server access.

```bash
# ESO can reach metadata server (Workload Identity token exchange)
kubectl get networkpolicy -n external-secrets-prod eso-allow-apiserver -o yaml | grep -A5 "port: 80"
# Expected: port-only rule (no ipBlock) for ports 80 and 988

# Verify ESO can authenticate (ClusterSecretStore should be Valid)
kubectl get clustersecretstore gcp-secret-manager -o jsonpath='{.status.conditions[0].status}'
# Expected: True
```

### Webhook Ingress

On private GKE, the API server reaches webhook pods via konnectivity agents running in the pod CIDR (`10.1.0.0/16`), not directly from the master CIDR.

```bash
# ESO webhook ingress includes pod CIDR
kubectl get networkpolicy -n external-secrets-prod eso-webhook-ingress -o jsonpath='{.spec.ingress[0].from[*].ipBlock.cidr}'
# Expected: includes 10.1.0.0/16

# cert-manager webhook ingress includes pod CIDR
kubectl get networkpolicy -n cert-manager cert-manager-webhook-ingress -o jsonpath='{.spec.ingress[0].from[*].ipBlock.cidr}'
# Expected: includes 10.1.0.0/16

# Verify webhooks are reachable (patch should not timeout)
kubectl get externalsecret -A --no-headers | head -1 | awk '{print $1" "$2}' | xargs -I{} sh -c 'NS=$(echo {} | cut -d" " -f1); NAME=$(echo {} | cut -d" " -f2); kubectl get externalsecret -n $NS $NAME -o yaml | kubectl apply -f - 2>&1 | head -1'
# Expected: no webhook timeout error
```

### cert-manager API Server Egress

```bash
# cert-manager can reach API server
kubectl get networkpolicy -n cert-manager cert-manager-allow-apiserver -o yaml | grep -A3 "cidr: 10.2.0.1"
# Expected: API server ClusterIP in egress rules
```

---

## Storage

```bash
# PVCs bound
kubectl get pvc -A --no-headers | grep -E "postgresql|redis"
# Expected: all Bound

# Terraform state bucket accessible
gsutil ls gs://apogee-terraform-state-* 2>/dev/null | head -3
```

---

## Monitoring

```bash
# Alert policies active
gcloud monitoring policies list --project=project-8a2657b9-d96c-4c0a-a69 --format='table(displayName,enabled)' 2>/dev/null
# Expected: 7 policies, all enabled

# GMP collectors running
kubectl get pods -n gmp-system --no-headers
```

---

## Cluster Audit

Audit the cluster for resource hygiene, configuration drift, and unused objects.

### Pod Health Audit

```bash
# Pods not in Running/Completed state (expect empty outside kube-system)
kubectl get pods -A --no-headers | grep -v "Running\|Completed" | grep -v "kube-system"

# Pods with high restart counts (> 5 restarts)
kubectl get pods -A --no-headers -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount' | \
  awk '$3 > 5 {print $0}'

# OOMKilled containers in the last hour
for ns in $(kubectl get ns --no-headers | awk '{print $1}' | grep -E '\-prod$|cert-manager|kube-system'); do
  kubectl get events -n "$ns" --field-selector=reason=OOMKilling --no-headers 2>/dev/null
done

# Pods in CrashLoopBackOff
kubectl get pods -A --no-headers | grep "CrashLoopBackOff"
# Expected: empty output
```

### Resource Audit

```bash
# ResourceQuotas — check usage vs limits
kubectl get resourcequota -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,CPU_USED:.status.used.requests\.cpu,CPU_HARD:.status.hard.requests\.cpu,MEM_USED:.status.used.requests\.memory,MEM_HARD:.status.hard.requests\.memory'

# LimitRanges applied
kubectl get limitrange -A

# PriorityClasses defined
kubectl get priorityclass --no-headers | grep -v "system-"

# Stale ReplicaSets (0 desired, 0 ready)
STALE_RS=$(kubectl get rs -A --no-headers | awk '$3==0 && $4==0' | wc -l)
echo "Stale ReplicaSets: $STALE_RS (warning if > 20)"

# revisionHistoryLimit set on all deployments (should be 3)
kubectl get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.revisionHistoryLimit}{"\n"}{end}' | \
  grep -v "kube-system\|gmp-system\|gke-managed\|external-secrets" | grep -v ": 3$"
# Expected: empty output
```

### Namespace Audit

```bash
# No stale namespaces (e.g. leftover -gcp, -dev, -staging)
kubectl get ns --no-headers | awk '{print $1}' | grep -v -E '^(kube-|gmp-|gke-|default$)' | sort
# Expected: only -prod namespaces, cert-manager, ingress-prod, external-secrets-prod

# No orphaned resources in non-prod namespaces
for ns in $(kubectl get ns --no-headers | awk '{print $1}' | grep -v -E '^(kube-|gmp-|gke-|default$)' | grep -v -E '\-prod$|cert-manager'); do
  COUNT=$(kubectl get all -n "$ns" --no-headers 2>/dev/null | wc -l)
  if [ "$COUNT" -gt 0 ]; then
    echo "UNEXPECTED: $ns has $COUNT resources"
  fi
done
```

### Endpoint & Service Audit

```bash
# Services with no endpoints (misconfigured selectors)
for ns in $(kubectl get ns --no-headers | awk '{print $1}' | grep '\-prod$'); do
  for svc in $(kubectl get svc -n "$ns" --no-headers 2>/dev/null | awk '{print $1}'); do
    EP_COUNT=$(kubectl get endpoints -n "$ns" "$svc" -o jsonpath='{.subsets[*].addresses}' 2>/dev/null | grep -c "ip" || true)
    if [ "$EP_COUNT" -eq 0 ]; then
      echo "NO ENDPOINTS: $ns/$svc"
    fi
  done
done
```

---

## Log Checks

Check component logs for errors, warnings, and operational issues.

### Infrastructure Component Logs

```bash
# ESO controller — secret sync errors
kubectl logs -n external-secrets-prod -l app.kubernetes.io/name=external-secrets --tail=50 2>/dev/null | grep -i "error\|fail" | tail -10

# ESO webhook — admission review failures
kubectl logs -n external-secrets-prod -l app.kubernetes.io/name=external-secrets-webhook --tail=50 2>/dev/null | grep -i "error\|timeout" | tail -10

# cert-manager controller — certificate issuance errors
kubectl logs -n cert-manager -l app.kubernetes.io/component=controller --tail=50 2>/dev/null | grep -i "error\|fail" | tail -10

# cert-manager webhook — admission failures
kubectl logs -n cert-manager -l app.kubernetes.io/component=webhook --tail=50 2>/dev/null | grep -i "error\|timeout" | tail -10
```

### Data Layer Logs

```bash
# PostgreSQL — connection errors, replication issues, OOM
kubectl logs -n postgresql-prod postgresql-0 --tail=100 2>/dev/null | grep -iE "error|fatal|panic|oom|out of memory" | tail -10

# Redis — connection issues, memory warnings
kubectl logs -n redis-prod -l app.kubernetes.io/name=redis --tail=100 2>/dev/null | grep -iE "error|warning|oom" | tail -10
```

### Application Service Logs

```bash
ENV="prod"

# Check each service for errors in recent logs
for ns_label in \
  "api-service-${ENV}|app=api-service" \
  "data-service-${ENV}|app=data-service" \
  "tool-integration-${ENV}|app=tool-integration" \
  "orchestration-${ENV}|app=orchestration" \
  "notification-${ENV}|app=notification" \
  "intelligence-engine-${ENV}|app=intelligence-engine" \
  "contract-parser-${ENV}|app=contract-parser" \
; do
  NS=$(echo "$ns_label" | cut -d'|' -f1)
  LABEL=$(echo "$ns_label" | cut -d'|' -f2)
  SVC=$(echo "$NS" | sed "s/-${ENV}$//")
  ERRORS=$(kubectl logs -n "$NS" -l "$LABEL" --tail=100 2>/dev/null | grep -ciE "error|exception|traceback" || true)
  if [ "$ERRORS" -gt 0 ]; then
    echo "WARNING: $SVC has $ERRORS error lines in recent logs"
    kubectl logs -n "$NS" -l "$LABEL" --tail=100 2>/dev/null | grep -iE "error|exception|traceback" | tail -5
  else
    echo "OK: $SVC — no errors in recent logs"
  fi
  echo ""
done
```

### Celery Worker Logs

```bash
# Worker task failures and connection issues
kubectl logs -n api-service-prod -l app.kubernetes.io/name=celery-worker --tail=100 2>/dev/null | grep -iE "error|exception|traceback|connection refused" | tail -10
```

### Cluster Events

```bash
# Warning events in the last hour (cluster-wide)
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -20

# Specifically check for:
# - FailedScheduling (resource pressure)
# - BackOff (CrashLoopBackOff)
# - Unhealthy (failed probes)
# - FailedMount (volume issues)
# - NetworkNotReady (CNI issues)
for reason in FailedScheduling BackOff Unhealthy FailedMount NetworkNotReady; do
  COUNT=$(kubectl get events -A --field-selector=reason=$reason --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 0 ]; then
    echo "WARNING: $COUNT $reason events"
    kubectl get events -A --field-selector=reason=$reason --no-headers 2>/dev/null | tail -3
  fi
done
```

### GCP Audit Logs

```bash
# Recent cluster admin operations (last 1 hour)
gcloud logging read \
  'resource.type="k8s_cluster" AND protoPayload.methodName=~"(create|delete|patch|update)" AND timestamp>="'"$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)"'"' \
  --project=project-8a2657b9-d96c-4c0a-a69 \
  --limit=20 \
  --format='table(timestamp,protoPayload.methodName,protoPayload.resourceName)' 2>/dev/null

# IAM policy changes (security-critical)
gcloud logging read \
  'protoPayload.methodName="SetIamPolicy" AND timestamp>="'"$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)"'"' \
  --project=project-8a2657b9-d96c-4c0a-a69 \
  --limit=10 \
  --format='table(timestamp,protoPayload.methodName,protoPayload.request.resource)' 2>/dev/null
```

---

## Quick Full Smoke Test Script

```bash
#!/bin/bash
# GCP cluster smoke test — run after infrastructure changes
set -euo pipefail

PASS=0
FAIL=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $name"
    ((PASS++))
  else
    echo "  FAIL: $name (expected=$expected, got=$actual)"
    ((FAIL++))
  fi
}

echo "=== Node Health ==="
NODE_NOT_READY=$(kubectl get nodes --no-headers | grep -v "Ready" | wc -l | tr -d ' ')
check "All nodes Ready" "0" "$NODE_NOT_READY"

echo ""
echo "=== Networking ==="
check "Gateway programmed" "True" "$(kubectl get gateway -n ingress-prod apogee-gateway -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)"

ARMOR_COUNT=$(kubectl get gcpbackendpolicy -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
check "Cloud Armor backends" "4" "$ARMOR_COUNT"

echo ""
echo "=== Secrets & Identity ==="
check "ClusterSecretStore valid" "True" "$(kubectl get clustersecretstore gcp-secret-manager -o jsonpath='{.status.conditions[0].status}' 2>/dev/null)"

UNSYNCED=$(kubectl get externalsecret -A --no-headers 2>/dev/null | grep -v "SecretSynced" | wc -l | tr -d ' ')
check "ExternalSecrets synced" "0" "$UNSYNCED"

ES_COUNT=$(kubectl get externalsecret -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
check "ExternalSecret count" "9" "$ES_COUNT"

WI_SA=$(kubectl get sa -n external-secrets-prod external-secrets-sa -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' 2>/dev/null)
check "Workload Identity annotation" "eso-secrets-accessor@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com" "$WI_SA"

echo ""
echo "=== TLS Certificates ==="
CERT_NOT_READY=$(kubectl get certificates -A --no-headers 2>/dev/null | grep -v "True" | wc -l | tr -d ' ')
check "All certificates Ready" "0" "$CERT_NOT_READY"

echo ""
echo "=== NetworkPolicy ==="
for ns in $(kubectl get ns --no-headers | awk '{print $1}' | grep '\-prod$'); do
  DENY=$(kubectl get networkpolicy -n "$ns" default-deny-all --no-headers 2>/dev/null | wc -l | tr -d ' ')
  check "default-deny-all in $ns" "1" "$DENY"
done

echo ""
echo "=== Storage ==="
PVC_NOT_BOUND=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -E "postgresql|redis" | grep -v "Bound" | wc -l | tr -d ' ')
check "PVCs bound" "0" "$PVC_NOT_BOUND"

echo ""
echo "=== Monitoring ==="
GMP_PODS=$(kubectl get pods -n gmp-system --no-headers --field-selector=status.phase=Running 2>/dev/null | wc -l | tr -d ' ')
if [ "$GMP_PODS" -gt 0 ]; then
  echo "  PASS: GMP collectors running ($GMP_PODS pods)"
  ((PASS++))
else
  echo "  FAIL: GMP collectors not running"
  ((FAIL++))
fi

echo ""
echo "=== Cluster Audit ==="
BAD_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -v "Running\|Completed" | grep -v "kube-system" | wc -l | tr -d ' ')
check "No unhealthy pods" "0" "$BAD_PODS"

CRASHLOOP=$(kubectl get pods -A --no-headers 2>/dev/null | grep "CrashLoopBackOff" | wc -l | tr -d ' ')
check "No CrashLoopBackOff" "0" "$CRASHLOOP"

NO_EP=0
for ns in $(kubectl get ns --no-headers 2>/dev/null | awk '{print $1}' | grep '\-prod$'); do
  for svc in $(kubectl get svc -n "$ns" --no-headers 2>/dev/null | awk '{print $1}'); do
    EP_COUNT=$(kubectl get endpoints -n "$ns" "$svc" -o jsonpath='{.subsets[*].addresses}' 2>/dev/null | grep -c "ip" || true)
    if [ "$EP_COUNT" -eq 0 ]; then
      echo "    NO ENDPOINTS: $ns/$svc"
      ((NO_EP++))
    fi
  done
done
check "All services have endpoints" "0" "$NO_EP"

echo ""
echo "=== Log Health ==="
WARN_EVENTS=$(kubectl get events -A --field-selector=type=Warning --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$WARN_EVENTS" -gt 20 ]; then
  echo "  WARN: $WARN_EVENTS warning events (review with: kubectl get events -A --field-selector=type=Warning)"
  ((FAIL++))
else
  echo "  PASS: $WARN_EVENTS warning events (threshold: 20)"
  ((PASS++))
fi

SVC_ERRORS=0
for ns in api-service-prod data-service-prod tool-integration-prod orchestration-prod notification-prod intelligence-engine-prod contract-parser-prod; do
  ERRORS=$(kubectl logs -n "$ns" --all-containers --tail=100 2>/dev/null | grep -ciE "error|exception|traceback" || true)
  if [ "$ERRORS" -gt 10 ]; then
    SVC=$(echo "$ns" | sed 's/-prod$//')
    echo "    WARNING: $SVC has $ERRORS error lines in recent logs"
    ((SVC_ERRORS++))
  fi
done
if [ "$SVC_ERRORS" -gt 0 ]; then
  echo "  WARN: $SVC_ERRORS services with elevated error rates"
  ((FAIL++))
else
  echo "  PASS: No services with elevated error rates"
  ((PASS++))
fi

PG_ERRORS=$(kubectl logs -n postgresql-prod postgresql-0 --tail=100 2>/dev/null | grep -ciE "error|fatal|panic" || true)
if [ "$PG_ERRORS" -gt 0 ]; then
  echo "  WARN: PostgreSQL has $PG_ERRORS error lines in recent logs"
  ((FAIL++))
else
  echo "  PASS: PostgreSQL — no errors in recent logs"
  ((PASS++))
fi

echo ""
echo "=== Summary ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
[ "$FAIL" -eq 0 ] && echo "  Result: ALL CHECKS PASSED" || echo "  Result: $FAIL CHECKS FAILED"
```

---

**See Also:**
- [Platform Smoke Test](../standards/smoke-test.md) — Service and application health checks
- [GCP Infrastructure](./infrastructure.md) — Cluster architecture
- [GCP Security](./security.md) — Security configuration
- [GCP Networking](./networking.md) — Network architecture and CIDRs
