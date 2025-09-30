# Task 1.4: Vault Setup - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing all cloud infrastructure configurations. This task focuses on deploying HashiCorp Vault Community Edition using standardized Kustomize structure with proper StatefulSet configuration for secure credential management.

**✅ ALIGNMENT CHECK**: This implementation establishes secure credential management for all platform services using HashiCorp Vault Community Edition with External Secrets Operator integration as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Deploy and configure HashiCorp Vault Community Edition for secure credential storage with manual unsealing and native Kubernetes integration via External Secrets Operator using ClusterSecretStore for cross-namespace access in vault-staging and vault-production namespaces.

### Key Requirements (from docs)
- **Vault Deployment**: Deploy Community Edition for staging and production environments in vault-staging and vault-production namespaces
- **RBAC Configuration**: Vault policies and Kubernetes service accounts for secure secret access via External Secrets Operator
- **Cross-Namespace Integration**: ClusterSecretStore configuration for external-secrets-operator service account from external-secrets-system namespace
- **Manual Management**: Manual secret management with Vault Community Edition (no enterprise auto-rotation)
- **Organization Structure**: Hierarchical secret organization using Vault's KV secrets engine

## Directory Structure Requirements

Following the standard Kustomize structure template for StatefulSet services:

```
solidity-security-aws-infrastructure/
└── k8s/
    ├── base/
    │   └── vault/
    │       ├── kustomization.yaml     # Base Vault configuration
    │       ├── statefulset.yaml       # Vault StatefulSet deployment
    │       ├── service.yaml            # Vault service (headless for StatefulSet)
    │       ├── configmap.yaml          # Vault configuration
    │       ├── pvc.yaml                # Persistent volume claims for Vault data
    │       ├── secret.yaml             # Vault initialization secrets
    │       ├── serviceaccount.yaml     # Vault service account
    │       ├── namespace.yaml          # Vault namespace template
    │       └── rbac.yaml               # Vault RBAC (ClusterRole, ClusterRoleBinding)
    │
    └── overlays/
        ├── staging/
        │   └── vault/
        │       ├── kustomization.yaml     # Staging Vault configuration
        │       ├── namespace.yaml          # vault-staging namespace
        │       ├── statefulset-patch.yaml # Staging-specific StatefulSet patches
        │       ├── configmap-patch.yaml   # Staging Vault configuration
        │       ├── pvc-patch.yaml          # Staging storage requirements
        │       ├── serviceaccount-patch.yaml # Staging RBAC configuration
        │       └── externalsecret.yaml     # ClusterSecretStore for External Secrets Operator integration
        │
        └── production/
            └── vault/
                ├── kustomization.yaml         # Production Vault configuration
                ├── namespace.yaml              # vault-production namespace
                ├── statefulset-patch.yaml     # Production-specific StatefulSet patches
                ├── configmap-patch.yaml       # Production Vault configuration
                ├── pvc-patch.yaml              # Production storage requirements
                ├── serviceaccount-patch.yaml  # Production RBAC configuration
                ├── pdb.yaml                    # PodDisruptionBudget for HA
                ├── backup-cronjob.yaml         # Vault file storage backup automation
                ├── externalsecret.yaml         # ClusterSecretStore and External Secrets Operator integration
                └── vault-policy.yaml          # Vault access policies and External Secrets Operator authentication
```

## Service Categories & Dependencies

### Backend Services (7 services)
- `api-service` (JWT secrets, OAuth credentials, database credentials)
- `tool-integration` (MythX API keys, tool credentials, third-party APIs)
- `data-service` (Database URLs, Redis credentials, encryption keys)
- `orchestration` (Celery broker, worker credentials, queue credentials)
- `intelligence-engine` (Algorithm configs, rule weights, pattern configs)
- `notification` (SMTP credentials, webhook URLs, template configs)
- `contract-parser` (API keys, service credentials)

### Frontend Services (4 services)
- `ui-core` (API endpoints, configuration)
- `dashboard` (WebSocket credentials, API keys)
- `findings` (Database connections, API credentials)
- `analysis` (Service endpoints, authentication tokens)

## Step 1: Vault Base Configuration (1.5 hours)

### Objectives
- Create Kustomize base manifests for HashiCorp Vault Community Edition StatefulSet
- Configure Vault RBAC with ClusterRole and service accounts for Kubernetes integration
- Set up persistent storage and StatefulSet configuration for high availability

### Key Components to Implement
- **Base StatefulSet**: Vault Community Edition StatefulSet with persistent storage
- **Service Configuration**: Headless service for StatefulSet pod communication
- **RBAC Setup**: ClusterRole, ClusterRoleBinding, and ServiceAccount for Vault
- **Base Configuration**: Vault configuration file with KV v2 secrets engine

### Technical Requirements
- StatefulSet with persistent volume claims for Vault data storage
- Headless service configuration for StatefulSet pod discovery
- Kubernetes authentication method configuration for External Secrets Operator
- Base security context and resource limits configuration

### Performance Goals
- High availability configuration with multiple replicas for production
- Persistent storage for Vault data with appropriate storage class

## Step 2: Environment Overlays and Configuration (1 hour)

### Objectives
- Create staging and production Kustomize overlays with environment-specific configurations
- Configure namespace patches for vault-staging and vault-production namespaces
- Set up environment-specific StatefulSet and PVC patches

### Key Components to Implement
- **Staging Overlay**: Single replica Vault with smaller storage for development
- **Production Overlay**: Multi-replica Vault with PodDisruptionBudget and backup automation
- **Environment Patches**: Resource limits, storage sizes, and replica counts
- **External Secrets Integration**: ClusterSecretStore configuration for cross-namespace secret access

