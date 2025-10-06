# Task 1.1: Domain Registration and Initial DNS Setup - Objectives & Implementation Details

## Repository: `solidity-security-aws-infrastructure`

AWS Infrastructure as Code repository containing all cloud infrastructure configurations. This task focuses on the DNS and domain management components for establishing the foundational domain infrastructure.

**✅ ALIGNMENT CHECK**: This implementation establishes the foundational domain infrastructure required for the Solidity Security Platform's local, staging and production environments as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Register the domain and set up initial DNS infrastructure. Actual service DNS records will be configured after AWS infrastructure is deployed.

**⚠️ CRITICAL DECISION**: Landing page routing strategy must be determined before DNS configuration.

### Key Requirements (from docs)
- **Domain Registration**: Purchase production domain via Cloudflare
- **DNS Management**: Configure Cloudflare hosted zone for DNS management
- **Subdomain Structure**: Set up local, staging and production subdomain zones
- **Landing Page Strategy**: Decide root domain routing for existing DigitalOcean lander
- **Preparation**: Prepare DNS infrastructure for future service record configuration

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Directory Structure Requirements

```
solidity-security-aws-infrastructure/
├── cloudflare/
│   ├── dns-records/               # DNS record configurations
│   └── subdomain-configs/         # Subdomain-specific settings
├── scripts/
│   └── validation/                # DNS validation scripts
└── README.md
```

## Step 1: Landing Page Strategy Decision (15 minutes)

### Objectives
- Determine root domain routing strategy for existing DigitalOcean lander
- Plan DNS record structure based on landing page decision
- Document routing architecture for infrastructure team

### Landing Page Strategy Options

**Option A: Preserve DigitalOcean Lander (Minimal Change)**
```
@ (root) → DigitalOcean IP                    # Keep existing lander
app.advancedblockchainsecurity.com → AWS ALB  # Application platform (staging/production)
www → CNAME to root                           # Points to DigitalOcean lander
```

**Option B: Migrate to AWS Infrastructure**
```
@ (root) → AWS ALB                            # New landing page on AWS
app.advancedblockchainsecurity.com → AWS ALB  # Application platform (staging/production)
www → CNAME to root                           # Points to AWS lander
```

**Option C: Hybrid Path-Based Routing**
```
@ (root) → AWS ALB with path routing          # Single ALB with routing rules
/app/* → Application platform                # App paths
/* → Landing page content                    # Marketing paths
www → CNAME to root                          # Points to AWS with routing
```

### Implementation Requirements
- **DigitalOcean IP**: Retrieve current lander IP address (if preserving)
- **DNS Configuration**: Update Cloudflare Terraform variables accordingly
- **Documentation**: Record decision for infrastructure team

## Step 2: Domain Purchase and Registration (30 minutes)

### Objectives
- Purchase production domain through Cloudflare
- Configure domain ownership and management
- Set up initial DNS zone configuration

### Key Components to Implement
- **Domain Registration**: Purchase domain (e.g., advancedblockchainsecurity.com)
- **Cloudflare Account**: Set up Cloudflare account for DNS management
- **Initial Configuration**: Configure basic DNS settings

### Technical Requirements
- Domain registration through Cloudflare registrar
- DNS zone creation and configuration
- Domain ownership verification

## Step 3: DNS Zone and Subdomain Setup (1 hour)

### Objectives
- Configure Cloudflare hosted zone for DNS management
- Set up local, staging and production subdomain zones
- Prepare infrastructure for future service routing

### Key Components to Implement
- **Hosted Zone**: Create and configure Cloudflare DNS zone
- **Subdomain Zones**: Prepare staging.advancedblockchainsecurity.com zone
- **Production Zone**: Prepare app.advancedblockchainsecurity.com zone

### Integration Strategy
- DNS infrastructure preparation for future microservices
- Subdomain zone structure for ArgoCD and services
- SSL certificate validation preparation for Let's Encrypt integration

## Step 4: DNS Infrastructure Validation (30 minutes)

### Objectives
- Validate DNS zone configuration and propagation
- Prepare DNS validation for future SSL certificates
- Document DNS infrastructure for service team

