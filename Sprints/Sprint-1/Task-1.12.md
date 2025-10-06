# Task 1.12: ArgoCD Application Definitions - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing ArgoCD Application definitions, AppProjects, and GitOps workflow configurations for managing all platform services across local, staging and production environments.

**✅ ALIGNMENT CHECK**: This implementation creates ArgoCD Application manifests for all platform services (7 backend + 4 frontend) with AppProjects, RBAC policies, and automated GitOps workflows as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Create comprehensive ArgoCD Application manifests with Application of Apps pattern, automated sync policies, and team access control for all platform services.

### Key Requirements (from docs)
- **Application Manifests**: ArgoCD Applications for all platform services
- **AppProjects**: RBAC policies and project organization
- **Application of Apps**: Pattern for service management at scale
- **GitOps Workflow**: Automated deployment with Git webhook integration

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Directory Structure Requirements

```
solidity-security-aws-infrastructure/
├── argocd/
│   ├── applications/              # ArgoCD Application manifests
│   │   ├── backend-services/      # Backend service applications
│   │   ├── frontend-services/     # Frontend service applications
│   │   ├── infrastructure/        # Infrastructure applications
│   │   └── app-of-apps.yaml       # Application of Apps pattern
│   ├── projects/                  # ArgoCD AppProject definitions
│   │   ├── local-project.yaml     # Local development project
│   │   ├── staging-project.yaml   # Staging environment project
│   │   └── production-project.yaml # Production environment project
│   ├── rbac/                      # RBAC policies and configurations
│   └── webhooks/                  # GitHub webhook configurations
└── README.md
```

## Service Categories & Dependencies

### Backend Services (6 applications)
- `solidity-security-api-service` (FastAPI authentication and API gateway)
- `solidity-security-tool-integration` (Security tool adapters, Hybrid Python/Rust)
- `solidity-security-intelligence-engine` (Risk scoring and ML analysis, Hybrid Python/Rust)
- `solidity-security-orchestration` (Workflow management, Python Celery)
- `solidity-security-data-service` (Database and caching, Hybrid Python/Rust)
- `solidity-security-notification` (Real-time notifications, Node.js/TypeScript)

### Contract Parser Service (1 application)
- `solidity-security-contract-parser` (High-performance parsing, Pure Rust)

### Frontend Services (4 applications)
- `solidity-security-ui-core` (Shared components, React/TypeScript)
- `solidity-security-dashboard` (Main dashboard, React/TypeScript)
- `solidity-security-findings` (Finding management, React/TypeScript)
- `solidity-security-analysis` (Analysis workflow, React/TypeScript)

### Infrastructure (Additional applications)
- Monitoring stack, secrets management

## Step 1: ArgoCD Application Manifests (3 hours)

### Objectives
- Create ArgoCD Application manifests for all platform services
- Configure repository connections and sync policies
- Set up environment-specific application configurations

### Key Components to Implement
- **Application Definitions**: ArgoCD Application CRDs for each service
- **Repository Configuration**: Git repository connections and paths
- **Sync Policies**: Automated sync and self-healing configuration

### Technical Requirements
- Environment-specific Application manifests (local/staging/production)
- Repository path configuration for service-specific deployments
- Sync policies with appropriate pruning and self-healing
- Health checks and sync wave configuration for proper ordering

## Step 2: AppProjects and RBAC Configuration (2 hours)

### Objectives
- Configure ArgoCD AppProjects with proper RBAC policies
- Set up team access control and permission management
- Implement Application of Apps pattern for service management

### Key Components to Implement
- **AppProjects**: Environment and team-specific project organization
- **RBAC Policies**: Role-based access control for team members
- **Application of Apps**: Meta-application for managing service applications

### Integration Strategy
- Project-based isolation between environments and teams
- Team-specific access controls with appropriate permissions
- Centralized application management via Application of Apps pattern

## Step 3: Automated Sync and Webhook Integration (1 hour)

### Objectives
- Configure automated sync policies and self-healing
- Set up Git webhook integration for continuous deployment
- Implement rollback capabilities and revision tracking

### Core Dependencies
- **Automated Sync**: Self-healing and automatic synchronization
- **Webhook Integration**: GitHub webhook configuration for push events
- **Revision Management**: Rollback capabilities and deployment history

