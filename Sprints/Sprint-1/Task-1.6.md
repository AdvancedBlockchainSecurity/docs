# Task 1.6: Kubernetes Infrastructure Components - Objectives & Implementation Details

**✅ ALIGNMENT CHECK**: This implementation installs essential Kubernetes infrastructure components including NGINX Ingress Controller for local development, AWS Load Balancer Controller for staging/production, cert-manager, and Vault Secrets Operator as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Install and configure critical Kubernetes infrastructure components to enable secure ingress, SSL certificate management, and Vault Community integration.

### Key Requirements (from docs)
- **Load Balancer Controller**: NGINX Ingress Controller for local development, AWS Load Balancer Controller for ALB management in staging/production
- **Certificate Management**: cert-manager with Let's Encrypt and DNS validation
- **Secret Integration**: Vault Secrets Operator with Kubernetes RBAC authentication in external-secrets-local, external-secrets-staging and external-secrets-production namespaces
- **CSI Driver**: Vault Secrets Store CSI Driver for direct secret mounting

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Directory Structure Requirements

note: nginx needs to be added for local overlay

```yaml
solidity-security-aws-infrastructure/
└── k8s/
    ├── base/                      # Kustomize base configurations
    │   ├── aws-load-balancer-controller/
    │   │   ├── kustomization.yaml # ALB controller base config
    │   │   ├── deployment.yaml    # Controller deployment
    │   │   ├── rbac.yaml          # RBAC configurations
    │   │   └── service-account.yaml # ServiceAccount with IRSA
    │   ├── cert-manager/
    │   │   ├── kustomization.yaml # cert-manager base config
    │   │   ├── deployment.yaml    # cert-manager deployment
    │   │   ├── cluster-issuer.yaml # Let's Encrypt ClusterIssuer
    │   │   └── cloudflare-secret.yaml # Cloudflare API secret template
    │   ├── external-secrets/
    │   │   ├── kustomization.yaml # Vault Secrets base config
    │   │   ├── operator.yaml      # Vault Secrets Operator
    │   │   ├── cluster-secret-store.yaml # Vault Community store
    │   │   └── rbac.yaml          # RBAC for Vault Secrets
    │   └── monitoring/
    │       ├── kustomization.yaml # Monitoring base config
    │       └── service-monitors.yaml # Service monitoring configs
    └── overlays/                  # Environment-specific overlays
        ├── local/                 # Local environment overlay
        │   ├── kustomization.yaml # Local customizations
        │   ├── nginx-ingress-patch.yaml # Local nginx config
        │   ├── cert-manager-patch.yaml # Local cert config (self-signed)
        │   └── external-secrets-patch.yaml # Local secrets config
        ├── staging/               # Staging environment overlay
        │   ├── kustomization.yaml # Staging customizations
        │   ├── alb-controller-patch.yaml # Staging ALB config
        │   ├── cert-manager-patch.yaml # Staging cert config
        │   └── external-secrets-patch.yaml # Staging secrets config
        └── production/            # Production environment overlay
            ├── kustomization.yaml # Production customizations
            ├── alb-controller-patch.yaml # Production ALB config
            ├── cert-manager-patch.yaml # Production cert config
            └── external-secrets-patch.yaml # Production secrets config
```

## Step 1: Load Balancer Installation (1.5 hours)

### Objectives
- Install NGINX Ingress Controller for local development
- Install AWS Load Balancer Controller for staging/production clusters
- Configure IAM roles and policies for ALB management in staging/production
- Validate load balancer provisioning (NGINX for local, ALB for staging/production)

### Key Components to Implement
- **Kustomize Base Manifests**: Base load balancer controller configuration (NGINX for local, AWS for staging/production)
- **IRSA Configuration**: ServiceAccount with IAM Role for Service Accounts (IRSA) for AWS environments
- **Environment Overlays**: Environment-specific controller settings (NGINX for local, AWS for staging/production)
- **Load Balancer Configuration**: Default IngressClass settings (NGINX for local, ALB for staging/production)

### Technical Requirements
- IRSA (IAM Roles for Service Accounts) configuration
- Proper AWS permissions for ALB lifecycle management
- Integration with VPC subnets for load balancer placement
- Support for both internet-facing and internal load balancers

## Step 2: Certificate Management Setup (Local, Staging, Production) (1.5 hours)

### Objectives
- Install cert-manager for automated SSL certificate management.
- Configure Let's Encrypt integration with DNS validation
- Set up Cloudflare DNS integration for certificate validation

### Key Components to Implement
- **Kustomize Base Manifests**: Base cert-manager configuration
- **ClusterIssuers**: Let's Encrypt local, staging and production issuers via Kustomize
- **DNS01 Challenge**: Cloudflare DNS validation configuration
- **Environment Overlays**: Staging vs production certificate configurations

### Integration Strategy
- Kustomize-based deployment with environment-specific certificate configurations
- DNS validation using Cloudflare API for domain ownership proof
- Automatic certificate renewal and management
- Integration with ingress controllers for SSL termination

## Step 3: Secrets Management Integration (1 hour)

### Objectives
- Install Vault Secrets Operator for HashiCorp Vault Community Edition integration in external-secrets-local, external-secrets-staging and external-secrets-production namespaces
- Configure Vault Secrets Store CSI Driver for direct secret mounting
- Set up IRSA for secure Vault Community access

