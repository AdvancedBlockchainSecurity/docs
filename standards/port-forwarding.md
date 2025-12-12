# Port-Forwarding Standards

**Version:** 2.3.0
**Last Updated:** December 12, 2025
**Status:** Active

## Overview

This document defines the standard port-forwarding configuration for local development with Minikube. Starting with the Traefik migration (v2.0.0), local development uses Traefik ingress controller to mirror production architecture, enabling services with relative URLs to work correctly in all environments.

## Standard Port Mappings

### Core Services

| Local Port | Service | Namespace | Target Port | Purpose |
|------------|---------|-----------|-------------|---------|
| **8000** | API Service | `api-service-local` | 8000 | Main REST API (HTTP) |
| **9090** | API Service | `api-service-local` | 9090 | Prometheus metrics |
| **8001** | Data Service | `data-service-local` | 8001 | Data aggregation API |
| **8002** | Intelligence Engine | `intelligence-engine-local` | 80 | ML/AI intelligence API |
| **8003** | Notification Service | `notification-local` | 8003 | Notification API + WebSocket |
| **8004** | Orchestration Service | `orchestration-local` | 8004 | Scan orchestration API |
| **8005** | Tool Integration | `tool-integration-local` | 8005 | Scanner integration API |

### Infrastructure Services

| Local Port | Service | Namespace | Target Port | Purpose |
|------------|---------|-----------|-------------|---------|
| **5432** | PostgreSQL | `postgresql-local` | 5432 | Main database |
| **6379** | Redis | `redis-local` | 6379 | Cache & session store |
| **8200** | Vault | `vault-local` | 8200 | Secret management |
| **8443** | Harbor | `harbor-local` | 443 | Container registry (HTTPS) |

### Monitoring Services (PLG Stack)

| Local Port | Service | Namespace | Target Port | Purpose |
|------------|---------|-----------|-------------|---------|
| **3001** | Grafana | `monitoring-local` | 3000 | Dashboards & visualization |
| **9091** | Prometheus | `monitoring-local` | 9090 | Metrics collection |
| **9093** | Loki | `monitoring-local` | 3100 | Log aggregation |

### Database Exporters

| Local Port | Service | Namespace | Target Port | Purpose |
|------------|---------|-----------|-------------|---------|
| **9187** | postgres-exporter | `postgresql-local` | 9187 | PostgreSQL metrics |
| **9121** | redis-exporter | `redis-local` | 9121 | Redis metrics |

### Frontend & Ingress

| Local Port | Service | Access URL | Purpose |
|------------|---------|------------|---------|
| **3000** | Traefik Ingress | http://127.0.0.1:3000 | Main entry point for dashboard and API routing |

## Port-Forward Setup Commands

### Complete Setup Script

Create all port-forwards for local development:

```bash
#!/bin/bash
# File: scripts/setup-port-forwards.sh

# Traefik Ingress Controller (primary access point for dashboard and API)
kubectl port-forward -n traefik-local svc/traefik 3000:80 &

# API Service - Prometheus Metrics
kubectl port-forward -n api-service-local svc/api-service 9090:9090 &

# Data Service
kubectl port-forward -n data-service-local svc/data-service 8001:8001 &

# Intelligence Engine
kubectl port-forward -n intelligence-engine-local svc/intelligence-engine 8002:80 &

# Notification Service (HTTP API + WebSocket on same port)
kubectl port-forward -n notification-local svc/notification 8003:8003 &

# Orchestration Service
kubectl port-forward -n orchestration-local svc/orchestration 8004:8004 &

# Tool Integration Service
kubectl port-forward -n tool-integration-local svc/tool-integration 8005:8005 &

# PostgreSQL Database
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &

# Redis Cache
kubectl port-forward -n redis-local svc/redis 6379:6379 &

# Vault Secret Manager
kubectl port-forward -n vault-local svc/vault 8200:8200 &

# Harbor Container Registry (HTTPS)
kubectl port-forward -n harbor-local svc/harbor 8443:443 &

# Monitoring - Grafana (port 3001 to avoid conflict with Traefik on 3000)
kubectl port-forward -n monitoring-local svc/grafana 3001:3000 &

# Monitoring - Prometheus (port 9091 to avoid conflict with API metrics on 9090)
kubectl port-forward -n monitoring-local svc/prometheus 9091:9090 &

# Monitoring - Loki (port 9093 for log queries)
kubectl port-forward -n monitoring-local svc/loki 9093:3100 &

# Database Exporters
kubectl port-forward -n postgresql-local svc/postgres-exporter 9187:9187 &
kubectl port-forward -n redis-local svc/redis-exporter 9121:9121 &

echo "✅ All port-forwards established"
echo ""
echo "Service URLs:"
echo "  Dashboard:        http://127.0.0.1:3000 (via Traefik)"
echo "  API Service:      http://127.0.0.1:3000/api/v1 (via Traefik)"
echo "  API Metrics:      http://127.0.0.1:9090"
echo "  Data Service:     http://127.0.0.1:8001"
echo "  Intelligence:     http://127.0.0.1:8002"
echo "  Notifications:    http://127.0.0.1:8003 (WebSocket: ws://127.0.0.1:8003/ws/)"
echo "  Orchestration:    http://127.0.0.1:8004"
echo "  Tool Integration: http://127.0.0.1:8005"
echo "  PostgreSQL:       postgresql://localhost:5432"
echo "  Redis:            redis://localhost:6379"
echo "  Vault:            http://127.0.0.1:8200"
echo "  Harbor:           https://127.0.0.1:8443 (admin/Harbor12345)"
echo ""
echo "Monitoring URLs:"
echo "  Grafana:          http://127.0.0.1:3001 (admin/admin)"
echo "  Prometheus:       http://127.0.0.1:9091"
echo "  Loki:             http://127.0.0.1:9093"
```

