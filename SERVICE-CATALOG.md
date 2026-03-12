# Apogee Platform Service Catalog

**Platform:** Apogee (formerly BlockSecOps)
**Infrastructure:** GCP GKE (us-west1, cluster: apogee-production-gke)
**Domain:** https://app.0xapogee.com
**Last Updated:** 2026-03-12

---

## Overview

The Apogee platform consists of 18 repositories: 7 backend microservices, 2 frontend applications, 3 shared libraries/tools, 3 IDE extensions, and 3 infrastructure/documentation repos.

---

## Backend Services

All backend services are containerized and deployed to GKE. Each has Kustomize manifests (`k8s/base/` + `k8s/overlays/gcp/`), ExternalSecrets for GCP Secret Manager integration, and NetworkPolicies with default-deny-all.

| Service | Repo | Version | Language | Port | Namespace |
|---------|------|---------|----------|------|-----------|
| API Service | `blocksecops-api-service` | 0.29.80 | Python 3.13 / FastAPI | 8000 | api-service-prod |
| Data Service | `blocksecops-data-service` | 0.2.7 | Python 3.11 / FastAPI | 8001 | data-service-prod |
| Intelligence Engine | `blocksecops-intelligence-engine` | 0.3.7 | Python 3.11 / FastAPI | 8000 | intelligence-engine-prod |
| Notification | `blocksecops-notification` | 0.2.6 | Python 3.11 / FastAPI | 8003 | notification-prod |
| Orchestration | `blocksecops-orchestration` | 0.10.9 | Python 3.11 / Celery + FastAPI | 8004 | orchestration-prod |
| Tool Integration | `blocksecops-tool-integration` | 0.5.29 | Python 3.11 / FastAPI | 8005 | tool-integration-prod |
| Contract Parser | `blocksecops-contract-parser` | 0.2.2 | Rust 1.90 / Axum | 9000 (base) / 8007 (gcp) | contract-parser-prod |

### API Service (`blocksecops-api-service`)

**Function:** Main API gateway and orchestrator for the Apogee platform.

- JWT authentication, session management, RBAC
- Contract upload and management
- Scan orchestration (dispatches to tool-integration)
- Vulnerability aggregation and reporting
- Stripe billing integration, organization/team management

**Dependencies:** PostgreSQL, Redis, all other backend services
**Version Source:** `pyproject.toml`
**Image:** `us-west1-docker.pkg.dev/.../apogee/api-service:0.29.80`

### Data Service (`blocksecops-data-service`)

**Function:** Database operations, caching, data processing, search, and analytics.

- Repository pattern for all data access
- Alembic database migrations
- Elasticsearch integration (optional) for search
- S3/MinIO storage for artifacts
- Contract data, analysis results, vulnerability records

**Dependencies:** PostgreSQL, Redis, Elasticsearch (optional), InfluxDB (optional)
**Version Source:** `pyproject.toml`
**Image:** `us-west1-docker.pkg.dev/.../apogee/data-service:0.2.7`

### Intelligence Engine (`blocksecops-intelligence-engine`)

**Function:** Embedding service for semantic analysis, deduplication, and RAG retrieval.

- Sentence transformer embeddings (all-MiniLM-L6-v2, 384-dim, CPU-only)
- OpenAI embeddings (optional fallback)
- Semantic similarity search for vulnerability deduplication
- RAG retrieval for AI-assisted analysis

**Dependencies:** Stateless (no direct DB); receives requests from api-service and orchestration
**Version Source:** `pyproject.toml`
**Image:** Uses custom base image (`harbor.blocksecops.local/...intelligence-engine-base:1.0.0-5ede3c61`)
**Note:** Base image contains ML dependencies to reduce build time (~20min to ~2-3min)

### Notification Service (`blocksecops-notification`)

**Function:** Real-time notifications, WebSocket connections, and multi-channel delivery.

- WebSocket endpoint for real-time dashboard updates
- Email notifications (SMTP templates)
- Slack, Microsoft Teams, Discord integrations
- Webhook delivery for external systems
- Celery background workers for async delivery

**Dependencies:** PostgreSQL, Redis
**Version Source:** `pyproject.toml`
**Image:** `us-west1-docker.pkg.dev/.../apogee/notification:0.2.6`

