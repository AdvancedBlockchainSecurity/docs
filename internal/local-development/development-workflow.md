# Development Workflow Guide

> **🚀 Complete guide for daily development using the local environment**

## Overview

This guide provides step-by-step instructions for using the local development environment effectively. Follow these workflows for common development tasks from starting your session to deploying and testing changes.

## 🚀 Daily Development Workflow

### Starting Your Development Session

```bash
# 1. Start the minikube cluster
minikube start

# 2. Verify everything is running
kubectl get pods -A

# 3. Check that databases are healthy
kubectl exec $(kubectl get pods -l app=postgresql -o name) -- psql -U postgres -d soliditysecurity -c "SELECT 1;"
kubectl exec $(kubectl get pods -l app=redis -o name) -- redis-cli ping

# 4. (Optional) Access monitoring dashboard
kubectl port-forward svc/monitoring-grafana 3001:80 -n monitoring &
# Open http://localhost:3001 (admin/admin)
```

**Expected Output:**
```
✅ minikube started successfully
✅ All pods running
✅ PostgreSQL: ?column? = 1
✅ Redis: PONG
✅ Grafana accessible at localhost:3001
```

## 💻 Development Tasks

### Working with Services

#### 1. **Making Code Changes**
```bash
# Navigate to any service
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Make your code changes in src/, tests/, etc.
# Edit files as needed with your preferred editor
```

#### 2. **Testing Changes Locally**
```bash
# Install dependencies locally for development
pip install -e .

# Run tests (if available)
python -m pytest tests/

# Run the service locally (outside container)
python src/main.py
```

#### 3. **Building Updated Docker Images**
```bash
# Rebuild the Docker image with your changes
docker build -t localhost:5000/blocksecops-api-service:dev .

# Push to local registry
docker push localhost:5000/blocksecops-api-service:dev

# Verify image is in registry
curl http://localhost:5000/v2/_catalog
```

**Expected Output:**
```json
{"repositories":["blocksecops-api-service"]}
```

#### 4. **Deploying Changes to Kubernetes**
```bash
# If you have k8s manifests, apply them
kubectl apply -f k8s/base/ -n blocksecops

# Or create a simple deployment
kubectl create deployment api-service \
  --image=localhost:5000/blocksecops-api-service:dev \
  -n blocksecops

# Expose the service
kubectl expose deployment api-service \
  --port=8000 --target-port=8000 \
  -n blocksecops
```

#### 5. **Accessing Your Service**
```bash
# Port forward to access locally
kubectl port-forward svc/api-service 8000:8000 -n blocksecops &

# Test your API
curl http://localhost:8000/health
```

### Working with the Shared Library

#### 1. **Modifying Shared Library**
```bash
# Navigate to shared library
cd /Users/pwner/Git/ABS/blocksecops-shared

# Make changes to Python code in python/src/solidity_shared/
# Edit schemas.py, utils.py, etc.
```

#### 2. **Rebuilding Shared Library**
```bash
# Rebuild the wheel
cd python
python3 setup_simple.py bdist_wheel

# Redistribute to services
for service in blocksecops-api-service blocksecops-data-service blocksecops-intelligence-engine blocksecops-orchestration blocksecops-tool-integration; do
    cp dist/blocksecops_shared-0.1.0-py3-none-any.whl /Users/pwner/Git/ABS/$service/
done
```

#### 3. **Testing Shared Library Changes**
```bash
# Install locally to test
pip install dist/blocksecops_shared-0.1.0-py3-none-any.whl --force-reinstall

# Test import
python3 -c "import solidity_shared; print('✅ Shared library working')"

# Rebuild any services that use it
cd /Users/pwner/Git/ABS/blocksecops-api-service
docker build -t localhost:5000/blocksecops-api-service:dev .
```

## 🔍 Monitoring and Debugging

### Accessing Logs
```bash
# View logs for a specific service
kubectl logs -f deployment/api-service -n blocksecops

# View logs for infrastructure
kubectl logs -f $(kubectl get pods -l app=postgresql -o name) -n default
kubectl logs -f $(kubectl get pods -l app=redis -o name) -n default

# Follow logs with timestamp
kubectl logs -f deployment/api-service -n 0xapogee --timestamps=true
```

