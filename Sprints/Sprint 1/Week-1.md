# Sprint 1: Infrastructure Foundation & Repository Setup (Weeks 1-2)

**Objective:** Establish complete local development environment, repository structure, and cloud-ready Infrastructure as Code foundation for all services with GitOps deployment automation and secure secret management.

## Week 1: Local Infrastructure Foundation & Cloud-Ready IaC

### **Day 1: Repository Foundation & Local Kubernetes Setup**

#### Morning: Repository Setup (2 hours)
- [x] Create 6 repositories on GitHub with branch protection
  - [x] solidity-security-platform
  - [x] solidity-security-infrastructure
  - [x] solidity-security-tools
  - [x] solidity-security-docs
  - [x] solidity-security-monitoring
  - [x] solidity-security-vulnerabilities
- [x] Set up team permissions and access controls
- [x] Clone all repositories and create initial folder structures
- [x] Configure repository templates and README files

#### Afternoon: AWS EKS Setup + Infrastructure Manifest Creation (5-6 hours)
- [ ] **Domain already owned: soliditysecops.com**
- [ ] **Configure Route53 hosted zone for soliditysecops.com - $0.50/month**
- [ ] **Set up development subdomain (dev.soliditysecops.com)**
- [ ] **Configure staging subdomain (staging.soliditysecops.com)**
- [ ] Set up AWS EKS development cluster with realistic resource allocation (t3.medium nodes)
- [ ] Configure EKS add-ons (AWS ALB Controller, EBS CSI Driver, VPC CNI)
- [ ] **Create Infrastructure Manifests:**
  - [ ] **Create AWS ALB ingress controller deployment manifests**
  - [ ] **Create cert-manager installation and Let's Encrypt issuer manifests**
  - [ ] **Create HashiCorp Vault installation manifests for AWS KMS auto-unseal**
  - [ ] **Create Vault configuration manifests with S3 backend storage**
  - [ ] **Create Vault PKI secret engine manifests for internal certificate management**
  - [ ] **Create Vault KV secret engine manifests for application secrets**
  - [ ] **Create ArgoCD installation manifests**
  - [ ] **Create ArgoCD RBAC configuration manifests**
  - [ ] **Create ArgoCD application project manifests for cloud development**
  - [ ] **Create ArgoCD Vault integration manifests for GitOps secret management**
- [ ] **Create Cloud Development Configuration:**
  - [ ] **Create Let's Encrypt certificate generation for soliditysecops.com**
  - [ ] **Create Vault initialization and unsealing scripts for cloud development**
  - [ ] **Create Vault secret provisioning scripts for cloud services**
  - [ ] **Create Route53 DNS configuration scripts**
  - [ ] **Create ArgoCD Git repository integration configuration**
  - [ ] **Create ArgoCD Vault Plugin configuration for secret injection**
- [ ] **Deploy Infrastructure Using Created Manifests:**
  - [ ] **Install and configure AWS ALB ingress controller**
  - [ ] **Install cert-manager with Let's Encrypt ClusterIssuer**
  - [ ] **Deploy HashiCorp Vault cluster with AWS KMS auto-unseal**
  - [ ] **Configure Vault PKI engine for internal certificate authority**
  - [ ] **Configure Vault KV engines for application secrets**
  - [ ] **Install ArgoCD in EKS cluster**
  - [ ] **Configure ArgoCD with GitHub repository integration**
  - [ ] **Configure ArgoCD RBAC for team access and permissions**
  - [ ] **Configure ArgoCD Vault Plugin for automatic secret injection**
- [ ] **Add A-Records for development services:**
  - [ ] **api.dev.soliditysecops.com → ALB**
  - [ ] **app.dev.soliditysecops.com → ALB**
  - [ ] **argocd.dev.soliditysecops.com → ALB**
  - [ ] **vault.dev.soliditysecops.com → ALB**
  - [ ] **grafana.dev.soliditysecops.com → ALB**
- [ ] Write setup scripts for automated cloud environment reproduction

**Cloud DNS Configuration:**
```bash
# Route53 A-Records for soliditysecops.com
api.dev.soliditysecops.com → ALB-DNS-NAME
app.dev.soliditysecops.com → ALB-DNS-NAME
argocd.dev.soliditysecops.com → ALB-DNS-NAME
vault.dev.soliditysecops.com → ALB-DNS-NAME
grafana.dev.soliditysecops.com → ALB-DNS-NAME
prometheus.dev.soliditysecops.com → ALB-DNS-NAME
```

**Vault Cloud Development Configuration:**
```yaml
Vault Production Setup:
  mode: "production"
  ui: true
  storage: "s3"
  seal_type: "awskms"
  cluster_address: "https://vault.dev.soliditysecops.com:8201"
  api_address: "https://vault.dev.soliditysecops.com:8200"
  
Secret Engines:
  kv_v2:
    path: "secret/"
    description: "Application secrets and configurations"
  pki:
    path: "pki/"
    description: "Internal certificate authority"
    max_ttl: "8760h"  # 1 year
  database:
    path: "database/"
    description: "Dynamic database credentials"
  
Auth Methods:
  aws:
    path: "auth/aws/"
    description: "AWS IAM authentication"
  kubernetes:
    path: "auth/kubernetes/"
    description: "Kubernetes service account authentication"
```

