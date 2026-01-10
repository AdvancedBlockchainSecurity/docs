# ML Development Standards

**Last Updated**: December 27, 2025
**Phase**: 5 - AI/ML Features

---

## Overview

This document defines standards for developing and maintaining ML features in BlockSecOps. All ML features use a CPU-only approach to minimize infrastructure costs.

---

## Architecture Principles

### 1. CPU-Only Execution
- **No GPU dependencies**: All models must run on CPU
- **No LLM API calls**: Avoid external API costs (OpenAI, AWS Bedrock)
- **Lightweight models**: Prefer small, fast models over large ones
- **Lazy loading**: Load models on first use, not at startup

### 2. Cost Efficiency
- Target: ~$1/month total ML infrastructure cost
- No additional compute resources beyond existing pods
- Model files stored in container or shared volume

### 3. Performance Targets
| Metric | Target |
|--------|--------|
| Inference latency | <100ms per item |
| Embedding generation | <50ms per item |
| Model memory footprint | <500MB per model |
| Cold start (first load) | <5 seconds |

---

## ML Module Structure

### Directory Layout
```
blocksecops-api-service/src/ml/
├── __init__.py                    # Module exports, lazy loading
├── risk_scorer.py                 # Risk score calculation
├── confidence_scorer.py           # Confidence scoring
├── prioritizer.py                 # Priority ranking
├── feature_extractor.py           # Feature extraction for classifiers
├── false_positive_classifier.py   # FP prediction
├── semantic_deduplicator.py       # Embedding-based similarity
├── background_tasks.py            # Async training tasks
├── label_counter.py               # Label tracking for retrain triggers
├── storage/
│   ├── __init__.py                # Storage exports
│   ├── base.py                    # Abstract storage interface
│   ├── local_storage.py           # Local filesystem storage
│   └── gcs_storage.py             # Google Cloud Storage backend
└── models/
    ├── .gitkeep
    └── fp_classifier_v1.joblib    # Trained model (when available)

blocksecops-api-service/scripts/
├── label_vulnerabilities.py       # Interactive CLI for manual labeling
├── import_labels.py               # CSV batch import
└── auto_label_vulnerabilities.py  # Heuristic auto-labeling
```

### Module Responsibilities

| Module | Purpose | Training Required |
|--------|---------|-------------------|
| `risk_scorer.py` | Aggregate risk scores (0-100) | No |
| `confidence_scorer.py` | Per-finding confidence (0.0-1.0) | No |
| `prioritizer.py` | Fix priority ranking | No |
| `feature_extractor.py` | Extract features for ML models | No |
| `false_positive_classifier.py` | Predict FP probability | Yes (200-500 labels) |
| `semantic_deduplicator.py` | Find similar vulnerabilities | No (pretrained model) |
| `background_tasks.py` | Async model training | N/A (orchestration) |
| `label_counter.py` | Track labels, trigger retraining | N/A (metadata) |
| `storage/local_storage.py` | Local model persistence | N/A (storage) |
| `storage/gcs_storage.py` | GCS model persistence | N/A (storage) |

---

## Coding Standards

### 1. Type Hints
All functions must have complete type annotations:

```python
def calculate_risk_score(
    vulnerabilities: List[Dict[str, Any]],
    include_fp_weight: bool = True
) -> RiskScoreResult:
    """Calculate aggregate risk score."""
    ...
```

### 2. Dataclass Models
Use dataclasses for structured outputs:

```python
from dataclasses import dataclass
from typing import Optional, List

@dataclass
class RiskScoreResult:
    score: int                      # 0-100
    level: str                      # CRITICAL, HIGH, MEDIUM, LOW
    breakdown: Dict[str, int]       # Score components
    vulnerabilities_analyzed: int
    adjustments: List[str]          # Applied adjustments
```

### 3. Lazy Loading Pattern
Models should be loaded lazily to avoid startup delays:

```python
class SemanticDeduplicator:
    _model = None

    @classmethod
    def _load_model(cls):
        if cls._model is None:
            from sentence_transformers import SentenceTransformer
            cls._model = SentenceTransformer('all-MiniLM-L6-v2')
        return cls._model

    def embed(self, text: str) -> np.ndarray:
        model = self._load_model()
        return model.encode(text)
```

### 4. Error Handling
Handle missing data gracefully with sensible defaults:

```python
def calculate_confidence(vulnerability: Dict[str, Any]) -> float:
    """Calculate confidence score with fallbacks."""
    signals = []

    # Each signal with weight
    fp_score = vulnerability.get('false_positive_score')
    if fp_score is not None:
        signals.append((1 - fp_score, 0.4))

    scanner_conf = vulnerability.get('confidence')
    if scanner_conf is not None:
        signals.append((scanner_conf, 0.2))

    # Return weighted average or default
    if not signals:
        return 0.5  # Unknown confidence

    total_weight = sum(w for _, w in signals)
    return sum(s * w for s, w in signals) / total_weight
```

---

## API Endpoint Standards

### URL Patterns
```
/api/v1/ml/<action>                    # Generic ML actions
/api/v1/ml/<resource>/{id}/<action>    # Resource-specific ML actions
```