### Database Access
```bash
# Connect to PostgreSQL
kubectl exec -it $(kubectl get pods -l app=postgresql -o name) -- psql -U postgres -d soliditysecurity

# Example queries
-- \l                    -- List databases
-- \dt                   -- List tables
-- SELECT version();     -- Check version
-- \q                    -- Quit

# Connect to Redis
kubectl exec -it $(kubectl get pods -l app=redis -o name) -- redis-cli

# Example Redis commands
# PING                   # Test connection
# KEYS *                 # List all keys
# INFO                   # Server information
# EXIT                   # Quit
```

### Monitoring Dashboard
```bash
# Access Grafana
kubectl port-forward svc/monitoring-grafana 3001:80 -n monitoring &
# Open http://localhost:3001 (admin/admin)

# Access Prometheus (if needed)
kubectl port-forward svc/prometheus-monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &
# Open http://localhost:9090

# Access AlertManager (if needed)
kubectl port-forward svc/alertmanager-monitoring-kube-prometheus-alertmanager 9093:9093 -n monitoring &
```

## 🧪 Testing Your Changes

### Integration Testing
```bash
# Deploy all services you're working with
kubectl apply -f service1/k8s/ -n blocksecops
kubectl apply -f service2/k8s/ -n blocksecops

# Test service-to-service communication
kubectl exec -it $(kubectl get pods -l app=api-service -o name) -- curl http://data-service:8001/health

# Check service discovery
kubectl exec -it $(kubectl get pods -l app=api-service -o name) -- nslookup data-service.0xapogee.svc.cluster.local
```

### End-to-End Testing
```bash
# Port forward multiple services
kubectl port-forward svc/api-service 8000:8000 -n blocksecops &
kubectl port-forward svc/data-service 8001:8001 -n blocksecops &

# Test workflows
curl -X POST http://localhost:8000/api/v1/analyze \
  -H "Content-Type: application/json" \
  -d '{"contract": "...", "analysis_type": "security"}'

# Test database connectivity through API
curl http://localhost:8000/api/v1/health/database
```

### Performance Testing
```bash
# Simple load test with curl
for i in {1..10}; do
  curl -s http://localhost:8000/health &
done
wait

# Monitor resource usage during testing
kubectl top pods -n blocksecops
```

## 🛠️ Common Development Tasks

### Adding a New Service

#### 1. **Create Service Structure**
```bash
# Create new service directory
mkdir /Users/pwner/Git/ABS/blocksecops-new-service
cd /Users/pwner/Git/ABS/blocksecops-new-service

# Create basic structure
mkdir -p src tests requirements k8s/base
```

#### 2. **Set Up Dependencies**
```bash
# Copy shared library wheel
cp ../blocksecops-shared/python/dist/blocksecops_shared-0.1.0-py3-none-any.whl .

# Create requirements file
cat > requirements/base.txt << EOF
fastapi>=0.104.1,<1.0.0
uvicorn[standard]>=0.24.0,<1.0.0
pydantic>=2.5.0,<3.0.0
blocksecops-shared>=0.1.0
EOF
```

#### 3. **Create Dockerfile**
```bash
# Copy and modify existing Dockerfile
cp ../blocksecops-api-service/Dockerfile .

# Update service name and port as needed
sed -i 's/api-service/new-service/g' Dockerfile
```

#### 4. **Build and Test**
```bash
# Build image
docker build -t localhost:5000/blocksecops-new-service:dev .

# Push to registry
docker push localhost:5000/blocksecops-new-service:dev

# Create deployment
kubectl create deployment new-service \
  --image=localhost:5000/blocksecops-new-service:dev \
  -n blocksecops
```

### Database Migrations

#### PostgreSQL Schema Changes
```bash
# Connect to PostgreSQL
kubectl exec -it $(kubectl get pods -l app=postgresql -o name) -- psql -U postgres -d soliditysecurity

# Run your SQL migrations
CREATE TABLE IF NOT EXISTS vulnerabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

# Verify table creation
\dt vulnerabilities
```

#### Adding Indexes
```sql
-- Add performance indexes
CREATE INDEX IF NOT EXISTS idx_vulnerabilities_severity ON vulnerabilities(severity);
CREATE INDEX IF NOT EXISTS idx_vulnerabilities_created_at ON vulnerabilities(created_at);
```

### Environment Variables

