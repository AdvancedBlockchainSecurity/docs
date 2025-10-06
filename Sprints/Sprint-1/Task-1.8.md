# Task 1.8: ArgoCD Installation and Configuration - Objectives & Implementation Details

**✅ ALIGNMENT CHECK**: This implementation deploys ArgoCD for GitOps workflow management in local, staging and production environments with GitHub integration and SSL termination as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Deploy and configure ArgoCD for GitOps workflow management in argocd-local, argocd-staging and argocd-production namespaces with GitHub integration, SSL termination, and team access control.

### Key Requirements (from docs)
- **ArgoCD Deployment**: ArgoCD in argocd-local, argocd-staging and argocd-production namespaces with Vault Community Edition integration
- **GitHub Integration**: Connection to all 17 repositories for deployment management
- **Access Control**: RBAC policies for team access and security
- **SSL Configuration**: SSL termination and domain access

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Directory Structure Requirements

ArgoCD configuration will be integrated into the existing infrastructure repository:

```
solidity-security-aws-infrastructure/
├── argocd/
│   ├── base/
│   │   ├── kustomization.yaml      # Base ArgoCD configuration
│   │   ├── deployment.yaml         # ArgoCD server deployment
│   │   ├── service.yaml            # ArgoCD service definition
│   │   ├── configmap.yaml          # ArgoCD configuration
│   │   ├── rbac-configmap.yaml     # RBAC policies
│   │   └── ingress.yaml            # ArgoCD ingress configuration
│   └── overlays/
│       ├── local/
│       │   ├── kustomization.yaml  # Local environment overlay
│       │   ├── configmap-patch.yaml
│       │   └── ingress-patch.yaml
│       ├── staging/
│       │   ├── kustomization.yaml  # Staging environment overlay
│       │   ├── configmap-patch.yaml
│       │   ├── ingress-patch.yaml
│       │   └── vault-secret.yaml   # Vault Secrets integration
│       └── production/
│           ├── kustomization.yaml  # Production environment overlay
│           ├── configmap-patch.yaml
│           ├── ingress-patch.yaml
│           ├── vault-secret.yaml   # Vault Secrets integration
│           └── ha-patches.yaml     # High availability configuration
├── applications/                   # ArgoCD Application definitions
│   ├── backend-services/
│   ├── frontend-services/
│   ├── infrastructure/
│   └── app-of-apps.yaml           # Application of Applications pattern
└── README.md
```

## Step 1: ArgoCD Server Deployment (2 hours)

### Objectives
- Deploy ArgoCD in argocd-staging namespace with AWS integration
- Deploy ArgoCD in argocd-production namespace with AWS integration
- Configure ArgoCD with Vault Secrets Operator for credential management

### Key Components to Implement
- **ArgoCD Server**: Core ArgoCD components (server, repo-server, application-controller)
- **Vault Integration**: Vault Secrets Operator integration for GitHub credentials
- **High Availability**: Multi-replica deployment for production environment

### Technical Requirements
- ArgoCD deployment with persistent storage for configuration
- Vault Secrets integration for GitHub tokens and SSH keys
- Resource limits and requests appropriate for environment
- Security context configuration for container security

## Step 2: GitHub Integration and Repository Access (1.5 hours)

### Objectives
- Configure GitHub integration for all 17 repositories
- Set up SSH key or token-based authentication
- Configure repository access and sync policies

### Key Components to Implement
- **Repository Connections**: GitHub repository configuration for all services
- **Authentication**: SSH key or GitHub token configuration via secrets
- **Sync Policies**: Repository synchronization and webhook configuration

### Integration Strategy
- Repository-specific access patterns for service deployment
- Webhook configuration for automatic synchronization
- Branch and tag-based deployment strategies

## Step 3: SSL Configuration and Team Access (30 minutes)

### Objectives
- Configure SSL termination and domain access
- Set up RBAC policies for team access control
- Validate ArgoCD accessibility and functionality

### Core Dependencies
- **SSL Certificates**: cert-manager integration for SSL termination
- **Ingress Configuration**: ALB ingress with SSL and domain routing
- **RBAC Policies**: Team-specific access control and permissions

### Integration Requirements
- Domain configuration: argocd.staging.advancedblockchainsecurity.com
- Domain configuration: argocd.app.advancedblockchainsecurity.com
- Team authentication via GitHub OAuth or OIDC integration

## Success Criteria & Validation

### ArgoCD Infrastructure Requirements
- [ ] ArgoCD operational in argocd-local namespace with basic configuration for minikube
- [ ] ArgoCD operational in argocd-staging namespace with persistent storage
- [ ] ArgoCD operational in argocd-production namespace with high availability
- [ ] Vault Secrets Operator integration functional for credential management
- [ ] ArgoCD server accessible and responsive
- [ ] Resource limits configured appropriate for environment load

