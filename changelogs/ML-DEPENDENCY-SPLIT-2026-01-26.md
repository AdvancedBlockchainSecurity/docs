# ML Dependency Split - API Service to Intelligence Engine

**Date:** January 26, 2026
**Services:** api-service (0.13.4), intelligence-engine (0.2.1)
**Type:** Architecture / Performance

## Summary

Moved ML dependencies (sentence-transformers, PyTorch) from api-service to intelligence-engine, reducing api-service image size from 12.6GB to 934MB (93% reduction).

## Problem

The api-service Docker image was 12.6GB because it included `sentence-transformers` which pulls in PyTorch (~2GB). The api-service should be a lightweight HTTP gateway, not an ML service.

## Solution

1. Created `/api/v1/embeddings` endpoint in intelligence-engine
2. Refactored api-service `semantic_deduplicator.py` to use HTTP client
3. Removed sentence-transformers from api-service requirements
4. Added httpx for HTTP client calls

## Architecture

```
BEFORE:
┌─────────────────────────────────────┐
│ api-service (12.6GB)                │
│ - sentence-transformers/PyTorch     │
│ - semantic_deduplicator.py (local)  │
└─────────────────────────────────────┘

AFTER:
┌─────────────────────────────────────┐
│ api-service (934MB)                 │
│ - httpx HTTP client                 │
└─────────────────┬───────────────────┘
                  │ POST /api/v1/embeddings
                  ▼
┌─────────────────────────────────────┐
│ intelligence-engine (3GB)           │
│ - SentenceTransformer model         │
│ - 384-dim vector embeddings         │
└─────────────────────────────────────┘
```

## Changes

### Intelligence Engine (0.2.1)

| File | Change |
|------|--------|
| `src/api/embeddings.py` | New embeddings endpoint |
| `src/main.py` | Register embeddings router |
| `pyproject.toml` | 0.2.0 → 0.2.1 |
| `k8s/overlays/local/kustomization.yaml` | newTag: 0.2.1 |

### API Service (0.13.4)

| File | Change |
|------|--------|
| `src/ml/semantic_deduplicator.py` | HTTP client instead of local model |
| `requirements/base.txt` | Removed sentence-transformers, added httpx |
| `Dockerfile` | Fixed UID to 1000, added HOME env |
| `pyproject.toml` | 0.13.3 → 0.13.4 |
| `k8s/overlays/local/api-service/kustomization.yaml` | newTag: 0.13.4 |

## API Endpoint

**POST /api/v1/embeddings**

Request:
```json
{
  "texts": ["reentrancy vulnerability", "integer overflow"]
}
```

Response:
```json
{
  "embeddings": [[0.123, 0.456, ...], [0.789, 0.012, ...]],
  "model": "all-MiniLM-L6-v2",
  "dimensions": 384
}
```

## Verification

| Test | Result |
|------|--------|
| Dashboard (http://app.0xapogee.local/) | PASS |
| API Health (v0.13.4) | PASS |
| API Scanners (15 scanners) | PASS |
| Intelligence Embeddings (384-dim vectors) | PASS |

## Breaking Changes

None. The semantic deduplication API is unchanged - only the implementation (HTTP vs local) changed.

## Issues Fixed

1. **Dockerfile UID Mismatch**: Kubernetes `securityContext.runAsUser: 1000` didn't match Dockerfile `useradd -r` (UID 999). Fixed by using `--uid 1000 --gid 1000`.

2. **Missing HOME environment**: Python couldn't find packages in `/home/appuser/.local/` because HOME wasn't set. Fixed by adding `HOME="/home/appuser"` to ENV.

## Subsequent Optimization (February 8, 2026)

The intelligence-engine image was further reduced from ~3GB to **1.89GB** (base image: 12.1GB → 1.85GB) by removing 13 unused ML packages (TensorFlow, spacy, pandas, etc.), switching to CPU-only PyTorch, and using multi-stage builds. See [PLAN-2026-02-08-INTELLIGENCE-ENGINE-DOCKER-SLIM.md](/home/pwner/Git/TaskDocs-Apogee/PLAN-2026-02-08-INTELLIGENCE-ENGINE-DOCKER-SLIM.md).

## Related

- [ML-DEPENDENCY-SPLIT-PLAN.md](/home/pwner/Git/TaskDocs-Apogee/phases/03-phase-4-intelligence/ML-DEPENDENCY-SPLIT-PLAN.md)
- [Docker Base Images Standards](/home/pwner/Git/docs/standards/docker-base-images.md)
