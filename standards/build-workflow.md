# Build Workflow

**Version:** 2.0.0
**Last Updated:** December 13, 2025

## Overview

```
Local Docker → Harbor Proxy (socat) → Harbor Registry → Kubernetes pulls from Harbor
```

Build locally (fast), push to Harbor via socat proxy, Kubernetes pulls the image.

## Prerequisites

### Harbor Proxy Setup

Docker Desktop cannot directly reach minikube's network. A socat container bridges the connection.

**One-time setup:**

1. Add Harbor to Docker's insecure registries (`~/.docker/daemon.json`):
```json
{
  "insecure-registries": ["localhost:5443"]
}
```

2. Restart Docker Desktop

3. Start the Harbor proxy:
```bash
docker run -d --name harbor-proxy --restart always \
  --network minikube \
  -p 5443:5443 \
  alpine/socat:latest \
  TCP-LISTEN:5443,fork,reuseaddr TCP:192.168.49.2:30443
```

**Verify connectivity:**
```bash
curl -k https://localhost:5443/v2/
# Should return: {"errors":[{"code":"UNAUTHORIZED",...}]}
```

## Build and Deploy

```bash
# 1. Build
docker build -t <service>:<version> -f <service>/Dockerfile .

# 2. Tag for Harbor (via proxy)
docker tag <service>:<version> localhost:5443/blocksecops/<service>:<version>

# 3. Push to Harbor
docker push localhost:5443/blocksecops/<service>:<version>

# 4. Update kustomization.yaml with new version tag
#    - Update images[].newTag
#    - Update labels app.kubernetes.io/version

# 5. Apply
kubectl apply -k k8s/overlays/local/<service>/
```

## Kustomization Image Reference

Kubernetes pulls from Harbor using the ClusterIP (internal to cluster):

```yaml
# k8s/overlays/local/<service>/kustomization.yaml
images:
- name: <service>
  newName: 10.106.241.219:443/blocksecops/<service>
  newTag: "<version>"
```

Get Harbor's ClusterIP: `kubectl get svc harbor -n harbor-local -o jsonpath='{.spec.clusterIP}'`

## Using Build Cache

```bash
docker build \
  --cache-from=localhost:5443/blocksecops/<service>:<previous-version> \
  -t <service>:<new-version> \
  -f <service>/Dockerfile .
```

## Why Local Docker (Not Minikube Docker)

| Local Docker | Minikube Docker (`eval $(minikube docker-env)`) |
|--------------|------------------------------------------------|
| Full system resources | Limited container resources |
| Fast builds | Slow builds |
| Harbor provides caching | No registry caching |

Only use minikube's Docker for debugging:

```bash
eval $(minikube docker-env)
docker images | grep <service>
```

## Troubleshooting

### Harbor proxy not running
```bash
docker ps | grep harbor-proxy
# If not running:
docker start harbor-proxy
# Or recreate it (see Prerequisites)
```

### Certificate errors on push
Ensure `localhost:5443` is in Docker's insecure-registries and Docker was restarted.

### Connection timeout
Check socat container is on minikube network:
```bash
docker inspect harbor-proxy --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}'
# Should output: minikube
```
