# Deployment Documentation

**Last Updated**: November 21, 2025
**Platform**: Apogee Security Platform
**Deployment Targets**: AWS EKS (Production), Minikube (Local)

---

## Overview

Comprehensive deployment guides for the Apogee Platform infrastructure components. This directory contains production deployment procedures, local configuration guides, and troubleshooting documentation.

---

## Contents

### 🚀 Service Deployment

Production and local deployment guides for all platform services:

- **[API Service Deployment](services/api-service-deployment.md)** - FastAPI-based API service
  - Production deployment to Kubernetes
  - Argon2id password hashing (OWASP 2025 compliant)
  - Alembic database migrations
  - Multi-language contract support (23 languages)
  - Security hardening checklist

- **[API Service Local Configuration](services/api-service-local-configuration.md)** - Local development setup
  - Minikube deployment
  - Environment variables
  - Database setup
  - Redis configuration
  - Port forwarding

- **[Orchestration Service Deployment](services/orchestration-service-deployment.md)** - Celery-based scan orchestration
  - Gevent worker pool configuration (high concurrency)
  - Dual database session support (sync/async)
  - RedBeat scheduler for distributed environments
  - Scanner integration (Slither, Aderyn, Mythril)
  - Monitoring with Flower and Prometheus

---

### ⚙️ Infrastructure

Infrastructure components and third-party service deployment:

- **[DNS Infrastructure](infrastructure/dns-infrastructure.md)** - Domain and DNS configuration
  - Cloudflare DNS setup
  - SSL/TLS certificate management
  - WAF and DDoS protection
  - Geo-blocking configuration
  - AWS Load Balancer Controller integration

- **[Monitoring Stack](infrastructure/monitoring-stack.md)** - Observability infrastructure
  - Prometheus metrics collection
  - Grafana dashboards
  - Loki log aggregation
  - Fluent Bit log forwarding
  - Alert manager configuration

- **[Vault Community Operations](infrastructure/vault-community-operations.md)** - HashiCorp Vault deployment
  - Vault installation on Kubernetes
  - Initialization and unsealing
  - Secret management workflows
  - External Secrets Operator integration
  - Backup and recovery procedures

---

### 🐳 Docker & Container Management

Docker image standards and scanner container management:

- **[Docker Image Standards](docker/docker-image-standards.md)** - Container image best practices
  - Semantic versioning
  - Multi-stage builds
  - Layer caching optimization
  - Security scanning
  - Registry management

- **[Scanner Docker Images](docker/scanner-docker-images.md)** - Security scanner containerization
  - Scanner image requirements
  - Dockerfile templates
  - Entry script patterns
  - Result webhook integration
  - Testing scanner images

- **[Scanner Execution Architecture](docker/scanner-execution-architecture.md)** - Kubernetes Job-based scanner execution
  - ConfigMap source code delivery
  - Job lifecycle management
  - Resource limits and timeouts
  - Result collection
  - Cleanup strategies

---

### 🔧 Fixes & Patches

Critical bug fixes and their resolutions:

- **[Contract Source Scan Trigger Fix](fixes/contract-source-scan-trigger-fix.md)** ✅ Resolved (Oct 13, 2025)
  - **Issue**: POST `/api/v1/scans` returned 500 error for large contracts
  - **Cause**: Contract source sent as URL query parameter (8KB limit)
  - **Fix**: Changed to JSON request body (deployed in api-service:0.3.8)
  - **Impact**: All contract sizes now scan successfully

---

### 📅 Sprint Documentation

Historical sprint implementation documentation:

- **[Sprint 8: Contract Source Management](sprints/sprint-8-contract-source-management.md)** - Contract source storage feature
  - Database schema changes
  - ConfigMap integration
  - Kubernetes Job workflow
  - End-to-end scanning implementation

---

## Deployment Environments

### Local Development (Minikube)

**Platform**: Minikube with local Docker registry
**Namespace per service**: `<service>-local`

**Configuration**:
- Replicas: 1 for all services
- Resources: Minimal limits (25-40% of production)
- Storage: Small PVC sizes (1-5Gi)
- Logging: Debug level
- Monitoring: Lightweight Prometheus and Grafana
- Backups: Disabled
- HPA: Disabled

**Quick Start**:
```bash
# Start Minikube
minikube start --cpus 4 --memory 8192 --disk-size 50g

# Deploy local environment
kubectl apply -k k8s/overlays/local

# Port forward services
kubectl port-forward svc/api-service 8000:80 -n api-service-local
kubectl port-forward svc/grafana 3000:80 -n monitoring-local
```

### Production (AWS EKS)

**Platform**: AWS EKS with Harbor registry
**Namespace per service**: `<service>-prod`

**Configuration**:
- Replicas: 2-3+ for high availability
- Resources: Production-grade limits
- Storage: Sized for growth (+ 30-50% buffer)
- Logging: Info/warn level
- Monitoring: Full observability stack
- Backups: Mandatory for stateful services
- HPA: Enabled for scalable services

**Deployment**:
```bash
# Tag and push images
docker tag api-service:0.4.0 registry.0xapogee.com/api-service:0.4.0
docker push registry.0xapogee.com/api-service:0.4.0

# Deploy via ArgoCD (GitOps)
argocd app sync api-service-prod

# Or manual deployment
kubectl apply -k k8s/overlays/production/api-service
```

---

## Service Dependencies

### Infrastructure Requirements

All services require:
- **PostgreSQL 15+** - Primary database
- **Redis 7.x** - Session storage and caching
- **Kubernetes** - Container orchestration
- **Vault** - Secret management

