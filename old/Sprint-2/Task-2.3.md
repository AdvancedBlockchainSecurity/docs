# Task 2.3: cert-manager Deployment and Configuration

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 5 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Day**: 3-4

## Objective

Deploy and configure cert-manager for automatic SSL certificate provisioning with Let's Encrypt and Cloudflare DNS validation for staging and production environments, and self-signed certificates for local development.

## Technical Requirements

### Core Certificate Management Components
- **cert-manager**: Kubernetes-native certificate management
- **ClusterIssuer**: Let's Encrypt and self-signed certificate issuers
- **DNS-01 Challenge**: Cloudflare integration for domain validation
- **Certificate Resources**: Automatic certificate provisioning for all services
- **Renewal Automation**: Automatic certificate renewal before expiration

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

### Kustomize Structure Implementation
```yaml
cert-manager/
├── base/
│   ├── kustomization.yaml
│   ├── cert-manager-deployment.yaml
│   ├── cluster-issuer-template.yaml
│   ├── certificate-template.yaml
│   └── webhook-configuration.yaml
└── overlays/
    ├── local/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── self-signed-issuer.yaml
    │   ├── local-certificates.yaml
    │   └── ca-certificate.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── letsencrypt-staging-issuer.yaml
    │   ├── cloudflare-secret.yaml
    │   ├── staging-certificates.yaml
    │   └── dns-challenge-config.yaml
    └── production/
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── letsencrypt-prod-issuer.yaml
        ├── cloudflare-secret.yaml
        ├── production-certificates.yaml
        ├── dns-challenge-config.yaml
        └── security-policies.yaml
```

### Environment-Specific Certificate Strategy

**Local Environment (cert-manager-local)**:
- Self-signed root CA for development
- Wildcard certificates for *.local domains
- Fast certificate generation for testing
- No external dependencies

**Staging Environment (cert-manager-staging)**:
- Let's Encrypt staging environment
- Real domain validation with Cloudflare DNS
- Production-like certificate workflows
- Certificate transparency logging

**Production Environment (cert-manager-production)**:
- Let's Encrypt production environment
- Cloudflare DNS validation for security
- Optimized certificate renewal timing
- Enhanced monitoring and alerting

## Deliverables

### cert-manager Core Installation
1. **cert-manager Deployment**:
   - cert-manager controller, webhook, and cainjector
   - Custom Resource Definitions (CRDs) for certificates
   - RBAC permissions for cluster-wide certificate management
   - Resource limits and health checks

2. **Webhook Configuration**:
   - Admission webhook for certificate validation
   - Webhook TLS configuration and certificates
   - Failure policy and timeout configuration
   - Webhook health monitoring

### Certificate Issuers Configuration
1. **Self-Signed Issuer (Local)**:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: selfsigned-issuer
   spec:
     selfSigned: {}
   ```

2. **Let's Encrypt Staging Issuer**:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-staging
   spec:
     acme:
       server: https://acme-staging-v02.api.letsencrypt.org/directory
       email: admin@advancedblockchainsecurity.com
       privateKeySecretRef:
         name: letsencrypt-staging
       solvers:
       - dns01:
           cloudflare:
             email: admin@advancedblockchainsecurity.com
             apiTokenSecretRef:
               name: cloudflare-api-token
               key: api-token
   ```

3. **Let's Encrypt Production Issuer**:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: admin@advancedblockchainsecurity.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - dns01:
           cloudflare:
             email: admin@advancedblockchainsecurity.com
             apiTokenSecretRef:
               name: cloudflare-api-token
               key: api-token
   ```

### Certificate Resources for Services
1. **Wildcard Certificate for Each Environment**:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: wildcard-cert
     namespace: istio-system
   spec:
     secretName: wildcard-tls
     issuerRef:
       name: letsencrypt-prod
       kind: ClusterIssuer
     dnsNames:
     - "advancedblockchainsecurity.com"
     - "*.advancedblockchainsecurity.com"
     - "*.staging.advancedblockchainsecurity.com"
   ```

2. **Service-Specific Certificates**:
   - API service SSL certificate
   - Dashboard SSL certificate
   - ArgoCD SSL certificate
   - Grafana SSL certificate
   - Kiali SSL certificate

### Cloudflare DNS Integration
1. **API Token Configuration**:
   - Cloudflare API token with DNS edit permissions
   - Secure storage via External Secrets integration
   - Token rotation and management procedures
   - DNS zone access validation

2. **DNS Challenge Configuration**:
   - DNS-01 challenge solver configuration
   - Cloudflare provider settings
   - Challenge timeout and retry policies
   - DNS propagation validation

## Implementation Steps

### Phase 1: cert-manager Installation (2 hours)
1. Create Kustomize base manifests for cert-manager
2. Configure environment-specific overlays
3. Deploy cert-manager to all environments
4. Verify cert-manager controller and webhook functionality
5. Validate CRD installation and RBAC permissions

### Phase 2: Certificate Issuers Setup (2 hours)
1. Configure self-signed issuer for local environment
2. Set up Let's Encrypt staging issuer with Cloudflare DNS
3. Configure Let's Encrypt production issuer
4. Create Cloudflare API token secret via External Secrets
5. Test issuer functionality with sample certificates

### Phase 3: Service Certificates (1 hour)
1. Create wildcard certificates for each environment
2. Configure service-specific certificates
3. Set up automatic renewal monitoring
4. Test certificate provisioning and validation
5. Configure ingress integration for SSL termination

## Success Criteria & Validation

### cert-manager Installation Requirements
- [ ] cert-manager deployed successfully in cert-manager-local, cert-manager-staging, cert-manager-production namespaces
- [ ] cert-manager controller, webhook, and cainjector operational
- [ ] CRDs installed and admission webhooks functional
- [ ] RBAC permissions configured correctly
- [ ] Resource limits and health checks passing

