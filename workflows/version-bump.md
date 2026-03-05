# Version Bump Workflow

**Version:** 1.0.0
**Last Updated:** March 5, 2026

## Overview

How to bump a service version. Update the source file, all kustomization overlays, and commit.

---

## Steps

### 1. Bump the source version

| Language | File | Example |
|----------|------|---------|
| Python | `pyproject.toml` | `version = "0.29.67"` |
| Node.js | `package.json` | `"version": "0.46.23"` |
| Rust | `Cargo.toml` | `version = "0.2.3"` |

### 2. Update all kustomization image tags

Update `newTag` and `app.kubernetes.io/version` in **every** kustomization that references this service — base AND all overlays (local, staging, production):

```yaml
images:
  - name: <service>
    newTag: "0.29.67"  # Must match source version

labels:
- pairs:
    app.kubernetes.io/version: "0.29.67"  # Must match source version
```

### 3. Commit all files together

```bash
git add pyproject.toml k8s/
git commit -m "chore(<service>): bump version to 0.29.67"
```

---

## Rules

- **Source version and all `newTag` values must always match.** Commit them together.
- **Check ALL overlays** — local, staging, and production. Missing one causes drift.

---

## Verification

```bash
# Confirm source and all overlays match
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
for f in $(grep -rl "newTag" k8s/); do
  TAG=$(grep 'newTag' "$f" | grep -o '"[^"]*"' | tr -d '"')
  if [ "$TAG" != "$VERSION" ] && [ "$TAG" != "staging-latest" ] && [ "$TAG" != "production-latest" ]; then
    echo "DRIFT: $f has $TAG, expected $VERSION"
  fi
done
echo "Done"
```

---

## Related Standards

- [Docker Image Versioning](../standards/docker-image-versioning.md)
- [Kustomize Standards](../standards/kustomize-standards.md)
- [Version Control Standards](../standards/version-control-standards.md)
