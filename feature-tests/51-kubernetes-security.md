# Feature Test: Kubernetes Security Configuration

**Feature ID**: 51
**Version**: 1.0.0
**Added**: v0.13.4 (API)
**Last Updated**: 2026-02-01

---

## Overview

Verification tests for Kubernetes security configuration including pod security contexts, NetworkPolicies, and revision history limits. These tests ensure all services meet the GCP launch security gate requirements.

---

## Prerequisites

- [ ] kubectl configured for target cluster
- [ ] Access to all service namespaces
- [ ] jq installed for JSON parsing

---

## Test 1: Revision History Limits

### 1.1 Verify All Deployments Have revisionHistoryLimit

| Service | Namespace | Expected | Status |
|---------|-----------|----------|--------|
| api-service | api-service-local | 3 | [ ] |
| orchestration | orchestration-local | 3 | [ ] |
| tool-integration | tool-integration-local | 3 | [ ] |
| dashboard | dashboard-local | 3 | [ ] |
| data-service | data-service-local | 3 | [ ] |
| intelligence-engine | intelligence-engine-local | 3 | [ ] |
| notification | notification-local | 3 | [ ] |
| contract-parser | contract-parser-local | 3 | [ ] |

```bash
# Check all deployments
for ns in api-service-local orchestration-local tool-integration-local dashboard-local data-service-local intelligence-engine-local notification-local contract-parser-local; do
  LIMIT=$(kubectl get deployment -n $ns -o jsonpath='{.items[0].spec.revisionHistoryLimit}' 2>/dev/null)
  DEPLOY=$(kubectl get deployment -n $ns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [ "$LIMIT" == "3" ]; then
    echo "✅ $ns/$DEPLOY: revisionHistoryLimit=$LIMIT"
  else
    echo "❌ $ns/$DEPLOY: revisionHistoryLimit=$LIMIT (expected 3)"
  fi
done
```

### 1.2 Verify No Stale ReplicaSets

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | List ReplicaSets with 0 replicas | Should be minimal | [ ] |
| 2 | Count per namespace | ≤3 per deployment | [ ] |

```bash
# List ReplicaSets with 0 desired replicas
kubectl get rs -A -o wide | awk 'NR==1 || $3 == 0'

# Count stale ReplicaSets (0 desired, 0 ready)
STALE_COUNT=$(kubectl get rs -A -o wide | awk '$3 == 0 && $4 == 0' | wc -l)
echo "Stale ReplicaSets: $STALE_COUNT"
```

---

## Test 2: Pod Security Contexts

### 2.1 Pod-Level Security Context

| Service | runAsNonRoot | runAsUser | fsGroup | seccompProfile | Status |
|---------|--------------|-----------|---------|----------------|--------|
| api-service | true | 1000 | 1000 | RuntimeDefault | [ ] |
| orchestration | true | 1000 | 1000 | RuntimeDefault | [ ] |
| tool-integration | true | 1000 | 1000 | RuntimeDefault | [ ] |
| dashboard | true | 1000 | 1000 | RuntimeDefault | [ ] |
| data-service | true | 1000 | 1000 | RuntimeDefault | [ ] |
| intelligence-engine | true | 1000 | 1000 | RuntimeDefault | [ ] |
| notification | true | 1000 | 1000 | RuntimeDefault | [ ] |
| contract-parser | true | 1000 | 1000 | RuntimeDefault | [ ] |

```bash
# Check pod security context for each service
for ns in api-service-local orchestration-local tool-integration-local dashboard-local data-service-local intelligence-engine-local notification-local contract-parser-local; do
  echo "=== $ns ==="
  kubectl get pod -n $ns -o jsonpath='{.items[0].spec.securityContext}' 2>/dev/null | jq .
  echo ""
done
```

### 2.2 Container-Level Security Context

| Service | allowPrivilegeEscalation | readOnlyRootFilesystem | capabilities.drop | Status |
|---------|--------------------------|------------------------|-------------------|--------|
| api-service | false | true | ALL | [ ] |
| orchestration | false | true | ALL | [ ] |
| tool-integration | false | true | ALL | [ ] |
| dashboard | false | true | ALL | [ ] |
| data-service | false | true | ALL | [ ] |
| intelligence-engine | false | true | ALL | [ ] |
| notification | false | true | ALL | [ ] |
| contract-parser | false | true | ALL | [ ] |

```bash
# Check container security context
for ns in api-service-local orchestration-local tool-integration-local dashboard-local data-service-local intelligence-engine-local notification-local contract-parser-local; do
  echo "=== $ns ==="
  kubectl get pod -n $ns -o jsonpath='{.items[0].spec.containers[0].securityContext}' 2>/dev/null | jq .
  echo ""
done
```

