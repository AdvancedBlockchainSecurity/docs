# Task 1.5: EKS Cluster Deployment - Objectives & Implementation Details

**✅ ALIGNMENT CHECK**: This implementation deploys production-ready EKS clusters for staging and production environments with managed node groups, and autoscaling integration as specified in Sprint 1 documentation.

**Note**: local development will use minikube, not EKS.

## High-Level Objectives

### Primary Goal
Deploy scalable and secure EKS clusters for staging and production environments with managed node groups, cluster autoscaling, and comprehensive logging.

### Key Requirements (from docs)
- **EKS Clusters**: Staging and production clusters with managed node groups
- **Autoscaling**: Cluster autoscaling and node group scaling configuration
- **Security**: Cluster security and network policies

### Cost Optimization Strategy (Staging)
**Phase 1 (Sprints 1-5)**: Minimal staging configuration
- **Node Type**: Single `t3.small` node (instead of `t3.medium`)
- **Node Count**: 1 node minimum, 2 maximum (vs 2-5 for production)
- **Addons**: Essential addons only (CoreDNS, VPC-CNI, EBS CSI)
- **Monitoring**: Basic kubernetes logging only
- **Target Cost**: ~$150-200/month for EKS portion

**Phase 2 (Sprint 6+)**: Full staging parity with production
- Scale to match production configuration for customer testing

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Directory Structure Requirements

```
solidity-security-aws-infrastructure/
├── terraform/
│   └── modules/
│       └── eks/                   # EKS Terraform module
│           ├── cluster.tf         # EKS cluster configuration
│           ├── node_groups.tf     # Managed node group configs
│           ├── variables.tf       # EKS module variables
│           └── outputs.tf         # EKS module outputs
└── k8s/
    ├── base/                      # Kustomize base configurations
    │   ├── eks-cluster/           # Base EKS configurations
    │   │   ├── kustomization.yaml # Base kustomization
    │   │   └── cluster-config.yaml # Basic cluster settings
    │   └── node-groups/           # Base node group configs
    │       ├── kustomization.yaml
    │       └── node-group.yaml
    └── overlays/                  # Environment-specific overlays
        ├── local/                 # Local environment (minikube)
        │   ├── kustomization.yaml # Local customizations
        │   ├── cluster-patch.yaml # Minikube cluster patches
        │   └── node-group-patch.yaml # Minikube node configs
        ├── staging/               # Staging environment overlay
        │   ├── kustomization.yaml # Staging customizations
        │   ├── cluster-patch.yaml # Staging cluster patches
        │   └── node-group-patch.yaml # Staging node configs
        └── production/            # Production environment overlay
            ├── kustomization.yaml # Production customizations
            ├── cluster-patch.yaml # Production cluster patches
            └── node-group-patch.yaml # Production node configs
```

## Step 1: EKS Cluster Creation (2 hours)

### Objectives
- Deploy EKS staging cluster with appropriate configuration
- Deploy EKS production cluster with high availability
- Configure cluster networking and security settings

### Key Components to Implement
- **EKS Terraform Module**: Infrastructure as code for cluster deployment
- **Kustomize Base Configs**: Base Kubernetes configurations for reusability
- **Environment Overlays**: Staging and production-specific customizations
- **Network Integration**: VPC and subnet integration from Task 1.2

### Technical Requirements
- Kubernetes version 1.28+ for latest features and security
- Private endpoint access for enhanced security
- Public endpoint access for administrative tasks
- Integration with VPC subnets and security groups

### Performance Goals
- Fast cluster provisioning and node scaling
- Low-latency pod networking and service communication

## Step 2: Managed Node Groups Configuration (1.5 hours)

### Objectives
- Configure managed node groups for both clusters
- Set up node group instance types and scaling policies
- Configure node group security and networking

### Key Components to Implement
- **Kustomize Base Manifests**: Base node group configurations
- **Environment Overlays**: Staging vs production node sizing and scaling
- **Instance Selection**: Appropriate instance types via Kustomize patches
- **Scaling Configuration**: Min/max nodes and autoscaling policies

### Integration Strategy
- Kustomize base configurations with environment-specific patches
- Node groups configured for single-AZ MVP deployment
- Integration with cluster autoscaler for demand-based scaling
- Security group integration for node communication

## Step 3: Autoscaling and Monitoring Setup (30 minutes)

### Objectives
- Configure cluster autoscaling for both environments
- Validate cluster accessibility and node readiness

