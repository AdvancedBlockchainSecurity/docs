# Kubernetes Pod Lifecycle Standards

**Version:** 2.0.0
**Last Updated:** March 10, 2026
**Status:** Active

## Overview

This document defines standards for Kubernetes pod lifecycle management, including revision history limits, pod cleanup, security contexts, and NetworkPolicies. These standards ensure:

- **Resource Efficiency:** Automatic cleanup of old ReplicaSets and pods
- **Security:** Consistent security contexts across all services
- **Network Isolation:** NetworkPolicies for defense-in-depth
- **Operational Safety:** Controlled rollback capability

---

## Revision History Limits

### Standard Configuration

**MANDATORY:** All Deployments must include `revisionHistoryLimit: 3`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service>
spec:
  revisionHistoryLimit: 3  # MANDATORY
  replicas: ...
```

### Why This Matters

| Without revisionHistoryLimit | With revisionHistoryLimit: 3 |
|------------------------------|------------------------------|
| Kubernetes keeps 10 old ReplicaSets (default) | Only 3 old ReplicaSets kept |
| Stale pods accumulate over time | Automatic cleanup after deployments |
| Resource waste (memory, etcd storage) | Efficient resource usage |
| Confusing `kubectl get rs` output | Clean, readable output |

### Rollback Capability

With `revisionHistoryLimit: 3`, you can rollback to any of the 3 previous versions:

```bash
# View revision history
kubectl rollout history deployment/<service> -n <namespace>

# Rollback to previous version
kubectl rollout undo deployment/<service> -n <namespace>

# Rollback to specific revision
kubectl rollout undo deployment/<service> -n <namespace> --to-revision=2
```

### Manual Cleanup

After setting revisionHistoryLimit, Kubernetes automatically cleans up excess ReplicaSets. For immediate cleanup:

```bash
# List old ReplicaSets with 0 replicas
kubectl get rs -A -o wide | awk '$3 == 0 && $4 == 0'

# Delete specific old ReplicaSet
kubectl delete rs -n <namespace> <old-rs-name>
```

---

## Security Contexts

### Pod-Level Security Context

**MANDATORY:** All Deployments must include pod-level security context.

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
```

| Setting | Purpose |
|---------|---------|
| `runAsNonRoot: true` | Prevents container from running as root |
| `runAsUser: 1000` | Runs as non-privileged user |
| `runAsGroup: 1000` | Sets primary group |
| `fsGroup: 1000` | Sets group ownership for mounted volumes |
| `seccompProfile: RuntimeDefault` | Applies default seccomp profile |

### Container-Level Security Context

**MANDATORY:** All containers must include container-level security context.

```yaml
containers:
- name: <service>
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

| Setting | Purpose |
|---------|---------|
| `allowPrivilegeEscalation: false` | Prevents gaining more privileges |
| `readOnlyRootFilesystem: true` | Makes root filesystem read-only |
| `capabilities.drop: ALL` | Removes all Linux capabilities |

### Volume Mounts for Read-Only Root

When using `readOnlyRootFilesystem: true`, applications need writable directories:

```yaml
containers:
- name: <service>
  volumeMounts:
  - name: tmp
    mountPath: /tmp
  - name: cache
    mountPath: /app/.cache
  - name: logs
    mountPath: /app/logs
volumes:
- name: tmp
  emptyDir: {}
- name: cache
  emptyDir: {}
- name: logs
  emptyDir: {}
```

**Common writable paths:**
- `/tmp` - Temporary files
- `/app/.cache` - Application cache
- `/app/logs` - Application logs (if not using stdout)
- `/app/data` - Runtime data

---

## InitContainer Patterns

### TLS Certificate Permission Fixing

Kubernetes secret volumes mount files as 0640 (group-readable) due to fsGroup projection, even when `defaultMode: 0600` is specified. PostgreSQL rejects TLS key files with permissions above 0600.

**Solution:** Use an initContainer to copy certs to an emptyDir with correct permissions:

```yaml
initContainers:
- name: fix-tls-permissions
  image: busybox:1.36
  command: ['sh', '-c', 'cp /tls-source/* /tls-target/ && chmod 600 /tls-target/tls.key && chmod 644 /tls-target/tls.crt /tls-target/ca.crt']
  volumeMounts:
  - name: tls-certs
    mountPath: /tls-source
    readOnly: true
  - name: tls-fixed
    mountPath: /tls-target
