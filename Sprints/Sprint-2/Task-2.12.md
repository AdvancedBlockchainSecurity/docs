# Task 2.12: ArgoCD Application Definitions and GitOps Workflow

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 4 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Day**: 11-12

## Objective

Create comprehensive ArgoCD application definitions for all infrastructure components and services, establish complete GitOps workflow with health monitoring, and validate end-to-end automated deployment pipeline.

## Technical Requirements

### ArgoCD Application Architecture
- **Infrastructure Applications**: Istio, cert-manager, External Secrets, Monitoring
- **Backend Service Applications**: 7 microservices with individual GitOps management
- **Frontend Service Applications**: 4 React applications with deployment automation
- **Health Monitoring**: Application health checks and dependency validation
- **Deployment Strategies**: Blue-green, rolling updates, and canary deployments

### Application Definition Structure
```yaml
ArgoCD Applications (18 total):
├── Infrastructure Applications (4):
│   ├── istio-system
│   ├── cert-manager
│   ├── external-secrets
│   └── monitoring-stack
├── Backend Service Applications (7):
│   ├── api-service
│   ├── tool-integration
│   ├── intelligence-engine
│   ├── orchestration
│   ├── data-service
│   ├── notification
│   └── contract-parser
└── Frontend Service Applications (4):
    ├── ui-core
    ├── dashboard
    ├── findings
    └── analysis
```

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Infrastructure Application Definitions
1. **Istio System Application**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: istio-system
     namespace: argocd-staging
     finalizers:
     - resources-finalizer.argocd.argoproj.io
   spec:
     project: infrastructure
     source:
       repoURL: https://github.com/your-org/solidity-security-aws-infrastructure
       targetRevision: main
       path: k8s/istio/overlays/staging
     destination:
       server: https://kubernetes.default.svc
       namespace: istio-system
     syncPolicy:
       automated:
         prune: false  # Safety for critical infrastructure
         selfHeal: true
       syncOptions:
       - CreateNamespace=true
       - ApplyOutOfSyncOnly=true
       retry:
         limit: 3
         backoff:
           duration: 5s
           factor: 2
           maxDuration: 3m
     revisionHistoryLimit: 10
   ```

2. **cert-manager Application**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: cert-manager
     namespace: argocd-staging
     finalizers:
     - resources-finalizer.argocd.argoproj.io
   spec:
     project: infrastructure
     source:
       repoURL: https://github.com/your-org/solidity-security-aws-infrastructure
       targetRevision: main
       path: k8s/cert-manager/overlays/staging
     destination:
       server: https://kubernetes.default.svc
       namespace: cert-manager
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
       - CreateNamespace=true
       retry:
         limit: 5
         backoff:
           duration: 5s
           factor: 2
           maxDuration: 3m
     revisionHistoryLimit: 10
   ```

3. **External Secrets Application**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: external-secrets
     namespace: argocd-staging
     finalizers:
     - resources-finalizer.argocd.argoproj.io
   spec:
     project: infrastructure
     source:
       repoURL: https://github.com/your-org/solidity-security-aws-infrastructure
       targetRevision: main
       path: k8s/external-secrets/overlays/staging
     destination:
       server: https://kubernetes.default.svc
       namespace: external-secrets-staging
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
       - CreateNamespace=true
       retry:
         limit: 5
         backoff:
           duration: 5s
           factor: 2
           maxDuration: 3m
     revisionHistoryLimit: 10
   ```

4. **Monitoring Stack Application**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: monitoring-stack
     namespace: argocd-staging
     finalizers:
     - resources-finalizer.argocd.argoproj.io
   spec:
     project: infrastructure
     source:
       repoURL: https://github.com/your-org/solidity-security-monitoring
       targetRevision: main
       path: k8s/monitoring/overlays/staging
     destination:
       server: https://kubernetes.default.svc
       namespace: monitoring-staging
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
       - CreateNamespace=true
       retry:
         limit: 5
         backoff:
           duration: 5s
           factor: 2
           maxDuration: 3m
     revisionHistoryLimit: 10
   ```

