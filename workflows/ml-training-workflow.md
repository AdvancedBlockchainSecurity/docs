# ML Training Workflow

**Last Updated:** March 2026
**Status:** Active

---

## Overview

The ML training workflow collects labeled vulnerability data and trains a Random Forest classifier to predict false positives. Training can be triggered automatically or manually.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ML TRAINING WORKFLOW                                 │
│                                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐ │
│  │  Label   │ → │ Collect  │ → │ Extract  │ → │  Train   │ → │  Deploy  │ │
│  │  Vulns   │   │ Training │   │ Features │   │  Model   │   │  Model   │ │
│  │          │   │   Data   │   │          │   │          │   │          │ │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘ │
│                                                                             │
│  Sources:                                                                   │
│  - UI Labeling Panel                                                        │
│  - API /ml/label-vulnerability                                              │
│  - Inline user_classification updates                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Model Architecture

| Aspect | Details |
|--------|---------|
| **Algorithm** | Random Forest Classifier |
| **Framework** | scikit-learn |
| **Features** | 30+ (scanner, code context, pattern) |
| **Output** | False positive probability (0.0-1.0) |
| **Requirements** | CPU-only (no GPU needed) |
| **Model Storage** | `$ML_MODEL_DIR/fp_classifier_v1.joblib` (default: `src/ml/models/`) |
| **K8s Model Dir** | `/app/.cache/ml-models` (writable `emptyDir` volume) |
| **Minimum Samples** | 50 (200+ recommended) |

---

## Training Data Collection

### Label Sources

Labels are collected from three sources (deduplicated):

| Source | Method | Location |
|--------|--------|----------|
| UI Labeling | VulnerabilityLabelingPanel submissions | Dashboard |
| API Labeling | `POST /api/v1/ml/label-vulnerability` | API |
| Inline Updates | Direct `user_classification` field | Database |

**Security:** The ML label endpoint verifies `contract.user_id == current_user.id` before allowing label saves. Secondary operations (provenance insert, scanner quality update, pattern FP update) use `db.begin_nested()` savepoints to prevent session corruption on partial failures.

### Label Values

| Classification | is_real_vulnerability | Description |
|----------------|----------------------|-------------|
| `confirmed` | `true` | Real vulnerability (true positive) |
| `false_positive` | `false` | Not a real vulnerability |

### API Labeling Endpoint

```bash
POST /api/v1/ml/label-vulnerability
Content-Type: application/json
Authorization: Bearer $TOKEN

{
  "vulnerability_id": "uuid-here",
  "is_real_vulnerability": true,
  "confidence": 0.9,
  "feedback": "Confirmed exploitable in production"
}
```

---

## Feature Extraction

The classifier uses 30+ features grouped into three categories:

### Scanner Features (10)

| Feature | Description |
|---------|-------------|
| `scanner_id` | One-hot encoded scanner identifier |
| `scanner_confidence` | Scanner's reported confidence |
| `consensus_score` | Agreement across multiple scanners |
| `has_dataflow_trace` | Whether dataflow analysis was used |
| `detector_fp_rate` | Historical FP rate for this detector |
| ... | ... |

### Code Context Features (10)

| Feature | Description |
|---------|-------------|
| `lines_of_code` | Affected code size |
| `function_visibility` | public/external/internal/private |
| `nesting_depth` | Control flow nesting level |
| `in_test_file` | Whether in test directory |
| `has_modifier` | Whether function has modifiers |
| ... | ... |

### Pattern Features (10)

| Feature | Description |
|---------|-------------|
| `pattern_severity` | BVD pattern severity |
| `pattern_fp_rate` | Historical FP rate for pattern |
| `has_cwe_mapping` | Whether CWE is assigned |
| `affected_lines_count` | Number of lines in finding |
| `has_recommendation` | Whether remediation exists |
| ... | ... |

**Location:** `src/ml/feature_extractor.py`

---

## Training Triggers

### Automatic Training

Training is triggered automatically in three ways:

1. **Label threshold**: When 100 new labels are added since last training, `schedule_model_retrain()` is called immediately via the API service.
2. **Daily freshness check**: Celery Beat task `ml.check_model_freshness` runs at **02:00 UTC daily**. If the model has never been trained (and sufficient data exists) or is older than 7 days, it triggers retraining via the orchestration service.
3. **Post-label counting**: The `LabelCounter` in `ml_model_metadata` tracks labels since last training and triggers retrain when `ML_RETRAIN_THRESHOLD` (default: 100) is reached.

The daily freshness check is critical for **initial training** — when the model has never been trained but labeled data exists (e.g., 385 samples from historical labeling), the freshness check detects this and triggers the first training automatically.

### Manual Training (Admin Only)

As of API Service v0.26.0, model retraining is an **admin-only operation** performed via the Admin Portal or the admin API endpoint.

**Admin Portal UI:**

Navigate to `admin.0xapogee.com/ml-models` and click **Retrain Model**.

**Admin API Endpoint:**

```bash
POST /api/v1/admin/system/ml/retrain
Content-Type: application/json
Authorization: Bearer $ADMIN_TOKEN

{
  "min_samples": 200,
  "force": false
}
```

Parameters:
- `min_samples`: Minimum required samples (default: 200, minimum: 50)
- `force`: Override minimum sample check (still requires 50)

Requires `platform_admin` role. All retrain attempts are recorded in the admin audit log.

**Legacy Endpoint (Deprecated):**

```bash
POST /api/v1/ml/retrain  # Deprecated in v0.26.0
```

This endpoint now requires `platform_admin` role. Use the admin endpoint above instead.

---

## Training Process

### Step 1: Collect Training Data

```python
# Gather all labeled vulnerabilities
labeled_vulns = await db.execute(
    select(VulnerabilityModel)
    .where(VulnerabilityModel.user_classification.isnot(None))
)
```

