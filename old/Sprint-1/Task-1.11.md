# Task 1.11: Frontend Microservice Kubernetes Templates - Objectives & Implementation Details

## Repositories: Frontend Service Repositories

This task creates Kubernetes templates for all frontend service repositories:
- `blocksecops-ui-core` (Shared UI components and design system, React/TypeScript)
- `blocksecops-dashboard` (Dashboard and metrics interface, React/TypeScript)
- `blocksecops-findings` (Finding management and analysis results, React/TypeScript)
- `blocksecops-analysis` (Contract analysis workflow, React/TypeScript)

**✅ ALIGNMENT CHECK**: This implementation creates production-ready Kubernetes deployment templates for all 4 frontend services with React optimization, environment configuration, and ALB integration as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Create comprehensive Kubernetes templates for all frontend microservices with React application optimization, environment-specific configuration, and production-ready deployment capabilities.

### Key Requirements (from docs)
- **React Applications**: Deployment configurations for React-based frontend services
- **Authentication UI**: Login pages and authentication flows for each subdomain/application
- **Environment Configuration**: ConfigMaps for environment-specific API endpoints
- **ALB Integration**: Ingress routing with SSL termination for frontend access
- **Asset Optimization**: Build-time optimization and static asset caching

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Directory Structure Requirements

### Example: `blocksecops-dashboard`
```
blocksecops-dashboard/
├── k8s/
│   ├── base/
│   │   ├── deployment.yaml        # React app deployment with NGINX
│   │   ├── service.yaml           # Kubernetes service
│   │   ├── configmap.yaml         # Environment-specific config
│   │   └── ingress.yaml           # ALB ingress with SSL
│   └── overlays/
│       ├── local/                 # Local development configs
│       ├── staging/               # Staging-specific configs
│       └── production/            # Production-specific configs
├── src/                           # React application source
│   ├── components/
│   │   ├── auth/                  # Authentication components
│   │   │   ├── LoginPage.tsx      # Login page component
│   │   │   ├── AuthProvider.tsx   # Authentication context
│   │   │   └── ProtectedRoute.tsx # Route protection
│   │   └── common/                # Shared components
│   ├── hooks/                     # Custom React hooks
│   │   └── useAuth.ts            # Authentication hook
│   └── services/
│       └── authService.ts        # API service integration
├── public/                        # Static assets
├── package.json                   # Node.js dependencies
├── vite.config.ts                 # Vite build configuration
├── Dockerfile                     # Multi-stage build
├── nginx.conf                     # NGINX configuration
└── README.md
```

## Service Categories & Dependencies

### Frontend Services (4 services)
- `ui-core` (Shared React component library with Storybook documentation and common auth components)
- `dashboard` (Main dashboard React application with real-time WebSocket connections and login page)
- `findings` (Finding management interface with advanced filtering capabilities and authentication)
- `analysis` (Contract upload interface with analysis progress tracking and user authentication)

## Step 1: React Application Templates with Authentication (3 hours)

### Objectives
- Create Kubernetes deployment manifests for all 4 frontend services
- Configure React application deployment with NGINX serving
- Implement authentication UI components and login pages for each service
- Set up build-time optimization and asset bundling

### Key Components to Implement
- **Authentication Components**: Login pages, auth providers, and protected routes
- **Deployment Manifests**: React application deployments with NGINX containers
- **Build Configuration**: Multi-stage Docker builds with optimization
- **Static Serving**: NGINX configuration for efficient static asset serving

### Technical Requirements
- Login page components for each frontend application
- JWT token handling and API integration with blocksecops-api-service
- Multi-stage Docker builds for optimized production images
- NGINX configuration for React single-page applications with auth routing
- Proper caching headers for static assets
- Environment variable injection for runtime configuration

## Step 2: Authentication Integration and Configuration (1.5 hours)

### Objectives
- Create ConfigMaps for environment-specific API endpoints and auth configuration
- Configure environment variable injection for React applications
- Set up authentication service integration with API gateway
- Configure JWT token management and refresh logic

### Key Components to Implement
- **Auth ConfigMaps**: Environment-specific authentication and API endpoint configuration
- **Environment Injection**: Runtime configuration for React applications with auth settings
- **Service Integration**: Backend API endpoint and authentication service configuration
- **Token Management**: JWT storage, refresh, and expiration handling

### Integration Strategy
- Environment-specific ConfigMaps for local, staging and production with auth endpoints
- Runtime environment variable injection without build-time hardcoding
- API endpoint configuration for backend service integration
- Authentication flow integration with blocksecops-api-service
- Subdomain-specific authentication routing and session management

## Step 3: ALB Ingress and Asset Optimization (30 minutes)

### Objectives
- Configure ALB ingress routing for all frontend services
- Set up SSL termination and domain-based routing
- Implement static asset caching and optimization

### Core Dependencies
- **ALB Ingress**: Application Load Balancer integration with path-based routing
- **SSL Termination**: cert-manager integration for automatic SSL certificates
- **Caching Strategy**: CloudFront or ALB-level caching for static assets

### Integration Requirements
- Domain-based routing for each frontend service
- SSL certificate provisioning via cert-manager
- Health checks for frontend service availability

## Success Criteria & Validation

### React Application Requirements
- [ ] Kubernetes deployment templates created for all 4 frontend services
- [ ] Login page components implemented for each frontend application
- [ ] Authentication context providers and protected routes configured
- [ ] JWT token handling and API integration implemented
- [ ] Multi-stage Docker builds configured with production optimization
- [ ] NGINX configuration implemented for React SPA serving with auth routing
- [ ] Static asset serving optimized with appropriate caching headers
- [ ] Build-time optimization configured for production deployments

