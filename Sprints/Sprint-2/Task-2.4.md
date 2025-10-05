# Task 2.4: Load Balancer Controller and Ingress

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 4 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Day**: 3-4

## Objective

Deploy NGINX Ingress Controller for local development and AWS Load Balancer Controller for staging/production environments with Application Load Balancer (ALB) integration, enabling proper SSL termination and traffic routing for each environment.

## Technical Requirements

### Core Ingress Components
- **AWS Load Balancer Controller**: Kubernetes-native ALB management for staging/production
- **NGINX Ingress Controller**: Local development ingress with SSL termination
- **IRSA Configuration**: IAM Roles for Service Accounts for secure AWS access
- **ALB Integration**: Application Load Balancer provisioning and management
- **SSL Termination**: Certificate integration with cert-manager

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`

### Kustomize Structure Implementation
```yaml
ingress-controllers/
├── aws-load-balancer-controller/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service-account.yaml
│   │   ├── rbac.yaml
│   │   ├── webhook.yaml
│   │   └── config.yaml
│   └── overlays/
│       ├── staging/
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── irsa-patch.yaml
│       │   ├── alb-ingress-class.yaml
│       │   └── controller-config-patch.yaml
│       └── production/
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           ├── irsa-patch.yaml
│           ├── alb-ingress-class.yaml
│           ├── controller-config-patch.yaml
│           └── security-policies.yaml
└── nginx-ingress/
    ├── base/
    │   ├── kustomization.yaml
    │   ├── nginx-deployment.yaml
    │   ├── nginx-service.yaml
    │   ├── nginx-configmap.yaml
    │   └── rbac.yaml
    └── overlays/
        └── local/
            ├── kustomization.yaml
            ├── namespace.yaml
            ├── local-config-patch.yaml
            ├── ssl-certificate.yaml
            └── service-patch.yaml
```

### Environment-Specific Ingress Strategy

**Local Environment (nginx)**:
- nginx ingress controller for simple HTTP/HTTPS routing
- Self-signed certificates from cert-manager
- NodePort or LoadBalancer service type
- Development-friendly configuration

**Staging Environment (AWS ALB)**:
- AWS Load Balancer Controller with ALB provisioning
- Let's Encrypt staging certificates
- SSL termination at load balancer level
- Health checks and target group management

**Production Environment (AWS ALB)**:
- Optimized AWS Load Balancer Controller configuration
- Production Let's Encrypt certificates
- Advanced ALB features (SSL policies, WAF integration)
- Enhanced security and monitoring

## Deliverables

### AWS Load Balancer Controller
1. **Controller Deployment**:
   - AWS Load Balancer Controller with IRSA configuration
   - Admission webhook for ALB resource validation
   - CRDs for ALB, TargetGroupBinding, and IngressClassParams
   - Resource limits and health monitoring

2. **IRSA Configuration**:
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: aws-load-balancer-controller
     namespace: kube-system
     annotations:
       eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/AmazonEKSLoadBalancerControllerRole
   ```

3. **ALB Ingress Class**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: IngressClass
   metadata:
     name: alb
     annotations:
       ingressclass.kubernetes.io/is-default-class: "true"
   spec:
     controller: ingress.k8s.aws/alb
     parameters:
       apiGroup: elbv2.k8s.aws
       kind: IngressClassParams
       name: alb-params
   ```

### nginx Ingress Controller (Local)
1. **nginx Deployment**:
   - nginx ingress controller for local development
   - ConfigMap for nginx configuration customization
   - SSL certificate integration with cert-manager
   - Service configuration for external access

2. **Local SSL Configuration**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: local-ingress
     annotations:
       kubernetes.io/ingress.class: nginx
       cert-manager.io/cluster-issuer: selfsigned-issuer
   spec:
     tls:
     - hosts:
       - "*.local.advancedblockchainsecurity.com"
       secretName: local-wildcard-tls
     rules:
     - host: api.local.advancedblockchainsecurity.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: api-service
               port:
                 number: 80
   ```

### ALB Integration and Configuration
1. **Application Load Balancer Features**:
   - SSL/TLS termination with cert-manager certificates
   - Target group health checks
   - Path-based and host-based routing
   - Integration with AWS WAF (production)

2. **ALB Ingress Annotations**:
   ```yaml
   metadata:
     annotations:
       kubernetes.io/ingress.class: alb
       alb.ingress.kubernetes.io/scheme: internet-facing
       alb.ingress.kubernetes.io/target-type: ip
       alb.ingress.kubernetes.io/ssl-redirect: '443'
       alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/cert-id
       alb.ingress.kubernetes.io/healthcheck-path: /health
       alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
       alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
       alb.ingress.kubernetes.io/healthy-threshold-count: '2'
       alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
   ```

### SSL Certificate Integration
1. **cert-manager Integration**:
   - Automatic certificate provisioning for ALB
   - Certificate ARN annotation for ALB ingress
   - Certificate renewal and ALB update automation
   - SSL policy configuration

2. **Health Check Configuration**:
   - Application health check endpoints
   - Target group health monitoring
   - Unhealthy target handling
   - Health check logging and alerting

## Implementation Steps

### Phase 1: AWS Load Balancer Controller (2.5 hours)
1. Create IRSA role and policy for AWS Load Balancer Controller
2. Deploy AWS Load Balancer Controller with Kustomize
3. Configure IngressClass and IngressClassParams
4. Verify controller functionality with test ingress
5. Test ALB provisioning and SSL termination