### Individual Service Commands

**Traefik Ingress (Dashboard and API access)**:
```bash
kubectl port-forward -n traefik-local svc/traefik 3000:80
```

**API Service (Metrics)**:
```bash
kubectl port-forward -n api-service-local svc/api-service 9090:9090
```

**PostgreSQL Database**:
```bash
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432
```

**Redis Cache**:
```bash
kubectl port-forward -n redis-local svc/redis 6379:6379
```

**Harbor Container Registry (HTTPS)**:
```bash
kubectl port-forward -n harbor-local svc/harbor 8443:443
```

**Note**: Harbor uses HTTPS with a self-signed certificate. Access via `https://127.0.0.1:8443`. Login: `admin` / `Harbor12345`.

**Grafana (Dashboards)**:
```bash
kubectl port-forward -n monitoring-local svc/grafana 3001:3000
```

**Prometheus (Metrics)**:
```bash
kubectl port-forward -n monitoring-local svc/prometheus 9091:9090
```

**Loki (Logs)**:
```bash
kubectl port-forward -n monitoring-local svc/loki 9093:3100
```

**Note**: Monitoring ports are offset from their default values to avoid conflicts with other services (Traefik on 3000, API metrics on 9090).

## Port Assignment Rules

### Port Range Allocation

- **8000-8099**: Application services (APIs, web services)
- **8200-8299**: Secret management (Vault)
- **8400-8499**: Container registry services (Harbor)
- **5000-5999**: Databases and data stores
- **6000-6999**: Cache and messaging systems
- **9000-9999**: Monitoring and metrics

### Port Selection Guidelines

1. **Use service's native port when possible**: If a service normally runs on port 5432 (PostgreSQL), forward to 5432
2. **Avoid common ports**: Don't use ports 80, 443, 22, 3306, etc. that may conflict with host services
3. **Sequential allocation**: Assign services in the 8000 range sequentially (8000, 8001, 8002, etc.)
4. **Document deviations**: If you must use a non-standard port, document why in this file

### Reserved Ports

**DO NOT USE** these ports (commonly used by macOS/Linux services):
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 3000 (Many dev servers - used by Dashboard Vite dev server)
- 3306 (MySQL)
- 5000 (AirPlay on macOS)
- 8080 (Common proxy port)

## Service Configuration

### Dashboard API Configuration

The dashboard frontend uses **relative URLs** for API requests, routed through Traefik ingress:

**File**: `blocksecops-dashboard/src/lib/api/client.ts`
```typescript
// API Configuration - Uses relative path with Traefik routing
const API_PREFIX = '/api/v1';

export const apiClient: AxiosInstance = axios.create({
  baseURL: API_PREFIX,
  timeout: 30000,
});
```

**Why Relative URLs?**
- Works seamlessly across all environments (local, staging, production)
- No environment-specific configuration needed
- Traefik routes `/api/v1/*` requests to api-service automatically
- Production-ready architecture in local development

### Traefik IngressRoute Configuration

Local development uses Traefik IngressRoutes to route traffic based on hostname and path:

