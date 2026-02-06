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

### 4.3 Training API (Admin Only)

**Endpoint**: `POST /api/v1/admin/system/ml/retrain` (requires `platform_admin` role)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.3.1 | Retrain with insufficient data | `success: false`, insufficient data message | [ ] |
| 4.3.2 | Retrain with force=true | Attempts with fewer samples (50+ min) | [ ] |
| 4.3.3 | Retrain with sufficient data | Returns accuracy, auc metrics, `success: true` | [ ] |
| 4.3.4 | Retrain as non-admin user | 403 Forbidden | [ ] |
| 4.3.5 | Retrain via legacy endpoint (`POST /ml/retrain`) | 403 for non-admin, deprecated warning | [ ] |
| 4.3.6 | Audit log entry created | `admin.ml.retrain` action logged | [ ] |

### 4.4 Prediction API

**Endpoint**: `POST /api/v1/ml/predict-false-positive`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.4.1 | Predict without trained model | Error: model not trained | [ ] |
| 4.4.2 | Predict with trained model | false_positive_probability 0-1 | [ ] |
| 4.4.3 | Prediction includes confidence | confidence 0-1 | [ ] |
| 4.4.4 | Prediction includes top features | Array of feature strings | [ ] |

### 4.5 Labeling Scripts

**Interactive CLI** (`scripts/label_vulnerabilities.py`):
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
python scripts/label_vulnerabilities.py --limit 50 --severity critical,high
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.5.1 | Interactive labeling session | Color-coded output, label prompts | [ ] |
| 4.5.2 | Export unlabeled to CSV | CSV file generated | [ ] |
| 4.5.3 | Filter by severity | Only matching severities shown | [ ] |
| 4.5.4 | Progress statistics | Shows labeled count, balance | [ ] |

**CSV Import** (`scripts/import_labels.py`):
```bash
python scripts/import_labels.py --file labeled_vulns.csv --dry-run
python scripts/import_labels.py --file labeled_vulns.csv
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.5.5 | Dry-run import | No changes, validation only | [ ] |
| 4.5.6 | Import valid CSV | Labels applied to database | [ ] |
| 4.5.7 | Invalid UUID handling | Skipped with warning | [ ] |
| 4.5.8 | Import statistics | Count of imported/skipped/errors | [ ] |

**Auto-Labeling** (`scripts/auto_label_vulnerabilities.py`):
```bash
python scripts/auto_label_vulnerabilities.py --dry-run
python scripts/auto_label_vulnerabilities.py --confidence 0.8
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.5.9 | Auto-label with heuristics | Applies labels based on patterns | [ ] |
| 4.5.10 | Minimum confidence filter | Only labels above threshold | [ ] |
| 4.5.11 | Test file detection | test/ files marked as FP | [ ] |
| 4.5.12 | Multi-scanner consensus | Higher confidence for multi-scanner | [ ] |

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

## 9. Model Training & Versioning

### 9.1 Training Requirements

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 9.1.1 | Training with < 50 samples | Error: insufficient data | [ ] |
| 9.1.2 | Training with 50-199 samples | Warning: suboptimal, proceeds | [ ] |
| 9.1.3 | Training with 200+ samples | Success, metrics returned | [ ] |
| 9.1.4 | Training with imbalanced data | Warning about class imbalance | [ ] |

### 9.2 Model Versioning

**Endpoint**: `GET /api/v1/ml/model-stats`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 9.2.1 | Get current model version | model_version string (v1, v2...) | [ ] |
| 9.2.2 | Model trained timestamp | ISO timestamp | [ ] |
| 9.2.3 | Model accuracy metric | 0.0-1.0 | [ ] |
| 9.2.4 | Model AUC metric | 0.0-1.0 | [ ] |
| 9.2.5 | Label counts | true_positive_count, false_positive_count | [ ] |

