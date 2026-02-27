# Playbook: ML Model Retraining

**Version:** 1.0.0
**Last Updated:** February 5, 2026

## Overview

This playbook covers retraining the **False Positive Classifier** — a Random Forest model that predicts the probability (0.0-1.0) that a vulnerability finding is a false positive. Retraining is an admin-only operation performed via the Admin Portal or API.

---

## Prerequisites

- [ ] Platform admin account with `platform_admin` role
- [ ] API Service running (port 8000)
- [ ] PostgreSQL database accessible
- [ ] Sufficient labeled vulnerability data (see thresholds below)
- [ ] Access to Admin Portal at `admin.0xapogee.local` or API endpoint
- [ ] `ML_MODEL_DIR` env var set to a writable path (K8s: `/app/.cache/ml-models`)

---

## Quick Reference

```bash
# Full retraining cycle
1. Check training data readiness (stats endpoint)
2. Verify label distribution (need both confirmed + false_positive)
3. Trigger retrain (Admin Portal or API)
4. Verify training metrics (accuracy 80%+, AUC 0.85+)
5. Confirm model saved to storage
6. Verify predictions working on new scans
```

---

## Training Data Thresholds

| Threshold | Value | Description |
|-----------|-------|-------------|
| `MIN_TRAINING_SAMPLES` | 50 | Minimum to attempt training (with `force: true`) |
| `RECOMMENDED_SAMPLES` | 200 | Default minimum for standard retraining |
| Force override | `force: true` | Bypasses minimum sample check (still requires 50) |

### Label Sources

Training data is collected from three sources:

| Source | Database Model | Labels |
|--------|---------------|--------|
| Annotations | `VulnerabilityAnnotationModel` | `confirmed`, `false_positive`, `wont_fix` |
| Classifications | `VulnerabilityClassificationModel` | Explicit classifications (`is_latest == True`) |
| Inline labels | `VulnerabilityModel.user_classification` | `confirmed`, `false_positive` |

Soft-deleted vulnerabilities are included — labels are preserved when contracts are deleted.

---

## Step 1: Check Training Data Readiness

### Via Admin Portal

Navigate to **Admin Portal > ML Models** and review the Training Data Stats section. It shows:
- Total labeled samples
- Confirmed vs. false positive distribution
- Whether the threshold is met

### Via API

```bash
# Check training data stats
curl -s http://127.0.0.1:8000/api/v1/ml/training-data-stats \
  -H "Authorization: Bearer $TOKEN" | jq
```

Expected response:
```json
{
  "total_samples": 250,
  "confirmed_count": 180,
  "false_positive_count": 60,
  "wont_fix_count": 10,
  "from_annotations": 120,
  "from_classifications": 80,
  "from_inline_labels": 50,
  "from_soft_deleted": 15,
  "is_ready_for_training": true,
  "is_recommended_for_training": true,
  "message": "Ready for training with 250 samples"
}
```

### Via Database

```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT user_classification, COUNT(*) FROM vulnerabilities
   WHERE user_classification IN ('confirmed', 'false_positive')
   GROUP BY user_classification;"
```

---

## Step 2: Verify Label Distribution

Good training requires **both classes** with reasonable balance:

| Distribution | Quality | Notes |
|-------------|---------|-------|
| 40-60% / 60-40% | Excellent | Well balanced |
| 30-70% / 70-30% | Good | `class_weight="balanced"` handles this |
| 20-80% / 80-20% | Acceptable | Model may underperform on minority class |
| <10% either class | Poor | Retrain not recommended; collect more labels |

The classifier uses `class_weight="balanced"` to compensate for imbalance, but extreme skew will reduce performance.

---

## Step 3: Trigger Retraining

### Option A: Admin Portal UI

1. Navigate to `admin.0xapogee.local/ml-models`
2. Review the model status and training data sections
3. Click **Retrain Model** (uses 200 sample minimum)
4. Or click **Force Retrain** (bypasses to 50 sample minimum)
5. Wait for the result to appear in the response section

### Option B: Admin API Endpoint

```bash
# Standard retrain (200+ samples required)
curl -s -X POST http://127.0.0.1:8000/api/v1/admin/system/ml/retrain \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"force": false, "min_samples": 200}' | jq
```

```bash
# Force retrain with fewer samples (50+ required)
curl -s -X POST http://127.0.0.1:8000/api/v1/admin/system/ml/retrain \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"force": true, "min_samples": 50}' | jq
```

### Option C: Legacy Endpoint (Deprecated)

```bash
# Deprecated — requires platform_admin role
curl -s -X POST http://127.0.0.1:8000/api/v1/ml/retrain \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"min_samples": 200}' | jq
```

This endpoint is deprecated in API Service v0.26.0. Use `POST /admin/system/ml/retrain` instead.

---

## Step 4: Verify Training Results

### Success Response

```json
{
  "success": true,
  "samples_used": 250,
  "accuracy": 0.87,
  "auc": 0.91,
  "message": "Model retrained successfully"
}
```

