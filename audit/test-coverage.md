# Test Coverage Audit — 2026-03-13

## Services

| Service | Tests | Threshold | CI |
|---------|-------|-----------|-----|
| api-service | 650+ | 80% | active |
| tool-integration | 200+ | — | commented |
| orchestration | 150+ | — | — |
| contract-parser | 12 | — | commented |
| intelligence-engine | 40 | 70% | commented |
| data-service | 57 | 70% | commented |
| notification | 61 | 60% | commented |
| shared (Rust) | 39 | — | commented |
| shared (Python) | 57 | 70% | commented |
| shared (TypeScript) | 10 | — | commented |
| dashboard | 20 | — | — |
| admin-portal | 15 | — | — |
| cli | 30 | — | — |
| SolidityDefend | 300+ | — | active |

## ML/AI

| Component | Tests |
|-----------|-------|
| FP Classifier (train/predict/batch) | 18 |
| Feature Extractor (30+ features) | 18 |
| Confidence Scorer (4-signal weighted) | 14 |
| Semantic Deduplicator (embed/cosine/retry) | 42 |
| ML Data Models (labels/weights/decay) | 24 |
| Label Counter (threshold trigger) | 11 |
| FP Training Collector | 10 |
| Multi-Class Classifier (4-class) | 7 |
| Prioritizer | 21 |
| Risk Scorer | 20 |
| Exploit Generator | 22 |
| Invariant Generator | 37 |

## Intelligence Pipeline

| Stage | Tests |
|-------|-------|
| Normalizer (Slither/Mythril/Aderyn/Generic) | 4 |
| Fingerprinter (code/AST/location/fuzzy/semantic) | 6 |
| Pattern Matcher (exact/Levenshtein/TF-IDF) | 3 |
| FP Predictor (multi-factor) | 3 |
| Full 5-stage integration | 3 |
| Deduplication groups | 2 |

## Deduplication

| Component | Tests |
|-----------|-------|
| 5-tier matcher | 26 |
| Data model | 26 |
| Multi-level matching | 35 |
| Stability | 14 |
| Maintenance | 50 |
| Pipeline regression | 5 |
| Celery tasks | 28 |
| Scanner quality tracker | 11 |
| Pattern FP aggregator | 7 |

## Security (BSO-SEC)

| Control | Tests |
|---------|-------|
| Prompt injection detection (23 patterns) — BSO-SEC-017/018 | 31 |
| AI output validation (review) — BSO-SEC-AI-002 | 8 |
| AI output validation (repair, dangerous patterns) — BSO-SEC-AI-002 | 9 |
| Retrain auth + JSON-only — BSO-SEC-004 | 2 |
| Implicit label service (training feedback) | 10 |
| Background retrain orchestration | 9 |

## Contract Tests

| Boundary | Tests |
|----------|-------|
| API -> Intelligence Engine (embedding schema) | 4 |
| Tool Integration -> API (result format) | 5 |
| Shared lib cross-language (Rust/Python consistency) | 8 |

## Training Feedback Loop

| Stage | Tests |
|-------|-------|
| Status -> label mapping | 10 |
| Source weights + temporal decay | 5 |
| Label counter (100 threshold) | 11 |
| Retrain orchestration (HTTP + asyncio fallback) | 9 |
| Model train/predict cycle | 18 |
| Active learning uncertainty | 4 |

## Transport Security

- In-cluster: HTTP + NetworkPolicies (explicit allow-lists)
- External APIs: HTTPS, default cert verification
- Production Redis: `rediss://` (TLS)
- Production PostgreSQL: `hostssl` enforced, `hostnossl` rejected
- Service auth: `secrets.compare_digest()` (constant-time)
- Model serialization: signed joblib (BSO-SEC-DESER-001)

## CI Workflows

Commented out (`workflow_dispatch` only). Enable when GitOps workflow established. Thresholds enforced via `--cov-fail-under` in CI.

## Frameworks

| Lang | Framework |
|------|-----------|
| Python | pytest, pytest-asyncio |
| Rust | cargo test |
| TypeScript | Vitest, Jest |
