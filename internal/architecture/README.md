# Architecture Documentation

**Last Updated**: December 7, 2025
**Platform Version**: 0.8.0 (Phase 3.4 Complete)

---

## Overview

System architecture, design patterns, and architectural decisions for the BlockSecOps Platform. This directory contains comprehensive documentation on how all services are structured and how they interact.

---

## Contents

### 🏗️ Core Services

#### API Service
- **[API Service Architecture](api-service-architecture.md)** - DDD + Clean Architecture + CQRS
  - Domain layer (entities, value objects)
  - Application layer (commands, queries, handlers)
  - Infrastructure layer (database, external services)
  - Presentation layer (REST endpoints)
  - Complete service responsibilities

- **[Authentication System](authentication-system.md)** - Supabase Auth integration
  - JWT verification with ES256
  - Tier-based access control
  - Quota enforcement
  - User auto-sync from Supabase

#### Orchestration Service
- **[Orchestration REST API](orchestration-rest-api.md)** - Workflow management API
  - Scan orchestration workflows
  - Scanner job management
  - Result aggregation

- **[Result Routing](orchestration-result-routing.md)** - Scanner result processing
  - Result collection from scanner jobs
  - Deduplication engine
  - Database persistence

#### Intelligence Service
- **[Intelligence Layer](intelligence-layer.md)** - AI/ML analysis architecture
  - Vulnerability pattern matching
  - Enriched findings generation
  - Pattern library management
  - 392+ vulnerability patterns

- **[Fingerprinting Engine](fingerprinting-engine.md)** - Vulnerability fingerprinting
  - ASM fingerprinting strategy
  - ENC fingerprinting strategy
  - EVT fingerprinting strategy
  - L2 fingerprinting strategy
  - Semantic fingerprinting roadmap

---

### 🔌 Integration Architecture

- **[Scanner Integration Architecture](phase-4e-scanner-integration-architecture.md)** - Scanner integration patterns
  - Kubernetes Job-based execution
  - ConfigMap source code delivery
  - Result webhook callbacks
  - Multi-language scanner support

- **[Project Mode Scanning](../scanners/PROJECT-MODE-SCANNING.md)** - Foundry/Hardhat support (Phase 3.2)
  - Multi-file project uploads
  - Import remapping handling
  - Framework config parsing (foundry.toml, hardhat.config.js)
  - Scanner project mode execution

---

## Architecture Principles

### Domain-Driven Design (DDD)
The platform follows DDD principles:
- **Ubiquitous Language**: Shared terminology across codebase
- **Bounded Contexts**: Clear service boundaries
- **Entities**: User, Project, Contract, Analysis, Scan
- **Value Objects**: Email, ContractAddress, AnalysisStatus
- **Aggregates**: Contract + Scans + Vulnerabilities

See: [DDD Implementation Guide](../development/ddd-implementation-guide.md)

### Clean Architecture
Four-layer architecture pattern:
1. **Domain Layer**: Pure business logic, no dependencies
2. **Application Layer**: Use cases and orchestration (CQRS)
3. **Infrastructure Layer**: External dependencies (DB, APIs)
4. **Presentation Layer**: HTTP endpoints and schemas

See: [API Service Architecture](api-service-architecture.md)

### CQRS (Command Query Responsibility Segregation)
Separation of read and write operations:
- **Commands**: State-changing operations (CreateContract, TriggerScan)
- **Queries**: Read operations (GetContract, ListVulnerabilities)
- **Handlers**: Execute commands and queries independently

See: [CQRS Patterns](../development/cqrs-patterns.md)

---

## Microservices Architecture

### Service Map

```
┌─────────────────┐
│   API Service   │ ←── Main orchestrator, authentication, tier enforcement
│   (Port 8000)   │
└────────┬────────┘
         │
         ├─────→ ┌──────────────────────┐
         │       │ Orchestration Service │ ←── Scan workflow management
         │       │     (Port 8005)       │
         │       └──────────────────────┘
         │
         ├─────→ ┌──────────────────────┐
         │       │ Intelligence Engine   │ ←── AI/ML vulnerability analysis
         │       │     (Port 8001)       │
         │       └──────────────────────┘
         │
         ├─────→ ┌──────────────────────┐
         │       │   Data Service        │ ←── Data access layer
         │       │     (Port 8002)       │
         │       └──────────────────────┘
         │
         ├─────→ ┌──────────────────────┐
         │       │ Notification Service  │ ←── WebSocket updates
         │       │     (Port 8003)       │
         │       └──────────────────────┘
         │
         └─────→ ┌──────────────────────┐
                 │  Tool Integration     │ ←── Scanner orchestration
                 │     (Port 8004)       │
                 └──────────────────────┘
```

