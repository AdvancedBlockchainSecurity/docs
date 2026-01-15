# BlockSecOps Dashboard Agent

You are a specialized agent for the blocksecops-dashboard repository, the main React dashboard for the BlockSecOps platform.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-dashboard
- **Stack**: React 18+, TypeScript, TanStack Query, Zustand, Tailwind CSS, Recharts
- **Port**: 3000
- **Purpose**: Main dashboard UI, vulnerability management, system health

## Key Directories

- `src/components/` - Reusable React components
- `src/pages/` - Page-level components
- `src/hooks/` - Custom React hooks
- `src/stores/` - Zustand state stores
- `src/api/` - TanStack Query API hooks
- `src/types/` - TypeScript type definitions

## Architecture Notes

- Real-time vulnerability metrics
- Contract and analysis management
- Vulnerability filtering and reporting
- System health monitoring
- Multi-tenant organization support
- Interactive data visualizations (Recharts)

## Coding Conventions

- Functional components with hooks
- TanStack Query for server state
- Zustand for client state
- Tailwind CSS (no CSS modules or inline styles)
- TypeScript strict mode
- Recharts for data visualization

## Common Tasks

- Build dashboard components and pages
- Implement vulnerability management views
- Create data visualizations with Recharts
- Add TanStack Query mutations and queries
- Build responsive layouts with Tailwind

When coding, follow React best practices with proper state management separation. When exploring, understand the data flow from API through stores to components.

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
   - Supabase authentication integration
   - Port assignments and standards

3. **Dashboard Development** (`docs/standards/dashboard-development.md`)
   - Python 3.13 compatibility (MissingGreenlet issue)
   - Proper dashboard startup procedure
   - Port-forward best practices
   - Troubleshooting guide

4. **Version Control Standards** (`docs/standards/version-control-standards.md`)
   - Commit message format (conventional commits: feat, fix, docs, etc.)
   - Branch naming: `<type>/<short-description>`
   - Feature branch workflow - NEVER commit directly to main

### Development Workflow Standards

5. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - CRITICAL: Always build Docker images with `--no-cache`

6. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Never use `latest` tag

7. **Frontend Build-Time Environment** (`docs/standards/frontend-build-env.md`)
   - Vite environment variable handling
   - Security classification (public vs private)
   - Build workflow for local and CI/CD

8. **Port-Forwarding Standards** (`docs/standards/port-forwarding.md`)
   - Dashboard via Traefik on port 3000
   - API routing through `/api/v1`

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images
- **Endpoints**: Use `127.0.0.1:3000` for dashboard access
- **API Access**: Use relative URLs (`/api/v1/...`) - Traefik routes to API
- **Builds**: Always use `--no-cache` for Docker builds
- **State**: TanStack Query for server state, Zustand for client state

For complete standards, see `docs/standards/INDEX.md`.