#### Updating Service Configuration
```bash
# Update ConfigMap with new environment variables
kubectl patch configmap service-config -n 0xapogee --patch='
data:
  NEW_ENV_VAR: "new_value"
  API_RATE_LIMIT: "1000"
  LOG_LEVEL: "DEBUG"
'

# Restart services to pick up changes
kubectl rollout restart deployment/api-service -n blocksecops

# Verify environment variables
kubectl exec $(kubectl get pods -l app=api-service -o name) -- env | grep NEW_ENV_VAR
```

#### Service-Specific Environment
```bash
# Add environment variables to specific deployment
kubectl patch deployment api-service -n 0xapogee --patch='
spec:
  template:
    spec:
      containers:
      - name: api-service
        env:
        - name: SERVICE_SPECIFIC_VAR
          value: "service_value"
'
```

## 📊 Health Checks and Monitoring

### Quick Daily Check Script

Create a daily health check script:

```bash
# Save as ~/check-dev-env.sh
#!/bin/bash

echo "🔍 Development Environment Health Check"
echo "====================================="

# Cluster
minikube status | grep -q "Running" && echo "✅ minikube" || echo "❌ minikube"

# Databases
kubectl exec -q $(kubectl get pods -l app=postgresql -o name) -- psql -U postgres -c "SELECT 1;" >/dev/null 2>&1 && echo "✅ PostgreSQL" || echo "❌ PostgreSQL"
kubectl exec -q $(kubectl get pods -l app=redis -o name) -- redis-cli ping >/dev/null 2>&1 && echo "✅ Redis" || echo "❌ Redis"

# Registry
curl -s http://localhost:5000/v2/_catalog >/dev/null && echo "✅ Registry" || echo "❌ Registry"

# Shared library
python3 -c "import solidity_shared" 2>/dev/null && echo "✅ Shared library" || echo "❌ Shared library"

# Services (if deployed)
kubectl get deployments -n 0xapogee --no-headers 2>/dev/null | while read name ready uptodate available age; do
  if [ "$ready" = "$available" ] && [ "$available" != "0" ]; then
    echo "✅ Service: $name"
  else
    echo "❌ Service: $name ($ready/$available)"
  fi
done

echo "====================================="

# Resource usage
echo "📊 Resource Usage:"
kubectl top nodes 2>/dev/null || echo "Metrics not available"

echo "====================================="
echo "✅ Health check complete!"
```

```bash
# Make executable and run
chmod +x ~/check-dev-env.sh
~/check-dev-env.sh
```

### Port-Forward Management

**IMPORTANT**: Port-forwards die when pods restart during deployments.

#### Restarting Port-Forwards After Deployment
```bash
# Kill existing port-forwards on port 8000
lsof -ti:8000 | xargs kill -9 2>/dev/null

# Wait for pods to stabilize
sleep 2

# Restart API port-forward
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &

# Verify connection
curl http://localhost:8000/api/v1/health/live
```

#### Common Port-Forward Issues
```bash
# Check if port is in use
lsof -ti:8000

# Check which process is using the port
lsof -i:8000

# Kill all kubectl port-forward processes
pkill -f "kubectl port-forward"

# Restart multiple port-forwards
lsof -ti:8000 | xargs kill -9 2>/dev/null
lsof -ti:8003 | xargs kill -9 2>/dev/null
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &
kubectl port-forward -n notification-local svc/notification 8003:8003 &
```

### Detailed Troubleshooting Commands

#### Pod Issues
```bash
# Check pod status
kubectl get pods -A | grep -v Running

# Describe problematic pods
kubectl describe pod <pod-name> -n <namespace>

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check events for issues
kubectl get events --sort-by=.metadata.creationTimestamp -A
```

#### Network Issues
```bash
# Check service endpoints
kubectl get endpoints -A

# Test DNS resolution
kubectl run debug --image=busybox --rm -it --restart=Never -- nslookup postgresql.default.svc.cluster.local

# Check service connectivity
kubectl run debug --image=busybox --rm -it --restart=Never -- telnet postgresql.default.svc.cluster.local 5432
```

#### Storage Issues
```bash
# Check persistent volumes
kubectl get pv
kubectl get pvc -A

# Check storage usage in pods
kubectl exec <pod-name> -- df -h
```

## 🔄 Advanced Workflows

### Hot Reloading Development

#### Using Development Mode
```bash
# Mount local code into container for hot reloading
kubectl create deployment api-service-dev \
  --image=localhost:5000/blocksecops-api-service:dev \
  -n blocksecops

# Edit deployment to mount local volume (for development)
kubectl patch deployment api-service-dev -n 0xapogee --patch='
spec:
  template:
    spec:
      containers:
      - name: blocksecops-api-service
        volumeMounts:
        - name: source-code
          mountPath: /app/src
      volumes:
      - name: source-code
        hostPath:
          path: /Users/pwner/Git/ABS/blocksecops-api-service/src
'
```

