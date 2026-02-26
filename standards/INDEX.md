# Platform Development Standards - Index

**Version:** 2.4.0
**Last Updated:** February 5, 2026
**Status:** Active

## Overview

This index provides a comprehensive guide to all BlockSecOps Platform development standards. These standards ensure:

- **Reproducibility** through code-first development
- **Traceability** of all platform changes
- **Consistency** across development environments
- **Safety** through documented change processes
- **Collaboration** through clear standards

**All platform changes MUST comply with these standards without exception.**

## Standards Documents

### 🔴 Critical Standards (Must Read First)

These standards contain the most critical rules that, if violated, can cause data loss, service outages, or security issues:

1. **[Core Development Rules](./core-development-rules.md)**
   - Critical development workflow rules
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint requirements (127.0.0.1)
   - Pod restart requirements after code changes
   - Emergency hotfix procedures

2. **[Database Management](./database-management.md)**
   - Database backup and recovery procedures
   - MANDATORY: Never apply database config changes without backups
   - Automated backup setup
   - Recovery procedures (with and without backups)
   - Cautionary example: October 16, 2025 database corruption incident

3. **[Secrets Management](./secrets-management.md)**
   - HashiCorp Vault with External Secrets Operator
   - What must be in Vault vs. what must NOT be in Git
   - Workflow for adding/updating secrets
   - ExternalSecret resource configuration

### 🟡 Development Workflow Standards

These standards define how you should work with code, Git, and deployments:

4. **[Version Control Standards](./version-control-standards.md)**
   - Commit message format (conventional commits)
   - Branch naming conventions
   - Git workflow - Feature branch model (MANDATORY)
   - Pull request requirements and templates
   - Branch protection rules
   - Common workflow scenarios

5. **[Testing & Deployment](./testing-deployment.md)**
   - Test before deploy workflow
   - CRITICAL: Do not rollback working deployments
   - CRITICAL: Test before committing fixes
   - Docker build caching with Harbor registry
   - Rollback procedures
   - Deployment checklist

6. **[Documentation Standards](./documentation-standards.md)**
   - Required documentation for all changes
   - Commit message requirements
   - Update summary document template
   - What documentation to update when

### 🟢 Local Development Standards

These standards help you set up and maintain your local development environment:

7. **[Local Development Setup](./local-development-setup.md)**
   - Access endpoints (use 127.0.0.1)
   - Kubernetes service selector standards (includeSelectors: false)
   - Environment configuration (.env.local)
   - External service integrations (Stripe CLI webhook forwarding)
   - Troubleshooting service endpoints
   - Local development checklist

8. **[Service Access Standards](./port-forwarding.md)**
   - **Always-available access patterns** (services must be accessible without manual setup)
   - Environment-specific access: hostPort, GCP Load Balancer
   - Standard port mappings for all services
   - Port-forward commands for debugging only
   - Service configuration and access URLs
   - Troubleshooting access issues

9. **[Service Availability](./service-availability.md)** [NEW]
   - Core principle: Services MUST be always available
   - Anti-pattern: Manual port-forwards for regular access
   - When port-forwards ARE acceptable (debugging, internal services)
   - Environment access matrix
   - Startup verification checklist

10. **[Dashboard Development](./dashboard-development.md)**
    - Python 3.13 compatibility issue (MissingGreenlet)
    - Proper dashboard startup procedure (7 steps)
    - Port-forward best practices (deployment vs service)
    - Troubleshooting dashboard issues
    - Dashboard development workflow
    - Daily development checklist

11. **[Frontend Development](./frontend-development.md)**
    - React + TypeScript + Vite frontend setup
    - Supabase authentication integration
    - Proper frontend startup procedure
    - Port assignments and port-forward standards
    - Kubernetes deployment and access
    - Troubleshooting frontend issues (CORS, auth, networking)
    - Frontend architecture and project structure

12. **[Domain Management](./domain-management.md)**
    - Environment-specific domain configuration (local, server, GCP)
    - Setting up `app.blocksecops.local` for server testing
    - Server self-resolution requirement (server must resolve its own domain)
    - GCP migration checklist for `app.blocksecops.com`
    - Kustomize overlay strategy for domains
    - CORS and IngressRoute configuration
    - Troubleshooting domain/DNS issues

### 🔵 Configuration & Versioning Standards

These standards ensure proper versioning and configuration management:

13. **[Docker Image Versioning](./docker-image-versioning.md)**
    - Semantic versioning for Docker images (MAJOR.MINOR.PATCH)
    - Version increment rules
    - Kustomization configuration
    - Why explicit versions (not `latest`)

