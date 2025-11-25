# Kubernetes Kustomize Structure Template - Production Systems

Use this template to generate a production-ready Kustomize folder structure with local, staging and production overlays.

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

---

## Standard Folder Structure

```
k8s/
├── base/
│   └── <service-name>/
│       ├── kustomization.yaml
│       ├── <workload-type>.yaml (deployment.yaml OR statefulset.yaml)
│       ├── service.yaml
│       ├── configmap.yaml
│       ├── [optional] pvc.yaml (for stateful services)
│       ├── [optional] secret.yaml
│       ├── [optional] serviceaccount.yaml
│       ├── [optional] ingress.yaml
│       ├── [optional] ingressroute.yaml (Traefik HTTP routing)
│       ├── [optional] ingressroute-tcp.yaml (Traefik TCP routing)
│       └── [optional] middleware-*.yaml (Traefik middlewares)
│       └── [optional] rbac files (clusterrole.yaml, clusterrolebinding.yaml, rolebinding.yaml)
│
└── overlays/
    ├── local/
    │   ├── kustomization.yaml
    │   └── <service-name>/
    │       ├── kustomization.yaml
    │       ├── namespace.yaml
    │       ├── <workload-type>-patch.yaml
    │       ├── configmap-patch.yaml
    │       ├── [optional] service-patch.yaml
    │       ├── [optional] ingress-patch.yaml
    │       ├── [optional] ingressroute.yaml (Traefik HTTP routing)
    │       ├── [optional] ingressroute-tcp.yaml (Traefik TCP routing)
    │       ├── [optional] middleware-cors.yaml (Traefik CORS)
    │       ├── [optional] middleware-*.yaml (other Traefik middlewares)
    │       └── [optional] pvc-patch.yaml
    │
    ├── staging/
    │   ├── kustomization.yaml
    │   └── <service-name>/
    │       ├── kustomization.yaml
    │       ├── namespace.yaml
    │       ├── <workload-type>-patch.yaml
    │       ├── configmap-patch.yaml
    │       ├── [optional] service-patch.yaml
    │       ├── [optional] ingress-patch.yaml
    │       ├── [optional] ingressroute.yaml (Traefik HTTP routing)
    │       ├── [optional] ingressroute-tcp.yaml (Traefik TCP routing)
    │       ├── [optional] middleware-cors.yaml (Traefik CORS)
    │       ├── [optional] middleware-*.yaml (other Traefik middlewares)
    │       └── [optional] pvc-patch.yaml
    │
    └── production/
        ├── kustomization.yaml
        └── <service-name>/
            ├── kustomization.yaml
            ├── namespace.yaml
            ├── <workload-type>-patch.yaml
            ├── configmap-patch.yaml
            ├── [optional] service-patch.yaml
            ├── [optional] ingress-patch.yaml
            ├── [optional] pvc-patch.yaml
            ├── [optional] hpa.yaml
            ├── [optional] pdb.yaml (PodDisruptionBudget)
            ├── [optional] networkpolicy.yaml
            ├── [optional] servicemonitor.yaml (for Prometheus)
            ├── [optional] backup-cronjob.yaml (for databases)
            ├── [optional] resourcequota.yaml
            ├── [optional] limitrange.yaml
            ├── [optional] externalsecret.yaml (if using External Secrets Operator)
            ├── [optional] vault-policy.yaml (Vault policy for service)
            ├── [optional] certificate.yaml (if using cert-manager)
            ├── [optional] priorityclass.yaml
            ├── [optional] virtualservice.yaml (if using Istio)
            ├── [optional] destinationrule.yaml (if using Istio)
            └── [optional] gateway.yaml (if using Istio for ingress)
```

---

## Namespace Strategy

**Production Standard: Per-Service Namespaces**

Each service gets its own namespace for:
- Security isolation between services
- Independent RBAC policies
- Resource quota management per service
- Network policy enforcement
- Clear blast radius
- Multi-tenant support

**Naming Convention:**
- Local: `<service-name>-local`
- Staging: `<service-name>-staging`
- Production: `<service-name>-prod`

---

## Service Classification

### Stateless Services (Use Deployment)
- Web applications and APIs
- Microservices
- Caching layers (Redis without persistence)
- Message queue consumers
- Monitoring tools (Grafana, Prometheus)
- Proxy/Gateway services (Nginx, Envoy, Kong)

