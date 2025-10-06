# Local Development Environment Setup Guide

## Overview

This guide sets up a local minikube development environment for the SolidityOps platform using the exact same 17-repository architecture as defined in `/Users/pwner/Git/ABS/docs/repos/`. This replaces AWS cloud infrastructure with local minikube to enable cost-effective development while maintaining identical service architecture.

## Repository Architecture (17 repos - 94K LOC)

### Backend Service Repositories (6 repos)
- `solidity-security-api-service` - FastAPI authentication and API gateway (10K LOC Python)
- `solidity-security-tool-integration` - Security tool adapters (12K LOC Hybrid Python/Rust)
- `solidity-security-intelligence-engine` - Risk scoring and correlation (8K LOC Hybrid Python/Rust)
- `solidity-security-orchestration` - Analysis workflow management (6K LOC Python Celery)
- `solidity-security-data-service` - Database access layer (7K LOC Hybrid Python/Rust)
- `solidity-security-notification` - Real-time notifications (5K LOC Node.js/TypeScript)

### Contract Parser Repository (1 repo)
- `solidity-security-contract-parser` - Solidity parsing and AST (8K LOC Pure Rust)

### Frontend Application Repositories (4 repos)
- `solidity-security-ui-core` - Shared UI components (8K LOC React/TypeScript)
- `solidity-security-dashboard` - Main dashboard interface (8K LOC React/TypeScript)
- `solidity-security-findings` - Finding management (8K LOC React/TypeScript)
- `solidity-security-analysis` - Analysis workflow (6K LOC React/TypeScript)

### Shared Libraries Repository (1 repo)
- `solidity-security-shared` - Multi-language utilities (7K LOC Rust/Python/TypeScript)

### Infrastructure Repositories (2 repos)
- `solidity-security-aws-infrastructure` - Infrastructure as Code
- `solidity-security-monitoring` - Observability configurations

### Supporting Repositories (3 repos)
- `solidity-security-docs` - Documentation
- `solidity-security-tools` - Tool configurations
- `solidity-security-vulnerabilities` - Vulnerability database

## Prerequisites

### Required Software Installation

```bash
# Docker Desktop
# Download from: https://docs.docker.com/desktop/

# minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
sudo install kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Node.js 18+ (for TypeScript services)
brew install node

# Python 3.11+ (for Python services)
brew install python@3.11

# Rust (for Rust services)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Hardware Requirements
- 16GB RAM minimum
- 8 CPU cores minimum
- 100GB available disk space
- Docker Desktop with 8GB+ memory allocation

## Step 1: Repository Verification

```bash
# Navigate to ABS directory
cd /Users/pwner/Git/ABS

# Verify all 17 repositories exist
ls -la | grep solidity-security | wc -l
# Should return 17

# Verify specific repositories
ls -d solidity-security-*/
```

## Step 2: minikube Setup

### Start minikube Cluster

```bash
# Start minikube with sufficient resources
minikube start \
  --driver=docker \
  --memory=12288 \
  --cpus=6 \
  --disk-size=80g \
  --kubernetes-version=v1.28.0

# Enable required addons
minikube addons enable ingress
minikube addons enable storage-provisioner
minikube addons enable default-storageclass
minikube addons enable metrics-server

# Verify cluster status
minikube status
kubectl cluster-info
```

### Configure Local Registry

```bash
# Start local Docker registry
docker run -d -p 5000:5000 --name registry \
  -v registry-data:/var/lib/registry \
  --restart unless-stopped \
  registry:2

# Verify registry is accessible
curl http://localhost:5000/v2/_catalog
```

## Step 3: Infrastructure Services

### Install PostgreSQL Database

```bash
# Add Bitnami Helm repository
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install PostgreSQL
helm install postgresql bitnami/postgresql \
  --set auth.postgresPassword=dev-password \
  --set auth.database=soliditysecurity \
  --set primary.persistence.enabled=true \
  --set primary.persistence.size=20Gi \
  --namespace default
