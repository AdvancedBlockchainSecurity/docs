# Task 2.6: Monitoring Stack Integration

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 5 hours
**Owner**: DevOps Team
**Priority**: P1 (High)
**Day**: 5-6

## Objective

Deploy and integrate comprehensive Prometheus + Grafana + Loki Stack monitoring across all environments, providing complete observability for infrastructure components and preparing for application monitoring.

## Technical Requirements

### Core Monitoring Components
- **Prometheus**: Metrics collection, storage, and alerting
- **Grafana**: Visualization dashboards and analytics
- **Loki + Fluent Bit**: Centralized logging and log aggregation
- **AlertManager**: Alert routing and notification management
- **Node Exporter**: System-level metrics collection

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

### Kustomize Structure Implementation
```yaml
monitoring/
├── prometheus/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── prometheus-deployment.yaml
│   │   ├── prometheus-config.yaml
│   │   ├── prometheus-rules.yaml
│   │   ├── service-monitor.yaml
│   │   └── rbac.yaml
│   └── overlays/
│       ├── local/
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── prometheus-config-patch.yaml
│       │   └── storage-patch.yaml
│       ├── staging/
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── prometheus-config-patch.yaml
│       │   ├── storage-patch.yaml
│       │   └── ingress.yaml
│       └── production/
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           ├── prometheus-config-patch.yaml
│           ├── storage-patch.yaml
│           ├── ingress.yaml
│           └── security-policies.yaml
├── grafana/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── grafana-deployment.yaml
│   │   ├── grafana-config.yaml
│   │   ├── datasources.yaml
│   │   └── dashboards/
│   │       ├── kubernetes-cluster.json
│   │       ├── istio-service-mesh.json
│   │       ├── cert-manager.json
│   │       └── external-secrets.json
│   └── overlays/
├── loki/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── loki-deployment.yaml
│   │   ├── loki-config.yaml
│   │   └── loki-storage.yaml
│   └── overlays/
├── fluent-bit/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── fluent-bit-daemonset.yaml
│   │   ├── fluent-bit-config.yaml
│   │   └── rbac.yaml
│   └── overlays/
└── alertmanager/
    ├── base/
    │   ├── kustomization.yaml
    │   ├── alertmanager-deployment.yaml
    │   ├── alertmanager-config.yaml
    │   └── notification-templates.yaml
    └── overlays/
```

### Environment-Specific Configuration

**Local Environment (monitoring-local)**:
- Lightweight resource allocation for development
- Local storage for metrics and logs
- Basic dashboards and alerting
- Simple notification setup

**Staging Environment (monitoring-staging)**:
- Production-like resource allocation
- Persistent storage with backup
- Comprehensive dashboards
- Full alerting and notification setup

**Production Environment (monitoring-production)**:
- Optimized resource allocation and performance
- High-availability storage configuration
- Advanced analytics and custom dashboards
- Enterprise alerting and escalation

## Deliverables

### Prometheus Deployment and Configuration
1. **Prometheus Server**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: prometheus
     namespace: monitoring-staging
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: prometheus
     template:
       metadata:
         labels:
           app: prometheus
       spec:
         serviceAccountName: prometheus
         containers:
         - name: prometheus
           image: prom/prometheus:v2.45.0
           ports:
           - containerPort: 9090
             name: web
           args:
           - '--config.file=/etc/prometheus/prometheus.yml'
           - '--storage.tsdb.path=/prometheus'
           - '--web.console.libraries=/usr/share/prometheus/console_libraries'
           - '--web.console.templates=/usr/share/prometheus/consoles'
           - '--storage.tsdb.retention.time=15d'
           - '--web.enable-lifecycle'
           - '--web.enable-admin-api'
           volumeMounts:
           - name: prometheus-config
             mountPath: /etc/prometheus
           - name: prometheus-storage
             mountPath: /prometheus
           resources:
             requests:
               cpu: 500m
               memory: 2Gi
             limits:
               cpu: 2000m
               memory: 8Gi
         volumes:
         - name: prometheus-config
           configMap:
             name: prometheus-config
         - name: prometheus-storage
           persistentVolumeClaim:
             claimName: prometheus-storage
   ```

2. **Prometheus Configuration**:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: prometheus-config
     namespace: monitoring-staging
   data:
     prometheus.yml: |
       global:
         scrape_interval: 15s
         evaluation_interval: 15s

       rule_files:
       - "/etc/prometheus/rules/*.yml"

       alerting:
         alertmanagers:
         - static_configs:
           - targets:
             - alertmanager:9093

       scrape_configs:
       - job_name: 'prometheus'
         static_configs:
         - targets: ['localhost:9090']

       - job_name: 'kubernetes-apiservers'
         kubernetes_sd_configs:
         - role: endpoints
         scheme: https
         tls_config:
           ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
         bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
         relabel_configs:
         - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
           action: keep
           regex: default;kubernetes;https

       - job_name: 'kubernetes-nodes'
         kubernetes_sd_configs:
         - role: node
         relabel_configs:
         - action: labelmap
           regex: __meta_kubernetes_node_label_(.+)

       - job_name: 'kubernetes-cadvisor'
         kubernetes_sd_configs:
         - role: node
         relabel_configs:
         - action: labelmap
           regex: __meta_kubernetes_node_label_(.+)
         - target_label: __address__
           replacement: kubernetes.default.svc:443
         - source_labels: [__meta_kubernetes_node_name]
           regex: (.+)
           target_label: __metrics_path__
           replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor

       - job_name: 'kubernetes-service-endpoints'
         kubernetes_sd_configs:
         - role: endpoints
         relabel_configs:
         - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
           action: keep
           regex: true
         - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
           action: replace
           target_label: __metrics_path__
           regex: (.+)

       - job_name: 'istio-mesh'
         kubernetes_sd_configs:
         - role: endpoints
           namespaces:
             names:
             - istio-system
         relabel_configs:
         - source_labels: [__meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
           action: keep
           regex: istio-telemetry;prometheus
   ```