### Orchestration Service (`blocksecops-orchestration`)

**Function:** Distributed task queue, workflow orchestration, and job scheduling.

- Celery-based task queue with Redis broker
- Multi-stage scan workflows (parse -> analyze -> deduplicate -> report)
- Task routing across queues: analysis, reports, notifications, maintenance
- Circuit breaker patterns for resilience
- Flower monitoring UI (port 5555)
- 4 containers: worker, beat, monitor, API

**Dependencies:** PostgreSQL, Redis (broker + backend)
**Version Source:** `pyproject.toml`
**Image:** Uses custom base image with security tool dependencies
**Note:** Supports GCP Spot VM scheduling via tolerations

### Tool Integration Service (`blocksecops-tool-integration`)

**Function:** Kubernetes Jobs manager for scanner execution and ConfigMap orchestration.

- Creates and manages K8s Jobs for each scanner invocation
- ConfigMap-based source code delivery to scanner pods
- Scanner version management via `scanner-versions-configmap.yaml`
- Supports 16 scanners across multiple categories:
  - **Solidity Static Analysis:** Slither, Aderyn, Semgrep, Solhint, Wake, SolidityDefend
  - **Vyper:** Vyper compiler analysis
  - **Formal Verification:** Halmos
  - **Fuzzing:** Echidna, Medusa, Moccasin
  - **Solana/Rust:** Sol-Azy, Sec3-Xray, Trident, Cargo-Fuzz-Solana, RustDefend

**Dependencies:** PostgreSQL, Redis, Kubernetes API (RBAC for Job/ConfigMap management)
**Version Source:** `pyproject.toml`
**Image:** `us-west1-docker.pkg.dev/.../apogee/tool-integration:0.5.29`
**Scanner Versions:** Managed via ConfigMap (single source of truth), not hardcoded

### Contract Parser (`blocksecops-contract-parser`)

**Function:** High-performance Solidity contract parsing, AST generation, and source mapping.

- Solidity AST analysis and dependency tracking
- Multi-version compiler support
- Source mapping for vulnerability location
- Performance: <1ms small contracts, <100ms large contracts
- Compiled Rust binary (minimal runtime image)

**Dependencies:** Stateless; Redis for caching
**Version Source:** `Cargo.toml`
**Image:** `us-west1-docker.pkg.dev/.../apogee/contract-parser:0.2.2`

---

## Frontend Applications

Both frontends are React/TypeScript SPAs built with Vite, served via nginx in containerized deployments.

| Service | Repo | Version | Port | Namespace |
|---------|------|---------|------|-----------|
| Dashboard | `blocksecops-dashboard` | 0.46.25 | 3000 | dashboard-prod |
| Admin Portal | `blocksecops-admin-portal` | 0.7.12 | 3000 | admin-portal-prod |

### Dashboard (`blocksecops-dashboard`)

**Function:** Main user-facing dashboard for contract analysis and vulnerability management.

- Contract upload and scan initiation
- Real-time analysis tracking (WebSocket)
- Vulnerability dashboard with severity filtering
- Report generation and export
- Organization and team management
- Stripe billing and subscription management
- WalletConnect integration for Web3 auth

**Stack:** React 18+, TypeScript, Vite, TanStack Query, Zustand, Tailwind CSS, Headless UI
**Auth:** Supabase (URL + anon key passed as build args)
**Version Source:** `package.json`

### Admin Portal (`blocksecops-admin-portal`)

**Function:** Administrative dashboard for platform operators.

- User and organization management
- Emergency actions (suspend accounts, force password reset)
- Platform metrics and monitoring
- Admin role verification with MFA requirement
- IP allowlist enforcement

**Stack:** React, TypeScript, Vite
**Auth:** Supabase (separate admin project)
**Security:** IP allowlist, MFA required, HttpOnly cookies
**Version Source:** `package.json`
**Replicas:** 2 (HA with pod anti-affinity)

---

## Shared Libraries & Tools

| Repo | Version | Language | Distribution |
|------|---------|----------|-------------|
| `blocksecops-shared` | 0.1.0 | Rust / Python / TypeScript | Library (multi-lang) |
| `blocksecops-cli` | 0.1.0 | Python | pip (`0xapogee-cli`) |
| `blocksecops-vulnerabilities` | N/A | YAML / JSON | Data repository |

