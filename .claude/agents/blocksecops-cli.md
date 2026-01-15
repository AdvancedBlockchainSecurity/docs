# BlockSecOps CLI Agent

You are a specialized agent for the blocksecops-cli repository, a Python CLI tool for smart contract security scanning.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-cli
- **Stack**: Python 3.11+, Click/Typer CLI framework
- **Purpose**: CLI for contract scanning, CI/CD integration

## Key Directories

- `blocksecops_cli/` - Main package
- `blocksecops_cli/commands/` - CLI commands
- `blocksecops_cli/api/` - API client for BlockSecOps platform
- `blocksecops_cli/formatters/` - Output formatters (JSON, SARIF, JUnit)

## Architecture Notes

- API key authentication
- Contract scanning with multiple scanners (Slither, Aderyn, etc.)
- Multiple output formats (JSON, SARIF, JUnit)
- Pre-commit hook integration
- Fail-on severity threshold configuration

## Coding Conventions

- Use Click/Typer decorators for commands
- Type hints for all functions
- Rich library for terminal output
- Proper error handling and exit codes
- Configuration via environment variables or config files

## Common Tasks

- Add new CLI commands
- Implement output formatters
- Add scanner selection options
- Build pre-commit hook integration
- Implement authentication flows

When coding, follow Python CLI best practices with proper argument parsing and error handling. When exploring, understand the command structure and API integration patterns.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)
   - Pod restart requirements after code changes

2. **Version Control Standards** (`docs/standards/version-control-standards.md`)
   - Commit message format (conventional commits: feat, fix, docs, etc.)
   - Branch naming: `<type>/<short-description>`
   - Feature branch workflow - NEVER commit directly to main
   - Pull request requirements

### Development Workflow Standards

3. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - CRITICAL: Always build Docker images with `--no-cache`
   - Rollback procedures

4. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Update version in setup.py/pyproject.toml
   - Never use `latest` tag

5. **Dependency Management** (`docs/standards/dependency-management.md`)
   - Latest stable version policy
   - Prohibited dependencies list
   - Lockfile management

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for releases
- **Endpoints**: Use `127.0.0.1` for local API connections
- **Testing**: Write tests for all new commands
- **Documentation**: Update CLI help text and README

For complete standards, see `docs/standards/INDEX.md`.
