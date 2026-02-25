# Sprint 1 Repository Structure - Microservice Architecture (~94K LOC)

## 🎯 MVP Status - October 9, 2025

### **Full-Stack MVP: ✅ COMPLETE & PRODUCTION READY (Sprint 9/10)**
The complete security scanning platform is fully operational and production-ready:

**Backend** (Sprint 1-8):
- ✅ **Sprint 1-3**: Core infrastructure, Kubernetes deployment, service discovery
- ✅ **Sprint 4**: API endpoint fixes, authentication, contract/scan management
- ✅ **Sprint 5**: Scanner execution validation with real security tools
- ✅ **Sprint 6**: API-Scanner integration via tool-integration service
- ✅ **Sprint 7**: Result collection & persistence (automated polling)
- ✅ **Sprint 8**: Contract source management via ConfigMaps

**Frontend** (Sprint 9-10):
- ✅ **Sprint 9**: Frontend MVP - Authentication, Contracts, Scan Results
- ✅ **Sprint 10**: WebSocket real-time updates

**Security** (Production Hardening):
- ✅ All HIGH severity issues fixed (3/3)
- ✅ All MEDIUM severity issues fixed (4/4)
- ✅ 21/21 security tests passing
- ✅ OWASP Top 10 compliant
- ✅ **Sprint 14 Phase 1 Complete** - HttpOnly cookies, CORS hardening, infrastructure standardization

**Live Capabilities**:
- User authentication with Login/Register pages
- Contract upload and management UI
- Scan triggering with real-time progress tracking
- Real scanner execution (Slither/Mythril) on actual Solidity code
- Vulnerability viewing with severity filtering
- WebSocket live updates during scanning
- Production-ready security (CSP, DOMPurify, token validation)

**Status**: ✅ **PRODUCTION READY** - Full-stack MVP operational with comprehensive security

---

## Core Repositories (16 repos) ✅ **INCLUDING DEPENDENCY MONITORING**

### **Backend Service Repositories (6 repos)**

### 1. **`blocksecops-api-service`** (~10K LOC) ✅ **SHARED LIBRARY INTEGRATED** + **DDD ARCHITECTURE** + **SECURITY HARDENED**
**FastAPI authentication and API gateway with Domain-Driven Design**
```
Purpose: User management, authentication, API routing, JWT handling, project management
Tech Stack: Python 3.13, FastAPI, SQLAlchemy, Pydantic, JWT
Architecture: Domain-Driven Design (DDD) + Clean Architecture + CQRS
Contains: Domain entities, application use cases, infrastructure adapters, API interfaces
Integration: Docker multi-stage build with PyO3 v0.22 bindings (10x performance boost)
Current Version: 0.2.3 (Multi-Scanner Execution Fix - November 3, 2025)
Features: Multi-scanner job triggering, rate limiting, consecutive failure tracking
Security: HttpOnly cookies (XSS protection), CORS hardening (origin validation), OWASP 2025 compliant
```

