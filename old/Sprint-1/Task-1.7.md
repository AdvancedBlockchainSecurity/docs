# Task 1.7: Monitoring and Observability Setup - Objectives & Implementation Details

**✅ ALIGNMENT CHECK**: This implementation establishes comprehensive monitoring and observability infrastructure using Prometheus and Grafana as specified in Sprint 1 documentation.

## High-Level Objectives

### Primary Goal
Deploy comprehensive monitoring and observability stack with Prometheus metrics collection, Grafana visualization, Loki log aggregation, and AlertManager for alerting.

### Key Requirements (from docs)
- **Metrics Collection**: Prometheus for cluster and application metrics
- **Visualization**: Grafana with HashiCorp Vault Community Edition integration in monitoring-local, monitoring-staging and monitoring-production namespaces
- **Logging**: Loki for log aggregation with Fluent Bit for log collection
- **Alerting**: AlertManager for routing and notification management

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Directory Structure Requirements

```
blocksecops-monitoring/
└── k8s/
    ├── base/                      # Kustomize base configurations
    │   ├── prometheus/
    │   │   ├── kustomization.yaml # Prometheus base config
    │   │   ├── deployment.yaml    # Prometheus deployment
    │   │   ├── configmap.yaml     # Prometheus configuration
    │   │   ├── service.yaml       # Prometheus service
    │   │   └── rbac.yaml          # Prometheus RBAC
    │   ├── grafana/
    │   │   ├── kustomization.yaml # Grafana base config
    │   │   ├── deployment.yaml    # Grafana deployment
    │   │   ├── configmap.yaml     # Grafana configuration
    │   │   ├── dashboards/        # Dashboard ConfigMaps
    │   │   └── secret.yaml        # Grafana admin credentials
    │   ├── node-exporter/
    │   │   ├── kustomization.yaml # Node Exporter base config
    │   │   ├── daemonset.yaml     # Node Exporter DaemonSet
    │   │   └── service.yaml       # Node Exporter service
    │   ├── alertmanager/
    │   │   ├── kustomization.yaml # AlertManager base config
    │   │   ├── deployment.yaml    # AlertManager deployment
    │   │   └── configmap.yaml     # AlertManager configuration
    │   ├── loki/
    │   │   ├── kustomization.yaml # Loki base config
    │   │   ├── deployment.yaml    # Loki deployment
    │   │   ├── configmap.yaml     # Loki configuration
    │   │   └── service.yaml       # Loki service
    │   └── fluent-bit/
    │       ├── kustomization.yaml # Fluent Bit base config
    │       ├── daemonset.yaml     # Fluent Bit DaemonSet
    │       ├── configmap.yaml     # Fluent Bit configuration
    │       └── rbac.yaml          # Fluent Bit RBAC
    └── overlays/                  # Environment-specific overlays
        ├── local/                 # Local development overlay
        │   ├── kustomization.yaml # Local development customizations
        │   ├── prometheus-patch.yaml # Local Prometheus config
        │   ├── grafana-patch.yaml # Local Grafana config
        │   ├── loki-patch.yaml    # Local Loki config
        │   ├── fluent-bit-patch.yaml # Local Fluent Bit config
        │   └── retention-patch.yaml # Local retention policies
        ├── staging/               # Staging monitoring overlay
        │   ├── kustomization.yaml # Staging customizations
        │   ├── prometheus-patch.yaml # Staging Prometheus config
        │   ├── grafana-patch.yaml # Staging Grafana config
        │   ├── loki-patch.yaml    # Staging Loki config
        │   ├── fluent-bit-patch.yaml # Staging Fluent Bit config
        │   └── retention-patch.yaml # Staging retention policies
        └── production/            # Production monitoring overlay
            ├── kustomization.yaml # Production customizations
            ├── prometheus-patch.yaml # Production Prometheus config
            ├── grafana-patch.yaml # Production Grafana config
            ├── loki-patch.yaml    # Production Loki config
            ├── fluent-bit-patch.yaml # Production Fluent Bit config
            └── retention-patch.yaml # Production retention policies
```