### Grafana Dashboard and Visualization
1. **Grafana Deployment**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: grafana
     namespace: monitoring-staging
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: grafana
     template:
       metadata:
         labels:
           app: grafana
       spec:
         serviceAccountName: grafana
         containers:
         - name: grafana
           image: grafana/grafana:10.0.0
           ports:
           - containerPort: 3000
             name: web
           env:
           - name: GF_SECURITY_ADMIN_PASSWORD
             valueFrom:
               secretKeyRef:
                 name: grafana-secrets
                 key: admin-password
           - name: GF_INSTALL_PLUGINS
             value: "grafana-piechart-panel,grafana-worldmap-panel"
           volumeMounts:
           - name: grafana-storage
             mountPath: /var/lib/grafana
           - name: grafana-config
             mountPath: /etc/grafana
           - name: grafana-dashboards
             mountPath: /var/lib/grafana/dashboards
           - name: grafana-datasources
             mountPath: /etc/grafana/provisioning/datasources
           resources:
             requests:
               cpu: 100m
               memory: 256Mi
             limits:
               cpu: 500m
               memory: 1Gi
         volumes:
         - name: grafana-storage
           persistentVolumeClaim:
             claimName: grafana-storage
         - name: grafana-config
           configMap:
             name: grafana-config
         - name: grafana-dashboards
           configMap:
             name: grafana-dashboards
         - name: grafana-datasources
           configMap:
             name: grafana-datasources
   ```

2. **Grafana Datasources Configuration**:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: grafana-datasources
     namespace: monitoring-staging
   data:
     prometheus.yaml: |
       apiVersion: 1
       datasources:
       - name: Prometheus
         type: prometheus
         url: http://prometheus:9090
         access: proxy
         isDefault: true
         editable: true
       - name: Loki
         type: loki
         url: http://loki:3100
         access: proxy
         editable: true
   ```

