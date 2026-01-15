# Service Access Standards

**Version:** 3.0.0
**Last Updated:** January 15, 2026
**Status:** Active

## Overview

This document defines service access patterns for all environments. **Services MUST be always available without manual intervention.** Manual port-forwards are a debugging tool, not an access pattern.

### Core Principle

> **Services must be always available.** After cluster start, all services should be accessible immediately without running additional commands.

---

## Always-Available Access (Standard)

Each environment has its own always-available access method:

| Environment | Method | Access Pattern | Setup |
|-------------|--------|----------------|-------|
| **Local (minikube)** | `minikube tunnel` + LoadBalancer | `http://127.0.0.1:3000` | One-time background service |
| **Server (kubeadm)** | hostPort 80/443 + Traefik | `http://app.blocksecops.local` | DNS entry only |
| **Production (GCP)** | GCP Load Balancer | `https://app.blocksecops.com` | Managed by infrastructure |

### Local Development (minikube) - Always Available

**Standard Pattern:** Use `minikube tunnel` as a background service for automatic LoadBalancer IP allocation.

**One-Time Setup:**
```bash
# Start minikube tunnel (requires sudo, runs persistently)
# Option 1: Run in background terminal
minikube tunnel

# Option 2: Run as nohup background process
nohup minikube tunnel > /tmp/minikube-tunnel.log 2>&1 &

# Option 3: Run in tmux session (recommended)
tmux new -s tunnel -d 'minikube tunnel'
```

**Daily Workflow:** None required. With tunnel running, services are immediately accessible.

**Access URLs:**
| Service | URL |
|---------|-----|
| Dashboard | http://127.0.0.1:3000 |
| API | http://127.0.0.1:3000/api/v1/... |

**Service Type:** Services must use `type: LoadBalancer` to work with minikube tunnel.

### Server Environment (kubeadm) - Always Available

**Standard Pattern:** Traefik with hostPort 80/443 provides standard HTTP/HTTPS access.

**Node IP:** 192.168.86.225
**Domain:** `app.blocksecops.local`

**One-Time Setup (Client machines):**
```bash
# Add to /etc/hosts on any machine that needs to access the server
echo "192.168.86.225  app.blocksecops.local" | sudo tee -a /etc/hosts
```

**One-Time Setup (Server itself):**
```bash
# Add to /etc/hosts so server can resolve its own domain (required for local API testing)
echo "127.0.0.1  app.blocksecops.local" | sudo tee -a /etc/hosts
```

**Daily Workflow:** None required. Services are accessible immediately after cluster start.

**Access URLs:**
| Service | URL |
|---------|-----|
| Dashboard | http://app.blocksecops.local |
| API | http://app.blocksecops.local/api/v1/... |
| Direct IP | http://192.168.86.225 |

**Kustomize Overlay:** `blocksecops-gcp-infrastructure/k8s/overlays/server/`

### Production (GCP) - Always Available

**Standard Pattern:** GCP Load Balancer with managed TLS certificate.

**Domain:** `app.blocksecops.com`

**Access URLs:**
| Service | URL |
|---------|-----|
| Dashboard | https://app.blocksecops.com |
| API | https://app.blocksecops.com/api/v1/... |

**Kustomize Overlay:** `blocksecops-gcp-infrastructure/k8s/overlays/gcp-production/`

---

## Port Mappings Reference

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
| **5432** | PostgreSQL | `postgresql-local` | 5432 | Main database (optional) |
| **6379** | Redis | `redis-local` | 6379 | Cache & session store (optional) |
| **8200** | Vault | `vault-local` | 8200 | Secret management |

> **Note:** Harbor is deployed but **not used for local development**. Images are built directly into minikube's Docker daemon using `eval $(minikube docker-env)`. See [Local Development Setup](./local-development-setup.md) for details.

### Monitoring Services (PLG Stack) - DISABLED BY DEFAULT

**Note:** Monitoring services are **disabled by default** for local development to reduce resource usage and improve performance. The platform functions fully without them.

| Local Port | Service | Namespace | Target Port | Purpose |
|------------|---------|-----------|-------------|---------|
| **3001** | Grafana | `monitoring-local` | 3000 | Dashboards & visualization |
| **9091** | Prometheus | `monitoring-local` | 9090 | Metrics collection |
| **9093** | Loki | `monitoring-local` | 3100 | Log aggregation |

### Database Exporters - DISABLED BY DEFAULT

| Local Port | Service | Namespace | Target Port | Purpose |
|------------|---------|-----------|-------------|---------|
| **9187** | postgres-exporter | `postgresql-local` | 9187 | PostgreSQL metrics |
| **9121** | redis-exporter | `redis-local` | 9121 | Redis metrics |

### Enabling/Disabling Monitoring

**To disable monitoring (default for local dev):**
```bash
kubectl scale deployment prometheus grafana loki -n monitoring-local --replicas=0
kubectl scale deployment postgres-exporter -n postgresql-local --replicas=0
kubectl scale deployment redis-exporter -n redis-local --replicas=0
```

**To enable monitoring when needed:**
```bash
kubectl scale deployment prometheus grafana loki -n monitoring-local --replicas=1
kubectl scale deployment postgres-exporter -n postgresql-local --replicas=1
kubectl scale deployment redis-exporter -n redis-local --replicas=1
```

### Frontend & Ingress

| Local Port | Service | Access URL | Purpose |
|------------|---------|------------|---------|
| **3000** | Traefik Ingress | http://127.0.0.1:3000 | Main entry point for dashboard and API routing |

---

## Debugging Tools (Port-Forwards)

**IMPORTANT:** Manual port-forwards are for **debugging and direct service access only**, not for regular platform access. Use the always-available patterns above for normal development.

