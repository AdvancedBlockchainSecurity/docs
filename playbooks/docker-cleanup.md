# Playbook: Docker Cleanup

**Version:** 1.0.0
**Last Updated:** January 26, 2026

## Overview

This playbook covers safely cleaning up Docker images and build cache without affecting images stored in Harbor or currently in use by the Kubernetes cluster.

---

## Quick Reference

```bash
# Check current usage
docker system df

# Safe cleanup (dangling + build cache)
/home/pwner/Git/blocksecops-orchestration/scripts/docker-cleanup.sh

# Full cleanup (includes old tagged images)
/home/pwner/Git/blocksecops-orchestration/scripts/docker-cleanup.sh --full

# Preview only (no changes)
/home/pwner/Git/blocksecops-orchestration/scripts/docker-cleanup.sh --dry-run
```

---

## Understanding Docker Storage

### What Takes Up Space

| Type | Description | Reclaimable |
|------|-------------|-------------|
| Images | Pulled/built images | Yes (if unused) |
| Containers | Stopped containers | Yes |
| Build Cache | BuildKit layer cache | Yes |
| Volumes | Persistent data | Careful! |

### Check Current Usage

```bash
# Overall Docker disk usage
docker system df

# Detailed breakdown
docker system df -v
```

---

## Safe Cleanup (Recommended)

The cleanup script protects critical images automatically:

```bash
./scripts/docker-cleanup.sh
```

### What Gets Removed

- Dangling images (untagged `<none>:<none>`)
- Build cache (BuildKit layers)

### What Gets Protected

- All Harbor-tagged images (`harbor.blocksecops.local/blocksecops/*`)
- Base images (`blocksecops-*-base`)
- Kubernetes system images (`registry.k8s.io/*`)
- Infrastructure (Vault, Traefik, Postgres, Redis, Harbor)
- Images currently in use by cluster pods

---

## Full Cleanup

For aggressive cleanup including old tagged images:

```bash
./scripts/docker-cleanup.sh --full
```

### What Gets Removed

Everything from safe cleanup, plus:
- Old versions of application images not in use
- Python/Node base images if not referenced

### Preview First

Always preview before full cleanup:

```bash
./scripts/docker-cleanup.sh --full --dry-run
```

---

## Manual Cleanup Commands

### Remove Dangling Images

```bash
docker image prune -f
```

### Remove Build Cache

```bash
docker builder prune -f
```

### Remove Specific Image

```bash
docker rmi harbor.blocksecops.local/blocksecops/api-service:0.11.0
```

### Remove All Unused Images (DANGEROUS)

```bash
# WARNING: Removes all images not used by running containers
docker image prune -a -f
```

---

## Harbor Storage

**Important:** Harbor images are stored separately in Harbor's registry storage (`/data/registry` on the Harbor pod). Docker cleanup commands do NOT affect Harbor storage.

### Verify Harbor Images After Cleanup

```bash
# List images in Harbor
curl -s -k https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories | jq -r '.[].name'

# Check specific image
curl -s -k https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories/api-service/artifacts | jq -r '.[].tags[].name'
```

### Pull Image Back from Harbor

If you accidentally removed a needed image:

```bash
docker pull harbor.blocksecops.local/blocksecops/api-service:0.13.2
```

---

## Cluster Image Verification

### Check Images in Use

```bash
kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u
```

### Verify Image Exists for Pod

```bash
# If pod shows ImagePullBackOff
kubectl describe pod <pod-name> -n <namespace>

# Check if image exists locally
docker images | grep <image-name>

# Check if image exists in Harbor
docker pull harbor.blocksecops.local/blocksecops/<image>:<tag>
```

---

## Scheduled Cleanup

### Cron Job (Optional)

```bash
# Add to crontab for weekly cleanup
0 3 * * 0 /home/pwner/Git/blocksecops-orchestration/scripts/docker-cleanup.sh >> /var/log/docker-cleanup.log 2>&1
```

---

## Troubleshooting

### "No space left on device"

```bash
# Emergency cleanup
docker system prune -a -f --volumes

# Check what's using space
du -sh /var/lib/docker/*
```

### Image Still Showing After Delete

```bash
# Force remove
docker rmi -f <image-id>

# Or prune all unused
docker image prune -a -f
```

### Cannot Delete Image (In Use)

```bash
# Find containers using the image
docker ps -a --filter ancestor=<image>

# Stop and remove containers first
docker stop <container-id>
docker rm <container-id>

# Then remove image
docker rmi <image>
```

---

## Checklist

- [ ] Run `docker system df` to check current usage
- [ ] Run cleanup with `--dry-run` first
- [ ] Verify Harbor images are accessible after cleanup
- [ ] Check cluster pods are still running
- [ ] Confirm disk space was freed with `df -h`

---

## Related Documentation

- [Deploy New Image](./deploy-new-image.md)
- [Docker Base Images Standard](/docs/standards/docker-base-images.md)
- [Docker Image Versioning](/docs/standards/docker-image-versioning.md)