### Core Dependencies
- **Cluster Autoscaler**: Automatic node scaling based on pod demands
- **Loki Logging**: API server, audit, authenticator, controllerManager, scheduler logs
- **kubectl Access**: Cluster accessibility validation

### Integration Requirements
- IAM roles for cluster autoscaler functionality
- Loki log streams for cluster logging
- kubeconfig generation for cluster access

## Success Criteria & Validation

### EKS Cluster Infrastructure Requirements
- [ ] EKS staging cluster deployed and operational
- [ ] EKS production cluster deployed and operational
- [ ] Cluster endpoints accessible via kubectl
- [ ] Cluster networking integrated with VPC from Task 1.2
- [ ] Cluster security groups properly configured

### Node Groups and Scaling Requirements
- [ ] Managed node groups operational in both clusters
- [ ] Node groups spanning multiple availability zones
- [ ] Cluster autoscaling functional and responsive to demand
- [ ] Node group scaling policies configured appropriately
- [ ] Instance types selected for workload requirements

### Monitoring and Access Requirements
- [ ] Loki logging operational for all cluster components
- [ ] kubectl access configured for local, staging and production
- [ ] Cluster health monitoring and alerting configured
- [ ] Node readiness and cluster status validated
- [ ] IAM roles and policies configured for cluster operations

## Implementation Priority

### Phase 1: Core Cluster Deployment (2 hours)
1. Deploy EKS staging cluster with managed control plane and networking
2. Deploy EKS production cluster with high availability configuration
3. Configure cluster security groups and network policies

### Phase 2: Node Groups and Scaling (1.5 hours)
1. Create managed node groups with appropriate instance types
2. Configure node group scaling policies and availability zone distribution
3. Set up cluster autoscaler with IAM roles and permissions

### Phase 3: Monitoring and Validation (30 minutes)
1. Enable Loki logging for all cluster components
2. Configure kubectl access and validate cluster connectivity
3. Test node scaling and cluster autoscaler functionality

## Key Implementation Notes

1. **Kustomize Structure**: Use base configurations with environment overlays for maintainability
2. **Version Management**: Use latest stable Kubernetes version for security and feature updates
3. **Security**: Configure private endpoint access with limited public access for administration
4. **Configuration Management**: All Kubernetes resources managed via Kustomize for GitOps compatibility
4. **Monitoring**: Enable comprehensive logging for troubleshooting and security auditing

---

**Estimated Time**: 4 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist

### Local Development Environment
- [x] minikube cluster installed and configured with required addons (v1.34.0, storage-provisioner enabled)
- [x] minikube ingress controller enabled for local service access (NGINX ingress deployed)
- [x] Local Docker registry configured for minikube image access (Harbor deployed in harbor-local)
- [x] kubectl configured for minikube cluster management (kubeconfig: Configured)
- [x] Local cluster resource limits configured for development (defaults appropriate for local dev)
- [x] minikube persistent volume provisioner configured (8 PVs provisioned for services)
- [x] Local service discovery and DNS resolution tested (all services accessible via cluster DNS)
- [x] Development node scaling and resource management verified (single-node minikube operational)

### Staging Environment
- [ ] EKS staging cluster created and configured with cost-optimized settings
- [ ] Staging cluster networking integrated with VPC subnets
- [ ] Staging cluster security groups configured properly
- [ ] Managed node groups created for staging cluster (t3.small instances)
- [ ] Node groups configured for single availability zone (cost optimization)
- [ ] Staging cluster autoscaling configured with IAM roles
- [ ] Node group scaling policies set up for staging (1-2 nodes)
- [ ] Loki logging enabled for staging cluster components
- [ ] kubectl access configured and tested for staging
- [ ] Staging cluster health and node readiness validated

### Production Environment
- [ ] EKS production cluster created and configured with high availability
- [ ] Production cluster networking integrated with multi-AZ VPC subnets
- [ ] Production cluster security groups configured with strict access controls
- [ ] Managed node groups created for production cluster (optimized instance types)
- [ ] Node groups configured across multiple availability zones for HA
- [ ] Production instance types selected appropriate for workloads
- [ ] Production cluster autoscaling configured with IAM roles
- [ ] Production node group scaling policies set up (2-5+ nodes)
- [ ] Loki logging enabled for all production cluster components
- [ ] kubectl access configured and tested for production
- [ ] Production cluster health and node readiness validated
- [ ] Production autoscaler functionality tested and operational
- [ ] Production monitoring and alerting configured