# Task 1.3: AWS Database and Cache Infrastructure - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing all cloud infrastructure configurations. This task focuses on the storage module providing PostgreSQL StatefulSets and ElastiCache Redis infrastructure for data persistence and caching.

**✅ ALIGNMENT CHECK**: This implementation establishes the data persistence and caching infrastructure required for the Solidity Security Platform's backend services as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Deploy fully cost-optimized database infrastructure with PostgreSQL in Kubernetes for local, staging and production environments.
Deploy fully cost-optimized database infrastructure with Redis in minikube for local overlay environment.
Deploy fully cost-optimized database infrastructure with ElastiCache Redis in Kubernetes for staging and production environments.

### Key Requirements (from docs)
- **Database Infrastructure**: PostgreSQL StatefulSet in Kubernetes for local, staging and production
- **Cache Infrastructure**: ElastiCache Redis with encryption for staging and production. Redis for local.
- **Security Controls**: Kubernetes NetworkPolicies and Redis security groups
- **Backup Strategy**: Kubernetes persistent volume snapshots and Redis backup capabilities
- **Cost Optimization**: Use PostgreSQL in Kubernetes instead of managed services (~$1200+/month savings)

### Cost Optimization Strategy (Staging)
**Phase 1 (Sprints 1-5)**: Minimal staging configuration
- **ElastiCache**: `cache.t3.micro` (single node, no clustering)
- **PostgreSQL**: Reduced resource requests (1GB RAM, 0.5 CPU vs 4GB/2CPU production)
- **Storage**: 20GB persistent volumes (vs 100GB+ production)
- **Backup**: Basic snapshots only (no cross-region replication)
- **Target Cost**: ~$50-80/month for storage portion

**Phase 2 (Sprint 6+)**: Full staging parity
- Scale ElastiCache to cluster mode
- Match production PostgreSQL resource allocation
- Implement full backup and replication strategy

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Directory Structure Requirements

```
solidity-security-aws-infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── storage/               # ElastiCache Redis modules only
│   │   │   ├── elasticache.tf    # ElastiCache Redis configuration (both envs)
│   │   │   ├── security_groups.tf # Redis security groups
│   │   │   ├── parameter_groups.tf # Redis parameter groups
│   │   │   ├── variables.tf      # Module variables
│   │   │   └── outputs.tf        # Module outputs
│   │   └── monitoring/
│   │       └── cache_monitoring.tf # ElastiCache monitoring
│   ├── environments/
│   │   ├── staging/               # Staging ElastiCache config
│   │   └── production/            # Production ElastiCache config
│   └── shared/                    # Shared storage components
├── k8s/
│   ├── base/
│   │   └── postgresql/
│   │       ├── kustomization.yaml
│   │       ├── statefulset.yaml
│   │       ├── service.yaml
│   │       ├── configmap.yaml
│   │       ├── pvc.yaml
│   │       ├── secret.yaml
│   │       ├── serviceaccount.yaml
│   │       └── rbac.yaml
│   └── overlays/
│       ├── local/
│       │   ├── kustomization.yaml
│       │   └── postgresql/
│       │       ├── kustomization.yaml
│       │       ├── namespace.yaml
│       │       ├── statefulset-patch.yaml
│       │       ├── configmap-patch.yaml
│       │       ├── pvc-patch.yaml
│       │       └── networkpolicy.yaml
│       ├── staging/
│       │   ├── kustomization.yaml
│       │   └── postgresql/
│       │       ├── kustomization.yaml
│       │       ├── namespace.yaml
│       │       ├── statefulset-patch.yaml
│       │       ├── configmap-patch.yaml
│       │       ├── pvc-patch.yaml
│       │       └── networkpolicy.yaml
│       └── production/
│           ├── kustomization.yaml
│           └── postgresql/
│               ├── kustomization.yaml
│               ├── namespace.yaml
│               ├── statefulset-patch.yaml
│               ├── configmap-patch.yaml
│               ├── pvc-patch.yaml
│               ├── networkpolicy.yaml
│               ├── pdb.yaml
│               ├── backup-cronjob.yaml
│               ├── resourcequota.yaml
│               ├── limitrange.yaml
│               ├── externalsecret.yaml
│               ├── vault-policy.yaml
│               └── servicemonitor.yaml
└── README.md
```

## Step 1: PostgreSQL in Kubernetes Configuration (30 minutes)

### Objectives
- Design PostgreSQL StatefulSet configuration for both environments
- Plan persistent volume and backup strategies
- Define security and networking requirements

### Key Components to Implement
- **Database Design**: PostgreSQL StatefulSet configuration for local, staging and production
- **Storage Planning**: Persistent volumes with appropriate storage classes
- **Security Planning**: NetworkPolicies and pod security contexts
- **Backup Strategy**: Volume snapshots and logical backup procedures

### Technical Requirements
- PostgreSQL 15 StatefulSet with persistent storage
- Environment-specific resource allocation (staging: minimal, production: optimized)
- Pod security contexts and network isolation
- Volume snapshot capabilities for backup and recovery
- Complete PostgreSQL migration to Kubernetes - massive cost savings (~$1200+/month)

## Step 2: ElastiCache Redis Deployment (1 hour)

### Objectives
- Deploy Redis for local
- Deploy ElastiCache Redis clusters for staging and production
- Configure encryption in transit and at rest
- Set up Redis security groups and network access controls