**Required base files:**
- deployment.yaml
- service.yaml
- configmap.yaml

**Required production additions:**
- hpa.yaml
- pdb.yaml

### Stateful Services (Use StatefulSet)
- Databases (PostgreSQL, MySQL, MongoDB, CockroachDB)
- Message brokers with persistence (Kafka, RabbitMQ, NATS)
- Distributed coordination (Vault, etcd, Consul, ZooKeeper)
- Search engines (Elasticsearch, OpenSearch)
- Time-series databases (InfluxDB, TimescaleDB)

**Required base files:**
- statefulset.yaml
- service.yaml (headless service)
- configmap.yaml
- pvc.yaml
- secret.yaml

**Required production additions:**
- backup-cronjob.yaml
- pdb.yaml
- Larger PVC sizes

### Services Requiring RBAC
- Monitoring (Prometheus, Grafana with K8s plugin)
- Service meshes (Istio, Linkerd)
- Operators and controllers
- CI/CD tools (ArgoCD, Flux, Tekton)
- Log collectors (Fluentd, Fluent Bit)
- Security tools (Falco, Cert-Manager)

**Additional base files:**
- serviceaccount.yaml
- clusterrole.yaml or role.yaml
- clusterrolebinding.yaml or rolebinding.yaml

---

## Production-Specific Resources

### Always Include in Production

**For All Services:**
- namespace.yaml (per-service)
- resourcequota.yaml (namespace-level quotas)
- limitrange.yaml (default resource limits)
- networkpolicy.yaml (network isolation)

**For Stateless Services:**
- hpa.yaml (Horizontal Pod Autoscaler)
- pdb.yaml (PodDisruptionBudget)
- servicemonitor.yaml (if using Prometheus Operator)

**For Stateful Services:**
- backup-cronjob.yaml (automated backups)
- restore-job.yaml (restore procedures)
- pdb.yaml (with careful configuration)
- volumesnapshot.yaml (if CSI driver supports it)

**For Internet-Facing Services:**
- ingress.yaml with TLS configuration
- certificate.yaml (if using cert-manager)
- gateway.yaml (if using Istio)
- virtualservice.yaml (if using Istio)
- externalDNS annotations

**For Services with Secrets:**
- externalsecret.yaml (if using External Secrets Operator)
- vault-policy.yaml (Vault policy defining access permissions)

**For Critical Services:**
- priorityclass.yaml (high priority scheduling)

---

## Environment-Specific Patterns

### Local Environment (Minikube)
- **Platform**: Minikube with local Docker registry
- **Namespace per service**: `<service>-local`
- **Replicas**: 1 for all services
- **Resources**: Minimal limits (25-40% of production)
- **Storage**: Small PVC sizes (1-5Gi)
- **Logging**: Debug level
- **Monitoring**: Prometheus and Grafana (lightweight configuration)
- **Backups**: Disabled
- **HPA**: Disabled
- **PDB**: Not required
- **Network Policies**: Optional
- **Ingress**: Traefik v3.6+ ingress controller
- **Secret Management**: Vault Community Edition (single replica)
- **Certificates**: Self-signed certificates via cert-manager
- **Service Mesh**: Optional (can be disabled for resource savings)
- **Database**: Lightweight PostgreSQL and Redis configurations
- **Image Tags**: Use `latest` tag in kustomization (see `/Users/pwner/Git/ABS/docs/standards/docker-image-versioning.md`)

### Staging Environment
- **Namespace per service**: `<service>-staging`
- **Replicas**: 1 for most services
- **Resources**: Lower limits (50-70% of production)
- **Storage**: Smaller PVC sizes
- **Logging**: Debug level
- **Monitoring**: Basic metrics
- **Backups**: Optional or less frequent
- **HPA**: Usually disabled
- **PDB**: Not required
- **Network Policies**: Optional
- **Ingress**: May use shared ingress or NodePort

