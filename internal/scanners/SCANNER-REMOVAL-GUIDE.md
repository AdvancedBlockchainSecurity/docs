# Scanner Removal Guide

**Version:** 1.0.0
**Last Updated:** October 27, 2025
**Status:** Active Template

## Purpose

This is a **reusable template** for safely removing security scanners from the BlockSecOps platform. Follow this guide step-by-step to ensure clean removal without breaking existing functionality.

---

## Table of Contents

1. [Before You Begin](#before-you-begin)
2. [Removal Checklist](#removal-checklist)
3. [Step-by-Step Removal](#step-by-step-removal)
4. [Verification](#verification)
5. [Rollback Plan](#rollback-plan)

---

## Before You Begin

###  Prerequisites

- [ ] Confirm scanner is deprecated or no longer needed
- [ ] Check if scanner is actively used (query scan history)
- [ ] Communicate removal timeline to users
- [ ] Create feature branch: `git checkout -b feature/remove-<scanner-name>`
- [ ] Backup database (if removing pattern mappings)

### Impact Assessment

**Query scanner usage:**

```sql
-- Check how many scans use this scanner
SELECT
    scanner_id,
    COUNT(*) as scan_count,
    MAX(created_at) as last_used
FROM scans
WHERE scanner_id = '<scanner-id>'
GROUP BY scanner_id;

-- Check how many findings from this scanner
SELECT COUNT(*) as finding_count
FROM vulnerabilities
WHERE scanner_id = '<scanner-id>';
```

**Considerations:**
- If `scan_count > 0`: Historical data exists
- If `last_used` is recent: Users may still be using it
- If `finding_count > 0`: Findings will remain (safe to remove scanner)

---

## Removal Checklist

### Phase 1: Remove from API Service
- [ ] Remove scanner entry from `scanners.py`
- [ ] Add localStorage migration to dashboard
- [ ] Build and deploy API service

### Phase 2: Clean Up Orchestration
- [ ] Remove parser (optional, doesn't break anything)
- [ ] Remove Kubernetes job template (optional)
- [ ] Build and deploy orchestration service

### Phase 3: Clean Up ConfigMap
- [ ] Remove scanner metadata from `scanner-versions-configmap.yaml`
- [ ] Apply updated ConfigMap
- [ ] Restart affected services

### Phase 4: Clean Up Docker Images
- [ ] Remove scanner directory from `scanner-images/`
- [ ] (Optional) Remove images from registry

### Phase 5: Clean Up Pattern Mappings (Optional)
- [ ] Remove pattern mapping file (optional, historical data stays)
- [ ] Do NOT remove from database (preserves historical findings)

### Phase 6: Update Documentation
- [ ] Update CHANGELOG
- [ ] Update platform README
- [ ] Document removal reason

### Phase 7: Git Workflow
- [ ] Commit all changes to feature branch
- [ ] Create pull request
- [ ] Code review
- [ ] Merge to main

---

## Step-by-Step Removal

### Step 1: Remove from API Service (REQUIRED) ⚠️

**⚠️ CRITICAL**: This is the **most important step** - it removes the scanner from the UI.

**DO THIS FIRST** before any other steps! Even if you remove the scanner from ConfigMaps, Docker images, and infrastructure, the scanner will STILL appear in the UI if it's in `scanners.py`.

#### 1.1 Remove Scanner Entry

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
vim src/infrastructure/scanner_config/scanners.py
```

Delete the scanner entry from the `SCANNERS` dictionary:

```python
SCANNERS: Dict[str, ScannerMetadata] = {
    "slither": ScannerMetadata(...),
    # ... other scanners
    # REMOVE THIS:
    # "<scanner-id>": ScannerMetadata(...),
}
```

#### 1.2 Remove from Scanner Result Type Map

Remove the scanner from the result type mapping in the API service:

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
vim src/domain/entities/scan_result.py
```

Remove the scanner from `SCANNER_RESULT_TYPE_MAP`:

```python
SCANNER_RESULT_TYPE_MAP = {
    "slither": [ScanResultType.VULNERABILITY, ScanResultType.GAS_ANALYSIS],
    # REMOVE THIS:
    # "<scanner-id>": [ScanResultType.CODE_QUALITY],
}
```

#### 1.3 Update Dashboard Component Comments (Optional)

Search for scanner references in dashboard component documentation:

```bash
cd /Users/pwner/Git/ABS/blocksecops-dashboard
grep -r "<scanner-name>" src/components/
```

Update any component comments that reference the removed scanner:

```typescript
// Before:
/**
 * Displays gas analysis from Slither and 4naly3er
 */

// After:
/**
 * Displays gas analysis from Slither
 */
```

#### 1.4 Add Dashboard localStorage Migration

This ensures users who had the scanner selected don't see errors.

```bash
cd /Users/pwner/Git/ABS/blocksecops-dashboard
vim src/lib/storage/scannerPreferences.ts
```

Add migration function:

```typescript
/**
 * Remove deprecated scanner from user preferences
 * Scanner: <Scanner Name>
 * Removed: YYYY-MM-DD
 * Reason: <Reason for removal>
 */
function removeDeprecatedScanner_<SCANNER_ID>(): void {
  const preferences = getPreferences();
  const defaults = getDefaults();
  let changed = false;

  // Remove from project preferences
  Object.keys(preferences.projects).forEach((projectId) => {
    const project = preferences.projects[projectId];
    const originalLength = project.selectedScanners.length;

    project.selectedScanners = project.selectedScanners.filter(
      (scannerId) => scannerId !== '<scanner-id>'
    );

    if (project.configs['<scanner-id>']) {
      delete project.configs['<scanner-id>'];
      changed = true;
    }

    if (project.selectedScanners.length !== originalLength) {
      changed = true;
    }
  });

  // Remove from language defaults
  Object.keys(defaults.languages).forEach((language) => {
    const langDefaults = defaults.languages[language];
    const originalLength = langDefaults.selectedScanners.length;

    langDefaults.selectedScanners = langDefaults.selectedScanners.filter(
      (scannerId) => scannerId !== '<scanner-id>'
    );

    if (langDefaults.selectedScanners.length !== originalLength) {
      changed = true;
    }
  });

  if (changed) {
    setPreferences(preferences);
    setDefaults(defaults);
    console.log('Removed deprecated scanner: <scanner-id>');
  }
}

// Add to migratePreferences() function
export function migratePreferences(): void {
  removeDeprecatedScanner_<SCANNER_ID>();
  // ... existing migration code
}
```

#### 1.5 Build and Deploy API Service

**CRITICAL:** Always use `--no-cache` flag when building Docker images to prevent stale code.

```bash
# Determine new version (removing scanner = MINOR increment for pre-1.0)
# Example: 0.1.2 → 0.2.0

# Build new Docker image with --no-cache
cd /Users/pwner/Git/ABS/blocksecops-api-service
eval $(minikube docker-env)
docker build --no-cache -t api-service:0.2.0 .

# For local development, use kubectl set image (faster)
kubectl set image -n api-service-local deployment/api-service api-service=api-service:0.2.0

# Wait for rollout
kubectl rollout status -n api-service-local deployment/api-service

# Restart port-forward (pod was replaced)
lsof -ti:8000 | xargs kill -9 2>/dev/null
sleep 2
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
```

**For production deployments:**

```bash
# Update kustomization
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
vim k8s/overlays/production/api-service/kustomization.yaml
# Change newTag to 0.2.0 AND app.kubernetes.io/version to 0.2.0

# Deploy
kubectl apply -k k8s/overlays/production/api-service/
```

#### 1.6 Verify Scanner Removed from API ⚠️ REQUIRED

**STOP HERE** and verify before continuing to other cleanup steps!

```bash
# Should NOT return the removed scanner
curl http://localhost:8000/api/v1/scanners | jq '.scanners[] | select(.id=="<scanner-id>")'

# Expected: Empty (no output)

# Verify scanner count decreased
curl http://localhost:8000/api/v1/scanners | jq '.scanners | length'
# Expected: One less than before
```

**⚠️ If scanner STILL appears:**
1. Check that you edited `scanners.py` correctly
2. Rebuild with `--no-cache` flag: `docker build --no-cache`
3. Verify the new image tag is applied in kustomization.yaml
4. Restart port-forward: `kubectl port-forward -n api-service-local deployment/api-service 8000:8000`

**DO NOT proceed to Steps 2-6** until the scanner is gone from the API response.

---

### Step 2: Remove from ConfigMap (OPTIONAL but recommended)

```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
vim k8s/base/scanner-versions-configmap.yaml
```

Remove scanner metadata:

```yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.4",
        "developer": "Trail of Bits"
      },
      # REMOVE THIS:
      # "<scanner-id>": {
      #   "version": "...",
      #   "developer": "..."
      # }
    }
```

Apply changes:

```bash
kubectl apply -f k8s/base/scanner-versions-configmap.yaml
```

---

### Step 3: Remove Parser (OPTIONAL)

**Note:** Removing the parser is optional. It won't break anything if left in place.

```bash
cd /Users/pwner/Git/ABS/blocksecops-orchestration

# Remove parser file
rm src/parsers/<scanner_name>_parser.py

# Remove parser tests
rm tests/parsers/test_<scanner_name>_parser.py

# Remove from parser registry
vim src/parsers/__init__.py
# Delete the line:
# "<scanner-id>": <ScannerName>Parser(),
```

If you remove the parser, rebuild and redeploy orchestration:

```bash
# Build
docker build -t blocksecops-orchestration:0.7.<N+1> .
minikube image load blocksecops-orchestration:0.7.<N+1>

# Update kustomization
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
vim k8s/overlays/local/orchestration/kustomization.yaml
# Change newTag to 0.7.<N+1>

# Deploy
kubectl apply -k k8s/overlays/local/orchestration/
kubectl rollout restart deployment/orchestration -n orchestration-local
```

---

### Step 4: Remove Docker Image Directory (OPTIONAL)

```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images
rm -rf <scanner-name>/
```

**Note:** Historical Docker images in Minikube/registry are safe to leave. They don't consume significant resources.

---

### Step 5: Remove Pattern Mappings (OPTIONAL)

**Important:** Do NOT remove pattern mappings from the database. This preserves historical findings.

You can optionally remove the seed file:

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
rm seeds/<scanner>_pattern_mappings.json
```

Remove from seed script:

```bash
vim scripts/seed_vulnerability_patterns.py
# Comment out or remove the section that loads this scanner's mappings
```

**Why keep database mappings:**
- Historical findings reference these pattern codes
- Users may view old scan results
- Deduplication logic may query old findings
- No harm in leaving mappings in database

---

### Step 6: Update Documentation

#### Update CHANGELOG

```markdown
# CHANGELOG - <Service Name>

## [<MAJOR.MINOR.PATCH>] - YYYY-MM-DD

### Removed
- Removed <Scanner Name> v<version> scanner
- Removed <Scanner Name> parser and pattern mappings
- Cleaned up <Scanner Name> Docker image and configuration

### Reason for Removal
<Explain why scanner was removed, e.g.:>
- Scanner deprecated by upstream project
- Replaced by newer/better scanner
- Low usage/adoption
- Licensing issues

### Migration Path
<If users should migrate to another scanner, document it:>
- Users of <Old Scanner> should migrate to <New Scanner>
- <New Scanner> provides equivalent or better coverage
- Pattern codes remain compatible for deduplication

### Impact
- Historical scan results preserved
- Existing findings remain viewable
- Dashboard localStorage automatically cleaned up
```

#### Update Platform README

```bash
vim /Users/pwner/Git/ABS/README.md
# Update scanner count
# Remove scanner from feature lists
```

---

## Verification

### Verify 1: Scanner Not in API Response

```bash
curl http://localhost:8000/api/v1/scanners | \
  jq '.scanners[] | select(.id=="<scanner-id>")'
# Expected: Empty (no output)
```

### Verify 2: Dashboard Doesn't Show Scanner

1. Open browser to `http://127.0.0.1:3000`
2. Navigate to scan configuration page
3. Verify scanner does not appear in scanner selection list

### Verify 3: Hard Refresh Clears Cache

```bash
# In browser:
# 1. Open DevTools (F12)
# 2. Right-click refresh button
# 3. Select "Empty Cache and Hard Reload"
# 4. Verify scanner still not visible
```

### Verify 4: localStorage Cleaned Up

```javascript
// In browser DevTools console:
localStorage.getItem('scanner-preferences');
// Verify <scanner-id> is not in selectedScanners arrays
```

### Verify 5: Historical Findings Preserved

```sql
-- Verify old findings still exist
SELECT COUNT(*) FROM vulnerabilities WHERE scanner_id = '<scanner-id>';
-- Expected: Historical count (not 0 if scanner was used)

-- Verify findings are viewable
SELECT
    id,
    title,
    severity,
    created_at
FROM vulnerabilities
WHERE scanner_id = '<scanner-id>'
ORDER BY created_at DESC
LIMIT 5;
```

---

## Rollback Plan

If removal causes issues, rollback using Git:

### Rollback Step 1: Revert Code Changes

```bash
# Identify the commit that removed the scanner
git log --oneline --grep="<scanner-name>"

# Revert the removal commit
git revert <commit-hash>

# Or reset to before removal (if not pushed)
git reset --hard <commit-before-removal>
```

### Rollback Step 2: Rebuild and Redeploy

```bash
# Rebuild API service
cd /Users/pwner/Git/ABS/blocksecops-api-service
docker build -t api-service:0.3.<N+2> .
minikube image load api-service:0.3.<N+2>

# Update kustomization
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
vim k8s/overlays/local/api-service/kustomization.yaml
# Change newTag to 0.3.<N+2>

# Deploy
kubectl apply -k k8s/overlays/local/api-service/
kubectl rollout restart deployment/api-service -n api-service-local
```

### Rollback Step 3: Restore ConfigMap

```bash
# Revert ConfigMap changes
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
git checkout HEAD~1 k8s/base/scanner-versions-configmap.yaml

# Apply
kubectl apply -f k8s/base/scanner-versions-configmap.yaml
```

### Rollback Step 4: Verify Scanner Restored

```bash
curl http://localhost:8000/api/v1/scanners | \
  jq '.scanners[] | select(.id=="<scanner-id>")'
# Expected: Scanner appears again
```

---

## Common Questions

### Q: Will removing the scanner delete historical scan results?

**A:** No. Historical findings remain in the database. Users can still view old scan results.

### Q: Should I remove pattern mappings from the database?

**A:** No. Leave them in the database to preserve historical data integrity.

### Q: What if users have pending scans with this scanner?

**A:** Pending scans will fail gracefully. The scanner won't be available for new scans after removal.

### Q: Can I remove just the Docker image but keep the scanner in the API?

**A:** No. If the scanner is in the API, users expect it to work. Remove from API first.

### Q: How do I notify users about the removal?

**A:**
1. Add notice in dashboard UI (banner or modal)
2. Send email to active users
3. Update documentation with migration path
4. Provide 30-day deprecation period if possible

---

## Related Documentation

- [Platform Development Standards](/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md)
- [Scanner Integration Guide](/Users/pwner/Git/ABS/blocksecops-docs/SCANNER-INTEGRATION-GUIDE.md)
- [Scanner Update Guide](/Users/pwner/Git/ABS/blocksecops-docs/SCANNER-UPDATE-GUIDE.md)
- [Scanner Integration Management](/Users/pwner/Git/ABS/docs/architecture/SCANNER-INTEGRATION-MANAGEMENT.md)

---

**Document Owner:** Engineering Team
**Last Updated:** October 27, 2025
**Next Review:** Quarterly or when removing scanners
