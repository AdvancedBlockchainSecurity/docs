# Platform Development Standards - Index

**Version:** 2.5.1
**Last Updated:** March 1, 2026
**Status:** Active

## Overview

This index provides a comprehensive guide to all Apogee Platform development standards. These standards ensure:

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

### 🟢 Environment & Access Standards

7. **[Service Availability](./service-availability.md)**
   - Core principle: Services MUST be always available
   - Anti-pattern: Manual port-forwards for regular access
   - Environment access matrix
   - Startup verification checklist

8. **[Domain Management](./domain-management.md)**
    - Environment-specific domain configuration (local, server, GCP)
    - GCP migration checklist for `app.0xapogee.com`
    - Kustomize overlay strategy for domains
    - CORS and IngressRoute configuration

### 🔵 Configuration & Versioning Standards

These standards ensure proper versioning and configuration management:

9. **[Docker Image Versioning](./docker-image-versioning.md)**
    - Semantic versioning for Docker images (MAJOR.MINOR.PATCH)
    - Version increment rules
    - Kustomization configuration
    - Why explicit versions (not `latest`)

10. **[Docker Base Images](./docker-base-images.md)**
    - Pre-built base images stored in Harbor for persistence
    - Reduces build times from ~20 min to ~2-3 min for code changes
    - Applies to: intelligence-engine (ML), orchestration (security tools)
    - Security hardening: checksum verification, pinned digests, pipx isolation
    - Base image versioning with content hashing
    - Complete build and push workflow

11. **[Build Workflow](./build-workflow.md)**
    - Local Docker build with Harbor registry
    - Build and deploy steps
    - Using build cache
    - Registry-agnostic build workflow

12. **[Frontend Build-Time Environment Variables](./frontend-build-env.md)**
    - Vite environment variable handling (baked at build time)
    - Security classification (public vs private variables)
    - Pass build args, never hardcode in Dockerfile
    - Environment files (.env.local vs .env.example)
    - Build workflow for local and CI/CD

13. **[Tool Metadata ConfigMaps](./tool-metadata-configmaps.md)**
    - Managing third-party tool versions via ConfigMaps
    - Version selection policy (latest stable)
    - ConfigMap solution vs. hardcoded versions
    - Application integration pattern
    - Version update workflow (2 minutes vs 15 minutes)
    - Multi-environment support
    - Real-world example: Scanner metadata refactoring

14. **[Dependency Management](./dependency-management.md)**
    - Latest stable version policy
    - Prohibited dependencies (deprecated, retired, unmaintained)
    - Dependency health monitoring (monthly/quarterly audits)
    - Exception process
    - Lockfile management
    - Migration from deprecated dependencies
    - Real-world example: Manticore removal

### 🤖 AI/ML Development Standards

15. **[ML Development](./ml-development.md)**
    - CPU-only ML architecture (no GPU/LLM costs)
    - ML module structure and responsibilities
    - Lazy loading patterns for models
    - Feature extraction standards (30+ features)
    - Model training and versioning
    - Testing patterns with mocks
    - Performance targets (<100ms inference)
    - API endpoint conventions

### 🔒 Security Standards

16. **[API Endpoint Authentication](./api-endpoint-auth.md)**
    - Authentication dependency selection (JWT vs API Key vs Dual-Auth)
    - **CRITICAL:** Write endpoints MUST use `require_auth_with_scope()`
    - API key scope enforcement (prevents unauthorized actions)
    - Scope-to-endpoint mapping reference
    - Decision tree for new endpoints
    - Migration guide for converting JWT-only to dual-auth

17. **[Secure Coding Standards](./secure-coding.md)**
    - Security-first development: no code ships with known vulnerabilities
    - OWASP Top 10 prevention with code examples
    - Input validation, output encoding, and injection prevention
    - Frontend, API, and container security requirements
    - Code review security checklist

18. **[Encryption Standards](./encryption-standards.md)**
    - Data in transit: TLS 1.2+ for all channels
    - Data at rest: disk encryption, application-level AES-256-GCM
    - Key management: Vault storage, rotation procedures
    - Hashing standards: bcrypt for passwords, SHA-256 for fingerprints
    - Prohibited algorithms and practices

19. **[Tier Standards](./tier-standards.md)**
    - Tier-based feature access (free, growth, enterprise)
    - API key availability per tier
    - Rate limiting by tier

