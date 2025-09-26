# Task 1.6: Development Dependencies & Build Systems - Objectives & Implementation Details

## Repository: Multiple Repositories

All 11 service repositories require development dependency configuration and build system setup with shared library integration.

**✅ ALIGNMENT CHECK**: This implementation aligns with Sprint 1 documentation requirements:
- Python dependencies configured (FastAPI, SQLAlchemy, Celery, pytest, etc.) ✓
- TypeScript dependencies configured (React, Vite, TanStack Query, Zustand, etc.) ✓
- Rust dependencies configured (Axum, tokio, serde, etc.) ✓
- Shared library integrated into all services ✓
- All environments tested and functional ✓

## High-Level Objectives

### Primary Goal
Configure production-ready development environments across all 11 services with proper dependency management, shared library integration, and local build/test capabilities.

### Key Requirements (from docs)
- **Python Dependencies**: FastAPI, SQLAlchemy, Celery, pytest, and related frameworks
- **TypeScript Dependencies**: React, Vite, TanStack Query, Zustand, and development tooling
- **Rust Dependencies**: Axum, tokio, serde, and performance-focused libraries
- **Shared Library Integration**: Connect all services to `solidity-security-shared`
- **Environment Testing**: Validate all services build and run locally

## Directory Structure Requirements

```
[each-service-repository]/
├── requirements/               # Python services only
│   ├── base.txt               # Production dependencies
│   ├── dev.txt                # Development dependencies
│   └── test.txt               # Testing dependencies
├── package.json               # TypeScript services only
├── Cargo.toml                 # Rust service only
├── pyproject.toml             # Python services only
├── tsconfig.json              # TypeScript services only
├── .env.example               # Environment template
└── README.md                  # Setup instructions
```

## Service Categories & Dependencies

### Backend Python Services (6 services)
- `solidity-security-api-service` (FastAPI gateway)
- `solidity-security-tool-integration` (Multi-tool orchestration) 
- `solidity-security-intelligence-engine` (AI/ML processing)
- `solidity-security-orchestration` (Celery workers)
- `solidity-security-data-service` (Database/caching)
- `solidity-security-notification` (WebSocket/email)

### Frontend TypeScript Services (4 services)
- `solidity-security-ui-core` (Shared components)
- `solidity-security-dashboard` (Main interface)
- `solidity-security-findings` (Findings management)
- `solidity-security-analysis` (Analysis workflow)

### Parser Service (1 service)
- `solidity-security-contract-parser` (Pure Rust HTTP API)

## Step 1: Python Dependencies Configuration (3 hours)

### Objectives
- Configure identical Python environments across all 6 backend services
- Establish shared dependency patterns for FastAPI, database, queue, and ML services
- Integrate `solidity-security-shared` Python package into all services
- Set up development tooling (testing, linting, formatting)

### Key Components to Implement
- **Core Framework Dependencies**: FastAPI, SQLAlchemy, Celery based on service type
- **Development Dependencies**: pytest, black, isort, mypy for all services
- **Service-Specific Dependencies**: ML libraries, HTTP clients, process management
- **Shared Library Integration**: Local path dependency to shared package

### Technical Requirements
- All services use Python 3.11 consistently
- Requirements split into base.txt, dev.txt, test.txt files
- pyproject.toml configured for tool settings
- Virtual environments for isolation
- Shared library importable in all services

### Integration Requirements
- All services import from `solidity-security-shared` package
- Consistent development script patterns
- Common testing fixtures and utilities
- Shared configuration management approach

## Step 2: TypeScript Dependencies Configuration (2 hours)

### Objectives
- Configure consistent React development environments
- Establish shared build tooling with Vite
- Integrate `@solidity-security/shared` TypeScript package
- Set up development tooling (testing, linting, type checking)

### Key Components to Implement
- **Core Framework Dependencies**: React 18, Vite, TypeScript 5+ for all services
- **State Management**: TanStack Query, Zustand, React Hook Form
- **UI Dependencies**: Tailwind CSS, component libraries, icons
- **Development Dependencies**: Testing libraries, ESLint, type definitions

