# ML (Machine Learning) API

Base URL: `/api/v1/ml`

This module provides machine learning capabilities for vulnerability classification, false positive prediction, scanner quality assessment, review queue management, risk scoring, and multi-class model training.

---

## Endpoints

### Get Model Statistics

Returns statistics about the current ML model including version, training status, and sample count.

**`GET /api/v1/ml/model-stats`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/model-stats \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "model_version": "1.2.0",
  "is_trained": true,
  "samples_count": 375,
  "accuracy": 0.89,
  "last_trained_at": "2026-02-10T08:00:00Z",
  "features_used": 32
}
```

#### Response Schema

| Field             | Type    | Description                              |
|-------------------|---------|------------------------------------------|
| `model_version`   | string  | Current model version identifier         |
| `is_trained`      | boolean | Whether the model has been trained       |
| `samples_count`   | integer | Number of training samples available     |
| `accuracy`        | float   | Model accuracy on test set               |
| `last_trained_at` | string  | ISO 8601 timestamp of last training run  |
| `features_used`   | integer | Number of features in the model          |

---

### Get Training Statistics

Returns training run statistics.

**`GET /api/v1/ml/training-stats`**

> **Known Issue:** This endpoint currently returns `500 Internal Server Error` due to a datetime serialization bug. Use `/api/v1/ml/model-stats` or `/api/v1/ml/training-data-stats` as alternatives.

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/training-stats \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `500 Internal Server Error`

```json
{
  "detail": "Internal server error",
  "status_code": 500
}
```

---

### Get Training Data Statistics

Returns statistics about the available training data.

**`GET /api/v1/ml/training-data-stats`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/training-data-stats \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "total_samples": 375,
  "labeled_samples": 312,
  "unlabeled_samples": 63,
  "is_ready_for_training": true,
  "label_distribution": {
    "true_positive": 198,
    "false_positive": 114
  },
  "by_scanner": {
    "slither": 150,
    "mythril": 120,
    "soliditydefend": 105
  }
}
```

#### Response Schema

| Field                  | Type    | Description                                    |
|------------------------|---------|------------------------------------------------|
| `total_samples`        | integer | Total training samples in the dataset          |
| `labeled_samples`      | integer | Samples with ground-truth labels               |
| `unlabeled_samples`    | integer | Samples awaiting labeling                      |
| `is_ready_for_training`| boolean | Whether minimum sample threshold is met        |
| `label_distribution`   | object  | Count of samples per label class               |
| `by_scanner`           | object  | Sample count grouped by scanner source         |

---

### Retrain Model

Triggers a model retraining using the current training dataset.

**`POST /api/v1/ml/retrain`**

#### Request Body

| Field             | Type    | Required | Description                          |
|-------------------|---------|----------|--------------------------------------|
| `force`           | boolean | No       | Force retrain even if data unchanged |
| `test_split`      | float   | No       | Test set ratio (default: 0.2)        |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/retrain \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "force": false,
    "test_split": 0.2
  }'
```

#### Response `202 Accepted`

```json
{
  "task_id": "task-aabb1122-3344-5566-7788-99aabbccddee",
  "status": "training_started",
  "message": "Model retraining initiated with 375 samples"
}
```

---

### Retrain Model with Weights

Triggers a weighted retraining to address class imbalance or prioritize certain sample types.

**`POST /api/v1/ml/retrain-weighted`**

#### Request Body

| Field             | Type   | Required | Description                               |
|-------------------|--------|----------|-------------------------------------------|
| `class_weights`   | object | No       | Weight per class label                    |
| `scanner_weights` | object | No       | Weight per scanner source                 |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/retrain-weighted \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "class_weights": {
      "true_positive": 1.0,
      "false_positive": 1.5
    },
    "scanner_weights": {
      "slither": 1.0,
      "mythril": 1.2
    }
  }'
```

#### Response `202 Accepted`

