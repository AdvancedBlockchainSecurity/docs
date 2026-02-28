# Monitoring & Observability Documentation

This directory contains comprehensive documentation for monitoring and observability services in the Apogee platform.

## 📊 Available Documentation

### Core Monitoring Services
- **[Dependency Monitoring Service](dependency-monitoring-service.md)** - Complete dependency tracking and security scanning
- **[Grafana Dashboards](grafana-dashboards.md)** - Visualization and dashboard management
- **[Prometheus Configuration](prometheus-configuration.md)** - Metrics collection and alerting setup
- **[Alert Management](alert-management.md)** - Alerting rules and notification setup
- **[Database Exporters](database-exporters.md)** - PostgreSQL and Redis metrics exporters

### Deployment Guides
- **[Local Deployment](local-deployment.md)** - Deploy monitoring stack locally
- **[Production Deployment](production-deployment.md)** - Production deployment procedures
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues and solutions

### Integration Guides
- **[CI/CD Integration](ci-cd-integration.md)** - Integrate monitoring with development workflows
- **[Service Integration](service-integration.md)** - Add monitoring to new services
- **[External Integrations](external-integrations.md)** - Slack, Teams, and other integrations

## 🏗️ Architecture Overview

The monitoring infrastructure uses the PLG stack (Prometheus + Loki + Grafana):

```
Monitoring Stack (PLG)
├── Prometheus (v2.48.0)    # Metrics collection and storage (7-day retention)
├── Loki (v2.9.3)           # Log aggregation (72-hour retention)
├── Grafana (v10.2.3)       # Visualization and dashboards
├── Promtail (v2.9.3)       # Log shipping agent (DaemonSet)
├── Dependency Monitor      # Multi-language dependency scanning
│
Database Exporters
├── postgres-exporter (v0.15.0)  # PostgreSQL metrics on port 9187
└── redis-exporter (v1.55.0)     # Redis metrics on port 9121
│
Service Instrumentation
├── Python Services          # prometheus-fastapi-instrumentator on port 9090
└── Node.js Services         # prom-client (planned)
```

## 🚀 Quick Start

1. **Deploy Local Monitoring**:
   ```bash
   kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/monitoring/
   ```

2. **Setup Port-Forwards**:
   ```bash
   kubectl port-forward -n monitoring-local svc/grafana 3001:3000 &
   kubectl port-forward -n monitoring-local svc/prometheus 9091:9090 &
   kubectl port-forward -n monitoring-local svc/loki 9093:3100 &
   ```

3. **Access Dashboards**:
   - Grafana: `http://127.0.0.1:3001` (admin/admin)
   - Prometheus: `http://127.0.0.1:9091`
   - Loki: `http://127.0.0.1:9093`

4. **Verify Health**:
   ```bash
   curl -s http://127.0.0.1:3001/api/health | jq .
   curl -s http://127.0.0.1:9091/-/ready
   curl -s http://127.0.0.1:9093/ready
   ```

## 📊 Pre-configured Dashboards

| Dashboard | Folder | Purpose |
|-----------|--------|---------|
| Cluster Overview | Cluster | Pod status, resource usage, cluster health |
| Logs Explorer | Logs | Search logs across all namespaces |
| Apogee Services | Services | API, Dashboard, Orchestration, Tool Integration |
| Infrastructure Services | Infrastructure | PostgreSQL, Redis, Vault, Harbor, Traefik |
| Scanner Jobs | Scanners | Slither, Aderyn, Semgrep, Wake, fuzzers |

## 📈 Key Metrics

### Python Service Metrics (FastAPI)

All Python services expose Prometheus metrics via `prometheus-fastapi-instrumentator` on port 9090:

| Service | Namespace | Metrics Port | Endpoint |
|---------|-----------|--------------|----------|
| api-service | api-service-local | 9090 | /metrics |
| data-service | data-service-local | 9090 | /metrics |
| intelligence-engine | intelligence-engine-local | 9090 | /metrics |
| orchestration | orchestration-local | 9090 | /metrics |
| tool-integration | tool-integration-local | 9090 | /metrics |

**HTTP Request Metrics:**
- `http_requests_total` - Total HTTP requests by method, path, status
- `http_request_duration_seconds` - Request latency histogram
- `http_requests_inprogress` - Currently in-flight requests

