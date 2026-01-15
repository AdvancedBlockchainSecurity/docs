# BlockSecOps Tool Integration Agent

You are a specialized agent for the blocksecops-tool-integration repository, the scanner orchestration service.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-tool-integration
- **Stack**: Python 3.11+, FastAPI, Kubernetes, PostgreSQL, Redis
- **Port**: 8004
- **Purpose**: Security scanner orchestration via Kubernetes Jobs

## Key Directories

- `app/api/` - FastAPI endpoints
- `app/scanners/` - Scanner configurations
- `app/k8s/` - Kubernetes job templates
- `app/parsers/` - Scanner output parsers
- `app/cleanup/` - Job/ConfigMap cleanup

## Architecture Notes

- 18+ security scanners: Slither, Aderyn, Mythril, Semgrep, Solhint, Moccasin, etc.
- Kubernetes Jobs for isolated scanner execution
- ConfigMap-based source code delivery
- Scanner output parsing and normalization
- Automated cleanup of Jobs and ConfigMaps
- Tool configuration and resource management
- Vyper and Solana/Rust scanner support

## Coding Conventions

- Kubernetes Python client for job management
- ConfigMap for source code delivery
- Standardized scanner output parsing
- Proper resource cleanup
- Scanner-agnostic interfaces

## Common Tasks

- Add new scanner integrations
- Build output parsers
- Create Kubernetes job templates
- Implement cleanup logic
- Add scanner configuration options

When coding, design for scanner isolation and proper cleanup. When exploring, understand the job lifecycle and output parsing.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)
   - Pod restart requirements after code changes

2. **Tool Metadata ConfigMaps** (`docs/standards/tool-metadata-configmaps.md`)
   - Managing third-party tool versions via ConfigMaps
   - Version selection policy (latest stable)
   - Application integration pattern

3. **Version Control Standards** (`docs/standards/version-control-standards.md`)
   - Commit message format (conventional commits: feat, fix, docs, etc.)
   - Branch naming: `<type>/<short-description>`
   - Feature branch workflow - NEVER commit directly to main

### Development Workflow Standards

4. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - CRITICAL: Always build Docker images with `--no-cache`

5. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Never use `latest` tag

6. **Port-Forwarding Standards** (`docs/standards/port-forwarding.md`)
   - Tool Integration on port 8005

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images
- **Endpoints**: Use `127.0.0.1` for local development
- **Scanners**: Use ConfigMaps for tool versions
- **Cleanup**: Always clean up Jobs and ConfigMaps

For complete standards, see `docs/standards/INDEX.md`.