### Shared Library (`blocksecops-shared`)

**Function:** Cross-language shared library providing consistent types, validation, and crypto functions.

- **Rust core:** High-performance implementations (crypto, validation, parsing)
- **Python bindings:** PyO3-based Pydantic models with Rust acceleration (10x speedup)
- **TypeScript bindings:** WASM-based type definitions (8x speedup)
- Auth utilities: JWT validation, PBKDF2 password hashing, API key generation
- SWC vulnerability mappings
- Tier configuration source of truth (`tier-config/tiers.json`)

### CLI (`blocksecops-cli`)

**Function:** Command-line interface for smart contract scanning.

- Authentication via system keyring (secure credential storage)
- Scan commands with multiple output formats (JSON, SARIF, JUnit)
- Pre-commit hook integration
- CI/CD pipeline support (GitHub Actions, GitLab CI)
- Default API endpoint: `https://api.0xapogee.com`

### Vulnerabilities Database (`blocksecops-vulnerabilities`)

**Function:** Vulnerability definitions, detection patterns, and threat intelligence.

- SWC-based vulnerability definitions
- Custom detection patterns and classification rules
- CVE mappings and threat intelligence data
- JSON/YAML schemas with validation tools
- Import scripts for external vulnerability feeds

---

## IDE Extensions

| Repo | Version | Platform | Language |
|------|---------|----------|----------|
| `blocksecops-vscode` | 0.1.0 | VS Code 1.85+ | TypeScript |
| `blocksecops-nvim` | N/A | Neovim / Vim 8+ | Lua |
| `blocksecops-intellij` | 0.1.0 | IntelliJ 2023.3+ | Kotlin |

All IDE extensions delegate scanning to the `blocksecops-cli` tool. API endpoints are user-configurable, not hardcoded.

### VS Code Extension (`blocksecops-vscode`)
- Inline diagnostics with severity filtering
- Scan-on-save functionality
- CodeLens integration
- Configurable via VS Code settings

### Neovim Plugin (`blocksecops-nvim`)
- ALE linting integration
- Virtual text and signs for findings
- Configurable via Vim global variables
- Supports both Neovim (Lua) and Vim 8+ (Vimscript)

### IntelliJ Plugin (`blocksecops-intellij`)
- External annotator for inline findings
- Settings panel for configuration
- Gradle-based build with signing support

---

## Infrastructure & Documentation

| Repo | Function |
|------|----------|
| `blocksecops-gcp-infrastructure` | Terraform + Kustomize IaC for GCP |
| `blocksecops-docs` | Platform documentation (Markdown) |

### GCP Infrastructure (`blocksecops-gcp-infrastructure`)

**Function:** Infrastructure as Code for the complete GCP deployment.

- **Terraform modules:** GKE cluster, Cloud SQL, Memorystore, Artifact Registry, Load Balancer, Cloud Armor, Networking
- **GKE Node Pools:**
  - Default: `e2-standard-2` (2-4 nodes, auto-repair/upgrade)
  - Scanner: `e2-standard-4` (0-3 Spot VM nodes, scale-to-zero)
- **Database:** Cloud SQL PostgreSQL 15.4 with pgvector
- **Cache:** Memorystore Redis 7.0
- **Secrets:** GCP Secret Manager with ExternalSecrets Operator
- **Security:** Private nodes, shielded nodes, Workload Identity, Binary Authorization, Cloud KMS encryption
- **Networking:** Cloud Armor WAF (10 rules), Google-managed TLS, Cloudflare proxy
- **GitOps:** ArgoCD v2.13.3

### Documentation (`blocksecops-docs`)

**Function:** Platform documentation covering all user-facing and developer topics.

- Getting started guides
- API reference documentation
- Architecture documentation
- Deployment playbooks
- Security guides
- Integration guides (CI/CD, IDE, CLI)
- Troubleshooting and support

---

## Related

### Marketing Website (`blocksecops_com`)

**Function:** Marketing and content platform at blocksecops.com.

- **Stack:** Next.js 15 + Payload CMS + TypeScript
- **Version:** 0.1.0
- **Features:** CMS-backed content, contracts trending, security research
- **Security:** Cloudflare Turnstile, DOMPurify sanitization