```json
{
  "task_id": "task-ccdd1122-3344-5566-7788-99aabbccddee",
  "status": "training_started",
  "message": "Weighted model retraining initiated"
}
```

---

### Predict False Positive

Predicts whether a given vulnerability is a false positive.

**`POST /api/v1/ml/predict-false-positive`**

#### Request Body

| Field              | Type   | Required | Description                             |
|--------------------|--------|----------|-----------------------------------------|
| `vulnerability_id` | string | Yes      | UUID of the vulnerability to predict    |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/predict-false-positive \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }'
```

#### Response `200 OK`

```json
{
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "prediction": "false_positive",
  "confidence": 0.87,
  "features_used": 32,
  "top_factors": [
    {"feature": "scanner_agreement_ratio", "importance": 0.23},
    {"feature": "severity_consistency", "importance": 0.18}
  ]
}
```

---

### Get Dynamic Priorities

Returns the current dynamic scanner priority ordering based on historical performance.

**`GET /api/v1/ml/dynamic-priorities`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/dynamic-priorities \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "priorities": [
    {"scanner": "slither", "priority": 1, "score": 0.95},
    {"scanner": "mythril", "priority": 2, "score": 0.88},
    {"scanner": "soliditydefend", "priority": 3, "score": 0.82}
  ],
  "last_updated": "2026-02-13T12:00:00Z"
}
```

---

### Get Scanner Quality Metrics

Returns quality metrics for all scanners.

**`GET /api/v1/ml/scanner-quality`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/scanner-quality \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "scanners": [
    {
      "scanner_id": "slither",
      "precision": 0.91,
      "recall": 0.85,
      "f1_score": 0.88,
      "total_findings": 1250,
      "true_positives": 890,
      "false_positives": 88
    }
  ],
  "total": 3
}
```

---

### Get Specific Scanner Quality

Returns quality metrics for a specific scanner.

**`GET /api/v1/ml/scanner-quality/{scanner_id}`**

#### Path Parameters

| Parameter    | Type   | Description               |
|--------------|--------|---------------------------|
| `scanner_id` | string | Scanner identifier        |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/scanner-quality/slither \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "scanner_id": "slither",
  "precision": 0.91,
  "recall": 0.85,
  "f1_score": 0.88,
  "total_findings": 1250,
  "true_positives": 890,
  "false_positives": 88,
  "by_severity": {
    "critical": {"precision": 0.95, "count": 120},
    "high": {"precision": 0.90, "count": 380},
    "medium": {"precision": 0.88, "count": 450},
    "low": {"precision": 0.85, "count": 300}
  }
}
```

---

### Get Review Queue

Returns items in the human review queue for manual labeling.

**`GET /api/v1/ml/review-queue`**

#### Query Parameters

| Parameter | Type    | Default | Description                    |
|-----------|---------|---------|--------------------------------|
| `page`    | integer | 1       | Page number                    |
| `limit`   | integer | 20      | Results per page               |
| `status`  | string  | —       | Filter: `pending`, `completed` |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/ml/review-queue?status=pending&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "items": [
    {
      "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "title": "Potential reentrancy in withdraw()",
      "scanner": "slither",
      "severity": "high",
      "ml_prediction": "uncertain",
      "ml_confidence": 0.52,
      "status": "pending",
      "queued_at": "2026-02-14T08:00:00Z"
    }
  ],
  "total": 15,
  "page": 1,
  "limit": 10
}
```

---

### Get Next Review Item

Returns the next highest-priority item from the review queue.

**`GET /api/v1/ml/review-queue/next`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/review-queue/next \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "title": "Potential reentrancy in withdraw()",
  "scanner": "slither",
  "severity": "high",
  "ml_prediction": "uncertain",
  "ml_confidence": 0.52,
  "context": {
    "code_snippet": "function withdraw(uint amount) public { ... }",
    "similar_findings": 3
  }
}
```

---

### Label Review Queue Item

Assigns a human-provided label to a vulnerability in the review queue.

