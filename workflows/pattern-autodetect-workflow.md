# Pattern Auto-Detection Workflow

**Last Updated:** March 2026
**Status:** Active

---

## Overview

When scanners detect vulnerabilities, each finding is matched to a known pattern via `pattern_tool_mappings`. If no mapping exists for a (scanner_id, detector_id) pair, the finding is stored with `pattern_code = NULL` — unclassified.

The pattern auto-detection workflow automatically creates patterns and mappings for unmapped detectors, eliminating the need to run `seed_scanner_patterns.py` manually.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PATTERN AUTO-DETECTION WORKFLOW                           │
│                                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐ │
│  │  Detect  │ → │  Infer   │ → │ Generate │ → │  Create  │ → │ Backfill │ │
│  │ Unmapped │   │ Category │   │   BVD    │   │ Pattern  │   │  Vuln    │ │
│  │ Detectors│   │ Severity │   │  Codes   │   │ Mappings │   │  Codes   │ │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘ │
│                                                                             │
│  Triggers:                                                                  │
│  - Post-scan hook (after each scan completes)                               │
│  - Daily Celery Beat sweep (03:00 UTC)                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Trigger Points

### 1. Post-Scan Hook

After every scan completes in the orchestration service (`scan_tasks_sync.py`), the `autodetect_patterns_task` fires asynchronously via `.delay()`. This is non-blocking — scan completion is never delayed.

**Scope**: Only the findings from the completed scan.

### 2. Daily Sweep (Celery Beat)

The `pattern.check_unmapped` task runs at **03:00 UTC daily**. It counts all vulnerabilities with `pattern_code IS NULL` across all scanners. If any exist, it dispatches `pattern.autodetect` to process them.

**Scope**: All unmapped findings across all scanners.

---

## Architecture

```
Orchestration Service                    API Service
┌──────────────────────┐                ┌──────────────────────┐
│ pattern.check_unmapped│                │ /internal/patterns/  │
│ (Beat: 03:00 UTC)    │───httpx POST──▶│ autodetect           │
│                      │                │                      │
│ pattern.autodetect   │                │ PatternAutoDetect    │
│ (post-scan hook)     │───httpx POST──▶│ Service              │
└──────────────────────┘                └──────────────────────┘
   Queue: ml-tasks                         Models:
   Auth: X-Internal-Service-Key            VulnerabilityPatternModel
   Serialization: JSON only                PatternToolMappingModel
```

---

## Detection Pipeline

### Step 1: Find Unmapped Detectors

Query `vulnerabilities` table where `pattern_code IS NULL`, grouped by `(scanner_id, title, category, severity)`. Generates a `detector_id` slug from the title.

### Step 2: Infer Category

Each detector name is matched against 14 category keyword lists:

| Category | Example Keywords |
|----------|-----------------|
| reentrancy | reentrancy, reentrant, callback |
| access-control | owner, admin, permission, role |
| arithmetic | overflow, underflow, division |
| unchecked-calls | unchecked, low-level, delegatecall |
| gas-optimization | gas, optimize, storage, cache |
| ... | (14 categories total) |

### Step 3: Infer Severity

Maps category to default severity, with keyword overrides:

| Category | Default Severity |
|----------|-----------------|
| reentrancy | critical |
| oracle-manipulation | critical |
| access-control | high |
| arithmetic | high |
| logic-errors | medium |
| best-practice | low |
| gas-optimization | info |

### Step 4: Generate BVD Code

Format: `BVD-SOL-{CATEGORY_PREFIX}-{SCANNER_SLUG}-{DETECTOR_SLUG}`

Example: `BVD-SOL-REE-SLI-REENTRANCY_ET`

### Step 5: Create Records

- `VulnerabilityPatternModel`: The pattern definition (category, severity, affected_languages)
- `PatternToolMappingModel`: Links scanner_id + detector_id to the pattern
- Skips if pattern or mapping already exists (idempotent)

### Step 6: Backfill

Updates `vulnerabilities.pattern_code` for previously-unclassified findings that now have matching mappings.

---

## Celery Task Configuration

| Task | Queue | Time Limit | Retries |
|------|-------|-----------|---------|
| `pattern.autodetect` | ml-tasks | 300s / 280s soft | 2 (30s delay) |
| `pattern.check_unmapped` | ml-tasks | 600s | 0 |

---

## Key Files

| File | Purpose |
|------|---------|
| `blocksecops-api-service/src/application/services/pattern_autodetect_service.py` | Core detection logic |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/ml.py` | Internal endpoint |
| `blocksecops-orchestration/src/.../tasks/pattern_tasks_sync.py` | Celery tasks |
| `blocksecops-orchestration/src/.../core/celery_app.py` | Beat schedule |
| `blocksecops-orchestration/src/.../tasks/scan_tasks_sync.py` | Post-scan hook |

---

## Monitoring

Check Celery logs for:
- `autodetect_patterns_started` — task fired
- `autodetect_patterns_completed` — task succeeded with counts
- `pattern_autodetect_trigger_failed` — post-scan hook failed (non-fatal)
- `check_unmapped_patterns_count` — daily sweep count
