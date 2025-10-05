# Task 1.2: AWS VPC and Networking Infrastructure - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing all cloud infrastructure configurations, including VPC, EKS, PostgreSQL in Kubernetes, ElastiCache, IAM, and Vault Community configurations. This task focuses on the networking module providing secure foundation for all AWS services.

**✅ ALIGNMENT CHECK**: This implementation establishes the secure networking foundation required for EKS, PostgreSQL StatefulSets, and ElastiCache services as specified in Sprint 1 AWS infrastructure requirements.

## High-Level Objectives

### Primary Goal
Create secure and scalable VPC infrastructure with single-AZ for staging and multi-AZ for production to support EKS clusters, PostgreSQL StatefulSets, and ElastiCache services.

### Key Requirements (from docs)
- **VPC Design**: Single-AZ VPC with public and private subnets for MVP deployment
- **Security Groups**: Configured for EKS and ElastiCache with least-privilege access, NetworkPolicies for PostgreSQL
- **Internet Access**: NAT gateways for secure private subnet internet connectivity
- **Service Integration**: VPC endpoints for AWS services to reduce internet egress
- **Terraform State Management**: S3 bucket and DynamoDB table for remote state storage and locking

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`

## Directory Structure Requirements

```
solidity-security-aws-infrastructure/
├── terraform/
│   ├── modules/
│   │   ├── networking/            # VPC, subnets, security groups
│   │   │   ├── vpc.tf            # VPC configuration
│   │   │   ├── subnets.tf        # Public/private subnets
│   │   │   ├── security_groups.tf # Security group rules
│   │   │   ├── nat_gateways.tf   # NAT gateway configuration
│   │   │   ├── vpc_endpoints.tf  # VPC endpoints for AWS services
│   │   │   ├── routing.tf        # Route tables and routing
│   │   │   ├── variables.tf      # Module variables
│   │   │   └── outputs.tf        # Module outputs
│   │   ├── state-backend/         # Terraform state management
│   │   │   ├── s3.tf             # S3 bucket for state storage
│   │   │   ├── dynamodb.tf       # DynamoDB table for state locking
│   │   │   ├── variables.tf      # Backend module variables
│   │   │   └── outputs.tf        # Backend module outputs
│   │   └── monitoring/
│   │       └── vpc_flow_logs.tf  # VPC Flow Logs configuration
│   ├── environments/
│   │   ├── staging/               # Staging network config
│   │   └── production/            # Production network config
│   └── shared/                    # Shared networking components
└── README.md
```

## Step 0: Deploy S3 State Backend (DEPLOY FIRST - 30 minutes)

**⚠️ CRITICAL: Deploy this BEFORE any other AWS infrastructure tasks**

### Deployment Order Context
This S3 backend deployment is **Step 0** in the corrected AWS resource deployment sequence:
- **Step 0**: Deploy S3 State Backend (Task 1.2 - THIS STEP)
- **Step 1**: VPC & Networking (Task 1.2 - remaining steps)
- **Step 2**: ElastiCache (Task 1.3)
- **Step 3**: EKS Clusters (Task 1.5)
- **Step 4**: IAM for Controllers (Task 1.6)
- **Step 5**: Load Balancer Controller (Task 1.6)
- **Step 6**: DNS (Task 1.1) - moved to last

### Objectives
- Create S3 bucket for Terraform remote state storage
- Configure DynamoDB table for Terraform state locking
- Set up secure backend configuration for team collaboration

### Key Components to Implement
- **S3 Bucket**: Versioned bucket for Terraform state files with encryption
- **DynamoDB Table**: State locking table to prevent concurrent modifications
- **Backend Configuration**: Secure remote state management setup

### Cost Optimization Strategy (Staging)
**Phase 1 (Sprints 1-5)**: Minimal staging configuration
- **Single AZ deployment** (reduce NAT gateway costs from ~$45/month to ~$22/month)
- **Smaller subnet allocation** (efficient IP usage)
- **Essential VPC endpoints only** (S3, Harbor Registry for EKS)
- **Basic security groups** (expanded in Phase 2)
- **Target Cost**: ~$30-50/month for networking portion

**Phase 2 (Sprint 6+)**: Full multi-AZ staging
- Scale to multi-AZ for production parity testing
- Additional VPC endpoints and security hardening

### Technical Requirements
- S3 bucket with versioning and encryption enabled
- DynamoDB table with LockID primary key for state locking
- Proper IAM permissions for Terraform state management
- Region-specific bucket naming for isolation

### Security Requirements
- Server-side encryption for S3 bucket (AES256 or KMS)
- Public access blocked on S3 bucket
- Least-privilege IAM policies for state management

## Step 1: VPC and Subnet Architecture (1.5 hours)

### Objectives
- Create VPC with proper CIDR block allocation
- Configure public and private subnets across multiple availability zones
- Set up routing tables and internet gateway

### Key Components to Implement
- **VPC Creation**: /16 CIDR block for scalability
- **Public Subnet**: Single public subnet for load balancer
- **Private Subnet**: Single private subnet for EKS nodes and databases

### Technical Requirements
- Single-AZ deployment for MVP cost optimization
- Proper CIDR block allocation for future growth
- Route table configuration for public and private subnets
- Internet Gateway for public subnet internet access

### Performance Goals
- Low-latency intra-subnet communication
- Simplified network architecture for MVP deployment

## Step 2: Security Groups and Network Controls (1.5 hours)

### Objectives
- Configure security groups with least-privilege access principles
- Set up network ACLs for additional security layers
- Implement security controls for all service types

### Key Components to Implement
- **EKS Security Groups**: Node groups, control plane, and pod communication
- **Database Security**: PostgreSQL access controlled via Kubernetes NetworkPolicies
- **ElastiCache Security Groups**: Cache access limited to application services

### Integration Strategy
- Security group rules allowing service-to-service communication
- Ingress rules for load balancers and external access
- Egress rules for internet access and AWS service communication

## Step 3: NAT Gateways and VPC Endpoints (1 hour)

### Objectives
- Deploy NAT gateways for secure private subnet internet access
- Configure VPC endpoints to reduce internet egress costs
- Set up network monitoring and security controls

### Core Dependencies
- **NAT Gateways**: High-availability NAT gateway deployment
- **VPC Endpoints**: S3, Harbor Registry, Vault Community endpoints
- **Network Monitoring**: VPC Flow Logs and Prometheus integration

### Integration Requirements
- Single NAT gateway deployment for MVP cost efficiency
- VPC endpoints for AWS service access and Harbor registry routing without internet egress
- Harbor registry integration with Kubernetes via service mesh and ingress controllers
- Network monitoring for security and performance analysis

## Success Criteria & Validation

### Terraform State Backend Requirements
- [ ] S3 bucket created with versioning and encryption enabled
- [ ] DynamoDB table created for Terraform state locking
- [ ] Backend configuration files created for staging and production
- [ ] Terraform remote state successfully initialized and tested

### VPC Infrastructure Requirements
- [ ] VPC created with appropriate CIDR block (/16 or larger)
- [ ] Public subnet deployed in single availability zone
- [ ] Private subnet deployed in single availability zone
- [ ] Internet Gateway attached and routing configured
- [ ] Route tables configured for public and private subnet traffic

### Security Configuration Requirements
- [ ] EKS security groups configured with least-privilege access
- [ ] PostgreSQL NetworkPolicies configured for pod-to-pod communication
- [ ] ElastiCache security groups with restricted application access
- [ ] Network ACLs configured for additional security layers
- [ ] Security group rules documented and validated

### High Availability Requirements
- [ ] NAT gateway deployed in single AZ for MVP
- [ ] VPC endpoints operational for S3, Harbor Registry, Vault Community
- [ ] Network monitoring enabled with VPC Flow Logs
- [ ] Single-AZ network communication tested and validated

## Implementation Priority

### Phase 0: State Backend Setup (30 minutes) - DEPLOY FIRST
1. Create S3 bucket for Terraform remote state with versioning and encryption
2. Configure DynamoDB table for Terraform state locking
3. Set up backend configuration files for staging and production environments

### Phase 1: Core VPC Infrastructure (1.5 hours)
1. Create VPC with /16 CIDR block for maximum flexibility and growth
2. Deploy public subnet in single AZ for load balancer placement
3. Deploy private subnet in single AZ for EKS nodes and databases

### Phase 2: Security and Access Control (1.5 hours)
1. Configure EKS security groups for cluster communication and node access
2. Plan PostgreSQL NetworkPolicies for Kubernetes-native security controls
3. Create ElastiCache security groups for cache service access

### Phase 3: Connectivity and Optimization (1 hour)
1. Deploy single NAT gateway for private subnet internet access
2. Configure VPC endpoints for AWS services to reduce egress costs
3. Enable VPC Flow Logs and network monitoring for security analysis

## Key Implementation Notes

1. **CIDR Planning**: Use /16 VPC CIDR with /24 subnets to allow for future expansion
2. **Security Groups**: Follow least-privilege principle with specific port and protocol restrictions
3. **MVP Architecture**: Single-AZ deployment for cost optimization, can expand to multi-AZ later
4. **Cost Optimization**: Use VPC endpoints to minimize NAT gateway and internet egress costs

---

**Estimated Time**: 4.5 hours (added 30 minutes for S3 backend setup)
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist

### Local Development Environment - Kubernetes Infrastructure ✅ COMPLETED
**Updated Structure**: All local overlays now follow the standardized kustomize structure template.

#### Core Infrastructure Services ✅ IMPLEMENTED
- [x] **Vault Community Edition**: Secret management with External Secrets integration
  - Location: `k8s/overlays/local/vault/` (namespace: `vault-local`)
  - Features: Kubernetes auth, Redis integration, per-service policies
- [x] **External Secrets Operator**: Vault-backed secret management
  - Location: `k8s/overlays/local/external-secrets/` (namespace: `external-secrets-local`)
  - Features: ClusterSecretStore, automatic secret synchronization
- [x] **Cert-Manager**: Self-signed certificate management for local TLS
  - Location: `k8s/overlays/local/cert-manager/` (namespace: `cert-manager-local`)
  - Features: Local CA issuer, automatic certificate provisioning
- [x] **NGINX Ingress Controller**: Local ingress and TLS termination
  - Location: `k8s/overlays/local/nginx-ingress-controller/` (namespace: `nginx-ingress-local`)
  - Features: Resource-optimized for minikube, NodePort configuration
- [x] **Metrics Server**: Local cluster metrics and HPA support
  - Location: `k8s/overlays/local/metrics-server/` (namespace: `metrics-server-local`)
  - Features: Lightweight configuration for minikube
- [x] **Network Policies**: Pod-to-pod communication security
  - Location: `k8s/overlays/local/network-policies/`
  - Features: Default deny, service-specific allow rules

#### Application Services ✅ IMPLEMENTED
- [x] **Redis Cache**: Memory store with Vault integration
  - Location: `k8s/overlays/local/redis/` (namespace: `redis-local`)
  - Features: External secrets, TLS ingress, service monitoring
- [x] **PostgreSQL Database**: Primary database with backup strategies
  - Location: `k8s/overlays/local/postgresql/` (namespace: `postgresql-local`)
  - Features: StatefulSet, persistent storage, TLS ingress
- [x] **Harbor Registry**: Container image registry with PostgreSQL backend
  - Location: `k8s/overlays/local/harbor/` (namespace: `harbor-local`)
  - Features: Redis cache integration, web UI, TLS certificates
- [x] **ArgoCD**: GitOps continuous deployment
  - Location: `k8s/overlays/local/argocd/` (namespace: `argocd-local`)
  - Features: RBAC configuration, server deployment patches

#### Structure Compliance ✅ VERIFIED
- [x] **Per-service namespaces**: `<service>-local` pattern implementation
- [x] **Template compliance**: Following `kubernetes-kustomize-structure-template.md`
- [x] **Security integration**: External secrets with vault policies
- [x] **Resource optimization**: 25-40% of production resources for minikube
- [x] **TLS automation**: Cert-manager integration across all services
- [x] **Umbrella kustomization**: Main local overlay coordinates all services

#### Security Features ✅ IMPLEMENTED
- [x] **Vault-backed secrets**: No secrets stored in Git, all via External Secrets
- [x] **Network isolation**: Per-service namespaces with network policies
- [x] **TLS everywhere**: Automatic HTTPS for all ingress services
- [x] **RBAC integration**: Service accounts with vault kubernetes auth
- [x] **Non-root containers**: Security contexts with dropped capabilities

#### Vault Secret Management ✅ IMPLEMENTED
- [x] **Redis secrets**: `secret/data/redis` → ExternalSecret in `redis-local` namespace
- [x] **Harbor Redis integration**: `secret/data/redis` → ExternalSecret in `harbor-local` namespace
- [x] **ArgoCD Redis secrets**: `secret/data/argocd` → ExternalSecret in `argocd-local` namespace
- [x] **Vault policies**: Per-service authentication and authorization roles
- [x] **SecretStore configuration**: Per-namespace SecretStore resources with Vault backend
- [x] **Automatic sync**: 15-second refresh interval for secret synchronization
- [x] **Secure storage**: All passwords generated and stored in Vault, no hardcoded values

### LEGACY CHECKLIST (Pre-Structure Update)
- [x] minikube cluster networking verified and operational
- [x] Harbor registry network configuration validated for container communication
- [x] Local Harbor registry access configured and tested
- [x] minikube ingress controller enabled and configured
- [x] Local service discovery and DNS resolution tested
- [x] Port forwarding configuration validated for service access
- [x] Local network policies tested for pod-to-pod communication
- [x] Development environment network isolation verified

### Staging Environment
- [ ] S3 bucket created for Terraform state storage (staging)
- [ ] DynamoDB table created for state locking (staging)
- [ ] Terraform remote state initialized for staging environment
- [ ] AWS VPC created with appropriate CIDR block allocation
- [ ] Public subnet deployed in single availability zone (staging)
- [ ] Private subnet deployed in single availability zone (staging)
- [ ] Internet Gateway attached and routing tables configured
- [ ] EKS security groups configured for staging cluster
- [ ] ElastiCache security groups configured for staging cache access
- [ ] NAT gateway deployed in single AZ (staging)
- [ ] VPC endpoints configured for AWS services (staging)

### Production Environment
- [ ] S3 bucket created for Terraform state storage (production)
- [ ] DynamoDB table created for state locking (production)
- [ ] Terraform remote state initialized for production environment
- [ ] Production VPC created with multi-AZ CIDR block allocation
- [ ] Public subnets deployed across multiple availability zones
- [ ] Private subnets deployed across multiple availability zones
- [ ] Production Internet Gateway and routing tables configured
- [ ] EKS security groups configured with production access controls
- [ ] PostgreSQL NetworkPolicies planned for Kubernetes security
- [ ] ElastiCache security groups configured for production cache access
- [ ] NAT gateways deployed across multiple AZs for high availability
- [ ] VPC endpoints configured for all required AWS services
- [ ] Network monitoring enabled with VPC Flow Logs
- [ ] Security group rules tested and validated for production
- [ ] Network infrastructure operational and validated