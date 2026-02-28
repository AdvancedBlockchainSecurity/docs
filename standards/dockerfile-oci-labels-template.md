# Dockerfile OCI Labels Template

**Version:** 1.0.0
**Last Updated:** January 18, 2026
**Status:** Active

## Overview

All Apogee service Dockerfiles must use OCI-compliant labels (org.opencontainers.image.*) instead of the deprecated org.label-schema format.

---

## Standard Template

### Build Arguments (Required)

```dockerfile
ARG SERVICE_NAME=blocksecops-<service-name>
ARG SERVICE_VERSION=0.0.0
ARG BUILD_DATE
ARG VCS_REF
```

### OCI Labels (Required)

```dockerfile
LABEL org.opencontainers.image.title="${SERVICE_NAME}" \
      org.opencontainers.image.description="<Service description>" \
      org.opencontainers.image.version="${SERVICE_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="Apogee" \
      org.opencontainers.image.source="https://github.com/AdvancedBlockchainSecurity/${SERVICE_NAME}" \
      org.opencontainers.image.authors="Apogee Team <team@0xapogee.com>"
```

---

## Label Definitions

| Label | Description | Example |
|-------|-------------|---------|
| `title` | Human-readable service name | `blocksecops-api-service` |
| `description` | Short description of service purpose | `FastAPI gateway service for Apogee Platform` |
| `version` | Semantic version from source file | `0.11.0` |
| `created` | Build timestamp (ISO 8601) | `2026-01-18T12:00:00Z` |
| `revision` | Git commit SHA | `abc1234` |
| `vendor` | Organization name | `Apogee` |
| `source` | Repository URL | `https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service` |
| `authors` | Maintainer contact | `Apogee Team <team@0xapogee.com>` |

---

## Scanner Image Extension

Scanner images add scanner-specific labels:

```dockerfile
ARG SCANNER_IMAGE_VERSION=0.4.0
ARG UPSTREAM_TOOL_VERSION=1.10.3
ARG SCANNER_CATEGORY=static

LABEL org.opencontainers.image.title="Apogee Scanner - ${SCANNER_NAME}" \
      org.opencontainers.image.description="${SCANNER_DESCRIPTION}" \
      org.opencontainers.image.version="${SCANNER_IMAGE_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.vendor="Apogee" \
      scanner.image.version="${SCANNER_IMAGE_VERSION}" \
      scanner.tool.version="${UPSTREAM_TOOL_VERSION}" \
      scanner.category="${SCANNER_CATEGORY}"
```

---

## Build Command

Pass build arguments when building:

```bash
docker build \
  --build-arg SERVICE_VERSION=$(grep 'version' pyproject.toml | head -1 | cut -d'"' -f2) \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.0xapogee.local/blocksecops/service-name:version .
```

---

## Verification

Check labels on built image:

```bash
docker inspect --format='{{json .Config.Labels}}' image:tag | jq
```

Expected output:

```json
{
  "org.opencontainers.image.title": "blocksecops-api-service",
  "org.opencontainers.image.description": "FastAPI gateway service for Apogee Platform",
  "org.opencontainers.image.version": "0.11.0",
  "org.opencontainers.image.created": "2026-01-18T12:00:00Z",
  "org.opencontainers.image.revision": "abc1234",
  "org.opencontainers.image.vendor": "Apogee",
  "org.opencontainers.image.source": "https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service",
  "org.opencontainers.image.authors": "Apogee Team <team@0xapogee.com>"
}
```

---

## Migration from org.label-schema

| Old (Deprecated) | New (OCI) |
|-----------------|-----------|
| `org.label-schema.name` | `org.opencontainers.image.title` |
| `org.label-schema.description` | `org.opencontainers.image.description` |
| `org.label-schema.version` | `org.opencontainers.image.version` |
| `org.label-schema.build-date` | `org.opencontainers.image.created` |
| `org.label-schema.vcs-ref` | `org.opencontainers.image.revision` |
| `org.label-schema.vcs-url` | `org.opencontainers.image.source` |
| `maintainer` | `org.opencontainers.image.authors` |

---

## Related Documentation

- [Docker Image Versioning](./docker-image-versioning.md)
- [Build Workflow](./build-workflow.md)
- [OCI Image Spec](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