**Deliverables Day 1:**
- [ ] All 6 repositories created with basic structure
- [ ] **Domain soliditysecops.com configured in Route53**
- [ ] **AWS EKS cluster operational with managed node groups**
- [ ] **AWS ALB ingress controller routing traffic**
- [ ] **Let's Encrypt ClusterIssuer provisioning SSL certificates automatically**
- [ ] **HashiCorp Vault deployed and operational at https://vault.dev.soliditysecops.com**
- [ ] **Vault PKI engine configured for internal certificate management**
- [ ] **Vault KV engines ready for application secret storage**
- [ ] **ArgoCD successfully deployed and accessible via https://argocd.dev.soliditysecops.com**
- [ ] **ArgoCD UI accessible with Let's Encrypt SSL certificates**
- [ ] **ArgoCD Vault Plugin configured for secret injection**
- [ ] **Cloud development environment fully scripted and reproducible**
- [ ] Infrastructure repository with complete cloud setup automation including Vault

---

### **Day 2: Cloud-Ready Service IaC & Local Data Services**

#### Morning: Cloud-Ready Service IaC Framework (3-4 hours)
- [ ] **Create Kubernetes IaC templates for infrastructure services:**
  - [ ] **PostgreSQL: Deployment, Service, PersistentVolumeClaim, ConfigMap manifests**
  - [ ] **Redis: Deployment, Service, ConfigMap manifests**
  - [ ] **Monitoring: Prometheus, Grafana, Jaeger Deployment manifests**
  - [ ] **Vault Secret Store CSI Driver manifests for secret mounting**
  - [ ] **External Secrets Operator manifests for Vault integration**
- [ ] **Create Helm chart templates for infrastructure services with local and cloud values**
- [ ] Create Kubernetes deployment templates for all 6 microservices with environment-specific configs
- [ ] Set up Helm chart templates with local and cloud environment values
- [ ] **Create local ingress definitions with self-signed SSL certificates**
- [ ] **Create cloud-ready ingress definitions for future AWS ALB integration**
- [ ] Configure cert-manager Certificate resources for local development
- [ ] **Design cloud-ready cert-manager configs for Let's Encrypt (commented/unused)**
- [ ] Set up nginx ingress rules with local routing and rate limiting
- [ ] Configure service discovery and mesh networking for local development
- [ ] Create Docker build templates optimized for both local and cloud deployment
- [ ] Set up environment-specific configuration management (local/dev/staging/prod)
- [ ] **Create ArgoCD Application manifests for each microservice**
- [ ] **Configure ArgoCD sync policies for local development workflow**
- [ ] **Create Vault policy templates for each microservice**
- [ ] **Configure ArgoCD Vault integration for automatic secret injection**

##### **DETAILED BREAKDOWN: Microservice Template Creation with Vault Integration**

###### **1. API Service Templates**
- [ ] **Create `api-service/` directory structure:**
  - [ ] **`k8s/base/deployment.yaml`** - FastAPI application deployment template with Vault secret injection
  - [ ] **`k8s/base/service.yaml`** - ClusterIP service for internal communication
  - [ ] **`k8s/base/configmap.yaml`** - Environment variables and app configuration (non-sensitive)
  - [ ] **`k8s/base/external-secret.yaml`** - External Secrets Operator config for Vault secrets
  - [ ] **`k8s/base/vault-policy.yaml`** - Vault policy for API service secret access
  - [ ] **`k8s/base/service-account.yaml`** - Kubernetes service account for Vault authentication
  - [ ] **`k8s/base/ingress.yaml`** - External API access routing
  - [ ] **`k8s/base/hpa.yaml`** - Horizontal Pod Autoscaler configuration
- [ ] **Create Helm chart for API service:**
  - [ ] **`helm/api-service/Chart.yaml`** - Chart metadata and dependencies
  - [ ] **`helm/api-service/values.yaml`** - Default values for all environments
  - [ ] **`helm/api-service/values-local.yaml`** - Local development overrides with Vault paths
  - [ ] **`helm/api-service/values-cloud.yaml`** - AWS cloud configuration with Vault
  - [ ] **`helm/api-service/templates/`** - Templated Kubernetes manifests
- [ ] **Create ArgoCD Application template:** `argocd/api-service-application.yaml`
- [ ] **Create Vault secret templates:** `vault/api-service-secrets.yaml`

