# Vendors, Services & Tools - Cost Breakdown

## Cloud Infrastructure & Platform Vendors

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Amazon Web Services (AWS) | EKS (Elastic Kubernetes Service) | Container orchestration | $200 (dev), $500-800 (prod) |  |
| Amazon Web Services (AWS) | VPC (Virtual Private Cloud) | Network infrastructure | Included in EKS |  |
| Amazon Web Services (AWS) | RDS PostgreSQL | Primary database with Multi-AZ | $50 (dev), $200 (prod) |  |
| Amazon Web Services (AWS) | ElastiCache Redis | Caching and message broker | $30 (dev), $100 (prod) |  |
| Amazon Web Services (AWS) | Application Load Balancer (ALB) | Load balancing and SSL termination | $30 (dev), $100 (prod) |  |
| Amazon Web Services (AWS) | CloudFront | CDN for global content delivery | $0-50 (usage-based) |  |
| Amazon Web Services (AWS) | ECR | Container image storage | $10-30 (usage-based) |  |
| Amazon Web Services (AWS) | S3 | Object storage | $5-20 (usage-based) |  |
| Amazon Web Services (AWS) | IAM | Identity and access management | n/a |  |
| Amazon Web Services (AWS) | CloudWatch | Monitoring, logging, and metrics | $20-100 (usage-based) |  |
| Amazon Web Services (AWS) | X-Ray | Distributed tracing | $5-20 (usage-based) |  |
| Amazon Web Services (AWS) | Certificate Manager | SSL certificate management | n/a |  |
| Amazon Web Services (AWS) | KMS | Key management service | $1-10 (usage-based) |  |
| Amazon Web Services (AWS) | VPC Endpoints | Private connectivity to AWS services | $20-50/month |  |
| Amazon Web Services (AWS) | WAF | Web application firewall | $10-50/month |  |
| Amazon Web Services (AWS) | GuardDuty | Threat detection | $10-30/month |  |
| Amazon Web Services (AWS) | Config | Compliance monitoring | $5-20/month |  |
| Amazon Web Services (AWS) | CloudTrail | API auditing | $5-15/month |  |
| Amazon Web Services (AWS) | Secrets Manager | Enterprise secret management | $10-50/month |  |
| Cloudflare | DNS Management | DNS and domain configuration | n/a (free tier) |  |
| Domain Registrar | Domain Purchase | advancedblockchainsecurity.com | $12-20/year |  |

## Security Analysis Tools Vendors

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Trail of Bits | Slither | Static analysis for Solidity | n/a |  |
| Cyfrin | Aderyn | Rust-based static analysis tool | n/a |  |
| ConsenSys | MythX | Commercial security analysis platform | $200-500/month |  |
| Open Source | Solidity-Metrics | Code complexity and metrics analysis | n/a |  |
| Certora | Certora Prover | Formal verification platform | $500-2000/month |  |
| Trail of Bits | Echidna | Fuzzing framework | n/a |  |
| Trail of Bits | Manticore | Symbolic execution engine | n/a |  |
| ChainSecurity | Securify | Static analyzer | n/a |  |
| SmartDec | SmartCheck | Static analysis tool | n/a |  |

## Development & DevOps Tools

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Python Software Foundation | Python 3.11 | Primary backend language | n/a |  |
| Node.js Foundation | Node.js | Frontend tooling and adapters | n/a |  |
| Rust Foundation | Rust | For Aderyn integration | n/a |  |
| Microsoft | TypeScript | Frontend development | n/a |  |
| FastAPI | FastAPI | API framework | n/a |  |
| Celery Project | Celery | Task queue and job processing | n/a |  |
| SQLAlchemy | SQLAlchemy | ORM for database operations | n/a |  |
| Alembic | Alembic | Database migration management | n/a |  |
| Pydantic | Pydantic | Data validation and serialization | n/a |  |
| pytest | pytest | Testing framework | n/a |  |
| Argon2 | Argon2 | Password hashing | n/a |  |

