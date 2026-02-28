# Kubernetes Service Endpoint Troubleshooting Guide

**Document Type:** Troubleshooting Guide
**Last Updated:** November 25, 2025
**Status:** Active

---

## Overview

This guide helps diagnose and resolve Kubernetes service endpoint issues, particularly when services cannot find their pods due to label mismatches or selector problems.

---

## Common Issue: Service Has No Endpoints

### Symptoms

- "Connection refused" errors even though pod is running and healthy
- Service exists but has no endpoints
- Port-forward fails with connection errors
- Other services cannot connect to the service

### Common Causes

1. **Label Mismatch**: Service selector doesn't match pod labels
2. **Pod Not Running**: Pods are in CrashLoopBackOff or Pending state
3. **Wrong Namespace**: Service and pods in different namespaces
4. **Port Mismatch**: Service targetPort doesn't match container port

---

## Diagnostic Procedure

### Step 1: Check Service Endpoints

```bash
kubectl get endpoints <service-name> -n <namespace>
```

**Expected Output:**
```
NAME      ENDPOINTS           AGE
redis     10.244.8.102:6379   5m
```

**Problem Indicator:** If `ENDPOINTS` column is empty, service can't find pods

---

### Step 2: Compare Service Selector with Pod Labels

```bash
# Get service selector
kubectl get service <service-name> -n <namespace> -o jsonpath='{.spec.selector}' | jq .

# Get pod labels
kubectl get pod -n <namespace> -o jsonpath='{.items[0].metadata.labels}' | jq .
```

**What to Look For:**
- All keys in service selector must exist in pod labels
- Values must match exactly
- Common mismatches:
  - `app.kubernetes.io/part-of`
  - `app.kubernetes.io/name`
  - `app.kubernetes.io/instance`

**Example of Mismatch:**
```json
// Service Selector
{
  "app.kubernetes.io/name": "redis",
  "app.kubernetes.io/part-of": "blocksecops-platform"
}

// Pod Labels
{
  "app.kubernetes.io/name": "redis",
  "app.kubernetes.io/part-of": "solidity-security-platform"  // ← MISMATCH
}
```

---

### Step 3: Check if Service Selector Matches Any Pods

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<service-name>
```

**Expected Output:** Should return the pods

**Problem Indicator:** If no pods returned, label mismatch confirmed

---

### Step 4: Verify Pod Status

```bash
kubectl get pods -n <namespace>
```

**Check:**
- Pod is in `Running` state
- `READY` shows `1/1` (or appropriate ratio)
- No recent restarts

---

### Step 5: Verify Container Ports

```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].ports}' | jq .
```

**Verify:**
- Container port matches service `targetPort`
- Port protocol matches (TCP vs UDP)

---

## Resolution Options

### Option 1: Fix Label Mismatch (Recreate Deployment)

**Use When:** Kustomization labels are correct but running pod has old labels

**Steps:**
```bash
# 1. Delete deployment (pod will be terminated)
kubectl delete deployment <service-name> -n <namespace>

# 2. Reapply from kustomization (creates deployment with correct labels)
kubectl apply -k path/to/overlays/local/<service-name>/

# 3. Wait for pod to be ready
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=<service-name> \
  -n <namespace> --timeout=60s

# 4. Verify endpoints are populated
kubectl get endpoints <service-name> -n <namespace>
```

**Result:** New pod created with labels from kustomization, service finds pod

---

### Option 2: Update Service Selector

**Use When:** Pod labels are correct but service selector is wrong

**Steps:**
```bash
# 1. Edit service
kubectl edit service <service-name> -n <namespace>

# 2. Update .spec.selector to match pod labels
# (Editor will open - modify and save)

# 3. Verify endpoints are populated
kubectl get endpoints <service-name> -n <namespace>
```

**Caution:** This is a quick fix. Update the kustomization file to make it permanent.

---

### Option 3: Restart Deployment (Minor Label Changes)

**Use When:** Labels were updated in kustomization but deployment wasn't restarted

**Steps:**
```bash
# 1. Restart deployment
kubectl rollout restart deployment/<service-name> -n <namespace>

# 2. Wait for rollout
kubectl rollout status deployment/<service-name> -n <namespace>

# 3. Verify endpoints
kubectl get endpoints <service-name> -n <namespace>
```

**Note:** This only works if `includeSelectors: true` in kustomization

---

## Prevention Best Practices

### 1. Always Use includeSelectors When Changing Labels

**In kustomization.yaml:**
```yaml
labels:
- includeSelectors: true  # ← CRITICAL for label changes
  pairs:
    app.kubernetes.io/name: service-name
    app.kubernetes.io/part-of: application-name
```

**Why:** Without `includeSelectors: true`, labels only apply to metadata, not selectors

---

### 2. Verify Endpoints After Label Changes

**After any label change:**
```bash
# 1. Apply changes
kubectl apply -k path/to/overlays/