### Backend Service Application Definitions
1. **API Service Application**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: api-service
     namespace: argocd-staging
     finalizers:
     - resources-finalizer.argocd.argoproj.io
   spec:
     project: backend-services
     source:
       repoURL: https://github.com/your-org/solidity-security-api-service
       targetRevision: main
       path: k8s/overlays/staging
     destination:
       server: https://kubernetes.default.svc
       namespace: api-service
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
       - CreateNamespace=true
       retry:
         limit: 3
         backoff:
           duration: 5s
           factor: 2
           maxDuration: 3m
     revisionHistoryLimit: 10
     ignoreDifferences:
     - group: apps
       kind: Deployment
       jsonPointers:
       - /spec/replicas  # Ignore HPA-managed replica count
   ```

2. **Tool Integration Application**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: tool-integration
     namespace: argocd-staging
     finalizers:
     - resources-finalizer.argocd.argoproj.io
   spec:
     project: backend-services
     source:
       repoURL: https://github.com/your-org/solidity-security-tool-integration
       targetRevision: main
       path: k8s/overlays/staging
     destination:
       server: https://kubernetes.default.svc
       namespace: tool-integration
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
       - CreateNamespace=true
       - RespectIgnoreDifferences=true
       retry:
         limit: 3
         backoff:
           duration: 5s
           factor: 2
           maxDuration: 3m
     revisionHistoryLimit: 10
     ignoreDifferences:
     - group: apps
       kind: Deployment
       jsonPointers:
       - /spec/replicas
   ```

### Frontend Service Application Definitions
1. **Dashboard Application**:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: dashboard
     namespace: argocd-staging
     finalizers:
     - resources-finalizer.argocd.argoproj.io
   spec:
     project: frontend-services
     source:
       repoURL: https://github.com/your-org/solidity-security-dashboard
       targetRevision: main
       path: k8s/overlays/staging
     destination:
       server: https://kubernetes.default.svc
       namespace: dashboard
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
       - CreateNamespace=true
       retry:
         limit: 3
         backoff:
           duration: 5s
           factor: 2
           maxDuration: 3m
     revisionHistoryLimit: 10
     ignoreDifferences:
     - group: apps
       kind: Deployment
       jsonPointers:
       - /spec/replicas
   ```

### Health Check Configuration
1. **Application Health Checks**:
   ```yaml
   # Custom health check for API service
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: api-service-health-check
     namespace: argocd-staging
     labels:
       app.kubernetes.io/part-of: argocd
   data:
     health.lua: |
       health_status = {}
       if obj.status ~= nil then
         if obj.status.readyReplicas ~= nil and obj.status.replicas ~= nil then
           if obj.status.readyReplicas >= math.ceil(obj.status.replicas * 0.5) then
             health_status.status = "Healthy"
             health_status.message = "Service is healthy with " .. obj.status.readyReplicas .. " ready replicas"
           else
             health_status.status = "Degraded"
             health_status.message = "Service is degraded with only " .. obj.status.readyReplicas .. " ready replicas"
           end
         else
           health_status.status = "Progressing"
           health_status.message = "Service is starting up"
         end
       else
         health_status.status = "Unknown"
         health_status.message = "Service status unknown"
       end
       return health_status
   ```

2. **Database Connectivity Health Check**:
   ```yaml
   # External database health check
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: database-health-check
     namespace: argocd-staging
     labels:
       app.kubernetes.io/part-of: argocd
   data:
     health.lua: |
       health_status = {}
       if obj.status ~= nil and obj.status.conditions ~= nil then
         for i, condition in ipairs(obj.status.conditions) do
           if condition.type == "Ready" then
             if condition.status == "True" then
               health_status.status = "Healthy"
               health_status.message = "Database connection is healthy"
             else
               health_status.status = "Degraded"
               health_status.message = "Database connection issues: " .. condition.message
             end
             break
           end
         end
       else
         health_status.status = "Unknown"
         health_status.message = "Database status unknown"
       end
       return health_status
   ```

### Git Webhook Configuration
1. **Webhook Integration Setup**:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: argocd-cmd-params-cm
     namespace: argocd-staging
   data:
     server.insecure: "false"
     server.webhook.github.secret: "webhook-secret"
     application.namespaces: "argocd-staging"
     controller.status.processors: "20"
     controller.operation.processors: "10"
     reposerver.parallelism.limit: "10"
   ```

