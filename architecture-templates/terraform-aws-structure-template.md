# Terraform Structure Template - Production AWS

Use this template to generate a production-ready Terraform folder structure for AWS with staging and production environments.

---

## Standard Folder Structure

```
terraform/
├── modules/
│   └── <module-name>/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── [optional] data.tf
│       ├── [optional] locals.tf
│       └── [optional] README.md
│
├── environments/
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── backend.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars
│   │   ├── [optional] data.tf
│   │   ├── [optional] locals.tf
│   │   └── <service-name>/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── terraform.tfvars
│   │
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── backend.tf
│       ├── providers.tf
│       ├── terraform.tfvars
│       ├── [optional] data.tf
│       ├── [optional] locals.tf
│       └── <service-name>/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars
│
├── global/
│   ├── iam/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   │
│   ├── cloudflare/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   │
│   └── s3-buckets/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── backend.tf
│       └── terraform.tfvars
│
├── .terraform.lock.hcl
├── .gitignore
└── README.md
```

---

## Module Categories

### Compute Modules
- `ec2` - EC2 instances
- `asg` - Auto Scaling Groups
- `ecs-cluster` - ECS clusters
- `ecs-service` - ECS services
- `eks-cluster` - EKS clusters
- `eks-addons` - EKS addons (CNI, CoreDNS, etc.)
- `lambda` - Lambda functions

### Networking Modules
- `vpc` - VPC with subnets, route tables, NAT gateways
- `security-group` - Security groups
- `alb` - Application Load Balancer
- `nlb` - Network Load Balancer
- `transit-gateway` - Transit Gateway
- `vpc-peering` - VPC peering connections
- `cloudflare-zone` - Cloudflare zones
- `cloudflare-record` - Cloudflare DNS records
- `cloudflare-firewall` - Cloudflare firewall rules
- `cloudflare-waf` - Cloudflare WAF rules

### Database Modules
- `rds-postgres` - RDS PostgreSQL
- `rds-mysql` - RDS MySQL
- `aurora-postgres` - Aurora PostgreSQL
- `aurora-mysql` - Aurora MySQL
- `dynamodb` - DynamoDB tables
- `elasticache-redis` - ElastiCache Redis
- `documentdb` - DocumentDB clusters

### Storage Modules
- `s3-bucket` - S3 buckets with encryption and policies
- `efs` - Elastic File System
- `ebs-volume` - EBS volumes

### Security Modules
- `kms-key` - KMS encryption keys
- `secrets-manager` - Secrets Manager secrets
- `iam-role` - IAM roles
- `iam-policy` - IAM policies
- `waf` - WAF web ACLs
- `security-hub` - Security Hub configuration
- `guardduty` - GuardDuty detector

### Monitoring Modules
- `cloudwatch-log-group` - CloudWatch log groups
- `cloudwatch-alarm` - CloudWatch alarms
- `sns-topic` - SNS topics for alerts
- `cloudwatch-dashboard` - CloudWatch dashboards

### Backup & DR Modules
- `backup-vault` - AWS Backup vault
- `backup-plan` - AWS Backup plans
- `rds-snapshot` - RDS snapshot automation

### Container & Orchestration
- `ecr-repository` - ECR container repositories
- `ecs-task-definition` - ECS task definitions
- `eks-node-group` - EKS managed node groups
- `eks-fargate-profile` - EKS Fargate profiles

---

## Environment Structure

### Staging Environment (`environments/staging/`)

**Top-level files:**
- `main.tf` - Root module imports
- `variables.tf` - Environment-wide variables
- `outputs.tf` - Environment-wide outputs
- `versions.tf` - Terraform and provider versions
- `backend.tf` - S3 backend configuration
- `providers.tf` - AWS provider configuration
- `terraform.tfvars` - Staging-specific values
- `data.tf` - Data sources (AMIs, availability zones, etc.)
- `locals.tf` - Local values and transformations

**Service-specific subdirectories:**
Each service gets its own directory for organization:
```
environments/staging/
├── networking/
├── database/
├── compute/
├── monitoring/
└── security/
```

### Production Environment (`environments/prod/`)

Same structure as staging with production-specific configurations:
- Higher resource allocations
- Multi-AZ deployments
- Enhanced monitoring and alerting
- Stricter security policies
- Backup and disaster recovery
- Auto-scaling configurations

---

## Global Resources (`global/`)

Resources that are shared across environments or region-independent:

### IAM (`global/iam/`)
- Cross-account roles
- Service roles
- User groups and policies
- OIDC providers for GitHub Actions/GitLab CI