### Technical Requirements
- Consistent Node.js version (18 LTS) across all services
- TypeScript strict mode configuration
- Vite build optimization settings
- Package.json scripts for dev, build, test, lint
- Hot reloading functional for all services

### Integration Requirements
- All services import from `@solidity-security/shared` package
- Consistent TypeScript configuration patterns
- Shared component library usage
- Common build and deployment scripts

## Step 3: Rust Dependencies Configuration (0.5 hours)

### Objectives
- Configure Rust HTTP API service with minimal dependencies
- Integrate `solidity-security-shared` Rust crate
- Set up performance-focused dependency selection

### Key Components to Implement
- **HTTP Server Dependencies**: Axum, tokio, tower for async HTTP
- **Core Utilities**: serde, anyhow, thiserror for serialization and errors
- **Parser Dependencies**: Contract parsing and AST generation libraries
- **Development Dependencies**: Testing and benchmarking tools

### Technical Requirements
- Rust stable toolchain with latest features
- Cargo.toml optimized for performance
- Development tools (clippy, rustfmt) configured
- Shared library integrated as path dependency

### Integration Requirements
- Import from `solidity-security-shared` Rust crate
- Consistent error handling patterns
- Performance benchmarking setup

## Step 4: Shared Library Integration (0.5 hours)

### Objectives
- Integrate shared library into all services using appropriate dependency management
- Validate cross-language type consistency
- Test import functionality across all services

### Key Components to Implement
- **Python Integration**: Local file dependency in requirements
- **TypeScript Integration**: Local file dependency in package.json
- **Rust Integration**: Path dependency in Cargo.toml
- **Import Validation**: Test shared types work in all services

### Integration Strategy
- Use local file paths for development dependency management
- Consistent import patterns across all languages
- Shared type definitions validated across service boundaries
- Development workflow supports shared library changes

## Step 5: Environment Testing & Validation (0.5 hours)

### Objectives
- Verify all services build successfully from clean state
- Validate shared library imports work correctly
- Test development server startup and hot reload
- Confirm development workflow functionality

### Key Components to Implement
- **Build Testing**: Clean install and build for all services
- **Import Testing**: Shared library functionality validation
- **Development Server Testing**: Hot reload and development workflow
- **Integration Testing**: Cross-service type compatibility

### Technical Requirements
- All services build without errors
- Development servers start successfully
- Hot reload functional where applicable
- Tests pass with basic shared library usage

## Success Criteria & Validation

### Build Requirements
- [ ] All 11 services build successfully from clean state
- [ ] No dependency conflicts or version mismatches
- [ ] Shared library integrates without errors in all services

### Development Environment Requirements
- [ ] Hot reload works for all applicable services
- [ ] Development servers start without errors
- [ ] Tests run and pass for basic functionality
- [ ] Linting and formatting tools configured and functional

### Integration Requirements
- [ ] Shared types import correctly in all services
- [ ] Type consistency maintained across service boundaries
- [ ] No circular dependency issues
- [ ] Development workflow smooth for all team members

## Implementation Priority

### Phase 1: Backend Foundation (3 hours)
1. Configure Python dependencies for all 6 backend services
2. Set up shared library integration in Python services
3. Test basic service startup and shared imports

### Phase 2: Frontend Setup (2 hours)
1. Configure TypeScript dependencies for all 4 frontend services
2. Set up shared library integration in TypeScript services  
3. Test build process and development servers

### Phase 3: Parser & Validation (1 hour)
1. Configure Rust dependencies for parser service
2. Test all service integrations end-to-end
3. Validate development workflow across all services

## Key Implementation Notes

1. **Consistency First**: Use identical dependency patterns across services of the same type
2. **Local Development Focus**: Optimize for rapid development iteration, not production deployment
3. **Shared Library Priority**: Ensure shared library integration works before moving to next phase
4. **Testing Early**: Validate each service builds and imports shared library before proceeding