2. **Repository Credential Templates**:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: github-repo-credentials
     namespace: argocd-staging
     labels:
       argocd.argoproj.io/secret-type: repository
   stringData:
     type: git
     url: https://github.com/your-org
     password: $github-token
     username: git
   ```

### Deployment Status Monitoring
1. **Application Status Dashboard**:
   ```yaml
   # Grafana dashboard for ArgoCD applications
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: argocd-applications-dashboard
     namespace: monitoring-staging
   data:
     argocd-applications.json: |
       {
         "dashboard": {
           "title": "ArgoCD Applications Status",
           "panels": [
             {
               "title": "Application Health Status",
               "type": "stat",
               "targets": [
                 {
                   "expr": "argocd_app_health_status",
                   "legendFormat": "{{name}} - {{health_status}}"
                 }
               ]
             },
             {
               "title": "Sync Status",
               "type": "stat",
               "targets": [
                 {
                   "expr": "argocd_app_sync_total",
                   "legendFormat": "{{name}} - {{sync_status}}"
                 }
               ]
             },
             {
               "title": "Application Sync History",
               "type": "graph",
               "targets": [
                 {
                   "expr": "rate(argocd_app_sync_total[5m])",
                   "legendFormat": "{{name}}"
                 }
               ]
             }
           ]
         }
       }
   ```

2. **AlertManager Rules**:
   ```yaml
   apiVersion: monitoring.coreos.com/v1
   kind: PrometheusRule
   metadata:
     name: argocd-application-alerts
     namespace: monitoring-staging
   spec:
     groups:
     - name: argocd.applications
       rules:
       - alert: ArgoCDApplicationSyncFailed
         expr: argocd_app_sync_total{sync_status="Failed"} > 0
         for: 5m
         labels:
           severity: warning
         annotations:
           summary: "ArgoCD application sync failed"
           description: "Application {{ $labels.name }} sync failed in project {{ $labels.project }}"

       - alert: ArgoCDApplicationUnhealthy
         expr: argocd_app_health_status{health_status!="Healthy"} > 0
         for: 10m
         labels:
           severity: critical
         annotations:
           summary: "ArgoCD application is unhealthy"
           description: "Application {{ $labels.name }} is in {{ $labels.health_status }} state"

       - alert: ArgoCDApplicationOutOfSync
         expr: argocd_app_sync_total{sync_status="OutOfSync"} > 0
         for: 15m
         labels:
           severity: warning
         annotations:
           summary: "ArgoCD application is out of sync"
           description: "Application {{ $labels.name }} has been out of sync for more than 15 minutes"
   ```

## Implementation Steps

### Phase 1: Infrastructure Application Setup (1.5 hours)
1. Create ArgoCD application definitions for all infrastructure components
2. Configure appropriate sync policies and health checks
3. Set up dependency ordering and deployment strategies
4. Deploy infrastructure applications and validate status
5. Test infrastructure application sync and health monitoring

### Phase 2: Service Application Configuration (2 hours)
1. Create ArgoCD applications for all 7 backend services
2. Configure ArgoCD applications for all 4 frontend services
3. Set up appropriate sync policies and retry mechanisms
4. Configure health checks and dependency validation
5. Test service application deployment and management

### Phase 3: Monitoring and Alerting Integration (30 minutes)
1. Set up ArgoCD metrics integration with Prometheus
2. Create Grafana dashboards for application status monitoring
3. Configure AlertManager rules for deployment failures
4. Set up notification channels for deployment events
5. Test end-to-end monitoring and alerting workflow

## Success Criteria & Validation

### Application Definition Requirements
- [ ] All 18 applications defined with proper ArgoCD configurations
- [ ] Infrastructure applications with appropriate sync policies
- [ ] Service applications with automated deployment configured
- [ ] Health checks accurately reflecting application status
- [ ] Dependency relationships properly configured

### GitOps Workflow Requirements
- [ ] Git commits triggering automatic application sync
- [ ] Sync policies working correctly for each application type
- [ ] Self-healing restoring desired state automatically
- [ ] Rollback capabilities functional for failed deployments
- [ ] Application status accurately reflected in ArgoCD UI

### Health Monitoring Requirements
- [ ] Application health checks providing accurate status
- [ ] Dependency validation working for complex applications
- [ ] Custom health checks for database and external dependencies
- [ ] Health status propagating to monitoring systems
- [ ] Unhealthy applications triggering appropriate alerts

### Integration Requirements
- [ ] ArgoCD integrated with monitoring stack
- [ ] Application status visible in Grafana dashboards
- [ ] Deployment events generating appropriate notifications
- [ ] Failed deployments triggering alert escalation
- [ ] Application metrics available for analysis

## Testing & Validation

### Application Deployment Testing
1. **Infrastructure Application Testing**:
   ```bash
   # Test infrastructure application sync
   argocd app sync istio-system
   argocd app wait istio-system --health --timeout 600

   argocd app sync cert-manager
   argocd app wait cert-manager --health --timeout 300

   # Verify infrastructure dependencies
   kubectl get pods -n istio-system
   kubectl get certificates -A
   ```

2. **Service Application Testing**:
   ```bash
   # Test backend service deployment
   argocd app sync api-service
   argocd app wait api-service --health --timeout 300

   # Test frontend service deployment
   argocd app sync dashboard
   argocd app wait dashboard --health --timeout 180

   # Verify service connectivity
   kubectl exec deployment/dashboard -n dashboard -- \
     curl http://api-service.api-service:8000/health
   ```

### GitOps Workflow Testing
1. **Automated Sync Testing**:
   ```bash
   # Make configuration change
   git commit -m "Update API service configuration" --allow-empty
   git push origin main

   # Monitor automatic sync
   argocd app wait api-service --sync --timeout 300
   argocd app get api-service
   ```

2. **Health Check Validation**:
   ```bash
   # Check application health status
   argocd app list --output wide

   # Test custom health checks
   kubectl scale deployment api-service --replicas=0 -n api-service
   argocd app get api-service  # Should show degraded health

   kubectl scale deployment api-service --replicas=2 -n api-service
   argocd app wait api-service --health --timeout 300
   ```

### Rollback Testing
1. **Failed Deployment Simulation**:
   ```bash
   # Deploy invalid configuration
   kubectl patch deployment api-service -n api-service \
     --patch '{"spec":{"template":{"spec":{"containers":[{"name":"api-service","image":"invalid:tag"}]}}}}'

   # Monitor ArgoCD response
   argocd app get api-service

   # Test manual rollback
   argocd app rollback api-service --revision 1
   argocd app wait api-service --health --timeout 300
   ```

## Integration Requirements

### Dependencies
- **From Task 2.7**: ArgoCD installed and operational
- **From Task 2.8**: Application of Apps pattern implemented
- **From Task 2.9**: Backend service Kustomize templates ready

### Integration Points
- **Task 2.13**: Platform integration testing
- **Task 2.6**: Monitoring stack integration
- **Task 2.11**: Service communication validation

### Post-Task Validation
- **Complete GitOps**: All services managed through GitOps workflow
- **Operational Excellence**: Automated deployment and health monitoring
- **Team Productivity**: Streamlined deployment and management processes
- **Platform Reliability**: Self-healing and automated recovery capabilities

## Troubleshooting Guide

### Common Issues
1. **Application Sync Failures**:
   - Check repository connectivity and authentication
   - Verify Kustomize manifest validity and syntax
   - Review RBAC permissions for ArgoCD service account
   - Check for resource conflicts and dependencies

2. **Health Check Issues**:
   - Verify application endpoints and connectivity
   - Check custom health check logic and configuration
   - Review resource readiness and startup timing
   - Monitor application logs for health endpoint errors

3. **Deployment Dependencies**:
   - Review application deployment order and timing
   - Check namespace creation and resource availability
   - Verify secret and configmap dependencies
   - Monitor inter-service communication requirements

### Monitoring and Debugging
1. **ArgoCD Application Status**:
   ```bash
   argocd app list --output wide
   argocd app get <app-name> --show-managed-fields
   argocd app logs <app-name> --follow
   argocd app diff <app-name>
   ```

2. **Kubernetes Resource Status**:
   ```bash
   kubectl get applications -n argocd-staging
   kubectl describe application <app-name> -n argocd-staging
   kubectl get events -n <target-namespace> --sort-by='.firstTimestamp'
   ```

## Risk Assessment

### High Risk Items
- **Application Dependencies**: Complex dependency relationships between applications
- **Health Check Accuracy**: Ensuring health checks accurately reflect application state
- **Deployment Timing**: Managing deployment order and resource availability

### Medium Risk Items
- **Sync Policy Configuration**: Balancing automation with safety requirements
- **Resource Management**: Managing resource conflicts and quotas
- **Performance Impact**: ArgoCD performance with large number of applications

### Mitigation Strategies
- **Gradual Rollout**: Phased deployment of applications with dependency validation
- **Comprehensive Testing**: Extensive testing of deployment scenarios and failure recovery
- **Monitoring and Alerting**: Real-time monitoring of application health and deployment status
- **Emergency Procedures**: Manual override and emergency deployment procedures

This task completes the GitOps foundation by establishing comprehensive application management, health monitoring, and automated deployment capabilities for the entire platform.