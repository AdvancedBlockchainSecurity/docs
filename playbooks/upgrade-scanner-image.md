# Playbook: Upgrade Scanner Image

**Version:** 1.2.0
**Last Updated:** February 5, 2026

## Overview

This playbook covers upgrading a scanner image in the BlockSecOps platform. Scanners have **dual versioning**: the upstream tool version and our scanner wrapper image version.

---

## Prerequisites

- [ ] Docker running locally
- [ ] kubectl configured for local cluster
- [ ] Harbor registry accessible at `harbor.blocksecops.local`
- [ ] Database backup created (if scanner has existing findings)
- [ ] Upstream release notes reviewed for breaking changes

---

## Quick Reference

```bash
# Full upgrade cycle
1. Create database backup (if needed)
2. Delete old findings (if clean slate preferred)
3. Update Dockerfile with new versions
4. Build image with --no-cache
5. Push to Harbor
6. Update ConfigMaps (base + overlay)
7. Apply and restart deployment
8. Verify scanner health
9. Run test scan
10. Seed patterns (if new detector types)
```

---

## Understanding Dual Versioning

Scanner images have two version numbers:

| Version Type | Example | Purpose |
|--------------|---------|---------|
| **Tool Version** | `1.10.3` | Upstream scanner release (e.g., SolidityDefend, Slither) |
| **Image Version** | `0.5.0` | Our wrapper image version for K8s deployment tracking |

### When to Increment Image Version

| Change | Increment | Example |
|--------|-----------|---------|
| Tool version upgrade | MINOR | `0.4.0` → `0.5.0` |
| Wrapper script fix | PATCH | `0.4.0` → `0.4.1` |
| Breaking wrapper changes | MAJOR | `0.4.0` → `1.0.0` |
| Base image update only | PATCH | `0.4.0` → `0.4.1` |

---

## Step 1: Pre-Upgrade Preparation

### Create Database Backup

```bash
# Port forward PostgreSQL if needed
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3

# Create backup
PGPASSWORD=postgres pg_dump \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  -F c \
  -f ~/backups/solidity_security_$(date +%Y%m%d_%H%M%S).dump
```

### Check Current Scanner State

```bash
# Check existing findings count
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT scanner_id, COUNT(*) FROM vulnerabilities WHERE scanner_id = '<SCANNER_ID>' GROUP BY scanner_id;"

# Check current scanner version in API
curl -s http://127.0.0.1:8000/api/v1/scanners/<SCANNER_ID> | jq '.version'
```

### Delete Old Findings (Optional - Clean Slate)

If you want to start fresh with the new scanner version:

```bash
# Delete findings for the scanner
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "DELETE FROM vulnerabilities WHERE scanner_id = '<SCANNER_ID>';"

# Recalculate scan counts
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "UPDATE scans SET
    high_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'high'),
    medium_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'medium'),
    low_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'low');"

# Clean deduplication groups
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "DELETE FROM deduplication_groups WHERE canonical_id NOT IN (SELECT id FROM vulnerabilities);"
```

---

## Step 2: Update Scanner Dockerfile

**Location:** `blocksecops-tool-integration/scanner-images/<scanner>/Dockerfile`

### Update Version Labels

```dockerfile
# Update image version (our internal versioning)
LABEL version="0.5.0"
LABEL scanner.image.version="0.5.0"

# Update tool version if upgrading upstream
LABEL scanner.tool.version="1.10.3"

# Update OCI labels
LABEL org.opencontainers.image.version="1.10.3"
```

### Update Git Clone Tag

```dockerfile
# Clone specific upstream version
RUN git clone --branch v1.10.3 --depth 1 https://github.com/BlockSecOps/<Scanner>.git .
```

### Verify Build Requirements

- Check if Rust/Node/Python version needs updating for new tool version
- Review upstream release notes for dependency changes
- Update base images if required

---

## Step 3: Build Scanner Image

**Per Docker Image Versioning Standard (v3.2.0):**

```bash
cd /home/pwner/Git/blocksecops-tool-integration/scanner-images/<scanner>

# CRITICAL: Always use --no-cache for production builds
docker build --no-cache \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/scanner-<scanner>:<IMAGE_VERSION> \
  .
```

### Build Tips

- Use `--no-cache` to ensure fresh build with latest dependencies
- Build can take 10-30 minutes for Rust-based scanners
- Monitor build output for compilation errors
- For large builds, consider using `docker build --progress=plain` for verbose output

---

## Step 4: Push to Harbor Registry

```bash
# Push to Harbor
docker push harbor.blocksecops.local/blocksecops/scanner-<scanner>:<IMAGE_VERSION>

# Verify push succeeded
curl -s https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories/scanner-<scanner>/artifacts \
  --insecure | jq '.[0].tags[].name'
```

---

## Step 5: Update ConfigMaps

### File 1: Base ConfigMap

