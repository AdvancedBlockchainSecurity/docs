# API Service Architecture

## Overview

The BlockSecOps API Service implements Domain-Driven Design (DDD) + Clean Architecture + CQRS patterns to provide a robust, maintainable, and scalable foundation for the security analysis platform.

## Service Responsibilities

The API Service acts as the central orchestrator for:
- **User authentication and authorization** (Phase 3.1a - Supabase Auth with JWT verification)
- **Tier-based access control and quota enforcement** (Phase 3.1a - Freemium model)
- Project management and configuration
- Contract submission and analysis workflow
- Analysis results aggregation and retrieval
- External service coordination (Contract Parser, Intelligence Engine)
- **Enterprise Features** (Phase 4.5):
  - Organizations and RBAC (team management, roles, members)
  - API Key management (scoped access, rate limiting)
  - Audit logging (compliance tracking, export)
  - Webhooks (event notifications, delivery tracking)

## Architecture Layers

### Domain Layer (`src/domain/`)

Contains pure business logic with zero external dependencies.

#### Core Entities
- **User**: User management and permissions
- **Project**: Security analysis project with configuration
- **Analysis**: Security analysis workflow and status tracking
- **Contract**: Smart contract representation and metadata

#### Value Objects
- **Email**: Email validation and domain operations
- **Password**: Password strength and hashing rules
- **AnalysisStatus**: Status transitions (SUBMITTED → PARSING → ANALYZING → COMPLETED/FAILED)
- **ContractAddress**: Ethereum address validation
- **SecurityLevel**: Risk assessment levels (LOW, MEDIUM, HIGH, CRITICAL)

#### Domain Services
- **AuthDomainService**: Authentication business rules
- **AnalysisWorkflowService**: Analysis state management
- **SecurityAssessmentService**: Risk calculation logic

### Application Layer (`src/application/`)

Orchestrates domain objects through commands and queries (CQRS pattern).

#### Commands (Write Operations)
```
auth/commands/
├── register_user_command.py
├── login_user_command.py
└── update_user_command.py

projects/commands/
├── create_project_command.py
├── update_project_command.py
└── delete_project_command.py

analysis/commands/
├── submit_contract_command.py
├── start_analysis_command.py
└── update_analysis_status_command.py
```

#### Queries (Read Operations)
```
auth/queries/
├── get_user_query.py
└── authenticate_user_query.py

projects/queries/
├── get_project_query.py
├── list_user_projects_query.py
└── get_project_analysis_query.py

analysis/queries/
├── get_analysis_query.py
├── list_analysis_results_query.py
└── get_analysis_status_query.py
```

#### Handlers
Command and query handlers implement the actual business logic orchestration.

### Infrastructure Layer (`src/infrastructure/`)

Implements technical concerns and external service integrations.

#### Database (`database/`)
- **Models**: SQLAlchemy ORM models
  - `models.py` - Core database models (UserModel, ContractModel, ScanModel, VulnerabilityModel, etc.)
  - `specialized_models/` - Specialized models for scanner results
    - `scan_results.py` - Scanner result models (GasAnalysisFindingModel, CodeQualityFindingModel, FormalVerificationResultModel, FuzzingResultModel)
    - `intelligence.py` - Intelligence layer models (VulnerabilityPatternModel, PatternToolMappingModel)
- **Repositories**: Concrete implementations of domain repository interfaces
- **Migrations**: Database schema evolution using Alembic
- **Session Management**:
  - **Async Sessions** (asyncpg): For API service endpoints
  - **Sync Sessions** (psycopg2): For Celery workers with gevent pool

#### External Services (`external/`)
- **ContractParserClient**: HTTP client for contract parsing service
- **IntelligenceEngineClient**: HTTP client for security analysis engine
- **MonitoringClient**: Metrics and logging integration

#### Security (`security/`)
- **JWTTokenService**: JWT token generation and validation
- **PasswordHashingService**: Secure password hashing
- **PermissionService**: Role-based access control

#### Middleware (`middleware/`)
- **SecurityHeadersMiddleware**: Adds security headers to all responses (Phase 7A)
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy: geolocation=(), microphone=(), camera=()...`
  - `Strict-Transport-Security` (production only)
- **RequestSizeLimitMiddleware**: Enforces 10MB request body limit
- **RateLimitMiddleware**: Redis-backed rate limiting with SlowAPI

#### Logging (`logging/`)
- **SecurityLogger**: Structured security event logging (Phase 7A)
  - AUTH_SUCCESS / AUTH_FAILURE events
  - RATE_LIMIT_EXCEEDED events
  - API_KEY_USED events
  - AUTHORIZATION_FAILURE events

### Presentation Layer (`src/presentation/`)

HTTP API endpoints and request/response handling.

#### API Structure
```
api/v1/
├── auth/
│   ├── router.py          # Authentication endpoints
│   └── schemas.py         # Request/response models
├── projects/
│   ├── router.py          # Project management endpoints
│   └── schemas.py         # Project data models
├── analysis/
│   ├── router.py          # Analysis workflow endpoints
│   └── schemas.py         # Analysis data models
└── health/
    └── router.py          # Health check endpoints
