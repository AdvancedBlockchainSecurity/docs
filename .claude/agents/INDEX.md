# BlockSecOps Agent Index

This directory contains specialized AI agents for each repository in the BlockSecOps ecosystem. Each agent is configured for both **coding assistance** (implementing features, fixing bugs, writing tests) and **codebase exploration** (understanding architecture, finding patterns, researching functionality).

## Quick Reference

| Agent | Repository | Purpose | Port |
|-------|-----------|---------|------|
| [blocksecops-analysis](./blocksecops-analysis.md) | `blocksecops-analysis` | React analysis workflow UI | 3002 |
| [blocksecops-api-service](./blocksecops-api-service.md) | `blocksecops-api-service` | FastAPI main HTTP gateway | 8000 |
| [blocksecops-aws-infrastructure](./blocksecops-aws-infrastructure.md) | `blocksecops-aws-infrastructure` | AWS infrastructure configs | - |
| [blocksecops-cli](./blocksecops-cli.md) | `blocksecops-cli` | Python CLI tool | - |
| [blocksecops-contract-parser](./blocksecops-contract-parser.md) | `blocksecops-contract-parser` | Rust contract parser | 9000 |
| [blocksecops-dashboard](./blocksecops-dashboard.md) | `blocksecops-dashboard` | React main dashboard | 3000 |
| [blocksecops-data-service](./blocksecops-data-service.md) | `blocksecops-data-service` | Database operations service | 8002 |
| [blocksecops-docs](./blocksecops-docs.md) | `blocksecops-docs` | Documentation site | - |
| [blocksecops-findings](./blocksecops-findings.md) | `blocksecops-findings` | React findings management UI | 3001 |
| [blocksecops-intelligence-engine](./blocksecops-intelligence-engine.md) | `blocksecops-intelligence-engine` | ML/AI analysis service | 8001 |
| [blocksecops-monitoring](./blocksecops-monitoring.md) | `blocksecops-monitoring` | Observability infrastructure | 3001/9091 |
| [blocksecops-notification](./blocksecops-notification.md) | `blocksecops-notification` | Real-time notifications | 8003 |
| [blocksecops-orchestration](./blocksecops-orchestration.md) | `blocksecops-orchestration` | Workflow orchestration | 8005 |
| [blocksecops-shared](./blocksecops-shared.md) | `blocksecops-shared` | Multi-language shared library | - |
| [blocksecops-tool-integration](./blocksecops-tool-integration.md) | `blocksecops-tool-integration` | Scanner orchestration | 8004 |
| [blocksecops-tools](./blocksecops-tools.md) | `blocksecops-tools` | Tool adapters | - |
| [soliditybom](./soliditybom.md) | `SolidityBOM` | SBOM generator for Solidity | - |
| [soliditydefend](./soliditydefend.md) | `SolidityDefend` | SAST scanner for Solidity | - |
| [taskdocs-blocksecops](./taskdocs-blocksecops.md) | `TaskDocs-BlockSecOps` | Development task documentation | - |

## Agent Categories

### Platform Services (16 agents)

Core platform microservices:

- **Frontend Services**: dashboard, analysis, findings
- **Backend Services**: api-service, data-service, notification, orchestration, tool-integration
- **Infrastructure**: aws-infrastructure, contract-parser, shared, tools, monitoring
- **Documentation**: docs

### Security Tools (2 agents)

Standalone security tools:

- **SolidityBOM**: SBOM generator (Rust)
- **SolidityDefend**: SAST scanner (Rust, 287+ detectors)

### Documentation (1 agent)

- **TaskDocs-BlockSecOps**: Development documentation hub

## Standards Included in All Agents

Every agent includes references to these critical standards:

1. **Core Development Rules** - Codebase-first development, 127.0.0.1 endpoints
2. **Version Control Standards** - Feature branch workflow, conventional commits
3. **Docker Image Versioning** - Semantic versioning (MAJOR.MINOR.PATCH)
4. **Testing & Deployment** - Test before deploy, --no-cache builds
5. **Port-Forwarding Standards** - Standard port mappings

## Usage

Each agent file contains:

1. **Repository Context** - Path, stack, port, purpose
2. **Key Directories** - Important directories to know
3. **Architecture Notes** - System design information
4. **Coding Conventions** - Patterns to follow
5. **Common Tasks** - What you'll typically do
6. **Platform Standards Reference** - Standards to follow

## Standards Location

All standards are located in `docs/standards/`:

```
docs/standards/
├── INDEX.md                              # Standards index
├── core-development-rules.md             # Critical development rules
├── database-management.md                # Database operations
├── version-control-standards.md          # Git workflow
├── docker-image-versioning.md            # Docker versioning
├── port-forwarding.md                    # Port mappings
├── testing-deployment.md                 # Testing and deployment
├── frontend-development.md               # Frontend standards
├── dashboard-development.md              # Dashboard specifics
├── ml-development.md                     # ML/AI standards
├── INTELLIGENCE-INTEGRATION-STANDARDS.md # Intelligence engine
└── ... (see INDEX.md for full list)
```

## Adding New Agents

When adding a new repository/service, create an agent file following this template:

1. Copy an existing agent file as a template
2. Update repository context (path, stack, port, purpose)
3. Update key directories
4. Update architecture notes and coding conventions
5. Include the Platform Standards Reference section
6. Add the agent to this INDEX.md

---

**Last Updated**: January 2026
**Total Agents**: 19