### Authentication and Environment Configuration Requirements
- [ ] ConfigMaps created for environment-specific API endpoint and auth configuration
- [ ] Environment variable injection configured for runtime configuration
- [ ] Authentication service integration with blocksecops-api-service configured
- [ ] JWT token management and refresh logic implemented
- [ ] Backend service integration configured via environment variables
- [ ] Service discovery configuration for backend API communication
- [ ] Subdomain-specific authentication routing configured
- [ ] Development and production environment configurations separated

### ALB and Optimization Requirements
- [ ] ALB ingress configurations created for all frontend services
- [ ] SSL termination configured with cert-manager integration
- [ ] Domain-based routing configured for service access
- [ ] Health checks implemented for frontend service availability
- [ ] Static asset caching and optimization configured

## Implementation Priority

### Phase 1: React Application Templates with Authentication (3 hours)
1. Create local development Kubernetes templates for all frontend services first
2. Create UI Core service template with component library, Storybook hosting, and shared auth components
3. Build Dashboard service template with real-time WebSocket integration and login page
4. Develop Findings service template with advanced filtering capabilities and authentication
5. Create Analysis service template with file upload, progress tracking, and user authentication
6. Implement JWT token handling and API integration for all services

### Phase 2: Authentication Integration and Configuration (1.5 hours)
1. Configure ConfigMaps for environment-specific API endpoints, auth settings, and JWT configuration
2. Set up environment variable injection for runtime React configuration with authentication
3. Configure service integration settings for backend API communication and auth service
4. Implement subdomain-specific authentication routing and session management

### Phase 3: ALB Integration and Optimization (30 minutes)
1. Configure ALB ingress with path-based routing for all frontend services
2. Set up SSL certificate provisioning and domain-based access
3. Implement static asset caching and performance optimization

## Key Implementation Notes

1. **Authentication Architecture**: Integrate with blocksecops-api-service for centralized authentication and JWT token management
2. **Subdomain Authentication**: Implement subdomain-specific login pages and authentication flows for each application
3. **React Optimization**: Configure webpack optimization and code splitting for production builds
4. **Environment Flexibility**: Use runtime configuration injection to avoid rebuilding for different environments
5. **Caching Strategy**: Implement proper caching headers for static assets and API responses
6. **Health Checks**: Configure appropriate health checks for React applications served by NGINX
7. **Security**: Implement secure JWT token storage, refresh logic, and protected route mechanisms

---

**Estimated Time**: 5 hours
**Owner**: Frontend/DevOps Team
**Priority**: P1 (High)

## Task Checklist

### Local Development Environment
- [ ] Local development Kubernetes templates created for all frontend services
- [ ] Local React development environment configured with hot reload
- [ ] Local ingress configurations for frontend service access via minikube
- [ ] Local authentication integration with development API endpoints
- [ ] Development ConfigMaps for local API endpoint configuration
- [ ] Local static asset serving via NGINX in minikube
- [ ] Development environment variables configured for local testing
- [ ] Local SSL certificate configuration for development HTTPS testing

### Staging Environment
- [ ] Staging Kubernetes deployment templates created for all frontend services
- [ ] UI Core staging service template created with component library deployment and shared auth components
- [ ] Storybook documentation hosting configured for UI Core staging
- [ ] Login page components implemented for all staging frontend applications
- [ ] Authentication context providers and protected routes configured for staging
- [ ] JWT token handling and API service integration implemented for staging
- [ ] Dashboard staging service template created with WebSocket integration and login page
- [ ] Real-time connection configuration implemented for staging Dashboard
- [ ] Findings staging service template created with filtering capabilities and authentication
- [ ] Advanced filtering and sorting configuration implemented for staging
- [ ] Analysis staging service template created with file upload interface and user authentication
- [ ] Staging ConfigMaps created for environment-specific API and auth configurations
- [ ] Staging environment variable injection configured for runtime settings with authentication
- [ ] Staging backend service integration configured via environment variables
- [ ] Staging authentication service integration with blocksecops-api-service configured

### Production Environment
- [ ] Production Kubernetes deployment templates created for all frontend services
- [ ] Production UI Core service template with optimized component library deployment
- [ ] Production Storybook documentation hosting with SSL and domain configuration
- [ ] Production login page components implemented for all frontend applications
- [ ] Production authentication context providers and protected routes configured
- [ ] Production JWT token handling and API service integration implemented
- [ ] Production Dashboard service template with WebSocket integration and optimized login page
- [ ] Production real-time connection configuration implemented for Dashboard
- [ ] Production Findings service template with advanced filtering and authentication
- [ ] Production Analysis service template with optimized file upload and user authentication
- [ ] Production analysis progress tracking and history management configured
- [ ] Production multi-stage Docker builds configured for all services
- [ ] Production NGINX configuration implemented for React SPA serving with auth routing
- [ ] Production ConfigMaps created for environment-specific API and auth configurations
- [ ] Production environment variable injection configured for runtime settings with authentication
- [ ] Production backend service integration configured via environment variables
- [ ] Production authentication service integration with blocksecops-api-service configured
- [ ] Production subdomain-specific authentication routing and session management implemented
- [ ] Production ALB ingress configurations created for all frontend services
- [ ] Production SSL termination configured with cert-manager
- [ ] Production domain-based routing configured for service access
- [ ] Production health checks implemented for all frontend services
- [ ] Production static asset caching and optimization configured