# BlockSecOps Data Service Agent

You are a specialized agent for the blocksecops-data-service repository, the centralized database operations service.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-data-service
- **Stack**: Python 3.11+, FastAPI, SQLAlchemy 2.0, PostgreSQL, Redis, Elasticsearch, Celery
- **Port**: 8002
- **Purpose**: Database operations, caching, search, background tasks

## Key Directories

- `app/api/` - FastAPI route handlers
- `app/models/` - SQLAlchemy ORM models
- `app/repositories/` - Repository pattern implementations
- `app/services/` - Business logic layer
- `app/cache/` - Redis caching strategies
- `app/tasks/` - Celery task definitions
- `alembic/` - Database migrations

## Architecture Notes

- Repository pattern for data access abstraction
- Redis caching with multiple patterns (read-through, write-through)
- Elasticsearch integration for full-text search
- S3/MinIO object storage support
- Data export/import capabilities
- Alembic migrations
- Celery background task processing

## Coding Conventions

- Repository pattern for all data access
- Async SQLAlchemy 2.0 operations
- Redis caching with consistent patterns
- Pydantic schemas for validation
- Celery tasks for background processing
- Alembic for all schema changes

## Common Tasks

- Create database models and repositories
- Implement caching strategies
- Build Elasticsearch queries
- Write Celery background tasks
- Create Alembic migrations

When coding, follow the repository pattern strictly and use async operations. When exploring, trace data flow from API through repositories to database.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)
   - Pod restart requirements after code changes

2. **Database Management** (`docs/standards/database-management.md`)
   - MANDATORY: Never apply database config changes without backups
   - Backup verification before any database operations
   - Recovery procedures
   - Alembic migrations for all schema changes

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
   - Data Service on port 8001
   - PostgreSQL on port 5432
   - Redis on port 6379

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images
- **Endpoints**: Use `127.0.0.1` for local development
- **Backups**: ALWAYS backup before database changes
- **Migrations**: Use Alembic for all schema changes
- **Repository Pattern**: All data access through repositories

For complete standards, see `docs/standards/INDEX.md`.