###### **2. Tool Integration Service Templates** 
- [ ] **Create `tool-integration-service/` directory structure:**
  - [ ] **`k8s/base/deployment.yaml`** - Multi-container pod with tool runtimes and Vault secret injection
  - [ ] **`k8s/base/service.yaml`** - Service for tool execution requests
  - [ ] **`k8s/base/configmap.yaml`** - Tool configurations and API endpoints (non-sensitive)
  - [ ] **`k8s/base/external-secret.yaml`** - External Secrets for MythX API keys and tool credentials
  - [ ] **`k8s/base/vault-policy.yaml`** - Vault policy for tool service secret access
  - [ ] **`k8s/base/service-account.yaml`** - Service account for Vault authentication
  - [ ] **`k8s/base/pvc.yaml`** - Persistent storage for contract files and tool outputs
  - [ ] **`k8s/base/ingress.yaml`** - Tool service API access
- [ ] **Create Helm chart for Tool Integration service:**
  - [ ] **`helm/tool-integration/Chart.yaml`** - Chart with tool dependencies
  - [ ] **`helm/tool-integration/values.yaml`** - Tool configurations and resource limits
  - [ ] **`helm/tool-integration/values-local.yaml`** - Local tool paths and Vault settings
  - [ ] **`helm/tool-integration/values-cloud.yaml`** - Cloud storage and scaling configs with Vault
- [ ] **Create ArgoCD Application template:** `argocd/tool-integration-application.yaml`
- [ ] **Create Vault secret templates:** `vault/tool-integration-secrets.yaml`

###### **3. Analysis Orchestration Service Templates**
- [ ] **Create `orchestration-service/` directory structure:**
  - [ ] **`k8s/base/deployment.yaml`** - Celery worker deployment template with Vault secret injection
  - [ ] **`k8s/base/service.yaml`** - Worker communication service
  - [ ] **`k8s/base/configmap.yaml`** - Celery broker settings and queue configurations (non-sensitive)
  - [ ] **`k8s/base/external-secret.yaml`** - External Secrets for Redis connection credentials
  - [ ] **`k8s/base/vault-policy.yaml`** - Vault policy for orchestration service
  - [ ] **`k8s/base/service-account.yaml`** - Service account for Vault authentication
  - [ ] **`k8s/base/hpa.yaml`** - Worker auto-scaling based on queue length
  - [ ] **`k8s/base/pdb.yaml`** - Pod disruption budget for rolling updates
- [ ] **Create Helm chart for Orchestration service:**
  - [ ] **`helm/orchestration/Chart.yaml`** - Chart with Celery dependencies
  - [ ] **`helm/orchestration/values.yaml`** - Worker concurrency and scaling settings
  - [ ] **`helm/orchestration/values-local.yaml`** - Single worker for local development with Vault
  - [ ] **`helm/orchestration/values-cloud.yaml`** - Multi-worker cloud configuration with Vault
- [ ] **Create ArgoCD Application template:** `argocd/orchestration-application.yaml`
- [ ] **Create Vault secret templates:** `vault/orchestration-secrets.yaml`

###### **4. Intelligence Engine Service Templates**
- [ ] **Create `intelligence-engine-service/` directory structure:**
  - [ ] **`k8s/base/deployment.yaml`** - ML processing deployment with GPU support and Vault secrets
  - [ ] **`k8s/base/service.yaml`** - Intelligence API service
  - [ ] **`k8s/base/configmap.yaml`** - ML model configurations and scoring algorithms (non-sensitive)
  - [ ] **`k8s/base/external-secret.yaml`** - External Secrets for ML service credentials
  - [ ] **`k8s/base/vault-policy.yaml`** - Vault policy for intelligence engine service
  - [ ] **`k8s/base/service-account.yaml`** - Service account for Vault authentication
  - [ ] **`k8s/base/pvc.yaml`** - Persistent storage for ML models and training data
  - [ ] **`k8s/base/ingress.yaml`** - Intelligence service API access
- [ ] **Create Helm chart for Intelligence Engine:**
  - [ ] **`helm/intelligence-engine/Chart.yaml`** - Chart with ML dependencies
  - [ ] **`helm/intelligence-engine/values.yaml`** - Model configurations and resource limits
  - [ ] **`helm/intelligence-engine/values-local.yaml`** - Local ML processing settings with Vault
  - [ ] **`helm/intelligence-engine/values-cloud.yaml`** - Cloud ML and GPU configurations with Vault
- [ ] **Create ArgoCD Application template:** `argocd/intelligence-engine-application.yaml`
- [ ] **Create Vault secret templates:** `vault/intelligence-engine-secrets.yaml`

###### **5. Data Service Templates**
- [ ] **Create `data-service/` directory structure:**
  - [ ] **`k8s/base/deployment.yaml`** - Database API service deployment with Vault secret injection
  - [ ] **`k8s/base/service.yaml`** - Database access service
  - [ ] **`k8s/base/configmap.yaml`** - Database connection pools and caching settings (non-sensitive)
  - [ ] **`k8s/base/external-secret.yaml`** - External Secrets for database credentials
  - [ ] **`k8s/base/vault-policy.yaml`** - Vault policy for data service
  - [ ] **`k8s/base/service-account.yaml`** - Service account for Vault authentication
  - [ ] **`k8s/base/ingress.yaml`** - Data service API access (admin only)