**Production-Ready DDD Architecture:**
```
blocksecops-api-service/
├── src/
│   ├── domain/                     # Domain Layer - Pure Business Logic
│   │   ├── entities/              # Core business entities
│   │   │   ├── __init__.py
│   │   │   ├── user.py            # User domain entity
│   │   │   ├── project.py         # Project domain entity
│   │   │   ├── analysis.py        # Analysis domain entity
│   │   │   └── base.py            # Base entity class
│   │   ├── repositories/          # Repository interfaces (abstract)
│   │   │   ├── __init__.py
│   │   │   ├── user_repository.py # User repository interface
│   │   │   ├── project_repository.py # Project repository interface
│   │   │   └── analysis_repository.py # Analysis repository interface
│   │   ├── services/              # Domain services (business rules)
│   │   │   ├── __init__.py
│   │   │   ├── user_service.py    # User domain service
│   │   │   ├── project_service.py # Project domain service
│   │   │   ├── analysis_service.py # Analysis domain service
│   │   │   └── auth_service.py    # Authentication domain service
│   │   ├── value_objects/         # Domain value objects
│   │   │   ├── __init__.py
│   │   │   ├── email.py           # Email value object
│   │   │   ├── password.py        # Password value object
│   │   │   └── analysis_status.py # Analysis status value object
│   │   └── exceptions/            # Domain-specific exceptions
│   │       ├── __init__.py
│   │       ├── user_exceptions.py
│   │       ├── project_exceptions.py
│   │       └── auth_exceptions.py
│   │
│   ├── application/               # Application Layer - Use Cases
│   │   ├── auth/                  # Authentication use cases
│   │   │   ├── commands/          # CQRS Commands (write operations)
│   │   │   │   ├── __init__.py
│   │   │   │   ├── login_command.py
│   │   │   │   ├── register_command.py
│   │   │   │   ├── change_password_command.py
│   │   │   │   └── logout_command.py
│   │   │   ├── queries/           # CQRS Queries (read operations)
│   │   │   │   ├── __init__.py
│   │   │   │   ├── get_user_query.py
│   │   │   │   ├── get_current_user_query.py
│   │   │   │   └── validate_token_query.py
│   │   │   └── handlers/          # Command/Query handlers
│   │   │       ├── __init__.py
│   │   │       ├── auth_command_handlers.py
│   │   │       └── auth_query_handlers.py
│   │   ├── users/                 # User management use cases
│   │   │   ├── commands/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── create_user_command.py
│   │   │   │   ├── update_user_command.py
│   │   │   │   └── delete_user_command.py
│   │   │   ├── queries/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── get_user_by_id_query.py
│   │   │   │   ├── list_users_query.py
│   │   │   │   └── search_users_query.py
│   │   │   └── handlers/
│   │   │       ├── __init__.py
│   │   │       ├── user_command_handlers.py
│   │   │       └── user_query_handlers.py
│   │   ├── projects/              # Project management use cases
│   │   │   ├── commands/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── create_project_command.py
│   │   │   │   ├── update_project_command.py
│   │   │   │   └── delete_project_command.py
│   │   │   ├── queries/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── get_project_query.py
│   │   │   │   ├── list_projects_query.py
│   │   │   │   └── get_user_projects_query.py
│   │   │   └── handlers/
│   │   │       ├── __init__.py
│   │   │       ├── project_command_handlers.py
│   │   │       └── project_query_handlers.py
│   │   └── analysis/              # Analysis workflow use cases
│   │       ├── commands/
│   │       │   ├── __init__.py
│   │       │   ├── submit_analysis_command.py
│   │       │   ├── cancel_analysis_command.py
│   │       │   └── retry_analysis_command.py
│   │       ├── queries/
│   │       │   ├── __init__.py
│   │       │   ├── get_analysis_status_query.py
│   │       │   ├── get_analysis_results_query.py
│   │       │   └── list_analyses_query.py
│   │       └── handlers/
│   │           ├── __init__.py
│   │           ├── analysis_command_handlers.py
│   │           └── analysis_query_handlers.py
│   │
│   ├── infrastructure/            # Infrastructure Layer - External Concerns
│   │   ├── database/
│   │   │   ├── models/            # SQLAlchemy models (data persistence)
│   │   │   │   ├── __init__.py
│   │   │   │   ├── user_model.py
│   │   │   │   ├── project_model.py
│   │   │   │   ├── analysis_model.py
│   │   │   │   └── base_model.py
│   │   │   ├── repositories/      # Repository implementations
│   │   │   │   ├── __init__.py
│   │   │   │   ├── user_repository_impl.py
│   │   │   │   ├── project_repository_impl.py
│   │   │   │   └── analysis_repository_impl.py
│   │   │   ├── migrations/        # Alembic database migrations
│   │   │   │   ├── env.py
│   │   │   │   ├── script.py.mako
│   │   │   │   └── versions/
│   │   │   ├── connection.py      # Database connection setup
│   │   │   └── session.py         # Database session management
│   │   ├── external_services/     # External service clients
│   │   │   ├── __init__.py
│   │   │   ├── contract_parser_client.py
│   │   │   ├── intelligence_engine_client.py
│   │   │   ├── tool_integration_client.py
│   │   │   └── notification_client.py
│   │   ├── monitoring/            # Observability infrastructure
│   │   │   ├── __init__.py
│   │   │   ├── metrics.py         # Prometheus metrics
│   │   │   ├── logging.py         # Structured logging
│   │   │   ├── tracing.py         # Distributed tracing
│   │   │   └── health_checks.py   # Health check endpoints
│   │   ├── security/              # Security implementations
│   │   │   ├── __init__.py
│   │   │   ├── jwt_handler.py     # JWT token handling
│   │   │   ├── password_hasher.py # Password hashing/verification
│   │   │   ├── permissions.py     # Permission checking
│   │   │   └── rate_limiter.py    # API rate limiting
│   │   └── messaging/             # Message queue implementations
│   │       ├── __init__.py
│   │       ├── redis_client.py    # Redis message queue
│   │       └── event_publisher.py # Domain event publishing
│   │
│   ├── presentation/              # Presentation Layer - API Interface
│   │   ├── api/
│   │   │   ├── v1/               # API versioning
│   │   │   │   ├── __init__.py
│   │   │   │   ├── auth/
│   │   │   │   │   ├── __init__.py
│   │   │   │   │   ├── router.py  # Auth endpoints
│   │   │   │   │   └── schemas.py # Auth request/response schemas
│   │   │   │   ├── users/
│   │   │   │   │   ├── __init__.py
│   │   │   │   │   ├── router.py  # User management endpoints
│   │   │   │   │   └── schemas.py # User schemas
│   │   │   │   ├── projects/
│   │   │   │   │   ├── __init__.py
│   │   │   │   │   ├── router.py  # Project endpoints
│   │   │   │   │   └── schemas.py # Project schemas
│   │   │   │   ├── analysis/
│   │   │   │   │   ├── __init__.py
│   │   │   │   │   ├── router.py  # Analysis endpoints
│   │   │   │   │   └── schemas.py # Analysis schemas
│   │   │   │   └── health/
│   │   │   │       ├── __init__.py
│   │   │   │       └── router.py  # Health check endpoints
│   │   │   └── dependencies.py    # FastAPI dependencies (DI container)
│   │   ├── middleware/           # Custom middleware
│   │   │   ├── __init__.py
│   │   │   ├── auth_middleware.py # Authentication middleware
│   │   │   ├── logging_middleware.py # Request logging
│   │   │   ├── metrics_middleware.py # Metrics collection
│   │   │   └── cors_middleware.py # CORS handling
│   │   └── exception_handlers.py # Global exception handling
│   │
│   ├── shared/                   # Shared utilities and configuration
│   │   ├── config/              # Configuration management
│   │   │   ├── __init__.py
│   │   │   ├── settings.py       # Application settings
│   │   │   ├── database_config.py # Database configuration
│   │   │   ├── security_config.py # Security configuration
│   │   │   └── monitoring_config.py # Monitoring configuration
│   │   ├── constants/           # Application constants
│   │   │   ├── __init__.py
│   │   │   ├── enums.py          # Enumeration constants
│   │   │   ├── messages.py       # Error/success messages
│   │   │   └── permissions.py    # Permission constants
│   │   ├── utils/               # Utility functions
│   │   │   ├── __init__.py
│   │   │   ├── datetime_utils.py # Date/time utilities
│   │   │   ├── validation_utils.py # Input validation
│   │   │   ├── crypto_utils.py   # Cryptographic utilities
│   │   │   └── string_utils.py   # String manipulation
│   │   └── events/              # Domain events
│   │       ├── __init__.py
│   │       ├── user_events.py    # User domain events
│   │       ├── project_events.py # Project domain events
│   │       └── analysis_events.py # Analysis domain events
│   │
│   └── main.py                  # Application entry point & DI container setup
│
├── tests/                       # Comprehensive test suite
│   ├── unit/                   # Unit tests (isolated)
│   │   ├── domain/             # Domain layer tests
│   │   ├── application/        # Application layer tests
│   │   └── infrastructure/     # Infrastructure tests
│   ├── integration/            # Integration tests
│   │   ├── api/                # API endpoint tests
│   │   ├── database/           # Database integration tests
│   │   └── external_services/  # External service tests
│   ├── e2e/                    # End-to-end tests
│   │   └── workflows/          # Complete workflow tests
│   ├── fixtures/               # Test data fixtures
│   ├── conftest.py            # Pytest configuration
│   └── __init__.py
│
├── k8s/                        # Kubernetes deployment manifests
│   ├── base/
│   │   ├── api-service/        # Base Kubernetes resources
│   │   │   ├── kustomization.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap.yaml
│   │   │   ├── external-secret.yaml # Vault secrets integration
│   │   │   └── ingress.yaml
│   │   └── migrations/         # Database migration job
│   │       ├── kustomization.yaml
│   │       └── migration-job.yaml
│   └── overlays/
│       ├── local/              # Local development (minikube)
│       │   ├── kustomization.yaml
│       │   └── api-service/
│       │       ├── kustomization.yaml
│       │       ├── namespace.yaml
│       │       ├── deployment-patch.yaml
│       │       └── configmap-patch.yaml
│       ├── staging/            # Staging environment
│       │   ├── kustomization.yaml
│       │   └── api-service/
│       │       ├── kustomization.yaml
│       │       ├── namespace.yaml
│       │       ├── deployment-patch.yaml
│       │       ├── configmap-patch.yaml
│       │       ├── hpa.yaml
│       │       └── service-patch.yaml
│       └── production/         # Production environment
│           ├── kustomization.yaml
│           └── api-service/
│               ├── kustomization.yaml
│               ├── namespace.yaml
│               ├── deployment-patch.yaml
│               ├── configmap-patch.yaml
│               ├── hpa.yaml
│               ├── pdb.yaml
│               ├── networkpolicy.yaml
│               ├── servicemonitor.yaml
│               ├── resourcequota.yaml
│               └── limitrange.yaml
│
├── docs/                       # Service-specific documentation
│   ├── architecture/          # Architecture documentation
│   │   ├── domain-model.md    # Domain model documentation
│   │   ├── api-design.md      # API design principles
│   │   └── security.md        # Security architecture
│   ├── development/           # Development guides
│   │   ├── setup.md           # Local setup guide
│   │   ├── testing.md         # Testing guidelines
│   │   └── contributing.md    # Contribution guidelines
│   └── deployment/            # Deployment documentation
│       ├── kubernetes.md      # Kubernetes deployment
│       └── monitoring.md      # Monitoring setup
│
├── scripts/                    # Development and deployment scripts
│   ├── build.sh               # Build script
│   ├── test.sh                # Test execution script
│   ├── migrate.sh             # Database migration script
│   └── deploy.sh              # Deployment script
│
├── requirements/              # Dependency management
│   ├── base.txt              # Base dependencies
│   ├── development.txt       # Development dependencies
│   ├── testing.txt           # Testing dependencies
│   └── production.txt        # Production dependencies
│
├── .env.example               # Environment variables template
├── alembic.ini                # Alembic configuration
├── pytest.ini                # Pytest configuration
├── pyproject.toml             # Python project configuration
├── Dockerfile                 # Multi-stage container build
├── docker-compose.yml         # Local development environment
├── Makefile                   # Development task automation
└── README.md                  # Service documentation
```

