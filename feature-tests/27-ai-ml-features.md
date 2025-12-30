# 27. AI/ML Features Test Checklist

Phase 5 CPU-only ML features for intelligent vulnerability analysis.

**Implementation Date**: 2025-12-27
**Operating Cost**: ~$1/month (CPU-only, no LLM APIs, no GPU)

---

## Prerequisites

- [ ] ML dependencies installed (scikit-learn, sentence-transformers, numpy, joblib)
- [ ] API service running with ML endpoints enabled
- [ ] At least one completed scan with vulnerabilities

---

## 1. Risk Scoring

### 1.1 Contract Risk Score API

**Endpoint**: `GET /api/v1/ml/contracts/{id}/risk-score`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1.1.1 | Get risk score for contract with critical vulnerabilities | Score 80-100, level "CRITICAL" | [ ] |
| 1.1.2 | Get risk score for contract with high vulnerabilities | Score 60-79, level "HIGH" | [ ] |
| 1.1.3 | Get risk score for contract with medium vulnerabilities | Score 40-59, level "MEDIUM" | [ ] |
| 1.1.4 | Get risk score for contract with low/info only | Score 0-39, level "LOW" | [ ] |
| 1.1.5 | Get risk score for contract with no vulnerabilities | Score 0, level "LOW" | [ ] |

### 1.2 Scan Risk Score API

**Endpoint**: `GET /api/v1/ml/scans/{id}/risk-score`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1.2.1 | Get risk score for completed scan | Score 0-100, vulnerability breakdown | [ ] |
| 1.2.2 | Risk score includes severity breakdown | JSON has critical, high, medium, low, info counts | [ ] |
| 1.2.3 | Risk score includes adjustments | Array of adjustment strings | [ ] |

### 1.3 Risk Score Adjustments

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1.3.1 | Exploit pattern boosts score | +10 for EXPLOIT-* pattern | [ ] |
| 1.3.2 | High consensus boosts score | +5 for tool_consensus_score > 0.8 | [ ] |
| 1.3.3 | Low confidence reduces score | -10 when all findings < 0.5 confidence | [ ] |
| 1.3.4 | Test file reduces score | -15 when all findings in test/ files | [ ] |
| 1.3.5 | False positive reduces weight | Severity weight * (1 - fp_score) | [ ] |

---

## 2. Confidence Scoring

### 2.1 Confidence Calculation

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.1.1 | Confidence with all signals | Weighted avg of 4 signals | [ ] |
| 2.1.2 | Confidence with FP score only | Inverse FP at 40% weight | [ ] |
| 2.1.3 | Confidence with scanner confidence only | 20% weight | [ ] |
| 2.1.4 | Confidence with no signals | Returns 0.5 (50%) | [ ] |

### 2.2 Confidence Levels

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.2.1 | Score > 0.8 | Level "high" | [ ] |
| 2.2.2 | Score 0.5-0.8 | Level "medium" | [ ] |
| 2.2.3 | Score < 0.5 | Level "low" | [ ] |

---

## 3. Smart Prioritization

### 3.1 Prioritized Vulnerabilities API

**Endpoint**: `GET /api/v1/ml/scans/{id}/prioritized`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.1.1 | Get prioritized list for scan | Vulnerabilities sorted by priority_score | [ ] |
| 3.1.2 | Priority includes rank | rank = 1, 2, 3, ... | [ ] |
| 3.1.3 | Priority includes breakdown | base_severity, confidence_factor, fp_factor | [ ] |
| 3.1.4 | Critical severity ranks highest | Critical before high, high before medium | [ ] |

### 3.2 Top Priorities API

**Endpoint**: `GET /api/v1/ml/contracts/{id}/top-priorities`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.2.1 | Get top 10 priorities | Max 10 vulnerabilities | [ ] |
| 3.2.2 | Custom limit parameter | `?limit=5` returns 5 | [ ] |

### 3.3 Priority Levels

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.3.1 | Score >= 100 | Level "CRITICAL" | [ ] |
| 3.3.2 | Score 60-99 | Level "HIGH" | [ ] |
| 3.3.3 | Score 30-59 | Level "MEDIUM" | [ ] |
| 3.3.4 | Score < 30 | Level "LOW" | [ ] |

---

## 4. False Positive Detection

### 4.1 Model Status API

**Endpoint**: `GET /api/v1/ml/model-stats`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.1.1 | Get model stats (untrained) | is_trained: false | [ ] |
| 4.1.2 | Get model stats (trained) | is_trained: true, accuracy, auc | [ ] |

### 4.2 Labeling API

**Endpoint**: `POST /api/v1/ml/label-vulnerability`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.2.1 | Label as true positive | is_real_vulnerability: true | [ ] |
| 4.2.2 | Label as false positive | is_real_vulnerability: false | [ ] |
| 4.2.3 | Label with reason | reason field stored | [ ] |
| 4.2.4 | Label with confidence | confidence 0.0-1.0 | [ ] |

### 4.3 Training API

