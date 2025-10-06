# Task 2.5: External Secrets Operator Deployment

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 6 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Day**: 5-6

## Objective

Deploy External Secrets Operator to enable seamless integration between HashiCorp Vault and Kubernetes secrets, providing automated secret synchronization and rotation across all environments.

## Technical Requirements

### Core Secret Management Components
- **External Secrets Operator**: Kubernetes-native secret synchronization
- **SecretStore Resources**: HashiCorp Vault integration configuration
- **ExternalSecret Resources**: Service-specific secret management
- **Kubernetes Authentication**: Vault authentication via service accounts
- **Secret Rotation**: Automated secret refresh and synchronization

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

### Kustomize Structure Implementation
```yaml
external-secrets/
├── base/
│   ├── kustomization.yaml
│   ├── external-secrets-operator.yaml
│   ├── secret-store-template.yaml
│   ├── external-secret-template.yaml
│   ├── rbac.yaml
│   └── webhook-config.yaml
└── overlays/
    ├── local/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── vault-local-secret-store.yaml
    │   ├── vault-auth-config.yaml
    │   └── service-secrets/
    │       ├── api-service-secret.yaml
    │       ├── data-service-secret.yaml
    │       ├── tool-integration-secret.yaml
    │       ├── intelligence-engine-secret.yaml
    │       ├── orchestration-secret.yaml
    │       ├── notification-secret.yaml
    │       └── contract-parser-secret.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── vault-staging-secret-store.yaml
    │   ├── vault-auth-config.yaml
    │   └── service-secrets/
    └── production/
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── vault-production-secret-store.yaml
        ├── vault-auth-config.yaml
        ├── security-policies.yaml
        └── service-secrets/
```

### Environment-Specific Secret Organization

**Local Environment (external-secrets-local)**:
- Development secrets with relaxed security
- Local Vault instance integration
- Fast refresh intervals for testing
- Service account authentication

**Staging Environment (external-secrets-staging)**:
- Production-like secret management
- Staging Vault namespace integration
- Regular refresh intervals
- Enhanced authentication and RBAC

**Production Environment (external-secrets-production)**:
- Security-optimized secret management
- Production Vault namespace integration
- Optimized refresh intervals
- Full audit logging and monitoring

## Deliverables

### External Secrets Operator Installation
1. **Operator Deployment**:
   - External Secrets Operator controller and webhook
   - Custom Resource Definitions for secret management
   - RBAC permissions for cluster-wide secret access
   - Resource limits and health monitoring

2. **Webhook Configuration**:
   - Admission webhook for secret validation
   - Webhook TLS configuration and certificates
   - Validation rules and policies
   - Error handling and retry logic

### HashiCorp Vault Integration
1. **SecretStore Configuration**:
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: SecretStore
   metadata:
     name: vault-backend
     namespace: external-secrets-staging
   spec:
     provider:
       vault:
         server: "https://vault.staging.advancedblockchainsecurity.com"
         path: "secret"
         version: "v2"
         auth:
           kubernetes:
             mountPath: "kubernetes"
             role: "external-secrets"
             serviceAccountRef:
               name: "external-secrets-sa"
   ```

2. **Kubernetes Authentication Setup**:
   - Service account for External Secrets authentication
   - Vault Kubernetes auth method configuration
   - Role-based access control in Vault
   - Token review and validation setup

### Service-Specific Secret Management
1. **API Service Secrets**:
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: api-service-secrets
     namespace: api-service
   spec:
     refreshInterval: 300s
     secretStoreRef:
       name: vault-backend
       kind: SecretStore
     target:
       name: api-service-secrets
       creationPolicy: Owner
     data:
     - secretKey: jwt-signing-key
       remoteRef:
         key: api-service/auth
         property: jwt-signing-key
     - secretKey: database-url
       remoteRef:
         key: api-service/database
         property: url
     - secretKey: redis-url
       remoteRef:
         key: api-service/cache
         property: redis-url
   ```