## Frontend Development

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Meta | React 18 | Frontend framework | n/a |  |
| Vite | Vite | Build tool and development server | n/a |  |
| TanStack | TanStack Query | Data fetching and caching | n/a |  |
| Zustand | Zustand | State management | n/a |  |
| React Hook Form | React Hook Form | Form handling | n/a |  |
| Zod | Zod | Schema validation | n/a |  |
| D3.js | D3.js | Data visualization | n/a |  |
| Recharts | Recharts | Chart components | n/a |  |
| React Flow | React Flow | Interactive diagrams | n/a |  |

## Version Control & CI/CD

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| GitHub | GitHub | Plugin development & Actions YAML hosting | $8/month (2 dev licenses) |  |
| GitHub | GitHub Actions | CI/CD automation templates | Included with licenses |  |
| GitLab | GitLab CI | Customer CI/CD integration (plugin) | n/a (customer subscription) |  |
| CloudBees | Jenkins | Customer CI/CD integration (plugin) | n/a (customer subscription) |  |

## Kubernetes & Infrastructure Tools

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Argo Project | ArgoCD | GitOps deployment automation | n/a |  |
| CNCF | Helm | Package management for Kubernetes | n/a |  |
| External Secrets | External Secrets Operator | Secret injection from AWS Secrets Manager | n/a |  |
| AWS | AWS Secrets Store CSI Driver | Direct secret mounting | n/a |  |
| cert-manager | cert-manager | Certificate lifecycle management | n/a |  |
| AWS | AWS Load Balancer Controller | ALB integration | n/a |  |
| Istio | Istio | Service mesh for microservices | n/a |  |
| Envoy Proxy | Envoy | Proxy for load balancing | n/a |  |
| HashiCorp | Terraform | AWS infrastructure provisioning | n/a |  |
| Kubernetes | Kubernetes Manifests | Application deployment | n/a |  |
| AWS | CloudFormation | Alternative AWS resource management | n/a |  |

## Monitoring & Observability

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Prometheus | Prometheus | Metrics collection and alerting | n/a |  |
| Grafana Labs | Grafana | Visualization dashboards | n/a (self-hosted) |  |
| Jaeger | Jaeger | Distributed tracing | n/a |  |
| Prometheus | AlertManager | Alert routing and management | n/a |  |
| Fluentd | Fluentd | Log collection and forwarding | n/a |  |
| Amazon Web Services (AWS) | Amazon Redshift | Data warehouse for analytics | $100-1000/month |  |
| Elastic | Elasticsearch | Search and log analysis | n/a (self-hosted) |  |
| Elastic | Kibana | Log visualization | n/a (self-hosted) |  |

## Database & Storage

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| PostgreSQL | PostgreSQL 15 | Primary application database | n/a (AWS RDS cost above) |  |
| Redis | Redis 7 | Caching and session storage | n/a (AWS ElastiCache cost above) |  |
| Amazon Web Services (AWS) | RDS Proxy | Connection pooling | $15-30/month |  |
| pandas | pandas | Data manipulation (Python) | n/a |  |
| NumPy | NumPy | Numerical computing | n/a |  |
| scikit-learn | scikit-learn | Machine learning algorithms | n/a |  |

## Authentication & Security

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| OAuth | OAuth 2.0 | Standard authentication protocol | n/a |  |
| Google | Google OAuth | Google SSO integration | n/a |  |
| GitHub | GitHub OAuth | GitHub SSO integration | n/a |  |
| Microsoft | Microsoft SSO | Enterprise authentication | n/a (customer subscription) |  |
| OASIS | SAML 2.0 | Enterprise identity providers | n/a |  |
| Microsoft | Active Directory | Enterprise directory service | n/a (customer subscription) |  |
| Okta | Okta | Identity management platform | n/a (customer subscription) |  |
| JWT | JWT | Token-based authentication | n/a |  |
| Let's Encrypt | Let's Encrypt | Free SSL certificates | n/a |  |
| r2c | Semgrep | Static security analysis | n/a (open source) |  |
| PyCQA | bandit | Python security scanner | n/a |  |
| Zricethezav | GitLeaks | Secret scanning | n/a |  |
| GitHub | Dependabot | Dependency vulnerability scanning | n/a |  |