### 2. **`blocksecops-tool-integration`** (~12K LOC) ✅ **MVP COMPLETE - SPRINT 8** + **MULTI-SCANNER SUPPORT**
**Security tool adapters and integrations - Kubernetes Jobs-based scanner execution**
```
Purpose: Multi-scanner orchestration (9 scanners: Slither, Mythril, Aderyn, Semgrep, Solhint, Halmos, Echidna, Wake, Medusa) via Kubernetes Jobs
Current Version: 0.2.2 (Multi-Scanner Whitelist Expansion - November 3, 2025)
Tech Stack: Python 3.13, FastAPI, Kubernetes Python Client, asyncio
Architecture: Job Manager + Result Collector with ConfigMap-based source delivery
Features: Real scanner execution, ConfigMap volume mounting, automatic cleanup, result parsing
Status: ✅ Sprint 8 Complete - Contract source management fully operational
MVP Capabilities: Creates scanner Jobs, delivers source via ConfigMaps, collects results
```

**Directory Structure:**
```
blocksecops-tool-integration/
├── src/
│   ├── adapters/
│   │   ├── __init__.py
│   │   ├── base_adapter.py        # Base adapter interface
│   │   ├── slither/
│   │   │   ├── __init__.py
│   │   │   ├── adapter.py         # Slither Python API adapter
│   │   │   ├── config.py          # Slither configuration
│   │   │   ├── normalizer.py      # Result normalization
│   │   │   └── detectors/         # Custom detector configs
│   │   ├── aderyn/
│   │   │   ├── __init__.py
│   │   │   ├── adapter.py         # Aderyn CLI wrapper
│   │   │   ├── rust_wrapper.py    # Rust process management
│   │   │   ├── config.py          # Aderyn configuration
│   │   │   └── normalizer.py      # Result normalization
│   │   ├── mythril/
│   │   │   ├── __init__.py
│   │   │   ├── adapter.py         # Mythril CLI adapter
│   │   │   ├── process_wrapper.py # Subprocess management
│   │   │   ├── config.py          # Mythril configuration
│   │   │   └── normalizer.py      # Result normalization
│   │   ├── semgrep/
│   │   │   ├── __init__.py
│   │   │   ├── adapter.py         # Semgrep adapter
│   │   │   ├── rules_manager.py   # Custom rules management
│   │   │   ├── config.py          # Semgrep configuration
│   │   │   └── normalizer.py      # Result normalization
│   │   │   ├── __init__.py
│   │   │   ├── adapter.py         # Solidity-Metrics adapter
│   │   │   ├── nodejs_wrapper.py  # Node.js process wrapper
│   │   │   ├── config.py          # Configuration
│   │   │   └── normalizer.py      # Result normalization
│   │   └── registry.py            # Adapter registry & factory
│   ├── common/
│   │   ├── __init__.py
│   │   ├── schemas.py             # Common vulnerability schemas
│   │   ├── normalizer.py          # Base normalizer
│   │   ├── validators.py          # Input validation
│   │   └── exceptions.py          # Tool-specific exceptions
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py              # Application configuration
│   │   ├── executor.py            # Parallel tool execution
│   │   └── plugin_loader.py       # Dynamic plugin loading
│   ├── api/
│   │   ├── __init__.py
│   │   ├── router.py              # FastAPI routes for tool integration
│   │   ├── schemas.py             # API request/response schemas
│   │   └── dependencies.py        # API dependencies
│   └── main.py                    # Application entry point
├── tools/                         # Tool installation scripts
│   ├── install_slither.sh
│   ├── install_aderyn.sh
│   ├── install_mythx.sh
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── fixtures/                  # Test contracts
│   │   ├── vulnerable/
│   │   ├── safe/
│   │   └── complex/
│   ├── test_slither.py
│   ├── test_aderyn.py
│   ├── test_mythx.py
│   └── integration/
│       └── test_parallel_execution.py
├── k8s/                           # Kubernetes manifests
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### 3. **`blocksecops-intelligence-engine`** (~8K LOC) 🦀
**Risk scoring and vulnerability correlation - Hybrid Python/Rust**
```
Purpose: Deduplication, risk scoring, pattern matching, false positive detection
Tech Stack: Rust computation engine + Python Machine Learning/API wrapper
Rust Components: AST similarity, pattern matching, deduplication algorithms
Python Components: Machine Learning models, API layer, business logic
Contains: Machine Learning algorithms, deduplication logic, risk scoring, pattern analysis
```

**Directory Structure:**
```
blocksecops-intelligence-engine/
├── rust-core/                    # High-performance computation engine
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs                # Rust library interface
│   │   ├── deduplication/
│   │   │   ├── mod.rs
│   │   │   ├── syntactic.rs      # Exact file/line matching
│   │   │   ├── semantic.rs       # AST-based similarity
│   │   │   ├── fuzzy.rs          # Levenshtein distance matching
│   │   │   └── engine.rs         # Main deduplication engine
│   │   ├── pattern_matching/
│   │   │   ├── mod.rs
│   │   │   ├── vulnerability_patterns.rs # Pattern matching
│   │   │   ├── signature_matcher.rs     # Signature matching
│   │   │   ├── regex_engine.rs          # High-performance regex
│   │   │   └── ast_matcher.rs           # AST pattern matching
│   │   ├── similarity/
│   │   │   ├── mod.rs
│   │   │   ├── ast_similarity.rs # Tree-edit distance
│   │   │   ├── text_similarity.rs # Text-based similarity
│   │   │   └── structural.rs     # Structural similarity
│   │   ├── scoring/
│   │   │   ├── mod.rs
│   │   │   ├── risk_calculator.rs # Risk scoring algorithms
│   │   │   └── confidence.rs      # Confidence calculations
│   │   └── ffi/
│   │       ├── mod.rs
│   │       └── python_bindings.rs # PyO3 Python bindings
│   └── tests/
├── python-ml/                    # Python ML and API layer
│   ├── src/
│   │   ├── ml/
│   │   │   ├── __init__.py
│   │   │   ├── models/           # ML model definitions
│   │   │   ├── features.py       # Feature extraction
│   │   │   ├── training.py       # Model training pipeline
│   │   │   └── inference.py      # Model inference
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── intelligence_service.py # Main service
│   │   │   ├── deduplication_service.py # Deduplication orchestration
│   │   │   └── scoring_service.py       # Risk scoring
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── router.py         # Intelligence engine API
│   │   │   ├── schemas.py        # Request/response schemas
│   │   │   └── dependencies.py   # API dependencies
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── config.py         # Configuration management
│   │   │   ├── rust_bridge.py    # Rust core integration
│   │   │   └── exceptions.py     # Custom exceptions
│   │   └── main.py              # Application entry point
│   └── requirements.txt
├── data/                         # ML training data and models
├── k8s/
├── docker/
│   ├── Dockerfile.rust
│   └── Dockerfile.python
└── README.md
```

### 4. **`blocksecops-orchestration`** (~6K LOC)
**Analysis workflow and job management**
```
Purpose: Celery workers, job queues, workflow orchestration, task scheduling
Tech Stack: Python 3.11, Celery, Redis, asyncio
Contains: Task definitions, workflow DAGs, job scheduling, worker management
```

**Directory Structure:**
```
blocksecops-orchestration/
├── src/
│   ├── tasks/
│   │   ├── __init__.py
│   │   ├── analysis_tasks.py      # Main analysis task definitions
│   │   ├── tool_tasks.py          # Individual tool execution tasks
│   │   ├── intelligence_tasks.py  # Intelligence engine tasks
│   │   ├── notification_tasks.py  # Notification tasks
│   │   └── cleanup_tasks.py       # Cleanup and maintenance tasks
│   ├── workflows/
│   │   ├── __init__.py
│   │   ├── analysis_workflow.py   # Complete analysis workflow
│   │   ├── dag_builder.py         # Workflow DAG construction
│   │   └── workflow_engine.py     # Workflow execution engine
│   ├── workers/
│   │   ├── __init__.py
│   │   ├── base_worker.py         # Base worker class
│   │   ├── tool_worker.py         # Tool execution worker
│   │   ├── intelligence_worker.py # Intelligence processing worker
│   │   └── notification_worker.py # Notification worker
│   ├── queue/
│   │   ├── __init__.py
│   │   ├── queue_manager.py       # Queue management
│   │   ├── priority_handler.py    # Priority queue handling
│   │   ├── retry_handler.py       # Failed job retry logic
│   │   └── dead_letter.py         # Dead letter queue management
│   ├── scheduler/
│   │   ├── __init__.py
│   │   ├── job_scheduler.py       # Job scheduling logic
│   │   ├── cron_scheduler.py      # Cron-based scheduling
│   │   └── event_scheduler.py     # Event-driven scheduling
│   ├── monitoring/
│   │   ├── __init__.py
│   │   ├── metrics.py             # Task metrics collection
│   │   ├── health_check.py        # Worker health monitoring
│   │   └── performance.py         # Performance monitoring
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py              # Celery configuration
│   │   ├── celery_app.py          # Celery application setup
│   │   └── exceptions.py          # Task-specific exceptions
│   └── main.py                    # Worker entry point
├── tests/
│   ├── __init__.py
│   ├── test_tasks.py
│   ├── test_workflows.py
│   ├── test_workers.py
│   └── test_queue_management.py
├── k8s/                           # Kubernetes manifests
├── requirements.txt
├── Dockerfile
└── README.md
```

### 5. **`blocksecops-data-service`** (~7K LOC) 🦀
**Database access and caching layer - Hybrid Python/Rust**
```
Purpose: Data models, repository pattern, caching, database migrations
Tech Stack: Python SQLAlchemy ORM + Rust performance engine
Rust Components: High-throughput data processing, search indexing, large file I/O
Python Components: Database models, API layer, migrations, business logic
Contains: Database models, repositories, migrations, caching strategies
```

**Directory Structure:**
```
blocksecops-data-service/
├── rust-engine/                  # High-performance data engine
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs
│   │   ├── indexing/
│   │   │   ├── mod.rs
│   │   │   ├── elasticsearch.rs  # Elasticsearch integration
│   │   │   ├── full_text.rs      # Full-text search
│   │   │   └── faceted.rs        # Faceted search
│   │   ├── processing/
│   │   │   ├── mod.rs
│   │   │   ├── bulk_operations.rs # Bulk data operations
│   │   │   ├── aggregations.rs    # Data aggregations
│   │   │   └── transformations.rs # Data transformations
│   │   ├── cache/
│   │   │   ├── mod.rs
│   │   │   ├── redis_client.rs   # High-performance Redis client
│   │   │   └── cache_strategies.rs # Caching algorithms
│   │   ├── io/
│   │   │   ├── mod.rs
│   │   │   ├── file_processor.rs # Large file processing
│   │   │   ├── csv_parser.rs     # CSV processing
│   │   │   └── json_parser.rs    # JSON processing
│   │   └── ffi/
│   │       └── python_bindings.rs # PyO3 bindings
│   └── tests/
├── python-orm/                   # Python ORM and API layer
│   ├── src/
│   │   ├── models/
│   │   │   ├── __init__.py
│   │   │   ├── base.py           # Base model class
│   │   │   ├── user.py           # User models
│   │   │   ├── project.py        # Project models
│   │   │   ├── analysis.py       # Analysis run models
│   │   │   ├── finding.py        # Security finding models
│   │   │   ├── vulnerability.py  # Vulnerability definition models
│   │   │   └── audit.py          # Audit trail models
│   │   ├── repositories/
│   │   │   ├── __init__.py
│   │   │   ├── base.py           # Base repository class
│   │   │   ├── user_repository.py # User data access
│   │   │   ├── project_repository.py # Project data access
│   │   │   ├── analysis_repository.py # Analysis data access
│   │   │   ├── finding_repository.py  # Finding data access
│   │   │   └── audit_repository.py    # Audit data access
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── data_service.py   # Main data service
│   │   │   ├── search_service.py # Search service
│   │   │   └── cache_service.py  # Cache management
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── router.py         # Data service API
│   │   │   ├── schemas.py        # API schemas
│   │   │   └── dependencies.py   # API dependencies
│   │   ├── core/
│   │   │   ├── __init__.py
│   │   │   ├── config.py         # Database configuration
│   │   │   ├── rust_bridge.py    # Rust engine integration
│   │   │   └── exceptions.py     # Data-specific exceptions
│   │   └── main.py              # Application entry point
│   └── requirements.txt
├── alembic/                      # Database migrations
├── k8s/
├── docker/
│   ├── Dockerfile.rust
│   └── Dockerfile.python
└── README.md
```

### 6. **`blocksecops-notification`** (~5K LOC)
**Real-time notifications and integrations**
```
Purpose: WebSocket server, email notifications, Slack/Teams integrations
Tech Stack: Node.js, TypeScript, Socket.IO, Express, Redis
Contains: WebSocket server, email templates, third-party integrations
```

**Directory Structure:**
```
blocksecops-notification/
├── src/
│   ├── websocket/
│   │   ├── index.ts               # Socket.IO server setup
│   │   ├── connection-handler.ts  # Connection management
│   │   ├── room-manager.ts        # Room/namespace management
│   │   ├── event-handlers.ts      # Socket event handlers
│   │   └── middleware.ts          # WebSocket middleware (auth, etc.)
│   ├── email/
│   │   ├── index.ts               # Email service setup
│   │   ├── smtp-client.ts         # SMTP client configuration
│   │   ├── email-builder.ts       # Email composition
│   │   ├── template-engine.ts     # Template rendering
│   │   └── templates/             # Email templates
│   │       ├── critical-finding.html
│   │       ├── analysis-complete.html
│   │       └── weekly-report.html
│   ├── integrations/
│   │   ├── index.ts
│   │   ├── slack/
│   │   │   ├── slack-client.ts    # Slack API client
│   │   │   ├── webhook-handler.ts # Slack webhook handling
│   │   │   └── message-formatter.ts # Slack message formatting
│   │   ├── teams/
│   │   │   ├── teams-client.ts    # Microsoft Teams integration
│   │   │   ├── adaptive-cards.ts  # Adaptive card builders
│   │   │   └── webhook-handler.ts # Teams webhook handling
│   │   └── generic/
│   │       ├── webhook-client.ts  # Generic webhook client
│   │       └── webhook-validator.ts # Webhook validation
│   ├── queue/
│   │   ├── index.ts
│   │   ├── redis-queue.ts         # Redis-based message queue
│   │   ├── job-processor.ts       # Background job processing
│   │   └── retry-handler.ts       # Failed notification retry
│   ├── api/
│   │   ├── index.ts
│   │   ├── routes/
│   │   │   ├── notifications.ts   # Notification API routes
│   │   │   ├── preferences.ts     # User preference routes
│   │   │   └── webhooks.ts        # Webhook management routes
│   │   ├── middleware/
│   │   │   ├── auth.ts            # Authentication middleware
│   │   │   ├── validation.ts      # Request validation
│   │   │   └── rate-limit.ts      # Rate limiting
│   │   └── schemas/
│   │       ├── notification.ts    # Notification schemas
│   │       └── preferences.ts     # Preference schemas
│   ├── models/
│   │   ├── index.ts
│   │   ├── notification.ts        # Notification models
│   │   ├── preference.ts          # User preference models
│   │   └── template.ts            # Template models
│   ├── services/
│   │   ├── index.ts
│   │   ├── notification-service.ts # Main notification service
│   │   ├── preference-service.ts   # User preference service
│   │   ├── template-service.ts     # Template management service
│   │   └── metrics-service.ts      # Notification metrics
│   ├── config/
│   │   ├── index.ts               # Configuration management
│   │   ├── database.ts            # Database configuration
│   │   ├── redis.ts               # Redis configuration
│   │   └── integrations.ts        # Third-party integration configs
│   ├── utils/
│   │   ├── index.ts
│   │   ├── logger.ts              # Logging utility
│   │   ├── validators.ts          # Data validators
│   │   └── formatters.ts          # Message formatters
│   └── app.ts                     # Express app setup & main entry
├── tests/
│   ├── unit/
│   │   ├── websocket.test.ts
│   │   ├── email.test.ts
│   │   ├── integrations.test.ts
│   │   └── services.test.ts
│   ├── integration/
│   │   ├── api.test.ts
│   │   └── end-to-end.test.ts
│   └── fixtures/                  # Test data fixtures
├── k8s/                           # Kubernetes manifests
├── package.json
├── package-lock.json
├── tsconfig.json
├── jest.config.js
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### **Frontend Repositories (3 repos)**