**Location:** `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

Update the SCANNER_METADATA JSON:

```yaml
SCANNER_METADATA: |
  {
    "<scanner>": {
      "version": "<TOOL_VERSION>",
      "developer": "<Developer Name>",
      "_note": "Updated YYYY-MM-DD, <features>, scanner wrapper <IMAGE_VERSION>"
    }
  }

# Update base image reference
SCANNER_IMAGE_<SCANNER>: "scanner-<scanner>:<IMAGE_VERSION>"
```

### File 2: Local Overlay Patch

**Location:** `blocksecops-tool-integration/k8s/overlays/local/scanner-versions-patch.yaml`

```yaml
SCANNER_IMAGE_<SCANNER>: "harbor.blocksecops.local/blocksecops/scanner-<scanner>:<IMAGE_VERSION>"
```

---

## Step 6: Deploy Updated Scanner

```bash
# Apply ConfigMap changes
kubectl apply -k /home/pwner/Git/blocksecops-tool-integration/k8s/overlays/local/

# Restart tool-integration deployment to pick up new ConfigMap
kubectl rollout restart deployment/tool-integration -n tool-integration-local

# Wait for rollout
kubectl rollout status deployment/tool-integration -n tool-integration-local --timeout=120s

# Verify pod is running
kubectl get pods -n tool-integration-local -l app=tool-integration
```

---

## Step 7: Verify Scanner Health

```bash
# Check tool-integration logs for scanner registration
kubectl logs -n tool-integration-local deployment/tool-integration --tail=50 | grep -i "<scanner>"

# Verify scanner metadata via API
curl -s http://127.0.0.1:8000/api/v1/scanners/<scanner_id> | jq '.'

# Check scanner version matches
curl -s http://127.0.0.1:8000/api/v1/scanners/<scanner_id> | jq '.version'
```

---

## Step 8: Run Test Scan

```bash
# Find a test contract
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT id, name FROM contracts LIMIT 5;"

# Trigger scan via API
curl -X POST "http://127.0.0.1:8000/api/v1/scans" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"contract_id": "<CONTRACT_ID>", "scanner_ids": ["<scanner_id>"]}'

# Monitor scan progress
curl -s "http://127.0.0.1:8000/api/v1/scans/<SCAN_ID>" | jq '.status'

# Verify results in database
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT scanner_id, COUNT(*), MIN(detected_at), MAX(detected_at)
   FROM vulnerabilities
   WHERE scanner_id = '<scanner_id>'
   GROUP BY scanner_id;"
```

---

## Step 9: Seed Scanner Patterns (If Needed)

If the new version has new detector types:

```bash
cd /home/pwner/Git/blocksecops-api-service

# Dry-run first to see what patterns would be created
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <scanner_id> --dry-run

# Apply if needed
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <scanner_id> --apply
```

---

## Rollback Procedure

### Quick Rollback

```bash
# Rollback tool-integration deployment
kubectl rollout undo deployment/tool-integration -n tool-integration-local
```

### Rollback to Specific Version

```bash
# Revert ConfigMap to previous image version
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge -p '{"data":{"SCANNER_IMAGE_<SCANNER>":"harbor.blocksecops.local/blocksecops/scanner-<scanner>:<OLD_VERSION>"}}'

# Restart deployment
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

### Full Rollback with Database Restore

If you need to restore previous findings:

```bash
# Restore from backup
gunzip -c ~/backups/solidity_security_YYYYMMDD_HHMMSS.dump.gz | \
  PGPASSWORD=postgres pg_restore \
    -h 127.0.0.1 \
    -p 5432 \
    -U postgres \
    -d solidity_security \
    --no-owner \
    --no-acl \
    --clean \
    -v
```

---

## Troubleshooting

### Image Pull Failed

```bash
# Check pod events
kubectl describe pod -n tool-integration-local -l app=tool-integration | grep -A5 "Events:"

# Verify image exists in Harbor
docker pull harbor.blocksecops.local/blocksecops/scanner-<scanner>:<VERSION>

# Check Harbor credentials
kubectl get secret -n tool-integration-local harbor-registry-secret -o yaml
```

### Scanner Job Fails

```bash
# Check scanner job logs
kubectl get jobs -n tool-integration-local | grep <scanner>
kubectl logs job/<JOB_NAME> -n tool-integration-local

# Check scanner container directly
docker run --rm -it harbor.blocksecops.local/blocksecops/scanner-<scanner>:<VERSION> --help
```

### Version Mismatch