### 2.3 Verify Pods Running as Non-Root

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Check running user ID | 1000 (not 0) | [ ] |
| 2 | Verify no root processes | None | [ ] |

```bash
# Check running user inside pod (for dashboard as example)
kubectl exec -n dashboard-local deployment/dashboard -- id

# Verify no root processes
kubectl exec -n dashboard-local deployment/dashboard -- ps aux | head -5
```

---

## Test 3: NetworkPolicies

### 3.1 Verify NetworkPolicies Exist

| Service | Namespace | Policies Expected | Status |
|---------|-----------|-------------------|--------|
| api-service | api-service-local | ≥4 | [ ] |
| orchestration | orchestration-local | ≥3 | [ ] |
| tool-integration | tool-integration-local | ≥3 | [ ] |
| dashboard | dashboard-local | ≥3 | [ ] |
| data-service | data-service-local | ≥4 | [ ] |
| intelligence-engine | intelligence-engine-local | ≥5 | [ ] |
| notification | notification-local | ≥4 | [ ] |
| contract-parser | contract-parser-local | ≥3 | [ ] |

```bash
# Count NetworkPolicies per namespace
for ns in api-service-local orchestration-local tool-integration-local dashboard-local data-service-local intelligence-engine-local notification-local contract-parser-local; do
  COUNT=$(kubectl get networkpolicy -n $ns --no-headers 2>/dev/null | wc -l)
  echo "$ns: $COUNT NetworkPolicies"
done
```

### 3.2 Verify Default Deny Policy

| Namespace | Has default-deny-all | Status |
|-----------|----------------------|--------|
| api-service-local | Yes | [ ] |
| dashboard-local | Yes | [ ] |
| data-service-local | Yes | [ ] |
| intelligence-engine-local | Yes | [ ] |
| notification-local | Yes | [ ] |
| contract-parser-local | Yes | [ ] |

```bash
# Check for default-deny-all policy
for ns in api-service-local dashboard-local data-service-local intelligence-engine-local notification-local contract-parser-local; do
  if kubectl get networkpolicy default-deny-all -n $ns &>/dev/null; then
    echo "✅ $ns: default-deny-all exists"
  else
    echo "❌ $ns: default-deny-all MISSING"
  fi
done
```

### 3.3 Verify Service Connectivity

| Source | Destination | Port | Expected | Status |
|--------|-------------|------|----------|--------|
| dashboard | api-service | 8000 | Allowed | [ ] |
| api-service | data-service | 8000 | Allowed | [ ] |
| api-service | postgresql | 5432 | Allowed | [ ] |
| api-service | redis | 6379 | Allowed | [ ] |
| All pods | DNS (kube-dns) | 53 | Allowed | [ ] |

```bash
# Test DNS resolution (should work from all pods)
kubectl exec -n dashboard-local deployment/dashboard -- nslookup api-service.api-service-local.svc.cluster.local

# Test connectivity to API service
kubectl exec -n dashboard-local deployment/dashboard -- curl -s --connect-timeout 5 http://api-service.api-service-local.svc.cluster.local:8000/api/v1/health/live

# Test denied connectivity (example: dashboard should NOT reach postgresql directly)
kubectl exec -n dashboard-local deployment/dashboard -- timeout 2 curl -s http://postgresql.postgresql-local.svc.cluster.local:5432 || echo "Connection blocked (expected)"
```

### 3.4 List All NetworkPolicies

```bash
# Full NetworkPolicy listing
kubectl get networkpolicy -A

# Detailed view for specific namespace
kubectl describe networkpolicy -n dashboard-local
```

---

## Test 4: Volume Mounts (Read-Only Root)

### 4.1 Verify EmptyDir Volumes

| Service | /tmp | /app/.cache | /app/logs | Status |
|---------|------|-------------|-----------|--------|
| api-service | ✓ | ✓ | - | [ ] |
| dashboard | ✓ | ✓ | - | [ ] |
| data-service | ✓ | ✓ | ✓ | [ ] |
| notification | ✓ | - | ✓ | [ ] |

```bash
# Check volume mounts for dashboard
kubectl get pod -n dashboard-local -o jsonpath='{.items[0].spec.containers[0].volumeMounts}' | jq .

# Check volumes defined
kubectl get pod -n dashboard-local -o jsonpath='{.items[0].spec.volumes}' | jq .
```

### 4.2 Verify Read-Only Root Filesystem

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Try to write to / | Permission denied | [ ] |
| 2 | Try to write to /tmp | Succeeds | [ ] |
| 3 | Try to write to /app | Permission denied | [ ] |

