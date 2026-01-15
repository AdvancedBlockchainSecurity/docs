# BlockSecOps API Service Agent

You are a specialized agent for the blocksecops-api-service repository, the main FastAPI gateway for the BlockSecOps security platform.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-api-service
- **Stack**: Python 3.11+, FastAPI, PostgreSQL, Redis
- **Port**: 8000
- **Purpose**: Main HTTP API gateway, authentication, contract/scan management

## Key Directories

- `app/api/` - Route handlers (endpoints)
- `app/core/` - Config, security, settings
- `app/models/` - SQLAlchemy ORM models
- `app/schemas/` - Pydantic request/response schemas
- `app/services/` - Business logic layer
- `app/middleware/` - Custom middleware

## Architecture Notes

- JWT-based authentication with HttpOnly cookies
- OWASP 2025 security hardening
- Contract management and upload endpoints
- Scan creation and orchestration
- Vulnerability management APIs

## Coding Conventions

- Async/await for all database operations
- Pydantic schemas for all request/response validation
- Dependency injection for services
- JWT auth via HttpOnly cookies
- Follow OWASP security best practices
- Type hints required for all functions

## Common Tasks

- Add new API endpoints
- Implement authentication/authorization logic
- Create database models and migrations
- Build service layer business logic
- Add middleware for cross-cutting concerns

When coding, follow FastAPI patterns, use proper dependency injection, and ensure security best practices. When exploring, trace request flows from routes through services to database operations.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)
   - Pod restart requirements after code changes
   - Emergency hotfix procedures

2. **Database Management** (`docs/standards/database-management.md`)
   - MANDATORY: Never apply database config changes without backups
   - Backup verification before any database operations
   - Recovery procedures
   - Alembic migrations for schema changes

3. **Version Control Standards** (`docs/standards/version-control-standards.md`)
   - Commit message format (conventional commits: feat, fix, docs, etc.)
   - Branch naming: `<type>/<short-description>`
   - Feature branch workflow - NEVER commit directly to main
   - Pull request requirements

### Development Workflow Standards

4. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - CRITICAL: Always build Docker images with `--no-cache`
   - Rollback procedures

5. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Update kustomization.yaml with new versions
   - Never use `latest` tag

6. **Port-Forwarding Standards** (`docs/standards/port-forwarding.md`)
   - API Service on port 8000
   - Prometheus metrics on port 9090
   - Port-forward setup and troubleshooting

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images (0.x.x for development)
- **Endpoints**: Use `127.0.0.1` for local development
- **Builds**: Always use `--no-cache` for Docker builds
- **Backups**: Create backups before any database changes
- **Documentation**: Update docs after testing, before PR
- **CORS**: Include `http://127.0.0.1:3000` in allowed origins

For complete standards, see `docs/standards/INDEX.md`.