### Performance Thresholds

Per [ML Development Standards](../standards/ml-development.md):

| Metric | Minimum | Target | Action if Below |
|--------|---------|--------|-----------------|
| Accuracy | 80% | 85%+ | Collect more labels, check label quality |
| AUC-ROC | 0.85 | 0.90+ | Check class balance, review outliers |
| CV AUC Mean | 0.80 | 0.85+ | Model may be overfitting; increase sample count |

### Check Model Stats After Training

```bash
curl -s http://127.0.0.1:8000/api/v1/ml/model-stats \
  -H "Authorization: Bearer $TOKEN" | jq
```

Expected fields:
```json
{
  "is_trained": true,
  "model_version": "1.0.0",
  "trained_at": "2026-02-05T14:30:00",
  "metrics": {
    "accuracy": 0.87,
    "auc": 0.91,
    "cv_auc_mean": 0.88,
    "cv_auc_std": 0.03,
    "samples_train": 200,
    "samples_test": 50,
    "true_positive_count": 170,
    "false_positive_count": 80
  }
}
```

---

## Step 5: Verify Model Persistence

### Local Storage (Default)

Model files are saved to `blocksecops-api-service/src/ml/models/fp_classifier/`:

| File | Purpose |
|------|---------|
| `current.joblib` | Active model used for predictions |
| `v{version}.joblib` | Versioned snapshot (e.g., `v1.0.0.joblib`) |
| `metadata.json` | Version, metrics, and timestamps |

```bash
# Check model files exist
ls -la /home/pwner/Git/blocksecops-api-service/src/ml/models/fp_classifier/

# View metadata
cat /home/pwner/Git/blocksecops-api-service/src/ml/models/fp_classifier/metadata.json | jq
```

### GCS Storage

If `ML_STORAGE_BACKEND=gcs`, models are stored in Google Cloud Storage:

```bash
# Check GCS bucket
gsutil ls gs://<bucket>/fp_classifier/
```

---

## Step 6: Verify Predictions Working

After retraining, test that the model produces predictions:

```bash
# Get a vulnerability ID from recent scans
VULN_ID=$(curl -s http://127.0.0.1:8000/api/v1/vulnerabilities?limit=1 \
  -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].id')

# Request FP prediction
curl -s -X POST http://127.0.0.1:8000/api/v1/ml/predict-false-positive \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"vulnerability_id\":\"$VULN_ID\"}" | jq
```

Expected: `false_positive_score` between 0.0 and 1.0.

---

## Model Architecture

| Parameter | Value |
|-----------|-------|
| Algorithm | `RandomForestClassifier` (scikit-learn) |
| Trees | `n_estimators=100` |
| Max depth | `max_depth=10` |
| Min samples split | `min_samples_split=5` |
| Min samples leaf | `min_samples_leaf=2` |
| Class weight | `balanced` (auto-adjusts for imbalance) |
| Test split | 80% train / 20% test (stratified) |
| Cross-validation | 5-fold AUC |
| Execution | CPU-only, <100ms inference, <500MB footprint |

### Feature Extraction

The `FeatureExtractor` produces 30+ features per vulnerability:

| Category | Features | Description |
|----------|----------|-------------|
| Scanner | `scanner_id`, `detector_id` | Source scanner and detector |
| Severity | `severity` | Vulnerability severity level |
| Confidence | `confidence`, `classification_confidence` | Scanner and classification scores |
| Code | `code_snippet` | Source code context (hashed/vectorized) |
| Pattern | `pattern_code` | BVD pattern classification |
| Consensus | `tool_consensus_score` | Cross-scanner agreement |
| Context | `file_path`, `description` | File location and description |

---

## Training Modes

| Mode | Method | Description | When to Use |
|------|--------|-------------|-------------|
| Standard | `train()` | Uses explicit user labels only | Default — most reliable |
| Weighted | `train_weighted()` | Combines explicit + weak labels with weights (0.0-1.0) | When few explicit labels exist but many weak signals available |

---

## Audit Trail

Every retrain attempt (success or failure) is recorded in the admin audit log:

| Field | Value |
|-------|-------|
| Action | `admin.ml.retrain` |
| Target type | `ml_model` |
| Logged data | `success`, `samples_used`, `accuracy`, `auc`, or `error` |

View audit history:
```bash
curl -s http://127.0.0.1:8000/api/v1/admin/audit-logs?action=admin.ml.retrain \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq
```

---

## Rollback Procedure

### Rollback to Previous Model Version

If the new model performs poorly, restore a previous version:

```bash
# List available model versions
ls /home/pwner/Git/blocksecops-api-service/src/ml/models/fp_classifier/v*.joblib

# Copy previous version to current
cp /home/pwner/Git/blocksecops-api-service/src/ml/models/fp_classifier/v{OLD_VERSION}.joblib \
   /home/pwner/Git/blocksecops-api-service/src/ml/models/fp_classifier/current.joblib

# Restart API service to reload model
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local --timeout=120s
```