## Testing & Quality Assurance

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| pytest | pytest | Python testing | n/a |  |
| Meta | Jest | JavaScript testing | n/a |  |
| Microsoft | Playwright | End-to-end browser testing | n/a |  |
| Grafana Labs | k6 | Load and performance testing | n/a |  |
| Hypothesis | Hypothesis | Property-based testing | n/a |  |
| ESLint | ESLint | JavaScript/TypeScript linting | n/a |  |
| PSF | Black | Python code formatting | n/a |  |
| PyCQA | isort | Python import sorting | n/a |  |
| Python | mypy | Python type checking | n/a |  |

## Communication & Integration Tools

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Slack | Slack | Integration plugin for customer notifications | n/a (customer subscription) |  |
| Microsoft | Microsoft Teams | Integration plugin for customer collaboration | n/a (customer subscription) |  |
| AWS | AWS SES | Email delivery service | $0.10/1000 emails |  |
| Various | Email/SMTP | Email notifications | $5-50/month |  |

## Enterprise Integrations

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Atlassian | Jira | Integration plugin for customer issue tracking | n/a (customer subscription) |  |
| ServiceNow | ServiceNow | Integration plugin for customer ITSM | n/a (customer subscription) |  |
| Salesforce | Salesforce | Integration plugin for customer CRM | n/a (customer subscription) |  |
| PagerDuty | PagerDuty | Integration plugin for customer alerting | n/a (customer subscription) |  |
| OpenLDAP | LDAP | Directory service integration | n/a (customer infrastructure) |  |

## Development Environment Tools

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Docker | Docker | Containerization | n/a |  |
| CNCF | Kubernetes | Container orchestration | n/a |  |
| containerd | containerd | Container runtime | n/a |  |
| Amazon Web Services (AWS) | AWS CLI | AWS command-line interface | n/a |  |
| Kubernetes | kubectl | Kubernetes CLI | n/a |  |
| CNCF | helm | Kubernetes package manager | n/a |  |
| Git | git | Version control client | n/a |  |
| Various | curl/wget | HTTP clients for testing | n/a |  |

## Business Intelligence & Analytics

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Custom Development | Custom React Dashboards | Built-in analytics | n/a |  |
| Various | External BI Tool APIs | Integration capabilities for customers | n/a (customer tools) |  |
| Custom Development | PDF/CSV Export | Report generation | n/a |  |

## Cost Optimization Tools

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Amazon Web Services (AWS) | AWS Cost Explorer | Cost analysis and optimization | n/a |  |
| Amazon Web Services (AWS) | AWS Budgets | Cost monitoring and alerts | n/a |  |
| Amazon Web Services (AWS) | Spot Instances | Reduced compute costs | 50-90% savings |  |
| Amazon Web Services (AWS) | Resource Tagging | Cost allocation and tracking | n/a |  |

## Documentation & Knowledge Management

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| Various | Markdown | Documentation format | n/a |  |
| Meta | Docusaurus | Documentation sites | n/a |  |
| GitBook | GitBook | Documentation platform | $6.70-12.50/user/month |  |
| OpenAPI | OpenAPI 3.0 | API documentation | n/a |  |
| Storybook | Storybook | Component documentation | n/a |  |

## Compliance & Audit Tools

| Vendor | Service/Tool | Purpose | Monthly Cost | Replace |
|--------|--------------|---------|--------------|---------|
| AICPA | SOC 2 Type II | Security compliance | $15,000-50,000/year audit |  |
| NIST | NIST Cybersecurity Framework | Security standards | n/a |  |
| ISO | ISO 27001 | Information security management | $10,000-30,000/year audit |  |

## Total Estimated Costs

### Development Environment (Months 1-3)
- **AWS Infrastructure**: ~$340/month
- **MythX API**: ~$200/month
- **GitHub (Dev Licenses)**: ~$8/month
- **Domain**: ~$20/year
- **Total Development**: ~$548/month

### Production Environment (Month 4+)
- **AWS Infrastructure**: ~$1,300/month
- **MythX API**: ~$500/month
- **GitHub (Dev Licenses)**: ~$8/month
- **Documentation Platform**: ~$15/month (optional)
- **Total Production**: ~$1,823/month

*Note: Costs are estimates and may vary based on usage, team size, and specific requirements. Customer integrations (Slack, Teams, Jira, etc.) use customer subscriptions - we only provide plugins/connectors.*