14. **[Docker Base Images](./docker-base-images.md)** [UPDATED v2.0]
    - Pre-built base images stored in Harbor for persistence
    - Reduces build times from ~20 min to ~2-3 min for code changes
    - Applies to: intelligence-engine (ML), orchestration (security tools)
    - Security hardening: checksum verification, pinned digests, pipx isolation
    - Base image versioning with content hashing
    - Complete build and push workflow

15. **[Build Workflow](./build-workflow.md)**
    - Local Docker build with Harbor registry
    - Build and deploy steps
    - Using build cache
    - Registry-agnostic build workflow

16. **[Frontend Build-Time Environment Variables](./frontend-build-env.md)**
    - Vite environment variable handling (baked at build time)
    - Security classification (public vs private variables)
    - Pass build args, never hardcode in Dockerfile
    - Environment files (.env.local vs .env.example)
    - Build workflow for local and CI/CD

17. **[Tool Metadata ConfigMaps](./tool-metadata-configmaps.md)**
    - Managing third-party tool versions via ConfigMaps
    - Version selection policy (latest stable)
    - ConfigMap solution vs. hardcoded versions
    - Application integration pattern
    - Version update workflow (2 minutes vs 15 minutes)
    - Multi-environment support
    - Real-world example: Scanner metadata refactoring

18. **[Dependency Management](./dependency-management.md)**
    - Latest stable version policy
    - Prohibited dependencies (deprecated, retired, unmaintained)
    - Dependency health monitoring (monthly/quarterly audits)
    - Exception process
    - Lockfile management
    - Migration from deprecated dependencies
    - Real-world example: Manticore removal

### 🤖 AI/ML Development Standards

19. **[ML Development](./ml-development.md)**
    - CPU-only ML architecture (no GPU/LLM costs)
    - ML module structure and responsibilities
    - Lazy loading patterns for models
    - Feature extraction standards (30+ features)
    - Model training and versioning
    - Testing patterns with mocks
    - Performance targets (<100ms inference)
    - API endpoint conventions

20. **[Intelligence Integration Standards](./INTELLIGENCE-INTEGRATION-STANDARDS.md)**
    - Vulnerability pattern classification (BVD codes)
    - Fingerprinting strategies (ASM, ENC, EVT, L2, Semantic)
    - Deduplication algorithms
    - Scanner-to-pattern mappings
    - Canonical finding selection

### 🔒 Security Standards

21. **[API Endpoint Authentication](./api-endpoint-auth.md)** [NEW]
    - Authentication dependency selection (JWT vs API Key vs Dual-Auth)
    - **CRITICAL:** Write endpoints MUST use `require_auth_with_scope()`
    - API key scope enforcement (prevents unauthorized actions)
    - Scope-to-endpoint mapping reference
    - Decision tree for new endpoints
    - Migration guide for converting JWT-only to dual-auth

22. **[Secure Coding Standards](./secure-coding.md)** [NEW]
    - Security-first development: no code ships with known vulnerabilities
    - OWASP Top 10 prevention with code examples
    - Input validation, output encoding, and injection prevention
    - Frontend, API, and container security requirements
    - Code review security checklist

23. **[Encryption Standards](./encryption-standards.md)** [NEW]
    - Data in transit: TLS 1.2+ for all channels
    - Data at rest: disk encryption, application-level AES-256-GCM
    - Key management: Vault storage, rotation procedures
    - Hashing standards: bcrypt for passwords, SHA-256 for fingerprints
    - Prohibited algorithms and practices

24. **[Tier Standards](./tier-standards.md)**
    - Tier-based feature access (free, growth, enterprise)
    - API key availability per tier
    - Rate limiting by tier

### ☸️ Kubernetes Standards

25. **[Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md)** [NEW]
    - Revision history limits (`revisionHistoryLimit: 3`)
    - Pod-level and container-level security contexts
    - NetworkPolicy patterns (default-deny, ingress, egress)
    - Automatic cleanup of old ReplicaSets
    - Volume mounts for read-only root filesystem
    - Troubleshooting pod lifecycle issues

26. **[Kustomize Standards](./kustomize-standards.md)** [NEW]
    - Base vs overlay directory structure
    - Patch file naming conventions
    - Environment-specific configuration patterns
    - Image versioning integration with pyproject.toml/package.json
    - Common patterns and anti-patterns
    - Validation and troubleshooting

### ✅ Compliance & Verification

27. **[Compliance Checklist](./compliance-checklist.md)**
    - Daily development checklist
    - Making changes checklist
    - Database configuration changes checklist
    - Code review checklist

28. **[Smoke Test](./smoke-test.md)** [NEW]
    - Platform smoke test after deployments
    - Pre-flight infrastructure checks
    - External and internal service health checks
    - Authenticated endpoint verification
    - Database integrity checks
    - Quick full smoke test script

## Quick Reference

### Most Common Violations

