# Platform Development Standards - Index

**Version:** 2.0.0
**Last Updated:** December 27, 2025
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
   - CRITICAL: Always build Docker images with --no-cache
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

8. **[Port-Forwarding Standards](./port-forwarding.md)**
   - Standard port mappings for all services
   - Port-forward setup commands and scripts
   - Port assignment rules and range allocation
   - Service configuration and access URLs
   - Troubleshooting port-forward issues
   - Monitoring and health check scripts
   - Best practices for port-forward management

9. **[Dashboard Development](./dashboard-development.md)**
   - Python 3.13 compatibility issue (MissingGreenlet)
   - Proper dashboard startup procedure (7 steps)
   - Port-forward best practices (deployment vs service)
   - Troubleshooting dashboard issues
   - Dashboard development workflow
   - Daily development checklist

10. **[Frontend Development](./frontend-development.md)**
    - React + TypeScript + Vite frontend setup
    - Supabase authentication integration
    - Proper frontend startup procedure
    - Port assignments and port-forward standards
    - Kubernetes deployment and access
    - Troubleshooting frontend issues (CORS, auth, networking)
    - Frontend architecture and project structure

### 🔵 Configuration & Versioning Standards

These standards ensure proper versioning and configuration management:

11. **[Docker Image Versioning](./docker-image-versioning.md)**
    - Semantic versioning for Docker images (MAJOR.MINOR.PATCH)
    - Version increment rules
    - Kustomization configuration
    - Why explicit versions (not `latest`)

12. **[Build Workflow](./build-workflow.md)**
    - Local Docker build with Harbor registry
    - Build and deploy steps
    - Using build cache
    - Why local Docker vs minikube Docker

13. **[Frontend Build-Time Environment Variables](./frontend-build-env.md)**
    - Vite environment variable handling (baked at build time)
    - Security classification (public vs private variables)
    - Pass build args, never hardcode in Dockerfile
    - Environment files (.env.local vs .env.example)
    - Build workflow for local and CI/CD

14. **[Tool Metadata ConfigMaps](./tool-metadata-configmaps.md)**
    - Managing third-party tool versions via ConfigMaps
    - Version selection policy (latest stable)
    - ConfigMap solution vs. hardcoded versions
    - Application integration pattern
    - Version update workflow (2 minutes vs 15 minutes)
    - Multi-environment support
    - Real-world example: Scanner metadata refactoring

15. **[Dependency Management](./dependency-management.md)**
    - Latest stable version policy
    - Prohibited dependencies (deprecated, retired, unmaintained)
    - Dependency health monitoring (monthly/quarterly audits)
    - Exception process
    - Lockfile management
    - Migration from deprecated dependencies
    - Real-world example: Manticore removal

### 🤖 AI/ML Development Standards

16. **[ML Development](./ml-development.md)**
    - CPU-only ML architecture (no GPU/LLM costs)
    - ML module structure and responsibilities
    - Lazy loading patterns for models
    - Feature extraction standards (30+ features)
    - Model training and versioning
    - Testing patterns with mocks
    - Performance targets (<100ms inference)
    - API endpoint conventions

17. **[Intelligence Integration Standards](./INTELLIGENCE-INTEGRATION-STANDARDS.md)**
    - Vulnerability pattern classification (BVD codes)
    - Fingerprinting strategies (ASM, ENC, EVT, L2, Semantic)
    - Deduplication algorithms
    - Scanner-to-pattern mappings
    - Canonical finding selection

### ✅ Compliance & Verification

18. **[Compliance Checklist](./compliance-checklist.md)**
    - Daily development checklist
    - Making changes checklist
    - Database configuration changes checklist
    - Code review checklist

## Quick Reference

### Most Common Violations

1. **Making kubectl changes without updating Git first** → See [Core Development Rules](./core-development-rules.md)
2. **Not creating database backups before config changes** → See [Database Management](./database-management.md)
3. **Using `localhost` instead of `127.0.0.1`** → See [Local Development Setup](./local-development-setup.md)
4. **Committing directly to main instead of using feature branches** → See [Version Control Standards](./version-control-standards.md)
5. **Building Docker images with cache (without --no-cache)** → See [Testing & Deployment](./testing-deployment.md)

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
├── port-forwarding.md
├── dashboard-development.md
├── frontend-development.md
├── frontend-build-env.md
├── database-management.md
├── documentation-standards.md
├── version-control-standards.md
├── testing-deployment.md
├── compliance-checklist.md
├── docker-image-versioning.md
├── build-workflow.md
├── tool-metadata-configmaps.md
├── dependency-management.md
├── ml-development.md
├── INTELLIGENCE-INTEGRATION-STANDARDS.md
└── ingress-networking.md
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

**Last Updated:** January 7, 2026
**Maintained By:** BlockSecOps Team