- [ ] **Create Helm chart for Data service:**
  - [ ] **`helm/data-service/Chart.yaml`** - Chart with database dependencies
  - [ ] **`helm/data-service/values.yaml`** - Connection pool and caching configurations
  - [ ] **`helm/data-service/values-local.yaml`** - Local database connection settings with Vault
  - [ ] **`helm/data-service/values-cloud.yaml`** - RDS and ElastiCache configurations with Vault
- [ ] **Create ArgoCD Application template:** `argocd/data-service-application.yaml`
- [ ] **Create Vault secret templates:** `vault/data-service-secrets.yaml`

###### **6. Notification Service Templates**
- [ ] **Create `notification-service/` directory structure:**
  - [ ] **`k8s/base/deployment.yaml`** - WebSocket and notification service with Vault secrets
  - [ ] **`k8s/base/service.yaml`** - WebSocket and API service
  - [ ] **`k8s/base/configmap.yaml`** - Email templates and notification configurations (non-sensitive)
  - [ ] **`k8s/base/external-secret.yaml`** - External Secrets for SMTP credentials and webhook URLs
  - [ ] **`k8s/base/vault-policy.yaml`** - Vault policy for notification service
  - [ ] **`k8s/base/service-account.yaml`** - Service account for Vault authentication
  - [ ] **`k8s/base/ingress.yaml`** - WebSocket and notification API access
- [ ] **Create Helm chart for Notification service:**
  - [ ] **`helm/notification/Chart.yaml`** - Chart with messaging dependencies
  - [ ] **`helm/notification/values.yaml`** - Email and WebSocket configurations
  - [ ] **`helm/notification/values-local.yaml`** - Local SMTP (MailHog) settings with Vault
  - [ ] **`helm/notification/values-cloud.yaml`** - AWS SES and SNS configurations with Vault
- [ ] **Create ArgoCD Application template:** `argocd/notification-application.yaml`
- [ ] **Create Vault secret templates:** `vault/notification-secrets.yaml`

#### Afternoon: AWS RDS & ElastiCache Setup + Infrastructure ArgoCD Applications (3-4 hours)
- [ ] **Deploy AWS RDS PostgreSQL 15 with automated backups and encryption**
- [ ] **Configure RDS parameter group for optimal performance**
- [ ] **Store RDS connection credentials in Vault KV engine**
- [ ] **Set up RDS Proxy for connection pooling (optional for development)**
- [ ] **Deploy AWS ElastiCache Redis with encryption in-transit and at-rest**
- [ ] **Configure ElastiCache subnet group and security groups**
- [ ] **Store ElastiCache connection credentials in Vault**
- [ ] **Test cloud database connectivity using Vault-managed credentials**
- [ ] **Configure RDS automated backup and point-in-time recovery**
- [ ] **Set up CloudWatch monitoring for RDS and ElastiCache**
- [ ] **Create ArgoCD Applications for cloud infrastructure monitoring**
- [ ] **Test ArgoCD automatic sync for infrastructure service configuration changes**
- [ ] **Configure ArgoCD health checks for cloud data services**
- [ ] **Test Vault integration with ArgoCD for automatic secret injection**
- [ ] **Validate External Secrets Operator functionality with cloud Vault**
- [ ] **Configure CloudWatch alarms for database performance monitoring**

**Environment Strategy:**
```yaml
Local Development:
  - Self-signed certificates via local CA
  - Single-node PostgreSQL and Redis
  - Local DNS resolution
  - minikube tunnel for load balancer simulation
  - Vault dev mode for secret management
  - External Secrets Operator for secret injection

Cloud Ready (Future):
  - Let's Encrypt certificates via Route53 DNS
  - RDS PostgreSQL with read replicas
  - ElastiCache Redis cluster
  - AWS ALB with SSL termination
  - Vault production mode with auto-unseal
  - AWS KMS integration for encryption
```

**Vault Secret Organization:**
```yaml
Secret Paths:
  secret/api-service/jwt-secret: "JWT signing key"
  secret/api-service/oauth-credentials: "OAuth provider credentials"
  secret/data-service/database-url: "PostgreSQL connection string"
  secret/data-service/redis-url: "Redis connection string"
  secret/tool-integration/mythx-api-key: "MythX API credentials"
  secret/tool-integration/tool-credentials: "Tool-specific API keys"
  secret/notification/smtp-credentials: "Email service credentials"
  secret/notification/slack-webhook: "Slack integration webhook"
  secret/orchestration/celery-broker: "Celery broker credentials"
  secret/intelligence-engine/ml-api-keys: "ML service API keys"
```

