# Phase 5: AI/ML Features - Planning Complete

**Date**: December 27, 2025
**Status**: PLANNING COMPLETE - Ready for Implementation
**Timeline**: 1-2 weeks (6-9 days)
**Monthly Cost**: ~$1 (CPU-only, no LLM/GPU)

---

## Executive Summary

Phase 5 implements **CPU-only ML features** that differentiate Apogee without incurring LLM API or GPU costs. All models run on existing infrastructure using scikit-learn, XGBoost, and Sentence Transformers.

---

## Key Decision: No LLM Costs

**Rejected Approaches**:
- OpenAI API: $50-200/month
- Self-hosted Ollama (GPU): $380-870/month
- AWS Bedrock: $100-500/month

**Chosen Approach**: CPU-only ML
- scikit-learn classifiers: $0
- Sentence Transformers: $0
- Training: Local/existing pods
- **Total: ~$1/month** (model storage only)

---

## Features Planned

### 1. False Positive Detection
- **What**: Predict probability (0.0-1.0) that a finding is a false positive
- **How**: Random Forest/XGBoost classifier with 30+ features
- **Requires**: 200-500 labeled vulnerabilities for training

### 2. Risk Scoring
- **What**: Aggregate risk score (0-100) for contracts/projects
- **How**: Weighted formula (no ML training needed)
- **Levels**: CRITICAL (80-100), HIGH (60-79), MEDIUM (40-59), LOW (0-39)

### 3. Confidence Scoring
- **What**: Per-finding confidence: "85% likely true positive"
- **How**: Weighted combination of FP score, scanner confidence, consensus
- **Display**: Percentage with color coding

### 4. Semantic Deduplication
- **What**: Find similar vulnerabilities using embeddings
- **How**: Sentence Transformers `all-MiniLM-L6-v2` (80MB, CPU)
- **Storage**: Base64 in existing `fingerprint_semantic` field

### 5. Smart Prioritization
- **What**: Rank vulnerabilities by what to fix first
- **How**: Composite score (severity × confidence × FP factor + boosts)
- **Display**: Priority badges (#1, #2, #3)

---

## Implementation Order

### Phase A: No Training Data Required (Days 1-4)
1. ML Infrastructure setup
2. Risk Scoring (weighted formula)
3. Confidence Scoring (multi-signal)
4. Smart Prioritization (composite score)

### Phase B: Requires Training Data (Days 5-8)
5. Data Labeling (200-500 vulnerabilities)
6. Feature Extractor (30+ features)
7. False Positive Classifier (train + deploy)

### Phase C: Enhancement (Days 8-9)
8. Semantic Deduplication
9. Testing & Documentation

---

## New API Endpoints

```
POST /api/v1/ml/predict-false-positive
POST /api/v1/ml/label-vulnerability
POST /api/v1/ml/retrain
GET  /api/v1/ml/model-stats

GET  /api/v1/contracts/{id}/risk-score
GET  /api/v1/projects/{id}/risk-score
GET  /api/v1/scans/{id}/risk-score

GET  /api/v1/vulnerabilities/{id}/similar
```

---

## Files to Create

```
blocksecops-api-service/src/ml/
├── __init__.py
├── feature_extractor.py
├── false_positive_classifier.py
├── risk_scorer.py
├── confidence_scorer.py
├── semantic_deduplicator.py
├── prioritizer.py
└── models/
    └── .gitkeep

blocksecops-api-service/src/presentation/api/v1/endpoints/ml.py
```

---

## Dependencies

```
scikit-learn>=1.3.0
xgboost>=2.0.0
sentence-transformers>=2.2.0
joblib>=1.3.0
numpy>=1.24.0
```

---

## Success Metrics

| Metric | Target |
|--------|--------|
| FP Classifier Accuracy | >85% |
| FP Classifier AUC | >0.90 |
| Inference Latency | <100ms per vulnerability |
| Embedding Generation | <50ms per vulnerability |
| Model Size | <50MB total |

---

## Database Fields (Already Exist)

The database already has ML-ready fields:
- `false_positive_score` (float 0.0-1.0)
- `classification_confidence` (float)
- `classification_method` (str: "rule_based", "ml_based", "hybrid")
- `fingerprint_semantic` (str for embedding storage)
- `tool_consensus_score` (float)

No new tables required for Phase 5.

---

## Documentation Created

| File | Location |
|------|----------|
| README.md | `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/` |
| PHASE-5-CPU-ML-PLAN.md | `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/` |
| DATA-LABELING-GUIDE.md | `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/` |
| TASK-1-ML-INFRASTRUCTURE.md | `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/` |
| TASK-2-FALSE-POSITIVE-DETECTION.md | `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/` |
| TASK-3-RISK-SCORING.md | `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/` |
| TASK-4-SEMANTIC-DEDUPLICATION.md | `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/` |
| TASK-5-SMART-PRIORITIZATION.md | `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/` |

---

## Prerequisites

- Phase 4.5 Complete (done)
- 200-500 labeled vulnerabilities for FP classifier
- Python ML dependencies installed

---

## Next Steps

1. Start with TASK-1: ML Infrastructure
2. Implement Risk Scoring (no training data needed)
3. Begin labeling vulnerabilities in parallel
4. Train FP classifier once labeled data available

---

**Last Updated**: December 27, 2025
