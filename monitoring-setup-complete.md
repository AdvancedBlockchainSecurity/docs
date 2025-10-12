# Monitoring Stack - Complete Setup with Prometheus Operator

## ✅ COMPLETE - All Issues Resolved

### What Was Fixed:
1. **Dashboards not visible** - ✅ FIXED by installing kube-prometheus-stack with dashboard sidecar
2. **No alerts in AlertManager** - ✅ FIXED by installing Prometheus Operator to read PrometheusRule CRDs

---

## Deployed Components (8 pods in monitoring-local)

### Prometheus Operator Stack
- **Prometheus Server**: 2/2 Running (Operator-managed, reads PrometheusRule CRDs)
- **AlertManager**: 2/2 Running (receiving alerts from Prometheus)
- **Grafana**: 3/3 Running (with dashboard sidecar auto-loading dashboards)
- **Prometheus Operator**: 1/1 Running (manages Prometheus/AlertManager resources)
- **Kube State Metrics**: 1/1 Running (Kubernetes object metrics)
- **Node Exporter**: 1/1 Running (node metrics DaemonSet)

### Loki Stack (separate installation)
- **Loki**: 1/1 Running (log aggregation)
- **Promtail**: 1/1 Running (log collection DaemonSet)

---

## ServiceMonitors (5 infrastructure services monitored)
✅ PostgreSQL - postgresql-local namespace
✅ Redis - redis-local namespace
✅ Vault - vault-local namespace
✅ ArgoCD - argocd-local namespace
✅ Harbor - harbor-local namespace

---

## Grafana Configuration

### Datasources (2 configured)
✅ **Prometheus**: Auto-configured by kube-prometheus-stack
✅ **Loki**: http://loki:3100 (added via ConfigMap with grafana_datasource label)

### Dashboards (30+ available)
**Platform Dashboards (2 custom):**
- Infrastructure Overview
- Platform Services Health

**Default kube-prometheus-stack Dashboards (28):**
- AlertManager Overview
- API Server
- Cluster Total
- CoreDNS
- Grafana Overview
- Kubernetes Resources (Cluster, Namespace, Node, Pod, Workload)
- Kubelet
- Nodes (including AIX, Darwin variants)
- Persistent Volumes Usage
- Prometheus
- And more...

### Access
```bash
kubectl port-forward -n monitoring-local svc/kube-prometheus-stack-grafana 3000:80
```
- URL: http://localhost:3000
- Username: `admin`
- Password: `admin` (or get from secret)

---

## Alerting Configuration

### PrometheusRules (36 total rule groups)

**Custom Platform Alerts (platform-alerts PrometheusRule):**
- Infrastructure: NodeDown, HighCPUUsage, HighMemoryUsage
- Services: PostgreSQL/Redis/Vault/ArgoCD/Harbor down
- Pods: PodCrashLooping, PodNotReady

**Default kube-prometheus-stack Alerts (35 rule groups):**
- AlertManager rules
- etcd rules
- General Kubernetes rules
- API Server rules
- Node rules
- Kubelet rules
- And more...

### AlertManager Status
✅ **2 alerts currently firing:**
1. Watchdog (always-on test alert)
2. etcdInsufficientMembers (expected in minikube)

### Access AlertManager
```bash
kubectl port-forward -n monitoring-local svc/kube-prometheus-stack-alertmanager 9093:9093
```
- URL: http://localhost:9093

---

## Prometheus Configuration

### Rules Loaded
✅ Our custom rule groups are loaded:
- `infrastructure` group
- `services` group  
- `pods` group

### Access Prometheus
```bash
kubectl port-forward -n monitoring-local svc/kube-prometheus-stack-prometheus 9090:9090
```
- URL: http://localhost:9090
- Rules: http://localhost:9090/rules
- Alerts: http://localhost:9090/alerts
- Targets: http://localhost:9090/targets

---

## How It Works Now

### Dashboard Auto-Loading
The Grafana pod has a sidecar container (`grafana-sc-dashboard`) that watches for ConfigMaps with the label `grafana_dashboard: "1"` and automatically loads them into Grafana.

### Datasource Auto-Loading
The Grafana pod has a sidecar container (`grafana-sc-datasources`) that watches for ConfigMaps with the label `grafana_datasource: "1"` and automatically configures datasources.

### Alert Flow
1. **Prometheus** scrapes metrics from ServiceMonitors
2. **Prometheus** evaluates PrometheusRule CRDs
3. **Prometheus** fires alerts to **AlertManager**
4. **AlertManager** routes alerts based on configuration
5. Alerts visible in both Prometheus (/alerts) and AlertManager (/api/v2/alerts)

---

## Migration Summary

### What Changed
- **FROM**: Standalone Prometheus/Grafana Helm charts
- **TO**: kube-prometheus-stack (unified Prometheus Operator solution)

### Why
- Standalone charts don't support PrometheusRule CRDs
- Standalone Grafana doesn't auto-load dashboard ConfigMaps
- Prometheus Operator provides production-grade monitoring with CRD-based configuration

### Benefits
✅ PrometheusRules work natively
✅ ServiceMonitors work natively
✅ Dashboards auto-load from ConfigMaps
✅ Datasources auto-configure from ConfigMaps
✅ 35+ production-ready alerting rules included
✅ 28+ production-ready dashboards included
✅ GitOps-friendly (all config in Kubernetes CRDs)

---

## Platform Observability Status

✅ **Metrics Collection**: Operational (Prometheus + ServiceMonitors)
✅ **Log Aggregation**: Operational (Loki + Promtail)
✅ **Visualization**: Operational (Grafana with 30+ dashboards)
✅ **Alerting**: Operational (PrometheusRules + AlertManager)
✅ **Service Discovery**: Operational (5 ServiceMonitors)
✅ **Infrastructure Monitoring**: Complete
✅ **Dashboards Visible**: YES
✅ **Alerts Firing**: YES

---

## Next Steps

### For Production Deployment
1. Save dashboard JSONs to Git repository (blocksecops-monitoring)
2. Create Kustomize base/overlays for staging/production
3. Configure real AlertManager receivers (Slack, PagerDuty, email)
4. Add application-specific dashboards for 17 services
5. Configure Vault integration for Grafana credentials
6. Tune retention policies per environment

### For Application Monitoring
1. Add ServiceMonitors for each deployed service
2. Create PrometheusRules for application-specific alerts
3. Create Grafana dashboards for application metrics
4. Configure SLO/SLI tracking

---

## Quick Reference

**Get Grafana Password:**
```bash
kubectl get secret -n monitoring-local kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

**Access Grafana:**
```bash
kubectl port-forward -n monitoring-local svc/kube-prometheus-stack-grafana 3000:80
```

**Access Prometheus:**
```bash
kubectl port-forward -n monitoring-local svc/kube-prometheus-stack-prometheus 9090:9090
```

**Access AlertManager:**
```bash
kubectl port-forward -n monitoring-local svc/kube-prometheus-stack-alertmanager 9093:9093
```

**Check Active Alerts:**
```bash
kubectl exec -n monitoring-local alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager -- wget -qO- http://localhost:9093/api/v2/alerts
```