2. **Tool Integration Secrets**:
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: tool-integration-secrets
     namespace: tool-integration
   spec:
     refreshInterval: 600s
     secretStoreRef:
       name: vault-backend
       kind: SecretStore
     target:
       name: tool-integration-secrets
       creationPolicy: Owner
     data:
     - secretKey: mythx-api-key
       remoteRef:
         key: tool-integration/mythx
         property: api-key
     - secretKey: github-token
       remoteRef:
         key: tool-integration/github
         property: token
   ```

### Vault Secret Organization Structure
```yaml
HashiCorp Vault Secret Paths:
staging/
├── api-service/
│   ├── auth/
│   │   ├── jwt-signing-key
│   │   ├── oauth-client-id
│   │   └── oauth-client-secret
│   ├── database/
│   │   ├── url
│   │   ├── username
│   │   └── password
│   └── cache/
│       ├── redis-url
│       └── redis-password
├── tool-integration/
│   ├── mythx/
│   │   ├── api-key
│   │   └── webhook-secret
│   ├── github/
│   │   ├── token
│   │   └── webhook-secret
│   └── tools/
│       ├── slither-config
│       └── aderyn-config
├── data-service/
│   ├── postgres/
│   │   ├── url
│   │   ├── username
│   │   └── password
│   ├── redis/
│   │   ├── url
│   │   └── password
│   └── encryption/
│       ├── master-key
│       └── signing-key
├── intelligence-engine/
│   ├── algorithms/
│   │   ├── model-configs
│   │   └── pattern-weights
│   └── ml/
│       ├── api-keys
│       └── model-secrets
├── orchestration/
│   ├── celery/
│   │   ├── broker-url
│   │   └── result-backend
│   └── workers/
│       ├── credentials
│       └── queue-config
├── notification/
│   ├── smtp/
│   │   ├── host
│   │   ├── username
│   │   └── password
│   ├── slack/
│   │   ├── webhook-url
│   │   └── bot-token
│   └── teams/
│       ├── webhook-url
│       └── tenant-id
└── contract-parser/
    ├── storage/
    │   ├── s3-access-key
    │   └── s3-secret-key
    └── cache/
        ├── redis-url
        └── redis-password

production/ (same structure)
```

## Implementation Steps

### Phase 1: External Secrets Operator Installation (2 hours)
1. Create Kustomize base manifests for External Secrets Operator
2. Configure environment-specific overlays
3. Deploy operator to all environments
4. Verify operator functionality and webhook configuration
5. Test basic secret synchronization

### Phase 2: Vault Integration Setup (2.5 hours)
1. Configure Kubernetes authentication in HashiCorp Vault
2. Create service accounts and RBAC for External Secrets
3. Set up SecretStore resources for each environment
4. Configure Vault policies for secret access
5. Test Vault authentication and secret retrieval

### Phase 3: Service Secret Configuration (1.5 hours)
1. Create ExternalSecret resources for all 7 backend services
2. Configure secret refresh intervals and policies
3. Set up secret templates and transformations
4. Test secret synchronization for all services
5. Validate secret format and accessibility

## Success Criteria & Validation

### External Secrets Operator Requirements
- [ ] External Secrets Operator deployed in external-secrets-local, external-secrets-staging, external-secrets-production namespaces
- [ ] Operator controller and webhook operational
- [ ] CRDs installed and admission webhook functional
- [ ] RBAC permissions configured correctly
- [ ] Resource monitoring and health checks passing

### Vault Integration Requirements
- [ ] SecretStore resources connecting to HashiCorp Vault successfully
- [ ] Kubernetes authentication working for all environments
- [ ] Service account permissions configured properly
- [ ] Vault policies providing appropriate secret access
- [ ] Connection stability and retry logic functional

### Secret Synchronization Requirements
- [ ] ExternalSecret resources syncing secrets automatically
- [ ] Kubernetes secrets created and formatted correctly
- [ ] Secret refresh intervals working as configured
- [ ] Secret rotation and updates propagating properly
- [ ] Error handling and retry mechanisms operational

### Service Integration Requirements
- [ ] All 7 backend services receiving required secrets
- [ ] Secret format compatible with application requirements
- [ ] Service authentication using synchronized secrets
- [ ] Database and cache connections using Vault secrets
- [ ] External API integrations using managed credentials

## Testing & Validation

### Functional Testing
1. **Operator Health Check**:
   ```bash
   kubectl get pods -n external-secrets-system
   kubectl logs -n external-secrets-system deployment/external-secrets
   kubectl get secretstores -A
   kubectl get externalsecrets -A
   ```

2. **Secret Synchronization**:
   ```bash
   kubectl get secrets -n api-service | grep api-service-secrets
   kubectl describe externalsecret api-service-secrets -n api-service
   kubectl get events --field-selector involvedObject.kind=ExternalSecret
   ```

3. **Vault Integration**:
   ```bash
   kubectl logs -n external-secrets-system deployment/external-secrets -f
   vault auth list
   vault policy list
   ```

### Secret Content Validation
1. **Secret Format Verification**:
   ```bash
   kubectl get secret api-service-secrets -n api-service -o yaml
   kubectl get secret api-service-secrets -n api-service -o jsonpath='{.data.jwt-signing-key}' | base64 -d
   ```

2. **Refresh Testing**:
   ```bash
   # Update secret in Vault
   vault kv put secret/api-service/auth jwt-signing-key="new-key"
   # Wait for refresh interval
   kubectl get secret api-service-secrets -n api-service -o yaml
   ```

## Integration Requirements

### Dependencies
- **From Task 1.4**: HashiCorp Vault Community Edition operational
- **From Task 2.1**: Istio service mesh for secure communication
- **From Task 1.5**: EKS clusters with proper RBAC

### Integration Points
- **Task 2.9**: Backend service secret consumption
- **Task 2.3**: cert-manager Cloudflare API token management
- **Task 2.7**: ArgoCD authentication credentials

### Post-Task Validation
- **Secret Automation**: All services using automatically managed secrets
- **Vault Integration**: Complete integration with HashiCorp Vault
- **Security Compliance**: Secrets properly encrypted and access controlled
- **Operational Readiness**: Secret rotation and monitoring operational

## Configuration Examples

### Service Account for External Secrets
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: external-secrets-staging
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "external-secrets"
```