**`POST /api/v1/ml/review-queue/{vulnerability_id}/label`**

#### Path Parameters

| Parameter          | Type   | Description                      |
|--------------------|--------|----------------------------------|
| `vulnerability_id` | string | UUID of the vulnerability        |

#### Request Body

| Field   | Type   | Required | Description                                    |
|---------|--------|----------|------------------------------------------------|
| `label` | string | Yes      | One of: `true_positive`, `false_positive`      |
| `notes` | string | No       | Reviewer notes                                 |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/review-queue/a1b2c3d4-e5f6-7890-abcd-ef1234567890/label \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "label": "true_positive",
    "notes": "Confirmed reentrancy: external call before state update."
  }'
```

#### Response `200 OK`

```json
{
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "label": "true_positive",
  "labeled_by": "user@example.com",
  "labeled_at": "2026-02-14T10:30:00Z"
}
```

---

### Populate Review Queue

Populates the review queue with unlabeled or uncertain vulnerabilities.

**`POST /api/v1/ml/populate-review-queue`**

#### Request Body

| Field           | Type    | Required | Description                                       |
|-----------------|---------|----------|---------------------------------------------------|
| `max_items`     | integer | No       | Maximum items to add (default: 50)                |
| `strategy`      | string  | No       | One of: `uncertain`, `random`, `diverse`          |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/populate-review-queue \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "max_items": 25,
    "strategy": "uncertain"
  }'
```

#### Response `200 OK`

```json
{
  "added": 25,
  "strategy": "uncertain",
  "queue_size": 40
}
```

---

### Get Multi-Class Model Statistics

Returns statistics about the multi-class classification model.

**`GET /api/v1/ml/multi-class/stats`**

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/multi-class/stats \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "model_version": "mc-1.0.0",
  "is_trained": true,
  "classes": ["true_positive", "false_positive", "needs_review", "informational"],
  "accuracy": 0.82,
  "per_class_f1": {
    "true_positive": 0.88,
    "false_positive": 0.85,
    "needs_review": 0.72,
    "informational": 0.78
  },
  "samples_count": 375
}
```

---

### Train Multi-Class Model

Triggers training of the multi-class classification model.

**`POST /api/v1/ml/multi-class/train`**

#### Request Body

| Field        | Type    | Required | Description                           |
|--------------|---------|----------|---------------------------------------|
| `force`      | boolean | No       | Force retrain if data unchanged       |
| `test_split` | float   | No       | Test set ratio (default: 0.2)         |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/multi-class/train \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "force": true
  }'
```

#### Response `202 Accepted`

```json
{
  "task_id": "task-eeff1122-3344-5566-7788-99aabbccddee",
  "status": "training_started",
  "message": "Multi-class model training initiated"
}
```

---

### Get Pattern Feedback

Returns collected feedback on vulnerability patterns.

**`GET /api/v1/ml/pattern-feedback`**

#### Query Parameters

| Parameter       | Type    | Default | Description                          |
|-----------------|---------|---------|--------------------------------------|
| `page`          | integer | 1       | Page number                          |
| `limit`         | integer | 20      | Results per page                     |
| `needs_review`  | boolean | —       | Filter for patterns needing review   |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/ml/pattern-feedback?limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "feedback": [
    {
      "pattern_id": "BVD-REEN-001",
      "positive_count": 25,
      "negative_count": 3,
      "needs_review": false
    }
  ],
  "total": 31,
  "patterns_needing_review": 2
}
```

#### Response Schema

| Field                    | Type    | Description                              |
|--------------------------|---------|------------------------------------------|
| `feedback`               | array   | Array of pattern feedback entries        |
| `total`                  | integer | Total number of feedback entries         |
| `patterns_needing_review`| integer | Patterns flagged for human review        |

---

### Label Vulnerability

Assigns a classification label to a vulnerability for ML training purposes.

**`POST /api/v1/ml/label-vulnerability`**

#### Request Body

| Field              | Type   | Required | Description                                     |
|--------------------|--------|----------|-------------------------------------------------|
| `vulnerability_id` | string | Yes      | UUID of the vulnerability                       |
| `label`            | string | Yes      | One of: `true_positive`, `false_positive`       |
| `confidence`       | float  | No       | Labeler's confidence (0.0-1.0)                  |
| `notes`            | string | No       | Additional context                              |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/label-vulnerability \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "label": "true_positive",
    "confidence": 0.95,
    "notes": "Confirmed by manual code review"
  }'
```

