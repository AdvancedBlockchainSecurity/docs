# Kustomize Standards

**Part of:** [Platform Development Standards](./INDEX.md)
**Version:** 1.1.0
**Last Updated:** February 5, 2026
**Status:** Active

## Overview

This document defines standards for using Kustomize to manage Kubernetes manifests across multiple environments. Kustomize enables configuration reuse through bases and overlays.

---

## Directory Structure

### Standard Layout

```
k8s/
├── base/                       # Shared base configuration
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── serviceaccount.yaml
└── overlays/
    ├── local/                  # Local development (kubeadm + Harbor)
    │   ├── kustomization.yaml
    │   ├── deployment-patch.yaml
    │   └── configmap-patch.yaml
    ├── server/                 # Server/staging environment
    │   ├── kustomization.yaml
    │   ├── ingressroute.yaml
    │   └── deployment-patch.yaml
    └── gcp-production/         # GCP production
        ├── kustomization.yaml
        ├── ingressroute.yaml
        └── deployment-patch.yaml
```

### Naming Conventions

| Resource Type | File Name |
|--------------|-----------|
| Deployment | `deployment.yaml` / `deployment-patch.yaml` |
| Service | `service.yaml` / `service-patch.yaml` |
| ConfigMap | `configmap.yaml` / `configmap-patch.yaml` |
| Secret (reference only) | `externalsecret.yaml` |
| IngressRoute | `ingressroute.yaml` |
| ServiceAccount | `serviceaccount.yaml` |
| NetworkPolicy | `networkpolicy.yaml` |

---

## Base Configuration

### Base kustomization.yaml

```yaml
# k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: <service>-base  # Will be overridden by overlay

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - serviceaccount.yaml

commonLabels:
  app.kubernetes.io/name: <service>
  app.kubernetes.io/part-of: blocksecops
```

### Base Deployment Template

```yaml
# k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service>
spec:
  replicas: 1
  revisionHistoryLimit: 3  # Required per kubernetes-pod-lifecycle.md
  selector:
    matchLabels:
      app.kubernetes.io/name: <service>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <service>
    spec:
      serviceAccountName: <service>
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: <service>
          image: <service>:latest  # Overridden by overlay
          ports:
            - containerPort: 8000
              name: http
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
```

---

## Overlay Configuration

### Overlay kustomization.yaml

```yaml
# k8s/overlays/local/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: <service>-local  # Environment-specific namespace

resources:
  - ../../base
  - ingressroute.yaml  # Environment-specific resources

patches:
  - path: deployment-patch.yaml
  - path: configmap-patch.yaml

images:
  - name: <service>
    newName: blocksecops-<service>
    newTag: "0.1.0"  # Must match pyproject.toml/package.json
```

### Patch File Standards

**Strategic Merge Patch (Default):**
```yaml
# k8s/overlays/local/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service>
spec:
  template:
    spec:
      containers:
        - name: <service>
          env:
            - name: ENVIRONMENT
              value: local
          resources:
            limits:
              memory: "1Gi"
```

**JSON Patch (for complex operations):**
```yaml
# k8s/overlays/local/kustomization.yaml
patches:
  - target:
      kind: Deployment
      name: <service>
    patch: |
      - op: replace
        path: /spec/replicas
        value: 2
```

---

## Environment-Specific Patterns

### Local Development (kubeadm + Harbor)

```yaml
# k8s/overlays/local/kustomization.yaml
namespace: <service>-local

images:
  - name: <service>
    newName: harbor.blocksecops.local/blocksecops/<service>
    newTag: "0.1.0"
```

**Build command:**
```bash
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"
docker build -t ${REGISTRY}/blocksecops/<service>:0.1.0 .
docker push ${REGISTRY}/blocksecops/<service>:0.1.0
kubectl apply -k k8s/overlays/local/
```

### Server (kubeadm with Harbor)

```yaml
# k8s/overlays/server/kustomization.yaml
namespace: <service>-local  # Still uses -local suffix

images:
  - name: <service>
    newName: harbor.blocksecops.local/blocksecops/<service>
    newTag: "0.1.0"
```

**Build command:**
```bash
docker build -t harbor.blocksecops.local/blocksecops/<service>:0.1.0 .
docker push harbor.blocksecops.local/blocksecops/<service>:0.1.0
kubectl apply -k k8s/overlays/local/  # Server uses local overlay for base
```

### GCP Production

```yaml
# k8s/overlays/gcp-production/kustomization.yaml
namespace: <service>

images:
  - name: <service>
    newName: us-central1-docker.pkg.dev/blocksecops/platform/<service>
    newTag: "0.1.0"
```

---

## Image Versioning Integration

### Source of Truth

The **application version file** is the single source of truth:

| Language | Source File | Field |
|----------|-------------|-------|
| Python | `pyproject.toml` | `version = "X.Y.Z"` |
| Node.js | `package.json` | `"version": "X.Y.Z"` |

### Version Sync Process

1. **Update source version:**
   ```bash
   # Python
   sed -i 's/version = ".*"/version = "0.2.0"/' pyproject.toml

   # Node.js
   npm version 0.2.0 --no-git-tag-version
   ```

2. **Update kustomization newTag:**
   ```yaml
   images:
     - name: <service>
       newTag: "0.2.0"  # Must match source
   ```

3. **Commit together:**
   ```bash
   git add pyproject.toml k8s/overlays/local/kustomization.yaml
   git commit -m "chore(<service>): bump version to 0.2.0"
   ```

### CRITICAL: CronJobs Use Same Image

**The kustomize `images` block applies to ALL resources**, including CronJobs. This is the intended behavior - CronJobs should use the same image version as Deployments.