### 7. **`blocksecops-dashboard`** (~14K LOC) ✅ **MVP COMPLETE - PRODUCTION READY** + **INTELLIGENCE LAYER INTEGRATED**
**Full-featured security dashboard with AI-powered intelligence and real-time updates**
```
Purpose: Complete security scanning interface with advanced intelligence features
Tech Stack: React 18, TypeScript, Recharts, TanStack Query, Socket.IO, DOMPurify, Zod, Vitest
Contains: Auth, contract management, scan results, real-time updates, intelligence components
Status: Production-ready with comprehensive security fixes + Intelligence Layer integration
Security: OWASP Top 10 compliant, 21/21 security tests passing
Testing: 31 component tests, 100% success rate
Latest Update: Phase 6 Intelligence Layer (Nov 2025)

Core Features:
  - Authentication (Login/Register pages with JWT)
  - Contract Management (Upload, list, detail, source viewer)
  - Scan Results (Vulnerability viewer, severity filtering, real-time updates)
  - WebSocket Integration (Live scan progress, instant notifications)
  - Security Hardening (CSP, DOMPurify sanitization, token validation)

Intelligence Layer Features (Phase 6):
  - Pattern Classification Badges (14 color-coded vulnerability categories)
  - Cross-Scanner Deduplication Indicators (consensus visualization)
  - Classification Confidence Meters (visual confidence scoring 0-100%)
  - Fingerprint Debug Panels (4 hash types for developers)
  - Scanner Comparison Views (side-by-side multi-scanner analysis)
  - Advanced Filtering (pattern code, confidence, scanner count, canonical findings)
  - Deduplication Groups (reduce noise, increase signal)
  - Pattern Library (397 vulnerability patterns, 4 ecosystems)
```