---

## Service Communication Map

```
                    ┌─────────────┐
                    │  Cloudflare  │
                    │   (Proxy)    │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  GCP Gateway │
                    │  (Cloud LB)  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──┐  ┌──────▼──┐  ┌─────▼──────┐
       │Dashboard │  │  Admin  │  │ API Service │◄── CLI / IDE Extensions
       │  :3000   │  │  :3000  │  │   :8000     │
       └──────────┘  └─────────┘  └──────┬──────┘
                                         │
                    ┌────────────┬────────┼────────┬──────────────┐
                    │            │        │        │              │
             ┌──────▼──┐ ┌──────▼──┐ ┌───▼────┐ ┌─▼──────────┐ ┌▼──────────┐
             │  Data    │ │ Intel   │ │Notif.  │ │Orchestrate │ │  Contract │
             │ Service  │ │ Engine  │ │Service │ │  Service   │ │  Parser   │
             │  :8001   │ │ :8000   │ │ :8003  │ │   :8004    │ │:9000/8007 │
             └────┬─────┘ └─────────┘ └───┬────┘ └─────┬──────┘ └───────────┘
                  │                        │            │
                  │                        │     ┌──────▼──────┐
                  │                        │     │    Tool     │
                  │                        │     │ Integration │
                  │                        │     │   :8005     │
                  │                        │     └──────┬──────┘
                  │                        │            │
            ┌─────▼─────┐           ┌──────▼──┐  ┌─────▼──────┐
            │ PostgreSQL │           │  Redis  │  │ Scanner K8s│
            │   :5432    │           │  :6379  │  │   Jobs     │
            └────────────┘           └─────────┘  └────────────┘
```

---

## Port Assignments

| Port | Service | Protocol |
|------|---------|----------|
| 3000 | Dashboard | HTTP |
| 3000 | Admin Portal | HTTP |
| 5432 | PostgreSQL | TCP (SSL) |
| 5555 | Orchestration Flower UI | HTTP |
| 6379 | Redis | TCP (TLS) |
| 8000 | API Service | HTTP |
| 8000 | Intelligence Engine | HTTP |
| 8001 | Data Service | HTTP |
| 8003 | Notification Service | HTTP/WS |
| 8004 | Orchestration API | HTTP |
| 8005 | Tool Integration | HTTP |
| 9000 | Contract Parser (base) | HTTP |
| 8007 | Contract Parser (gcp) | HTTP |

---

## Database Dependencies

| Service | PostgreSQL | Redis | Elasticsearch | Other |
|---------|-----------|-------|---------------|-------|
| API Service | Primary DB | Session cache, rate limiting | - | - |
| Data Service | Primary DB | Query cache | Search (optional) | InfluxDB (optional) |
| Intelligence Engine | - | - | - | - |
| Notification | Notification records | Pub/sub, queue | - | SMTP, Slack, Teams, Discord |
| Orchestration | Task state | Celery broker + backend | - | - |
| Tool Integration | Job records | Job queue | - | K8s API |
| Contract Parser | - | Parse cache | - | - |
| Dashboard | - | - | - | Supabase (auth) |
| Admin Portal | - | - | - | Supabase (auth) |

---

## Version Sources

| Service | File | Current Version |
|---------|------|-----------------|
| api-service | `pyproject.toml` | 0.29.80 |
| data-service | `pyproject.toml` | 0.2.7 |
| intelligence-engine | `pyproject.toml` | 0.3.7 |
| notification | `pyproject.toml` | 0.2.6 |
| orchestration | `pyproject.toml` | 0.10.9 |
| tool-integration | `pyproject.toml` | 0.5.29 |
| contract-parser | `Cargo.toml` | 0.2.2 |
| dashboard | `package.json` | 0.46.25 |
| admin-portal | `package.json` | 0.7.12 |
| shared (Rust) | `Cargo.toml` | 0.1.0 |
| shared (TS) | `package.json` | 0.1.0 |
| cli | `pyproject.toml` | 0.1.0 |
| vscode | `package.json` | 0.1.0 |
| intellij | `build.gradle.kts` | 0.1.0 |
| blocksecops_com | `package.json` | 0.1.0 |