**Dashboard IngressRoute** (`k8s/overlays/local/dashboard/ingressroute.yaml`):
```yaml
routes:
  - match: Host(`localhost`) || Host(`127.0.0.1`)
    kind: Rule
    services:
      - name: dashboard
        port: 3000
```

**API Service IngressRoute** (`k8s/overlays/local/api-service/ingressroute.yaml`):
```yaml
routes:
  - match: (Host(`localhost`) || Host(`127.0.0.1`)) && PathPrefix(`/api`)
    kind: Rule
    services:
      - name: api-service
        port: 8000
```

**Routing Logic**:
- `http://127.0.0.1:3000` → Dashboard UI
- `http://127.0.0.1:3000/api/v1/...` → API Service (matches PathPrefix `/api`)
- This mirrors production where all traffic goes through a single ingress point

### Notification Service Ports

The notification service uses a single port for both HTTP API and WebSocket connections:

**File**: `blocksecops-notification/k8s/base/service.yaml`
```yaml
ports:
- port: 8003
  targetPort: 8003
  name: http
  protocol: TCP
```

- **Port 8003**: HTTP REST API + WebSocket (at `/ws/` path)

**Endpoints**:
- `/` - Service status
- `/api/v1/health/live` - Liveness probe
- `/api/v1/health/ready` - Readiness probe (includes Redis check)
- `/api/v1/info` - Service information
- `/api/v1/notifications` - Notification management
- `/ws/` - WebSocket endpoint for real-time updates
- `/docs` - OpenAPI documentation

**Port-Forward Command**:
```bash
kubectl port-forward -n notification-local svc/notification 8003:8003
```

**When to Start Notification Service**:

| Use Case | Required? |
|----------|-----------|
| Basic dashboard usage (scans, viewing results) | **No** |
| Real-time scan status updates in dashboard | Yes |
| Receiving webhook notifications from CI/CD | Yes |
| Email/Slack/Teams alerts | Yes |
| API-triggered notifications | Yes |

**Note**: The Notification Service is **optional** for basic local development. The core workflow (creating scans, viewing vulnerabilities) works without it. Only port-forward when you need:
- Real-time WebSocket updates in the dashboard (`ws://127.0.0.1:8003/ws/`)
- Webhook/notification testing for Phase 4.5 features

### API Service Ports

The API service container exposes two ports:

**File**: `blocksecops-api-service/k8s/base/deployment.yaml`
```yaml
ports:
- containerPort: 8000
  name: http
  protocol: TCP
- containerPort: 9090
  name: metrics
  protocol: TCP
```

- **Port 8000**: Main REST API (FastAPI application)
- **Port 9090**: Prometheus metrics endpoint

## Troubleshooting

### Port Already in Use

If you get "bind: address already in use" error:

```bash
# Find what's using the port
lsof -i :8000

# Kill the process
kill -9 <PID>

# Or kill all kubectl port-forwards
pkill -f "kubectl port-forward"

# Then restart the port-forwards
./scripts/setup-port-forwards.sh
```

### Port-Forward Connection Refused

If you get "error forwarding port ... connection refused":

1. **Check pod is running**:
   ```bash
   kubectl get pods -n api-service-local
   ```

2. **Check container port**:
   ```bash
   kubectl get pod -n api-service-local -o jsonpath='{.items[0].spec.containers[0].ports}' | jq .
   ```

3. **Verify service configuration**:
   ```bash
   kubectl get svc -n api-service-local api-service -o yaml
   ```

4. **Check if service is listening inside pod**:
   ```bash
   kubectl exec -n api-service-local deployment/api-service -- netstat -tlnp
   ```

### Dashboard Can't Connect to API

**Symptoms**: Dashboard shows network errors, 404 on `/api/v1/*` requests

**Solution**:
1. Verify Traefik port-forward on 3000 is active:
   ```bash
   lsof -i :3000 | grep LISTEN
   ```

2. Test Traefik routing to dashboard:
   ```bash
   curl http://127.0.0.1:3000
   ```

3. Test Traefik routing to API:
   ```bash
   curl http://127.0.0.1:3000/api/v1/scanners
   ```

4. If missing, create Traefik port-forward:
   ```bash
   kubectl port-forward -n traefik-local svc/traefik 3000:80 &
   ```

5. Verify IngressRoutes are configured:
   ```bash
   kubectl get ingressroute -n dashboard-local
   kubectl get ingressroute -n api-service-local
   ```

## Monitoring Port-Forwards

### Check Active Port-Forwards

