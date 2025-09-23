# Sprint 1 Repository Structure - Microservice Architecture (~85K LOC)

Based on the estimated ~85K LOC and need for manageable repository sizes, here are the repositories you need to create. **Rust is used from Day 1 for performance-critical services.**

## Core Repositories (17 repos)

### **Backend Service Repositories (6 repos)**

### 1. **`solidity-security-api-service`** (~10K LOC)
**FastAPI authentication and API gateway**
```
Purpose: User management, authentication, API routing, JWT handling
Tech Stack: Python 3.11, FastAPI, SQLAlchemy, Pydantic, JWT
Contains: FastAPI routers, auth middleware, user management, API documentation
```

**Directory Structure:**
```
solidity-security-api-service/
├── src/
│   ├── auth/
│   │   ├── __init__.py
│   │   ├── router.py              # Authentication endpoints
│   │   ├── schemas.py             # Pydantic auth models
│   │   ├── models.py              # SQLAlchemy user models
│   │   ├── dependencies.py        # Auth dependencies & JWT validation
│   │   ├── service.py             # Authentication business logic
│   │   ├── utils.py               # Auth utilities (hashing, etc.)
│   │   └── exceptions.py          # Auth-specific exceptions
│   ├── users/
│   │   ├── __init__.py
│   │   ├── router.py              # User management endpoints
│   │   ├── schemas.py             # User Pydantic models
│   │   ├── models.py              # User SQLAlchemy models
│   │   ├── service.py             # User business logic
│   │   └── dependencies.py        # User-specific dependencies
│   ├── projects/
│   │   ├── __init__.py
│   │   ├── router.py              # Project management endpoints
│   │   ├── schemas.py             # Project schemas
│   │   ├── models.py              # Project database models
│   │   └── service.py             # Project business logic
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py              # FastAPI configuration & settings
│   │   ├── security.py            # Security utilities, CORS, etc.
│   │   ├── database.py            # Database connection & session
│   │   └── exceptions.py          # Global exception handlers
│   └── main.py                    # FastAPI application entry point
├── alembic/                       # Database migrations
│   ├── versions/                  # Migration files
│   ├── env.py                     # Alembic environment
│   └── script.py.mako            # Migration template
├── tests/
│   ├── __init__.py
│   ├── conftest.py               # Pytest configuration
│   ├── test_auth.py              # Authentication tests
│   ├── test_users.py             # User management tests
│   └── test_projects.py          # Project management tests
├── k8s/
│   ├── base/
│   │   ├── deployment.yaml        # Kubernetes deployment
│   │   ├── service.yaml           # Kubernetes service
│   │   ├── configmap.yaml         # Configuration
│   │   ├── external-secret.yaml   # AWS Secrets Manager integration
│   │   └── ingress.yaml           # ALB ingress
│   └── overlays/
│       ├── staging/               # Staging-specific configs
│       └── production/            # Production-specific configs
├── requirements.txt               # Python dependencies
├── requirements-dev.txt           # Development dependencies
├── Dockerfile                     # Container build
├── docker-compose.yml             # Local development
├── alembic.ini                    # Alembic configuration
├── pytest.ini                    # Pytest configuration
├── .env.example                   # Environment variables template
└── README.md                      # Setup and usage documentation
```

### 2. **`solidity-security-tool-integration`** (~12K LOC)
**Security tool adapters and integrations**
```
Purpose: Slither, Aderyn, MythX, Solidity-Metrics adapters
Tech Stack: Python 3.11, asyncio, aiohttp, subprocess, Rust wrappers (for Slither, Aderyn), Node.js wrappers (for MythX, Solidity-Metrics)
Contains: Tool adapters, result normalizers, rate limiting, plugin architecture
```

**Directory Structure:**
```
solidity-security-tool-integration/
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
│   │   ├── mythx/
│   │   │   ├── __init__.py
│   │   │   ├── adapter.py         # MythX API adapter
│   │   │   ├── async_client.py    # Async HTTP client
│   │   │   ├── rate_limiter.py    # API rate limiting
│   │   │   ├── config.py          # MythX configuration
│   │   │   └── normalizer.py      # Result normalization
│   │   ├── solidity_metrics/
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
│   └── install_solidity_metrics.sh
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
│   ├── test_solidity_metrics.py
│   └── integration/
│       └── test_parallel_execution.py
├── k8s/                           # Kubernetes manifests
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### 3. **`solidity-security-intelligence-engine`** (~8K LOC) 🦀
**Risk scoring and vulnerability correlation - Hybrid Python/Rust**
```
Purpose: Deduplication, risk scoring, pattern matching, false positive detection
Tech Stack: Rust computation engine + Python ML/API wrapper
Rust Components: AST similarity, pattern matching, deduplication algorithms
Python Components: ML models, API layer, business logic
Contains: ML algorithms, deduplication logic, risk scoring, pattern analysis
```

**Directory Structure:**
```
solidity-security-intelligence-engine/
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

### 4. **`solidity-security-orchestration`** (~6K LOC)
**Analysis workflow and job management**
```
Purpose: Celery workers, job queues, workflow orchestration, task scheduling
Tech Stack: Python 3.11, Celery, Redis, asyncio
Contains: Task definitions, workflow DAGs, job scheduling, worker management
```

