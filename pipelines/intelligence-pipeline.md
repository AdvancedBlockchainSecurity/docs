# Intelligence Pipeline

Real-time per-scan pipeline that enriches raw scanner findings with normalization, fingerprinting, pattern classification, false positive prediction, and deduplication.

## Overview

```
Scan Complete              IntelligencePipelineService                 Database
─────────────              ───────────────────────────                 ────────
Raw findings →             1. Normalize scanner output                 vulnerabilities
                           2. Generate multi-dimensional fingerprints
                           3. Match to vulnerability pattern (BVD codes)
                           4. Predict false positive score
                           5. Build enriched vulnerability record
                    →      INSERT enriched findings
```

## Trigger

Runs automatically after each scan completes. Called from the scan result processing flow with the scan's raw findings.

## Pipeline Stages

| # | Stage | Service | Description |
|---|-------|---------|-------------|
| 1 | Normalization | `VulnerabilityNormalizer` | Convert scanner-specific output to unified `NormalizedFinding` format (title, severity, detector_id, SWC/CWE mapping) |
| 2 | Fingerprinting | `VulnerabilityFingerprinter` | Generate 5 fingerprint dimensions: `fingerprint_code`, `fingerprint_ast`, `fingerprint_location`, `fingerprint_location_fuzzy`, `fingerprint_semantic` |
| 3 | Pattern Classification | `PatternMatcher` | Match finding to vulnerability patterns via `pattern_tool_mappings`. Returns `pattern_id` + `classification_confidence` |
| 4 | FP Prediction | `FalsePositivePredictor` | Calculate `false_positive_score` (0.0-1.0) based on pattern history and scanner confidence |
| 5 | Enrichment | `_build_enriched_vulnerability()` | Assemble final vulnerability record with all intelligence fields for database insertion |

## Deduplication (Post-Insert)

After findings are stored, the `DeduplicationService` groups duplicates using 5-level matching:

| Level | Strategy | Fields | Precision |
|-------|----------|--------|-----------|
| 1 | EXACT | `fingerprint_code` + `fingerprint_location` | 99% |
| 2 | HIGH | `fingerprint_code` + `fingerprint_location_fuzzy` | 95% |
| 3 | MEDIUM | `fingerprint_ast` + `fingerprint_location_fuzzy` | 85% |
| 4 | LOW | `pattern_code` + `fingerprint_location_fuzzy` | 75% |
| 5 | SEMANTIC | ML embedding similarity | 80%+ |

All matching is scoped by `contract_id` + `detector_id` to prevent cross-type grouping.

## Data Flow

```
Raw Scanner Output
      │
      ▼
NormalizedFinding (scanner_id, detector_id, title, severity, confidence)
      │
      ▼
VulnerabilityFingerprint (5 hash dimensions)
      │
      ▼
Pattern Match (pattern_id, classification_confidence)
      │
      ▼
FP Score (false_positive_score: 0.0-1.0)
      │
      ▼
Enriched Vulnerability Dict → INSERT into vulnerabilities table
```

## Files

| File | Role |
|------|------|
| `blocksecops-api-service/src/application/services/intelligence_pipeline_service.py` | Main pipeline orchestrator (`IntelligencePipelineService`) |
| `blocksecops-api-service/src/domain/services/intelligence_service.py` | Domain services: `VulnerabilityNormalizer`, `VulnerabilityFingerprinter`, `PatternMatcher`, `FalsePositivePredictor` |
| `blocksecops-api-service/src/domain/services/deduplication_matcher.py` | 5-level `DeduplicationMatcher` |
| `blocksecops-api-service/src/ml/semantic_deduplicator.py` | Level 5 semantic embedding similarity |

## Error Handling

Each finding is processed independently. If a single finding fails any stage, it is logged and skipped — remaining findings continue processing.

## Database Tables

- `vulnerabilities` — enriched findings with intelligence columns (migration 006)
- `deduplication_groups` — groups of duplicate findings with canonical selection
- `vulnerability_patterns` — BVD pattern definitions
- `pattern_tool_mappings` — scanner detector → pattern mappings
