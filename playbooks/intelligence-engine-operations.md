# Intelligence Engine Operations Playbook

**Last Updated:** February 2026
**Service:** intelligence-engine
**Version:** 0.3.3

---

## Quick Reference

| Item | Value |
|------|-------|
| Namespace | `intelligence-engine-local` |
| Replicas | 2 |
| Container Port | 8000 |
| Service Port | 80 |
| Metrics Port | 9090 |
| External Access | `https://app.0xapogee.com` (via Traefik, not directly exposed) |
| Internal URL | `http://intelligence-engine.intelligence-engine-local.svc.cluster.local:80` |
| Image | `harbor.blocksecops.local/blocksecops/intelligence-engine:0.3.3` |
| Base Image | `blocksecops-intelligence-base-cpu:1.0.0-5ede3c61` |

---

## Health Checks

### Quick Status

```bash
# Pod status
kubectl get pods -n intelligence-engine-local

# Detailed pod info
kubectl describe pod -n intelligence-engine-local -l app.kubernetes.io/name=intelligence-engine

# Service health (via internal port-forward)
kubectl port-forward -n intelligence-engine-local svc/intelligence-engine 8002:80 &
curl -s http://127.0.0.1:8002/health | jq
curl -s http://127.0.0.1:8002/api/v1/embeddings/health | jq
curl -s http://127.0.0.1:8002/api/v1/embeddings/info | jq
```

### Verify Model Is Loaded

```bash
# Check embeddings health — model_loaded should be true
curl -s http://127.0.0.1:8002/api/v1/embeddings/health | jq '.model_loaded'

# Check logs for model loading (should say "loaded from local cache", no download)
kubectl logs -n intelligence-engine-local -l app.kubernetes.io/name=intelligence-engine --tail=50 | grep -i model
```

### Test Embedding Generation

```bash
curl -s -X POST http://127.0.0.1:8002/api/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"texts": ["reentrancy vulnerability in withdraw function"]}' | jq '{model, provider, dimensions, processing_time_ms, embedding_count: (.embeddings | length)}'
```

Expected output:
```json
{
  "model": "all-MiniLM-L6-v2",
  "provider": "local",
  "dimensions": 384,
  "processing_time_ms": 30,
  "embedding_count": 1
}
```

---

## Troubleshooting

### Pod CrashLoopBackOff

**Symptoms:** Pod restarts repeatedly, never reaches Ready state.

1. Check logs:
   ```bash
   kubectl logs -n intelligence-engine-local -l app.kubernetes.io/name=intelligence-engine --previous
   ```

2. Check initContainer logs (model copy):
   ```bash
   kubectl logs -n intelligence-engine-local -l app.kubernetes.io/name=intelligence-engine -c load-ml-models
   ```

3. Common causes:
   - **initContainer failed:** Model files missing from image at `/opt/ml-models`
   - **OOM kill:** Check `kubectl describe pod` for `OOMKilled` — increase memory limits
   - **Port conflict:** Another service using port 8000 in the container

### Model Not Loading

**Symptoms:** `/api/v1/embeddings/health` shows `model_loaded: false`, first POST request fails.

1. Verify model files exist in pod:
   ```bash
   POD=$(kubectl get pods -n intelligence-engine-local -l app.kubernetes.io/name=intelligence-engine -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n intelligence-engine-local $POD -- ls -la /app/models/
   ```

2. Verify `HF_HUB_OFFLINE=1` is set:
   ```bash
   kubectl exec -n intelligence-engine-local $POD -- env | grep HF_HUB
   ```

3. If model files are missing, check initContainer:
   ```bash
   kubectl logs -n intelligence-engine-local $POD -c load-ml-models
   ```

4. If initContainer shows empty `/opt/ml-models`, rebuild the image:
   ```bash
   cd /home/pwner/Git/blocksecops-intelligence-engine
   # Bump version, rebuild with model download
   docker build --no-cache \
     --build-arg SERVICE_VERSION=${VERSION} \
     --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
     --build-arg VCS_REF=$(git rev-parse --short HEAD) \
     -t ${REGISTRY}/blocksecops/intelligence-engine:${VERSION} .
   ```

### High Latency on Embedding Requests

**Symptoms:** `processing_time_ms` > 500ms for single texts.

1. **First request is slow (cold start):** Normal — model loads lazily on first POST request. Subsequent requests should be <100ms.

2. **All requests slow:**
   - Check CPU limits: `kubectl top pods -n intelligence-engine-local`
   - If CPU is throttled, increase limits in deployment patch
   - Check if pod is on an overloaded node: `kubectl top nodes`

3. **Batch requests slow:**
   - Large batches (50-100 texts) take longer — this is expected
   - Consider splitting into smaller batches from the caller

### Startup Probe Timeout

**Symptoms:** Pod killed before becoming ready, events show "startup probe failed".

The startup probe allows 140 seconds total (20s initial + 12 failures * 10s period). If this isn't enough:

1. Check if model download is happening at runtime (should NOT with HF_HUB_OFFLINE=1):
   ```bash
   kubectl logs -n intelligence-engine-local -l app.kubernetes.io/name=intelligence-engine | grep -i "download\|huggingface"
   ```

2. If downloading at runtime, the image was built without the model pre-download step. Rebuild the image.

### Network Policy Issues

**Symptoms:** API Service cannot reach Intelligence Engine, connection timeouts.

1. Verify NetworkPolicy allows ingress from api-service:
   ```bash
   kubectl get networkpolicy -n intelligence-engine-local -o yaml
   ```

2. Test connectivity from api-service pod:
   ```bash
   API_POD=$(kubectl get pods -n api-service-local -l app.kubernetes.io/name=api-service -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n api-service-local $API_POD -- curl -s http://intelligence-engine.intelligence-engine-local.svc.cluster.local:80/health
   ```

---

## Scaling

### Horizontal Scaling

The service runs 2 replicas by default with pod anti-affinity. To scale:

```bash
# Temporary scale (not persisted in Git)
kubectl scale deployment intelligence-engine -n intelligence-engine-local --replicas=3

# Permanent scale (codebase-first)
# Edit k8s/overlays/local/intelligence-engine/deployment-patch.yaml
# Add: spec.replicas: 3
# Then: kubectl apply -k k8s/overlays/local/intelligence-engine/
```

### Resource Tuning

Current limits:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 500m | 1000m |
| Memory | 1Gi | 2Gi |

The model uses ~500MB memory when loaded. With overhead, 1Gi request is appropriate. Increase limits if seeing OOM kills during batch processing.

---

## Version Upgrade

1. Update `pyproject.toml` version
2. Update `k8s/overlays/local/intelligence-engine/kustomization.yaml` newTag
3. Build with build args, push to Harbor
4. `kubectl apply -k` and verify rollout
5. Test embedding endpoint
6. Commit and PR

See [Intelligence Engine Pipeline](../pipelines/intelligence-engine-service.md) for full build steps.

---

## Related Documentation

- [Intelligence Engine Pipeline](../pipelines/intelligence-engine-service.md) — Build and deploy pipeline
- [Intelligence Engine Workflow](../workflows/intelligence-engine-workflow.md) — Embedding generation flow
- [Deploy New Image](./deploy-new-image.md) — General image deployment playbook
- [ML Development Standards](../standards/ml-development.md) — ML architecture