```

## Key API Endpoints

### Authentication
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Token refresh

### Project Management
- `GET /api/v1/projects` - List user projects
- `POST /api/v1/projects` - Create new project
- `GET /api/v1/projects/{id}` - Get project details
- `PUT /api/v1/projects/{id}` - Update project
- `DELETE /api/v1/projects/{id}` - Delete project

### Contract Analysis
- `POST /api/v1/projects/{id}/contracts` - Submit contract for analysis
- `GET /api/v1/projects/{id}/analyses` - List project analyses
- `GET /api/v1/analyses/{id}` - Get analysis details
- `GET /api/v1/analyses/{id}/results` - Get analysis results

### Scanner-Specific Results
- `GET /api/v1/scans/{id}/result-types` - Get available result types for scan
- `GET /api/v1/scans/{id}/code-quality` - Get code quality findings
- `GET /api/v1/scans/{id}/gas-analysis` - Get gas optimization findings
- `GET /api/v1/scans/{id}/formal-verification` - Get formal verification results
- `GET /api/v1/scans/{id}/fuzzing` - Get fuzzing test results

### Enterprise Features (Phase 4.5)

#### Organizations & RBAC
- `GET /api/v1/organizations` - List user's organizations
- `POST /api/v1/organizations` - Create organization (Enterprise tier)
- `GET /api/v1/organizations/{id}/roles` - List organization roles
- `GET /api/v1/organizations/{id}/members` - List members
- `POST /api/v1/organizations/{id}/members` - Add member

#### API Key Management
- `GET /api/v1/api-keys` - List user's API keys
- `POST /api/v1/api-keys` - Create API key (Pro+ tier)
- `GET /api/v1/api-keys/scopes` - List available scopes
- `GET /api/v1/api-keys/{id}/usage` - Get usage statistics

#### Audit Logging
- `GET /api/v1/audit-logs` - Query audit logs (Enterprise tier)
- `GET /api/v1/audit-logs/actions` - List action categories
- `GET /api/v1/audit-logs/summary` - Get statistics
- `GET /api/v1/audit-logs/export/csv` - Export as CSV

#### Webhooks
- `GET /api/v1/webhooks` - List user's webhooks
- `POST /api/v1/webhooks` - Create webhook (Pro+ tier)
- `GET /api/v1/webhooks/events` - List event types

## External Service Integration

### Contract Parser Service
- **Purpose**: Parse and validate smart contract code
- **Communication**: HTTP REST API
- **Data Flow**: API → Contract Parser → Analysis Results

### Intelligence Engine Service
- **Purpose**: Perform security analysis and vulnerability detection
- **Communication**: HTTP REST API
- **Data Flow**: API → Intelligence Engine → Security Assessment

## Data Flow

### Contract Submission Workflow
1. **Submission**: User submits contract through API
2. **Validation**: API validates contract format and project permissions
3. **Parsing**: Contract sent to Parser Service for syntax analysis
4. **Analysis**: Parsed contract sent to Intelligence Engine for security analysis
5. **Aggregation**: Results combined and stored in database
6. **Notification**: User notified of completion

### Analysis Status Tracking
```
SUBMITTED → PARSING → ANALYZING → COMPLETED
                          ↓
                       FAILED
```

## Security Architecture

### Authentication Flow
1. User credentials validated against domain rules
2. JWT tokens generated with appropriate claims
3. Token validation on protected endpoints
4. Role-based access control for resources

### Authorization Patterns
- **Resource Ownership**: Users can only access their own projects
- **Role-Based Access**: Admin, User, Viewer roles with different permissions
- **API Key Support**: Service-to-service authentication

## Error Handling Strategy

### Domain Errors
- Business rule violations return structured domain errors
- Value object validation errors with specific field information

### Application Errors
- Command/query validation errors
- Service integration failures with circuit breaker patterns

### Infrastructure Errors
- Database connection failures with retry logic
- External service timeouts with fallback responses

## Performance Considerations

### Database Optimization
- Proper indexing on frequently queried fields
- Connection pooling for high concurrency
- Query optimization for complex analysis retrievals

### Caching Strategy
- Redis for WebSocket pub/sub, rate limiting, and application caching (NOT for sessions)
- Sessions stored in PostgreSQL database for persistence and audit trail
- Application-level caching for frequently accessed data
- HTTP caching headers for static analysis results

### External Service Resilience
- Circuit breaker pattern for service calls
- Timeout configuration and retry logic
- Graceful degradation when services are unavailable

## Monitoring and Observability

### Metrics Collection
- Request/response times per endpoint
- External service call success rates
- Analysis workflow completion metrics
- Database query performance

### Logging Strategy
- Structured logging with correlation IDs
- Business event logging for audit trails
- Error logging with stack traces and context

### Health Checks
- Application health endpoint
- Database connectivity checks
- External service dependency health

## Testing Strategy

### Unit Testing
- Domain entities and value objects (100% coverage)
- Application command/query handlers
- Infrastructure service implementations

### Integration Testing
- Database repository implementations
- External service client integrations
- End-to-end API workflow testing

### Performance Testing
- API endpoint load testing
- Database query performance validation
- External service integration resilience

## Deployment Architecture

### Container Structure
```
api-service/
├── Dockerfile
├── requirements.txt
├── pyproject.toml
└── src/
```

### Kubernetes Configuration
- Deployment with rolling updates
- Service for internal communication
- Ingress for external access
- ConfigMap for environment configuration
- Secret for sensitive data

### Environment Variables
```bash
# Database
DATABASE_URL=postgresql://...
DATABASE_POOL_SIZE=10

# External Services
CONTRACT_PARSER_URL=http://contract-parser-service:8080
INTELLIGENCE_ENGINE_URL=http://intelligence-engine-service:8080

# Security
JWT_SECRET_KEY=...
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30

# Monitoring
PROMETHEUS_METRICS_PORT=8000
LOG_LEVEL=INFO
```

## Development Workflow

### Local Development
1. Start infrastructure with `minikube start`
2. Deploy dependencies: `kubectl apply -k k8s/overlays/local`
3. Run tests: `pytest tests/`
4. Start development server: `uvicorn src.main:app --reload`

### Code Quality
- Type checking with `mypy`
- Code formatting with `black`
- Import sorting with `isort`
- Linting with `flake8`

This architecture provides a solid foundation for building a maintainable, scalable, and testable API service that can evolve with the platform's requirements.