### Service Map

```
┌─────────────────┐
│   API Service   │ (Port 8000)
│   Namespace:    │
│   api-service-* │
└────────┬────────┘
         │
         ├─────→ PostgreSQL (StatefulSet)
         ├─────→ Redis (StatefulSet)
         ├─────→ Vault (External Secrets)
         │
         └─────→ ┌──────────────────────┐
                 │ Orchestration Service │ (Port 8005)
                 │     Namespace:        │
                 │ orchestration-*       │
                 └──────────┬────────────┘
                            │
                            ├─────→ PostgreSQL
                            ├─────→ Redis (Celery backend)
                            │
                            └─────→ Scanner Jobs (Kubernetes Jobs)
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] **Environment Variables** - All secrets in Vault
- [ ] **Database Migrations** - Alembic migrations applied
- [ ] **Docker Images** - Built and pushed to registry
- [ ] **Kubernetes Manifests** - Reviewed and updated
- [ ] **Resource Limits** - CPU/memory configured appropriately
- [ ] **Health Checks** - Liveness and readiness probes configured
- [ ] **Monitoring** - Prometheus ServiceMonitor created

### Deployment

- [ ] **Apply Manifests** - `kubectl apply -k k8s/overlays/<env>`
- [ ] **Verify Pods** - All pods running and ready
- [ ] **Check Logs** - No error messages in startup logs
- [ ] **Test Health** - `/health` endpoints responding
- [ ] **Verify Database** - Migrations applied, data accessible
- [ ] **Test API** - Sample requests successful

### Post-Deployment

- [ ] **Monitor Metrics** - Check Grafana dashboards
- [ ] **Verify Logs** - Log aggregation working
- [ ] **Test E2E** - Complete user workflow tested
- [ ] **Document Changes** - Update [CHANGELOG](CHANGELOG.md)
- [ ] **Notify Team** - Deployment announcement
- [ ] **Rollback Plan** - Rollback procedure documented

---

## Versioning Strategy

### Semantic Versioning

**Format**: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (API incompatibility)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

**Examples**:
- `0.4.12` - Patch release (bug fix)
- `0.5.0` - Minor release (new features - Projects)
- `1.0.0` - Major release (stable API)

### Docker Image Tags

**Production**:
```bash
registry.0xapogee.com/api-service:0.4.12  # Specific version
registry.0xapogee.com/api-service:0.4     # Minor version
registry.0xapogee.com/api-service:latest  # Latest stable
```

**Local Development**:
```bash
api-service:latest  # Always use latest for local
```

See: [Docker Image Standards](docker/docker-image-standards.md)

---

## Monitoring & Observability

### Health Checks

**Kubernetes Probes**:
```yaml
livenessProbe:
  httpGet:
    path: /api/v1/health/live
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /api/v1/health/ready
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 5
```

### Metrics

**Prometheus Metrics**:
- Request rate and latency
- Database query performance
- Error rates by endpoint
- Active user sessions
- Scanner job statistics

**Grafana Dashboards**:
- API Service Overview
- Database Performance
- Scanner Execution
- User Activity

See: [Monitoring Stack](infrastructure/monitoring-stack.md)

---

## Troubleshooting

### Common Issues

**Pod CrashLoopBackOff**:
```bash
# Check logs
kubectl logs <pod-name> -n <namespace>

# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Database connection failed
# - Missing environment variables
# - Resource limits too low
```

**Database Connection Errors**:
```bash
# Test connection
kubectl exec -it <pod-name> -n <namespace> -- psql -h postgres -U postgres

# Common causes:
# - PostgreSQL not ready
# - Wrong credentials in Vault
# - Network policy blocking
```

**Scanner Jobs Not Starting**:
```bash
# Check jobs
kubectl get jobs -n api-service-prod

# Check configmaps
kubectl get configmaps -n api-service-prod | grep contract-source

# Common causes:
# - ConfigMap not created
# - Image pull error
# - Insufficient resources
```

---

## Release Process

### Standard Release

1. **Create Git Tag**
   ```bash
   git tag -a v0.4.12 -m "Release v0.4.12: Gas analysis bug fix"
   git push origin v0.4.12
   ```

2. **GitHub Actions** - Automatically:
   - Builds Docker image
   - Pushes to registry
   - Updates Kubernetes manifests

3. **ArgoCD Sync** - Deploys to production:
   ```bash
   argocd app sync api-service-prod
   ```

4. **Verify Deployment**:
   ```bash
   kubectl get pods -n api-service-prod
   curl https://api.0xapogee.com/api/v1/health
   ```

5. **Update Changelog**:
   - Document changes in [CHANGELOG](CHANGELOG.md)

---

## Related Documentation

### Development
- [Local Development Setup](../local-development/README.md)
- [Development Workflow](../local-development/development-workflow.md)

### Architecture
- [API Service Architecture](../architecture/api-service-architecture.md)
- [Scanner Integration Architecture](../architecture/phase-4e-scanner-integration-architecture.md)

### Operations
- [Monitoring Guide](infrastructure/monitoring-stack.md)
- [Vault Operations](infrastructure/vault-community-operations.md)

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

**Latest Release**: v0.4.12 (October 28, 2025)
- Gas analysis module fix
- Renamed models/ to specialized_models/

**Previous Release**: v0.4.0 (October 2025)
- Multi-file and multi-language support
- Supabase Auth integration

---

**Maintained by**: Apogee DevOps Team
**Last Review**: November 21, 2025
**Emergency Contact**: devops@0xapogee.com
