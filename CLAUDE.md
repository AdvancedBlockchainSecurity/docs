# Apogee Development Guide

This project contains documentation and standards for the Apogee platform.

## Project Agents

When working on specific repositories, use the appropriate agent by referencing its file. Each agent includes repository context, coding conventions, and platform standards.

### Platform Services

| Repository | Agent File | Use For |
|------------|------------|---------|
| blocksecops-analysis | @.claude/agents/blocksecops-analysis.md | React analysis workflow UI |
| blocksecops-api-service | @.claude/agents/blocksecops-api-service.md | FastAPI main HTTP gateway |
| blocksecops-gcp-infrastructure | @.claude/agents/blocksecops-gcp-infrastructure.md | GCP/Kubernetes infrastructure |
| 0xapogee-cli | @.claude/agents/0xapogee-cli.md | Python CLI tool |
| blocksecops-contract-parser | @.claude/agents/blocksecops-contract-parser.md | Rust contract parser |
| blocksecops-dashboard | @.claude/agents/blocksecops-dashboard.md | React main dashboard |
| blocksecops-data-service | @.claude/agents/blocksecops-data-service.md | Database operations |
| blocksecops-docs | @.claude/agents/blocksecops-docs.md | Documentation site |
| blocksecops-findings | @.claude/agents/blocksecops-findings.md | React findings management |
| blocksecops-intelligence-engine | @.claude/agents/blocksecops-intelligence-engine.md | ML/AI analysis service |
| blocksecops-monitoring | @.claude/agents/blocksecops-monitoring.md | Observability infrastructure |
| blocksecops-notification | @.claude/agents/blocksecops-notification.md | Real-time notifications |
| blocksecops-orchestration | @.claude/agents/blocksecops-orchestration.md | Workflow orchestration |
| blocksecops-shared | @.claude/agents/blocksecops-shared.md | Multi-language shared library |
| blocksecops-tool-integration | @.claude/agents/blocksecops-tool-integration.md | Scanner orchestration |
| blocksecops-tools | @.claude/agents/blocksecops-tools.md | Tool adapters |

### Security Tools

| Repository | Agent File | Use For |
|------------|------------|---------|
| SolidityBOM | @.claude/agents/soliditybom.md | SBOM generator for Solidity |
| SolidityDefend | @.claude/agents/soliditydefend.md | SAST scanner (287+ detectors) |

### Documentation

| Repository | Agent File | Use For |
|------------|------------|---------|
| TaskDocs-Apogee | @.claude/agents/taskdocs-blocksecops.md | Development task documentation |

## Platform Standards

All development must follow these standards (see `standards/` for full documentation):

### Critical Rules

1. **Codebase-First**: All changes must exist in Git before being applied
2. **Endpoints**: Always use `127.0.0.1` (not localhost) for local development
3. **Backups**: MANDATORY backup before any database changes
4. **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
5. **Docker Builds**: Use versioned tags; `--no-cache` only when debugging build issues
6. **Report All Issues**: ALWAYS report discovered bugs, edge cases, or potential problems - even if not directly related to the current task

### Issue Reporting

**ALWAYS proactively report issues discovered during work:**

- Bugs found in existing code (even if unrelated to current task)
- Edge cases that could cause problems
- Missing error handling or validation
- Security concerns
- Performance issues
- Data integrity problems (e.g., empty fingerprints, malformed data)
- Inconsistencies between documentation and implementation
- Technical debt that should be tracked

**Format:** When reporting issues, include:
1. What was discovered
2. Where it was found (file, function, line)
3. Potential impact
4. Suggested fix or investigation steps

**Document discovered issues in:** `~/Git/TaskDocs-BlockSecOps/` or relevant workflow/playbook docs

### Standards Index

- @standards/INDEX.md - Full standards index
- @standards/core-development-rules.md - Critical development rules
- @standards/version-control-standards.md - Git workflow
- @standards/database-management.md - Database operations
- @standards/docker-image-versioning.md - Semantic versioning
- @standards/port-forwarding.md - Port mappings

## Usage Examples

```
# Working on the API service
Read @.claude/agents/blocksecops-api-service.md and help me add a new endpoint for webhooks

# Working on the dashboard
Read @.claude/agents/blocksecops-dashboard.md and fix the vulnerability table filtering

# Working on SolidityDefend
Read @.claude/agents/soliditydefend.md and implement a new reentrancy detector

# Working on infrastructure
Read @.claude/agents/blocksecops-gcp-infrastructure.md and add a new Kubernetes service for GCP
```

## Port Reference

| Port | Service |
|------|---------|
| 3000 | Dashboard (via Traefik) |
| 3001 | Findings UI / Grafana |
| 3002 | Analysis UI |
| 8000 | API Service |
| 8001 | Data Service |
| 8002 | Intelligence Engine |
| 8003 | Notification Service |
| 8004 | Orchestration |
| 8005 | Tool Integration |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 9000 | Contract Parser |