**Intelligence Components** (Phase 6.3 - 8 components, 1,236 lines):
```typescript
src/components/intelligence/
├── PatternCodeBadge.tsx           # BVD pattern codes with 14 category colors
├── DeduplicationIndicator.tsx     # Multi-scanner consensus badges
├── ClassificationConfidenceMeter.tsx  # Visual 0-100% confidence
├── FingerprintDebugPanel.tsx      # 4 fingerprint hashes with copy-to-clipboard
├── DeduplicationGroupCard.tsx     # Group summary cards
├── DeduplicationGroupList.tsx     # Filterable/sortable group list
├── ScannerComparisonView.tsx      # Side-by-side scanner comparison
├── VulnerabilityCard.tsx          # Enhanced vulnerability display
└── index.ts                       # Component exports
```

**TypeScript Types** (Phase 6.2 - Full IntelliSense):
```typescript
src/lib/api/
├── vulnerabilities.ts             # Updated with 13 intelligence fields
├── deduplication.ts               # Deduplication group types
├── patterns.ts                    # Vulnerability pattern types
├── deduplicationApi.ts            # Deduplication API client methods
└── index.ts                       # Type exports
```

**Intelligence Fields Integrated** (13 fields):
```typescript
interface Vulnerability {
  // Pattern Classification (4 fields)
  pattern_id?: string;
  pattern_code?: string;                    // BVD-EVM-REE-001
  classification_confidence?: number;       // 0.0-1.0
  classification_method?: 'rule_based' | 'ml_based' | 'hybrid';

  // Fingerprints (4 fields)
  fingerprint_code?: string;                // SHA-256 of normalized code
  fingerprint_location?: string;            // SHA-256 of file:line:function
  fingerprint_ast?: string;                 // SHA-256 of AST structure
  fingerprint_location_fuzzy?: string;      // Fuzzy location hash (±3 lines)

  // Deduplication (5 fields)
  deduplication_group_id?: string;
  is_canonical?: boolean;
  duplicate_count?: number;
  scanner_count?: number;                   // Number of scanners detecting this
  scanners?: string[];                      // List of scanner IDs
}
```

