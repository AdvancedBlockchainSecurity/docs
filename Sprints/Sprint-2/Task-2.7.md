# Task 2.7: ArgoCD Installation and GitOps Setup

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 6 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Day**: 7-8

## Objective

Deploy ArgoCD for comprehensive GitOps workflow management across all environments, enabling automated application deployment and configuration management for the entire Solidity Security Platform.

## Technical Requirements

### Core GitOps Components
- **ArgoCD Server**: Web UI, API server, and application management
- **ArgoCD Controller**: Application reconciliation and sync management
- **ArgoCD Repo Server**: Git repository management and manifest generation
- **ArgoCD Redis**: Caching and session management
- **GitHub Integration**: Repository access and webhook configuration

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

### Kustomize Structure Implementation
```yaml
argocd/
├── base/
│   ├── kustomization.yaml
│   ├── argocd-server.yaml
│   ├── argocd-application-controller.yaml
│   ├── argocd-repo-server.yaml
│   ├── argocd-redis.yaml
│   ├── argocd-dex-server.yaml
│   ├── rbac-config.yaml
│   └── argocd-config.yaml
└── overlays/
    ├── local/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── argocd-config-patch.yaml
    │   ├── local-projects.yaml
    │   ├── local-repositories.yaml
    │   └── service-patch.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── argocd-config-patch.yaml
    │   ├── staging-projects.yaml
    │   ├── staging-repositories.yaml
    │   ├── ingress.yaml
    │   ├── certificate.yaml
    │   └── rbac-patch.yaml
    └── production/
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── argocd-config-patch.yaml
        ├── production-projects.yaml
        ├── production-repositories.yaml
        ├── ingress.yaml
        ├── certificate.yaml
        ├── rbac-patch.yaml
        └── security-policies.yaml
```

### Environment-Specific Configuration

**Local Environment (argocd-local)**:
- Single-instance ArgoCD for development
- Local repository access without authentication
- Simplified RBAC configuration
- NodePort or port-forward access

**Staging Environment (argocd-staging)**:
- Production-like ArgoCD configuration
- GitHub integration with webhooks
- SSL-enabled ingress access
- Team-based RBAC policies

**Production Environment (argocd-production)**:
- Highly available ArgoCD deployment
- Secure GitHub integration
- Production SSL certificates
- Comprehensive audit logging and monitoring

## Deliverables

### ArgoCD Core Installation
1. **ArgoCD Server Deployment**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: argocd-server
     namespace: argocd-production
   spec:
     replicas: 2
     selector:
       matchLabels:
         app.kubernetes.io/name: argocd-server
     template:
       metadata:
         labels:
           app.kubernetes.io/name: argocd-server
       spec:
         containers:
         - name: argocd-server
           image: quay.io/argoproj/argocd:v2.8.0
           command:
           - argocd-server
           - --staticassets
           - /shared/app
           - --repo-server
           - argocd-repo-server:8081
           - --redis
           - argocd-redis:6379
           ports:
           - containerPort: 8080
           - containerPort: 8083
           resources:
             requests:
               cpu: 100m
               memory: 128Mi
             limits:
               cpu: 500m
               memory: 512Mi
   ```

2. **Application Controller**:
   - ArgoCD application controller for reconciliation
   - Resource limits and health monitoring
   - Metrics and observability configuration
   - High availability for production

3. **Repository Server**:
   - Git repository management and caching
   - Kustomize and Helm support
   - Manifest generation and validation
   - Repository access credentials

### GitHub Integration
1. **Repository Configuration**:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: argocd-repositories
     namespace: argocd-staging
   data:
     repositories: |
       - url: https://github.com/your-org/solidity-security-api-service
         name: api-service
         type: git
       - url: https://github.com/your-org/solidity-security-tool-integration
         name: tool-integration
         type: git
       - url: https://github.com/your-org/solidity-security-intelligence-engine
         name: intelligence-engine
         type: git
       # Additional repositories...
   ```

2. **Webhook Configuration**:
   - GitHub webhook for automatic sync triggers
   - Webhook authentication and security
   - Repository event filtering
   - Error handling and retry logic

