# BlockSecOps Platform Installation Guide

**Version:** 1.0.0
**Created:** December 13, 2025
**Status:** Active

## Overview

This guide provides comprehensive step-by-step instructions for installing the BlockSecOps platform on a local Minikube cluster using the `local` overlay. Follow the phases in order for a successful installation.

## Deferred Components

The following components are **skipped for local development** and will be implemented after migration to the production server:

| Component | Reason | Future Phase |
|-----------|--------|--------------|
| **Monitoring** (Prometheus/Grafana) | Resource-intensive; not required for local dev | Post-server migration |
| **Logging** (ELK/Loki stack) | Resource-intensive; kubectl logs sufficient for local | Post-server migration |
| **ArgoCD** | GitOps not needed for local development; code is ready | Post-server migration |

These components have kustomization configurations prepared in `k8s/overlays/local/` but should not be deployed on local development machines due to resource constraints.

## Configuration Standards

**IMPORTANT:** All configuration must be done through Kustomize files in the codebase. Runtime patching is prohibited.

- **No `kubectl patch` commands** - All patches must be defined in kustomization.yaml files
- **No `kubectl apply -f -` with inline YAML** - All resources must be in version-controlled files
- **No manual secret creation** - All secrets must be managed through External Secrets Operator and Vault
- **No runtime scaling** - Replica counts must be set in kustomization overlays

If you need to modify configuration:
1. Update the appropriate kustomization.yaml or resource file
2. Commit the change to version control
3. Apply using `kubectl apply -k <overlay-path>/`