**Endpoint**: `POST /api/v1/ml/retrain`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.3.1 | Retrain with insufficient data | Error: need 200+ samples | [ ] |
| 4.3.2 | Retrain with force=true | Attempts with fewer samples | [ ] |
| 4.3.3 | Retrain with sufficient data | Returns accuracy, auc metrics | [ ] |

### 4.4 Prediction API

**Endpoint**: `POST /api/v1/ml/predict-false-positive`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.4.1 | Predict without trained model | Error: model not trained | [ ] |
| 4.4.2 | Predict with trained model | false_positive_probability 0-1 | [ ] |
| 4.4.3 | Prediction includes confidence | confidence 0-1 | [ ] |
| 4.4.4 | Prediction includes top features | Array of feature strings | [ ] |

---

## 5. Semantic Similarity

### 5.1 Similar Vulnerabilities API

**Endpoint**: `GET /api/v1/ml/vulnerabilities/{id}/similar`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 5.1.1 | Find similar vulnerabilities | List with similarity scores | [ ] |
| 5.1.2 | Custom threshold parameter | `?threshold=0.9` filters results | [ ] |
| 5.1.3 | Custom limit parameter | `?limit=5` limits results | [ ] |
| 5.1.4 | Similar includes severity | severity field in response | [ ] |
| 5.1.5 | Similar includes contract name | contract_name field | [ ] |

### 5.2 Embedding Generation

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 5.2.1 | Embedding from title only | 384-dim vector | [ ] |
| 5.2.2 | Embedding from title + description | 384-dim vector | [ ] |
| 5.2.3 | Embedding includes code snippet | Code context in embedding | [ ] |

---

## 6. Feature Extraction

### 6.1 Scanner Features (10 features)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 6.1.1 | scanner_id_hash | Consistent hash per scanner | [ ] |
| 6.1.2 | detector_id_hash | Hash of detector name | [ ] |
| 6.1.3 | scanner_confidence | 0.0-1.0 | [ ] |
| 6.1.4 | tool_consensus | 0.0-1.0 | [ ] |

### 6.2 Code Context Features (10 features)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 6.2.1 | visibility_level | public=1.0, external=0.75, internal=0.5, private=0.25 | [ ] |
| 6.2.2 | has_modifier | 0 or 1 | [ ] |
| 6.2.3 | nesting_depth | Count of { brackets | [ ] |
| 6.2.4 | in_test_file | 0 or 1 | [ ] |

### 6.3 Pattern Features (10 features)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 6.3.1 | severity_level | critical=4, high=3, medium=2, low=1, info=0 | [ ] |
| 6.3.2 | has_swc_id | SWC-xxx detection | [ ] |
| 6.3.3 | has_cwe_id | CWE-xxx detection | [ ] |
| 6.3.4 | has_remediation | Remediation text exists | [ ] |

---

## 7. Unit Tests

### 7.1 Test Execution

```bash
# Run all ML tests
cd /Users/pwner/Git/ABS/blocksecops-api-service
.venv/bin/pytest tests/unit/ml/ -v

# Run specific test file
.venv/bin/pytest tests/unit/ml/test_risk_scorer.py -v
.venv/bin/pytest tests/unit/ml/test_confidence_scorer.py -v
.venv/bin/pytest tests/unit/ml/test_prioritizer.py -v
.venv/bin/pytest tests/unit/ml/test_feature_extractor.py -v
.venv/bin/pytest tests/unit/ml/test_false_positive_classifier.py -v
.venv/bin/pytest tests/unit/ml/test_semantic_deduplicator.py -v
```

| # | Test File | Expected | Status |
|---|-----------|----------|--------|
| 7.1.1 | test_risk_scorer.py | All tests pass | [ ] |
| 7.1.2 | test_confidence_scorer.py | All tests pass | [ ] |
| 7.1.3 | test_prioritizer.py | All tests pass | [ ] |
| 7.1.4 | test_feature_extractor.py | All tests pass | [ ] |
| 7.1.5 | test_false_positive_classifier.py | All tests pass | [ ] |
| 7.1.6 | test_semantic_deduplicator.py | All tests pass | [ ] |

---

## 8. Performance

### 8.1 Latency Requirements

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 8.1.1 | Risk score calculation | < 50ms | [ ] |
| 8.1.2 | Confidence calculation | < 10ms | [ ] |
| 8.1.3 | Priority calculation (10 vulns) | < 100ms | [ ] |
| 8.1.4 | FP prediction (trained model) | < 100ms | [ ] |
| 8.1.5 | Embedding generation | < 50ms per vuln | [ ] |
| 8.1.6 | Similarity search (100 candidates) | < 200ms | [ ] |

---

## Notes

```
Testing Notes:
- FP classifier requires labeled training data (200+ samples)
- Semantic deduplication uses all-MiniLM-L6-v2 (80MB model)
- All ML features run on CPU only
- No external API calls needed (no LLM costs)
```

---

## Test Results

| Date | Tester | Result | Notes |
|------|--------|--------|-------|
| 2025-12-27 | Claude Code | PARTIAL | ML module implemented, endpoints registered, FP classifier needs training data |