## Step 1: Prometheus Deployment and Configuration (1.5 hours)

### Objectives
- Deploy Prometheus for metrics collection in monitoring-local, monitoring-staging and monitoring-production namespaces
- Configure service discovery for automatic target detection
- Set up metrics collection from cluster components and applications

### Key Components to Implement
- **Kustomize Base Manifests**: Base Prometheus configuration with RBAC
- **Environment Overlays**: Staging vs production retention and resource limits
- **Service Discovery**: Automatic discovery of Kubernetes services and pods
- **Metrics Collection**: Cluster, node, and application metrics via Kustomize

### Technical Requirements
- Prometheus deployment with persistent storage
- Service monitors for automatic target discovery
- Metrics retention policies appropriate for environment
- Integration with Kubernetes API for service discovery

### Performance Goals
- Efficient metrics collection with minimal cluster impact
- Appropriate retention policies balancing storage and historical data

## Step 2: Grafana Deployment and Integration (1 hour)

### Objectives
- Deploy Grafana with HashiCorp Vault Community Edition integration in monitoring-local, monitoring-staging and monitoring-production namespaces
- Configure data sources for Prometheus
- Create initial platform health dashboards

### Key Components to Implement
- **Kustomize Base Manifests**: Base Grafana deployment with ConfigMaps
- **Environment Overlays**: Environment-specific dashboard and data source configurations
- **Vault Integration**: HashiCorp Vault Community Edition integration via Vault Secrets Operator
- **Data Sources**: Prometheus data source configuration via Kustomize

### Integration Strategy
- Kustomize-based deployment with environment-specific configurations
- Vault Secrets Operator integration for Grafana credentials
- Multi-environment dashboard organization via Kustomize overlays
- Role-based access control for team members

## Step 3: Loki and Fluent Bit Logging Setup (1 hour)

### Objectives
- Deploy Loki for log aggregation and storage
- Deploy Fluent Bit for log collection from all pods and nodes
- Integrate logging with Grafana for unified observability

### Key Components to Implement
- **Kustomize Base Manifests**: Base Loki and Fluent Bit configurations
- **Environment Overlays**: Environment-specific log retention and resource limits
- **Log Collection**: Fluent Bit DaemonSet for comprehensive log collection
- **Grafana Integration**: Loki data source configuration for log querying

### Integration Strategy
- Kustomize-based deployment with environment-specific configurations
- Fluent Bit deployed as DaemonSet for node-level log collection
- Loki storage optimized for cost-effective log retention
- Native Grafana integration for unified metrics and logs view

## Step 4: AlertManager Setup and Alerting (30 minutes)

### Objectives
- Configure AlertManager for alert routing and notification
- Set up service monitoring and alerting rules
- Create platform health dashboards and alerts

### Core Dependencies
- **AlertManager Integration**: Alert routing and notification management
- **Alert Rules**: Infrastructure health and performance alerting
- **Dashboard Creation**: Initial monitoring dashboards for platform health

### Integration Requirements
- Prometheus metrics from EKS, pods, and infrastructure services
- Log aggregation from application and infrastructure components via Loki + Fluent Bit
- Alert routing and notification configuration

## Success Criteria & Validation

### Prometheus Monitoring Requirements
- [ ] Prometheus operational in staging cluster with metrics collection
- [ ] Prometheus operational in production cluster with metrics collection
- [ ] Service discovery functional for automatic target detection
- [ ] Cluster metrics (nodes, pods, services) being collected
- [ ] Application metrics collection configured and functional

### Grafana Visualization Requirements
- [ ] Grafana deployed with HashiCorp Vault Community Edition credential integration in monitoring-local, monitoring-staging and monitoring-production namespaces
- [ ] Prometheus data sources configured and operational
- [ ] Initial platform health dashboards created and functional
- [ ] Role-based access control configured for team access