```bash
# List all port-forward processes
ps aux | grep "kubectl port-forward" | grep -v grep

# Check specific port
lsof -i :8000 | grep LISTEN

# Test connectivity
curl -s http://127.0.0.1:8000/health || echo "Port 8000 not accessible"
```

### Port-Forward Health Check Script

```bash
#!/bin/bash
# File: scripts/check-port-forwards.sh

ports=(8000 8001 8002 8003 8004 8005 9090 5432 6379 8200 8443 3001 9091 9093 9187 9121)
services=(
  "API Service HTTP"
  "Data Service"
  "Intelligence Engine"
  "Notification Service"
  "Orchestration Service"
  "Tool Integration"
  "API Service Metrics"
  "PostgreSQL"
  "Redis"
  "Vault"
  "Harbor Registry"
  "Grafana"
  "Prometheus"
  "Loki"
  "PostgreSQL Exporter"
  "Redis Exporter"
)

echo "Checking port-forwards..."
echo ""

for i in "${!ports[@]}"; do
  port=${ports[$i]}
  service=${services[$i]}

  if lsof -i :$port | grep -q LISTEN; then
    echo "✅ Port $port - $service"
  else
    echo "❌ Port $port - $service (NOT FORWARDED)"
  fi
done
```

## Best Practices

### 1. Use Background Port-Forwards for Development

Run port-forwards in background during development:

```bash
# Start in background
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &

# Check it's running
jobs

# Bring to foreground if needed
fg %1
```

### 2. Use tmux/screen for Persistent Sessions

Keep port-forwards alive across terminal sessions:

```bash
# Start tmux session
tmux new -s port-forwards

# Run setup script
./scripts/setup-port-forwards.sh

# Detach from tmux (Ctrl+B, then D)

# Reattach later
tmux attach -t port-forwards
```

### 3. Cleanup on Exit

Always clean up port-forwards when done:

```bash
# Kill all port-forwards
pkill -f "kubectl port-forward"

# Or create cleanup script
#!/bin/bash
# File: scripts/cleanup-port-forwards.sh
pkill -f "kubectl port-forward"
echo "✅ All port-forwards terminated"
```

### 4. Document Custom Ports

If you add a new service that needs a port-forward:

1. Update this document with the new port mapping
2. Add the port-forward command to `setup-port-forwards.sh`
3. Add the port to the health check script
4. Update the dashboard API client if applicable

## Production vs Local Development

### Local Development (Minikube with Traefik)

**Architecture**: Local development now **mirrors production** using Traefik ingress controller.

**Access Pattern**:
- Single entry point: `http://127.0.0.1:3000` (Traefik ingress)
- Dashboard: `http://127.0.0.1:3000`
- API: `http://127.0.0.1:3000/api/v1/...`
- Traefik routes traffic based on path prefixes

**Benefits**:
- Production-ready relative URLs work locally
- No environment-specific configuration
- Mirrors production routing behavior
- Services can communicate through ingress just like production

### Production Deployment

Production uses the same Traefik ingress pattern at scale:
- **Traefik ingress controller** for external HTTPS access
- **TLS certificates** via cert-manager
- **DNS-based routing** with custom domains
- **Load balancers** for high availability
- **Service mesh** (optional) for advanced traffic management

**Key Difference**: Production has multiple Traefik replicas with load balancing, while local has single replica.

See `/Users/pwner/Git/ABS/docs/standards/kubernetes-kustomize-structure-template.md` for production deployment configuration.

---

## Quick Reference

**Setup All Port-Forwards**:
```bash
./scripts/setup-port-forwards.sh
```

**Check Port-Forwards**:
```bash
./scripts/check-port-forwards.sh
```

**Kill All Port-Forwards**:
```bash
pkill -f "kubectl port-forward"
```

**Test Dashboard and API via Traefik**:
```bash
# Test dashboard
curl http://127.0.0.1:3000

# Test API routing
curl http://127.0.0.1:3000/api/v1/scanners
```

**Test Monitoring Stack**:
```bash
# Test Grafana
curl -s http://127.0.0.1:3001/api/health | jq .

# Test Prometheus
curl -s http://127.0.0.1:9091/-/ready

# Test Loki
curl -s http://127.0.0.1:9093/ready
```

---

**See Also**:
- [Docker Image Versioning](./docker-image-versioning.md)
- [Kubernetes Kustomize Structure](../architecture-templates/kubernetes-kustomize-structure-template.md)
- [Testing & Deployment](./testing-deployment.md)
