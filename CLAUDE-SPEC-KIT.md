# Claude Code Specification Kit

**Last Updated**: October 6, 2025
**Purpose**: Comprehensive specification for building BlockSecOps Platform services

## 📋 Quick Reference

### Project Overview
- **Platform**: BlockSecOps Analysis Platform
- **Architecture**: Microservices (7 backend services) + React Dashboard
- **Infrastructure**: Kubernetes (minikube local, AWS EKS production)
- **Languages**: Python (FastAPI), Rust, TypeScript/React, Node.js

### Current State (as of Task 1.10a completion)
- ✅ Infrastructure running (K8s, Vault, PostgreSQL, Redis, monitoring)
- ✅ K8s templates complete for all 7 services
- ✅ Dashboard UI with mock data
- ✅ Shared library (Rust/Python/TypeScript)
- 🔨 **NEXT**: Build backend service Docker images

---

## 🏗️ Architecture Standards

### Clean Architecture + DDD
**Reference**: `/Users/pwner/Git/ABS/docs/architecture/clean-architecture-decision.md`

**Directory Structure for All Services**:
```
<service>/
├── src/
│   ├── domain/           # Business logic, entities, value objects
│   │   ├── entities/
│   │   ├── value_objects/
│   │   └── services/
│   ├── application/      # Use cases, commands, queries
│   │   ├── commands/
│   │   ├── queries/
│   │   └── handlers/
│   ├── infrastructure/   # External dependencies
│   │   ├── database/
│   │   ├── external_services/
│   │   └── security/
│   └── presentation/     # API layer
│       ├── api/
│       │   ├── v1/
│       │   │   └── endpoints/
│       │   └── dependencies.py
│       ├── schemas/
│       └── middleware/
├── tests/
├── k8s/                  # Kubernetes templates
├── Dockerfile
└── pyproject.toml / Cargo.toml / package.json
```

### Kubernetes Structure
**Reference**: `/Users/pwner/Git/ABS/docs/architecture-templates/kubernetes-kustomize-structure-template.md`

**Every service MUST have**:
```
k8s/
├── base/
│   └── <service-name>/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── configmap.yaml
│       ├── serviceaccount.yaml
│       └── kustomization.yaml
└── overlays/
    ├── local/
    ├── staging/
    └── production/
```

**Key requirements**:
- Per-service namespaces: `<service>-<environment>`
- External Secrets for all sensitive data
- Security contexts (non-root, read-only filesystem)
- Health checks (liveness, readiness, startup)
- Resource limits defined

---

## 🔧 Service Specifications

### 1. API Service (api-service)
**Language**: Python (FastAPI)
**Port**: 8000
**Dependencies**: PostgreSQL, Redis, Vault

**Core Responsibilities**:
- JWT authentication & session management
- API gateway for all backend services
- User management
- Request routing

**Key Endpoints**:
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/register`
- `GET /api/v1/health/live`
- `GET /api/v1/health/ready`
- `GET /api/v1/health/startup`

**Database Tables**:
- users
- sessions
- api_keys

**Environment Variables**:
```env
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
JWT_SECRET_KEY=<from-vault>
SESSION_SECRET=<from-vault>
VAULT_ADDR=http://vault:8200
```

### 2. Data Service (data-service)
**Language**: Python/Rust hybrid
**Port**: 8020
**Dependencies**: PostgreSQL, Redis

**Core Responsibilities**:
- CRUD operations for contracts
- CRUD operations for vulnerabilities
- Database connection pooling
- Caching layer

**Key Endpoints**:
- `POST /api/v1/contracts`
- `GET /api/v1/contracts/{id}`
- `POST /api/v1/vulnerabilities`
- `GET /api/v1/vulnerabilities?contract_id={id}`

**Database Tables**:
- contracts
- vulnerabilities
- scan_results
- findings

### 3. Intelligence Engine (intelligence-engine)
**Language**: Python/Rust hybrid
**Port**: 8010
**Dependencies**: PostgreSQL, Redis, ML models

**Core Responsibilities**:
- Risk scoring algorithms
- ML-based pattern detection
- Vulnerability classification
- Threat intelligence

**Key Endpoints**:
- `POST /api/v1/analyze`
- `POST /api/v1/risk-score`
- `GET /api/v1/patterns`

### 4. Tool Integration (tool-integration)
**Language**: Multi-container (Python/Rust/Node.js)
**Ports**: 8001 (coordinator), 8002-8004 (adapters)
**Dependencies**: External security tools

**Core Responsibilities**:
- Slither integration
- Mythril integration
- Tool output normalization
- Result aggregation

**Multi-container Deployment**:
- Coordinator container (Python)
- Slither adapter container (Python)
- Mythril adapter container (Python)
- Custom tool adapter container (Rust/Node.js)

### 5. Orchestration (orchestration)
**Language**: Python (Celery)
**Port**: 5555 (Flower monitoring)
**Dependencies**: Redis (broker), PostgreSQL

**Core Responsibilities**:
- Workflow orchestration
- Task queue management
- Scan job scheduling
- Background processing

**Celery Tasks**:
- `scan_contract_task`
- `aggregate_results_task`
- `generate_report_task`

### 6. Notification Service (notification)
**Language**: Node.js/TypeScript
**Ports**: 8030 (WebSocket), 8031 (HTTP)
**Dependencies**: Redis (pub/sub)

**Core Responsibilities**:
- Real-time WebSocket connections
- Push notifications
- Event broadcasting
- Subscription management

### 7. Contract Parser (contract-parser)
**Language**: Pure Rust
**Port**: 8040
**Dependencies**: None (stateless)

**Core Responsibilities**:
- High-performance Solidity parsing
- AST generation
- Static analysis preparation
- Code structure extraction

---

## 📦 Docker Image Standards

### Base Image Requirements
- **Python services**: `python:3.13-slim`
- **Rust services**: `rust:1.90-slim` (builder), `debian:bookworm-slim` (runtime)
- **Node.js services**: `node:24-slim`

### Multi-stage Build Pattern (REQUIRED)
```dockerfile
# Stage 1: Builder
FROM python:3.13-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.13-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY src/ ./src/
ENV PATH=/root/.local/bin:$PATH
EXPOSE 8000
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Security Requirements
- Non-root user (UID 1000)
- Read-only root filesystem
- No secrets in images
- Health check endpoint
- Minimal dependencies