### Cloudflare (`global/cloudflare/`)
- Zones and DNS records
- Firewall rules
- WAF rules
- Page rules
- Workers and KV namespaces
- Access policies
- SSL/TLS settings

### S3 Buckets (`global/s3-buckets/`)
- Terraform state buckets
- Artifact storage
- Log aggregation buckets
- Cross-region replication buckets

### Organizations (`global/organizations/`)
- AWS Organizations structure
- Service Control Policies (SCPs)
- Organizational units

---

## File Naming Conventions

### modules/<module>/
- `main.tf` - Primary resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `versions.tf` - Required provider versions
- `data.tf` - Data source lookups
- `locals.tf` - Local value computations
- `README.md` - Module documentation

### Optional module files:
- `iam.tf` - IAM-related resources
- `security-groups.tf` - Security group rules
- `cloudwatch.tf` - Monitoring resources
- `tags.tf` - Tagging logic
- `validation.tf` - Variable validation rules

---

## Backend Configuration

### S3 Backend Structure
Each environment has its own state file:

```
s3://<company>-terraform-state/
├── staging/
│   ├── networking/terraform.tfstate
│   ├── database/terraform.tfstate
│   ├── compute/terraform.tfstate
│   └── security/terraform.tfstate
│
└── prod/
    ├── networking/terraform.tfstate
    ├── database/terraform.tfstate
    ├── compute/terraform.tfstate
    └── security/terraform.tfstate
```

**backend.tf example:**
```
terraform {
  backend "s3" {
    bucket         = "<company>-terraform-state"
    key            = "<environment>/<service>/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "<company>-terraform-locks"
    kms_key_id     = "arn:aws:kms:..."
  }
}
```

---

## Environment-Specific Patterns

### Staging Environment
- **Region**: Single region deployment
- **Availability Zones**: Single AZ for cost savings (except databases)
- **Instance Types**: Smaller, cost-optimized (t3.small, t3.medium)
- **RDS**: Single-AZ, smaller instances (db.t3.small)
- **Auto Scaling**: Minimal (1-2 instances)
- **Backups**: Daily, 7-day retention
- **Monitoring**: Basic CloudWatch metrics
- **Cost Controls**: Auto-shutdown for non-critical resources
- **Networking**: Simpler architecture, fewer subnets
- **Security**: Development-friendly policies

### Production Environment
- **Region**: Multi-region for DR (primary + secondary)
- **Availability Zones**: Multi-AZ for high availability (minimum 3)
- **Instance Types**: Production-grade (c5.xlarge, r5.2xlarge)
- **RDS**: Multi-AZ, read replicas, larger instances
- **Auto Scaling**: Robust (3-10+ instances)
- **Backups**: Multiple daily, 30-day retention, cross-region replication
- **Monitoring**: Enhanced monitoring, custom metrics, alarms
- **Cost Controls**: Reserved instances, savings plans
- **Networking**: Full isolation, private subnets, NAT gateways per AZ
- **Security**: Strict least-privilege, encryption at rest and in transit

---

## Resource Tagging Strategy

### Required Tags (All Resources)
```hcl
tags = {
  Environment     = "<staging|prod>"
  ManagedBy      = "terraform"
  Service        = "<service-name>"
  Owner          = "<team-name>"
  CostCenter     = "<cost-center-id>"
  Project        = "<project-name>"
  Terraform      = "true"
  BackupPolicy   = "<daily|weekly|none>"
}
```

### Optional Tags
```hcl
tags = {
  Compliance     = "<pci|hipaa|sox>"
  DataClass      = "<public|internal|confidential|restricted>"
  GitRepo        = "<repository-url>"
  Version        = "<version>"
  Schedule       = "<24x7|business-hours>"
}
```

---

## Security Best Practices

### State File Security
- S3 bucket encryption (KMS)
- Versioning enabled
- MFA delete enabled (production)
- Bucket policies restricting access
- DynamoDB table for state locking

### Secrets Management
- Never commit secrets to Git
- Use AWS Secrets Manager or Parameter Store
- Reference secrets via data sources
- Rotate secrets regularly
- Use IAM roles, not access keys

### Network Security
- Private subnets for workloads
- Public subnets only for load balancers
- NACLs for additional layer
- Security groups with least privilege
- VPC Flow Logs enabled
- GuardDuty enabled

---

## Module Development Guidelines

### Module Structure
Each module should be:
- **Self-contained**: Can be used independently
- **Reusable**: Works across environments with variables
- **Well-documented**: Clear README with examples
- **Versioned**: Use Git tags for module versions
- **Tested**: Terraform validate and plan

