# Task 1.3: AWS Database and Cache Infrastructure - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing all cloud infrastructure configurations. This task focuses on the storage module providing PostgreSQL StatefulSets and ElastiCache Redis infrastructure for data persistence and caching.

**✅ ALIGNMENT CHECK**: This implementation establishes the data persistence and caching infrastructure required for the Solidity Security Platform's backend services as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Deploy fully cost-optimized database infrastructure with PostgreSQL in Kubernetes for both staging and production environments, plus ElastiCache Redis for caching.

### Key Requirements (from docs)
- **Database Infrastructure**: PostgreSQL StatefulSet in Kubernetes for both staging and production
- **Cache Infrastructure**: ElastiCache Redis with encryption for staging and production
- **Security Controls**: Kubernetes NetworkPolicies and Redis security groups
- **Backup Strategy**: Kubernetes persistent volume snapshots and Redis backup capabilities
- **Cost Optimization**: Use PostgreSQL in Kubernetes instead of managed services (~$1200+/month savings)

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
├── kubernetes/
│   ├── postgresql/                # PostgreSQL StatefulSet manifests
│   │   ├── base/                  # Base PostgreSQL configuration
│   │   │   ├── kustomization.yaml # Base kustomization
│   │   │   ├── statefulset.yaml   # PostgreSQL StatefulSet
│   │   │   ├── service.yaml       # PostgreSQL service
│   │   │   ├── configmap.yaml     # PostgreSQL configuration
│   │   │   ├── secret.yaml        # PostgreSQL credentials
│   │   │   └── networkpolicy.yaml # PostgreSQL network policies
│   │   └── overlays/              # Environment-specific overlays
│   │       ├── staging/           # Staging PostgreSQL config
│   │       └── production/        # Production PostgreSQL config
│   └── storage/                   # Storage classes and PV configs
└── README.md
```

## Step 1: PostgreSQL in Kubernetes Configuration (30 minutes)

### Objectives
- Design PostgreSQL StatefulSet configuration for both environments
- Plan persistent volume and backup strategies
- Define security and networking requirements

### Key Components to Implement
- **Database Design**: PostgreSQL StatefulSet configuration for staging and production
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
- **Monitoring**: CloudWatch metrics for ElastiCache
- **Backup Validation**: ElastiCache backup verification

### Integration Requirements
- Redis credentials stored in AWS Secrets Manager
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
- [ ] Redis credentials stored securely in AWS Secrets Manager
- [ ] CloudWatch monitoring enabled for ElastiCache
- [ ] Redis AUTH configured for secure access
- [ ] ElastiCache backup and maintenance windows configured appropriately
- [ ] Redis connection testing validated from EKS
- [ ] PostgreSQL StatefulSet security and monitoring configured

## Implementation Priority

### Phase 1: PostgreSQL Configuration Planning (30 minutes)
1. Design PostgreSQL StatefulSet configuration for both environments
2. Plan persistent volume storage and backup strategies
3. Define security contexts and NetworkPolicies

### Phase 2: ElastiCache Redis Deployment (1 hour)
1. Deploy ElastiCache Redis staging cluster with encryption enabled
2. Deploy ElastiCache Redis production cluster with high availability
3. Configure Redis security groups for application service access

### Phase 3: Security and Monitoring (30 minutes)
1. Store Redis credentials in AWS Secrets Manager
2. Configure CloudWatch monitoring for ElastiCache
3. Set up Redis backup validation and maintenance windows

## Key Implementation Notes

1. **Cost Optimization**: PostgreSQL in Kubernetes eliminates managed database costs (~$1200+/month savings)
2. **Security**: Use Kubernetes NetworkPolicies and pod security contexts for database isolation
3. **Backup Strategy**: Use Kubernetes persistent volume snapshots and logical backup procedures
4. **Monitoring**: Use Kubernetes-native monitoring for PostgreSQL, CloudWatch for ElastiCache

---

**Estimated Time**: 2 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist
- [ ] Task 1.3 started
- [ ] PostgreSQL StatefulSet configuration designed for both environments
- [ ] Persistent volume storage strategy defined with backup capabilities
- [ ] Pod security contexts and NetworkPolicies planned
- [ ] Environment-specific resource allocation configured
- [ ] ElastiCache Redis staging cluster deployed with encryption
- [ ] ElastiCache Redis production cluster deployed with HA
- [ ] Redis security groups configured for service access
- [ ] Redis credentials stored in AWS Secrets Manager
- [ ] CloudWatch monitoring enabled for ElastiCache
- [ ] Redis backup and maintenance windows configured
- [ ] Redis connectivity tested from EKS
- [ ] PostgreSQL StatefulSet manifests created and deployment tested
- [ ] Task 1.3 completed and validated