### Core Dependencies
- **Zone Configuration**: Cloudflare DNS zones operational
- **Propagation**: Global DNS propagation validated
- **Documentation**: DNS infrastructure documented for service configuration

### Integration Requirements
- DNS infrastructure ready for AWS Load Balancer targets
- Zone structure compatible with cert-manager DNS validation
- Documentation for future service DNS record configuration

## Success Criteria & Validation

### Landing Page Strategy Requirements
- [ ] Landing page routing strategy decided (Option A, B, or C)
- [ ] DigitalOcean lander IP address retrieved (if preserving)
- [ ] DNS routing architecture documented for infrastructure team
- [ ] Cloudflare Terraform variables planned based on strategy

### DNS Infrastructure Requirements
- [ ] Domain registered and accessible at advancedblockchainsecurity.com
- [ ] Cloudflare DNS management operational and responding to queries
- [ ] Staging subdomain zone (staging.advancedblockchainsecurity.com) created and resolvable
- [ ] Production subdomain zone (app.advancedblockchainsecurity.com) created and resolvable
- [ ] Root domain routing configured according to chosen landing page strategy
- [ ] DNS propagation completed globally (verified with multiple DNS checkers)

### Future Integration Preparation Requirements
- [ ] DNS infrastructure documented for service team
- [ ] Zone structure prepared for future AWS Load Balancer targets
- [ ] DNS validation structure prepared for SSL certificate provisioning
- [ ] Subdomain structure planned and documented for service routing
- [ ] DNS TTL values configured appropriately for production use

## Implementation Priority

### Phase 1: Landing Page Strategy (15 minutes)
1. Decide landing page routing strategy (Option A, B, or C)
2. Retrieve DigitalOcean lander IP address if preserving current setup
3. Document routing architecture for infrastructure team

### Phase 2: Domain Registration (30 minutes)
1. Register domain through Cloudflare registrar for integrated DNS management
2. Configure Cloudflare account settings and security features
3. Verify domain ownership and management access

### Phase 3: DNS Zone Setup (45 minutes)
1. Create Cloudflare DNS zone and configure basic settings
2. Set up staging subdomain zone structure
3. Configure production subdomain zone structure
4. Configure root domain routing according to chosen landing page strategy

### Phase 4: Infrastructure Documentation (15 minutes)
1. Document DNS infrastructure for service team
2. Plan future DNS record structure for AWS Load Balancer targets
3. Validate DNS propagation and global resolution

## Key Implementation Notes

1. **DNS Propagation**: DNS changes may take up to 24 hours to propagate globally, plan accordingly
2. **Future Integration**: DNS infrastructure prepared for AWS Load Balancer Controller targets
3. **Security Configuration**: Enable Cloudflare security features appropriate for production use
4. **Documentation**: Comprehensive documentation required for service team to configure records later

---

**Estimated Time**: 2.25 hours (added 15 minutes for landing page strategy)
**Owner**: DevOps Team
**Priority**: P0 (Critical)

## Task Checklist

### Local Development Environment
- [ ] Local domain configuration for development testing (using localhost or local domains)
- [ ] Local DNS resolution setup for minikube ingress (e.g., *.local.advancedblockchainsecurity.com)
- [ ] /etc/hosts entries configured for local service access
- [ ] Local ingress controller configuration validated
- [ ] Development domain routing tested with port forwarding

### Staging Environment
- [ ] Staging subdomain zone (staging.advancedblockchainsecurity.com) created in Cloudflare
- [ ] AWS ALB configuration planned for staging environment
- [ ] SSL certificate strategy planned for staging domain
- [ ] Staging DNS records prepared for AWS Load Balancer targets
- [ ] Landing page routing strategy decided for staging environment

### Production Environment
- [ ] Domain purchased through Cloudflare registrar
- [ ] Production subdomain zone (app.advancedblockchainsecurity.com) created and configured
- [ ] Root domain routing configured according to landing page strategy
- [ ] Cloudflare DNS zone created and configured with security features
- [ ] DNS infrastructure documented for service team
- [ ] DNS structure planned for production AWS Load Balancer targets
- [ ] DNS propagation verified globally
- [ ] Production SSL certificate validation prepared
- [ ] Domain security features enabled in Cloudflare
- [ ] Production landing page routing tested and validated