### Loki and Fluent Bit Logging Requirements
- [ ] Loki deployed and operational for log aggregation and storage
- [ ] Fluent Bit deployed as DaemonSet for log collection from all pods and nodes
- [ ] Loki data source configured in Grafana for log querying
- [ ] Log retention policies configured for staging and production environments
- [ ] Unified metrics and logs view operational in Grafana dashboards

### AlertManager and Alerting Requirements
- [ ] AlertManager deployed and operational for alert routing
- [ ] Basic alerting rules configured for infrastructure health
- [ ] Alert routing configured for team notification via AlertManager
- [ ] Platform health monitoring dashboards displaying real-time data

## Implementation Priority

### Phase 1: Prometheus Deployment (1.5 hours)
1. Deploy Prometheus server with persistent storage
2. Configure service discovery and metrics collection rules
3. Set up service monitors for automatic target detection and validation

### Phase 2: Grafana and Visualization (1 hour)
1. Deploy Grafana with Vault Secrets Operator integration
2. Configure Prometheus data sources
3. Create initial platform health and infrastructure dashboards

### Phase 3: Loki and Fluent Bit Logging (1 hour)
1. Deploy Loki for log aggregation and storage
2. Deploy Fluent Bit DaemonSet for comprehensive log collection
3. Configure Loki data source in Grafana for unified observability

### Phase 4: AlertManager and Alerting (30 minutes)
1. Deploy AlertManager for alert routing and notification management
2. Set up basic alerting rules for infrastructure health monitoring
3. Create notification routing via AlertManager and validate alert delivery

## Key Implementation Notes

1. **Resource Management**: Configure appropriate resource limits for monitoring components
2. **Data Retention**: Set retention policies balancing storage costs with historical data needs
3. **Security**: Use Vault Secrets Operator for all monitoring credential management
4. **Dashboard Organization**: Create environment-specific dashboard folders for clear organization

---

**Estimated Time**: 4 hours
**Owner**: DevOps Team
**Priority**: P1 (High)

## Task Checklist

### Local Development Environment
- [ ] prometheus Helm chart installed in minikube
- [ ] Prometheus configured for local development metrics collection
- [ ] Grafana configured with development dashboards and data sources
- [ ] Local alerting configured for development monitoring
- [ ] Local log collection configured via Fluent Bit or built-in logging
- [ ] Development metrics and monitoring accessible via port forwarding
- [ ] Local dashboard for platform development health monitoring
- [ ] Development alert testing and validation completed

### Staging Environment
- [ ] Kustomize base manifests created for Prometheus monitoring stack
- [ ] Environment overlays configured for staging monitoring infrastructure
- [ ] Prometheus deployed in monitoring-staging namespace with persistent storage
- [ ] Service discovery configured for automatic target detection in staging
- [ ] Staging cluster and node metrics collection operational
- [ ] Application metrics collection configured for staging services
- [ ] Grafana deployed with HashiCorp Vault integration in monitoring-staging namespace
- [ ] Prometheus data sources configured in staging Grafana
- [ ] Staging platform health dashboards created and functional
- [ ] Loki deployed and operational for staging log aggregation
- [ ] Fluent Bit deployed as DaemonSet for staging log collection
- [ ] Staging unified metrics and logs view functional in Grafana

### Production Environment
- [ ] Production overlays configured for monitoring infrastructure
- [ ] Prometheus deployed in monitoring-production namespace with persistent storage
- [ ] Production service discovery configured for automatic target detection
- [ ] Production cluster and node metrics collection operational
- [ ] Production application metrics collection configured
- [ ] Grafana deployed with HashiCorp Vault integration in monitoring-production namespace
- [ ] Production Prometheus data sources configured in Grafana
- [ ] Production platform health dashboards created and optimized
- [ ] Role-based access control configured for production Grafana
- [ ] Production Loki deployed and operational for log aggregation
- [ ] Production Fluent Bit deployed as DaemonSet for comprehensive log collection
- [ ] Production unified metrics and logs view functional in Grafana
- [ ] Production alerting rules configured for infrastructure health
- [ ] Alert routing and notification configured for production alerts
- [ ] Production monitoring validated and fully operational