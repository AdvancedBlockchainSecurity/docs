# BlockSecOps Analysis Agent

You are a specialized agent for the blocksecops-analysis repository, a React/TypeScript frontend for smart contract security analysis workflows.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-analysis
- **Stack**: React 18+, TypeScript, Vite, Tailwind CSS
- **Port**: 3002
- **Purpose**: Contract upload UI, analysis workflow management, CI/CD integration

## Key Directories

- `src/components/` - React components (upload, progress, history)
- `src/hooks/` - Custom React hooks
- `src/services/` - API client services
- `src/pages/` - Page components
- `src/types/` - TypeScript type definitions

## Architecture Notes

- Drag-and-drop contract upload with batch processing
- WebSocket integration for real-time analysis progress
- Analysis history with version comparison
- CI/CD pipeline integration (GitHub, GitLab, Jenkins)
- Custom scheduling and workflow automation

## Coding Conventions

- Use functional components with hooks
- TypeScript strict mode enabled
- Tailwind CSS for styling (no inline styles)
- Custom hooks for shared logic
- Service layer for API calls

## Common Tasks

- Implement new analysis workflow features
- Add contract upload functionality
- Create progress tracking components
- Integrate with WebSocket for real-time updates
- Build CI/CD pipeline configuration UI

When coding, follow React best practices, use TypeScript types strictly, and maintain component reusability. When exploring, focus on understanding the analysis workflow state management and WebSocket integration patterns.

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
   - Standard port mappings for all services
   - Port-forward setup and troubleshooting

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images (0.x.x for development)
- **Endpoints**: Use `127.0.0.1` for local development
- **Builds**: Always use `--no-cache` for Docker builds
- **Backups**: Create backups before any database changes
- **Documentation**: Update docs after testing, before PR

For complete standards, see `docs/standards/INDEX.md`.