```

#### Configure API Service Database

After PostgreSQL is installed, create a dedicated database and user for the API service:

```bash
# Get the PostgreSQL pod name
POD_NAME=$(kubectl get pods -n postgresql-local -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')

# Connect to PostgreSQL and create database
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -c "CREATE DATABASE solidity_security;"

# Create dedicated user for API service
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -c "CREATE USER solidity WITH PASSWORD 'solidity-local-password';"

# Grant privileges
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -c "GRANT ALL PRIVILEGES ON DATABASE solidity_security TO solidity;"
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -d solidity_security -c "GRANT ALL ON SCHEMA public TO solidity;"

# Verify database creation
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -c "\l solidity_security"
```

**Database Credentials for Local Development:**
- Database: `solidity_security`
- User: `solidity`
- Password: `solidity-local-password`
- Host: `postgresql.postgresql-local.svc.cluster.local`
- Port: `5432`
- Connection URL: `postgresql+asyncpg://solidity:solidity-local-password@postgresql.postgresql-local.svc.cluster.local:5432/solidity_security`

**Note:** The API service will automatically create necessary tables (`users`, `sessions`) on startup using SQLAlchemy migrations.

### Install Redis Cache

```bash
# Install Redis
helm install redis bitnami/redis \
  --set auth.enabled=false \
  --set master.persistence.enabled=true \
  --set master.persistence.size=10Gi \
  --namespace default
```

### Install HashiCorp Vault (Development)

```bash
# Add HashiCorp Helm repository
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install Vault in development mode
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=dev-root-token" \
  --set "injector.enabled=false" \
  --namespace default
```

### Install Monitoring Stack

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install monitoring stack
helm install monitoring prometheus-community/kube-prometheus-stack \
  --set grafana.adminPassword=admin \
  --namespace monitoring \
  --create-namespace
```

## Step 4: Build Service Images

### Build All Services

```bash
# Navigate to ABS root
cd /Users/pwner/Git/ABS

# Build all service images using existing script
./build-all-images.sh --tag dev --registry localhost:5000

# Verify images built successfully
docker images | grep solidity-security
```

## Step 5: Deploy Services

### Create Kubernetes Manifests

```bash
# Create namespace for services
kubectl create namespace solidity-security

# Deploy backend services using existing k8s manifests
for service in api-service data-service intelligence-engine orchestration notification tool-integration contract-parser; do
  if [ -d "solidity-security-$service/k8s/base" ]; then
    kubectl apply -f solidity-security-$service/k8s/base/ -n solidity-security
  fi
done

# Deploy frontend services
for service in ui-core dashboard findings analysis; do
  if [ -d "solidity-security-$service/k8s/base" ]; then
    kubectl apply -f solidity-security-$service/k8s/base/ -n solidity-security
  fi
done
```

### Configure Environment Variables

```bash
# Create ConfigMap with database and service URLs
kubectl create configmap service-config \
  --from-literal=DATABASE_URL=postgresql://postgres:dev-password@postgresql:5432/soliditysecurity \
  --from-literal=REDIS_URL=redis://redis-master:6379 \
  --from-literal=VAULT_URL=http://vault:8200 \
  --from-literal=VAULT_TOKEN=dev-root-token \
  --namespace solidity-security
```

## Step 6: Access Configuration

### Port Forwarding Setup

```bash
# Forward API service
kubectl port-forward svc/solidity-security-api-service 8000:8000 -n solidity-security &

# Forward main dashboard
kubectl port-forward svc/solidity-security-dashboard 3000:3000 -n solidity-security &

# Forward Grafana
kubectl port-forward svc/monitoring-grafana 3001:80 -n monitoring &

# Access services:
# API: http://localhost:8000
# Dashboard: http://localhost:3000
# Grafana: http://localhost:3001 (admin/admin)
```

### Ingress Configuration

```bash
# Create ingress for services
cat > local-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: solidityops-ingress
  namespace: solidity-security
spec:
  rules:
  - host: api.solidityops.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: solidity-security-api-service
            port:
              number: 8000
  - host: dashboard.solidityops.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: solidity-security-dashboard
            port:
              number: 3000
EOF

kubectl apply -f local-ingress.yaml

# Add hosts to /etc/hosts
echo "$(minikube ip) api.solidityops.local" | sudo tee -a /etc/hosts
echo "$(minikube ip) dashboard.solidityops.local" | sudo tee -a /etc/hosts
```

## Step 7: Verification

### Service Health Checks

```bash
# Check all pods are running
kubectl get pods -n solidity-security

# Check infrastructure services
kubectl get pods -n default | grep -E "(postgresql|redis|vault)"
kubectl get pods -n monitoring

# Test API connectivity
curl http://api.solidityops.local/health
```

### Database Connectivity

```bash
# Test PostgreSQL connection
kubectl exec -it postgresql-0 -- psql -U postgres -d soliditysecurity -c "SELECT version();"

# Test Redis connection
kubectl exec -it redis-master-0 -- redis-cli ping
```

## Step 8: Development Workflow

### Log Monitoring

```bash
# Monitor all service logs
kubectl logs -f -l app=solidity-security -n solidity-security

# Monitor specific service
kubectl logs -f deployment/solidity-security-api-service -n solidity-security
```

### Service Management

```bash
# Restart service after code changes
kubectl rollout restart deployment/solidity-security-api-service -n solidity-security

# Scale service replicas
kubectl scale deployment solidity-security-api-service --replicas=2 -n solidity-security
```

## Environment Management

### Cleanup Commands

```bash
# Stop all port forwards
pkill -f "kubectl port-forward"

# Remove services
kubectl delete namespace solidity-security

# Reset minikube
minikube delete && minikube start
```

### Daily Operations

```bash
# Start development environment
minikube start
kubectl port-forward svc/solidity-security-api-service 8000:8000 -n solidity-security &
kubectl port-forward svc/solidity-security-dashboard 3000:3000 -n solidity-security &

# Stop development environment
minikube stop
```

## Summary

Local development environment provides:

1. **Complete 17-repository architecture** running on minikube
2. **Identical service structure** as production deployment
3. **Full infrastructure services** (PostgreSQL, Redis, Vault, monitoring)
4. **Cost-effective development** with no cloud costs
5. **Production parity** using same Docker images and K8s manifests

The environment is now ready for platform development following the Sprint guides in `/Users/pwner/Git/ABS/docs/Sprints/`.