# FP Training Pipeline

Collects labeled vulnerability data from multiple sources, validates and deduplicates it, extracts features, trains a Random Forest classifier, and persists the model.

## Overview

```
Label Sources                FPTrainingDataCollector       FalsePositiveClassifier
──────────────               ──────────────────────        ───────────────────────
Annotations        →         1. Collect from annotations   4. Extract 30+ features
Classifications    →         2. Collect from classifications 5. Train/test split (80/20)
Inline labels      →         3. Deduplicate by vuln_id     6. Train RandomForest
                                                           7. Evaluate (accuracy, AUC, CV)
                                                           8. Save model to storage
                                                  →        fp_classifier_v1.joblib
```

## Trigger

- **Admin Portal**: Platform admin clicks "Retrain Model" at `POST /admin/system/ml/retrain`
- **Auto-trigger**: When new labels push count over training threshold (50 min, 200 recommended)
- **Legacy endpoint**: `POST /ml/retrain` (deprecated, requires platform_admin role)

## Pipeline Phases

### Phase 1: Data Collection

| # | Step | Source | Description |
|---|------|--------|-------------|
| 1 | Collect annotations | `VulnerabilityAnnotationModel` | User annotations with status: `confirmed`, `false_positive`, `wont_fix` |
| 2 | Collect classifications | `VulnerabilityClassificationModel` | Explicit classifications (latest only, `is_latest == True`) |
| 3 | Collect inline labels | `VulnerabilityModel.user_classification` | Inline labels: `confirmed`, `false_positive` |
| 4 | Include soft-deleted | All sources | Soft-deleted vulnerabilities are included (labels preserved when contracts deleted) |
| 5 | Deduplicate | By `vulnerability_id` | Keep one label per vulnerability (first seen wins) |

### Phase 2: Feature Extraction

The `FeatureExtractor` produces 30+ features from each vulnerability:

| Category | Features | Description |
|----------|----------|-------------|
| Scanner | `scanner_id`, `detector_id` | Source scanner and detector identifier |
| Severity | `severity` | Vulnerability severity level |
| Confidence | `confidence`, `classification_confidence` | Scanner and classification confidence scores |
| Code | `code_snippet` | Source code context (hashed/vectorized) |
| Pattern | `pattern_code` | BVD pattern classification |
| Consensus | `tool_consensus_score` | Cross-scanner agreement score |
| Context | `file_path`, `description` | File location and description features |

### Phase 3: Model Training

| Step | Description |
|------|-------------|
| Split | 80/20 train/test split with stratification |
| Train | `RandomForestClassifier(n_estimators=100, max_depth=10, class_weight="balanced")` |
| Evaluate | Accuracy, AUC, 5-fold cross-validation AUC |
| Save | Persist to storage backend (local filesystem or GCS) |

### Phase 4: Model Persistence

| Backend | Location | Config |
|---------|----------|--------|
| Local (default) | `src/ml/models/fp_classifier_v1.joblib` | `ML_STORAGE_BACKEND=local` |
| GCS | Google Cloud Storage bucket | `ML_STORAGE_BACKEND=gcs` |

## Training Thresholds

| Threshold | Value | Description |
|-----------|-------|-------------|
| `MIN_TRAINING_SAMPLES` | 50 | Minimum to attempt training |
| `RECOMMENDED_SAMPLES` | 200 | Recommended for reliable model performance |
| Force override | `force: true` | Bypasses minimum sample check |

## Training Modes

| Mode | Method | Description |
|------|--------|-------------|
| Standard | `train()` | Uses explicit user labels only |
| Weighted | `train_weighted()` | Combines explicit + weak labels with sample weights (0.0-1.0) |

## Model Output

The trained model predicts `false_positive_score` (0.0-1.0) for each vulnerability:
- **0.0**: High confidence real vulnerability
- **1.0**: High confidence false positive

## Training Metrics

| Metric | Description |
|--------|-------------|
| `accuracy` | Overall classification accuracy |
| `auc` | Area Under ROC Curve |
| `cv_auc_mean` | 5-fold cross-validation AUC mean |
| `cv_auc_std` | 5-fold cross-validation AUC standard deviation |
| `samples_train` | Training set size |
| `samples_test` | Test set size |
| `true_positive_count` | Count of real vulnerabilities in dataset |
| `false_positive_count` | Count of false positives in dataset |

## Files

| File | Role |
|------|------|
| `blocksecops-api-service/src/ml/fp_training_collector.py` | `FPTrainingDataCollector`: data collection from 3 sources |
| `blocksecops-api-service/src/ml/false_positive_classifier.py` | `FalsePositiveClassifier`: RF training, prediction, persistence |
| `blocksecops-api-service/src/ml/feature_extractor.py` | `FeatureExtractor`: 30+ feature extraction |
| `blocksecops-api-service/src/ml/storage/local_storage.py` | Local model storage backend |
| `blocksecops-api-service/src/ml/storage/gcs_storage.py` | GCS model storage backend |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/admin/system.py` | Admin retrain endpoint |
| `blocksecops-admin-portal/src/pages/AdminMLModels.tsx` | Admin UI for retraining |

## Error Handling

- Training fails gracefully if insufficient samples (returns `success: false` with message)
- Individual data collection sources are independent; a failure in one does not block others
- Model save failures are logged but do not crash the training process
- Admin audit log records success/failure with metrics for every retrain attempt

## Related Pipelines

- [Intelligence Pipeline](./intelligence-pipeline.md) — uses trained model for `false_positive_score` prediction
- [Deduplication Pipeline](./deduplication-pipeline.md) — scanner quality metrics depend on training labels
