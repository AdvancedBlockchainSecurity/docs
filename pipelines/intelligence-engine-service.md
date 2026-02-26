# Intelligence Engine Service Pipeline

**Last Updated:** February 2026
**Service:** intelligence-engine
**Version:** 0.3.3

---

## Overview

The Intelligence Engine is a standalone FastAPI microservice that provides semantic embedding generation for the BlockSecOps platform. It powers Level 5 (semantic) deduplication matching by generating 384-dimensional vectors from vulnerability text.

```
API Service                Intelligence Engine              SentenceTransformer
──────────                 ───────────────────              ───────────────────
POST /api/v1/embeddings →  Sanitize input texts        →   all-MiniLM-L6-v2
                           Validate batch constraints       Encode to 384-dim vectors
                      ←    Return embedding vectors    ←   numpy → list[float]
```

## Architecture

| Component | Detail |
|-----------|--------|
| Framework | FastAPI + Uvicorn |
| ML Library | sentence-transformers (CPU-only) |
| Model | `all-MiniLM-L6-v2` (384 dimensions, ~80MB) |
| Port | 8000 (HTTP) / 9090 (Prometheus metrics) |
| Replicas | 2 (pod anti-affinity across nodes) |
| Base Image | `blocksecops-intelligence-base-cpu:1.0.0-5ede3c61` |

## Build Pipeline

### Prerequisites

- Pre-built base image in Harbor with ML dependencies (torch, sentence-transformers, numpy, scipy, scikit-learn)
- Base image only needs rebuilding when ML dependency versions change

### Build Steps

```bash
cd /home/pwner/Git/blocksecops-intelligence-engine

VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# Build (base image provides ML deps; app image adds source + pre-downloaded model)
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/intelligence-engine:${VERSION} .

# Push to Harbor (immutable tags)
docker push ${REGISTRY}/blocksecops/intelligence-engine:${VERSION}

# Deploy
kubectl apply -k k8s/overlays/local/intelligence-engine/
kubectl rollout status deployment/intelligence-engine -n intelligence-engine-local
```

### Docker Multi-Stage Build

```
Stage 1: builder
  FROM blocksecops-intelligence-base-cpu (has torch, sentence-transformers)
  → pip install application dependencies from requirements/base.txt

Stage 2: runtime
  FROM blocksecops-intelligence-base-cpu
  → Copy pip packages from builder
  → Copy src/ application code
  → Pre-download all-MiniLM-L6-v2 to /opt/ml-models
  → Set HF_HUB_OFFLINE=1
  → USER appuser
```

### ML Model Handling

The `all-MiniLM-L6-v2` model is **pre-downloaded during Docker build** to `/opt/ml-models`. This avoids ~80MB HuggingFace downloads on every pod restart.

**Why `/opt/ml-models` and not `/app/models`?**
- K8s mounts an `emptyDir` volume at `/app/models` (for write access on read-only root filesystem)
- The emptyDir shadows any files baked into the image at that path
- An `initContainer` copies from `/opt/ml-models` to `/app/models` before the main container starts

```
Docker Build:  model → /opt/ml-models (persists in image)
initContainer: cp /opt/ml-models/. → /app/models (emptyDir)
Main Container: loads model from /app/models
HF_HUB_OFFLINE=1: blocks all runtime HuggingFace network calls
```

## Kubernetes Resources

| Resource | File | Purpose |
|----------|------|---------|
| Deployment | `k8s/base/intelligence-engine/deployment.yaml` | 2 replicas, initContainer, security contexts |
| Service | `k8s/base/intelligence-engine/service.yaml` | ClusterIP on port 80 → targetPort 8000 |
| ConfigMap | `k8s/base/intelligence-engine/configmap.yaml` | Environment, log level, model path |
| NetworkPolicy | `k8s/base/intelligence-engine/networkpolicy.yaml` | Default-deny with allow rules |
| ServiceAccount | `k8s/base/intelligence-engine/serviceaccount.yaml` | Minimal RBAC |
| ExternalSecret | `k8s/overlays/local/.../externalsecret.yaml` | Vault-sourced secrets |

### Security Posture

| Control | Value |
|---------|-------|
| runAsNonRoot | true |
| runAsUser | 1000 |
| readOnlyRootFilesystem | true |
| allowPrivilegeEscalation | false |
| capabilities | drop ALL |
| seccompProfile | RuntimeDefault |
| NetworkPolicy | default-deny ingress/egress with explicit allow rules |
| revisionHistoryLimit | 3 |

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Service info (name, version, status) |
| GET | `/health` | Liveness probe |
| GET | `/ready` | Readiness probe |
| GET | `/startup` | Startup probe |
| POST | `/api/v1/embeddings` | Generate embeddings for text batch |
| GET | `/api/v1/embeddings/health` | Embedding service health + model status |
| GET | `/api/v1/embeddings/info` | Model configuration and available models |
| GET | `/docs` | OpenAPI documentation |
| GET | `/redoc` | ReDoc documentation |

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `ENVIRONMENT` | `development` | Runtime environment |
| `LOG_LEVEL` | `INFO` | Logging level |
| `PORT` | `8000` | HTTP listen port |
| `ML_MODEL_PATH` | `/app/models` | Model storage directory |
| `EMBEDDING_PROVIDER` | `local` | Provider: `local` or `openai` |
| `EMBEDDING_MODEL_LOCAL` | `all-MiniLM-L6-v2` | Local model name |
| `EMBEDDING_MAX_BATCH_SIZE` | `100` | Max texts per request |
| `EMBEDDING_MAX_TEXT_LENGTH` | `8192` | Max characters per text |
| `EMBEDDING_RATE_LIMIT_PER_MINUTE` | `100` | Rate limit |
| `HF_HUB_OFFLINE` | `1` | Block HuggingFace network calls |

## Version History

| Version | Change |
|---------|--------|
| 0.3.3 | Pre-download ML model into image, initContainer copy, HF_HUB_OFFLINE=1 |
| 0.3.2 | Security audit: pydantic bump, ML pin loosening |
| 0.3.1 | Initial deployment with embedding endpoints |

## Related Documentation

- [Intelligence Pipeline](./intelligence-pipeline.md) — API-service side pipeline that calls this service
- [Intelligence Pipeline Workflow](../workflows/intelligence-pipeline-workflow.md) — Full pipeline workflow
- [Intelligence Engine Workflow](../workflows/intelligence-engine-workflow.md) — Service-specific workflow
- [Docker Base Images](../standards/docker-base-images.md) — Base image build process
- [ML Development Standards](../standards/ml-development.md) — ML architecture and patterns