**Deliverables Day 2:**
- [ ] Complete DNS A-Records configured and resolving to ALB
- [ ] SSL certificates automatically provisioned for all subdomains
- [ ] Complete Kubernetes IaC templates for all 6 microservices with AWS integration
- [ ] Helm charts with development values and production-ready structure
- [ ] AWS RDS PostgreSQL deployed and accessible via Vault-managed credentials
- [ ] AWS ElastiCache Redis deployed and operational
- [ ] **ArgoCD Applications created for all microservices and cloud infrastructure**
- [ ] **GitOps workflow functional for cloud infrastructure deployments**
- [ ] **Vault secret management operational for all cloud services**
- [ ] **External Secrets Operator successfully injecting secrets from Vault**
- [ ] **ArgoCD Vault Plugin working for GitOps secret management**
- [ ] **Cloud-ready IaC templates prepared for production deployment**
- [ ] SSL certificates automatically managed and renewed via Let's Encrypt

**Directory Structure Created:**
```
solidity-security-platform/
├── services/
│   ├── api-service/
│   │   ├── k8s/base/ (8 manifests including Vault integration)
│   │   ├── helm/ (5 files)
│   │   ├── argocd/ (1 application)
│   │   └── vault/ (secret templates)
│   ├── tool-integration-service/
│   │   ├── k8s/base/ (8 manifests including Vault integration)
│   │   ├── helm/ (5 files)
│   │   ├── argocd/ (1 application)
│   │   └── vault/ (secret templates)
│   ├── orchestration-service/
│   │   ├── k8s/base/ (8 manifests including Vault integration)
│   │   ├── helm/ (5 files)
│   │   ├── argocd/ (1 application)
│   │   └── vault/ (secret templates)
│   ├── intelligence-engine-service/
│   │   ├── k8s/base/ (8 manifests including Vault integration)
│   │   ├── helm/ (5 files)
│   │   ├── argocd/ (1 application)
│   │   └── vault/ (secret templates)
│   ├── data-service/
│   │   ├── k8s/base/ (7 manifests including Vault integration)
│   │   ├── helm/ (5 files)
│   │   ├── argocd/ (1 application)
│   │   └── vault/ (secret templates)
│   └── notification-service/
│       ├── k8s/base/ (7 manifests including Vault integration)
│       ├── helm/ (5 files)
│       ├── argocd/ (1 application)
│       └── vault/ (secret templates)
└── infrastructure/
    ├── vault/ (Vault configuration and policies)
    ├── postgresql/ (IaC deployed)
    ├── redis/ (IaC deployed)
    ├── monitoring/ (IaC deployed)
    └── argocd-apps/ (infrastructure applications)
```

**Total Templates Created:** 6 microservices × ~13 files each (including Vault) = 78 template files ready for service implementation in Week 2.

---

### **Day 3: Local Monitoring Stack & Platform Repository**

#### Morning: Cloud Monitoring Infrastructure + S3 Configuration (3-4 hours)
- [ ] **Deploy Prometheus for metrics collection in EKS cluster**
- [ ] **Configure Grafana with cloud infrastructure dashboards**
- [ ] **Install Jaeger for distributed tracing in EKS**
- [ ] **Set up AWS CloudWatch integration with Prometheus**
- [ ] **Configure CloudWatch Container Insights for EKS monitoring**
- [ ] **Set up AWS X-Ray for distributed tracing (preparation)**
- [ ] **Configure Vault integration for monitoring stack credentials**
- [ ] **Store Grafana admin credentials in Vault KV engine**
- [ ] **Configure monitoring service discovery for EKS services**
- [ ] **Set up CloudWatch alarms for critical infrastructure metrics**
- [ ] **Configure ALB ingress for monitoring services with custom domains**
- [ ] **Create S3 bucket for contract file storage with encryption**
- [ ] **Configure S3 bucket lifecycle policies for cost optimization**
- [ ] **Set up S3 IAM roles and policies for service access**
- [ ] **Create ArgoCD Applications for cloud monitoring stack**
- [ ] **Configure ArgoCD to manage Prometheus and Grafana deployments**
- [ ] **Set up monitoring for ArgoCD itself using CloudWatch**
- [ ] **Configure Vault metrics collection and CloudWatch integration**
- [ ] **Test External Secrets Operator integration with monitoring credentials**

#### Afternoon: Platform Repository Structure + GitOps Patterns (3 hours)
- [ ] Create platform monorepo structure for all microservices
- [ ] Set up backend service directory templates with local development configs
- [ ] Create React frontend application structure with local API endpoints
- [ ] Configure shared libraries and utilities for cross-service communication
- [ ] Set up basic service communication patterns for local development
- [ ] **Configure local frontend ingress with self-signed SSL termination**
- [ ] **Implement ArgoCD App-of-Apps pattern for local application management**
- [ ] **Configure ArgoCD ApplicationSets for local environment automation**
- [ ] **Set up local Git webhook integration for automatic ArgoCD sync**
- [ ] **Configure Vault secret rotation policies for local development**
- [ ] **Test Vault PKI engine for automatic certificate generation**