1. **Making kubectl changes without updating Git first** → See [Core Development Rules](./core-development-rules.md)
2. **Not creating database backups before config changes** → See [Database Management](./database-management.md)
3. **Using `localhost` instead of `127.0.0.1`** → See [Local Development Setup](./local-development-setup.md)
4. **Committing directly to main instead of using feature branches** → See [Version Control Standards](./version-control-standards.md)
5. **Not incrementing version tags when rebuilding images** → See [Testing & Deployment](./testing-deployment.md)
6. **Using manual port-forwards for regular access** → See [Service Availability](./service-availability.md)
7. **Using `get_current_user_or_api_key` for write endpoints** → See [API Endpoint Authentication](./api-endpoint-auth.md) - MUST use `require_auth_with_scope()`
8. **Missing `revisionHistoryLimit` on Deployments** → See [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md) - causes stale pod accumulation
9. **Missing security context on pods/containers** → See [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md) - required for security compliance
10. **Missing NetworkPolicy for services** → See [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md) - required for network isolation
11. **Shipping code with known vulnerabilities** → See [Secure Coding Standards](./secure-coding.md) - no code ships with known vulnerabilities

### Most Frequent Issues

1. **Service has no endpoints** → See [Local Development Setup - Kubernetes Service Selector Standards](./local-development-setup.md#kubernetes-service-selector-standards)
2. **Port-forward dies after pod restart** → See [Dashboard Development - Troubleshooting](./dashboard-development.md#troubleshooting-dashboard-issues)
3. **MissingGreenlet error in API** → See [Dashboard Development - Python 3.13 Compatibility](./dashboard-development.md#critical-python-313-compatibility-issue)
4. **Dashboard shows wrong port (5173 instead of 3000)** → See [Local Development Setup - Port Number Consistency](./local-development-setup.md#port-number-consistency-standards)
5. **Code changes not deployed despite rebuilding** → See [Testing & Deployment - Docker --no-cache](./testing-deployment.md#critical-always-build-docker-images-with---no-cache)

## Document Organization

The original `PLATFORM-DEVELOPMENT-STANDARDS.md` file has been split into focused documents for easier reference and maintenance:

```
docs/standards/
├── INDEX.md (this file)
├── core-development-rules.md
├── secrets-management.md
├── local-development-setup.md
├── port-forwarding.md              # Renamed: Service Access Standards
├── service-availability.md         # NEW: Always-available access principles
├── domain-management.md
├── dashboard-development.md
├── frontend-development.md
├── frontend-build-env.md
├── database-management.md
├── documentation-standards.md
├── version-control-standards.md
├── testing-deployment.md
├── compliance-checklist.md
├── docker-image-versioning.md
├── docker-base-images.md          # NEW: Pre-built base images for heavy deps
├── build-workflow.md
├── tool-metadata-configmaps.md
├── dependency-management.md
├── ml-development.md
├── INTELLIGENCE-INTEGRATION-STANDARDS.md
├── ingress-networking.md
├── api-endpoint-auth.md           # NEW: API authentication and scope enforcement
├── tier-standards.md
├── kubernetes-pod-lifecycle.md    # NEW: Pod lifecycle, security contexts, NetworkPolicies
├── kustomize-standards.md         # NEW: Kustomize base/overlay patterns
├── secure-coding.md               # NEW: Security-first development, OWASP Top 10
├── encryption-standards.md        # NEW: Encryption at rest, in transit, key management
└── smoke-test.md                  # NEW: Platform smoke test procedures
```

## Referencing Standards in Claude Code

When working with Claude Code, you can reference specific standards documents:

```markdown
# For local development questions
@docs/standards/local-development-setup.md

# For port-forwarding and service access
@docs/standards/port-forwarding.md

# For Git workflow questions
@docs/standards/version-control-standards.md

# For database questions
@docs/standards/database-management.md

# For deployment questions
@docs/standards/testing-deployment.md
```

## Related Documentation

**Architecture & Templates:**
- [Kubernetes Kustomize Structure Template](../architecture-templates/kubernetes-kustomize-structure-template.md)

**Technical Documentation:**
- [Docker Image Standards](../DOCKER-IMAGE-STANDARDS.md)
- [Claude Spec Kit](../CLAUDE-SPEC-KIT.md)
- Development Workflow (blocksecops-docs/local-development/)

**Task Documentation:**
- Implementation summaries (TaskDocs-BlockSecOps/)
- Sprint plans and completion reports (docs/Sprints/)

---

## Questions or Issues?

Contact the development team or create an issue in the `blocksecops-docs` repository.

**Remember: These are MANDATORY standards. Violations will require immediate correction.**

---

**Last Updated:** February 12, 2026
**Maintained By:** BlockSecOps Team