### Tool Integration Custom Metrics

The tool-integration service exposes scanner-specific metrics on port 9090:

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `tool_integration_scan_trigger_total` | Counter | scanner, status | Scan trigger requests |
| `tool_integration_scan_callback_total` | Counter | scanner, status | Result callbacks received |
| `tool_integration_scan_callback_forward_total` | Counter | status | Result forwarding to API service |
| `tool_integration_scan_callback_duration_seconds` | Histogram | scanner | Callback processing duration |
| `tool_integration_job_conflict_total` | Counter | scanner | 409 Conflict errors during Job creation |
| `tool_integration_vulnerabilities_parsed_total` | Counter | scanner, severity | Vulnerabilities parsed from results |

**PrometheusRule alerts** are defined in `blocksecops-tool-integration/k8s/base/prometheus-rules.yaml`:
- `ScannerHighFailureRate` - Scanner failure rate >25%
- `ScannerPipelineStalled` - Triggers sent but no callbacks received
- `JobConflictRateHigh` - High 409 Conflict rate
- `CallbackForwardingFailure` - API result forwarding failing
- `CallbackProcessingSlowP95` - p95 callback latency >30s
- `ToolIntegrationNotReady` - <50% replicas available
- `ScannerJobStuck` - Jobs running >15 minutes

### Database Exporter Metrics

| Exporter | Namespace | Port | Key Metrics |
|----------|-----------|------|-------------|
| postgres-exporter | postgresql-local | 9187 | pg_up, pg_stat_activity, pg_database_size |
| redis-exporter | redis-local | 9121 | redis_up, redis_connected_clients, redis_memory_used |

### Dependency Health
- `dependency_current_version_info` - Current package versions
- `dependency_security_vulnerabilities_total` - Security vulnerabilities by severity
- `service_dependency_count_total` - Total dependencies per service

### Service Performance
- `dependency_scan_duration_seconds` - Scan execution time
- `dependency_scan_errors_total` - Scan failure tracking
- `service_vulnerabilities_total` - Total vulnerabilities per service

### Operational Metrics
- `up` - Service availability
- `process_cpu_seconds_total` - CPU usage
- `process_resident_memory_bytes` - Memory usage

## 🔧 Configuration

### Environment-Specific Settings

#### Local Development
- Minimal resource allocation
- Basic monitoring features
- Single-node deployment

#### Staging
- Full feature set
- Moderate resource allocation
- Production-like configuration

#### Production
- High availability setup
- Auto-scaling enabled
- Enhanced security policies

## 🛡️ Security

### Access Control
- **RBAC**: Role-based access control for all monitoring components
- **Network Policies**: Restricted network access between components
- **TLS**: Encrypted communication for all external connections

### Data Protection
- **Read-Only Access**: Repository scanning with read-only permissions
- **Secret Management**: Secure handling of credentials and API keys
- **Audit Logging**: Comprehensive audit trails for all operations

## 📋 Best Practices

### Monitoring
1. Set up baseline metrics for all services
2. Configure appropriate alert thresholds
3. Regular dashboard maintenance and updates
4. Balance monitoring coverage with alert noise

### Dependency Management
1. Prioritize security updates over feature updates
2. Test dependency updates in isolation
3. Maintain documentation for breaking changes
4. Schedule regular dependency review cycles

### Operations
1. Keep runbooks updated with current procedures
2. Regular team training on monitoring tools
3. Automate routine monitoring tasks
4. Continuous improvement through metrics review

## 🆘 Support

### Getting Help
- **Documentation**: Start with the specific service documentation
- **Troubleshooting**: Check the troubleshooting guide for common issues
- **Logs**: Review service logs for detailed error information
- **Metrics**: Use Prometheus queries to investigate performance issues

### Contributing
- **Documentation Updates**: Keep documentation current with implementation
- **Dashboard Improvements**: Enhance existing dashboards based on usage
- **Alert Tuning**: Adjust alert thresholds based on operational experience
- **Best Practices**: Share operational insights and lessons learned

This monitoring infrastructure provides comprehensive visibility into the health, security, and performance of the entire Apogee platform.