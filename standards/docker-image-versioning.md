# Docker Image Versioning Standards

**Version:** 2.0.0
**Last Updated:** December 12, 2025

## Semantic Versioning

All Docker images follow [Semantic Versioning 2.0.0](https://semver.org/):

**Format:** `MAJOR.MINOR.PATCH`

| Increment | When | Example |
|-----------|------|---------|
| **PATCH** | Bug fixes, security patches, minor improvements | `0.3.12` → `0.3.13` |
| **MINOR** | New features (backwards-compatible) | `0.3.13` → `0.4.0` |
| **MAJOR** | Breaking changes | `0.4.0` → `1.0.0` |

## Workflow

```bash
# 1. Build image with new version
docker build -t <service>:<version> -f <service>/Dockerfile .

# 2. Push to registry
docker push <registry>/<service>:<version>

# 3. Update kustomization.yaml
#    - Change newTag to new version
#    - Change app.kubernetes.io/version label to match

# 4. Apply
kubectl apply -k k8s/overlays/local/
```

Kubernetes sees the image tag changed → triggers rollout → pulls new image.

## Kustomization Example

```yaml
# k8s/overlays/local/<service>/kustomization.yaml
images:
- name: PLACEHOLDER_REGISTRY/<service>
  newName: <service>
  newTag: "0.2.1"  # ← Update this

labels:
- pairs:
    app.kubernetes.io/version: "0.2.1"  # ← Keep in sync
```

## Why Explicit Versions (Not `latest`)

Per [Kubernetes documentation](https://kubernetes.io/docs/concepts/containers/images/):

> "You should avoid using the `:latest` tag when deploying containers in production as it is harder to track which version of the image is running and more difficult to roll back properly."

| Explicit Versions | `latest` Tag |
|-------------------|--------------|
| Know what's running | Unknown version |
| Easy rollback | No rollback target |
| Reproducible | May vary between pulls |
| Change triggers rollout | Requires manual restart |

## Pre-1.0 Development

All services are currently `0.x.x` (development phase).

- `0.x.x` - API may change
- `1.0.0` - Stable, production-ready API