**Cloud Monitoring Configuration with AWS Integration:**
```yaml
Prometheus in EKS:
  - Scrape EKS cluster metrics via ServiceMonitor
  - CloudWatch integration for AWS service metrics
  - Persistent storage using EBS volumes
  - High availability with multiple replicas

Grafana in EKS:
  - Pre-configured dashboards for AWS services
  - CloudWatch data source configuration
  - OAuth integration with Vault-managed secrets
  - Admin credentials managed by Vault
  - Custom domain: grafana.dev.soliditysecops.com

Jaeger in EKS:
  - Elasticsearch backend for trace storage
  - Integration with AWS X-Ray (future)
  - Custom domain access for team collaboration

CloudWatch Integration:
  - Container Insights for EKS monitoring
  - Application logs via Fluentd
  - Custom metrics from application services
  - Automated alerting for critical issues

S3 Storage Configuration:
  - Bucket: soliditysecops-contracts-dev
  - Encryption: AWS KMS with customer-managed keys
  - Lifecycle: Transition to IA after 30 days, delete after 90 days
  - Versioning: Enabled for contract file history
  - Access: IAM roles for service access, no public access
```

**Deliverables Day 3:**
- [ ] Complete cloud monitoring stack (Prometheus, Grafana, Jaeger) deployed in EKS
- [ ] **Cloud monitoring dashboards accessible via https://grafana.dev.soliditysecops.com**
- [ ] **Vault operational at https://vault.dev.soliditysecops.com with CloudWatch monitoring**
- [ ] **S3 bucket configured for contract storage with proper encryption and lifecycle**
- [ ] Platform repository with microservice structure and cloud configs
- [ ] Basic service templates optimized for cloud development
- [ ] **ArgoCD managing all cloud monitoring components via GitOps**
- [ ] **ArgoCD App-of-Apps pattern implemented for scalable cloud management**
- [ ] **Vault secret management integrated with all monitoring components**
- [ ] **CloudWatch providing comprehensive infrastructure and application monitoring**

---

### **Day 4: Local CI/CD & Tools Repository**

#### Morning: Local CI/CD Pipeline + ArgoCD Integration (3-4 hours)
- [ ] Create GitHub Actions workflows for local infrastructure validation
- [ ] Set up automated testing for Kubernetes manifests and Helm charts
- [ ] Configure Docker image building with security scanning
- [ ] **Implement local deployment automation using minikube registry**
- [ ] Set up dependency scanning and vulnerability alerts
- [ ] **Configure local ingress validation and SSL certificate checks**
- [ ] **Implement local cert-manager certificate lifecycle testing**
- [ ] **Integrate GitHub Actions with local ArgoCD for GitOps workflows**
- [ ] **Configure ArgoCD Image Updater for local development (disabled by default)**
- [ ] **Set up ArgoCD notifications for local deployment status**
- [ ] **Configure Vault integration in GitHub Actions for secret management**
- [ ] **Implement Vault-based secret injection in CI/CD pipelines**
- [ ] **Set up Vault policy validation in CI/CD workflows**

#### Afternoon: Tools Repository Structure + Local Testing (3 hours)
- [ ] Create tools repository with adapter structure for local development
- [ ] Set up adapter templates for Slither, Aderyn, MythX, Solidity-Metrics
- [ ] Configure tool installation and management scripts for local environment
- [ ] Create common schemas for vulnerability normalization
- [ ] Set up integration testing framework for tools in local environment
- [ ] **Configure local tools service ingress with self-signed SSL**
- [ ] **Create ArgoCD Application for local tools service deployment**
- [ ] **Configure ArgoCD to manage local tool configurations and updates**
- [ ] **Test ArgoCD rollback functionality for local tools service**
- [ ] **Store tool API keys and credentials in Vault**
- [ ] **Configure External Secrets Operator for tool credential injection**
- [ ] **Test Vault secret rotation for tool credentials**

**Local CI/CD Strategy with Vault:**
```yaml
Development Workflow:
  1. Commit to feature branch
  2. GitHub Actions runs tests and builds images
  3. Vault provides secrets for CI/CD processes
  4. Push images to minikube registry
  5. ArgoCD automatically syncs local deployment with Vault secrets
  6. Test changes in local environment
  7. Merge to main triggers production-ready build

Vault Integration:
  - CI/CD secrets stored in Vault
  - Dynamic secret generation for builds
  - Policy-based access control for pipelines
  - Secret rotation testing in CI/CD
```

**Deliverables Day 4:**
- [ ] Complete local CI/CD pipeline for infrastructure validation
- [ ] Automated testing and building for all services with local registry
- [ ] Tools repository with adapter structure optimized for local development
- [ ] **GitHub Actions integrated with ArgoCD for local GitOps workflow**
- [ ] **Local development workflow documented and tested**
- [ ] **ArgoCD deployment notifications working for local environment**
- [ ] **Vault secret management integrated with CI/CD pipelines**
- [ ] **Tool credentials securely managed through Vault**

