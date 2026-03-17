# Seed Data Automation Workflow

**Last Updated:** March 2026
**Status:** Active

---

## Overview

The Apogee platform automatically seeds and maintains five categories of data that previously required manual scripts or SQL. All seeding runs on API service startup or via Celery Beat scheduled tasks.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SEED DATA AUTOMATION                                   │
│                                                                             │
│  STARTUP (api-service lifespan)          SCHEDULED (Celery Beat)            │
│  ─────────────────────────────           ───────────────────────            │
│  1. Vulnerability Patterns (397)         ML Model Freshness (02:00 UTC)     │
│  2. Exploits & CVEs (10+10)              Unmapped Pattern Sweep (03:00 UTC) │
│  3. Scanner Versions (16)                Post-scan Pattern Detection        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Startup Seeding (API Service)

Runs automatically on every pod start, after `init_db()`:

| Order | Service | Data Source | Records | Version Tracking |
|-------|---------|-------------|---------|-----------------|
| 1 | `pattern_seed_service` | `seeds/vulnerability_patterns.json` | 397 patterns + 678 mappings | `pattern_seed` |
| 2 | `exploit_cve_seed_service` | `seeds/exploits_and_cves.json` | 10 exploits + 10 CVEs | `exploit_cve_seed` |
| 3 | `scanner_version_seed_service` | `SCANNER_METADATA` env var | 16 scanners | `scanner_version_seed` |

All are idempotent and version-tracked via `ml_model_metadata`.

---

## Scheduled Automation (Celery Beat)

| Task | Schedule | Purpose |
|------|----------|---------|
| `ml.check_model_freshness` | 02:00 UTC daily | Detect never-trained or stale ML models, trigger retraining |
| `pattern.check_unmapped` | 03:00 UTC daily | Sweep for unmapped scanner detectors, create patterns |
| Post-scan hook | After each scan | Detect unmapped detectors from scan results |

---

## What Was Automated

| # | Mechanism | Before | After |
|---|-----------|--------|-------|
| 1 | ML Model Training | Never triggered automatically | Daily freshness check + label threshold + dashboard button |
| 2 | Scanner Pattern Detection | Manual K8s Job | Post-scan hook + daily Celery sweep |
| 3 | Vulnerability Patterns | Manual `seed_vulnerability_patterns.py` | Startup seeding from bundled JSON |
| 4 | Exploit & CVE Intelligence | Manual `seed_exploits_and_cves.py` | Startup seeding from bundled JSON |
| 5 | Scanner Version Tracking | Manual SQL inserts | Startup seeding from ConfigMap |

---

## Related Documentation

- [Startup Seed Pipeline](../pipelines/startup-seed-pipeline.md) — Technical pipeline details
- [Seed Data Operations Playbook](../playbooks/seed-data-operations.md) — Manual operations and troubleshooting
- [Pattern Auto-Detection Workflow](./pattern-autodetect-workflow.md) — Pattern detection details
- [ML Training Workflow](./ml-training-workflow.md) — ML model training automation
- [FP Training Pipeline](../pipelines/fp-training-pipeline.md) — ML training pipeline details