```bash
# Test read-only root (should fail)
kubectl exec -n dashboard-local deployment/dashboard -- touch /test 2>&1 || echo "Read-only root (expected)"

# Test writable /tmp (should succeed)
kubectl exec -n dashboard-local deployment/dashboard -- touch /tmp/test && echo "✅ /tmp is writable"

# Test writable /app/.cache (should succeed)
kubectl exec -n dashboard-local deployment/dashboard -- touch /app/.cache/test 2>&1 && echo "✅ /app/.cache is writable"
```

---

## Test 5: Service Account Configuration

### 5.1 Verify ServiceAccounts Exist

| Service | ServiceAccount | automountServiceAccountToken | Status |
|---------|----------------|------------------------------|--------|
| api-service | api-service | false | [ ] |
| orchestration | orchestration | false | [ ] |
| data-service | data-service | false | [ ] |

```bash
# Check ServiceAccount configuration
for ns in api-service-local orchestration-local data-service-local; do
  SA=$(kubectl get deployment -n $ns -o jsonpath='{.items[0].spec.template.spec.serviceAccountName}')
  AUTOMOUNT=$(kubectl get deployment -n $ns -o jsonpath='{.items[0].spec.template.spec.automountServiceAccountToken}')
  echo "$ns: serviceAccount=$SA, automountToken=${AUTOMOUNT:-true}"
done
```

---

## Quick Verification Script

```bash
#!/bin/bash
# Kubernetes Security Verification Script
# Usage: ./verify-k8s-security.sh

echo "=== Kubernetes Security Verification ==="
echo ""

# Define namespaces
NAMESPACES="api-service-local orchestration-local tool-integration-local dashboard-local data-service-local intelligence-engine-local notification-local contract-parser-local"

# 1. Check revisionHistoryLimit
echo "1. Revision History Limits"
for ns in $NAMESPACES; do
  LIMIT=$(kubectl get deployment -n $ns -o jsonpath='{.items[0].spec.revisionHistoryLimit}' 2>/dev/null)
  if [ "$LIMIT" == "3" ]; then
    echo "   ✅ $ns: $LIMIT"
  else
    echo "   ❌ $ns: $LIMIT (expected 3)"
  fi
done
echo ""

# 2. Check security contexts
echo "2. Security Contexts"
for ns in $NAMESPACES; do
  RAN=$(kubectl get pod -n $ns -o jsonpath='{.items[0].spec.securityContext.runAsNonRoot}' 2>/dev/null)
  APE=$(kubectl get pod -n $ns -o jsonpath='{.items[0].spec.containers[0].securityContext.allowPrivilegeEscalation}' 2>/dev/null)
  RO=$(kubectl get pod -n $ns -o jsonpath='{.items[0].spec.containers[0].securityContext.readOnlyRootFilesystem}' 2>/dev/null)
  if [ "$RAN" == "true" ] && [ "$APE" == "false" ] && [ "$RO" == "true" ]; then
    echo "   ✅ $ns: runAsNonRoot=$RAN, allowPrivilegeEscalation=$APE, readOnlyRootFilesystem=$RO"
  else
    echo "   ❌ $ns: runAsNonRoot=$RAN, allowPrivilegeEscalation=$APE, readOnlyRootFilesystem=$RO"
  fi
done
echo ""

# 3. Check NetworkPolicies
echo "3. NetworkPolicies"
for ns in $NAMESPACES; do
  COUNT=$(kubectl get networkpolicy -n $ns --no-headers 2>/dev/null | wc -l)
  if [ "$COUNT" -ge 2 ]; then
    echo "   ✅ $ns: $COUNT policies"
  else
    echo "   ❌ $ns: $COUNT policies (expected ≥2)"
  fi
done
echo ""

# 4. Check stale ReplicaSets
echo "4. Stale ReplicaSets"
STALE=$(kubectl get rs -A -o wide 2>/dev/null | awk '$3 == 0 && $4 == 0' | wc -l)
if [ "$STALE" -eq 0 ]; then
  echo "   ✅ No stale ReplicaSets"
else
  echo "   ⚠️  $STALE stale ReplicaSets found"
fi
echo ""

echo "=== Verification Complete ==="
```

---

## Sign-Off

| Tester | Date | Environment | Result |
|--------|------|-------------|--------|
| | | local | |
| | | GCP staging | |
| | | GCP production | |

---

## Related Documentation

- [Kubernetes Pod Lifecycle Standards](../standards/kubernetes-pod-lifecycle.md)
- [GCP Launch Phase 2](../../TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-02-01-GCP-LAUNCH-PHASE-2.md)
- [Application Security Testing](./29-application-security.md)
