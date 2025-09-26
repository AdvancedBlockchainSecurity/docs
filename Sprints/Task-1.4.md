# Task 1.4: AWS Secrets Manager Setup - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing all cloud infrastructure configurations. This task focuses on the security module providing AWS Secrets Manager infrastructure with IAM policies and rotation capabilities for secure credential management.

**✅ ALIGNMENT CHECK**: This implementation establishes secure credential management for all platform services using AWS Secrets Manager with External Secrets Operator integration as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Deploy and configure AWS Secrets Manager for secure credential storage with automatic rotation and Kubernetes integration via External Secrets Operator.

### Key Requirements (from docs)
- **Secrets Manager**: Deploy for staging and production environments
- **IAM Configuration**: Roles and policies for secure secret access
- **Automatic Rotation**: Rotation policies for database credentials
- **Organization Structure**: Hierarchical secret organization for all services

## Directory Structure Requirements

```
solidity-security-aws-infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── security/              # Security and secrets management
│   │   │   ├── secrets_manager.tf # Secrets Manager configuration
│   │   │   ├── iam_roles.tf       # IAM roles and policies
│   │   │   ├── rotation_policies.tf # Automatic rotation
│   │   │   ├── kms_keys.tf        # KMS encryption keys
│   │   │   ├── variables.tf       # Module variables
│   │   │   └── outputs.tf         # Module outputs
│   │   └── monitoring/
│   │       └── secrets_monitoring.tf # Secrets access monitoring
│   ├── environments/
│   │   ├── staging/               # Staging secrets config
│   │   └── production/            # Production secrets config
│   └── shared/                    # Shared security components
├── k8s/
│   └── external-secrets/          # External Secrets Operator configs
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

## Step 1: Secrets Manager Infrastructure (1.5 hours)

### Objectives
- Deploy AWS Secrets Manager for staging and production environments
- Configure IAM roles and policies for least-privilege secret access
- Set up secret organization structure for all services

### Key Components to Implement
- **Secrets Manager**: Service deployment in both environments
- **IAM Policies**: Least-privilege access for services and External Secrets Operator
- **Secret Organization**: Hierarchical structure for service categorization

### Technical Requirements
- Environment-specific secret isolation (staging/production)
- Service-specific IAM roles for secret access
- Secret naming convention for easy management
- Encryption at rest using AWS KMS

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
- Secret organization supporting External Secrets Operator
- Environment-specific secret namespacing
- Service-specific secret access patterns

## Step 3: Automatic Rotation and Monitoring (30 minutes)

### Objectives
- Configure automatic rotation policies for database credentials
- Set up secret access monitoring and alerting
- Validate secret retrieval from Kubernetes services

### Core Dependencies
- **Rotation Policies**: Database credential automatic rotation
- **Access Monitoring**: CloudTrail logging for secret access
- **Integration Testing**: External Secrets Operator connectivity

### Integration Requirements
- Rotation policies compatible with PostgreSQL and ElastiCache
- Secret access logging for security monitoring
- Testing framework for secret retrieval validation

## Success Criteria & Validation

### Secrets Manager Infrastructure Requirements
- [ ] AWS Secrets Manager operational in staging environment
- [ ] AWS Secrets Manager operational in production environment
- [ ] IAM roles configured with least-privilege secret access
- [ ] Secret organization structure implemented per specification
- [ ] KMS encryption configured for all secrets

### Secret Organization Requirements
- [ ] Backend service secrets organized by service category
- [ ] Frontend service secrets properly structured
- [ ] Database credentials stored with automatic rotation capability
- [ ] Redis credentials stored with appropriate access controls
- [ ] Tool integration secrets (MythX, etc.) properly organized

### Integration and Security Requirements
- [ ] External Secrets Operator IAM integration configured
- [ ] Secret rotation policies configured for database credentials
- [ ] CloudTrail logging enabled for secret access monitoring
- [ ] Secret retrieval tested from Kubernetes environment
- [ ] Access controls validated for service-specific secret access

## Implementation Priority

### Phase 1: Core Infrastructure (1.5 hours)
1. Deploy AWS Secrets Manager in staging and production environments
2. Configure IAM roles and policies for External Secrets Operator integration
3. Set up KMS encryption and secret organization hierarchy

### Phase 2: Secret Organization (1 hour)
1. Create service-specific secret categories and initial secrets
2. Deploy database and Redis credentials with rotation configuration
3. Set up tool integration secrets (API keys, third-party credentials)

### Phase 3: Monitoring and Validation (30 minutes)
1. Configure automatic rotation policies for database credentials
2. Enable CloudTrail logging for secret access monitoring
3. Test secret retrieval integration with External Secrets Operator

## Key Implementation Notes

1. **Secret Naming**: Use consistent naming convention: `{environment}/{service}/{secret-type}`
2. **Access Control**: Implement least-privilege IAM policies for each service
3. **Rotation**: Configure automatic rotation for database credentials to enhance security
4. **Monitoring**: Enable comprehensive logging for secret access and rotation events

---

**Estimated Time**: 3 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist
- [ ] Task 1.4 started
- [ ] AWS Secrets Manager deployed in staging environment
- [ ] AWS Secrets Manager deployed in production environment
- [ ] IAM roles and policies configured for External Secrets Operator
- [ ] Secret organization structure implemented
- [ ] KMS encryption configured for all secrets
- [ ] Backend service secrets created and organized
- [ ] Frontend service secrets created and organized
- [ ] Database credentials stored with rotation policies
- [ ] Redis credentials configured with access controls
- [ ] Tool integration secrets (MythX, APIs) stored securely
- [ ] Automatic rotation policies configured for database credentials
- [ ] CloudTrail logging enabled for secret access monitoring
- [ ] External Secrets Operator integration tested and validated
- [ ] Service-specific secret access controls validated
- [ ] Task 1.4 completed with full secret management operational