### 9.3 Model Storage

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 9.3.1 | Local storage save | Model saved to filesystem | [ ] |
| 9.3.2 | Local storage load | Model loaded from filesystem | [ ] |
| 9.3.3 | GCS storage save | Model uploaded to bucket | [ ] |
| 9.3.4 | GCS storage load | Model downloaded from bucket | [ ] |
| 9.3.5 | Storage backend config | ML_STORAGE_BACKEND env var | [ ] |

---

## 10. Background Tasks & Auto-Retraining

### 10.1 Label Threshold Triggers

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 10.1.1 | Labels below threshold | No retraining triggered | [ ] |
| 10.1.2 | Labels reach threshold | Background retraining starts | [ ] |
| 10.1.3 | Custom threshold config | ML_RETRAIN_THRESHOLD env var | [ ] |

### 10.2 Background Task Execution

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 10.2.1 | Async training task | Non-blocking execution | [ ] |
| 10.2.2 | Model update after training | New version available | [ ] |
| 10.2.3 | Metrics update after training | accuracy, auc updated | [ ] |

### 10.3 Model Freshness

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 10.3.1 | Fresh model (< 1 week) | is_stale: false | [ ] |
| 10.3.2 | Stale model (> 1 week) | is_stale: true | [ ] |
| 10.3.3 | Custom freshness config | ML_MODEL_MAX_AGE_DAYS env var | [ ] |

---

## Notes

```
Testing Notes:
- FP classifier requires labeled training data (200+ samples)
- Semantic deduplication uses all-MiniLM-L6-v2 (80MB model)
- All ML features run on CPU only
- No external API calls needed (no LLM costs)
```

## Architecture Update (January 26, 2026)

**ML Dependency Split:** Embedding generation moved from api-service to intelligence-engine.

| Component | Before | After |
|-----------|--------|-------|
| api-service | 12.6GB (included PyTorch) | 934MB (HTTP client only) |
| intelligence-engine | 3GB | 3GB (hosts embeddings endpoint) |

**Embeddings Endpoint:** `POST /api/v1/embeddings`
- Host: `intelligence-engine.intelligence-engine-local.svc.cluster.local:8000`
- Model: `all-MiniLM-L6-v2`
- Dimensions: 384

The api-service `semantic_deduplicator.py` now uses httpx to call the intelligence-engine instead of loading the model locally. This reduces api-service image size by 93%.

---

---

## 11. Frontend AI Features (Dashboard v0.32.0)

**Implementation Date**: 2026-01-29
**Dashboard Version**: 0.32.0

### 11.1 Navigation

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 11.1.1 | AI ASSISTANT section appears in sidebar | Shows robot icon with section title | [ ] |
| 11.1.2 | Security Copilot link | Navigates to `/copilot` | [ ] |
| 11.1.3 | Code Review link | Navigates to `/code-review` | [ ] |
| 11.1.4 | Code Repair link | Navigates to `/code-repair` | [ ] |
| 11.1.5 | Scanner Quality link under INTELLIGENCE | Navigates to `/intelligence/scanner-quality` | [ ] |

### 11.2 Scanner Quality Page (`/intelligence/scanner-quality`)

**Note:** As of Dashboard v0.39.0, the Retrain Model button has been removed from the user dashboard. Retraining is now admin-only via the Admin Portal at `admin.blocksecops.local/ml-models`.

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 11.2.1 | Page loads without errors | No console errors | [ ] |
| 11.2.2 | Quality gauges display | Shows Accuracy, AUC, CV AUC Mean gauges | [ ] |
| 11.2.3 | Training Data Stats card | Shows total samples, TP, FP counts | [ ] |
| 11.2.4 | Scanner Quality Table | Sortable table with scanner metrics | [ ] |
| 11.2.5 | No Retrain button present | Retrain removed from user dashboard (admin-only) | [ ] |
| 11.2.6 | Empty state message | Explains labeling needed, 10+ labels per scanner, links to vulnerability detail | [ ] |
| 11.2.7 | ModelStatusWidget is read-only | No retrain controls visible | [ ] |

