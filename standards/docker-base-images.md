# Docker Base Image Standards

**Version:** 1.0.0
**Last Updated:** January 25, 2026
**Status:** Active

## Overview

This standard defines the strategy for optimizing Docker build times using pre-built base images. Services with heavy dependencies that rarely change should use dedicated base images to separate dependency installation from application code changes.

## Problem

Some services have long build times (~15-20 minutes) because they install large dependency sets from scratch on every build. Code-only changes trigger full dependency reinstalls, wasting CI/CD time and developer productivity.

## Solution

Create separate base images containing pre-installed heavy dependencies. Application Dockerfiles build FROM these base images, so code changes only require copying files (~2-3 minutes instead of ~15-20 minutes).

## Services Using Base Images

| Service | Base Image | Heavy Dependencies |
|---------|------------|-------------------|
| `blocksecops-intelligence-engine` | `blocksecops-intelligence-base-cpu` | PyTorch, TensorFlow, transformers, scikit-learn, spacy, NLP libraries |
| `blocksecops-intelligence-engine` | `blocksecops-intelligence-base-gpu` | Same as CPU + CUDA support |
| `blocksecops-orchestration` | `blocksecops-orchestration-base` | Security analysis tools (Slither, Echidna, Mythril, Semgrep, Foundry, etc.) |

## Build Time Comparison

| Scenario | Before | After |
|----------|--------|-------|
| Code change only | ~15-20 min | ~2-3 min |
| App dependency change | ~15-20 min | ~5-7 min |
| Base dependency change | ~15-20 min | ~15-20 min (base only) |

## Base Image Versioning

Base images are versioned using a hash of their dependency specification files:

- **Tag format**: `{version}-{requirements-hash}` (e.g., `1.0.0-a1b2c3d`)
- **Hash source**: SHA256 of requirements file(s) or Dockerfile tool versions
- **Rebuild trigger**: Hash change indicates dependency change

## Directory Structure

```
docker/
  base/
    Dockerfile.cpu              # Intelligence engine CPU base
    Dockerfile.gpu              # Intelligence engine GPU base
    Dockerfile.orchestration    # Orchestration tools base
  build-base-image.sh           # Build script for all base images

requirements/
  base-ml.txt                   # ML dependencies (for base image)
  base.txt                      # App-specific dependencies (lightweight)
```

## When to Rebuild Base Images

Rebuild base images when:

1. Adding or removing packages from base requirements
2. Updating version constraints for base packages
3. Security patches require dependency updates
4. Quarterly maintenance cycle

Base images do NOT need rebuilding for:

- Application code changes
- App-specific dependency changes (in `requirements/base.txt`)
- Configuration changes

## Registry Location

Base images are stored in the same registry as application images:

- **Local**: `harbor.blocksecops.local/blocksecops/`
- **Production**: `ghcr.io/blocksecops/` or GCP Artifact Registry

## Implementation Reference

Implementation details (Dockerfiles, build scripts, requirements files) follow the patterns established in `blocksecops-intelligence-engine/docker/base/`. Claude Code will implement according to these standards when creating or updating base images.

## Services NOT Using Base Images

The following services do not benefit from base images and should continue using standard multi-stage builds:

| Service | Reason |
|---------|--------|
| `blocksecops-api-service` | Lightweight FastAPI dependencies, builds fast |
| `blocksecops-notification` | Lightweight dependencies |
| `blocksecops-contract-parser` | Rust with cargo dependency caching |
| `blocksecops-shared` | Already optimized multi-stage build |
| Node.js frontends | npm ci with cache mounts is efficient |

## Related Standards

- [Docker Image Versioning](./docker-image-versioning.md) - Semantic versioning for images
- [Build Workflow](./build-workflow.md) - Local build processes
- [Dependency Management](./dependency-management.md) - Dependency policies