### Phase 2: nginx Ingress Controller (1 hour)
1. Create Kustomize manifests for nginx ingress
2. Configure nginx with SSL certificate integration
3. Deploy nginx controller to local environment
4. Test local ingress routing and SSL termination
5. Verify cert-manager integration

### Phase 3: Service Integration (30 minutes)
1. Create ingress resources for infrastructure services
2. Configure health checks and monitoring
3. Test end-to-end traffic routing
4. Validate SSL certificate functionality
5. Verify load balancer health and status

## Success Criteria & Validation

### AWS Load Balancer Controller Requirements
- [ ] AWS Load Balancer Controller deployed in staging and production
- [ ] IRSA configuration providing appropriate AWS permissions
- [ ] ALB provisioning and management working correctly
- [ ] SSL termination functional with cert-manager certificates
- [ ] Health checks and target group management operational

### nginx Ingress Controller Requirements
- [ ] nginx ingress controller operational in local environment
- [ ] SSL certificate integration with cert-manager working
- [ ] Local service routing and load balancing functional
- [ ] nginx configuration customizable via ConfigMap
- [ ] External access configured appropriately

### Traffic Routing Requirements
- [ ] All services accessible via configured ingress rules
- [ ] SSL/HTTPS redirection working correctly
- [ ] Health checks passing for all backend services
- [ ] Load balancing distributing traffic appropriately
- [ ] Ingress status and metrics available

### Integration Requirements
- [ ] cert-manager certificates integrated with ingress controllers
- [ ] DNS resolution working for all configured hosts
- [ ] Monitoring integration for ingress controller health
- [ ] External Secrets integration for sensitive configurations
- [ ] ArgoCD managing ingress resource deployments

## Testing & Validation

### Functional Testing
1. **AWS Load Balancer Controller**:
   ```bash
   kubectl get deployment -n kube-system aws-load-balancer-controller
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   kubectl get ingressclass alb
   ```

2. **ALB Provisioning**:
   ```bash
   kubectl apply -f test-ingress.yaml
   kubectl get ingress test-ingress
   kubectl describe ingress test-ingress
   # Verify ALB created in AWS console
   ```

3. **nginx Ingress**:
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl get service -n ingress-nginx
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   ```

### SSL/TLS Testing
1. **Certificate Validation**:
   ```bash
   curl -I https://api.staging.advancedblockchainsecurity.com
   openssl s_client -connect api.staging.advancedblockchainsecurity.com:443
   ```

2. **Health Check Testing**:
   ```bash
   # Check ALB target group health in AWS console
   kubectl get endpoints
   kubectl describe ingress <ingress-name>
   ```

## Integration Requirements

### Dependencies
- **From Task 1.5**: EKS clusters operational
- **From Task 2.3**: cert-manager for SSL certificates
- **From Task 1.2**: VPC and security group configuration

### Integration Points
- **Task 2.7**: ArgoCD ingress configuration
- **Task 2.6**: Monitoring dashboard ingress access
- **Task 2.9**: Backend service ingress resources

### Post-Task Validation
- **Ingress Ready**: All services can be exposed via ingress controllers
- **SSL Enabled**: HTTPS access configured for all public services
- **Load Balancing**: Traffic distribution and health monitoring operational
- **DNS Integration**: Domain routing functional for all environments

## Configuration Examples

### ALB Ingress for API Service
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-service-ingress
  namespace: api-service
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:123456789:certificate/cert-id
    alb.ingress.kubernetes.io/healthcheck-path: /health
spec:
  rules:
  - host: api.staging.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

### nginx ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  proxy-body-size: "100m"
  proxy-read-timeout: "300"
  proxy-send-timeout: "300"
  ssl-protocols: "TLSv1.2 TLSv1.3"
  ssl-ciphers: "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384"
```

## Troubleshooting Guide

### Common Issues
1. **ALB Provisioning Failures**:
   - Verify IRSA role permissions and trust policy
   - Check security group and subnet configurations
   - Review AWS Load Balancer Controller logs
   - Validate ingress annotations and configuration

2. **SSL Certificate Issues**:
   - Verify cert-manager certificate status
   - Check certificate ARN in ALB configuration
   - Review DNS validation and propagation
   - Monitor certificate renewal process

3. **Health Check Failures**:
   - Verify application health check endpoints
   - Check target group configuration
   - Review security group rules for health checks
   - Monitor application pod health and readiness

### Monitoring and Debugging
1. **Controller Logs**:
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller -f
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f
   ```

2. **Ingress Status**:
   ```bash
   kubectl get ingress -A
   kubectl describe ingress <name> -n <namespace>
   kubectl get events --field-selector involvedObject.kind=Ingress
   ```

3. **AWS Resources**:
   ```bash
   aws elbv2 describe-load-balancers
   aws elbv2 describe-target-groups
   aws elbv2 describe-target-health --target-group-arn <arn>
   ```

## Risk Assessment

### High Risk Items
- **AWS Service Dependencies**: ALB and target group management reliability
- **SSL Certificate Integration**: Automated certificate management complexity
- **IRSA Configuration**: Proper IAM role and permission setup

### Medium Risk Items
- **Health Check Configuration**: Proper application health monitoring
- **DNS Resolution**: Domain routing and propagation timing
- **Load Balancer Costs**: AWS ALB usage and associated costs

### Mitigation Strategies
- **Backup Ingress**: nginx as fallback for critical services
- **Manual Certificate Procedures**: Emergency SSL certificate procedures
- **Cost Monitoring**: ALB usage and cost tracking
- **Health Check Validation**: Comprehensive health check testing

This task establishes robust ingress capabilities for all environments, enabling secure and reliable external access to platform services with automatic SSL certificate management.