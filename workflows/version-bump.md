# Version Bump Workflow

**Version:** 1.0.0
**Last Updated:** March 4, 2026

## Overview

How to bump a service version. Two files, one commit, no scripts.

---

## Steps

### 1. Bump the source version

| Language | File | Example |
|----------|------|---------|
| Python | `pyproject.toml` | `version = "0.29.67"` |
| Node.js | `package.json` | `"version": "0.46.23"` |
| Rust | `Cargo.toml` | `version = "0.2.3"` |

### 2. Update the base kustomization

Edit `k8s/base/<service>/kustomization.yaml`:

```yaml
images:
  - name: <service>
    newTag: "0.29.67"  # Must match source version

labels:
- includeSelectors: false
  pairs:
    app.kubernetes.io/version: "0.29.67"  # Must match source version
```

### 3. Commit both files together

```bash
git add pyproject.toml k8s/base/
git commit -m "chore(<service>): bump version to 0.29.67"
```

---

## Rules

- **Only the base kustomization has `newTag`**. Overlays inherit it.
- **Never add `newTag` or `app.kubernetes.io/version` to an overlay**. Overlays only set `newName` (registry path per environment).
- **Source version and base `newTag` must always match**. Commit them together.

---

## Build and Deploy

After bumping and committing:

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# Build and push
docker build -t ${REGISTRY}/blocksecops/<service>:${VERSION} .
docker push ${REGISTRY}/blocksecops/<service>:${VERSION}

# Apply (updates Deployment AND CronJob image tags)
kubectl apply -k k8s/overlays/local/<service>/
```

---

## Verification

```bash
# Confirm source and base match
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
BASE_TAG=$(grep 'newTag' k8s/base/*/kustomization.yaml | head -1 | grep -o '"[^"]*"' | tr -d '"')
[ "$VERSION" = "$BASE_TAG" ] && echo "IN SYNC" || echo "DRIFT: source=$VERSION base=$BASE_TAG"

# Confirm no overlay has newTag
grep -r "newTag" k8s/overlays/ && echo "VIOLATION: overlay has newTag" || echo "Clean"
```

---

## Related Standards

- [Docker Image Versioning](../standards/docker-image-versioning.md)
- [Kustomize Standards](../standards/kustomize-standards.md)
- [Version Control Standards](../standards/version-control-standards.md)
