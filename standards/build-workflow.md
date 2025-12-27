# Build Workflow

**Version:** 3.0.0
**Last Updated:** December 22, 2025

## Overview

For local development, images are built directly into minikube's Docker daemon:

```
eval $(minikube docker-env) → docker build → kubectl apply
```

This is the fastest workflow for rapid iteration during development.

> **Note:** Harbor is deployed in the cluster but is **not used for local development**. Harbor is intended for staging/production CI/CD pipelines.

## Local Development Workflow (Recommended)

### Build and Deploy

```bash
# 1. Switch to minikube's Docker daemon (REQUIRED)
eval $(minikube docker-env)

# 2. Build with versioned tag
docker build -t <service>:<version> .

# 3. Tag as latest (for kustomization compatibility)
docker tag <service>:<version> <service>:latest

# 4. Update kustomization.yaml with new version
#    - Update images[].newTag
#    - Update labels app.kubernetes.io/version

# 5. Apply
kubectl apply -k k8s/overlays/local/<service>/
```

### Example: Building API Service

```bash
eval $(minikube docker-env)
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Build
docker build -t api-service:0.4.2 .
docker tag api-service:0.4.2 api-service:latest

# Update version in kustomization.yaml, then deploy
kubectl apply -k k8s/overlays/local/
```

### Kustomization Image Reference

For local development, use simple image names (no registry prefix):

```yaml
# k8s/overlays/local/<service>/kustomization.yaml
images:
- name: <service>
  newName: <service>
  newTag: "<version>"
```

## Why Minikube Docker (Not Harbor)

| Minikube Docker | Harbor Registry |
|-----------------|-----------------|
| No push/pull overhead | Requires push + pull |
| Instant availability | Network transfer time |
| Simple workflow | Requires socat proxy setup |
| Good for rapid iteration | Better for CI/CD pipelines |

## Verifying Images in Minikube

```bash
# List images in minikube's Docker
eval $(minikube docker-env)
docker images | grep <service>

# Check what's running in cluster
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].image}'
```

## Force Deployment Update

If kubectl apply doesn't trigger a rollout (same image tag):

```bash
# Option 1: Rollout restart
kubectl rollout restart deployment/<service> -n <namespace>

# Option 2: Set image explicitly
kubectl set image deployment/<service> <service>=<service>:<new-version> -n <namespace>
```

## Troubleshooting

### Image not found by Kubernetes

Ensure you're building in minikube's Docker context:
```bash
# Check current Docker context
docker context show
# Should NOT be "default" - use minikube's daemon instead

# Switch to minikube's Docker
eval $(minikube docker-env)

# Rebuild
docker build -t <service>:<version> .
```

### Pod stuck in ImagePullBackOff

Check the image exists in minikube:
```bash
eval $(minikube docker-env)
docker images | grep <service>
```

If missing, rebuild the image.

### Deployment not updating

Force a rollout:
```bash
kubectl rollout restart deployment/<service> -n <namespace>
```

---

## Harbor Workflow (Staging/Production Only)

> **Note:** This section is for staging/production CI/CD pipelines. **Do not use Harbor for local development.**

For CI/CD pipelines that need to push to Harbor:

```bash
# Build locally
docker build -t <service>:<version> .

# Tag for Harbor
docker tag <service>:<version> <harbor-clusterip>:443/blocksecops/<service>:<version>

# Push to Harbor
docker push <harbor-clusterip>:443/blocksecops/<service>:<version>
```

Get Harbor's ClusterIP: `kubectl get svc harbor-core -n harbor-local -o jsonpath='{.spec.clusterIP}'`