### Image Naming Convention
```
localhost:8080/library/<service>:<tag>
```

**Tags**:
- `latest` - most recent build
- `local-latest` - local development
- `v1.2.3` - semantic version
- `main-<commit-sha>` - git commit

---

## 🗄️ Database Schema Standards

### PostgreSQL (Version 17.4.0)
**Connection**: `postgresql://postgres:postgres@postgresql.postgresql-local.svc:5432/blocksecops`

### Required Tables (Initial Schema)

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_superuser BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Contracts table
CREATE TABLE contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    address VARCHAR(42),
    source_code TEXT NOT NULL,
    source_code_hash VARCHAR(64) NOT NULL,
    compiler_version VARCHAR(50),
    optimization_enabled BOOLEAN,
    optimization_runs INTEGER,
    lines_of_code INTEGER,
    user_id UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Scan results table
CREATE TABLE scan_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id UUID REFERENCES contracts(id) ON DELETE CASCADE,
    scan_type VARCHAR(50) NOT NULL,  -- 'slither', 'mythril', 'custom'
    status VARCHAR(20) NOT NULL,     -- 'pending', 'running', 'completed', 'failed'
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Vulnerabilities table
CREATE TABLE vulnerabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scan_result_id UUID REFERENCES scan_results(id) ON DELETE CASCADE,
    contract_id UUID REFERENCES contracts(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL,  -- 'critical', 'high', 'medium', 'low', 'info'
    confidence DECIMAL(3,2),        -- 0.00 to 1.00
    swc_id VARCHAR(20),
    line_number INTEGER,
    column_number INTEGER,
    code_snippet TEXT,
    recommendation TEXT,
    status VARCHAR(20) DEFAULT 'open',  -- 'open', 'acknowledged', 'fixed', 'false_positive'
    risk_score DECIMAL(4,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_contracts_user_id ON contracts(user_id);
CREATE INDEX idx_contracts_address ON contracts(address);
CREATE INDEX idx_scan_results_contract_id ON scan_results(contract_id);
CREATE INDEX idx_scan_results_status ON scan_results(status);
CREATE INDEX idx_vulnerabilities_scan_result_id ON vulnerabilities(scan_result_id);
CREATE INDEX idx_vulnerabilities_contract_id ON vulnerabilities(contract_id);
CREATE INDEX idx_vulnerabilities_severity ON vulnerabilities(severity);
CREATE INDEX idx_vulnerabilities_status ON vulnerabilities(status);
```

---

## 🔐 Security & Secrets

### Vault Integration
**Vault URL**: `http://vault.vault-local.svc.cluster.local:8200`
**Root Token**: `root` (local only!)

### Secret Paths
```
secret/blocksecops/<service>/local/
  ├── database_url
  ├── redis_url
  ├── jwt_secret_key
  ├── session_secret
  └── <service-specific-secrets>
```

### External Secrets Pattern
Every service MUST have `externalsecret.yaml`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <service>-secret
  namespace: <service>-local
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: <service>-secret
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: secret/blocksecops/<service>/local
        property: database_url
```

---

## 🚀 Development Workflow

### 1. Create New Service
```bash
# 1. Create repository
cd /Users/pwner/Git/ABS/
mkdir blocksecops-<service>
cd blocksecops-<service>

# 2. Initialize git
git init
git remote add origin https://github.com/SolidityOps/blocksecops-<service>

# 3. Create directory structure (follow Clean Architecture + DDD)
mkdir -p src/{domain,application,infrastructure,presentation}
mkdir -p tests/{unit,integration}
mkdir -p k8s/{base/<service>,overlays/local/<service>}

# 4. Create Dockerfile (multi-stage build)
# 5. Create K8s templates
# 6. Create dependencies file (requirements.txt, Cargo.toml, package.json)
# 7. Implement core functionality
# 8. Write tests
# 9. Build Docker image
# 10. Push to Harbor
# 11. Deploy to minikube
```

### 2. Build Docker Image
```bash
# Build
docker build -t localhost:8080/library/<service>:latest .

# Test locally
docker run -p 8000:8000 localhost:8080/library/<service>:latest

# Push to Harbor
docker push localhost:8080/library/<service>:latest
```

### 3. Deploy to Kubernetes
```bash
# Apply K8s templates
kubectl apply -k k8s/overlays/local

# Check deployment
kubectl get pods -n <service>-local
kubectl logs -n <service>-local -l app.kubernetes.io/name=<service>

# Port forward for testing
kubectl port-forward -n <service>-local svc/<service> 8000:8000
```

---

## 📊 Monitoring & Observability

### Health Check Requirements
ALL services MUST implement:
- `GET /health/live` - Liveness probe (is process running?)
- `GET /health/ready` - Readiness probe (can accept traffic?)
- `GET /health/startup` - Startup probe (has initialization completed?)

### Prometheus Metrics
Expose metrics at `/metrics`:
- `http_requests_total`
- `http_request_duration_seconds`
- `http_requests_in_progress`
- Service-specific metrics

### Logging Standards
```python
import logging

logger = logging.getLogger(__name__)

# Log format
# [TIMESTAMP] [LEVEL] [SERVICE] [REQUEST_ID] Message
logger.info("Contract scanned", extra={
    "contract_id": contract_id,
    "scan_type": "slither",
    "duration_ms": duration
})
```

---

## 🧪 Testing Requirements

### Unit Tests (REQUIRED)
- Domain layer: 100% coverage
- Application layer: >90% coverage
- Located in `tests/unit/`

### Integration Tests (REQUIRED)
- API endpoints
- Database operations
- External service calls
- Located in `tests/integration/`

### Test Commands
```bash
# Python (pytest)
pytest tests/ -v --cov=src --cov-report=html

# Rust (cargo)
cargo test --all-features

# TypeScript (vitest)
npm test
```

---

## 📝 Documentation Requirements

### Every Service MUST Have
1. **README.md** - Overview, setup, usage
2. **CLAUDE.md** - Claude-specific development notes
3. **API.md** - API endpoint documentation (if applicable)
4. **DEPLOYMENT.md** - Deployment instructions

### API Documentation
Use OpenAPI/Swagger for FastAPI services:
```python
from fastapi import FastAPI

app = FastAPI(
    title="<Service> API",
    description="<Description>",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc"
)
```

---

## 🎯 Current Priority: Build API Service

**Next steps** (in order):
1. Create FastAPI app skeleton
2. Implement Clean Architecture structure
3. Add database models (SQLAlchemy)
4. Create health check endpoints
5. Add authentication endpoints
6. Create Dockerfile
7. Build and push image to Harbor
8. Deploy to minikube
9. Connect dashboard to live API
10. Verify end-to-end data flow

---

## 📚 Key Reference Documents

**Management Docs** (`/Users/pwner/Git/ABS/docs/`):
- `architecture/clean-architecture-decision.md` - Architecture patterns
- `architecture-templates/kubernetes-kustomize-structure-template.md` - K8s standards
- `Sprints/Sprint-1/Task-*.md` - Task specifications

**Technical Docs** (`/Users/pwner/Git/ABS/blocksecops-docs/`):
- `development/ddd-implementation-guide.md` - DDD patterns
- `development/dependency-management.md` - Dependency standards
- `development/testing-guide.md` - Testing requirements
- `architecture/api-service-architecture.md` - API service spec
- `local-development/README.md` - Local setup

**Shared Library** (`/Users/pwner/Git/ABS/blocksecops-shared/`):
- `CLAUDE.md` - Multi-language library usage
- `rust/`, `python/`, `typescript/` - Shared types

---

## 💡 Tips for Claude Code

1. **Always check existing code first** - Many services may have partial implementations
2. **Follow the patterns** - If one service has a pattern, replicate it
3. **Use the shared library** - Don't redefine types that exist in blocksecops-shared
4. **Security first** - Never commit secrets, always use Vault
5. **Test before deploy** - Run unit tests and integration tests
6. **Document as you go** - Update CLAUDE.md with decisions and gotchas
7. **Ask before major changes** - When in doubt, ask the user for clarification

---

**This spec kit should be updated whenever**:
- New services are added
- Architecture patterns change
- New standards are established
- Infrastructure changes occur

Last updated by: Claude Code
Version: 1.0.0