#### Response `200 OK`

```json
{
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "label": "true_positive",
  "labeled_at": "2026-02-14T10:30:00Z"
}
```

---

### Generate Weak Labels

Automatically generates weak labels for unlabeled vulnerabilities using heuristics.

**`POST /api/v1/ml/generate-weak-labels`**

#### Request Body

| Field        | Type    | Required | Description                             |
|--------------|---------|----------|-----------------------------------------|
| `max_items`  | integer | No       | Maximum items to label (default: 100)   |
| `min_confidence` | float | No    | Minimum heuristic confidence threshold  |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/generate-weak-labels \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "max_items": 50,
    "min_confidence": 0.7
  }'
```

#### Response `200 OK`

```json
{
  "labeled": 42,
  "skipped": 8,
  "average_confidence": 0.83
}
```

---

### Get Contract Risk Score

Returns the ML-computed risk score for a specific contract.

**`GET /api/v1/ml/contracts/{contract_id}/risk-score`**

#### Path Parameters

| Parameter     | Type   | Description             |
|---------------|--------|-------------------------|
| `contract_id` | string | UUID of the contract    |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/contracts/c1d2e3f4-a5b6-7890-cdef-1234567890ab/risk-score \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "contract_id": "c1d2e3f4-a5b6-7890-cdef-1234567890ab",
  "risk_score": 7.8,
  "risk_level": "high",
  "factors": [
    {"factor": "critical_vulnerabilities", "weight": 0.4, "value": 3},
    {"factor": "scanner_agreement", "weight": 0.3, "value": 0.75}
  ]
}
```

---

### Get Contract Top Priorities

Returns the highest-priority vulnerabilities for a specific contract.

**`GET /api/v1/ml/contracts/{contract_id}/top-priorities`**

#### Path Parameters

| Parameter     | Type   | Description             |
|---------------|--------|-------------------------|
| `contract_id` | string | UUID of the contract    |

#### Query Parameters

| Parameter | Type    | Default | Description                |
|-----------|---------|---------|----------------------------|
| `limit`   | integer | 10      | Maximum results to return  |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/ml/contracts/c1d2e3f4-a5b6-7890-cdef-1234567890ab/top-priorities?limit=5" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "contract_id": "c1d2e3f4-a5b6-7890-cdef-1234567890ab",
  "priorities": [
    {
      "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "title": "Reentrancy in withdraw()",
      "severity": "critical",
      "priority_score": 9.5,
      "ml_confidence": 0.94
    }
  ],
  "total": 1
}
```

---

### Get Prioritized Vulnerabilities for a Scan

Returns vulnerabilities from a scan ordered by ML-computed priority.

**`GET /api/v1/ml/scans/{scan_id}/prioritized`**

#### Path Parameters

| Parameter | Type   | Description          |
|-----------|--------|----------------------|
| `scan_id` | string | UUID of the scan    |

#### Query Parameters

| Parameter | Type    | Default | Description                |
|-----------|---------|---------|----------------------------|
| `page`    | integer | 1       | Page number                |
| `limit`   | integer | 20      | Results per page           |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/ml/scans/s1a2b3c4-d5e6-7890-abcd-ef1234567890/prioritized?limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "scan_id": "s1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "vulnerabilities": [
    {
      "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
      "title": "Reentrancy in withdraw()",
      "severity": "critical",
      "priority_score": 9.5,
      "classification": "true_positive",
      "ml_confidence": 0.94
    }
  ],
  "total": 15,
  "page": 1,
  "limit": 10
}
```

