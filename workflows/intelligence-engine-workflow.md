# Intelligence Engine Service Workflow

**Last Updated:** February 2026
**Status:** Active

---

## Overview

The Intelligence Engine is a standalone embedding generation microservice. It receives text from the API Service and returns 384-dimensional semantic vectors used for Level 5 deduplication matching.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     INTELLIGENCE ENGINE                              │
│                                                                     │
│  ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐    │
│  │  Receive   │ → │ Sanitize  │ → │   Encode  │ → │  Return   │    │
│  │   Texts    │   │  & Valid  │   │  Vectors  │   │ Embeddings│    │
│  └───────────┘   └───────────┘   └───────────┘   └───────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Services Involved

| Service | Role | Port |
|---------|------|------|
| Intelligence Engine | Embedding generation | 8002 (external) / 8000 (container) |
| API Service | Caller — sends texts for embedding during scan processing | 8000 |
| PostgreSQL | Not directly accessed by IE | 5432 |

---

## Embedding Generation Flow

### 1. Request Reception

The API Service sends a batch of vulnerability texts to the embedding endpoint:

```bash
POST /api/v1/embeddings
Content-Type: application/json

{
  "texts": [
    "Reentrancy vulnerability in withdraw() function allows attacker to drain contract",
    "Unchecked return value from low-level call in transfer()"
  ]
}
```

### 2. Input Validation & Sanitization

Before processing, all texts are validated and sanitized:

| Check | Limit | Action |
|-------|-------|--------|
| Batch size | max 100 texts | 400 error if exceeded |
| Text length | max 8192 characters | Truncated silently |
| Empty texts | not allowed | 400 error |
| Control characters | removed | `\x00-\x08`, `\x0b`, `\x0c`, `\x0e-\x1f`, `\x7f-\x9f` stripped |
| Whitespace | normalized | Collapsed to single spaces |

### 3. Model Loading (Lazy)

The SentenceTransformer model is loaded on first request:

- Model files are at `/app/models` (copied from `/opt/ml-models` by initContainer)
- `HF_HUB_OFFLINE=1` ensures no network calls — model must be available locally
- Once loaded, the model stays in memory for subsequent requests
- Model uses CPU only (no GPU required)

### 4. Encoding

```python
embeddings = model.encode(texts, convert_to_numpy=True, show_progress_bar=False)
```

| Parameter | Value |
|-----------|-------|
| Model | all-MiniLM-L6-v2 |
| Output dimensions | 384 |
| Output type | `list[list[float]]` |
| Inference device | CPU |
| Target latency | <100ms for single text |

### 5. Response

```json
{
  "embeddings": [[0.0123, -0.0456, ...], [0.0789, -0.0321, ...]],
  "model": "all-MiniLM-L6-v2",
  "provider": "local",
  "dimensions": 384,
  "processing_time_ms": 42
}
```

---

## Integration with Intelligence Pipeline

The API Service's `SemanticDeduplicator` calls the Intelligence Engine during Level 5 deduplication:

1. **Scan results arrive** at API Service
2. Pipeline processes through Levels 1-4 (fingerprint-based)
3. Unmatched findings are sent to Intelligence Engine for embedding
4. Returned vectors are compared using cosine similarity
5. Findings with similarity > threshold are grouped as duplicates

**Internal Service URL:**
```
http://intelligence-engine.intelligence-engine-local.svc.cluster.local:80
```

---

## Provider Configuration

### Local Provider (Default)

Uses SentenceTransformer models running on CPU. No external API calls.

| Model | Dimensions | Size | Quality |
|-------|-----------|------|---------|
| all-MiniLM-L6-v2 | 384 | 80MB | Good (default) |
| all-mpnet-base-v2 | 768 | 420MB | Better |
| bge-large-en-v1.5 | 1024 | 1.3GB | High |

### OpenAI Provider (Optional)

Uses OpenAI embedding API. Requires `OPENAI_API_KEY`.

| Model | Dimensions | Quality |
|-------|-----------|---------|
| text-embedding-3-small | 1536 | High |
| text-embedding-3-large | 3072 | Highest |

Switch provider via environment variable:
```yaml
EMBEDDING_PROVIDER: "openai"  # or "local" (default)
```

---

## Monitoring

### Prometheus Metrics

Metrics are exposed on port 9090 (started in `startup_event`):

- `http_request_duration_seconds` — Request latency histogram
- `http_requests_total` — Request count by method, endpoint, status

### Health Endpoints

| Endpoint | Probe | What It Checks |
|----------|-------|----------------|
| `/health` | Liveness | Service is running |
| `/ready` | Readiness | Service can accept requests |
| `/startup` | Startup | Service has initialized |
| `/api/v1/embeddings/health` | Application | Model loaded status, provider config |

### Probe Configuration

| Probe | Initial Delay | Period | Timeout | Failure Threshold |
|-------|---------------|--------|---------|-------------------|
| Startup | 20s | 10s | 5s | 12 (allows 140s total startup) |
| Readiness | 10s | 10s | 5s | 3 |
| Liveness | 45s | 30s | 10s | 5 |

---

## Deployment Workflow

### Standard Deployment

```bash
cd /home/pwner/Git/blocksecops-intelligence-engine

# 1. Update version
VERSION="X.Y.Z"
sed -i "s/version = \".*\"/version = \"${VERSION}\"/" pyproject.toml

# 2. Update kustomize
sed -i "s/newTag: \".*\"/newTag: \"${VERSION}\"/" k8s/overlays/local/intelligence-engine/kustomization.yaml

# 3. Build and push
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/intelligence-engine:${VERSION} .
docker push ${REGISTRY}/blocksecops/intelligence-engine:${VERSION}

# 4. Deploy and verify
kubectl apply -k k8s/overlays/local/intelligence-engine/
kubectl rollout status deployment/intelligence-engine -n intelligence-engine-local
```

### Verify Deployment

```bash
# Check pods
kubectl get pods -n intelligence-engine-local

# Check image version
kubectl get deployment intelligence-engine -n intelligence-engine-local \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check initContainer image
kubectl get deployment intelligence-engine -n intelligence-engine-local \
  -o jsonpath='{.spec.template.spec.initContainers[0].image}'

# Check logs (should show no HuggingFace downloads)
kubectl logs -n intelligence-engine-local -l app.kubernetes.io/name=intelligence-engine --tail=30

# Test endpoint
curl -sk https://app.0xapogee.local/api/v1/health/ready
```

---

## Related Documentation

- [Intelligence Engine Pipeline](../pipelines/intelligence-engine-service.md) — Build pipeline details
- [Intelligence Pipeline](../pipelines/intelligence-pipeline.md) — API-service pipeline that calls this service
- [Intelligence Engine Playbook](../playbooks/intelligence-engine-operations.md) — Operational troubleshooting
- [ML Development Standards](../standards/ml-development.md) — ML architecture and patterns
- [Docker Base Images](../standards/docker-base-images.md) — Base image build process