### Loki + Fluent Bit Logging Stack
1. **Loki Deployment**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: loki
     namespace: monitoring-staging
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: loki
     template:
       metadata:
         labels:
           app: loki
       spec:
         containers:
         - name: loki
           image: grafana/loki:2.8.0
           ports:
           - containerPort: 3100
             name: http
           args:
           - -config.file=/etc/loki/local-config.yaml
           volumeMounts:
           - name: loki-config
             mountPath: /etc/loki
           - name: loki-storage
             mountPath: /loki
           resources:
             requests:
               cpu: 100m
               memory: 256Mi
             limits:
               cpu: 500m
               memory: 1Gi
         volumes:
         - name: loki-config
           configMap:
             name: loki-config
         - name: loki-storage
           persistentVolumeClaim:
             claimName: loki-storage
   ```

2. **Fluent Bit DaemonSet**:
   ```yaml
   apiVersion: apps/v1
   kind: DaemonSet
   metadata:
     name: fluent-bit
     namespace: monitoring-staging
   spec:
     selector:
       matchLabels:
         app: fluent-bit
     template:
       metadata:
         labels:
           app: fluent-bit
       spec:
         serviceAccountName: fluent-bit
         containers:
         - name: fluent-bit
           image: fluent/fluent-bit:2.1.0
           ports:
           - containerPort: 2020
             name: metrics
           volumeMounts:
           - name: fluent-bit-config
             mountPath: /fluent-bit/etc
           - name: varlog
             mountPath: /var/log
             readOnly: true
           - name: varlibdockercontainers
             mountPath: /var/lib/docker/containers
             readOnly: true
           resources:
             requests:
               cpu: 50m
               memory: 64Mi
             limits:
               cpu: 200m
               memory: 128Mi
         volumes:
         - name: fluent-bit-config
           configMap:
             name: fluent-bit-config
         - name: varlog
           hostPath:
             path: /var/log
         - name: varlibdockercontainers
           hostPath:
             path: /var/lib/docker/containers
   ```

### AlertManager Configuration
1. **AlertManager Deployment**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: alertmanager
     namespace: monitoring-staging
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: alertmanager
     template:
       metadata:
         labels:
           app: alertmanager
       spec:
         containers:
         - name: alertmanager
           image: prom/alertmanager:v0.25.0
           ports:
           - containerPort: 9093
             name: web
           args:
           - '--config.file=/etc/alertmanager/config.yml'
           - '--storage.path=/alertmanager'
           - '--web.external-url=https://alertmanager.staging.advancedblockchainsecurity.com'
           volumeMounts:
           - name: alertmanager-config
             mountPath: /etc/alertmanager
           - name: alertmanager-storage
             mountPath: /alertmanager
           resources:
             requests:
               cpu: 50m
               memory: 64Mi
             limits:
               cpu: 200m
               memory: 256Mi
         volumes:
         - name: alertmanager-config
           configMap:
             name: alertmanager-config
         - name: alertmanager-storage
           persistentVolumeClaim:
             claimName: alertmanager-storage
   ```