```bash
# Verify ConfigMap is correct
kubectl get configmap scanner-versions -n tool-integration-local -o yaml | grep <SCANNER>

# Force deployment restart
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

### Scanner Job Fails with JSON Parse Error (HTTP 500)

**Symptoms:** Scanner shows "Degraded" status with failed jobs. Job logs show:
```
ERROR: Failed to post results to callback URL (HTTP 500)
{"detail":"Expecting value: line 1 column 155 (char 154)"}
```

**Root Cause:** Scanner wrapper script generates invalid JSON when findings are empty. Common pattern:
```bash
# BUG: Returns empty string (not "0") when input is empty
"total_findings": $(echo "$FINDINGS" | jq 'length'),
# Produces: "total_findings": ,   <-- invalid JSON
```

**Fix Pattern:**
```bash
# 1. Guard against empty strings before jq validation
if [ -z "$FINDINGS" ] || ! echo "$FINDINGS" | jq empty 2>/dev/null; then
    FINDINGS="[]"
fi

# 2. Pre-compute counts with fallback
TOTAL_FINDINGS=$(echo "$FINDINGS" | jq 'length' 2>/dev/null || echo "0")
if [ -z "$TOTAL_FINDINGS" ]; then
    TOTAL_FINDINGS=0
fi

# 3. Use pre-computed variable in JSON output
"total_findings": $TOTAL_FINDINGS,
```

**Key Lesson:** `jq empty` on an empty string returns exit 0 (no error), and `jq 'length'` on empty string returns no output (not "0"). Always check `[ -z "$VAR" ]` before piping to jq.

**See:** [Semgrep JSON Fix (2026-02-05)](../changelogs/ADMIN-SYSTEM-FIXES-2026-02-05.md#issue-2-semgrep-degraded-status-json-generation-bug)

---

## Admin Dashboard Upgrade (Full Pipeline)

As of API Service v0.25.9, the Admin Dashboard "Upgrade" button runs the **full scanner upgrade pipeline** automatically: ConfigMap update, detector comparison, pattern seeding, and audit validation.

**Location:** Admin System → Security Scanners table → "Upgrade" button (shown when `latest_version ≠ version`)

**What this does:**
1. Updates `SCANNER_METADATA` version in the `scanner-versions` ConfigMap
2. Restarts the tool-integration deployment
3. Runs detector comparison (identifies new/changed/removed detectors)
4. Seeds patterns for unmapped vulnerabilities (creates BVD codes and mappings)
5. Runs audit validation (calculates coverage and health score)
6. Logs the action in the admin audit trail
7. Displays pipeline results in the confirmation dialog

**What this does NOT do:**
- Rebuild the Docker scanner image (Steps 2-4 of this playbook)
- Run deduplication maintenance (handled by daily CronJob at 2AM UTC)

**When to use:** Use the Admin Dashboard button after the Docker image has been rebuilt and pushed to Harbor. The button handles both metadata updates and database-side intelligence operations (detector comparison, pattern seeding, audit). For the full image rebuild + pipeline, follow Steps 1-8 of this playbook first, then click "Upgrade" in the Admin Dashboard.

**See:** [Scanner Upgrade Workflow](../workflows/scanner-upgrade-workflow.md) for full workflow details and [Scanner Upgrade Pipeline](../pipelines/scanner-upgrade-pipeline.md) for pipeline architecture.

---

## Full Upgrade Pipeline Scripts

After completing the image build and ConfigMap update (Steps 1-8), use these scripts for detector comparison and pattern seeding:

```bash
cd /home/pwner/Git/blocksecops-api-service

# Detector comparison (identify added/removed detectors)
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/upgrade_scanner.py --scanner <scanner_id> --new-version <version>

# Pattern seeding - dry-run first
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <scanner_id> --dry-run

# Pattern seeding - apply
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <scanner_id> --apply

# Audit validation
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/audit_scanner_upgrade.py --scanner <scanner_id>
```

Deduplication maintenance runs automatically via daily CronJob (2AM UTC).

---

## Checklist

- [ ] Database backup created (if existing findings)
- [ ] Old findings deleted (if clean slate preferred)
- [ ] Dockerfile updated with correct versions
- [ ] Image built
- [ ] Image pushed to Harbor registry
- [ ] Base ConfigMap updated (version + note)
- [ ] Local overlay patch updated
- [ ] Tool-integration deployment restarted
- [ ] Pod healthy (1/1 Ready)
- [ ] Test scan completes successfully
- [ ] New findings appear in database
- [ ] Detector comparison script run (if new version has detector changes)
- [ ] Pattern seeding runs without errors (if new detectors found)
- [ ] Audit validation passes
- [ ] Changes committed to Git

---

## Related Documentation

- [Scanner Upgrade Workflow](../workflows/scanner-upgrade-workflow.md) - Full automated pipeline overview
- [Docker Image Versioning Standards](../standards/docker-image-versioning.md)
- [Tool Metadata ConfigMaps Standard](../standards/tool-metadata-configmaps.md)
- [Docker Base Images Standard](../standards/docker-base-images.md)
- [Deploy New Image Playbook](deploy-new-image.md)
- [Database Management Standards](../standards/database-management.md)
- [Scanner Version Tracking Database](../database/SCANNER-VERSION-TRACKING.md)