**Optional Pages** (Phase 6.3.9-6.3.15 - Planned):
```
Detailed implementation plan available (1,790+ lines):
  - /vulnerabilities/:id - Enhanced vulnerability detail page
  - /deduplication - Browse deduplication groups
  - /deduplication/:id - Detailed group comparison
  - /patterns - Vulnerability pattern library
  - /patterns/:id - Individual pattern details
  - Advanced intelligence filters
  - UI polish (loading, errors, responsive)
```

**Testing** (Phase 6.4):
```
Component Tests:
  - 31 tests (PatternCodeBadge, DeduplicationIndicator, etc.)
  - 100% success rate
  - Framework: Vitest + React Testing Library

Integration:
  - Full TypeScript type coverage
  - Backward compatible (all fields optional)
  - Zero breaking changes
```

### 8. **`blocksecops-findings`** (~8K LOC)
**Finding management and analysis results**
```
Purpose: Findings table, detail views, status management, filtering
Tech Stack: React, TypeScript, TanStack Query, TanStack Table
Contains: Findings components, filters, detail modals, status management
```

### 9. **`blocksecops-analysis`** (~6K LOC) ✅ **SHARED LIBRARY INTEGRATED**
**Contract analysis workflow**
```
Purpose: Contract upload, analysis progress, history management
Tech Stack: React, TypeScript, React Hook Form, TanStack Query
Contains: Upload components, progress tracking, analysis history
Integration: WASM-enabled TypeScript package with JavaScript fallbacks (6x performance boost)
```