### Multi-Service Development

#### Deploy Full Stack
```bash
# Deploy multiple related services
services=("api-service" "data-service" "intelligence-engine")

for service in "${services[@]}"; do
  echo "Deploying $service..."

  # Build image
  cd /Users/pwner/Git/ABS/blocksecops-$service
  docker build -t localhost:5000/blocksecops-$service:dev .
  docker push localhost:5000/blocksecops-$service:dev

  # Deploy to kubernetes
  kubectl create deployment $service \
    --image=localhost:5000/blocksecops-$service:dev \
    -n blocksecops

  # Expose service
  kubectl expose deployment $service \
    --port=8000 --target-port=8000 \
    -n blocksecops
done
```

#### Test Service Communication
```bash
# Port forward all services
kubectl port-forward svc/api-service 8000:8000 -n blocksecops &
kubectl port-forward svc/data-service 8001:8001 -n blocksecops &
kubectl port-forward svc/intelligence-engine 8002:8002 -n blocksecops &

# Test service chain
curl -X POST http://localhost:8000/api/v1/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "contract_code": "pragma solidity ^0.8.0; contract Test {}",
    "analysis_type": "comprehensive"
  }'
```

## 🛑 Stopping Development Session

### Clean Shutdown
```bash
# Stop port forwards
pkill -f "kubectl port-forward"

# Scale down deployments (optional - saves resources)
kubectl scale deployment --all --replicas=0 -n blocksecops

# Stop minikube (preserves state)
minikube stop
```

### Complete Reset
```bash
# Delete all deployments
kubectl delete deployment --all -n blocksecops

# Or delete entire namespace
kubectl delete namespace blocksecops
kubectl create namespace blocksecops

# Or completely reset minikube
minikube delete
# Then follow setup-summary.md to recreate
```

## 📚 Quick Reference

### Key URLs
- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090 (when port-forwarded)
- **Registry**: http://localhost:5000/v2/_catalog
- **Services**: http://localhost:8000+ (when port-forwarded)

### Key Commands Reference

#### Environment Management
```bash
# Status check
minikube status && kubectl get pods -A

# Start/stop
minikube start / minikube stop

# Resource usage
kubectl top nodes && kubectl top pods -A
```

#### Service Development
```bash
# Build and deploy
docker build -t localhost:5000/service:dev . && docker push localhost:5000/service:dev
kubectl create deployment service --image=localhost:5000/service:dev -n blocksecops

# Access service
kubectl port-forward svc/service 8000:8000 -n blocksecops

# Update deployment
kubectl set image deployment/service service=localhost:5000/service:dev -n blocksecops
```

#### Debugging
```bash
# Logs
kubectl logs -f deployment/service -n blocksecops

# Shell access
kubectl exec -it deployment/service -n 0xapogee -- /bin/bash

# Database access
kubectl exec -it $(kubectl get pods -l app=postgresql -o name) -- psql -U postgres -d soliditysecurity
```

### Key Directories
- **Services**: `/Users/pwner/Git/ABS/blocksecops-*/`
- **Shared Library**: `/Users/pwner/Git/ABS/blocksecops-shared/`
- **Documentation**: `/Users/pwner/Git/ABS/blocksecops-docs/local-development/`
- **Scripts**: `~/check-dev-env.sh`

## 🎯 Pro Tips

### Efficiency Tips
1. **Use aliases** for common commands:
   ```bash
   alias k='kubectl'
   alias kgp='kubectl get pods'
   alias kns='kubectl config set-context --current --namespace'
   ```

2. **Create development scripts** for repetitive tasks
3. **Use kubectl contexts** for different environments
4. **Monitor resource usage** to avoid running out of memory
5. **Keep port-forward sessions** in separate terminal tabs

### Best Practices
- **Always verify environment health** before starting development
- **Test locally first** before building Docker images
- **Use meaningful commit messages** when testing image builds
- **Clean up unused images** to save disk space: `docker system prune`
- **Document any new environment variables** or configuration changes

---

**Guide Version**: 1.0
**Last Updated**: October 2, 2025
**Environment**: Local Development minikube
**Status**: ✅ Ready for daily development use