```yaml
# This applies to BOTH deployment.yaml AND cronjob-*.yaml
images:
  - name: blocksecops-api-service
    newName: harbor.blocksecops.local/blocksecops/api-service
    newTag: "0.25.7"  # Applied to Deployment AND CronJob
```

**Verification:**
```bash
# Verify both deployment and cronjob use same version
kubectl kustomize k8s/overlays/local | grep -A2 "image:"
```

**Common Issue:** If `kubectl apply -k` is not re-run after a version bump, CronJobs will run with old code while Deployments may appear updated (via `kubectl rollout restart`). This can cause:
- Data inconsistencies between scheduled jobs and API
- Failed jobs due to schema mismatches
- Hard-to-debug production issues

**Root Cause (February 2026 incident):** During rapid version iteration (30+ bumps in 4 days), `kubectl apply -k` was missed after bumping from 0.29.5 to 0.29.7. The CronJob continued running 0.29.5 for 2 days, producing failed jobs. The Deployment also remained at 0.29.5 but appeared functional after a `kubectl rollout restart`.

**Prevention:** After every version bump, always run the full deploy cycle:
```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"
docker build -t ${REGISTRY}/blocksecops/<service>:${VERSION} .
docker push ${REGISTRY}/blocksecops/<service>:${VERSION}
kubectl apply -k k8s/overlays/local/<service>/   # NEVER skip this step
```

**Post-deploy verification:**
```bash
# Verify CronJob image matches Deployment image
kubectl get deployment -n <service>-local <service> -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get cronjob -n <service>-local -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.jobTemplate.spec.template.spec.containers[0].image}{"\n"}{end}'
```

---

## Common Patterns

### Adding Environment Variables

```yaml
# deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service>
spec:
  template:
    spec:
      containers:
        - name: <service>
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: <service>-secrets
                  key: database-url
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: <service>-config
                  key: log-level
```

### ConfigMap Patching

```yaml
# configmap-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <service>-config
data:
  log-level: "DEBUG"  # Override for local development
  api-url: "http://127.0.0.1:8000"
```

### Resource Limits by Environment

| Environment | Memory Request | Memory Limit | CPU Request | CPU Limit |
|-------------|---------------|--------------|-------------|-----------|
| Local | 256Mi | 512Mi | 100m | 500m |
| Server | 512Mi | 1Gi | 200m | 1000m |
| Production | 1Gi | 2Gi | 500m | 2000m |

---

## Validation

### Preview Changes

```bash
# Preview rendered manifests
kubectl kustomize k8s/overlays/local/

# Diff against current state
kubectl diff -k k8s/overlays/local/

# Dry-run apply
kubectl apply -k k8s/overlays/local/ --dry-run=client
```

### Common Validation Checks

1. **Namespace matches environment:**
   ```bash
   kubectl kustomize k8s/overlays/local/ | grep "namespace:"
   ```

2. **Image tag matches version:**
   ```bash
   VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
   kubectl kustomize k8s/overlays/local/ | grep "image:" | grep "$VERSION"
   ```

3. **No hardcoded secrets:**
   ```bash
   kubectl kustomize k8s/overlays/local/ | grep -i "password\|secret\|key" | grep -v "secretKeyRef"
   ```

---

## Anti-Patterns

### DO NOT

1. **Hardcode environment values in base:**
   ```yaml
   # BAD - in base/deployment.yaml
   env:
     - name: API_URL
       value: "http://localhost:8000"  # Should be in overlay
   ```

2. **Use `latest` tag:**
   ```yaml
   # BAD
   images:
     - name: api-service
       newTag: "latest"  # Use explicit version
   ```

3. **Duplicate resources across overlays:**
   ```yaml
   # BAD - copying entire deployment.yaml to overlay
   # Use patches instead
   ```

4. **Include cross-namespace resources in kustomization with `namespace:` set:**
   ```yaml
   # BAD - vault-policy.yaml has namespace: vault-local but kustomization overrides it
   namespace: postgresql-local  # Overrides ALL resources including vault-policy
   resources:
     - vault-policy.yaml  # This Job needs vault-local, not postgresql-local!

   # GOOD - apply cross-namespace resources separately
   # Remove from kustomization, apply directly:
   # kubectl apply -f vault-policy.yaml
   ```

5. **Commit ExternalSecrets with values:**
   ```yaml
   # BAD - in Git
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   spec:
     data:
       - secretKey: password
         remoteRef:
           key: secret/data/password  # OK to commit reference
           property: value  # OK
   ```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "no matches for kind" | Missing CRD | Apply CRDs before kustomization |
| Namespace conflict | Wrong overlay | Verify overlay path |
| Image not found | Tag mismatch | Sync newTag with version file |
| Patch not applied | Wrong path | Check strategic merge path |
| Cross-namespace resource placed in wrong NS | `namespace:` field overrides all resources | Apply cross-namespace resources separately with `kubectl apply -f` |

### Debug Commands

```bash
# Show kustomization tree
kubectl kustomize k8s/overlays/local/ --load-restrictor LoadRestrictionsNone

# Validate YAML syntax
kubectl kustomize k8s/overlays/local/ | kubectl apply --dry-run=client -f -

# Show applied patches
kustomize build k8s/overlays/local/ --enable-alpha-plugins
```

---

## Related Standards

- [Docker Image Versioning](./docker-image-versioning.md) - Version management
- [Port Forwarding](./port-forwarding.md) - Service access patterns
- [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md) - Pod configuration
- [Core Development Rules](./core-development-rules.md) - Codebase-first development

---

**See Also:**
- [Kubernetes Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Kustomization File Reference](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/)