# 2. Restart deployment
kubectl rollout restart deployment/<service> -n <namespace>

# 3. Wait for rollout
kubectl rollout status deployment/<service> -n <namespace>

# 4. Verify endpoints
kubectl get endpoints <service> -n <namespace>
```

---

### 3. Test Service Connectivity

**From inside cluster:**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  wget -qO- http://<service>.<namespace>.svc.cluster.local:<port>
```

**Expected:** Should connect successfully

---

### 4. Monitor Service Endpoints

**Set up monitoring alert:**
```yaml
# Prometheus alert example
- alert: ServiceNoEndpoints
  expr: |
    kube_service_info
    unless on(service,namespace)
    kube_endpoint_address_available
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Service {{ $labels.service }} in {{ $labels.namespace }} has no endpoints"
```

---

## Real-World Example: Redis Label Mismatch

### Background

After Traefik migration (November 23, 2025), platform was renamed:
- Old: `solidity-security-platform`
- New: `blocksecops-platform`

Kustomization files were updated, but running pods kept old labels.

### Investigation

```bash
# Check endpoints
$ kubectl get endpoints redis -n redis-local
NAME    ENDPOINTS   AGE
redis   <none>      5m  # ← No endpoints!

# Compare labels
$ kubectl get service redis -n redis-local -o jsonpath='{.spec.selector}'
{"app.kubernetes.io/part-of":"blocksecops-platform"}  # ← Service selector

$ kubectl get pod -n redis-local -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/part-of}'
solidity-security-platform  # ← Pod label (OLD)
```

### Resolution

```bash
# Delete and recreate deployment
kubectl delete deployment redis -n redis-local
kubectl apply -k blocksecops-gcp-infrastructure/k8s/overlays/local/redis/

# Verify fix
$ kubectl get endpoints redis -n redis-local
NAME    ENDPOINTS           AGE
redis   10.244.8.102:6379   10s  # ← Endpoints populated!
```

### Result

- ✅ Service found pod with matching labels
- ✅ Endpoints registered successfully
- ✅ API service connected to Redis
- ✅ Projects endpoint functional

---

## Additional Diagnostics

### Check Service Configuration

```bash
kubectl get service <service-name> -n <namespace> -o yaml
```

**Verify:**
- `.spec.selector` matches pod labels
- `.spec.ports[].targetPort` matches container port
- `.spec.type` is appropriate (ClusterIP, NodePort, etc.)

---

### Check Network Policies

```bash
kubectl get networkpolicy -n <namespace>
```

**If policies exist:**
```bash
kubectl describe networkpolicy <policy-name> -n <namespace>
```

**Check:** Policy allows ingress to pod from service subnet

---

### Check Pod Logs

```bash
kubectl logs -n <namespace> <pod-name>
```

**Look For:**
- Application listening on correct port
- Binding to `0.0.0.0` (not `localhost`)
- No startup errors

---

### Test Port Connectivity Inside Pod

```bash
kubectl exec -n <namespace> <pod-name> -- netstat -tlnp
```

**Verify:** Application listening on expected port

---

## Related Documentation

**Standards:**
- [Kubernetes Kustomize Structure Template](/Users/pwner/Git/ABS/docs/architecture-templates/kubernetes-kustomize-structure-template.md)
- [Port-Forwarding Standards](/Users/pwner/Git/ABS/docs/standards/port-forwarding.md)
- [Ingress and Networking Standards](/Users/pwner/Git/ABS/docs/standards/ingress-networking.md)

**Troubleshooting:**
- [Local Development Setup](/Users/pwner/Git/ABS/docs/standards/local-development-setup.md)

**Work Documentation:**
- [Redis Projects Fix - November 25, 2025](/Users/pwner/Git/ABS/TaskDocs-Apogee/DOCUMENTATION-UPDATE-2025-11-25-REDIS-PROJECTS-FIX.md)

---

## Quick Reference Commands

```bash
# Check endpoints
kubectl get endpoints <service> -n <namespace>

# Compare selector and labels
kubectl get service <service> -n <namespace> -o jsonpath='{.spec.selector}' | jq .
kubectl get pod -n <namespace> -o jsonpath='{.items[0].metadata.labels}' | jq .

# Find pods matching selector
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<service>

# Fix: Recreate deployment
kubectl delete deployment <service> -n <namespace>
kubectl apply -k path/to/overlays/local/<service>/

# Fix: Restart deployment
kubectl rollout restart deployment/<service> -n <namespace>

# Verify fix
kubectl get endpoints <service> -n <namespace>
```

---

**Document Owner:** Advanced Blockchain Security
**Created:** November 25, 2025
**Last Updated:** November 25, 2025
**Status:** Active