```

**Important:** Do NOT set `runAsUser: 0` on the initContainer if the pod has `runAsNonRoot: true`. The copy will work as the pod's default user (e.g., 999 for postgres), and file ownership will be correct via fsGroup.

**Used by:** PostgreSQL StatefulSet (local overlay) for cert-manager TLS certificates.

---

## NetworkPolicies

### Standard Pattern

**MANDATORY:** All services must have NetworkPolicies defining allowed traffic.

Every service namespace should have:
1. Default deny-all policy
2. Service-specific ingress rules
3. Service-specific egress rules (DNS, databases, etc.)

### Default Deny-All Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Ingress Policy Template

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <service>-ingress
spec:
  podSelector:
    matchLabels:
      app: <service>
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: <source-namespace>
      ports:
        - protocol: TCP
          port: <service-port>
```

### Egress Policy Template (DNS)

**MANDATORY:** All services need DNS egress with AND selector (namespace + pod).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <service>-to-dns
spec:
  podSelector:
    matchLabels:
      app: <service>
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

### AND vs OR Selectors (Critical)

**IMPORTANT:** Egress `to:` items with separate list entries are ORed, not ANDed. For defense-in-depth, use a single object with both `namespaceSelector` and `podSelector`:

```yaml
# CORRECT (AND - must match BOTH namespace AND pod label):
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: postgresql-<env>
        podSelector:              # Same list item = AND
          matchLabels:
            app.kubernetes.io/name: postgresql

# WRONG (OR - matches any pod in namespace OR any namespace with pod label):
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: postgresql-<env>
      - podSelector:              # Separate list item = OR
          matchLabels:
            app.kubernetes.io/name: postgresql
```

On non-enforcing CNIs (Flannel) both patterns appear to work, but on enforcing CNIs (Calico, Cilium) the OR pattern allows unintended traffic.

### Namespace Selector Labels

**MANDATORY:** Always use `kubernetes.io/metadata.name` for namespace selectors. This label is automatically applied by Kubernetes to every namespace and is guaranteed to exist.

```yaml
# CORRECT:
namespaceSelector:
  matchLabels:
    kubernetes.io/metadata.name: postgresql-<env>

# WRONG (custom label that may not exist):
namespaceSelector:
  matchLabels:
    name: postgresql-local
```

### Common Egress Patterns

**PostgreSQL:**
```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: postgresql-<env>
        podSelector:
          matchLabels:
            app.kubernetes.io/name: postgresql
    ports:
      - protocol: TCP
        port: 5432
```

**Redis:**
```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: redis-<env>
        podSelector:
          matchLabels:
            app.kubernetes.io/name: redis
            app.kubernetes.io/component: master
    ports:
      - protocol: TCP
        port: 6379
```

**Vault:**
```yaml
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: vault-<env>
        podSelector:
          matchLabels:
            app.kubernetes.io/name: vault
    ports:
      - protocol: TCP
        port: 8200
```

**External HTTPS (APIs, webhooks) - RFC1918 exclusion:**
```yaml
egress:
  - to:
      - ipBlock:
          cidr: 0.0.0.0/0
          except:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16
    ports:
      - protocol: TCP
        port: 443
```

> **Note:** Use `ipBlock` with RFC1918 exclusions instead of `namespaceSelector: {}` to prevent internal cluster traffic from bypassing per-service egress rules.

### Kustomization Integration

Add NetworkPolicy to kustomization.yaml:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - serviceaccount.yaml
  - networkpolicy.yaml  # Add this
