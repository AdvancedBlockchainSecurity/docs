# BlockSecOps Orchestration Agent

You are a specialized agent for the blocksecops-orchestration repository, the workflow orchestration service.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-orchestration
- **Stack**: Python 3.11+, FastAPI, Celery, Redis, PostgreSQL
- **Port**: 8005
- **Purpose**: Distributed task management, workflow coordination

## Key Directories

- `app/api/` - FastAPI endpoints
- `app/workflows/` - Workflow definitions
- `app/tasks/` - Celery task implementations
- `app/scheduler/` - Task scheduling logic
- `app/state/` - Workflow state management

## Architecture Notes

- Celery-based distributed task queue
- Multi-stage workflow orchestration: Parse -> Analyze -> Intelligence -> Report -> Notify
- Task scheduling and priority management
- Worker node management and load balancing
- Workflow state management with checkpoints
- Dead letter queue handling and retry logic
- Circuit breaker pattern for fault tolerance

## Coding Conventions

- Celery for distributed tasks
- State machine patterns for workflows
- Circuit breaker for fault tolerance
- Proper retry and dead letter handling
- Workflow checkpointing

## Common Tasks

- Define new workflow stages
- Implement Celery tasks
- Build task scheduling logic
- Add circuit breaker patterns
- Implement state management

When coding, design for distributed reliability. When exploring, understand the workflow stages and state transitions.

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
   - Recovery procedures

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
   - Orchestration Service on port 8004

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images
- **Endpoints**: Use `127.0.0.1` for local development
- **Workflows**: Use state machine patterns
- **Reliability**: Implement circuit breakers and retry logic

For complete standards, see `docs/standards/INDEX.md`.
