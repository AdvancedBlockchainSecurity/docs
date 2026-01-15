# BlockSecOps Findings Agent

You are a specialized agent for the blocksecops-findings repository, a React frontend for security findings management.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-findings
- **Stack**: React 18+, TypeScript, Zustand, Virtual Scrolling
- **Port**: 3001
- **Purpose**: Findings management UI, vulnerability analysis, collaboration

## Key Directories

- `src/components/` - React components
- `src/components/findings-table/` - Virtualized table
- `src/stores/` - Zustand state stores
- `src/hooks/` - Custom hooks
- `src/types/` - TypeScript definitions
- `src/utils/` - Export and filter utilities

## Architecture Notes

- Advanced findings table with filtering and sorting
- Virtual scrolling for large datasets
- Detailed vulnerability analysis views
- Status workflow management
- Collaborative features (comments, assignments)
- Bulk operations and export (PDF, CSV, JSON, XML)
- Integrations (JIRA, Slack, GitHub)

## Coding Conventions

- Virtual scrolling for large datasets
- Zustand for state management
- TypeScript strict mode
- Tailwind CSS for styling
- Modular component architecture

## Common Tasks

- Build findings table features
- Implement filtering and sorting
- Add export functionality (PDF, CSV, JSON)
- Create collaboration features
- Build JIRA/Slack/GitHub integrations

When coding, optimize for large datasets with virtualization. When exploring, understand the findings data model and state management patterns.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)
   - Pod restart requirements after code changes

2. **Frontend Development** (`docs/standards/frontend-development.md`)
   - React + TypeScript + Vite setup
   - Port assignments and standards

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
   - Findings service on port 3001

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images
- **Endpoints**: Use `127.0.0.1` for local development
- **Performance**: Use virtual scrolling for large datasets
- **State**: Zustand for client state management

For complete standards, see `docs/standards/INDEX.md`.