```

---

## Service-Specific Requirements

### Frontend Services (Dashboard)

```yaml
# Ingress from Traefik only
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: traefik-<env>
    ports:
      - protocol: TCP
        port: 3000

# Egress to API service and DNS
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: api-service-<env>
    ports:
      - protocol: TCP
        port: 8000
```

### Backend Services (API, Data, Intelligence)

```yaml
# Ingress from other services
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: api-service-<env>
    ports:
      - protocol: TCP
        port: 8000

# Egress to databases, cache, other services
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: postgresql-<env>
    ports:
      - protocol: TCP
        port: 5432
```

### Notification Services

```yaml
# Additional egress for external webhooks
egress:
  # SMTP
  - ports:
      - protocol: TCP
        port: 25
      - protocol: TCP
        port: 465
      - protocol: TCP
        port: 587
  # HTTPS (Slack, Teams webhooks)
  - ports:
      - protocol: TCP
        port: 443
```

---

## Verification

### Check Revision History Limit

```bash
# Check all deployments
kubectl get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.revisionHistoryLimit}{"\n"}{end}'

# Check specific deployment
kubectl get deployment <name> -n <namespace> -o jsonpath='{.spec.revisionHistoryLimit}'
```

### Check Security Contexts

```bash
# Check pod security context
kubectl get pod -n <namespace> -l app=<service> -o jsonpath='{.items[0].spec.securityContext}' | jq .

# Check container security context
kubectl get pod -n <namespace> -l app=<service> -o jsonpath='{.items[0].spec.containers[0].securityContext}' | jq .
```

### Check NetworkPolicies

```bash
# List all NetworkPolicies
kubectl get networkpolicy -A

# Describe specific policy
kubectl describe networkpolicy <name> -n <namespace>

# Test connectivity (from within a pod)
kubectl exec -n <namespace> <pod> -- curl -s <target-service>.<target-namespace>.svc.cluster.local:<port>
```

---

## Troubleshooting

### Pods Not Starting After Security Context

**Symptom:** Pod in CrashLoopBackOff after adding readOnlyRootFilesystem

**Solution:** Add emptyDir volumes for writable paths:
```yaml
volumeMounts:
- name: tmp
  mountPath: /tmp
volumes:
- name: tmp
  emptyDir: {}
```

### Network Connectivity Issues After NetworkPolicy

**Symptom:** Service cannot reach database/other services

**Solution:**
1. Verify egress policy exists for target
2. Check namespace selector labels match
3. Ensure DNS egress is configured

```bash
# Check namespace labels
kubectl get namespace <target-ns> --show-labels

# Test DNS resolution
kubectl exec -n <namespace> <pod> -- nslookup <service>.<target-ns>.svc.cluster.local
```

### Old ReplicaSets Not Cleaning Up

**Symptom:** Old ReplicaSets remain after deployment

**Solution:**
1. Verify revisionHistoryLimit is set
2. Check ReplicaSet count exceeds limit
3. Manually delete if needed

```bash
# Check current ReplicaSets
kubectl get rs -n <namespace>

# Delete old ReplicaSet
kubectl delete rs -n <namespace> <old-rs-name>
```

---

## Compliance Checklist

Before deploying any new service:

- [ ] `revisionHistoryLimit: 3` set in Deployment spec
- [ ] Pod-level security context configured
- [ ] Container-level security context configured
- [ ] Volume mounts for writable directories
- [ ] NetworkPolicy with default-deny created
- [ ] Ingress rules for allowed sources
- [ ] Egress rules for DNS
- [ ] Egress rules for databases (if needed)
- [ ] Egress rules for other services (if needed)
- [ ] NetworkPolicy added to kustomization.yaml

---

## Related Documentation

- [Core Development Rules](./core-development-rules.md)
- [Docker Image Versioning](./docker-image-versioning.md)
- [Testing & Deployment](./testing-deployment.md)
- [GCP Launch Phase 2](../../TaskDocs-Apogee/DOCUMENTATION-UPDATE-2026-02-01-GCP-LAUNCH-PHASE-2.md)