### Certificate Issuer Requirements
- [ ] Self-signed issuer operational for local development
- [ ] Let's Encrypt staging issuer configured with Cloudflare DNS
- [ ] Let's Encrypt production issuer ready for SSL certificates
- [ ] Cloudflare API integration working correctly
- [ ] DNS-01 challenges completing successfully

### Certificate Provisioning Requirements
- [ ] Wildcard certificates provisioned for all environments
- [ ] Service-specific certificates available for ingress
- [ ] Certificate renewal automation configured
- [ ] Certificate secrets properly formatted for ingress controllers
- [ ] Certificate status monitoring and alerting functional

### Integration Requirements
- [ ] External Secrets integration for Cloudflare API tokens
- [ ] Istio Gateway SSL certificate integration
- [ ] ArgoCD dashboard SSL configuration
- [ ] Monitoring dashboard SSL access
- [ ] All service ingress routes using valid SSL certificates

## Testing & Validation

### Functional Testing
1. **cert-manager Health Check**:
   ```bash
   kubectl get pods -n cert-manager
   kubectl get clusterissuers
   kubectl describe clusterissuer letsencrypt-prod
   ```

2. **Certificate Provisioning**:
   ```bash
   kubectl get certificates -A
   kubectl describe certificate wildcard-cert -n istio-system
   kubectl get certificaterequests -A
   ```

3. **DNS Challenge Validation**:
   ```bash
   kubectl logs -n cert-manager deployment/cert-manager -f
   kubectl get challenges -A
   kubectl describe challenge <challenge-name>
   ```

### SSL/TLS Testing
1. **Certificate Validation**:
   ```bash
   openssl s_client -connect staging.advancedblockchainsecurity.com:443
   curl -I https://argocd.staging.advancedblockchainsecurity.com
   ```

2. **Certificate Renewal Testing**:
   ```bash
   kubectl annotate certificate wildcard-cert cert-manager.io/force-renewal=true
   kubectl get certificaterequests -w
   ```

## Integration Requirements

### Dependencies
- **From Task 1.1**: Domain registration and Cloudflare DNS management
- **From Task 2.1**: Istio Gateway for SSL termination
- **From Task 2.5**: External Secrets for Cloudflare API tokens

### Integration Points
- **Task 2.4**: Load balancer SSL termination configuration (NGINX for local, ALB for staging/production)
- **Task 2.7**: ArgoCD SSL certificate configuration
- **Task 2.6**: Monitoring dashboard SSL access

### Post-Task Validation
- **SSL Ready**: All services can use automatically provisioned SSL certificates
- **Domain Security**: HTTPS enabled for all public-facing services
- **Certificate Automation**: No manual certificate management required
- **Renewal Monitoring**: Certificate expiration monitoring and alerting operational

## Configuration Examples

### Cloudflare API Token Secret
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
spec:
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: cloudflare-api-token
    creationPolicy: Owner
  data:
  - secretKey: api-token
    remoteRef:
      key: cloudflare
      property: api-token
```

### Certificate Template
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: service-cert
  namespace: app-namespace
spec:
  secretName: service-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - service.advancedblockchainsecurity.com
  renewBefore: 720h # 30 days
```

### Ingress SSL Configuration
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: service-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - service.advancedblockchainsecurity.com
    secretName: service-tls
  rules:
  - host: service.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service
            port:
              number: 80
```

## Troubleshooting Guide

### Common Issues
1. **Certificate Provisioning Failures**:
   - Check ClusterIssuer status and configuration
   - Verify Cloudflare API token permissions
   - Review DNS challenge logs and timing
   - Validate domain ownership and DNS configuration

2. **DNS Challenge Problems**:
   - Verify Cloudflare API connectivity
   - Check DNS propagation timing
   - Review challenge timeout settings
   - Validate DNS zone permissions

3. **Certificate Renewal Issues**:
   - Monitor certificate expiration dates
   - Check renewal trigger timing
   - Review renewal challenge execution
   - Validate renewed certificate deployment

### Monitoring and Debugging
1. **cert-manager Logs**:
   ```bash
   kubectl logs -n cert-manager deployment/cert-manager -f
   kubectl logs -n cert-manager deployment/cert-manager-webhook -f
   kubectl logs -n cert-manager deployment/cert-manager-cainjector -f
   ```

2. **Certificate Status**:
   ```bash
   kubectl get certificates -A -o wide
   kubectl describe certificate <name> -n <namespace>
   kubectl get events --field-selector involvedObject.kind=Certificate
   ```

3. **Challenge Debugging**:
   ```bash
   kubectl get challenges -A
   kubectl describe challenge <challenge-name>
   kubectl get orders -A
   ```

## Risk Assessment

### High Risk Items
- **Cloudflare API Dependency**: External service dependency for certificate validation
- **Let's Encrypt Rate Limits**: Production certificate request limits
- **DNS Challenge Timing**: DNS propagation delays affecting certificate issuance

### Medium Risk Items
- **Certificate Renewal**: Automated renewal process reliability
- **API Token Security**: Secure management of Cloudflare API credentials
- **Webhook Availability**: cert-manager webhook impact on cluster operations

### Mitigation Strategies
- **Backup Issuers**: Multiple certificate issuer options
- **Rate Limit Monitoring**: Tracking Let's Encrypt usage and limits
- **Manual Procedures**: Emergency manual certificate procedures
- **Token Rotation**: Regular API token rotation and monitoring

This task establishes automated SSL certificate management for the entire platform, ensuring all services can be accessed securely via HTTPS with automatically managed certificates.