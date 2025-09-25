# Task 1.7: Development Docker Images - Objectives & Implementation Details

## Repository: Multiple Repositories

All 11 service repositories require Dockerfile creation for development with container registry integration.

**✅ ALIGNMENT CHECK**: This implementation aligns with Sprint 1 documentation requirements:
- Dockerfiles created for all services (Python, TypeScript, Rust) ✓
- All images built with dev tag ✓
- Images pushed to registry ✓
- Build automation scripts created ✓

## High-Level Objectives

### Primary Goal
Create optimized Docker images for all services with development-focused configurations, hot reloading capabilities, and automated build/push workflows to local registry.

### Key Requirements (from docs)
- **Dockerfile Creation**: Multi-stage builds for Python, TypeScript, and Rust services
- **Image Building**: Build all images with development tags
- **Registry Integration**: Push images to local container registry
- **Build Automation**: Scripts for automated building and pushing

## Directory Structure Requirements

```
[each-service-repository]/
├── Dockerfile                   # Multi-stage development build
├── .dockerignore               # Build context optimization
├── docker-compose.yml           # Local development (optional)
├── scripts/
│   ├── build-image.sh          # Build automation script
│   ├── push-image.sh           # Registry push script
│   └── dev-setup.sh            # Development container setup
└── README.md                   # Docker usage instructions
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

## Step 1: Python Service Dockerfiles (2 hours)

### Objectives
- Create multi-stage Docker builds for all 6 Python services
- Optimize for development with hot reloading capabilities
- Implement security best practices with non-root users
- Configure proper dependency installation and caching

### Key Components to Implement
- **Multi-Stage Build**: Separate builder and runtime stages for efficiency
- **Dependency Installation**: Requirements.txt installation with pip caching
- **Security Context**: Non-root user creation and file permissions
- **Development Optimization**: Hot reloading with uvicorn --reload
- **Health Checks**: HTTP endpoint health checking

### Technical Requirements
- Base image: python:3.11-slim for consistency
- Builder stage installs dependencies to user directory
- Runtime stage copies only necessary files and dependencies
- Exposed ports match service requirements (8000, 8001, etc.)
- Environment variables for configuration
- Proper .dockerignore for build optimization

### Integration Requirements
- All Python services use consistent Dockerfile patterns
- Shared library properly installed in container
- Development dependencies available for hot reloading
- Volume mounts configured for source code changes

## Step 2: TypeScript Service Dockerfiles (1 hour)

### Objectives
- Create development-optimized Docker builds for all 4 TypeScript services
- Configure Node.js environment with proper caching
- Enable hot reloading for frontend development
- Implement multi-stage builds for efficiency

### Key Components to Implement
- **Multi-Stage Build**: Node.js builder and runtime stages
- **Dependency Installation**: npm ci with package-lock.json caching
- **Development Server**: Vite dev server with hot reloading
- **Security Context**: Non-root nodejs user
- **Static Asset Serving**: Development asset serving optimization

### Technical Requirements
- Base image: node:18-alpine for lightweight builds
- Builder stage handles npm dependency installation
- Runtime stage configured for development serving
- Exposed port 3000 (or service-specific ports)
- Volume mounts for source code hot reloading
- Proper .dockerignore for node_modules and build artifacts

### Integration Requirements
- Shared TypeScript library available in container
- Hot reloading functional for rapid development
- Consistent build patterns across all frontend services
- Environment variable injection for API endpoints

## Step 3: Rust Service Dockerfile (0.5 hours)

### Objectives
- Create optimized Docker build for Rust parser service
- Implement multi-stage build for minimal runtime image
- Configure for development with fast rebuild capabilities
- Ensure security and performance optimization

### Key Components to Implement
- **Multi-Stage Build**: Rust builder and minimal runtime
- **Dependency Caching**: Cargo dependency pre-compilation
- **Binary Optimization**: Release mode compilation with optimizations
- **Minimal Runtime**: Debian slim base for small image size
- **Security Context**: Non-root user with proper permissions

### Technical Requirements
- Builder stage: rust:1.74-slim with full toolchain
- Runtime stage: debian:bullseye-slim with ca-certificates
- Cargo dependency caching for faster rebuilds
- Binary executable copied to runtime stage
- Exposed port 8080 for HTTP API
- Health check endpoint configuration

### Integration Requirements
- Shared Rust library compiled into binary
- Container optimized for performance and security
- Minimal dependencies for production-ready image

## Step 4: Build Automation Scripts (0.5 hours)

### Objectives
- Create automated scripts for building all service images
- Implement registry pushing with proper tagging
- Configure development workflow automation
- Enable easy image management and updates

### Key Components to Implement
- **Build Script**: Automated Docker build for each service type
- **Push Script**: Registry push with development tags
- **Tag Management**: Consistent tagging strategy (dev, latest)
- **Registry Configuration**: Local registry endpoint configuration
- **Error Handling**: Build failure detection and reporting

### Technical Requirements
- Shell scripts executable from service root directories
- Docker build commands with proper context and tags
- Registry push commands with error handling
- Service discovery for automatic image building
- Development tag naming convention (service-name:dev)

### Integration Requirements
- Scripts work from any service repository
- Registry endpoint configurable via environment variables
- Build order handles service dependencies
- Integration with local development workflow

## Success Criteria & Validation

### Build Requirements
- [ ] All 11 services have functional Dockerfiles
- [ ] All images build successfully without errors
- [ ] Images tagged consistently with dev tags
- [ ] Build process completes in reasonable time (<5 minutes per service)

### Registry Requirements
- [ ] All images push successfully to local registry
- [ ] Images available and pullable from registry
- [ ] Registry catalog shows all service images
- [ ] Image sizes optimized for development use

### Development Requirements
- [ ] Hot reloading configured and functional for applicable services
- [ ] Development containers start without errors
- [ ] Source code changes reflect in running containers
- [ ] Container security contexts properly configured

## Implementation Priority

### Phase 1: Python Services (2 hours)
1. Create Dockerfile template for Python services
2. Implement Dockerfiles for all 6 backend services
3. Test builds and registry pushes for Python images

### Phase 2: Frontend Services (1 hour)
1. Create Dockerfile template for TypeScript services
2. Implement Dockerfiles for all 4 frontend services
3. Test hot reloading and development server functionality

### Phase 3: Rust & Automation (1 hour)
1. Create Dockerfile for Rust parser service
2. Implement build automation scripts
3. Test complete build and push workflow for all services

## Key Implementation Notes

1. **Development Focus**: Optimize for development workflow, not production deployment
2. **Consistency**: Use consistent patterns across services of same type
3. **Security**: Implement non-root users and proper file permissions
4. **Performance**: Use multi-stage builds and proper caching strategies
5. **Hot Reloading**: Priority for frontend services and Python development