### Remove Model Entirely

To revert to a no-model state (rule-based FP scoring only):

```bash
# Remove model files
rm /home/pwner/Git/blocksecops-api-service/src/ml/models/fp_classifier/current.joblib

# Restart API service
kubectl rollout restart deployment/api-service -n api-service-local
```

---

## Troubleshooting

### "Not enough labeled data" Error

**Symptoms:** Retrain returns `success: false` with insufficient data message.

**Solution:**
1. Check current label count via training data stats endpoint
2. If below threshold, label more vulnerabilities:
   - Dashboard: Open vulnerability detail page > label as Confirmed or False Positive
   - API: `POST /api/v1/ml/label-vulnerability`
   - Batch: `python scripts/label_vulnerabilities.py` (interactive CLI)
   - Import: `python scripts/import_labels.py` (CSV batch)
3. After reaching threshold, retry retraining

### Training Fails with scikit-learn Error

**Symptoms:** `ImportError: scikit-learn required for training`

**Solution:** Verify scikit-learn is installed in the API service container:
```bash
kubectl exec -n api-service-local deployment/api-service -- pip list | grep scikit
```

### Low Accuracy or AUC After Training

**Symptoms:** Metrics below minimum thresholds (accuracy <80%, AUC <0.85).

**Causes and fixes:**

| Cause | Fix |
|-------|-----|
| Too few samples | Collect more labels (target 200+) |
| Extreme class imbalance | Label more of the minority class |
| Noisy labels | Review and correct mislabeled vulnerabilities |
| Insufficient feature diversity | Ensure labels span multiple scanners and severity levels |

### Model Not Loading After Retrain

**Symptoms:** `is_trained: false` after successful retrain.

**Solution:**
1. Check model file exists: `ls -la src/ml/models/fp_classifier/current.joblib`
2. Restart API service: `kubectl rollout restart deployment/api-service -n api-service-local`
3. Check API logs for model loading errors:
   ```bash
   kubectl logs -n api-service-local deployment/api-service --tail=50 | grep -i "model\|classifier"
   ```

### 403 Forbidden on Retrain Endpoint

**Symptoms:** `403 Forbidden` when calling `POST /admin/system/ml/retrain`.

**Solution:** Verify the user has `platform_admin` role:
```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT email, admin_role FROM users WHERE admin_role = 'platform_admin';"
```

---

## Generating Training Labels

If you need to build up labeled data before retraining:

### Interactive CLI Labeling

```bash
cd /home/pwner/Git/blocksecops-api-service
source .venv/bin/activate
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  python scripts/label_vulnerabilities.py
```

### CSV Batch Import

```bash
# Prepare CSV with columns: vulnerability_id, label (confirmed/false_positive)
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  python scripts/import_labels.py --file labels.csv
```

### Heuristic Auto-Labeling

```bash
# Auto-label based on heuristics (lower confidence, use for weighted training)
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  python scripts/auto_label_vulnerabilities.py
```

---

## Checklist

- [ ] Training data stats checked (200+ labeled samples recommended)
- [ ] Both classes present (confirmed + false_positive)
- [ ] Class distribution is reasonable (no extreme skew)
- [ ] Retrain triggered via Admin Portal or API
- [ ] Training completed successfully
- [ ] Accuracy meets minimum threshold (80%+)
- [ ] AUC meets minimum threshold (0.85+)
- [ ] Model file saved to storage (`current.joblib`)
- [ ] FP predictions returning valid scores for new vulnerabilities
- [ ] Audit log entry created for retrain action

---

## Related Documentation

- [FP Training Pipeline](../pipelines/fp-training-pipeline.md) — Pipeline architecture
- [Intelligence Pipeline](../pipelines/intelligence-pipeline.md) — Uses trained model for FP scoring
- [ML Development Standards](../standards/ml-development.md) — Architecture and performance targets
- [AI/ML Audit Playbook](ai-ml-audit-playbook.md) — Full ML system audit
- [Admin Account Setup](admin-account-setup.md) — Setting up platform_admin role

## Files

| File | Role |
|------|------|
| `blocksecops-api-service/src/ml/false_positive_classifier.py` | `FalsePositiveClassifier`: training, prediction, persistence |
| `blocksecops-api-service/src/ml/fp_training_collector.py` | `FPTrainingDataCollector`: data collection from 3 sources |
| `blocksecops-api-service/src/ml/feature_extractor.py` | `FeatureExtractor`: 30+ feature extraction |
| `blocksecops-api-service/src/ml/storage/local_storage.py` | Local model storage (versioned saves + metadata) |
| `blocksecops-api-service/src/ml/storage/gcs_storage.py` | GCS model storage backend |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/admin/system.py` | Admin retrain endpoint |
| `blocksecops-admin-portal/src/pages/AdminMLModels.tsx` | Admin UI for model management and retraining |
