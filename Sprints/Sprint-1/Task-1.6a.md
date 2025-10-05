# Task 1.6a: DNS Service Configuration - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing all cloud infrastructure configurations. This task focuses on configuring DNS service records using AWS Application Load Balancer (ALB) targets for staging/production environments, while local development uses NGINX Ingress Controller.

**✅ ALIGNMENT CHECK**: This implementation configures the actual DNS service records pointing to AWS infrastructure, completing the domain setup started in Task 1.1.

## High-Level Objectives

### Primary Goal
Configure DNS service records in Cloudflare to point to AWS Application Load Balancer (ALB) targets for staging/production environments, enabling access to cloud-hosted services. Local development uses NGINX Ingress Controller for routing.

### Key Requirements (from docs)
- **Service DNS Records**: Configure A/CNAME records pointing to AWS Application Load Balancer (ALB) for staging/production
- **SSL Certificate Validation**: Set up DNS validation records for Let's Encrypt
- **Subdomain Routing**: Configure service-specific subdomain routing
- **ArgoCD Access**: Configure DNS records for ArgoCD dashboard access

## Directory Structure Requirements

```
solidity-security-aws-infrastructure/
├── cloudflare/
│   ├── dns-records/               # Service DNS record configurations
│   └── service-routing/           # Service-specific routing configs
├── scripts/
│   └── dns-validation/            # DNS record validation scripts
└── README.md
```

## Step 1: AWS Load Balancer Target Discovery (30 minutes)

### Objectives
- Discover AWS Application Load Balancer DNS names from deployed infrastructure
- Document ALB targets for local, staging and production environments
- Validate ALB accessibility and health status

### Key Components to Implement
- **ALB Discovery**: Get ALB DNS names from AWS infrastructure
- **Target Validation**: Verify ALB health and accessibility
- **Documentation**: Record ALB targets for DNS configuration

### Technical Requirements
- AWS CLI/Console access to discover ALB endpoints
- ALB health check validation
- Target endpoint documentation for DNS team

## Step 2: DNS Service Record Configuration (1 hour)

### Objectives
- Configure A/CNAME records pointing to AWS ALB targets
- Set up local, staging and production service routing
- Configure ArgoCD dashboard access

### Key Components to Implement
- **Staging Records**: staging.advancedblockchainsecurity.com → staging ALB
- **Production Records**: app.advancedblockchainsecurity.com → production ALB
- **ArgoCD Access**: argocd-staging.advancedblockchainsecurity.com and argocd.advancedblockchainsecurity.com

### Integration Strategy
- DNS records pointing to AWS Application Load Balancer endpoints
- Service-specific subdomain routing for different applications
- SSL certificate validation records for cert-manager integration

## Step 3: SSL Certificate DNS Validation (30 minutes)

### Objectives
- Configure DNS validation records for Let's Encrypt certificates
- Validate cert-manager integration with Cloudflare DNS
- Test SSL certificate provisioning workflow

### Core Dependencies
- **DNS Validation**: TXT records for certificate validation
- **cert-manager Integration**: Cloudflare API token configuration
- **Certificate Testing**: Validate SSL certificate issuance

### Integration Requirements
- Cloudflare API integration for automated DNS validation
- cert-manager configured to use Cloudflare DNS for validation
- SSL certificate automation testing

## Success Criteria & Validation

### DNS Service Record Requirements
- [ ] Staging environment accessible via staging.advancedblockchainsecurity.com
- [ ] Production environment accessible via app.advancedblockchainsecurity.com
- [ ] ArgoCD staging dashboard accessible via argocd-staging.advancedblockchainsecurity.com
- [ ] ArgoCD production dashboard accessible via argocd.advancedblockchainsecurity.com
- [ ] DNS propagation completed globally for all service records

### SSL Certificate Requirements
- [ ] DNS validation records configured for automated certificate provisioning
- [ ] cert-manager successfully issuing certificates via Let's Encrypt
- [ ] SSL certificates valid and trusted for all configured domains
- [ ] Automatic certificate renewal working via DNS validation
- [ ] HTTPS access working for all configured services

## Implementation Priority

### Phase 1: Target Discovery (30 minutes)
1. Discover AWS Application Load Balancer DNS names from infrastructure
2. Validate ALB health and accessibility from internet
3. Document ALB targets for DNS configuration

### Phase 2: Service DNS Configuration (45 minutes)
1. Configure staging subdomain DNS records pointing to staging ALB
2. Configure production subdomain DNS records pointing to production ALB
3. Configure ArgoCD access subdomains for both environments

### Phase 3: SSL Integration (15 minutes)
1. Configure DNS validation records for Let's Encrypt certificates
2. Test cert-manager integration with Cloudflare DNS validation
3. Validate SSL certificate issuance and renewal workflow

## Key Implementation Notes

1. **Dependency**: This task requires completed AWS infrastructure from Tasks 1.5 and 1.6
2. **ALB Targets**: Must use actual AWS Application Load Balancer DNS names from deployed infrastructure
3. **SSL Automation**: Configure DNS validation for automated certificate management
4. **Validation**: Test complete workflow from DNS resolution to SSL-enabled service access

---

**Estimated Time**: 2 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Dependencies**: Task 1.5 (EKS Deployment), Task 1.6 (Kubernetes Infrastructure)

## Task Checklist

### Local Development Environment
- [ ] Local ingress controller configured for development service access
- [ ] /etc/hosts entries configured for local service routing
- [ ] Local ingress rules configured for service access via minikube
- [ ] Self-signed certificates configured for local HTTPS access
- [ ] Local ArgoCD access configured via port forwarding or ingress
- [ ] Development domain resolution tested (*.local.advancedblockchainsecurity.com)
- [ ] Local SSL certificate validation working for development services

### Staging Environment
- [ ] AWS Application Load Balancer targets discovered and documented for staging
- [ ] Staging DNS records configured and pointing to staging ALB
- [ ] ArgoCD staging DNS records configured (argocd-staging.advancedblockchainsecurity.com)
- [ ] DNS validation records configured for staging SSL certificate automation
- [ ] cert-manager integration with Cloudflare DNS validated for staging
- [ ] Staging SSL certificates issued successfully via Let's Encrypt
- [ ] Staging services accessible via HTTPS at staging.advancedblockchainsecurity.com
- [ ] Staging DNS propagation verified globally for all service records

### Production Environment
- [ ] AWS Application Load Balancer targets discovered and documented for production
- [ ] Production DNS records configured and pointing to production ALB
- [ ] ArgoCD production DNS records configured (argocd.advancedblockchainsecurity.com)
- [ ] Production DNS validation records configured for SSL certificate automation
- [ ] cert-manager integration with Cloudflare DNS validated for production
- [ ] Production SSL certificates issued successfully via Let's Encrypt
- [ ] Production services accessible via HTTPS at app.advancedblockchainsecurity.com
- [ ] Production DNS propagation verified globally for all service records
- [ ] Production SSL certificate monitoring and renewal configured