### Integration Strategy
- Kustomize overlays following standardized directory structure
- Environment-specific namespace creation and configuration
- Production-grade file storage backup and recovery procedures via CronJob
- External Secrets Operator integration via ClusterSecretStore for cross-namespace secret retrieval

## Step 3: Deployment and Integration Testing (30 minutes)

### Objectives
- Deploy Vault using Kustomize overlays to staging and production environments
- Validate External Secrets Operator integration and secret retrieval via ClusterSecretStore
- Test Vault initialization and unsealing procedures

### Core Dependencies
- **Kustomize Deployment**: Deploy via `kubectl apply -k overlays/staging/vault/`
- **Vault Initialization**: Manual Vault initialization and unsealing process
- **Integration Testing**: External Secrets Operator connectivity via ClusterSecretStore from external-secrets-system namespace

### Integration Requirements
- Validate StatefulSet deployment and persistent storage mounting
- Test Kubernetes authentication method configuration
- Verify External Secrets Operator can authenticate and retrieve secrets via ClusterSecretStore
- Confirm proper RBAC permissions for external-secrets-operator service account from external-secrets-system namespace
- Configure Vault policies to allow cross-namespace authentication (handled in vault-policy.yaml setup scripts)

## Success Criteria & Validation

### Kustomize Base Configuration Requirements
- [ ] Base Vault StatefulSet manifest created with persistent storage
- [ ] Base Vault service configured as headless service for StatefulSet
- [ ] Base Vault ConfigMap created with KV v2 secrets engine configuration
- [ ] Vault RBAC configured with ClusterRole and ServiceAccount
- [ ] Base namespace template created with placeholder for environment overlay

### Environment Overlay Requirements
- [ ] Staging overlay created with vault-staging namespace
- [ ] Production overlay created with vault-production namespace
- [ ] StatefulSet patches configured for environment-specific resource limits
- [ ] PVC patches configured for appropriate storage sizes per environment
- [ ] Production PodDisruptionBudget configured for high availability

### Deployment and Integration Requirements
- [ ] Vault deployed successfully in vault-staging namespace via Kustomize
- [ ] Vault deployed successfully in vault-production namespace via Kustomize
- [ ] Vault StatefulSet pods running and persistent storage mounted
- [ ] Vault initialization and unsealing completed manually
- [ ] External Secrets Operator integration tested and functional
- [ ] Kubernetes authentication method configured for External Secrets Operator via ClusterSecretStore

## Implementation Priority

### Phase 1: Base Configuration (1.5 hours)
1. Create Kustomize base manifests for Vault StatefulSet in `k8s/base/vault/`
2. Configure Vault RBAC with ClusterRole, ClusterRoleBinding, and ServiceAccount
3. Set up base ConfigMap with Vault configuration and KV v2 secrets engine
4. Create base StatefulSet with persistent volume claims and security context

### Phase 2: Environment Overlays (1 hour)
1. Create staging overlay in `k8s/overlays/staging/vault/` with single replica configuration
2. Create production overlay in `k8s/overlays/production/vault/` with HA configuration
3. Configure environment-specific patches for resources, storage, and namespaces
4. Set up ClusterSecretStore manifests for External Secrets Operator integration

### Phase 3: Deployment and Testing (30 minutes)
1. Deploy Vault to staging environment via `kubectl apply -k overlays/staging/vault/`
2. Deploy Vault to production environment via `kubectl apply -k overlays/production/vault/`
3. Initialize and unseal Vault manually for both environments
4. Test External Secrets Operator integration via ClusterSecretStore and validate cross-namespace secret retrieval

## Key Implementation Notes

1. **Kustomize Structure**: Follow standardized Kustomize template with base and overlay directories
2. **StatefulSet Configuration**: Use StatefulSet for Vault with persistent storage for data durability
3. **Environment Separation**: Use separate namespaces (vault-staging, vault-production) for isolation
4. **RBAC Security**: Implement least-privilege ClusterRole for Vault Kubernetes integration
5. **Cross-Namespace Authentication**: Configure Vault policies for external-secrets-operator service account from external-secrets-system namespace (handled in vault-policy.yaml setup scripts)
6. **Production Hardening**: Include PodDisruptionBudget and file storage backup CronJob for production environment

---

**Estimated Time**: 3 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist
- [ ] Task 1.4 started
- [ ] Kustomize base manifests created in `k8s/base/vault/`
- [ ] Base StatefulSet configured with persistent storage and security context
- [ ] Base headless service created for StatefulSet pod communication
- [ ] Base ConfigMap created with Vault configuration and KV v2 engine
- [ ] Vault RBAC configured with ClusterRole and ServiceAccount
- [ ] Base namespace template created with environment placeholder
- [ ] Staging overlay created in `k8s/overlays/staging/vault/`
- [ ] Production overlay created in `k8s/overlays/production/vault/`
- [ ] Environment-specific namespace patches configured
- [ ] StatefulSet patches configured for resource limits and replica counts
- [ ] PVC patches configured for appropriate storage sizes
- [ ] Production PodDisruptionBudget and backup CronJob configured
- [ ] ClusterSecretStore manifests created for External Secrets Operator integration
- [ ] Vault deployed to vault-staging namespace via Kustomize
- [ ] Vault deployed to vault-production namespace via Kustomize
- [ ] Vault StatefulSet pods running with persistent storage mounted
- [ ] Vault initialization and unsealing completed for both environments
- [ ] Kubernetes authentication method configured for External Secrets Operator via ClusterSecretStore
- [ ] Vault policies configured for external-secrets-operator service account from external-secrets-system namespace
- [ ] External Secrets Operator integration tested and functional via ClusterSecretStore
- [ ] Cross-namespace secret retrieval validated
- [ ] Task 1.4 completed with Vault operational via standardized Kustomize structure