### 11.3 AI Copilot (`/copilot`)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 11.3.1 | Chat interface renders | Message input, send button visible | [ ] |
| 11.3.2 | Preview banner displays | Shows AI preview warning | [ ] |
| 11.3.3 | Conversation list sidebar | Shows conversation history | [ ] |
| 11.3.4 | New conversation button | Creates new conversation | [ ] |
| 11.3.5 | Message input accepts text | Can type in input field | [ ] |
| 11.3.6 | Send button functional | Button responds to click | [ ] |
| 11.3.7 | Conversations List page | `/copilot/conversations` loads | [ ] |
| 11.3.8 | Conversation Detail page | `/copilot/conversations/:id` loads | [ ] |

### 11.4 Code Repair (`/code-repair`)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 11.4.1 | Page loads | Main repair page renders | [ ] |
| 11.4.2 | Filter buttons work | All, Ready, Applied, Rejected, Pending | [ ] |
| 11.4.3 | Empty state shows | "No repair suggestions" message | [ ] |
| 11.4.4 | "How Code Repair Works" section | 3-step explanation visible | [ ] |
| 11.4.5 | View History link | Navigates to `/code-repair/history` | [ ] |
| 11.4.6 | History page loads | `/code-repair/history` renders table | [ ] |
| 11.4.7 | Detail page loads | `/code-repair/:id` renders (with valid ID) | [ ] |
| 11.4.8 | Code diff component | Shows original vs repaired code | [ ] |

### 11.5 Code Review (`/code-review`)

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 11.5.1 | Page loads | Main review page renders | [ ] |
| 11.5.2 | Status filter buttons | All, Completed, In Progress, Pending, Failed | [ ] |
| 11.5.3 | Empty state shows | "No reviews found" message | [ ] |
| 11.5.4 | Stats cards area | Shows review statistics (when data exists) | [ ] |
| 11.5.5 | Suggestion Types section | Security, Gas, Best Practice, Code Quality | [ ] |
| 11.5.6 | View History link | Navigates to `/code-review/history` | [ ] |
| 11.5.7 | History page loads | `/code-review/history` renders table | [ ] |
| 11.5.8 | Detail page loads | `/code-review/:id` renders (with valid ID) | [ ] |

### 11.6 General UI Tests

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 11.6.1 | Dark mode styling | Glass-card, gradients consistent | [ ] |
| 11.6.2 | No console errors | Browser DevTools clean | [ ] |
| 11.6.3 | Responsive layout | Works on different screen sizes | [ ] |
| 11.6.4 | Back links work | Navigate to parent pages correctly | [ ] |
| 11.6.5 | Loading states | Skeleton/spinner shows during data fetch | [ ] |
| 11.6.6 | Error handling | Graceful error display on API failures | [ ] |

### 11.7 API Integration Notes

**Expected Behavior Without Backend:**
- API calls will return errors (503/404) - this is expected
- Pages should show empty states or error messages gracefully
- Preview banners warn users about AI preview mode

**New Routes Added:**
```
/copilot
/copilot/conversations
/copilot/conversations/:id
/code-repair
/code-repair/history
/code-repair/:id
/code-review
/code-review/history
/code-review/:id
/intelligence/scanner-quality
```

---

## Test Results

| Date | Tester | Result | Notes |
|------|--------|--------|-------|
| 2025-12-27 | - | PARTIAL | ML module implemented, endpoints registered |
| 2026-01-08 | - | PARTIAL | Added model training, labeling scripts, background tasks, model storage |
| 2026-01-26 | Claude Code | PARTIAL | ML dependency split complete - embeddings moved to intelligence-engine, api-service reduced from 12.6GB to 934MB |
| 2026-01-29 | Claude Code | PENDING | Frontend AI features added (v0.32.0) - Copilot, Code Repair, Code Review, Scanner Quality UI |
