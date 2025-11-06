# Docker Image Versioning Standards

**Version:** 1.9.0
**Last Updated:** November 5, 2025
**Status:** Active

## Semantic Versioning for Docker Images

**MANDATORY:** All Docker images MUST follow [Semantic Versioning 2.0.0](https://semver.org/) specification.

**Format:** `MAJOR.MINOR.PATCH`

Where:
- **MAJOR** version = Breaking changes (incompatible API changes)
- **MINOR** version = New features (backwards-compatible functionality)
- **PATCH** version = Bug fixes (backwards-compatible fixes)

**Examples:**

```bash
# Bug fix (scanner import error) - increment PATCH
api-service:0.3.12 → api-service:0.3.13

# New feature (custom scanner selection) - increment MINOR
api-service:0.3.13 → api-service:0.4.0

# Breaking change (new authentication system) - increment MAJOR
api-service:0.4.0 → api-service:1.0.0
```

## Version Increment Rules

**MANDATORY:** Docker image version MUST be incremented whenever code changes are made to the service.

**When to increment PATCH (0.3.12 → 0.3.13):**
- Bug fixes
- Security patches
- Performance improvements (no API changes)
- Documentation updates
- Dependency updates (no behavior change)
- Code changes (any source code modifications)

**When to increment MINOR (0.3.13 → 0.4.0):**
- New features (backwards-compatible)
- New API endpoints
- New configuration options
- Deprecated features (not removed)
- Internal refactoring with new capabilities

**When to increment MAJOR (0.4.0 → 1.0.0):**
- Breaking API changes
- Removed endpoints or features
- Changed authentication/authorization
- Database schema changes requiring migration
- Configuration format changes
- Removed or changed environment variables

## Pre-1.0 Development

**Current Status:** All services are in `0.x.x` (pre-release/development)

During `0.x.x` versions:
- **MINOR** versions MAY introduce breaking changes
- **PATCH** versions MUST be backwards-compatible
- Version `1.0.0` signals production-ready, stable API

**When to release 1.0.0:**
- API is stable and well-tested
- All critical features implemented
- Comprehensive test coverage
- Security hardening complete
- Documentation complete
- Ready for production use

## Image Tagging Workflow

**Building and tagging images:**

```bash
# 1. Determine version increment based on changes
# Bug fix example: 0.3.12 → 0.3.13

# 2. Build image with new version
eval $(minikube docker-env)
docker build -t api-service:0.3.13 -f Dockerfile .

# 3. Also tag as 'latest' for local development
docker tag api-service:0.3.13 api-service:latest

# 4. Verify image exists
docker images | grep api-service
```

## Kustomize Configuration Strategy

**IMPORTANT:** Kustomize configuration differs between local development and production environments.

### Local Development (k8s/overlays/local/)

**For local development, use `latest` tag to avoid manual updates:**

```yaml
# k8s/overlays/local/kustomization.yaml
images:
- name: PLACEHOLDER_REGISTRY/blocksecops-api-service
  newName: api-service
  newTag: latest  # ← Always use 'latest' for local development

labels:
- includeSelectors: false
  pairs:
    app.kubernetes.io/version: latest  # ← Use 'latest' for local dev
```

**Benefits:**
- No need to update kustomization.yaml after each image build
- Kubernetes automatically pulls the latest local image
- Faster development iteration
- Reduces configuration drift between code and deployment

**Deployment workflow:**
```bash
# 1. Build versioned image
docker build -t api-service:0.3.13 -f Dockerfile .

# 2. Tag as latest
docker tag api-service:0.3.13 api-service:latest

# 3. Apply kustomization (no changes needed)
kubectl apply -k k8s/overlays/local/

# 4. Restart deployment to pick up new image
kubectl rollout restart deployment/api-service -n api-service-local
```

### Production/Staging (k8s/overlays/prod/, k8s/overlays/staging/)

**For production deployments, use specific version tags:**

```yaml
# k8s/overlays/prod/kustomization.yaml
images:
- name: PLACEHOLDER_REGISTRY/blocksecops-api-service
  newName: registry.example.com/api-service
  newTag: 0.3.13  # ← Specific version for reproducibility

labels:
- includeSelectors: false
  pairs:
    app.kubernetes.io/version: 0.3.13  # ← Match image version
```

**Benefits:**
- Reproducible deployments
- Easy rollbacks to known versions
- Clear audit trail of deployed versions
- Prevents accidental deployments

**Critical:** Update BOTH `newTag` AND `app.kubernetes.io/version` to match for production!

## Version Tracking

**Track image versions in multiple locations:**

1. **Docker Image Tag:** Actual image version
2. **Kustomization:** Kubernetes deployment version
3. **Git Tag:** Code version matching image

**Creating git tags for releases:**

```bash
# Tag the commit that matches the Docker image
git tag -a api-service-v0.3.13 -m "Release API Service v0.3.13

- Fix: Scanner endpoint import error
- Allows scanner metadata to be retrieved via API
- Resolves blocking issue for custom scanner selection feature"

# Push tag to remote
git push origin api-service-v0.3.13
```

## Version Documentation

**Document version changes in CHANGELOG:**

```markdown
# CHANGELOG - API Service

## [0.3.13] - 2025-10-17

### Fixed
- Scanner endpoint import error preventing scanner metadata retrieval
- Corrected import path from non-existent ScannerService to ToolIntegrationClient

## [0.3.12] - 2025-10-17

### Fixed
- Kubernetes service endpoint issue with includeSelectors
- Service selector mismatch causing zero endpoints

## [0.3.11] - 2025-10-16

### Added
- TypeScript build fixes for ui-core package
- Scan modal UX improvements with loading states
```

## Rollback Considerations

**Version tracking enables easy rollbacks:**

### Local Development Rollback

```bash
# For local development, rollback by re-tagging older version as latest
eval $(minikube docker-env)
docker tag api-service:0.3.12 api-service:latest
kubectl rollout restart deployment/api-service -n api-service-local
```

### Production Rollback

```bash
# Update kustomization with previous version
vim k8s/overlays/prod/kustomization.yaml
# Change newTag: 0.3.13 back to newTag: 0.3.12
# Change app.kubernetes.io/version: 0.3.13 to 0.3.12

kubectl apply -k k8s/overlays/prod/
```

## Version Checklist

### Local Development Checklist

Before deploying locally:

- [ ] Determine correct increment type (MAJOR/MINOR/PATCH)
- [ ] Build Docker image with new version tag
- [ ] Tag image as `latest`
- [ ] **No kustomization.yaml changes needed** (uses `latest`)
- [ ] Restart deployment to pick up new image
- [ ] Test new functionality
- [ ] Create git tag matching version (for tracking)
- [ ] Update CHANGELOG with changes

### Production Deployment Checklist

Before deploying to production:

- [ ] Ensure version is tested in local environment
- [ ] Build and push Docker image to registry with version tag
- [ ] Update production kustomization.yaml (newTag + version label)
- [ ] Create git tag matching version
- [ ] Update CHANGELOG with changes
- [ ] Document breaking changes (if MAJOR/MINOR increment)
- [ ] Test deployment in staging environment
- [ ] Verify rollback procedure works
- [ ] Deploy to production

**Example Version History:**

```
0.1.0 - Initial development version
0.2.0 - Added scan functionality
0.3.0 - Added vulnerability management
0.3.1 - Fixed vulnerability status bug
0.3.2 - Performance improvements
...
0.3.12 - Fixed service endpoint issue
0.3.13 - Fixed scanner import error
0.4.0 - Added custom scanner selection (next)
1.0.0 - Production release (future)
```

---

**See Also:**
- [Testing & Deployment](./testing-deployment.md) - Testing and deployment workflows
- [Version Control Standards](./version-control-standards.md) - Git workflow and tagging
- [Core Development Rules](./core-development-rules.md) - Development workflow rules