### Examples
```
POST /api/v1/ml/predict-false-positive
POST /api/v1/ml/label-vulnerability
POST /api/v1/ml/retrain
GET  /api/v1/ml/model-stats

GET  /api/v1/ml/contracts/{id}/risk-score
GET  /api/v1/ml/scans/{id}/risk-score
GET  /api/v1/ml/scans/{id}/prioritized
GET  /api/v1/ml/vulnerabilities/{id}/similar
```

### Response Schema
All ML endpoints return structured responses:

```python
class RiskScoreResponse(BaseModel):
    score: int
    level: str
    breakdown: Dict[str, int]
    vulnerabilities_analyzed: int
    adjustments: List[str]
    calculated_at: datetime
```

---

## Testing Standards

### Unit Test Structure
```
tests/unit/ml/
├── __init__.py
├── test_risk_scorer.py
├── test_confidence_scorer.py
├── test_prioritizer.py
├── test_feature_extractor.py
├── test_false_positive_classifier.py
└── test_semantic_deduplicator.py
```

### Test Requirements
1. **Coverage**: Minimum 80% code coverage
2. **Edge cases**: Test empty inputs, None values, missing fields
3. **Boundary values**: Test score limits (0, 100, etc.)
4. **Mock external models**: Don't load real models in unit tests

### Mock Pattern for Models
```python
from unittest.mock import Mock, patch

def test_semantic_similarity():
    # Mock the sentence transformer model
    with patch.object(SemanticDeduplicator, '_load_model') as mock_load:
        mock_model = Mock()
        mock_model.encode.return_value = np.array([0.1, 0.2, 0.3])
        mock_load.return_value = mock_model

        deduplicator = SemanticDeduplicator()
        result = deduplicator.embed("test text")

        assert result.shape == (3,)
        mock_model.encode.assert_called_once_with("test text")
```

---

## Model Training Standards

### Training Data Requirements
| Model | Minimum Samples | Recommended | Balance |
|-------|-----------------|-------------|---------|
| FP Classifier | 200 | 500+ | ~50/50 TP/FP |

### Training Pipeline
1. Export labeled data from `vulnerability_classifications` table
2. Feature extraction using `FeatureExtractor`
3. Train with cross-validation
4. Evaluate on held-out test set
5. Save model with versioned filename

### Model Versioning
```
models/
├── fp_classifier_v1.joblib     # First trained model
├── fp_classifier_v2.joblib     # Improved model
└── fp_classifier_current.joblib -> fp_classifier_v2.joblib
```

### Performance Thresholds
| Metric | Minimum | Target |
|--------|---------|--------|
| Accuracy | 80% | 85%+ |
| AUC-ROC | 0.85 | 0.90+ |
| Precision | 0.80 | 0.85+ |
| Recall | 0.75 | 0.80+ |

---

## Feature Extraction Standards

### Feature Categories

**Scanner Features (10)**
- Scanner ID (one-hot)
- Detector ID hash
- Scanner confidence
- Tool consensus score
- Has dataflow trace
- Has call stack
- Scanner runtime
- Multiple detectors
- Finding count in contract
- Scanner version

**Code Context Features (10)**
- Lines of code
- Function visibility
- Has modifier
- Nesting depth
- Comment density
- TODO/FIXME keywords
- Uses unchecked block
- In test file
- Function name patterns
- Code complexity

**Pattern Features (10)**
- Pattern ID (embedding)
- Category (one-hot)
- Severity (ordinal)
- Historical FP rate
- Pattern confidence
- SWC ID present
- CWE ID present
- Description length
- Has remediation
- Affected lines count

---

## Dependencies

### Required Packages
```
scikit-learn>=1.3.0,<2.0.0      # Core ML
joblib>=1.3.0,<2.0.0            # Model serialization
numpy>=1.24.0,<2.0.0            # Numerical operations
sentence-transformers>=2.2.0    # Embeddings (CPU)
```

### Optional Packages
```
xgboost>=2.0.0                  # Better classifier (optional)
```

---

## Deployment Considerations

### Container Requirements
- Models included in Docker image OR mounted from volume
- No GPU drivers needed
- Memory: Allow 1GB headroom for model loading

### Environment Variables
```
ML_MODEL_PATH=/app/models           # Model storage path
ML_LAZY_LOAD=true                   # Lazy load models
ML_EMBEDDING_MODEL=all-MiniLM-L6-v2 # Embedding model name
```

### Health Checks
Include ML readiness in health endpoint:
```python
@router.get("/health")
async def health():
    return {
        "status": "healthy",
        "ml": {
            "risk_scorer": "ready",
            "confidence_scorer": "ready",
            "fp_classifier": "model_not_trained",  # or "ready"
            "semantic_deduplicator": "lazy_load"
        }
    }
```

---

## Related Documentation

- [Phase 5 AI/ML Features](/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/README.md)
- [Intelligence Integration Standards](./INTELLIGENCE-INTEGRATION-STANDARDS.md)
- [Testing Standards](./testing-deployment.md)
- [Core Development Rules](./core-development-rules.md)
