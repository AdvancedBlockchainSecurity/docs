# Playbook: Deduplication Maintenance

**Version:** 1.0.0
**Last Updated:** February 23, 2026
**Audience:** Platform Operator | Developer

## Overview

Monitor and troubleshoot the hybrid deduplication maintenance system. Deduplication runs via two paths:

1. **Inline post-scan** — 4 scoped tasks run automatically during scan result ingestion (sub-second)
2. **Weekly CronJob** — Full 18-task sweep runs Sunday 2 AM UTC

---

## Prerequisites

- [ ] `kubectl` access to `api-service-local` namespace
- [ ] API service running (v0.29.11+)

---

## Workflow Diagram

```mermaid
flowchart TD
    A[Scanner Results Stored] --> B[Phase 1: Intra-Scan Dedup]
    B --> C[Phase 2: Cross-Scan Dedup]
    C --> D[Phase 3: Inline Maintenance]
    D --> D1[Fuzzy Fingerprints scan-scoped]
    D --> D2[Semantic Fingerprints scan-scoped]
    D --> D3[Tool Consensus contract-scoped]
    D --> D4[Orphan Grouping contract-scoped]
    D1 & D2 & D3 & D4 --> E[API Response Returns]

    F[Weekly CronJob Sun 2AM] --> G[Full 18-Task Sweep]
    G --> H[Cleanup + All Fingerprints]
    H --> I[Grouping + Analytics]
    I --> J[ML Feedback Loop]
```

---

## Monitoring the Inline Path

### Verify inline dedup runs after a scan

After uploading a contract and receiving scan results:

```sql
-- Check that new vulnerabilities have fingerprints
SELECT title, severity,
       fingerprint_location_fuzzy IS NOT NULL as has_fuzzy,
       fingerprint_semantic IS NOT NULL as has_semantic,
       tool_consensus_score,
       deduplication_group_id IS NOT NULL as has_group
FROM vulnerabilities
WHERE scan_id = '<scan-uuid>'
ORDER BY severity;
```

**Expected:** All rows should have `has_fuzzy = true` and `has_semantic = true`.

### Check API logs for inline processing

```bash
kubectl logs -n api-service-local deploy/api-service --tail=100 | \
  grep -i "post-scan\|maintenance completed"
```

---

## Monitoring the Weekly CronJob

### Check CronJob status

```bash
# CronJob schedule and last run
kubectl get cronjob -n api-service-local

# Recent jobs
kubectl get jobs -n api-service-local | grep dedup

# Job logs
kubectl logs -n api-service-local job/<job-name> --tail=50
```

### Manual trigger (for testing)

```bash
kubectl create job --from=cronjob/deduplication-maintenance \
  dedup-manual-$(date +%s) -n api-service-local
```

### Verify CronJob configuration

```bash
# Should show: schedule "0 2 * * 0", --weekly flag, v0.29.11 image
kubectl get cronjob deduplication-maintenance -n api-service-local -o yaml | \
  grep -E "schedule|image|command|activeDeadline"
```

---

## Troubleshooting

### Findings missing fingerprints after scan

1. Check if Phase 3 ran (look for errors in logs):
   ```bash
   kubectl logs -n api-service-local deploy/api-service --tail=200 | \
     grep -i "warning.*post-scan\|error.*dedup"
   ```

2. Check Intelligence Engine is running (required for semantic fingerprints):
   ```bash
   kubectl get pods -n intelligence-engine-local
   ```

3. Manual fix — trigger the weekly job to backfill:
   ```bash
   kubectl create job --from=cronjob/deduplication-maintenance \
     dedup-backfill-$(date +%s) -n api-service-local
   ```

### CronJob not running

1. Check schedule:
   ```bash
   kubectl get cronjob -n api-service-local
   ```

2. Check for failed jobs:
   ```bash
   kubectl get jobs -n api-service-local --field-selector status.successful=0
   ```

3. Check `concurrencyPolicy: Forbid` isn't blocking (previous job still running):
   ```bash
   kubectl get jobs -n api-service-local | grep dedup | grep -v Completed
   ```

### CronJob exceeds deadline

The weekly full sweep processes all 6,300+ vulnerabilities. If it exceeds the 2-hour deadline:

1. Check for slow tasks in job logs
2. Consider if data volume has grown significantly
3. The inline path handles new data — the weekly sweep is for maintenance only

---

## CLI Interface

```bash
# From inside the pod or locally with correct DATABASE_URL:

# Weekly housekeeping (what the CronJob runs)
python -m src.infrastructure.tasks.deduplication_maintenance --weekly

# Post-scan for specific scan (manual testing)
python -m src.infrastructure.tasks.deduplication_maintenance \
  --scan-id <scan-uuid> --contract-id <contract-uuid>

# Full sweep (legacy default)
python -m src.infrastructure.tasks.deduplication_maintenance
```

---

## Checklist

- [ ] Inline path: New scan findings have fingerprints immediately
- [ ] Weekly CronJob: Scheduled `0 2 * * 0` with `--weekly` flag
- [ ] CronJob image matches api-service image version
- [ ] Intelligence Engine running (for semantic fingerprints)
- [ ] No stale/stuck jobs blocking CronJob

---

## Related Playbooks

- [Deploy New Image](deploy-new-image.md)
- [AI/ML Comprehensive Audit](ai-ml-audit-playbook.md)
- [Scanner Pipeline Troubleshooting](scanner-pipeline-troubleshooting.md)