### Core Dependencies
- **Kustomize Base Manifests**: Base Vault Secrets Operator configuration
- **Vault Secrets Operator**: Kubernetes-native secret synchronization in external-secrets-local, external-secrets-staging and external-secrets-production namespaces
- **Vault Secrets Driver**: Direct secret mounting capabilities via Kustomize
- **Environment Overlays**: Staging vs production secrets configurations

### Integration Requirements
- Kustomize-based deployment with environment-specific configurations
- Integration with HashiCorp Vault Community Edition from Task 1.4
- Service account configuration for each service namespace via overlays
- Secret synchronization and automatic rotation support

## Success Criteria & Validation

### Load Balancer Requirements
- [ ] Kustomize base manifests created for AWS Load Balancer Controller 
- [ ] Environment overlays configured for local, staging and production
- [ ] AWS Load Balancer Controller operational in both clusters
- [ ] IRSA configured for ALB management permissions
- [ ] ALB integration with VPC subnets validated

### Certificate Management Requirements
- [ ] Kustomize base manifests created for cert-manager
- [ ] Environment overlays configured with Let's Encrypt ClusterIssuers
- [ ] cert-manager deployed and operational in both clusters
- [ ] Cloudflare DNS validation configured via Kustomize
- [ ] Test certificate issuance for domain validation

### Secrets Management Requirements
- [ ] Kustomize base manifests created for Vault Secrets Operator
- [ ] Environment overlays configured for HashiCorp Vault Community Edition integration
- [ ] Vault Secrets Operator deployed and operational
- [ ] Kubernetes auth configured for HashiCorp Vault Community Edition access
- [ ] Test secret synchronization from HashiCorp Vault Community Edition via Kustomize

## Implementation Priority

### Phase 1: Load Balancer Controller (1.5 hours)
1. Create Staging and Production Kustomize base manifests for AWS Load Balancer Controller. Create Local overlay Kustomize base manifests for NGINX.
2. Configure environment overlays for local, staging and production clusters
3. Deploy via kubectl apply -k and validate ALB creation

### Phase 2: Certificate Management (1.5 hours)
1. Create Kustomize base manifests for cert-manager components
2. Configure environment overlays with Let's Encrypt ClusterIssuers
3. Deploy via Kustomize and test certificate issuance with Cloudflare DNS

### Phase 3: Secrets Integration (1 hour)
1. Create Kustomize base manifests for Vault Secrets Operator
2. Configure environment overlays for HashiCorp Vault Community Edition integration
3. Deploy via Kustomize and test secret synchronization capabilities

## Key Implementation Notes

1. **Kustomize Structure**: Use base configurations with environment overlays for maintainability
2. **IRSA Configuration**: Ensure proper IAM roles are created and associated with service accounts
3. **DNS Integration**: Cloudflare API credentials must be securely stored and accessible
4. **GitOps Ready**: All manifests structured for ArgoCD deployment in future tasks
4. **Monitoring**: Enable monitoring for all infrastructure components to track health and performance

---

**Estimated Time**: 4 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist

### Local Development Environment
- [ ] nginx-ingress-controller Helm chart installed in minikube
- [ ] Local ingress controller configured for development service access
- [ ] Self-signed certificate generation configured for local development
- [ ] Local External Secrets Operator installed via Helm chart
- [ ] Local secrets integration with HashiCorp Vault configured
- [ ] Development ingress rules configured and tested
- [ ] Local certificate management tested with self-signed certs
- [ ] Port forwarding configured for direct service access

### Staging Environment
- [ ] Kustomize base manifests created for AWS Load Balancer Controller
- [ ] Environment overlays configured for staging ALB controller
- [ ] AWS Load Balancer Controller installed in staging cluster
- [ ] IRSA configured for staging Load Balancer Controller
- [ ] Staging ALB creation and management functionality validated
- [ ] Kustomize base manifests created for cert-manager
- [ ] Staging cert-manager installed with CRDs
- [ ] Let's Encrypt ClusterIssuer configured for staging environment
- [ ] Cloudflare DNS integration configured and tested for staging
- [ ] Staging test certificate issuance completed successfully
- [ ] Vault Secrets Operator installed and configured for staging
- [ ] Staging Kubernetes auth configured for HashiCorp Vault access
- [ ] Secret synchronization from HashiCorp Vault tested in staging

### Production Environment
- [ ] Production overlays configured for AWS Load Balancer Controller
- [ ] AWS Load Balancer Controller installed in production cluster
- [ ] Production IRSA configured for Load Balancer Controller
- [ ] Production ALB creation and management functionality validated
- [ ] Production cert-manager installed with CRDs
- [ ] Let's Encrypt ClusterIssuer configured for production environment
- [ ] Production Cloudflare DNS integration configured and tested
- [ ] Production test certificate issuance completed successfully
- [ ] Production Vault Secrets Operator installed and configured
- [ ] Vault Secrets Store CSI Driver installed and operational in production
- [ ] Production Kubernetes auth configured for HashiCorp Vault access
- [ ] Production secret synchronization from HashiCorp Vault tested
- [ ] Production secret mounting capabilities validated
- [ ] All production infrastructure components monitored and healthy