### Service Communication
- **Synchronous**: REST API calls (httpx)
- **Asynchronous**: Kubernetes Jobs for scanner execution
- **Real-time**: WebSocket connections for dashboard updates

---

## Data Architecture

### Database Design
- **PostgreSQL 15+** - Primary datastore
- **SQLAlchemy 2.x** - Async ORM
- **Alembic** - Schema migrations

**Core Tables**:
- `users` - User accounts (synced from Supabase)
- `user_quotas` - Tier limits and usage tracking
- `contracts` - Smart contract source code (with framework metadata)
- `project_files` - Multi-file project storage (Phase 3.2)
- `scans` - Security scan records
- `vulnerabilities` - Detected security issues
- `projects` - Contract grouping
- `project_contracts` - Project-contract associations

### Caching Strategy
- **Redis 7.x** - Session storage and caching
- **TTL Policies**:
  - User sessions: 7 days
  - Analytics: 5 minutes
  - JWKS keys: 1 hour

---

## Security Architecture

### Authentication Flow
1. User authenticates with Supabase (frontend)
2. Supabase generates ES256 JWT token
3. Frontend sends token in Authorization header
4. API verifies token via JWKS
5. User auto-synced to local database (first request)
6. Tier and quota loaded from database

See: [Authentication System](authentication-system.md)

### Authorization Layers
- **Tier-based access**: Free, Pro, Enterprise, Enterprise Broker
- **Quota enforcement**: Monthly scan limits per tier
- **Resource ownership**: Users can only access their own resources

---

## Deployment Architecture

### Kubernetes Components
- **Deployments**: Stateless services (API, Orchestration, Intelligence)
- **StatefulSets**: Stateful services (PostgreSQL, Redis)
- **Jobs**: Scanner execution (Slither, Aderyn, Mythril, etc.)
- **ConfigMaps**: Contract source code delivery to scanner jobs
- **Secrets**: Credentials and API keys (Vault integration)
- **HPA**: Horizontal Pod Autoscaler for API service

### Infrastructure
- **Platform**: AWS EKS (production) | Minikube (local)
- **Registry**: Docker Hub (scanners) | Local registry (development)
- **Monitoring**: Prometheus + Grafana
- **Logging**: Loki + Fluent Bit

See: [Deployment Documentation](../deployment/README.md)

---

## Performance Considerations

### Scalability
- **Horizontal scaling**: API service scales with HPA
- **Async operations**: All I/O operations use async/await
- **Connection pooling**: PostgreSQL pool (20 connections + 10 overflow)
- **Caching**: Redis for frequently accessed data

### Optimization Strategies
- **Database indexes**: On user_id, contract_id, severity, status
- **Full-text search**: GIN indexes for vulnerability titles
- **Job parallelization**: Multiple scanner jobs run concurrently
- **Result streaming**: Large scan results streamed via WebSocket

---

## Related Documentation

### Development Guides
- [DDD Implementation Guide](../development/ddd-implementation-guide.md)
- [CQRS Patterns](../development/cqrs-patterns.md)
- [Testing DDD Services](../development/testing-ddd-services.md)

### Deployment
- [API Service Deployment](../deployment/api-service-deployment.md)
- [Orchestration Service Deployment](../deployment/orchestration-service-deployment.md)
- [Scanner Execution Architecture](../deployment/scanner-execution-architecture.md)

### Intelligence
- [Intelligence Integration Guide](../intelligence/INTELLIGENCE-INTEGRATION-GUIDE.md)
- [Detector Addition Guide](../intelligence/DETECTOR-ADDITION-GUIDE.md)

---

## Architecture Decision Records (ADRs)

### Key Decisions
1. **Supabase Auth** (Phase 3.1a) - External auth provider for scalability
2. **DDD + Clean Architecture** - Maintainability and testability
3. **CQRS Pattern** - Separate read/write optimization
4. **Kubernetes Jobs** - Isolated scanner execution
5. **ES256 JWT** - Industry-standard public key cryptography
6. **Tier-based access** - Freemium business model support
7. **Project Mode Scanning** (Phase 3.2) - Foundry/Hardhat framework support with remappings
8. **MetaMask/Wallet Auth** (Phase 3.3) - SIWE (Sign-In With Ethereum) for Web3 native users
9. **x402 Pay-Per-Scan** (Phase 3.4) - USDC on Base blockchain for pay-per-scan payments via wagmi

---

**Maintained by**: BlockSecOps Architecture Team
**Last Review**: December 7, 2025
**Version**: 0.8.0 (Phase 3.3 + 3.4 Complete)