### When to Use Port-Forwards

| Use Case | Recommended Approach |
|----------|---------------------|
| Regular development | **Always-available access** (minikube tunnel, hostPort) |
| Direct database access | Port-forward to PostgreSQL |
| Direct Redis access | Port-forward to Redis |
| Debugging specific service | Port-forward to that service |
| Accessing internal-only services | Port-forward as needed |

### Port-Forward Setup Script (Debugging Only)

For situations where you need direct service access:

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

# NOTE: Harbor is NOT used for local development
# Images are built directly into minikube's Docker daemon
# See local-development-setup.md for the build workflow

# NOTE: Monitoring services are DISABLED by default for local development
# Uncomment below if you need monitoring:
# kubectl port-forward -n monitoring-local svc/grafana 3001:3000 &
# kubectl port-forward -n monitoring-local svc/prometheus 9091:9090 &
# kubectl port-forward -n monitoring-local svc/loki 9093:3100 &
# kubectl port-forward -n postgresql-local svc/postgres-exporter 9187:9187 &
# kubectl port-forward -n redis-local svc/redis-exporter 9121:9121 &

echo "✅ All port-forwards established (monitoring disabled by default)"
echo ""
echo "Service URLs:"
echo "  Dashboard:        http://127.0.0.1:3000 (via Traefik)"
echo "  API Service:      http://127.0.0.1:3000/api/v1 (via Traefik)"
echo "  Notifications:    http://127.0.0.1:8003 (WebSocket: ws://127.0.0.1:8003/ws/)"
echo "  Vault:            http://127.0.0.1:8200"
echo ""
echo "Optional (for debugging):"
echo "  PostgreSQL:       postgresql://localhost:5432"
echo "  Redis:            redis://localhost:6379"
echo ""
echo "Monitoring (disabled by default):"
echo "  Grafana:          http://127.0.0.1:3001 (admin/admin)"
echo "  Prometheus:       http://127.0.0.1:9091"
echo ""
echo "Note: Harbor is NOT used for local dev. Build images with: eval \$(minikube docker-env)"
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

**Dashboard IngressRoute** (`k8s/overlays/local/ingressroute.yaml`):
```yaml
routes:
  # Catch all except /api/v1 paths (allows /api-keys, /audit-logs, /webhooks, etc.)
  - match: (Host(`localhost`) || Host(`127.0.0.1`)) && !PathPrefix(`/api/v1`) && !PathPrefix(`/docs`)
    kind: Rule
    services:
      - name: dashboard
        port: 3000
```

**API Service IngressRoute** (`k8s/overlays/local/api-service/ingressroute.yaml`):
```yaml
routes:
  # Use /api/v1 specifically to avoid catching dashboard routes like /api-keys
  - match: (Host(`localhost`) || Host(`127.0.0.1`)) && PathPrefix(`/api/v1`)
    kind: Rule
    services:
      - name: api-service
        port: 8000
```

**Routing Logic**:
- `http://127.0.0.1:3000` → Dashboard UI
- `http://127.0.0.1:3000/api-keys` → Dashboard UI (page route)
- `http://127.0.0.1:3000/audit-logs` → Dashboard UI (page route)
- `http://127.0.0.1:3000/api/v1/...` → API Service (matches PathPrefix `/api/v1`)
- This mirrors production where all traffic goes through a single ingress point

**Important**: Use `/api/v1` (not `/api`) for API routing to avoid catching dashboard page routes that start with `/api-*` (like `/api-keys`).

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

# Core services (always needed)
ports=(3000 8003 8200)
services=(
  "Traefik (Dashboard/API)"
  "Notification Service"
  "Vault"
)

# Optional services (for debugging)
# ports+=(5432 6379)
# services+=("PostgreSQL" "Redis")

# Optional monitoring ports (disabled by default)
# monitoring_ports=(3001 9091 9093 9187 9121)
# monitoring_services=("Grafana" "Prometheus" "Loki" "PostgreSQL Exporter" "Redis Exporter")

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

## Quick Reference

### Always-Available Access (Standard)

**Local (minikube):**
```bash
# One-time setup: Start tunnel in tmux
tmux new -s tunnel -d 'minikube tunnel'

# Access (no daily commands needed)
curl http://127.0.0.1:3000                    # Dashboard
curl http://127.0.0.1:3000/api/v1/health/live # API
```

**Server (kubeadm):**
```bash
# One-time setup: Add DNS entries
# On server:
echo "127.0.0.1  app.blocksecops.local" | sudo tee -a /etc/hosts
# On client:
echo "192.168.86.225  app.blocksecops.local" | sudo tee -a /etc/hosts

# Access (no daily commands needed)
curl http://app.blocksecops.local                    # Dashboard
curl http://app.blocksecops.local/api/v1/health/live # API
```

### Debugging (Port-Forwards)

**Setup Port-Forwards (debugging only):**
```bash
./scripts/setup-port-forwards.sh
```

**Kill All Port-Forwards:**
```bash
pkill -f "kubectl port-forward"
```

### Build Images

**Local Development (minikube):**
```bash
eval $(minikube docker-env)
docker build -t <service>:<version> .
kubectl apply -k k8s/overlays/local/<service>/
```

**Server (kubeadm with containerd):**
```bash
docker build -t blocksecops-<service>:<version> .
docker save blocksecops-<service>:<version> | sudo ctr -n k8s.io images import -
kubectl apply -k k8s/overlays/server/
```

---

**See Also**:
- [Service Availability](./service-availability.md) - Always-available access principles
- [Domain Management](./domain-management.md) - Domain and DNS configuration
- [Docker Image Versioning](./docker-image-versioning.md)
- [Testing & Deployment](./testing-deployment.md)