### Step 2: Extract Features

```python
features = []
labels = []

for vuln in labeled_vulns:
    feature_vector = feature_extractor.extract(vuln)
    features.append(feature_vector)
    labels.append(1 if vuln.user_classification == "false_positive" else 0)
```

### Step 3: Train Model

```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import cross_val_score

# Train with cross-validation
model = RandomForestClassifier(
    n_estimators=100,
    max_depth=10,
    random_state=42
)

# Cross-validation for evaluation
cv_scores = cross_val_score(model, X, y, cv=5, scoring='roc_auc')

# Final training on all data
model.fit(X, y)
```

### Step 4: Store Model

```python
# Local storage
joblib.dump(model, "src/ml/models/fp_classifier_v1.joblib")

# Or GCS storage (production)
gcs_storage.save_model(model, f"models/fp_classifier_v{version}.joblib")
```

**Location:** `src/ml/false_positive_classifier.py`

---

## Model Evaluation

### Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| Accuracy | > 70% | Overall correct predictions |
| AUC-ROC | > 70% | Discrimination ability |
| CV AUC Mean | Close to AUC | Generalization quality |
| CV AUC Std | < 0.05 | Stability across folds |

### Check Training Status

```bash
GET /api/v1/ml/model-stats
Authorization: Bearer $TOKEN
```

Response:
```json
{
  "model_version": "1.0.0",
  "trained_at": "2026-02-04T12:00:00Z",
  "is_trained": true,
  "samples_count": 200,
  "accuracy": 0.85,
  "auc": 0.89,
  "cv_auc_mean": 0.87,
  "cv_auc_std": 0.02,
  "true_positive_count": 120,
  "false_positive_count": 80
}
```

### Check Training Data Readiness

```bash
GET /api/v1/ml/training-data-stats
Authorization: Bearer $TOKEN
```

Response:
```json
{
  "total_samples": 150,
  "confirmed_count": 85,
  "false_positive_count": 65,
  "is_ready_for_training": true,
  "is_recommended_for_training": false,
  "message": "Ready for training. 50 more samples recommended."
}
```

---

## Prediction Flow

Once trained, the model predicts FP probability for new vulnerabilities:

```
New Vulnerability
      │
      ▼
┌─────────────────┐
│ Extract         │  30+ features from vulnerability
│ Features        │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Load Model      │  Cached in memory (lazy loaded)
│                 │
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Predict         │  model.predict_proba(features)
│                 │
└─────────────────┘
      │
      ▼
false_positive_score: 0.23
confidence: 0.87
```

### Prediction API

```bash
POST /api/v1/ml/predict-false-positive
Content-Type: application/json
Authorization: Bearer $TOKEN

{
  "vulnerability_id": "uuid-here"
}
```

Response:
```json
{
  "vulnerability_id": "uuid-here",
  "false_positive_probability": 0.23,
  "confidence": 0.87,
  "top_features": ["scanner_confidence", "has_dataflow_trace", "pattern_fp_rate"],
  "model_version": "1.0.0"
}
```

### Score Interpretation

| Score Range | Interpretation | Recommended Action |
|-------------|----------------|-------------------|
| 0.0 - 0.3 | Likely real vulnerability | Review and fix |
| 0.3 - 0.6 | Uncertain | Manual review needed |
| 0.6 - 1.0 | Likely false positive | Lower priority |

---

## Model Storage

| Environment | Backend | Location |
|-------------|---------|----------|
| Local Dev | local | `src/ml/models/fp_classifier_v1.joblib` |
| Production | gcs | `gs://blocksecops-ml-models/models/` |

### Configuration

```bash
# Environment variables
ML_STORAGE_BACKEND=local  # or gcs
ML_GCS_BUCKET=blocksecops-ml-models
FP_CLASSIFIER_MIN_SAMPLES=50
FP_CLASSIFIER_AUTO_RETRAIN_THRESHOLD=100
```

---

## Scanner Quality Tracking

Labels also feed into scanner quality metrics:

```bash
GET /api/v1/ml/scanner-quality
Authorization: Bearer $TOKEN
```

Response:
```json
{
  "scanners": [
    {
      "scanner_id": "slither",
      "total_findings": 500,
      "confirmed_count": 400,
      "false_positive_count": 100,
      "fp_rate": 0.20,
      "precision": 0.80
    },
    {
      "scanner_id": "mythril",
      "total_findings": 300,
      "confirmed_count": 200,
      "false_positive_count": 100,
      "fp_rate": 0.33,
      "precision": 0.67
    }
  ]
}
```

---

## Troubleshooting

### "Not enough samples to train"

Need 50+ labeled vulnerabilities:
```bash
# Check current count
curl -s http://127.0.0.1:8000/api/v1/ml/training-data-stats \
  -H "Authorization: Bearer $TOKEN" | jq

# Label more via UI or API
```

### Model not improving

1. Check label balance (need both confirmed and FP)
2. Add more diverse samples
3. Check for labeling inconsistencies

### Predictions all similar

1. Model may be undertrained
2. Add 50+ more samples and retrain
3. Check feature extraction logs

### Label save failures (session corruption)

The ML label endpoint uses `db.begin_nested()` savepoints for secondary operations. If a provenance insert or scanner quality update fails, only that savepoint is rolled back — the primary label save remains intact.

---

## Related Documentation

- [Intelligence Pipeline Workflow](./intelligence-pipeline-workflow.md)
- [Deduplication Workflow](./deduplication-workflow.md)
- [ML Model Retraining Playbook](../playbooks/ml-model-retraining.md)
- [FP Training Pipeline](../pipelines/fp-training-pipeline.md)
- [ML Development Standards](../standards/ml-development.md)