### GitHub Integration Requirements
- [ ] All 17 repositories connected and accessible in ArgoCD
- [ ] GitHub authentication configured via Vault Secrets Operator
- [ ] Repository synchronization functional with appropriate policies
- [ ] Webhook integration configured for automatic sync triggers
- [ ] Repository access validated for deployment operations

### SSL and Access Control Requirements
- [ ] Self-signed certificates configured for ArgoCD local domain (argocd.local)
- [ ] SSL certificates provisioned for ArgoCD staging domain via cert-manager-staging namespace
- [ ] SSL certificates provisioned for ArgoCD production domain via cert-manager-production namespace
- [ ] ArgoCD accessible at argocd.local (local development)
- [ ] ArgoCD accessible at argocd.staging.advancedblockchainsecurity.com
- [ ] ArgoCD accessible at argocd.app.advancedblockchainsecurity.com
- [ ] RBAC policies configured for team access control
- [ ] Team authentication functional via GitHub integration

## Implementation Priority

### Phase 1: Core ArgoCD Deployment (2 hours)
1. Create ArgoCD Kustomize base configuration in `solidity-security-aws-infrastructure/argocd/base/`
2. Deploy ArgoCD server components in argocd-local namespace using Kustomize overlay in `argocd/overlays/local/`
3. Deploy ArgoCD server components in argocd-staging namespace using Kustomize overlay in `argocd/overlays/staging/`
4. Deploy ArgoCD server components in argocd-production namespace using Kustomize overlay in `argocd/overlays/production/`
4. Configure persistent storage and Vault Secrets Operator integration via Kustomize patches

### Phase 2: Repository Integration (1.5 hours)
1. Configure GitHub repository connections for all 17 services via ArgoCD configmap patches
2. Set up authentication credentials via Vault Secrets integration in environment overlays
3. Create ArgoCD Application definitions in `applications/` directory
4. Configure repository synchronization policies and webhook integration

### Phase 3: SSL and Access Control (30 minutes)
1. Configure SSL certificates and ingress via Kustomize ingress patches
2. Set up RBAC policies via `rbac-configmap.yaml` in base configuration
3. Apply environment-specific ingress patches for domain configuration
4. Validate ArgoCD accessibility and GitHub integration functionality

## Key Implementation Notes

1. **High Availability**: Configure ArgoCD with multiple replicas in production for reliability
2. **Security**: Use Vault Secrets Operator for all credential management
3. **Access Control**: Implement least-privilege RBAC policies for team access
4. **Monitoring**: Enable ArgoCD metrics collection for monitoring and alerting

---

**Estimated Time**: 4 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist

### Local Development Environment
- [x] ArgoCD Helm chart installed in minikube for local development
- [x] Local ArgoCD configured with development repositories access
- [x] Development GitOps workflow configured for local deployments
- [x] Local ArgoCD accessible via port forwarding (localhost:8080)
- [x] Development applications configured for local minikube deployment
- [x] Local repository sync policies configured for development workflow
- [x] Development RBAC policies configured for local access

### Staging Environment
- [ ] Kustomize base manifests created for ArgoCD in infrastructure repository
- [ ] Staging overlay created in `argocd/overlays/staging/` directory
- [ ] ArgoCD deployed in argocd-staging namespace with persistent storage
- [ ] Vault Secrets Operator integration configured for staging credentials
- [ ] Staging resource limits and security contexts configured
- [ ] GitHub repositories connected to staging ArgoCD (subset for staging)
- [ ] GitHub authentication configured via Vault Secrets for staging
- [ ] Repository synchronization policies configured for staging
- [ ] Webhook integration set up for automatic sync in staging
- [ ] SSL certificates provisioned for staging ArgoCD domain
- [ ] ArgoCD accessible at argocd-staging.advancedblockchainsecurity.com
- [ ] Staging RBAC policies configured for team access control

### Production Environment
- [ ] Production overlay created in `argocd/overlays/production/` directory
- [ ] ArgoCD deployed in argocd-production namespace with high availability
- [ ] Production Vault Secrets Operator integration configured for credentials
- [ ] Production resource limits and security contexts configured
- [ ] All 17 GitHub repositories connected to production ArgoCD
- [ ] Production GitHub authentication configured via Vault Secrets
- [ ] Production repository synchronization policies configured
- [ ] Production webhook integration set up for automatic sync
- [ ] Production SSL certificates provisioned for ArgoCD domains
- [ ] ArgoCD accessible at argocd.app.advancedblockchainsecurity.com
- [ ] Production RBAC policies configured for team access control
- [ ] Production team authentication functional via GitHub integration
- [ ] Production ArgoCD functionality validated with repository access
- [ ] Production GitOps workflow operational and validated