### Production Environment
- **Namespace per service**: `<service>-prod`
- **Replicas**: 2-3+ for high availability
- **Resources**: Production-grade limits
- **Storage**: Sized for growth (+ 30-50% buffer)
- **Logging**: Info or warn level
- **Monitoring**: Full observability (metrics, logs, traces)
- **Backups**: Mandatory for stateful services
- **HPA**: Enabled for scalable services
- **PDB**: Required for HA services
- **Network Policies**: Strictly enforced
- **Ingress**: TLS-enabled with proper DNS

---

## Patch File Patterns

### deployment-patch.yaml / statefulset-patch.yaml
Common patches:
- Resource requests and limits
- Security context (runAsNonRoot, readOnlyRootFilesystem)
- Health checks (liveness, readiness, startup probes)
- Affinity rules (pod anti-affinity for HA)
- Tolerations and node selectors
- Image pull policy
- Termination grace period
- Volume mounts
- Init containers

### configmap-patch.yaml
Environment-specific configuration:
- Service endpoints and URLs
- Database connection strings
- Feature flags
- Log levels
- Timeout values
- Cache configurations
- Rate limiting settings
- External service integrations

### service-patch.yaml
- Service type (ClusterIP, LoadBalancer, NodePort)
- Load balancer annotations
- Session affinity
- External traffic policy

### pvc-patch.yaml
- Storage size (staging: smaller, production: larger)
- Storage class (fast SSD for production)
- Access modes
- Volume expansion settings

### ingress-patch.yaml
- Hostnames (staging vs production domains)
- TLS certificates
- Annotations (load balancer, WAF, rate limiting)
- Path routing rules
- CORS settings

---

## Additional Production Resources

### networkpolicy.yaml
Restrict network traffic:
- Default deny all ingress/egress
- Allow specific service-to-service communication
- Allow DNS
- Allow monitoring scraping

### pdb.yaml (PodDisruptionBudget)
Ensure availability during updates:
- For stateless: `minAvailable: 1` or `maxUnavailable: 1`
- For stateful: Very conservative (consider `maxUnavailable: 0` during critical periods)

### servicemonitor.yaml
Prometheus Operator integration:
- Metrics endpoint configuration
- Scrape interval
- Labels for prometheus selection

### resourcequota.yaml
Per-namespace limits:
- CPU and memory limits
- Pod count limits
- PVC storage limits
- ConfigMap and Secret limits

### limitrange.yaml
Default resource constraints:
- Default CPU/memory requests
- Default CPU/memory limits
- Min/max boundaries

---

## Cross-Cutting Concerns

### Secrets Management
**MANDATORY: All secrets MUST be stored in Vault and pulled via External Secrets Operator.**
**Production systems should NEVER store secrets in Git.**

Standardized approach for all environments:
- **Vault Community Edition**: Secret storage backend
- **External Secrets Operator**: Secret synchronization to Kubernetes
- **SecretStore/ClusterSecretStore**: Per-namespace vault backend configuration
- **ExternalSecret**: Per-service secret retrieval manifests
- **Vault Policies**: Service-specific access control

Template structure includes:
```
overlays/local/<service>/
├── externalsecret.yaml (if using External Secrets Operator)
└── vault-policy.yaml (Vault policy for the service)

overlays/staging/<service>/
├── externalsecret.yaml (if using External Secrets Operator)
└── vault-policy.yaml (Vault policy for the service)

overlays/production/<service>/
├── externalsecret.yaml (if using External Secrets Operator)
└── vault-policy.yaml (Vault policy for the service)
```

### GitOps Integration
Structure supports:
- ArgoCD Application manifests
- Flux Kustomization resources
- Tekton PipelineRuns

Add to repository root:
```
k8s/
├── argocd/
│   ├── staging-apps/
│   │   └── <service>-app.yaml
│   └── production-apps/
│       └── <service>-app.yaml
```

### Service Mesh Integration
For Istio/Linkerd add to each service overlay:
```
overlays/local/<service>/
├── virtualservice.yaml (if using Istio)
├── destinationrule.yaml (if using Istio)
└── ingress.yaml (nginx ingress for local)

overlays/staging/<service>/
├── virtualservice.yaml
├── destinationrule.yaml
└── gateway.yaml (for ingress services)

overlays/production/<service>/
├── virtualservice.yaml
├── destinationrule.yaml
└── gateway.yaml (for ingress services)
```

---

## Labels and Annotations