### Variable Naming
- Use snake_case: `vpc_cidr_block`
- Prefix booleans: `enable_nat_gateway`
- Use meaningful names: `database_instance_class` not `db_type`
- Set sensible defaults where possible
- Use descriptions for all variables

### Output Naming
- Be explicit: `vpc_id` not `id`
- Group related outputs: `rds_endpoint`, `rds_port`, `rds_arn`
- Output everything consumers might need

---

## Workspace Strategy

### Option 1: Directory-Based (Recommended)
Separate directories for environments:
- Clear separation
- Different backend configs
- Independent state files
- Better for team workflows

### Option 2: Workspace-Based
Use Terraform workspaces:
- Same code, different workspaces
- Shared backend, separate state files
- More complex variable management
- Use only for simple infrastructures

**Recommendation**: Use directory-based approach (Option 1) for production systems.

---

## Deployment Workflow

### Development Flow
1. Develop modules in `modules/`
2. Test in `environments/staging/`
3. Promote to `environments/prod/` after validation

### CI/CD Integration
```
terraform/
├── .github/
│   └── workflows/
│       ├── terraform-plan-staging.yml
│       ├── terraform-apply-staging.yml
│       ├── terraform-plan-prod.yml
│       └── terraform-apply-prod.yml
```

### Deployment Order
1. Global resources (IAM, Cloudflare zones)
2. Networking (VPC, subnets, security groups)
3. Data layer (RDS, DynamoDB, ElastiCache)
4. Compute layer (ECS, EKS, EC2, Lambda)
5. DNS (Cloudflare records)
6. Monitoring (CloudWatch, alarms)
7. Security (WAF, GuardDuty, Cloudflare firewall)

---

## Additional Files

### .gitignore
```
# Terraform files
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfvars.json
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraform.lock.hcl

# Sensitive files
*.pem
*.key
secrets.tf
*.secret

# IDE
.idea/
.vscode/
*.swp
*.swo
*~
```

### Root README.md
Should include:
- Repository structure overview
- Prerequisites (AWS CLI, Terraform version)
- Authentication setup (AWS credentials, roles)
- Deployment instructions
- Module documentation links
- Naming conventions
- Contact information

---

## Multi-Region Strategy

For production multi-region deployments:

```
environments/
├── prod/
│   ├── us-east-1/
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   └── <services>/
│   │
│   └── us-west-2/
│       ├── main.tf
│       ├── backend.tf
│       └── <services>/
```

---

## Common Anti-Patterns to Avoid

**DO NOT:**
- Hardcode values (use variables)
- Commit state files to Git
- Share state files across environments
- Use default VPCs
- Store secrets in tfvars files
- Deploy everything in one giant main.tf
- Skip resource tagging
- Use hardcoded regions
- Ignore state locking
- Mix environment resources in single state
- Use admin credentials (use least-privilege roles)
- Deploy directly to prod without staging validation

---

## Quality Checklist

Production-ready Terraform structure must have:
- [ ] Separate state files per environment
- [ ] S3 backend with encryption and versioning
- [ ] DynamoDB table for state locking
- [ ] Consistent tagging strategy implemented
- [ ] All secrets in Secrets Manager/Parameter Store
- [ ] Variables with descriptions and validation
- [ ] Module versioning strategy
- [ ] Documentation for all modules
- [ ] .gitignore configured properly
- [ ] Backend configuration secured (encryption, MFA delete for prod)
- [ ] Multi-AZ deployment for production
- [ ] Backup and disaster recovery configured
- [ ] CloudWatch monitoring and alarms
- [ ] Security groups following least privilege
- [ ] VPC Flow Logs enabled
- [ ] GuardDuty enabled
- [ ] Encryption at rest for all data stores
- [ ] Encryption in transit (TLS/SSL)
- [ ] IAM roles instead of access keys
- [ ] No hardcoded credentials or secrets

---

## Usage Instructions

### Generate New Structure
Provide:
1. **AWS Services needed** (RDS, ECS, Lambda, etc.)
2. **Region requirements** (single or multi-region)
3. **High availability needs** (multi-AZ, read replicas)
4. **Compliance requirements** (encryption, logging, etc.)
5. **Team structure** (for tagging and permissions)

### Example Request
"Generate a production Terraform structure for AWS with:
- VPC with public and private subnets
- RDS PostgreSQL with read replica in prod
- ECS Fargate cluster
- Application Load Balancer
- ElastiCache Redis
- S3 buckets for storage
- Cloudflare DNS and WAF configuration
- CloudWatch monitoring and alarms

Deploy to us-east-1 for staging (single-AZ) and us-east-1 + us-west-2 for production (multi-AZ, multi-region)."