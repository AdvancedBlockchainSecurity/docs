# Orchestration Docker Dependency Removal

**Date:** January 31, 2026
**Version:** Orchestration 0.9.3
**Type:** Bug Fix / Architecture Improvement

## Summary

Removed Docker CLI dependency from orchestration service. The service was failing to start because it tried to run `docker image inspect` commands in a Kubernetes environment using containerd.

## Problem

```
PermissionError: [Errno 13] Permission denied: 'docker'
ERROR:    Application startup failed. Exiting.
```

The `_check_docker_image_exists()` function attempted to verify scanner images using Docker CLI, which:
1. Doesn't exist in containerd environments
2. Requires Docker socket access (security concern)
3. Isn't needed in Kubernetes (image pulls are handled by kubelet)

## Solution

Replaced `_check_docker_image_exists()` with `_check_scanner_image_available()`:

```python
def _check_scanner_image_available(image_name: str) -> bool:
    """
    Check if a scanner image is available.

    In Kubernetes environments, images are pulled by the container runtime
    (containerd) when Jobs are created. We don't need to verify availability
    at startup - Kubernetes will report ImagePullBackOff if unavailable.
    """
    known_images = set(SOLANA_SCANNER_IMAGES.values())
    if image_name in known_images:
        logger.debug("scanner_image_registered", image=image_name)
        return True
    return True  # Let Kubernetes verify at Job creation time
```

## Benefits

| Aspect | Before | After |
|--------|--------|-------|
| Docker dependency | Required | None |
| Startup reliability | Failed in K8s | Always succeeds |
| Security | Needed Docker socket | No special permissions |
| GCP compatibility | Would fail | Works with Artifact Registry |

## File Changed

`src/blocksecops_orchestration/scanners/solana_scanners.py`

## Verification

```bash
kubectl get pods -n orchestration-local
# orchestration-xxx   4/4     Running   0

kubectl logs -n orchestration-local deployment/orchestration -c orchestration-api --tail=5
# scanner_image_registered image=scanner-sol-azy:latest
# GET /api/v1/health/ready HTTP/1.1" 200 OK
```

## Related

- Version: 0.9.3
- Image: `harbor.blocksecops.local/blocksecops/orchestration:0.9.3`