### 10. **`blocksecops-contract-parser`** (~8K LOC) 🦀
**High-performance Solidity parsing and AST generation - Pure Rust**
```
Purpose: Contract parsing, AST generation, dependency analysis, source mapping
Tech Stack: Pure Rust with HTTP API
Components: Solidity parser, AST builder, dependency analyzer, source mapper
Benefits: 10-50x faster parsing, memory safety, true parallelism
```

**Directory Structure:**
```
blocksecops-contract-parser/
├── Cargo.toml
├── src/
│   ├── main.rs                   # HTTP server entry point
│   ├── lib.rs                    # Library interface
│   ├── parser/
│   │   ├── mod.rs
│   │   ├── solidity.rs           # Solidity language parser
│   │   ├── ast.rs                # AST node definitions
│   │   ├── lexer.rs              # Tokenizer
│   │   └── grammar.pest          # Parser grammar (if using pest)
│   ├── analyzer/
│   │   ├── mod.rs
│   │   ├── dependency.rs         # Dependency graph builder
│   │   ├── complexity.rs         # Complexity metrics
│   │   ├── imports.rs            # Import resolution
│   │   └── validation.rs         # Syntax validation
│   ├── api/
│   │   ├── mod.rs
│   │   ├── handlers.rs           # HTTP API handlers (Axum/warp)
│   │   ├── models.rs             # API request/response models
│   │   ├── middleware.rs         # HTTP middleware
│   │   └── server.rs             # HTTP server setup
│   ├── cache/
│   │   ├── mod.rs
│   │   ├── redis.rs              # Redis integration
│   │   ├── memory.rs             # In-memory caching
│   │   └── strategies.rs         # Cache strategies
│   ├── storage/
│   │   ├── mod.rs
│   │   ├── file_system.rs        # File system operations
│   │   └── s3_client.rs          # S3 integration
│   ├── utils/
│   │   ├── mod.rs
│   │   ├── source_map.rs         # Source mapping utilities
│   │   ├── file_utils.rs         # File I/O utilities
│   │   ├── error.rs              # Error handling
│   │   └── config.rs             # Configuration management
│   └── metrics/
│       ├── mod.rs
│       └── prometheus.rs         # Prometheus metrics
├── tests/
│   ├── integration/
│   │   ├── api_tests.rs
│   │   └── parser_tests.rs
│   ├── unit/
│   │   ├── parser_unit_tests.rs
│   │   └── analyzer_unit_tests.rs
│   └── fixtures/                 # Test Solidity contracts
│       ├── simple/
│       ├── complex/
│       └── vulnerable/
├── k8s/                          # Kubernetes manifests
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── ingress.yaml
│   └── overlays/
├── docker/
│   └── Dockerfile               # Multi-stage Rust build
├── scripts/
│   ├── build.sh
│   └── test.sh
├── benches/                     # Performance benchmarks
│   └── parsing_benchmarks.rs
└── README.md
```

### **Shared Libraries (1 repo)**

### 11. **`blocksecops-shared`** (~7K LOC) 🦀 ✅ **PRODUCTION DEPLOYED**
**Common utilities and schemas - Multi-language**
```
Purpose: Shared types, utilities, authentication helpers, validation schemas
Tech Stack: Python + TypeScript + Rust shared libraries
Contains: Common schemas, validation, crypto utilities, shared constants
Status: Production-ready with PyO3 v0.22 + WASM integration across 3 services
Performance: 6-15x speedup for critical operations, 100% cross-language compatibility
```

**Directory Structure:**
```
blocksecops-shared/
├── rust/                         # Rust shared libraries
│   ├── Cargo.toml
│   ├── src/
│   │   ├── lib.rs
│   │   ├── types/
│   │   │   ├── mod.rs
│   │   │   ├── vulnerability.rs  # Vulnerability types
│   │   │   ├── finding.rs        # Finding types
│   │   │   ├── analysis.rs       # Analysis types
│   │   │   └── common.rs         # Common types
│   │   ├── validation/
│   │   │   ├── mod.rs
│   │   │   ├── schema.rs         # Schema validation
│   │   │   ├── contract.rs       # Contract validation
│   │   │   └── security.rs       # Security validation
│   │   ├── crypto/
│   │   │   ├── mod.rs
│   │   │   ├── hashing.rs        # Cryptographic hashing
│   │   │   ├── signatures.rs     # Digital signatures
│   │   │   └── encryption.rs     # Encryption utilities
│   │   ├── constants/
│   │   │   ├── mod.rs
│   │   │   ├── severity.rs       # Severity constants
│   │   │   ├── swc.rs           # SWC mapping constants
│   │   │   └── status.rs         # Status constants
│   │   └── utils/
│   │       ├── mod.rs
│   │       ├── formatting.rs     # Data formatting
│   │       ├── datetime.rs       # DateTime utilities
│   │       └── file.rs           # File utilities
│   └── tests/
├── python/                       # Python shared libraries
│   ├── src/
│   │   ├── solidity_shared/
│   │   │   ├── __init__.py
│   │   │   ├── schemas/          # Pydantic schemas
│   │   │   ├── utils/            # Python utilities
│   │   │   ├── constants/        # Shared constants
│   │   │   ├── auth/             # Auth utilities
│   │   │   ├── exceptions/       # Exception classes
│   │   │   ├── types/            # Type definitions
│   │   │   └── rust_bridge/      # Rust integration
│   │   │       ├── __init__.py
│   │   │       └── bindings.py   # PyO3 bindings
│   │   └── setup.py
│   └── tests/
├── typescript/                   # TypeScript shared libraries
│   ├── src/
│   │   ├── types/                # TypeScript type definitions
│   │   ├── schemas/              # Validation schemas
│   │   ├── utils/                # Utility functions
│   │   ├── constants/            # Shared constants
│   │   ├── auth/                 # Auth utilities
│   │   └── wasm/                 # WASM bindings to Rust
│   │       ├── index.ts
│   │       └── solidity_shared_bg.wasm
│   ├── package.json
│   ├── tsconfig.json
│   └── tests/
├── wasm-bindings/                # Rust → WASM for TypeScript
│   ├── Cargo.toml
│   ├── src/
│   │   └── lib.rs               # WASM bindings
│   └── pkg/                     # Generated WASM output
├── requirements.txt              # Python dependencies
├── package.json                  # TypeScript dependencies
└── README.md
```