---

### Get Scan Risk Score

Returns the aggregate ML-computed risk score for an entire scan.

**`GET /api/v1/ml/scans/{scan_id}/risk-score`**

#### Path Parameters

| Parameter | Type   | Description          |
|-----------|--------|----------------------|
| `scan_id` | string | UUID of the scan    |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/scans/s1a2b3c4-d5e6-7890-abcd-ef1234567890/risk-score \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "scan_id": "s1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "risk_score": 8.2,
  "risk_level": "high",
  "total_vulnerabilities": 45,
  "critical_count": 3,
  "high_count": 8,
  "predicted_true_positives": 32
}
```

---

### Classify All Vulnerabilities in a Scan

Runs ML classification on all vulnerabilities in a given scan.

**`POST /api/v1/ml/scans/{scan_id}/classify-all`**

#### Path Parameters

| Parameter | Type   | Description          |
|-----------|--------|----------------------|
| `scan_id` | string | UUID of the scan    |

#### Example Request

```bash
curl -X POST http://localhost:8000/api/v1/ml/scans/s1a2b3c4-d5e6-7890-abcd-ef1234567890/classify-all \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "scan_id": "s1a2b3c4-d5e6-7890-abcd-ef1234567890",
  "classified": 45,
  "results": {
    "true_positive": 32,
    "false_positive": 8,
    "uncertain": 5
  },
  "average_confidence": 0.84
}
```

---

### Classify a Single Vulnerability

Runs ML classification on a single vulnerability.

**`GET /api/v1/ml/vulnerabilities/{vulnerability_id}/classify`**

#### Path Parameters

| Parameter          | Type   | Description                      |
|--------------------|--------|----------------------------------|
| `vulnerability_id` | string | UUID of the vulnerability        |

#### Example Request

```bash
curl -X GET http://localhost:8000/api/v1/ml/vulnerabilities/a1b2c3d4-e5f6-7890-abcd-ef1234567890/classify \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "classification": "true_positive",
  "confidence": 0.94,
  "probabilities": {
    "true_positive": 0.94,
    "false_positive": 0.04,
    "uncertain": 0.02
  }
}
```

---

### Find Similar Vulnerabilities

Finds vulnerabilities similar to the given one using ML feature similarity.

**`GET /api/v1/ml/vulnerabilities/{vulnerability_id}/similar`**

#### Path Parameters

| Parameter          | Type   | Description                      |
|--------------------|--------|----------------------------------|
| `vulnerability_id` | string | UUID of the vulnerability        |

#### Query Parameters

| Parameter | Type    | Default | Description                |
|-----------|---------|---------|----------------------------|
| `limit`   | integer | 10      | Maximum results to return  |
| `min_similarity` | float | 0.7 | Minimum similarity score   |

#### Example Request

```bash
curl -X GET "http://localhost:8000/api/v1/ml/vulnerabilities/a1b2c3d4-e5f6-7890-abcd-ef1234567890/similar?limit=5" \
  -H "Authorization: Bearer $TOKEN"
```

#### Response `200 OK`

```json
{
  "vulnerability_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "similar": [
    {
      "vulnerability_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
      "title": "Reentrancy in deposit()",
      "similarity": 0.92,
      "label": "true_positive",
      "scanner": "mythril"
    }
  ],
  "total": 1
}
```

---

## Error Responses

All endpoints may return the following error responses:

| Status | Description               |
|--------|---------------------------|
| `400`  | Bad request / validation  |
| `401`  | Unauthorized              |
| `404`  | Resource not found        |
| `422`  | Unprocessable entity      |
| `500`  | Internal server error     |

```json
{
  "detail": "Model is not trained. Call /api/v1/ml/retrain first.",
  "status_code": 400
}
```