### ArgoCD Project Structure
1. **Infrastructure Project**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: AppProject
   metadata:
     name: infrastructure
     namespace: argocd-staging
   spec:
     description: Infrastructure components
     sourceRepos:
     - 'https://github.com/your-org/solidity-security-aws-infrastructure'
     - 'https://github.com/your-org/solidity-security-monitoring'
     destinations:
     - namespace: 'istio-system'
       server: https://kubernetes.default.svc
     - namespace: 'cert-manager'
       server: https://kubernetes.default.svc
     - namespace: 'external-secrets-*'
       server: https://kubernetes.default.svc
     - namespace: 'monitoring-*'
       server: https://kubernetes.default.svc
     clusterResourceWhitelist:
     - group: '*'
       kind: '*'
     roles:
     - name: infrastructure-admin
       policies:
       - p, proj:infrastructure:infrastructure-admin, applications, *, infrastructure/*, allow
       groups:
       - infrastructure-team
   ```

2. **Backend Services Project**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: AppProject
   metadata:
     name: backend-services
     namespace: argocd-staging
   spec:
     description: Backend microservices
     sourceRepos:
     - 'https://github.com/your-org/solidity-security-api-service'
     - 'https://github.com/your-org/solidity-security-tool-integration'
     - 'https://github.com/your-org/solidity-security-intelligence-engine'
     - 'https://github.com/your-org/solidity-security-orchestration'
     - 'https://github.com/your-org/solidity-security-data-service'
     - 'https://github.com/your-org/solidity-security-notification'
     - 'https://github.com/your-org/solidity-security-contract-parser'
     destinations:
     - namespace: 'api-service'
       server: https://kubernetes.default.svc
     - namespace: 'tool-integration'
       server: https://kubernetes.default.svc
     - namespace: 'intelligence-engine'
       server: https://kubernetes.default.svc
     - namespace: 'orchestration'
       server: https://kubernetes.default.svc
     - namespace: 'data-service'
       server: https://kubernetes.default.svc
     - namespace: 'notification'
       server: https://kubernetes.default.svc
     - namespace: 'contract-parser'
       server: https://kubernetes.default.svc
     namespaceResourceWhitelist:
     - group: 'apps'
       kind: Deployment
     - group: 'v1'
       kind: Service
     - group: 'v1'
       kind: ConfigMap
     - group: 'v1'
       kind: Secret
     roles:
     - name: backend-developer
       policies:
       - p, proj:backend-services:backend-developer, applications, *, backend-services/*, allow
       groups:
       - backend-team
   ```

3. **Frontend Services Project**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: AppProject
   metadata:
     name: frontend-services
     namespace: argocd-staging
   spec:
     description: Frontend applications
     sourceRepos:
     - 'https://github.com/your-org/solidity-security-ui-core'
     - 'https://github.com/your-org/solidity-security-dashboard'
     - 'https://github.com/your-org/solidity-security-findings'
     - 'https://github.com/your-org/solidity-security-analysis'
     destinations:
     - namespace: 'ui-core'
       server: https://kubernetes.default.svc
     - namespace: 'dashboard'
       server: https://kubernetes.default.svc
     - namespace: 'findings'
       server: https://kubernetes.default.svc
     - namespace: 'analysis'
       server: https://kubernetes.default.svc
     namespaceResourceWhitelist:
     - group: 'apps'
       kind: Deployment
     - group: 'v1'
       kind: Service
     - group: 'v1'
       kind: ConfigMap
     - group: 'networking.k8s.io'
       kind: Ingress
     roles:
     - name: frontend-developer
       policies:
       - p, proj:frontend-services:frontend-developer, applications, *, frontend-services/*, allow
       groups:
       - frontend-team
   ```

### RBAC and Authentication
1. **RBAC Configuration**:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: argocd-rbac-cm
     namespace: argocd-staging
   data:
     policy.default: role:readonly
     policy.csv: |
       p, role:admin, applications, *, *, allow
       p, role:admin, clusters, *, *, allow
       p, role:admin, repositories, *, *, allow

       p, role:developer, applications, get, */*, allow
       p, role:developer, applications, sync, */*, allow
       p, role:developer, logs, get, */*, allow

       g, infrastructure-team, role:admin
       g, backend-team, role:developer
       g, frontend-team, role:developer
   ```

2. **Authentication Integration**:
   - GitHub OAuth integration
   - Token-based authentication
   - Session management and security
   - Audit logging for user actions

## Implementation Steps

### Phase 1: ArgoCD Installation (2.5 hours)
1. Create Kustomize base manifests for ArgoCD components
2. Configure environment-specific overlays
3. Deploy ArgoCD to all environments
4. Verify ArgoCD component health and functionality
5. Configure initial admin access and authentication

### Phase 2: Repository and Project Setup (2 hours)
1. Configure GitHub repository connections
2. Create ArgoCD projects for infrastructure, backend, and frontend
3. Set up RBAC policies and team access
4. Configure webhook integration for automatic sync
5. Test repository connectivity and project access

### Phase 3: SSL and Ingress Configuration (1.5 hours)
1. Configure SSL certificates via cert-manager
2. Set up ingress resources for ArgoCD access
3. Configure DNS routing for ArgoCD dashboards
4. Test secure access and authentication
5. Validate SSL certificate functionality

## Success Criteria & Validation

### ArgoCD Installation Requirements
- [ ] ArgoCD deployed successfully in argocd-local, argocd-staging, argocd-production namespaces
- [ ] All ArgoCD components operational (server, controller, repo-server, redis)
- [ ] ArgoCD UI accessible via configured domains
- [ ] Component health checks passing consistently
- [ ] Resource utilization within expected ranges

### GitHub Integration Requirements
- [ ] All 17 repositories connected to ArgoCD successfully
- [ ] Repository authentication and access working
- [ ] Webhook integration functional for automatic sync
- [ ] Git repository caching and manifest generation working
- [ ] Repository status and health monitoring operational

### Project and RBAC Requirements
- [ ] ArgoCD projects created for infrastructure, backend, and frontend
- [ ] RBAC policies enforcing appropriate access controls
- [ ] Team-based authentication and authorization working
- [ ] Project-specific resource permissions configured
- [ ] Audit logging capturing all user actions

### SSL and Access Requirements
- [ ] ArgoCD dashboards accessible via HTTPS
- [ ] SSL certificates automatically provisioned and renewed
- [ ] DNS resolution working for all ArgoCD domains
- [ ] Authentication flow functional end-to-end
- [ ] Ingress routing and load balancing operational

## Testing & Validation

### Functional Testing
1. **ArgoCD Component Health**:
   ```bash
   kubectl get pods -n argocd-staging
   kubectl get services -n argocd-staging
   kubectl logs -n argocd-staging deployment/argocd-server
   kubectl logs -n argocd-staging deployment/argocd-application-controller
   ```

2. **Repository Connectivity**:
   ```bash
   argocd repo list
   argocd repo get https://github.com/your-org/solidity-security-api-service
   kubectl get configmap argocd-repositories -n argocd-staging -o yaml
   ```

3. **Project and RBAC**:
   ```bash
   argocd proj list
   argocd proj get infrastructure
   argocd account list
   kubectl get configmap argocd-rbac-cm -n argocd-staging -o yaml
   ```

### Access and Authentication Testing
1. **Web UI Access**:
   ```bash
   # Test ArgoCD UI access
   curl -I https://argocd.staging.advancedblockchainsecurity.com

   # Test authentication flow
   argocd login argocd.staging.advancedblockchainsecurity.com
   argocd context
   ```

2. **SSL Certificate Validation**:
   ```bash
   openssl s_client -connect argocd.staging.advancedblockchainsecurity.com:443
   kubectl get certificate argocd-tls -n argocd-staging
   ```

## Integration Requirements

### Dependencies
- **From Task 2.3**: cert-manager for SSL certificates
- **From Task 2.4**: Ingress controllers for external access
- **From Task 2.5**: External Secrets for repository credentials

### Integration Points
- **Task 2.8**: Application of Apps pattern implementation
- **Task 2.9**: Backend service ArgoCD applications
- **Task 2.10**: Frontend service ArgoCD applications

### Post-Task Validation
- **GitOps Ready**: Complete GitOps workflow operational
- **Repository Management**: All repositories accessible and manageable
- **Team Access**: Role-based access control functional
- **SSL Security**: Secure access to ArgoCD dashboards

## Configuration Examples

### ArgoCD Server Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-config
  namespace: argocd-staging
data:
  url: https://argocd.staging.advancedblockchainsecurity.com
  application.instanceLabelKey: argocd.argoproj.io/instance
  server.rbac.log.enforce.enable: "true"
  exec.enabled: "true"
  admin.enabled: "true"
  timeout.reconciliation: 180s
  timeout.hard.reconciliation: 0s
  oidc.config: |
    name: GitHub
    issuer: https://github.com
    clientId: $github-oauth:clientId
    clientSecret: $github-oauth:clientSecret
```