### Key Components to Implement
- **Redis Clusters**: Single-AZ staging and production ElastiCache clusters
- **Encryption**: In-transit and at-rest encryption configuration
- **Security Groups**: Redis access limited to application services

### Integration Strategy
- Redis cluster configuration for session storage and caching
- Network isolation within private subnets
- Integration with External Secrets Operator for credential management

## Step 3: Security and Monitoring Setup (30 minutes)

### Objectives
- Configure Redis security groups with least-privilege access
- Set up ElastiCache monitoring and alerting
- Implement Redis backup validation and recovery testing

### Core Dependencies
- **Security Groups**: Redis ingress rules from EKS nodes only
- **Monitoring**: Prometheus metrics for Redis
- **Backup Validation**: ElastiCache backup verification

### Integration Requirements
- Redis credentials stored in Vault Community
- Redis backup and maintenance windows during low-usage periods
- Cache performance monitoring and alerting
- PostgreSQL StatefulSet deployed within this infrastructure repository

## Success Criteria & Validation

### PostgreSQL in Kubernetes Requirements
- [ ] PostgreSQL StatefulSet configuration designed for both environments
- [ ] Persistent volume storage strategy defined with backup capabilities
- [ ] Pod security contexts and NetworkPolicies planned
- [ ] Environment-specific resource allocation configured
- [ ] Integration with Kubernetes-native monitoring planned

### ElastiCache Infrastructure Requirements
- [ ] ElastiCache Redis staging cluster operational with encryption
- [ ] ElastiCache Redis production cluster operational with encryption
- [ ] Redis security groups configured for application service access
- [ ] Cache cluster accessible from EKS nodes only
- [ ] Redis AUTH configured for secure access

### Security and Monitoring Requirements
- [ ] Redis credentials stored securely in Vault Community
- [ ] Prometheus monitoring enabled for ElastiCache
- [ ] Redis AUTH configured for secure access
- [ ] ElastiCache backup and maintenance windows configured appropriately
- [ ] Redis connection testing validated from EKS
- [ ] PostgreSQL StatefulSet security and monitoring configured

## Implementation Priority

### Phase 1: PostgreSQL Configuration Planning (30 minutes)
1. Design PostgreSQL StatefulSet configuration for local development environment first
2. Design PostgreSQL StatefulSet configuration for local, staging and production environments
3. Plan persistent volume storage and backup strategies
4. Define security contexts and NetworkPolicies

### Phase 2: ElastiCache Redis Deployment (1 hour)
1. Deploy ElastiCache Redis staging cluster with encryption enabled
2. Deploy ElastiCache Redis production cluster with high availability
3. Configure Redis security groups for application service access

### Phase 3: Security and Monitoring (30 minutes)
1. Store Redis credentials in Vault Community
2. Configure Prometheus monitoring for ElastiCache
3. Set up Redis backup validation and maintenance windows

## Key Implementation Notes

1. **Cost Optimization**: PostgreSQL in Kubernetes eliminates managed database costs (~$1200+/month savings)
2. **Security**: Use Kubernetes NetworkPolicies and pod security contexts for database isolation
3. **Backup Strategy**: Use Kubernetes persistent volume snapshots and logical backup procedures
4. **Monitoring**: Use Kubernetes-native monitoring for PostgreSQL, Prometheus for ElastiCache

---

**Estimated Time**: 2 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist

### Local Development Environment
- [ ] PostgreSQL Helm chart (Bitnami) installed in minikube
- [ ] PostgreSQL configured with development resource limits
- [ ] Redis Helm chart (Bitnami) installed in minikube
- [ ] Redis configured for local development access
- [ ] Local persistent volumes configured for PostgreSQL data
- [ ] ConfigMaps created for PostgreSQL and Redis configuration
- [ ] Local service discovery tested for database connections
- [ ] Port forwarding configured for direct database access
- [ ] Development database initialized with test data
- [ ] Local backup and restore procedures validated

### Staging Environment
- [ ] PostgreSQL StatefulSet configuration designed for staging environment
- [ ] Staging persistent volume storage strategy defined with backup capabilities
- [ ] Pod security contexts and NetworkPolicies configured for staging
- [ ] Environment-specific resource allocation configured (reduced for cost)
- [ ] PostgreSQL StatefulSet deployed to staging via Kustomize
- [ ] ElastiCache Redis staging cluster deployed with encryption
- [ ] Redis security groups configured for staging service access
- [ ] Redis credentials stored in Vault Community (staging)
- [ ] Prometheus monitoring enabled for staging ElastiCache
- [ ] Staging database connectivity tested from EKS

### Production Environment
- [ ] PostgreSQL StatefulSet configuration designed for production environment
- [ ] Production persistent volume storage strategy with full backup capabilities
- [ ] Production pod security contexts and NetworkPolicies configured
- [ ] Production resource allocation configured for optimal performance
- [ ] PostgreSQL StatefulSet deployed to production via Kustomize
- [ ] ElastiCache Redis production cluster deployed with HA
- [ ] Production Redis security groups configured with strict access controls
- [ ] Production Redis credentials stored in Vault Community
- [ ] Prometheus monitoring and alerting enabled for production ElastiCache
- [ ] Redis backup and maintenance windows configured for production
- [ ] Production database connectivity tested and validated from EKS
- [ ] PostgreSQL production backup and disaster recovery procedures implemented