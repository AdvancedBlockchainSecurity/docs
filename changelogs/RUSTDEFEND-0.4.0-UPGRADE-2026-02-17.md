# RustDefend v0.4.0 Upgrade Changelog

**Date:** 2026-02-17
**Previous Tool Version:** 0.3.1
**New Tool Version:** 0.4.0
**Previous Image Version:** 0.3.3
**New Image Version:** 0.4.0
**Upgrade Type:** FP-Heavy Clean Slate

---

## Summary

RustDefend v0.4.0 addresses two issues from v0.3.1:

1. **Title field support** -- v0.3.1 did not include a `title` field in its JSON output, causing the dashboard to display detector IDs (e.g., "SOL-002") as vulnerability names instead of human-readable titles (e.g., "Missing Owner Check").

2. **False positive fixes** -- Upstream FP fixes reduce false positive findings. Because old FP data would poison ML models and dedup groups, the FP-heavy clean-slate procedure was used to remove all prior RustDefend data before rescanning.

---

## Changes

### Callback Handler (`src/main.py`)

Single-line change to prefer the scanner's `title` field over the hardcoded `detector_names` dictionary:

```python
# Before:
title = detector_names.get(detector_id, detector_id.replace("-", " ").title())

# After:
title = finding.get("title") or detector_names.get(detector_id, detector_id.replace("-", " ").title())
```

The `detector_names` dict is retained as fallback for older RustDefend versions that don't emit `title`.

### Dockerfile

- Upstream tool version: 0.3.1 -> 0.4.0
- Scanner image version: 0.3.3 -> 0.4.0
- Git clone tag: v0.3.1 -> v0.4.0

### Version Locations (4 locations updated)

| Location | File | Change |
|----------|------|--------|
| KJM fallback | `src/scanners/kubernetes_job_manager.py` | `scanner-rustdefend:0.3.3` -> `0.4.0` |
| Base ConfigMap | `k8s/base/scanner-versions-configmap.yaml` | `scanner-rustdefend:0.3.3` -> `0.4.0`, metadata version `0.4.0` |
| Local overlay | `k8s/overlays/local/scanner-versions-patch.yaml` | Harbor path `0.3.3` -> `0.4.0` |
| Production overlay | `k8s/overlays/production/scanner-versions-patch.yaml` | GCP AR path `0.3.3` -> `0.4.0` |

---

## Clean Slate Procedure

Per `docs/pipelines/scanner-upgrade-pipeline.md#fp-heavy-scanner-upgrade-clean-slate`:

### Pre-cleanup Counts

| Type | Count |
|------|-------|
| Vulnerabilities | 0 |
| Scans (single-scanner) | 1 |
| Scans (multi-scanner) | 2 |
| Dedup groups (scanner canonical) | 0 |
| User labels | 0 |

### Steps Executed

1. Database backup created
2. Pre-cleanup counts recorded
3. Dedup groups ungrouped and deleted (0 affected)
4. Vulnerabilities deleted (0 affected)
5. Single-scanner scans deleted (1 deleted)
6. Empty multi-scanner scans deleted (0 deleted)
7. Multi-scanner scan severity counts recalculated (2 updated)
8. `rustdefend` removed from `scanners_used` arrays (2 updated)
9. Orphaned dedup groups cleaned (0 affected)
10. Dedup maintenance triggered
11. Verified zero rustdefend traces remain

### Post-cleanup Verification

| Check | Count |
|-------|-------|
| Scanner in scanners_used | 0 |
| Scanner vulnerabilities | 0 |
| Total scans | 432 |
| Total vulnerabilities | 3514 |
| Dedup groups | 823 |

---

## Documentation Updated

| File | Change |
|------|--------|
| `docs/standards/docker-image-versioning.md` | scanner-rustdefend 0.3.3 -> 0.4.0 |
| `docs/scanners/RustDefend/README.md` | Tool 0.3.1 -> 0.4.0, image 0.3.3 -> 0.4.0 |
| `docs/feature-tests/64-configmap-symlink-scanner-fix.md` | rustdefend 0.3.3 -> 0.4.0 |
| `docs/changelogs/RUSTDEFEND-0.1.0-INTEGRATION-2026-02-16.md` | Added v0.4.0 version history entry |
| `docs/changelogs/RUSTDEFEND-0.4.0-UPGRADE-2026-02-17.md` | This file |