---

### **Day 5: Integration Testing & Local Development Documentation**

#### Morning: End-to-End Local Integration Testing (3-4 hours)
- [ ] Create comprehensive local integration testing scripts
- [ ] Test complete local infrastructure stack functionality
- [ ] Validate service-to-service communication in local environment
- [ ] Test local monitoring and alerting end-to-end
- [ ] Verify local CI/CD pipeline functionality
- [ ] **Test local SSL certificate renewal and validation**
- [ ] **Validate local ingress routing and rate limiting**
- [ ] **Test ArgoCD deployment, sync, and rollback functionality in local environment**
- [ ] **Validate ArgoCD RBAC and local environment access**
- [ ] **Test local ArgoCD disaster recovery and backup procedures**
- [ ] **Test Vault secret injection across all services**
- [ ] **Validate Vault secret rotation and renewal processes**
- [ ] **Test Vault PKI engine certificate lifecycle**
- [ ] **Verify External Secrets Operator functionality end-to-end**

#### Afternoon: Local Development Documentation & Cloud Migration Prep (3-4 hours)
- [ ] Create comprehensive local development setup documentation
- [ ] Document local architecture and service interactions
- [ ] Write local troubleshooting and maintenance guides
- [ ] Create team onboarding documentation for local environment
- [ ] **Document local SSL certificate management procedures**
- [ ] **Create local nginx configuration and troubleshooting guide**
- [ ] **Create ArgoCD local operational runbooks and troubleshooting guides**
- [ ] **Document local GitOps workflow and best practices**
- [ ] **Document Vault local deployment and management procedures**
- [ ] **Create Vault secret management operational guide**
- [ ] **Document Vault policy management and best practices**
- [ ] **Create Vault troubleshooting and recovery procedures**
- [ ] **Prepare cloud migration strategy documentation for Sprint 7 including Vault**
- [ ] **Create comparison guide: local vs cloud configurations including Vault setup**
- [ ] Run final validation of all Sprint 1 acceptance criteria

**Local Environment Documentation with Vault:**
```yaml
Required Documentation:
  - Local setup automation scripts including Vault deployment
  - minikube configuration and resource requirements
  - Local DNS and SSL certificate setup
  - Vault installation, configuration, and initialization
  - Vault secret management procedures and policies
  - ArgoCD local deployment and management
  - External Secrets Operator configuration and troubleshooting
  - Troubleshooting common local development issues including Vault
  - Cloud migration preparation checklist including Vault migration
```

**Deliverables Day 5:**
- [ ] End-to-end local integration testing complete
- [ ] Complete documentation for local setup and operations
- [ ] **Local SSL certificate management documentation**
- [ ] Team onboarding guide ready for local development
- [ ] **ArgoCD local operational documentation complete**
- [ ] **Local GitOps workflow documented and tested**
- [ ] **Vault local deployment and management documentation complete**
- [ ] **Vault secret management procedures documented and validated**
- [ ] **Cloud migration strategy documented for future reference including Vault**
- [ ] All Sprint 1 acceptance criteria validated

## Sprint 1 Final Acceptance Criteria

### **Local Infrastructure Requirements:**
- [ ] All services deploy successfully to local minikube cluster
- [ ] Local monitoring dashboards display metrics from all infrastructure components
- [ ] Local CI/CD pipeline successfully builds and deploys to local environment
- [ ] Local database connections and Redis functional
- [ ] **Local SSL termination working with self-signed certificates**
- [ ] **cert-manager automatically provisions and renews local certificates**
- [ ] **nginx ingress controller routes local traffic correctly with rate limiting**
- [ ] **ArgoCD successfully deploys and manages local application lifecycle via GitOps**
- [ ] **HashiCorp Vault operational and managing all application secrets**
- [ ] **External Secrets Operator successfully injecting secrets from Vault**

### **Local GitOps & ArgoCD Requirements:**
- [ ] **ArgoCD Applications deployed for all local microservices and infrastructure**
- [ ] **GitOps workflow functional for all local deployments and updates**
- [ ] **ArgoCD sync policies configured for local development environment**
- [ ] **ArgoCD RBAC working with proper local team access controls**
- [ ] **ArgoCD rollback capability tested in local environment**
- [ ] **ArgoCD health checks validate local application deployment status**
- [ ] **GitHub Actions integrated with ArgoCD for local automated GitOps**
- [ ] **ArgoCD Vault Plugin working for secret management in GitOps**

