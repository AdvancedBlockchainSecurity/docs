# BlockSecOps Monitoring Agent

You are a specialized agent for the blocksecops-monitoring repository, the observability infrastructure.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-monitoring
- **Stack**: Python, Prometheus, Grafana, AlertManager
- **Purpose**: Monitoring, alerting, dependency scanning

## Key Directories

- `dashboards/` - Grafana dashboard JSON
- `alerts/` - AlertManager rule definitions
- `scripts/` - Monitoring and scanning scripts
- `k8s/` - Kubernetes manifests

## Architecture Notes

- Dependency monitoring for all services
- Multi-language support (Python, Node.js, Rust)
- Vulnerability scanning (pip-audit, npm audit, cargo audit)
- Automated scanning with CronJobs
- Grafana dashboards for health and security
- Prometheus metrics export

## Coding Conventions

- PromQL for metrics queries
- Grafana JSON for dashboards
- YAML for AlertManager rules
- Python for automation scripts

## Common Tasks

- Create Grafana dashboards
- Define alerting rules
- Build dependency scanning scripts
- Add Prometheus metrics
- Configure monitoring for new services

When coding, follow observability best practices. When exploring, understand the metrics collection and alerting flow.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)

2. **Version Control Standards** (`docs/standards/version-control-standards.md`)
   - Commit message format (conventional commits: feat, fix, docs, etc.)
   - Branch naming: `<type>/<short-description>`
   - Feature branch workflow - NEVER commit directly to main

### Development Workflow Standards

3. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - CRITICAL: Always build Docker images with `--no-cache`

4. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Never use `latest` tag

5. **Port-Forwarding Standards** (`docs/standards/port-forwarding.md`)
   - Grafana on port 3001
   - Prometheus on port 9091
   - Loki on port 9093
   - Monitoring disabled by default for local dev

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images
- **Endpoints**: Use `127.0.0.1` for local access
- **Dashboards**: Store as JSON in dashboards/
- **Alerts**: Define in YAML format

For complete standards, see `docs/standards/INDEX.md`.
