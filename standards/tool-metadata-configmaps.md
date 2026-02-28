# Tool Metadata Management via ConfigMaps

**Version:** 1.9.0
**Last Updated:** February 9, 2026
**Status:** Active

## Overview

**MANDATORY:** Third-party tool metadata (versions, developer information, configuration) MUST be managed via Kubernetes ConfigMaps rather than hardcoded in application code.

**Why this matters:**
- **Production Sustainability:** Version updates don't require code changes or deployments
- **Single Source of Truth:** All tool metadata centralized in one location
- **Git-Tracked History:** All version changes auditable through Git
- **Environment Flexibility:** Overlay-specific ConfigMaps enable staging/production version differences
- **Operational Simplicity:** Update ConfigMap → Restart service (no Docker rebuild required)

**Violations of this pattern result in:**
- Version drift (displayed versions don't match actual tools)
- Manual maintenance burden (every version update requires code change)
- Deployment overhead (Docker rebuild and push for simple version changes)
- No audit trail (can't track which versions ran when)

## Version Selection Policy

**MANDATORY:** All third-party tools and dependencies MUST use the latest stable version unless explicitly exempted.

**Policy:**
1. **Default: Latest Stable**
   - Always use the most recent stable release of all third-party tools
   - Applies to security scanners, libraries, frameworks, and all external dependencies
   - "Stable" means non-beta, non-RC, non-preview releases (e.g., `v1.2.3` not `v1.2.3-beta`)

2. **Exception Process**
   - Exceptions ONLY permitted when a major bug is discovered in the latest version
   - Exception decisions made at time of discovery through team review
   - Exceptions must be documented with:
     - Bug description and impact
     - Link to upstream issue/PR
     - Target date for upgrading to fixed version
     - Name of reviewer who approved exception

3. **Rationale**
   - **Security:** Latest versions include critical security patches
   - **Bug Fixes:** Benefit from upstream bug fixes immediately
   - **Performance:** Access to performance improvements and optimizations
   - **Compatibility:** Avoid technical debt from outdated dependencies
   - **Support:** Upstream projects typically only support recent versions

**Example Exception Documentation:**

```yaml
# ConfigMap with version exception
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.3",  # NOT latest (0.10.4)
        "exception_reason": "v0.10.4 has critical bug causing false positives on delegatecall patterns",
        "exception_issue": "https://github.com/crytic/slither/issues/12345",
        "exception_approved_by": "security-team",
        "exception_approved_date": "2024-10-15",
        "exception_target_upgrade": "v0.10.5 (when released)"
      }
    }
```

**Enforcement:**
- Weekly dependency update reviews (automated PR via Dependabot/Renovate recommended)
- CI pipeline warnings for outdated versions (> 30 days old)
- Quarterly security audit of all tool versions
- Dashboard visibility of version status (current vs latest)

## The Problem with Hardcoded Versions

**Anti-Pattern Example** (DO NOT DO THIS):

```python
# ❌ WRONG: Hardcoded scanner metadata in Python code
SCANNERS = {
    "slither": ScannerMetadata(
        id="slither",
        name="Slither",
        version="0.10.4",  # Hardcoded - requires code change to update
        developer="Trail of Bits",  # Hardcoded - no central management
        # ... other fields
    ),
    # ... 20+ more scanners with hardcoded versions
}
```

**Problems:**
- Every scanner version update requires:
  1. Edit Python code
  2. Commit code changes
  3. Build new Docker image
  4. Push Docker image
  5. Update deployment
  6. Restart pods
- No way to track version history separate from code changes
- Can't use different versions in staging vs production without code branches
- Version information scattered across multiple files

## The ConfigMap Solution

**Pattern:** Store tool metadata in a Kubernetes ConfigMap as JSON, load at runtime

**ConfigMap Structure:**

```yaml
# Location: k8s/base/scanner-versions-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
  namespace: tool-integration-local
data:
  # Tool metadata as JSON (single source of truth)
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.4",
        "developer": "Trail of Bits",
        "release_date": "2024-09-15"
      },
      "mythril": {
        "version": "0.24.8",
        "developer": "ConsenSys",
        "release_date": "2024-08-20"
      },
      "aderyn": {
        "version": "0.1.0",
        "developer": "Cyfrin",
        "release_date": "2024-07-10"
      }
    }

  # Tool Docker image tags (used by KubernetesJobManager)
  SCANNER_IMAGE_SLITHER: "scanner-slither:0.3.1"
  SCANNER_IMAGE_MYTHRIL: "scanner-mythril:0.2.0"
  SCANNER_IMAGE_ADERYN: "scanner-aderyn:0.7.0"
```

**Benefits:**
- One file contains all tool metadata
- Git tracks all version changes
- Can diff versions across environments
- Easy to review what versions are deployed

## Application Integration Pattern

**Step 1: Inject ConfigMap as Environment Variable**

```yaml
# Location: k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
spec:
  template:
    spec:
      containers:
      - name: api-service
        image: api-service:0.1.8
        env:
        # Inject tool metadata from ConfigMap
        - name: SCANNER_METADATA
          valueFrom:
            configMapKeyRef:
              name: scanner-versions
              key: SCANNER_METADATA
```

**Step 2: Load Metadata at Application Startup**

```python
# Location: src/infrastructure/scanner_config/scanners.py
import os
import json
import logging
from typing import Dict

logger = logging.getLogger(__name__)

def _load_scanner_metadata_from_env() -> Dict[str, dict]:
    """
    Load scanner metadata from SCANNER_METADATA environment variable.

    Returns:
        Dictionary mapping scanner_id -> {version, developer, ...}
    """
    metadata_json = os.getenv("SCANNER_METADATA", "{}")
    try:
        metadata = json.loads(metadata_json)
        logger.info(f"Loaded metadata for {len(metadata)} scanners from ConfigMap")
        return metadata
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse SCANNER_METADATA env var: {e}")
        return {}

# Load at module initialization (runs once at startup)
_SCANNER_METADATA_FROM_CONFIG = _load_scanner_metadata_from_env()
```

**Step 3: Use Metadata in Application Code**

```python
class ScannerMetadata:
    def __init__(
        self,
        id: str,
        name: str,
        description: str,
        version: Optional[str] = None,
        developer: Optional[str] = None,
        # ... other fields
    ):
        self.id = id
        self.name = name
        self.description = description

        # Load version/developer from ConfigMap automatically
        config_metadata = _SCANNER_METADATA_FROM_CONFIG.get(id, {})
        self.version = version or config_metadata.get("version", "unknown")
        self.developer = developer or config_metadata.get("developer", "unknown")

        # ✅ GOOD: Version defaults to ConfigMap value
        # Optional override parameter allows backward compatibility
```

**Benefits of this pattern:**
- Metadata loaded once at startup (no repeated JSON parsing)
- Comprehensive logging of what was loaded
- Fail-safe defaults if ConfigMap unavailable
- Optional override parameters for testing
- Type-safe Python access to metadata

## Version Update Workflow

**When a tool version changes (e.g., Slither 0.10.4 → 0.10.5):**

```bash
# 1. Update ConfigMap
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
vim k8s/base/scanner-versions-configmap.yaml

# Change:
#   "version": "0.10.4"
# To:
#   "version": "0.10.5"

# 2. Commit ConfigMap change
git add k8s/base/scanner-versions-configmap.yaml
git commit -m "feat: Update Slither scanner to v0.10.5

- Updated SCANNER_METADATA version for slither
- New version includes performance improvements
- Release notes: https://github.com/crytic/slither/releases/tag/0.10.5"

# 3. Apply ConfigMap to Kubernetes
kubectl apply -f k8s/base/scanner-versions-configmap.yaml

# 4. Restart API service to reload env vars
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 5. Verify version update
curl http://localhost:8000/api/v1/scanners | \
  jq '.scanners[] | select(.id=="slither") | {id, version, developer}'

# Expected output:
# {
#   "id": "slither",
#   "version": "0.10.5",
#   "developer": "Trail of Bits"
# }
```

**Total time:** ~2 minutes (vs ~15 minutes with code change + Docker rebuild)

**No Docker rebuild required!**

## Multi-Environment Support

**Use Kustomize overlays for environment-specific versions:**

**Base ConfigMap** (production-stable versions):

```yaml
# k8s/base/scanner-versions-configmap.yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.4",
        "developer": "Trail of Bits"
      }
    }
```

**Local Development Override** (latest versions for testing):

```yaml
# k8s/overlays/local/scanner-versions-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.5-dev",
        "developer": "Trail of Bits"
      }
    }
```

**Staging Override** (release candidates):

```yaml
# k8s/overlays/staging/scanner-versions-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.5-rc1",
        "developer": "Trail of Bits"
      }
    }
```

**Benefits:**
- Test new versions in local/staging before production
- Production always uses stable versions
- No code changes required across environments
- Git tracks version differences

## Monitoring and Validation

**RECOMMENDED:** Implement version validation to detect drift

**Pattern 1: Log Loaded Metadata**

```python
# At startup, log all loaded metadata
def _load_scanner_metadata_from_env() -> Dict[str, dict]:
    metadata_json = os.getenv("SCANNER_METADATA", "{}")
    try:
        metadata = json.loads(metadata_json)
        logger.info(f"Loaded metadata for {len(metadata)} scanners from ConfigMap")

        # Log summary for audit trail
        for scanner_id, meta in metadata.items():
            logger.info(f"  {scanner_id}: v{meta.get('version', 'unknown')} "
                       f"by {meta.get('developer', 'unknown')}")

        return metadata
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse SCANNER_METADATA env var: {e}")
        return {}
```

**Pattern 2: Health Check Endpoint**

```python
# Add metadata to health check response
@router.get("/health/metadata")
async def get_metadata():
    return {
        "scanners": {
            scanner_id: {
                "version": meta.version,
                "developer": meta.developer
            }
            for scanner_id, meta in SCANNERS.items()
        },
        "loaded_at": startup_time,
        "source": "scanner-versions ConfigMap"
    }
```

**Pattern 3: Alert on "unknown" Versions**

```python
# Monitor for fallback to "unknown" (indicates ConfigMap loading issue)
for scanner_id, meta in SCANNERS.items():
    if meta.version == "unknown" or meta.developer == "unknown":
        logger.error(f"Scanner {scanner_id} has unknown metadata - ConfigMap may not be loaded!")
        # Send alert to monitoring system
```

## Real-World Example: Scanner Metadata Refactoring

**Context:** Apogee Platform manages 21 security scanners across 5 blockchain languages

**Before (Anti-Pattern):**
```python
# 21 scanners with hardcoded versions in scanners.py
"slither": ScannerMetadata(
    id="slither",
    version="0.10.4",  # Hardcoded
    developer="Trail of Bits",  # Hardcoded
    # ...
),
# ... 20 more scanners
```

**After (ConfigMap Pattern):**
```yaml
# scanner-versions-configmap.yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {"version": "0.10.4", "developer": "Trail of Bits"},
      "mythril": {"version": "0.24.8", "developer": "ConsenSys"},
      "aderyn": {"version": "0.1.0", "developer": "Cyfrin"},
      # ... 18 more scanners
    }
```

```python
# scanners.py - NO hardcoded versions
"slither": ScannerMetadata(
    id="slither",
    name="Slither",
    description="Industry-standard static analysis",
    # version/developer auto-loaded from ConfigMap
),
```

**Results:**
- ✅ Version updates: 15 minutes → 2 minutes
- ✅ Single source of truth established
- ✅ Git tracks all version history
- ✅ Dashboard displays actual tool versions
- ✅ Zero code changes for version updates

**Documentation:** See `/Users/pwner/Git/ABS/docs/SCANNER-METADATA-REFACTORING-2025-10-18.md`

## Best Practices

**1. JSON Structure Standards:**

```json
{
  "tool-id": {
    "version": "MAJOR.MINOR.PATCH",
    "developer": "Organization Name",
    "release_date": "YYYY-MM-DD",
    "notes": "Optional release notes or warnings"
  }
}
```

**2. ConfigMap Naming:**
- Use descriptive names: `scanner-versions`, `tool-metadata`, `external-tool-config`
- Include purpose in name: `*-versions`, `*-metadata`, `*-config`

**3. JSON Validation:**
- Validate JSON at startup with comprehensive error handling
- Log parsing errors clearly
- Provide fail-safe defaults for missing fields

**4. Documentation Requirements:**
- Comment ConfigMap with usage instructions
- Document what services consume the ConfigMap
- Track version update history in commit messages

**5. Testing:**
```bash
# Test ConfigMap JSON is valid
kubectl get configmap scanner-versions -o jsonpath='{.data.SCANNER_METADATA}' | jq '.'

# Test application loads metadata correctly
kubectl logs deployment/api-service | grep "Loaded metadata"

# Test health endpoint shows correct versions
curl http://localhost:8000/api/v1/health/metadata | jq '.scanners'
```

## Two-Version Model: Tool Version vs Image Version

Scanner ConfigMaps track two independent version numbers:

| Concept | ConfigMap Key | Tracks | Example |
|---------|--------------|--------|---------|
| **Tool version** | `SCANNER_METADATA` → `"version"` | Version of the upstream scanner tool | slither `0.11.5` |
| **Image version** | `SCANNER_IMAGE_*` tag | Version of our Docker wrapper image | `scanner-slither:0.3.1` |

These are independent:
- **Bump image version** when: wrapper script changes, base image updates, dependency fixes
- **Bump tool version** when: upstream scanner releases a new version (requires image rebuild too)

**Both must use semantic versioning.** `SCANNER_IMAGE_*` tags are used directly by `KubernetesJobManager._get_scanner_image()` — Kubernetes pulls exactly what the ConfigMap specifies.

### Why Pin Image Tags

| | `:latest` | Pinned (e.g., `0.3.1`) |
|---|---|---|
| Reproducibility | Unknown which build ran | Exact build traceable |
| Stability | Rebuild silently changes what runs | Explicit ConfigMap update required |
| Audit trail | No version in Git history | Version change visible in Git diff |
| Rollback | Cannot roll back to previous build | Change ConfigMap tag to previous version |
| Harbor compatibility | Conflicts with immutable tag policy | Works with immutable tags |

### Pinning Third-Party Base Images

When a scanner Dockerfile uses a third-party base image, pin with **tag + digest**:

```dockerfile
# GOOD: Pinned to version tag AND SHA256 digest
ARG SEC3_XRAY_VERSION=v0.0.6
FROM ghcr.io/sec3-product/x-ray:${SEC3_XRAY_VERSION}@sha256:543dc6a984d4...

# BAD: Unpinned upstream image
FROM ghcr.io/sec3-product/x-ray:latest
```

The tag provides readability; the digest provides immutability. Even if upstream re-pushes the same tag with different content, the digest ensures the exact same image is used.

## When to Use This Pattern

**✅ MANDATORY for:**
- Third-party tool versions (scanners, analyzers, validators)
- External service versions (APIs, SDKs, libraries)
- Tool configuration that changes independently of code
- Metadata displayed to users (version numbers, developer names)
- Multi-environment version differences

**❌ NOT REQUIRED for:**
- Application version numbers (use Docker image tags)
- Code logic or business rules (belongs in code)
- Secrets or sensitive data (use Kubernetes Secrets + External Secrets)
- Data that changes per-request (use database)

## Checklist: Implementing ConfigMap Metadata Management

Before deploying tool metadata via ConfigMaps:

- [ ] **ConfigMap created** with valid JSON structure
- [ ] **Environment variable** added to deployment
- [ ] **Loading function** implemented with error handling
- [ ] **Logging** added for startup and errors
- [ ] **Fail-safe defaults** defined (e.g., "unknown")
- [ ] **Health endpoint** exposes loaded metadata
- [ ] **Documentation** updated with ConfigMap location
- [ ] **Testing** validates JSON parsing and loading
- [ ] **Monitoring** alerts on "unknown" values
- [ ] **Version update workflow** documented

After deployment:

- [ ] Verify ConfigMap exists: `kubectl get configmap -n <namespace>`
- [ ] Verify pod has env var: `kubectl describe pod <pod-name>`
- [ ] Check startup logs: `kubectl logs <pod-name> | grep metadata`
- [ ] Test health endpoint: `curl http://localhost:8000/health/metadata`
- [ ] Perform version update test (update ConfigMap, restart pod, verify)

## Common Issues and Troubleshooting

**Issue:** Pod shows `CreateContainerConfigError`

**Cause:** ConfigMap doesn't exist in pod's namespace

**Solution:**
```bash
# Check ConfigMap exists
kubectl get configmap scanner-versions -n <namespace>

# If missing, apply ConfigMap
kubectl apply -f k8s/base/scanner-versions-configmap.yaml -n <namespace>
```

**Issue:** Metadata shows "unknown" for all tools

**Cause:** Environment variable not mounted, JSON parsing failed, or ConfigMap empty

**Diagnosis:**
```bash
# Check pod has env var
kubectl describe pod -n <namespace> <pod-name> | grep SCANNER_METADATA

# Check ConfigMap content
kubectl get configmap scanner-versions -o jsonpath='{.data.SCANNER_METADATA}' | jq '.'

# Check pod logs for parsing errors
kubectl logs -n <namespace> <pod-name> | grep -i "metadata\|parse\|config"
```

**Issue:** Version update not reflected after ConfigMap change

**Cause:** Pods not restarted (environment variables loaded at container start)

**Solution:**
```bash
# Restart deployment to reload env vars
kubectl rollout restart deployment/<service-name> -n <namespace>
kubectl rollout status deployment/<service-name> -n <namespace>

# Verify new version
curl http://localhost:8000/api/v1/scanners | jq '.scanners[0].version'
```

---

**See Also:**
- [Dependency Management](./dependency-management.md) - Dependency versioning and management
- [Docker Image Versioning](./docker-image-versioning.md) - Application version management
- [Core Development Rules](./core-development-rules.md) - Development workflow rules