### **Vault & Secret Management Requirements:**
- [ ] **Vault deployed and operational in local development mode**
- [ ] **Vault PKI engine configured for local certificate management**
- [ ] **Vault KV engines storing all application secrets**
- [ ] **External Secrets Operator injecting secrets into all services**
- [ ] **Vault policies configured for each microservice**
- [ ] **Secret rotation tested and functional for all services**
- [ ] **ArgoCD Vault integration working for GitOps secret management**
- [ ] **CI/CD pipelines using Vault for secret management**

### **Repository & IaC Requirements:**
- [ ] All 6 repositories created with proper structure and local development documentation
- [ ] **IaC templates work for both local development and future cloud deployment**
- [ ] Infrastructure as Code validates and deploys successfully to local environment
- [ ] **Team members can reproduce local environment setup in <30 minutes**
- [ ] Security scanning integrated into local build process
- [ ] **Local SSL certificate management automated and documented**
- [ ] **Cloud-ready IaC templates prepared for future AWS deployment**
- [ ] **Vault configuration templates ready for cloud deployment**

### **Local Operational Requirements:**
- [ ] Health checks and monitoring for all local services operational
- [ ] **Local automated testing and validation pipelines working**
- [ ] **Local development documentation complete and accessible**
- [ ] **Local development environment fully reproducible across team**
- [ ] **Team onboarding process documented and tested for local setup**
- [ ] **Local SSL certificates rotate automatically without service interruption**
- [ ] **ArgoCD local operational runbooks and troubleshooting documentation complete**
- [ ] **Vault operational procedures documented and tested**

### **Performance Requirements:**
- [ ] **Local platform handles basic load without degradation**
- [ ] **Local API response times meet targets (<200ms P95)**
- [ ] **Local database queries execute efficiently**
- [ ] **Local monitoring system responsive and reliable**
- [ ] **Local ingress layer handles traffic routing efficiently**
- [ ] **Local certificate provisioning completes within 2 minutes**
- [ ] **ArgoCD local sync operations complete within 1 minute**
- [ ] **Vault secret retrieval completes within 100ms**

### **Development Workflow Requirements:**
- [ ] **Local development workflow supports hot-reload and fast iteration**
- [ ] **Local debugging and testing procedures documented**
- [ ] **Local environment isolated from cloud resources (zero cloud costs)**
- [ ] **Local GitOps workflow prepares team for cloud deployment patterns**
- [ ] **Cloud migration strategy documented and ready for Sprint 7**
- [ ] **Vault secret management prepares team for cloud secret management**

## Local Development Strategy Summary

### **Cost Savings:**
- **Zero cloud costs** during Sprints 1-6 (estimated $6,000-9,000 saved)
- **Local resource utilization** instead of cloud compute charges
- **No cloud networking or storage costs** during development

### **Development Benefits:**
- **Faster iteration cycles** with local testing and debugging
- **Offline development capability** for improved productivity
- **Consistent team environments** via scripted setup
- **Full GitOps pattern learning** with local ArgoCD deployment
- **Enterprise-grade secret management** with local Vault

### **Cloud Migration Preparation:**
- **Cloud-ready IaC templates** developed from day one
- **Environment-specific configurations** prepared for AWS deployment
- **GitOps workflow patterns** proven locally before cloud deployment
- **Vault cloud deployment** configurations ready for production
- **Migration strategy** documented for seamless Sprint 7 transition

## IaC Storage Strategy Summary

- **Infrastructure IaC** → `solidity-security-infrastructure` repository
  - Local minikube configurations
  - Local Vault deployment and configuration
  - Cloud-ready AWS templates (unused until Sprint 7)
  - Cloud-ready Vault production configurations
  - ArgoCD Applications for both local and cloud
- **Application IaC** → Embedded in service directories within platform repository
  - Local development Helm values with Vault integration
  - Cloud-ready Helm values with Vault (prepared for future use)
  - Vault policies and secret templates for each service
- **Monitoring IaC** → `solidity-security-monitoring` repository
  - Local monitoring stack configurations with Vault integration
  - Cloud-ready monitoring configurations with Vault
- **CI/CD IaC** → `.github/workflows` in respective repositories
  - Local development workflows with Vault integration
  - Cloud deployment workflows with Vault (prepared for Sprint 7)
- **Documentation** → `solidity-security-docs` repository
  - Local development setup guides including Vault
  - Cloud migration procedures including Vault migration
  - Vault operational guides and troubleshooting
- **Tool Configurations** → `solidity-security-tools` repository
  - Local tool adapter configurations with Vault secret management
- **ArgoCD Applications** → `solidity-security-infrastructure/argocd/`
  - Local development applications with Vault integration
  - Cloud-ready applications with Vault (prepared for future)
- **GitOps Configurations** → `solidity-security-infrastructure/gitops/`
  - Local GitOps patterns and workflows with Vault
  - Cloud GitOps templates with Vault
- **Vault Configurations** → `solidity-security-infrastructure/vault/`
  - Local Vault deployment manifests
  - Cloud Vault production configurations
  - Vault policies and secret engine configurations
  - Vault operational procedures and automation