### Standard Labels
All resources should include standard Kubernetes labels using the `labels` field (not deprecated `commonLabels`):

**In kustomization.yaml:**
```yaml
labels:
- pairs:
    app.kubernetes.io/name: <service>
    app.kubernetes.io/instance: <environment>-<service>
    app.kubernetes.io/version: <version>
    app.kubernetes.io/component: <component-type>
    app.kubernetes.io/part-of: <application-name>
    app.kubernetes.io/managed-by: kustomize
    environment: <local|staging|production>
    team: <team-name>
```

**Note**: Use `labels` with `pairs` syntax, not the deprecated `commonLabels` field.

### Production Annotations
Common production annotations:
- `prometheus.io/scrape: "true"`
- `prometheus.io/port: "<port>"`
- `backup.velero.io/backup-volumes: "<volume-names>"`
- Ingress controller specific annotations
- Service mesh annotations
- Cost allocation tags

---

## Multi-Environment Extension

For additional environments:
```
overlays/
├── local/
├── development/
├── staging/
├── production/
├── dr/ (disaster recovery)
└── performance/ (performance testing)
```

Each follows the same per-service namespace pattern.

---

## Usage Instructions

### Generate New Structure
Provide:
1. **Service name and type** (stateless/stateful)
2. **Special requirements** (RBAC, ingress, public-facing, etc.)
3. **Production constraints** (HA requirements, backup needs, compliance)
4. **Team ownership** (for labels and RBAC)

### Example Request
"Generate a production Kustomize structure for:
- api-gateway (stateless, public-facing, needs ingress and HPA)
- postgresql (stateful, needs backups and PDB)
- redis (stateless cache, internal only)
- prometheus (stateless, needs RBAC, service monitoring)

Use per-service namespaces with network policies."

---

## Quality Checklist

Production-ready structure must have:
- [ ] Per-service namespaces for all services
- [ ] StatefulSet for all stateful workloads
- [ ] Deployment for all stateless workloads
- [ ] HPA for scalable stateless services in production
- [ ] PDB for all HA services in production
- [ ] Backup CronJob for all databases in production
- [ ] Network policies for network isolation
- [ ] Resource quotas and limit ranges
- [ ] RBAC with least privilege principle
- [ ] Health checks (liveness, readiness, startup)
- [ ] Security context (non-root, read-only filesystem where possible)
- [ ] Service monitors for metrics collection
- [ ] Proper resource requests and limits
- [ ] Anti-affinity rules for HA deployments
- [ ] TLS for all external-facing services
- [ ] Secrets managed externally (not in Git)
- [ ] Complete labels following kubernetes standards
- [ ] Documentation of service dependencies

---

## Local Development Environment Setup

### Minikube Configuration

**Required Components for Local Development:**
- Minikube with adequate resources (8GB+ RAM, 4+ CPU cores)
- Traefik v3.6+ Ingress Controller (modern, production-ready)
- Vault Community Edition (single replica)
- Prometheus and Grafana (lightweight monitoring)
- PostgreSQL and Redis (development configurations)
- cert-manager with self-signed certificate issuer

**Local Overlay Specifications:**
```yaml
# Example local overlay patch
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-name
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: service-name
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

**Local Environment Variables:**
- `ENVIRONMENT=local`
- `LOG_LEVEL=debug`
- `VAULT_ADDR=http://vault.vault-local.svc.cluster.local:8200`
- `PROMETHEUS_URL=http://prometheus.monitoring-local.svc.cluster.local:9090`
- `GRAFANA_URL=http://grafana.monitoring-local.svc.cluster.local:3000`

---

## Anti-Patterns to Avoid

**DO NOT:**
- Share namespaces between services in production
- Store ANY secrets in Git (hardcoded passwords, API keys, certificates)
- Create Kubernetes Secret resources directly (use ExternalSecret only)
- Bypass Vault for secret storage (all secrets must go through Vault)
- Run production without PodDisruptionBudgets
- Skip backup strategies for stateful services
- Use `latest` image tags in production (local development uses `latest` - see docker-image-versioning.md)
- Run containers as root
- Deploy without resource limits
- Skip network policies
- Use single replica for critical services
- Ignore security contexts
- Deploy without health checks
- Skip monitoring integration