2. **AlertManager Configuration**:
   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: alertmanager-config
     namespace: monitoring-staging
   data:
     config.yml: |
       global:
         smtp_smarthost: 'smtp.gmail.com:587'
         smtp_from: 'alerts@advancedblockchainsecurity.com'
         smtp_auth_username: 'alerts@advancedblockchainsecurity.com'
         smtp_auth_password_file: '/etc/alertmanager/secrets/smtp-password'

       route:
         group_by: ['alertname']
         group_wait: 10s
         group_interval: 10s
         repeat_interval: 1h
         receiver: 'web.hook'
         routes:
         - match:
             severity: critical
           receiver: 'critical-alerts'
         - match:
             severity: warning
           receiver: 'warning-alerts'

       receivers:
       - name: 'web.hook'
         webhook_configs:
         - url: 'http://notification:3000/webhook/alertmanager'

       - name: 'critical-alerts'
         email_configs:
         - to: 'devops@advancedblockchainsecurity.com'
           subject: 'CRITICAL: {{ .GroupLabels.alertname }}'
           body: |
             {{ range .Alerts }}
             Alert: {{ .Annotations.summary }}
             Description: {{ .Annotations.description }}
             {{ end }}
         slack_configs:
         - api_url_file: '/etc/alertmanager/secrets/slack-webhook'
           channel: '#alerts'
           title: 'CRITICAL Alert'
           text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

       - name: 'warning-alerts'
         email_configs:
         - to: 'team@advancedblockchainsecurity.com'
           subject: 'WARNING: {{ .GroupLabels.alertname }}'
           body: |
             {{ range .Alerts }}
             Alert: {{ .Annotations.summary }}
             Description: {{ .Annotations.description }}
             {{ end }}
   ```

### Infrastructure Monitoring Dashboards
1. **Kubernetes Cluster Dashboard**:
   - Cluster resource utilization (CPU, memory, storage)
   - Node health and capacity metrics
   - Pod distribution and status
   - Network traffic and performance

2. **Istio Service Mesh Dashboard**:
   - Service-to-service communication metrics
   - mTLS certificate status
   - Circuit breaker and retry statistics
   - Traffic routing and load balancing

3. **cert-manager Dashboard**:
   - Certificate expiration monitoring
   - Certificate issuance and renewal rates
   - ACME challenge success/failure rates
   - Certificate authority health

4. **External Secrets Dashboard**:
   - Secret synchronization status
   - Vault connectivity health
   - Secret refresh rates and errors
   - Authentication success/failure metrics

## Implementation Steps

### Phase 1: Core Monitoring Deployment (2.5 hours)
1. Deploy Prometheus with cluster monitoring configuration
2. Deploy Grafana with datasource integration
3. Configure Loki + Fluent Bit for log aggregation
4. Set up AlertManager with basic notification rules
5. Test monitoring stack connectivity and functionality

### Phase 2: Dashboard and Visualization Setup (1.5 hours)
1. Import and configure infrastructure dashboards
2. Create service mesh monitoring dashboards
3. Set up certificate and secret management dashboards
4. Configure alerting rules for infrastructure components
5. Test dashboard functionality and data accuracy

### Phase 3: Integration and Optimization (1 hour)
1. Integrate monitoring with External Secrets for credentials
2. Configure SSL certificates for monitoring dashboards
3. Set up monitoring ingress and access controls
4. Optimize resource allocation and performance
5. Validate end-to-end monitoring functionality

## Success Criteria & Validation

### Monitoring Stack Requirements
- [ ] Prometheus collecting metrics from all infrastructure components
- [ ] Grafana operational with comprehensive dashboards
- [ ] Loki + Fluent Bit aggregating logs from all services
- [ ] AlertManager configured with appropriate notification channels
- [ ] Node Exporter providing system-level metrics

### Dashboard and Visualization Requirements
- [ ] Infrastructure dashboards displaying real-time system health
- [ ] Service mesh dashboards showing traffic and security metrics
- [ ] Certificate management dashboards monitoring SSL health
- [ ] External Secrets dashboards tracking secret synchronization
- [ ] Custom alerting rules for critical infrastructure events

### Integration Requirements
- [ ] External Secrets managing monitoring credentials
- [ ] SSL certificates configured for monitoring dashboard access
- [ ] Ingress controllers routing traffic to monitoring services
- [ ] RBAC policies controlling access to monitoring data
- [ ] ArgoCD managing monitoring stack deployments

### Performance and Reliability Requirements
- [ ] Monitoring stack resource usage optimized for each environment
- [ ] High availability configuration for production monitoring
- [ ] Data retention policies configured appropriately
- [ ] Backup and disaster recovery procedures operational
- [ ] Performance impact of monitoring minimal on infrastructure

## Testing & Validation

### Functional Testing
1. **Metrics Collection**:
   ```bash
   # Test Prometheus targets
   kubectl port-forward -n monitoring-staging svc/prometheus 9090:9090
   curl http://localhost:9090/api/v1/targets

   # Verify metric ingestion
   curl "http://localhost:9090/api/v1/query?query=up"
   curl "http://localhost:9090/api/v1/query?query=kubernetes_build_info"
   ```

2. **Dashboard Access**:
   ```bash
   # Test Grafana connectivity
   kubectl port-forward -n monitoring-staging svc/grafana 3000:3000
   curl http://localhost:3000/api/health

   # Test dashboard data
   curl -u admin:password http://localhost:3000/api/dashboards/home
   ```

3. **Log Aggregation**:
   ```bash
   # Test Loki functionality
   kubectl port-forward -n monitoring-staging svc/loki 3100:3100
   curl http://localhost:3100/ready

   # Query logs
   curl "http://localhost:3100/loki/api/v1/query?query={job=\"fluent-bit\"}"
   ```

### Alert Testing
1. **Alert Rule Validation**:
   ```bash
   # Test alert rules
   curl "http://localhost:9090/api/v1/rules"

   # Trigger test alert
   kubectl scale deployment prometheus --replicas=0 -n monitoring-staging
   sleep 60
   curl "http://localhost:9093/api/v1/alerts"
   ```

## Integration Requirements

### Dependencies
- **From Task 2.1**: Istio service mesh for metrics collection
- **From Task 2.5**: External Secrets for monitoring credentials
- **From Task 2.3**: cert-manager for monitoring dashboard SSL

### Integration Points
- **Task 2.7**: ArgoCD monitoring and deployment
- **Task 2.9**: Backend service monitoring integration
- **Task 2.13**: Platform integration testing with monitoring

### Post-Task Validation
- **Observability Ready**: Complete infrastructure monitoring operational
- **Dashboard Access**: Team can monitor system health and performance
- **Alerting Functional**: Critical issues trigger appropriate notifications
- **Integration Complete**: Monitoring stack integrated with all infrastructure

This task establishes comprehensive monitoring and observability for the entire Kubernetes infrastructure, providing the foundation for application monitoring and operational excellence.