### Integration Requirements
- GitHub webhook configuration for automatic deployment triggers
- Sync policies balancing automation with safety
- Audit logging and deployment tracking

## Success Criteria & Validation

### Application Configuration Requirements
- [ ] ArgoCD Application manifests created for all 6 backend services plus contract parser
- [ ] ArgoCD Application manifests created for all 4 frontend services
- [ ] Infrastructure applications configured for monitoring and secrets
- [ ] Environment-specific configurations separated (staging/production)
- [ ] Repository paths and sync configurations validated

### Project and Access Control Requirements
- [ ] AppProjects configured with environment and team separation
- [ ] RBAC policies implemented for team-specific access control
- [ ] Application of Apps pattern implemented for centralized management
- [ ] Team permissions configured with appropriate service access
- [ ] Project isolation validated between environments

### Automation and Integration Requirements
- [ ] Automated sync policies configured with self-healing
- [ ] GitHub webhook integration configured for all repositories
- [ ] Continuous deployment triggered by Git push events
- [ ] Rollback capabilities tested and functional
- [ ] Deployment history and audit logging operational

## Implementation Priority

### Phase 1: Application Manifests (3 hours)
1. Create ArgoCD Applications for local development environment first
2. Create ArgoCD Applications for all 6 backend services plus contract parser with appropriate configurations
3. Build frontend service Applications with React-specific deployment settings
4. Configure infrastructure Applications for monitoring and secret management
5. Set up environment-specific Application configurations

### Phase 2: Projects and RBAC (2 hours)
1. Configure AppProjects with team and environment-based organization
2. Implement RBAC policies for team access control and permissions
3. Set up Application of Apps pattern for centralized service management

### Phase 3: Automation and Integration (1 hour)
1. Configure automated sync policies with appropriate self-healing settings
2. Set up GitHub webhook integration for continuous deployment
3. Test rollback capabilities and deployment tracking functionality

## Key Implementation Notes

1. **Sync Waves**: Configure appropriate sync waves for service dependencies
2. **Health Checks**: Implement comprehensive health checks for all applications
3. **Security**: Use least-privilege RBAC policies for team access
4. **Monitoring**: Enable ArgoCD application metrics and alerting

---

**Estimated Time**: 6 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist

### Local Development Environment
- [ ] Local ArgoCD Application manifests created for development services
- [ ] Local GitOps workflow configured for minikube deployments
- [ ] Development Application of Apps pattern for local service management
- [ ] Local RBAC policies configured for development access
- [ ] Local repository connections configured for development workflows
- [ ] Development sync policies configured for rapid iteration
- [ ] Local service deployment validation via ArgoCD

### Staging Environment
- [ ] Staging ArgoCD Application manifests created for all backend services
- [ ] Staging ArgoCD Application manifests created for all frontend services
- [ ] Staging infrastructure applications configured (monitoring, secrets)
- [ ] Staging AppProjects configured with team and environment organization
- [ ] Staging RBAC policies implemented for team access control
- [ ] Staging Application of Apps pattern implemented for service management
- [ ] Staging repository connections and sync policies configured
- [ ] Staging automated sync policies configured with appropriate self-healing
- [ ] GitHub webhook integration set up for staging repositories
- [ ] Staging continuous deployment tested and functional
- [ ] Staging rollback capabilities validated and operational

### Production Environment
- [ ] Production ArgoCD Application manifests created for all 6 backend services plus contract parser
- [ ] Production ArgoCD Application manifests created for all 4 frontend services
- [ ] Production infrastructure applications configured (monitoring, secrets)
- [ ] Production environment-specific configurations separated and validated
- [ ] Production repository connections and sync policies configured
- [ ] Production AppProjects configured with strict team and environment organization
- [ ] Production RBAC policies implemented for secure team access control
- [ ] Production Application of Apps pattern implemented for centralized service management
- [ ] Production team permissions configured with appropriate service access
- [ ] Production automated sync policies configured with conservative self-healing
- [ ] Production GitHub webhook integration set up for all repositories
- [ ] Production continuous deployment tested and functional
- [ ] Production rollback capabilities validated and operational
- [ ] Production deployment history and audit logging configured
- [ ] Production ArgoCD UI showing healthy status for all applications