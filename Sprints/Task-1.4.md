# Task 1.4: Vault Setup - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing all cloud infrastructure configurations. This task focuses on the security module providing HashiCorp Vault infrastructure with Kubernetes integration and rotation capabilities for secure credential management.

**✅ ALIGNMENT CHECK**: This implementation establishes secure credential management for all platform services using HashiCorp Vault Community Edition with Vault Secrets Operator integration as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Deploy and configure HashiCorp Vault Community Edition for secure credential storage with manual unsealing and native Kubernetes integration via Vault Secrets Operator in vault-staging and vault-production namespaces.

### Key Requirements (from docs)
- **Vault Deployment**: Deploy Community Edition for staging and production environments in vault-staging and vault-production namespaces
- **RBAC Configuration**: Vault policies and Kubernetes service accounts for secure secret access
- **Manual Management**: Manual secret management with Vault Community Edition (no enterprise auto-rotation)
- **Organization Structure**: Hierarchical secret organization using Vault's KV secrets engine

## Directory Structure Requirements

```
solidity-security-monitoring/
├── vault/
│   ├── manifests/                 # Kubernetes manifests for Vault
│   │   ├── vault-namespace.yaml   # Vault namespace
│   │   ├── vault-statefulset.yaml # Vault StatefulSet configuration
│   │   ├── vault-service.yaml     # Vault service
│   │   ├── vault-configmap.yaml   # Vault configuration
│   │   ├── vault-rbac.yaml        # RBAC for Vault
│   │   └── vault-pvc.yaml         # Persistent volume claims
│   ├── policies/                  # Vault policies
│   │   ├── backend-services.hcl   # Backend service policies
│   │   ├── frontend-services.hcl  # Frontend service policies
│   │   └── admin.hcl              # Admin policies
│   ├── auth/                      # Authentication methods
│   │   └── kubernetes-auth.hcl    # Kubernetes auth configuration
│   └── secrets-engines/           # Secrets engine configurations
│       ├── kv-v2.hcl              # KV v2 secrets engine
│       └── database.hcl           # Database secrets engine
└── README.md
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

## Step 1: Vault Infrastructure (1.5 hours)

### Objectives
- Deploy HashiCorp Vault Community Edition StatefulSets in vault-staging and vault-production namespaces
- Configure Vault policies and Kubernetes RBAC for least-privilege secret access
- Set up secret organization structure using Vault's KV v2 secrets engine

### Key Components to Implement
- **Vault Deployment**: Community Edition StatefulSet deployment in vault-staging and vault-production namespaces
- **RBAC Policies**: Least-privilege access for services and Vault Secrets Operator
- **Secret Organization**: Hierarchical structure using Vault's KV v2 secrets engine

### Technical Requirements
- Environment-specific secret isolation using Vault namespaces
- Service-specific Kubernetes service accounts for secret access
- Secret naming convention using Vault's hierarchical paths
- Encryption at rest using Vault's built-in encryption

## Step 2: Secret Organization and Structure (1 hour)

### Objectives
- Create hierarchical secret organization structure
- Deploy initial secrets for database and cache services
- Configure secret templates for consistent organization

### Key Components to Implement
- **Service Categories**: Backend, frontend, and infrastructure secrets
- **Secret Templates**: Standardized secret structures
- **Initial Secrets**: Database credentials, Redis credentials, basic service keys

### Integration Strategy
- Secret organization supporting Vault Secrets Operator
- Environment-specific secret namespacing using Vault namespaces
- Service-specific secret access patterns using Vault policies

## Step 3: Automatic Rotation and Monitoring (30 minutes)

### Objectives
- Configure manual secret management for database credentials (Community Edition limitation)
- Set up secret access monitoring and alerting
- Validate secret retrieval from Kubernetes services

### Core Dependencies
- **Manual Rotation**: Database credential manual rotation using Vault Community Edition KV engine
- **Access Monitoring**: Vault audit logging for secret access
- **Integration Testing**: Vault Secrets Operator connectivity

### Integration Requirements
- Manual rotation procedures compatible with PostgreSQL using Vault Community Edition
- Secret access logging for security monitoring via Vault audit logs
- Testing framework for secret retrieval validation with Vault CLI

## Success Criteria & Validation

### Vault Infrastructure Requirements
- [ ] HashiCorp Vault Community Edition operational in vault-staging namespace
- [ ] HashiCorp Vault Community Edition operational in vault-production namespace
- [ ] Vault policies configured with least-privilege secret access
- [ ] Secret organization structure implemented using KV v2 secrets engine
- [ ] Vault encryption configured for all secrets

### Secret Organization Requirements
- [ ] Backend service secrets organized by service category
- [ ] Frontend service secrets properly structured
- [ ] Database credentials stored with automatic rotation capability
- [ ] Redis credentials stored with appropriate access controls
- [ ] Tool integration secrets (MythX, etc.) properly organized

### Integration and Security Requirements
- [ ] Vault Secrets Operator Kubernetes integration configured
- [ ] Manual secret rotation procedures documented for database credentials using Vault Community Edition
- [ ] Vault audit logging enabled for secret access monitoring
- [ ] Secret retrieval tested from Kubernetes environment using Vault CLI
- [ ] Access controls validated for service-specific secret access using Vault policies

## Implementation Priority

### Phase 1: Core Infrastructure (1.5 hours)
1. Deploy HashiCorp Vault Community Edition StatefulSets in vault-staging and vault-production namespaces
2. Configure Vault policies and Kubernetes RBAC for Vault Secrets Operator integration
3. Set up Vault encryption and secret organization hierarchy using KV v2 engine

### Phase 2: Secret Organization (1 hour)
1. Create service-specific secret categories and initial secrets using Vault KV v2
2. Deploy database credentials with manual rotation procedures using Vault Community Edition KV engine
3. Set up tool integration secrets (API keys, third-party credentials) in Vault

### Phase 3: Monitoring and Validation (30 minutes)
1. Configure manual rotation procedures for database credentials using Vault Community Edition
2. Enable Vault audit logging for secret access monitoring
3. Test secret retrieval integration with Vault Secrets Operator

## Key Implementation Notes

1. **Secret Naming**: Use consistent naming convention: `{environment}/{service}/{secret-type}` in Vault KV v2
2. **Access Control**: Implement least-privilege Vault policies for each service
3. **Manual Rotation**: Configure manual rotation procedures for database credentials using Vault Community Edition
4. **Monitoring**: Enable comprehensive Vault audit logging for secret access and manual rotation events

---

**Estimated Time**: 3 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist
- [ ] Task 1.4 started
- [ ] HashiCorp Vault Community Edition deployed in vault-staging namespace
- [ ] HashiCorp Vault Community Edition deployed in vault-production namespace
- [ ] Vault policies and Kubernetes RBAC configured for Vault Secrets Operator
- [ ] Secret organization structure implemented using KV v2 engine
- [ ] Vault encryption configured for all secrets
- [ ] Backend service secrets created and organized in Vault
- [ ] Frontend service secrets created and organized in Vault
- [ ] Database credentials stored with manual rotation procedures using Vault Community Edition KV engine
- [ ] Redis credentials configured with access controls in Vault
- [ ] Tool integration secrets (MythX, APIs) stored securely in Vault
- [ ] Manual rotation procedures configured for database credentials using Vault Community Edition
- [ ] Vault audit logging enabled for secret access monitoring
- [ ] Vault Secrets Operator integration tested and validated
- [ ] Service-specific secret access controls validated using Vault policies
- [ ] Task 1.4 completed with full Vault secret management operational