### Repository Secret
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-repo-secret
  namespace: argocd-staging
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/your-org/solidity-security-api-service
  password: $github-token
  username: git
```

## Troubleshooting Guide

### Common Issues
1. **ArgoCD Component Startup Failures**:
   - Check resource allocation and limits
   - Verify persistent volume availability
   - Review RBAC permissions and service accounts
   - Check network policies and security groups

2. **Repository Connection Problems**:
   - Verify GitHub token permissions and expiration
   - Check repository URL and accessibility
   - Review network connectivity and firewalls
   - Validate SSH key or token authentication

3. **RBAC and Access Issues**:
   - Review RBAC policy configuration
   - Check user group membership and mapping
   - Verify authentication provider configuration
   - Monitor audit logs for access attempts

### Monitoring and Debugging
1. **ArgoCD Logs**:
   ```bash
   kubectl logs -n argocd-staging deployment/argocd-server -f
   kubectl logs -n argocd-staging deployment/argocd-application-controller -f
   kubectl logs -n argocd-staging deployment/argocd-repo-server -f
   ```

2. **Application Status**:
   ```bash
   argocd app list
   argocd app get <app-name>
   argocd app logs <app-name>
   argocd app diff <app-name>
   ```

## Risk Assessment

### High Risk Items
- **Repository Access**: GitHub token security and access control
- **RBAC Configuration**: Proper access control and permission management
- **Certificate Management**: SSL certificate provisioning and renewal

### Medium Risk Items
- **Resource Usage**: ArgoCD resource consumption and scaling
- **Webhook Security**: GitHub webhook authentication and validation
- **Backup and Recovery**: ArgoCD configuration and application backup

### Mitigation Strategies
- **Token Rotation**: Regular GitHub token rotation and monitoring
- **Access Monitoring**: Comprehensive audit logging and alerting
- **Configuration Backup**: Regular backup of ArgoCD configuration
- **Disaster Recovery**: Documented recovery procedures

This task establishes the core GitOps infrastructure that will enable automated deployment and management of all platform services across all environments.