See [/docs/standards/](/docs/standards/) for complete standards documentation.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Phases](#installation-phases)
3. [Phase 1: Minikube Setup](#phase-1-minikube-setup)
4. [Phase 2: Platform Infrastructure](#phase-2-platform-infrastructure)
5. [Phase 3: Database Services](#phase-3-database-services)
6. [Phase 4: Security Infrastructure](#phase-4-security-infrastructure)
7. [Phase 5: Networking & Ingress](#phase-5-networking--ingress)
8. [Phase 6: Container Registry](#phase-6-container-registry)
9. [Phase 7: Monitoring Stack](#phase-7-monitoring-stack)
10. [Phase 8: Application Services](#phase-8-application-services)
11. [Phase 9: Scanner Integration](#phase-9-scanner-integration)
12. [Phase 10: Verification & Testing](#phase-10-verification--testing)
13. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| Memory | 8GB | 10GB+ |
| CPU Cores | 4 | 6-8 |
| Disk | 40GB | 60GB+ |

### Software Requirements

Install the following tools before proceeding:

```bash
# Required tools
brew install minikube
brew install kubectl
brew install helm
brew install jq

# Verify installations
minikube version    # v1.37.0+
kubectl version --client    # v1.28+
helm version    # v3.19+
jq --version    # 1.6+
```

### Docker Desktop Configuration

1. Open Docker Desktop Settings
2. Navigate to Resources → Advanced
3. Set Memory to **12GB** (minimum 10GB)
4. Set CPUs to **8** (minimum 4)
5. Apply and restart Docker Desktop

---

## Installation Phases

| Phase | Component | Namespace | Dependencies |
|-------|-----------|-----------|--------------|
| 1 | Minikube | - | Docker Desktop |
| 2 | Metrics Server | kube-system | Minikube |
| 3a | PostgreSQL | postgresql-local | Phase 2 |
| 3b | Redis | redis-local | Phase 2 |
| 4a | Vault | vault-local | Phase 2 |
| 4b | External Secrets | external-secrets-local | Phase 4a |
| 4c | Cert-Manager | cert-manager-local | Phase 2 |
| 5a | Traefik | traefik-local | Phase 4c |
| 5b | Network Policies | various | Phase 5a |
| 6 | Harbor Registry | harbor-local | Phase 5a |
| 7 | ~~Monitoring~~ | ~~monitoring-local~~ | **DEFERRED** |
| 8a | API Service | api-service-local | Phase 3, 4 |
| 8b | Dashboard | dashboard-local | Phase 8a |
| 8c | Orchestration | orchestration-local | Phase 3, 8a |
| 8d | Tool Integration | tool-integration-local | Phase 8c |
| 8e | Intelligence Engine | intelligence-engine-local | Phase 3 |
| 8f | Data Service | data-service-local | Phase 3 |
| 8g | Notification | notification-local | Phase 3 |
| 9 | Scanner Images | tool-integration-local | Phase 8d |
| 10 | Verification | - | All phases |

---

## Phase 1: Minikube Setup

### 1.1 Start Minikube Cluster

```bash
# Start minikube with recommended resources
minikube start --cpus=8 --memory=11500

# Verify cluster is running
minikube status
kubectl cluster-info
```

### 1.2 Enable Required Addons

```bash
# Enable addons
minikube addons enable storage-provisioner
minikube addons enable default-storageclass

# Verify addons
minikube addons list | grep -E "storage|default"
```

### 1.3 Verify Node Resources

```bash
kubectl get nodes
kubectl describe node minikube | grep -A 10 "Allocatable"
```

**Expected Output:**
- Memory: ~10GB allocatable
- CPU: 8 cores

---

## Phase 2: Platform Infrastructure

### 2.1 Install Metrics Server

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Apply metrics-server
kubectl apply -k k8s/overlays/local/metrics-server/

# Verify metrics-server is running
kubectl get pods -n kube-system | grep metrics-server
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s
```

### 2.2 Verify Metrics Collection

```bash
# Wait for metrics to be available (may take 1-2 minutes)
sleep 60
kubectl top nodes
kubectl top pods -A
```

---

## Phase 3: Database Services

### 3.1 Deploy PostgreSQL

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Create namespace and deploy PostgreSQL
kubectl apply -k k8s/overlays/local/postgresql/

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n postgresql-local --timeout=180s

# Verify deployment
kubectl get pods -n postgresql-local
kubectl get pvc -n postgresql-local
```

### 3.2 Verify PostgreSQL Connectivity

```bash
# Port forward for testing
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3

# Test connection
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -c "SELECT version();"

# Kill port forward
pkill -f "port-forward.*postgresql"
```

### 3.3 Deploy Redis

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Create namespace and deploy Redis
kubectl apply -k k8s/overlays/local/redis/

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n redis-local --timeout=120s

# Verify deployment
kubectl get pods -n redis-local
```

### 3.4 Verify Redis Connectivity

```bash
# Port forward for testing
kubectl port-forward -n redis-local svc/redis-master 6379:6379 &
sleep 3

# Test connection
redis-cli -h 127.0.0.1 -p 6379 ping

# Kill port forward
pkill -f "port-forward.*redis"
```

---

## Phase 4: Security Infrastructure

### 4.1 Deploy Vault

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Deploy Vault
kubectl apply -k k8s/overlays/local/vault/

# Wait for Vault to be ready
kubectl wait --for=condition=ready pod/vault-0 -n vault-local --timeout=120s

# Verify Vault status
kubectl exec -n vault-local vault-0 -- vault status
```

### 4.2 Initialize Vault Secrets

```bash
# Run the Vault initialization script
/Users/pwner/Git/ABS/scripts/init-vault-local.sh

# Verify secrets were created
kubectl exec -n vault-local vault-0 -- vault kv list secret/kv/
kubectl exec -n vault-local vault-0 -- vault kv list secret/local/
```

### 4.3 Configure Vault Kubernetes Authentication

```bash
# Enable Kubernetes auth method
kubectl exec -n vault-local vault-0 -- vault auth enable kubernetes

# Configure Kubernetes auth with cluster CA and API server
kubectl exec -n vault-local vault-0 -- sh -c '
  vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    disable_iss_validation=true
'

# Create policies and roles for each service (run init-vault-local.sh which includes these)
# The script creates per-service policies following least-privilege principle
```

### 4.4 Deploy Cert-Manager (Required before External Secrets)

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Install cert-manager CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.crds.yaml

# Wait for CRDs
kubectl wait --for=condition=Established crd certificates.cert-manager.io --timeout=60s

# Deploy cert-manager
kubectl apply -k k8s/overlays/local/cert-manager/

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager-local --timeout=180s

# Verify
kubectl get pods -n cert-manager-local
```

### 4.5 Deploy External Secrets Operator

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Install External Secrets Operator CRDs first
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml

# Wait for CRDs to be established
kubectl wait --for=condition=Established crd externalsecrets.external-secrets.io --timeout=60s

# Deploy External Secrets Operator
kubectl apply -k k8s/overlays/local/external-secrets/

# Wait for operator to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets-local --timeout=120s

# Wait for webhook certificate to be issued
kubectl wait --for=condition=ready certificate external-secrets-webhook -n external-secrets-local --timeout=60s

# Verify ClusterSecretStore is ready
kubectl get clustersecretstore vault-backend
```

### 4.6 Verify External Secrets Integration

```bash
# Check ClusterSecretStore status (should show Ready: True)
kubectl describe clustersecretstore vault-backend | grep -A5 "Status:"

# If not ready, check the external-secrets logs
kubectl logs -n external-secrets-local -l app.kubernetes.io/name=external-secrets --tail=50
```

---

## Phase 5: Networking & Ingress

### 5.1 Deploy Traefik Ingress Controller

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Deploy Traefik
kubectl apply -k k8s/overlays/local/traefik/

# Wait for Traefik to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traefik -n traefik-local --timeout=120s

# Verify deployment
kubectl get pods -n traefik-local
kubectl get svc -n traefik-local
```

### 5.2 Deploy Network Policies

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Apply network policies
kubectl apply -k k8s/overlays/local/network-policies/

# Verify network policies
kubectl get networkpolicies -A
```

---

## Phase 6: Container Registry

### 6.1 Deploy Harbor Registry

```bash
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure

# Deploy Harbor
kubectl apply -k k8s/overlays/local/harbor/

# Wait for Harbor core to be ready (may take several minutes)
kubectl wait --for=condition=ready pod -l app=harbor -n harbor-local --timeout=300s

# Verify all Harbor components
kubectl get pods -n harbor-local
```

### 6.2 Configure Docker for Harbor

```bash
# Get Harbor service ClusterIP
HARBOR_IP=$(kubectl get svc harbor -n harbor-local -o jsonpath='{.spec.clusterIP}')
echo "Harbor ClusterIP: $HARBOR_IP"

# Add to Docker insecure registries (if needed)
# Edit ~/.docker/daemon.json and add:
# { "insecure-registries": ["localhost:5443"] }
# Then restart Docker Desktop
```

### 6.3 Setup Harbor Proxy (for local Docker push)

```bash
# Start socat proxy for Harbor access from local Docker
docker run -d --name harbor-proxy --restart always \
  --network minikube \
  -p 5443:5443 \
  alpine/socat:latest \
  TCP-LISTEN:5443,fork,reuseaddr TCP:$(minikube ip):30443

# Verify proxy
curl -k https://localhost:5443/v2/
```

---

## Phase 7: Monitoring Stack

> **DEFERRED:** Monitoring is skipped for local development due to resource constraints.
> This phase will be implemented after migration to the production server.
> For local debugging, use `kubectl logs` instead.

<!--
### 7.1 Deploy Prometheus & Grafana

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
cd /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring-local \
  --create-namespace \
  -f k8s/overlays/local/monitoring/values.yaml

# Wait for monitoring stack
kubectl wait --for=condition=ready pod -l app=kube-prometheus-stack-operator -n monitoring-local --timeout=180s
```

### 7.2 Verify Monitoring Stack

```bash
# Check all monitoring pods
kubectl get pods -n monitoring-local

# Port forward Grafana
kubectl port-forward -n monitoring-local svc/kube-prometheus-stack-grafana 3001:80 &

# Access Grafana at http://localhost:3001 (admin/admin)
```
-->

---

## Phase 8: Application Services

### 8.1 Build Application Images

Before deploying services, build all Docker images:

```bash
# Set minikube Docker environment
eval $(minikube docker-env)

# Build API Service
cd /Users/pwner/Git/ABS/blocksecops-api-service
docker build -t api-service:latest .

# Build Dashboard
cd /Users/pwner/Git/ABS/blocksecops-dashboard
docker build -t blocksecops-dashboard:latest -f Dockerfile ..

# Build Orchestration
cd /Users/pwner/Git/ABS/blocksecops-orchestration
docker build -t blocksecops-orchestration:latest .

# Build Tool Integration
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
docker build -t tool-integration:latest .

# Build Intelligence Engine
cd /Users/pwner/Git/ABS/blocksecops-intelligence-engine
docker build -t intelligence-engine:latest .

# Build Data Service
cd /Users/pwner/Git/ABS/blocksecops-data-service
docker build -t data-service:latest .

# Build Notification Service
cd /Users/pwner/Git/ABS/blocksecops-notification
docker build -t notification:latest .
```

### 8.2 Deploy API Service

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Deploy API service
kubectl apply -k k8s/overlays/local/

# Wait for API service
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=api-service -n api-service-local --timeout=180s

# Verify
kubectl get pods -n api-service-local
kubectl get endpoints -n api-service-local
```

### 8.3 Run Database Migrations

```bash
# Port forward PostgreSQL
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3

# Run Alembic migrations
cd /Users/pwner/Git/ABS/blocksecops-api-service
source .venv/bin/activate
export DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/solidity_security"
alembic upgrade head

# Kill port forward
pkill -f "port-forward.*postgresql"
```

### 8.4 Deploy Dashboard

```bash
cd /Users/pwner/Git/ABS/blocksecops-dashboard

# Deploy dashboard
kubectl apply -k k8s/overlays/local/

# Wait for dashboard
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=dashboard -n dashboard-local --timeout=120s

# Verify
kubectl get pods -n dashboard-local
```

### 8.5 Deploy Orchestration Service

```bash
cd /Users/pwner/Git/ABS/blocksecops-orchestration

# Deploy orchestration
kubectl apply -k k8s/overlays/local/

# Wait for orchestration
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=orchestration -n orchestration-local --timeout=180s

# Verify
kubectl get pods -n orchestration-local
```

### 8.6 Deploy Tool Integration

```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration

# Deploy tool-integration
kubectl apply -k k8s/overlays/local/

# Wait for tool-integration
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=tool-integration -n tool-integration-local --timeout=120s

# Verify
kubectl get pods -n tool-integration-local
```

### 8.7 Deploy Intelligence Engine

```bash
cd /Users/pwner/Git/ABS/blocksecops-intelligence-engine

# Deploy intelligence engine
kubectl apply -k k8s/overlays/local/

# Wait for intelligence engine
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=intelligence-engine -n intelligence-engine-local --timeout=120s

# Verify
kubectl get pods -n intelligence-engine-local
```

### 8.8 Deploy Data Service

```bash
cd /Users/pwner/Git/ABS/blocksecops-data-service

# Deploy data service
kubectl apply -k k8s/overlays/local/

# Wait for data service
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=data-service -n data-service-local --timeout=120s

# Verify
kubectl get pods -n data-service-local
```

### 8.9 Deploy Notification Service

```bash
cd /Users/pwner/Git/ABS/blocksecops-notification

# Deploy notification
kubectl apply -k k8s/overlays/local/

# Wait for notification
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=notification -n notification-local --timeout=120s

# Verify
kubectl get pods -n notification-local
```

---

## Phase 9: Scanner Integration

### 9.1 Build Scanner Images

```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images

# Set minikube Docker environment
eval $(minikube docker-env)

# Build all scanners
./build-all.sh

# Or build individual scanners:
cd slither && docker build -t scanner-slither:latest . && cd ..
cd aderyn && docker build -t scanner-aderyn:latest . && cd ..
cd wake && docker build -t scanner-wake:latest . && cd ..
cd mythril && docker build -t scanner-mythril:latest . && cd ..
cd semgrep && docker build -t scanner-semgrep:latest . && cd ..
cd solhint && docker build -t scanner-solhint:latest . && cd ..
cd echidna && docker build -t scanner-echidna:latest . && cd ..
cd medusa && docker build -t scanner-medusa:latest . && cd ..
cd halmos && docker build -t scanner-halmos:latest . && cd ..
```

### 9.2 Verify Scanner Images

```bash
# List scanner images in minikube
eval $(minikube docker-env)
docker images | grep scanner
```

---

## Phase 10: Verification & Testing

### 10.1 Start Port Forwards

```bash
# Kill any existing port forwards
pkill -f "kubectl port-forward"
sleep 2

# Start required port forwards
kubectl port-forward -n traefik-local svc/traefik 3000:80 > /tmp/pf-traefik.log 2>&1 &
kubectl port-forward -n notification-local svc/notification 8003:8003 > /tmp/pf-notification.log 2>&1 &
kubectl port-forward -n harbor-local svc/harbor 8443:443 > /tmp/pf-harbor.log 2>&1 &
# Note: Grafana port-forward deferred (monitoring not deployed locally)

sleep 3
echo "Port forwards active"
```

### 10.2 Verify All Services

```bash
# Check all pods are running (monitoring deferred for local)
kubectl get pods -A | grep -E "local"

# Check all services have endpoints
kubectl get endpoints -A | grep -v kube-system | grep -v "none"

# Test API health
curl -s http://127.0.0.1:3000/api/v1/health/live | jq .
curl -s http://127.0.0.1:3000/api/v1/health/ready | jq .

# Test Dashboard
curl -s http://127.0.0.1:3000/ | head -5

# Test Scanner List
curl -s http://127.0.0.1:3000/api/v1/scanners | jq '.scanners[].id'
```

### 10.3 Verify External Secrets Sync

```bash
# Check External Secrets status
kubectl get externalsecrets -A

# All should show "SecretSynced" and "True"
```

### 10.4 Quick Health Check Script

```bash
#!/bin/bash
# Save as /Users/pwner/Git/ABS/scripts/health-check.sh

echo "=== BlockSecOps Platform Health Check ==="
echo

echo "1. Cluster Status:"
kubectl cluster-info | head -1

echo
echo "2. Pod Status by Namespace:"
# Note: monitoring-local is deferred for local development
for ns in postgresql-local redis-local vault-local external-secrets-local traefik-local harbor-local api-service-local dashboard-local orchestration-local tool-integration-local intelligence-engine-local data-service-local notification-local; do
    PODS=$(kubectl get pods -n $ns --no-headers 2>/dev/null | wc -l)
    RUNNING=$(kubectl get pods -n $ns --no-headers 2>/dev/null | grep Running | wc -l)
    if [ "$PODS" -gt 0 ]; then
        echo "  $ns: $RUNNING/$PODS running"
    fi
done

echo
echo "3. API Health:"
curl -s http://127.0.0.1:3000/api/v1/health/live 2>/dev/null || echo "  API not accessible"

echo
echo "4. External Secrets:"
kubectl get externalsecrets -A --no-headers 2>/dev/null | awk '{print "  " $1 "/" $2 ": " $4}'

echo
echo "=== Health Check Complete ==="
```

---

## Troubleshooting

### Common Issues

#### Pods Stuck in Pending State

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace> | tail -20

# Check node resources
kubectl describe node minikube | grep -A 10 "Allocated resources"

# Solution: Scale down non-essential services or increase minikube resources
```

#### External Secrets Not Syncing

```bash
# Check SecretStore status
kubectl get secretstore -A
kubectl describe secretstore -n <namespace>

# Check vault-token secret exists
kubectl get secret vault-token -n <namespace>

# Re-run vault initialization
/Users/pwner/Git/ABS/scripts/init-vault-local.sh
```

#### Service Has No Endpoints

```bash
# Check service selector
kubectl get svc -n <namespace> <service> -o yaml | grep -A 5 selector

# Check pod labels
kubectl get pods -n <namespace> -o yaml | grep -A 10 labels

# Fix: Ensure kustomization.yaml has includeSelectors: false
```

#### Harbor Registry Push Fails

```bash
# Check harbor-proxy is running
docker ps | grep harbor-proxy

# Restart if needed
docker restart harbor-proxy

# Verify connectivity
curl -k https://localhost:5443/v2/
```

#### Port Forward Dies

```bash
# Kill all port forwards
pkill -f "kubectl port-forward"

# Restart required port forwards
kubectl port-forward -n traefik-local svc/traefik 3000:80 &
```

### Log Locations

```bash
# Service logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<service> --tail=100

# Port forward logs
cat /tmp/pf-traefik.log
cat /tmp/pf-grafana.log

# Minikube logs
minikube logs --file=minikube.log
```

---

## Quick Reference

### Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Dashboard | http://127.0.0.1:3000 | Supabase Auth |
| API Docs | http://127.0.0.1:3000/api/v1/docs | - |
| Harbor | https://127.0.0.1:8443 | admin/Harbor12345 |
| ~~Grafana~~ | ~~http://127.0.0.1:3001~~ | **DEFERRED** |

### Key Commands

```bash
# Start minikube
minikube start

# Stop minikube (preserves data)
minikube stop

# Check cluster status
kubectl get pods -A

# Watch pod status
kubectl get pods -A -w

# Port forward all services
/Users/pwner/Git/ABS/scripts/start-port-forwards.sh

# Initialize vault after restart
/Users/pwner/Git/ABS/scripts/init-vault-local.sh

# Health check
curl http://127.0.0.1:3000/api/v1/health/ready
```

---

## Related Documentation

- [Local Development Setup Standards](../standards/local-development-setup.md)
- [Docker Image Versioning](../standards/docker-image-versioning.md)
- [Secrets Management](../standards/secrets-management.md)
- [Build Workflow](../standards/build-workflow.md)
- [Testing & Deployment](../standards/testing-deployment.md)
- [Scanner Integration Guide](../../blocksecops-docs/scanners/SCANNER-INTEGRATION-GUIDE.md)

---

**Document Owner:** Infrastructure Team
**Last Updated:** December 14, 2025
**Next Review:** As needed