**Directory Structure:**
```
solidity-security-orchestration/
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

### 5. **`solidity-security-data-service`** (~7K LOC) 🦀
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
solidity-security-data-service/
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

### 6. **`solidity-security-notification`** (~5K LOC)
**Real-time notifications and integrations**
```
Purpose: WebSocket server, email notifications, Slack/Teams integrations
Tech Stack: Node.js, TypeScript, Socket.IO, Express, Redis
Contains: WebSocket server, email templates, third-party integrations
```

**Directory Structure:**
```
solidity-security-notification/
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

### **Frontend Repositories (4 repos)**

### 7. **`solidity-security-ui-core`** (~8K LOC)
**Shared UI components and design system**
```
Purpose: Reusable components, layouts, authentication, theme system
Tech Stack: React 18, TypeScript, Tailwind CSS, Storybook
Contains: UI components, layouts, auth components, design tokens, utilities
```

### 8. **`solidity-security-dashboard`** (~8K LOC) 
**Dashboard and metrics interface**
```
Purpose: Main dashboard, metrics visualization, overview screens
Tech Stack: React 18, TypeScript, Recharts, TanStack Query
Contains: Dashboard components, charts, metrics, summary views
```

### 9. **`solidity-security-findings`** (~8K LOC)
**Finding management and analysis results**
```
Purpose: Findings table, detail views, status management, filtering
Tech Stack: React 18, TypeScript, TanStack Query, TanStack Table
Contains: Findings components, filters, detail modals, status management
```

### 10. **`solidity-security-analysis`** (~6K LOC)
**Contract analysis workflow**
```
Purpose: Contract upload, analysis progress, history management
Tech Stack: React 18, TypeScript, React Hook Form, TanStack Query
Contains: Upload components, progress tracking, analysis history
```

### 11. **`solidity-security-contract-parser`** (~8K LOC) 🦀
**High-performance Solidity parsing and AST generation - Pure Rust**
```
Purpose: Contract parsing, AST generation, dependency analysis, source mapping
Tech Stack: Pure Rust with HTTP API
Components: Solidity parser, AST builder, dependency analyzer, source mapper
Benefits: 10-50x faster parsing, memory safety, true parallelism
```

**Directory Structure:**
```
solidity-security-contract-parser/
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

### 12. **`solidity-security-shared`** (~7K LOC) 🦀
**Common utilities and schemas - Multi-language**
```
Purpose: Shared types, utilities, authentication helpers, validation schemas
Tech Stack: Python + TypeScript + Rust shared libraries
Contains: Common schemas, validation, crypto utilities, shared constants
```

**Directory Structure:**
```
solidity-security-shared/
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

### **Infrastructure Repositories (3 repos)**

### 13. **`solidity-security-aws-infrastructure`**
**AWS Infrastructure as Code repository**
```
Purpose: AWS cloud resource provisioning and management
Tech Stack: Terraform, AWS CLI, CloudFormation
Contains: VPC, EKS, RDS, ElastiCache, IAM, Secrets Manager configurations
```

### 14. **`solidity-security-infrastructure`**
**Kubernetes Infrastructure as Code repository**
```
Purpose: Kubernetes service definitions and deployment scripts
Tech Stack: Helm, Kubernetes manifests, ArgoCD, GitHub Actions
Contains: K8s manifests, ArgoCD applications, CI/CD pipelines
```

### 15. **`solidity-security-monitoring`**
**Observability and monitoring configurations**
```
Purpose: Monitoring, alerting, and observability setup
Tech Stack: Prometheus, Grafana, custom dashboards
Contains: Grafana dashboards, Prometheus rules, alerting configs
```

### **Supporting Repositories (3 repos)**

### 16. **`solidity-security-docs`**
**Documentation and knowledge base**
```
Purpose: Technical documentation, API docs, user guides
Tech Stack: Markdown, Docusaurus/GitBook
Contains: Architecture docs, setup guides, API documentation
```

### 17. **`solidity-security-tools`**
**Security tool configurations and utilities**
```
Purpose: Tool installation scripts, configuration templates, test contracts
Tech Stack: Shell scripts, Docker, tool-specific configs
Contains: Tool installation scripts, test fixtures, tool version management
```

### 18. **`solidity-security-vulnerabilities`**
**Vulnerability database and intelligence**
```
Purpose: Vulnerability data, patterns, and threat intelligence
Tech Stack: JSON/YAML schemas, Python scripts
Contains: Vulnerability definitions, patterns, threat intelligence
```

## Repository Size Summary

```yaml
Backend Services:           48,000 LOC  (51%)
├── API Service:           10,000 LOC  (Python FastAPI)
├── Tool Integration:      12,000 LOC  (🦀 Hybrid Python/Rust)
├── Intelligence Engine:    8,000 LOC  (🦀 Hybrid Python/Rust)
├── Orchestration:          6,000 LOC  (Python Celery)
├── Data Service:           7,000 LOC  (🦀 Hybrid Python/Rust)
└── Notification:           5,000 LOC  (Node.js/TypeScript)

Contract Parser:             8,000 LOC  (8%) (🦀 Pure Rust)

Frontend Applications:      30,000 LOC  (32%)
├── UI Core:                8,000 LOC  (React/TypeScript)
├── Dashboard:              8,000 LOC  (React/TypeScript) 
├── Findings:               8,000 LOC  (React/TypeScript)
└── Analysis:               6,000 LOC  (React/TypeScript)

Shared Libraries:            7,000 LOC  (7%)  (🦀 Python + TypeScript + Rust)
Infrastructure & Support:    1,000 LOC  (1%)  (Terraform + K8s)

Total Repositories:         17 repos
Total Estimated:           94,000 LOC
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