20. **[Organization, Team, and User Hierarchy](./organization-team-user-hierarchy.md)**
    - Organization → Team → User data model and relationships
    - RBAC roles (owner, admin, member, viewer) and permissions
    - Tier requirements for org creation (starter+) and service accounts (growth+)
    - Invite workflow, data scoping rules, enterprise features (SSO/SAML)

### ☸️ Kubernetes Standards

21. **[Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md)**
    - Revision history limits (`revisionHistoryLimit: 3`)
    - Pod-level and container-level security contexts
    - NetworkPolicy patterns (default-deny, ingress, egress)
    - Automatic cleanup of old ReplicaSets
    - Volume mounts for read-only root filesystem
    - Troubleshooting pod lifecycle issues

22. **[Kustomize Standards](./kustomize-standards.md)**
    - Base vs overlay directory structure
    - Patch file naming conventions
    - Environment-specific configuration patterns
    - Image versioning integration with pyproject.toml/package.json
    - Common patterns and anti-patterns
    - Validation and troubleshooting

### ✅ Compliance & Verification

23. **[Compliance Checklist](./compliance-checklist.md)**
    - Daily development checklist
    - Making changes checklist
    - Database configuration changes checklist
    - Code review checklist

24. **[Smoke Test](./smoke-test.md)**
    - Platform smoke test after deployments
    - Pre-flight infrastructure checks
    - External and internal service health checks
    - Authenticated endpoint verification
    - Database integrity checks
    - Quick full smoke test script

## Quick Reference

### Most Common Violations

1. **Performing GitOps without owner approval** → See [Core Development Rules — Rule 0](./core-development-rules.md#rule-0-gitops-requires-owner-approval)
2. **Making kubectl changes without updating Git first** → See [Core Development Rules](./core-development-rules.md)
3. **Not creating database backups before config changes** → See [Database Management](./database-management.md)
4. **Using `localhost` instead of `127.0.0.1`** → Use `127.0.0.1` for local development
5. **Committing directly to main instead of using feature branches** → See [Version Control Standards](./version-control-standards.md)
6. **Not incrementing version tags when rebuilding images** → See [Testing & Deployment](./testing-deployment.md)
7. **Using manual port-forwards for regular access** → See [Service Availability](./service-availability.md)
8. **Using `get_current_user_or_api_key` for write endpoints** → See [API Endpoint Authentication](./api-endpoint-auth.md) - MUST use `require_auth_with_scope()`
9. **Missing `revisionHistoryLimit` on Deployments** → See [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md) - causes stale pod accumulation
10. **Missing security context on pods/containers** → See [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md) - required for security compliance
11. **Missing NetworkPolicy for services** → See [Kubernetes Pod Lifecycle](./kubernetes-pod-lifecycle.md) - required for network isolation
12. **Shipping code with known vulnerabilities** → See [Secure Coding Standards](./secure-coding.md) - no code ships with known vulnerabilities

### Most Frequent Issues

1. **Service has no endpoints** → Check Kubernetes service selector labels match pod labels
2. **Code changes not deployed despite rebuilding** → See [Testing & Deployment](./testing-deployment.md) — always run `kubectl apply -k` after version bump

## Document Organization

The original `PLATFORM-DEVELOPMENT-STANDARDS.md` file has been split into focused documents for easier reference and maintenance:

```
docs/standards/
├── INDEX.md (this file)
├── api-endpoint-auth.md
├── blocksecops-style-guide.md
├── build-workflow.md
├── compliance-checklist.md
├── core-development-rules.md
├── database-management.md
├── dependency-management.md
├── docker-base-images.md
├── docker-image-versioning.md
├── documentation-standards.md
├── domain-management.md
├── encryption-standards.md
├── frontend-build-env.md
├── ingress-networking.md
├── kubernetes-pod-lifecycle.md
├── kustomize-standards.md
├── ml-development.md
├── organization-team-user-hierarchy.md
├── secrets-management.md
├── secure-coding.md
├── security-standards.md
├── service-availability.md
├── smoke-test.md
├── testing-deployment.md
├── tier-standards.md
├── tool-metadata-configmaps.md
└── version-control-standards.md
```

## Referencing Standards in Claude Code

When working with Claude Code, you can reference specific standards documents:

```markdown
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
- Implementation summaries (TaskDocs-Apogee/)
- Sprint plans and completion reports (docs/Sprints/)

---

## Questions or Issues?

Contact the development team or create an issue in the `blocksecops-docs` repository.

**Remember: These are MANDATORY standards. Violations will require immediate correction.**

---

**Last Updated:** February 28, 2026
**Maintained By:** Apogee Team