### **Infrastructure Repositories (2 repos)**

### 12. **`blocksecops-gcp-infrastructure`**
**GCP Infrastructure as Code repository**
```
Purpose: GCP cloud resource provisioning and management
Tech Stack: Terraform, gcloud CLI
Contains: VPC, GKE, Cloud SQL, Memorystore, Workload Identity, IAM configurations
```

### **Monitoring & Operations (1 repo)**

### 13. **`blocksecops-monitoring`** ✅ **DEPENDENCY MONITORING DEPLOYED**
**Observability and monitoring configurations + Dependency Monitoring Service**
```
Purpose: Monitoring, alerting, observability setup + Multi-language dependency scanning
Tech Stack: Prometheus, Grafana, custom dashboards + Python FastAPI dependency service
Contains: Grafana dashboards, Prometheus rules, alerting configs + Dependency monitoring service
Additional: Multi-language dependency collectors (Python, Node.js, Rust), security vulnerability scanning, Kubernetes deployment with proper Kustomize structure
```

### **Supporting Repositories (3 repos)**

### 14. **`blocksecops-docs`**
**Documentation and knowledge base**
```
Purpose: Technical documentation, API docs, user guides
Tech Stack: Markdown, Docusaurus/GitBook
Contains: Architecture docs, setup guides, API documentation
```

### 15. **`blocksecops-tools`**
**Security tool configurations and utilities**
```
Purpose: Tool installation scripts, configuration templates, test contracts
Tech Stack: Shell scripts, Docker, tool-specific configs
Contains: Tool installation scripts, test fixtures, tool version management, configuration templates
```

### 16. **`blocksecops-vulnerabilities`**
**Vulnerability database and intelligence**
```
Purpose: Vulnerability data, patterns, and threat intelligence
Tech Stack: JSON/YAML schemas, Python scripts
Contains: Vulnerability definitions, patterns, threat intelligence, SWC mappings, severity classifications
```

## Repository Approximate Size Summary

```yaml
Backend Services:           48,000 LOC  (51%)
├── API Service:           10,000 LOC  (Python FastAPI)
├── Tool Integration:      12,000 LOC  (🦀 Hybrid Python/Rust)
├── Intelligence Engine:    8,000 LOC  (🦀 Hybrid Python/Rust)
├── Orchestration:          6,000 LOC  (Python Celery)
├── Data Service:           7,000 LOC  (🦀 Hybrid Python/Rust)
└── Notification:           5,000 LOC  (Node.js/TypeScript)

Contract Parser:             8,000 LOC  (8%) (🦀 Pure Rust)

Frontend Applications:      28,000 LOC  (30%)
├── Dashboard:             14,000 LOC  (React/TypeScript)
├── Findings:               8,000 LOC  (React/TypeScript)
└── Analysis:               6,000 LOC  (React/TypeScript)

Shared Libraries:            7,000 LOC  (7%)  (🦀 Python + TypeScript + Rust)
Infrastructure & Support:    1,000 LOC  (1%)  (Terraform + K8s)

Total Repositories:         16 repos (including dependency monitoring)
Total Estimated:           91,000 LOC
Rust Components:           ~35,000 LOC (37% of codebase)
```

### **Hybrid Python/Rust Services:**
```yaml
Tool Integration Service (12K LOC):
  🦀 Rust Core: File parsing, parallel execution, native Aderyn
  🐍 Python Layer: FastAPI, external integrations, configuration
  Benefits: 5-10x faster tool execution + Python productivity

Intelligence Engine Service (8K LOC):
  🦀 Rust Core: AST similarity, pattern matching, deduplication
  🐍 Python Layer: ML models, API, business logic
  Benefits: 20-50x faster similarity calculations + ML ecosystem

Data Service (7K LOC):
  🦀 Rust Engine: High-throughput processing, search indexing
  🐍 Python Layer: SQLAlchemy ORM, API, migrations
  Benefits: 10x faster data operations + ORM productivity

Shared Libraries (7K LOC):
  🦀 Rust Core: Cryptography, validation, performance utilities
  🐍 Python Bindings: PyO3 integration
  🟨 TypeScript Bindings: WASM integration
  Benefits: Shared performance + multi-language support

Dependency Monitoring Service (2K LOC):
  🐍 Python FastAPI: Multi-language dependency scanning
  🎯 Collectors: Python pip-audit, Node.js npm audit, Rust cargo audit
  📊 Monitoring: Prometheus metrics, Grafana dashboards
  🚀 Deployment: Kubernetes with proper Kustomize structure
  Benefits: Real-time dependency health + security vulnerability alerts
```

## Development Approach

### **Hybrid Architecture Benefits:**
```yaml
🦀 Rust Components (37% of codebase):
  - Contract parsing and AST generation
  - Performance-critical computations
  - Pattern matching and similarity algorithms
  - High-throughput data processing
  - Cryptographic operations
  - Native tool integrations

🐍 Python Components (43% of codebase):
  - FastAPI web services
  - Machine learning and AI
  - Database ORM and migrations
  - Business logic and workflows
  - External API integrations
  - Configuration management

🟨 TypeScript Components (20% of codebase):
  - React frontend application
  - Node.js notification service
  - Type definitions and schemas
  - API clients and utilities
```

### **Multi-Language Integration:**
- **PyO3**: Seamless Python ↔ Rust integration
- **WASM**: Rust utilities available in TypeScript
- **HTTP APIs**: Language-agnostic service communication
- **Shared schemas**: Consistent data models across languages
- **Docker containers**: Standardized deployment regardless of language