### Vault Kubernetes Auth Configuration
```bash
# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create role for External Secrets
vault write auth/kubernetes/role/external-secrets \
    bound_service_account_names=external-secrets-sa \
    bound_service_account_namespaces=external-secrets-staging \
    policies=external-secrets-policy \
    ttl=24h
```

### Vault Policy for External Secrets
```hcl
path "secret/data/api-service/*" {
  capabilities = ["read"]
}

path "secret/data/tool-integration/*" {
  capabilities = ["read"]
}

path "secret/data/data-service/*" {
  capabilities = ["read"]
}

# Additional paths for other services...
```

## Troubleshooting Guide

### Common Issues
1. **Authentication Failures**:
   - Verify service account configuration and RBAC
   - Check Vault Kubernetes auth method setup
   - Review token reviewer JWT and CA certificate
   - Validate role binding and policy assignment

2. **Secret Synchronization Problems**:
   - Check ExternalSecret resource status and events
   - Verify Vault secret paths and permissions
   - Review refresh interval and retry configuration
   - Monitor operator logs for error messages

3. **Connection Issues**:
   - Verify network connectivity to Vault
   - Check TLS certificate validation
   - Review security group and firewall rules
   - Validate Vault server accessibility

### Monitoring and Debugging
1. **Operator Logs**:
   ```bash
   kubectl logs -n external-secrets-system deployment/external-secrets -f
   kubectl logs -n external-secrets-system deployment/external-secrets-webhook -f
   ```

2. **Secret Status**:
   ```bash
   kubectl describe externalsecret <name> -n <namespace>
   kubectl get externalsecrets -A -o wide
   kubectl get events --field-selector involvedObject.kind=ExternalSecret
   ```

3. **Vault Debugging**:
   ```bash
   vault auth -method=kubernetes role=external-secrets jwt=$SA_JWT
   vault read secret/data/api-service/auth
   vault audit list
   ```

## Risk Assessment

### High Risk Items
- **Vault Connectivity**: Network connectivity and authentication reliability
- **Secret Exposure**: Risk of secret exposure during synchronization
- **Authentication Token**: Service account token security and rotation

### Medium Risk Items
- **Refresh Timing**: Secret refresh frequency and application restart requirements
- **Vault Policies**: Proper access control and principle of least privilege
- **Error Handling**: Graceful degradation when secrets are unavailable

### Mitigation Strategies
- **Backup Authentication**: Multiple authentication methods for redundancy
- **Secret Validation**: Comprehensive secret format and content validation
- **Monitoring and Alerting**: Real-time monitoring of secret synchronization
- **Emergency Procedures**: Manual secret injection procedures for outages

This task establishes secure and automated secret management for the entire platform, eliminating manual secret handling and enabling secure service authentication with HashiCorp Vault integration.