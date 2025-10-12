# API Service Deployment Guide

## Overview

This guide covers the deployment of `blocksecops-api-service` to the local minikube environment. The API service is a FastAPI application that provides authentication, API gateway functionality, and serves as the entry point for the platform.

## Architecture

**Technology Stack:**
- **Framework:** FastAPI (Python)
- **Architecture:** Clean Architecture with 4 layers
  - Domain: Business entities (User)
  - Application: Use case handlers (AuthHandler)
  - Infrastructure: External dependencies (Database, JWT, Config)
  - Presentation: API endpoints (Health, Auth)
- **Database:** PostgreSQL with async SQLAlchemy
- **Authentication:** JWT with access and refresh tokens
- **Security:** bcrypt password hashing

## Prerequisites

1. Minikube cluster running
2. PostgreSQL deployed in `postgresql-local` namespace
3. Redis deployed in `redis-local` namespace
4. Vault deployed in `vault-local` namespace (optional)

## Database Setup

### Create Dedicated Database

The API service requires a dedicated PostgreSQL database:

```bash
# Get PostgreSQL pod name
POD_NAME=$(kubectl get pods -n postgresql-local -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')

# Create database
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -c "CREATE DATABASE blocksecops;"

# Create user
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -c "CREATE USER solidity WITH PASSWORD 'solidity-local-password';"

# Grant privileges
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -c "GRANT ALL PRIVILEGES ON DATABASE blocksecops TO solidity;"
kubectl exec -n postgresql-local $POD_NAME -- psql -U harbor -d blocksecops -c "GRANT ALL ON SCHEMA public TO solidity;"

# Verify
kubectl exec -n postgresql-local $POD_NAME -- psql -U solidity -d blocksecops -c "\dt"
```

**Database Credentials:**
- Database: `blocksecops`
- User: `solidity`
- Password: `solidity-local-password`
- Host: `postgresql.postgresql-local.svc.cluster.local:5432`

## Configuration

### Kubernetes Secrets

Create the secret with database and authentication configuration:

```bash
kubectl create secret generic api-service-secret -n api-service-local \
  --from-literal=DATABASE_URL='postgresql+asyncpg://solidity:solidity-local-password@postgresql.postgresql-local.svc.cluster.local:5432/blocksecops' \
  --from-literal=REDIS_URL='redis://redis-master.redis-local.svc.cluster.local:6379/0' \
  --from-literal=JWT_SECRET_KEY='local-dev-jwt-secret-key-change-in-production' \
  --from-literal=SESSION_SECRET='local-dev-session-secret-change-in-production'
```

**Security Note:** These secrets are for local development only. Production should use Vault or AWS Secrets Manager.

### ConfigMap

The ConfigMap contains non-sensitive configuration:

```bash
kubectl get configmap api-service-config -n api-service-local -o yaml
```

Key configuration values:
- `environment`: `local`
- `log_level`: `DEBUG`
- `cors_origins`: Allowed origins for CORS

## Build and Deploy

### Build Docker Image

```bash
# Navigate to api-service repository
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Build Docker image
docker build -t localhost:8080/library/api-service:latest .

# Load into minikube
minikube image load localhost:8080/library/api-service:latest
```

### Deploy to Kubernetes

```bash
# Deploy using kustomize
kubectl apply -k k8s/overlays/local/

# Or use the pre-generated manifest (if kustomize has issues)
kubectl apply -f k8s/overlays/local/generated-manifest.yaml

# Check deployment status
kubectl get pods -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local
```

## Verification

### Check Pod Status

```bash
# List all pods
kubectl get pods -n api-service-local

# Should see pods with status 1/1 Running
# Example output:
# NAME                           READY   STATUS    RESTARTS   AGE
# api-service-7599655588-4mvgq   1/1     Running   0          5m
```

### Check Database Tables

The application automatically creates tables on startup:

```bash
# Verify tables exist
kubectl exec -n postgresql-local postgresql-0 -- psql -U solidity -d blocksecops -c "\dt"

# Expected tables:
# - users
# - sessions
```

### Test Health Endpoints

```bash
# Port forward to the service
kubectl port-forward -n api-service-local svc/api-service 8001:8000 &

# Test liveness endpoint
curl http://localhost:8001/api/v1/health/live | jq

# Test readiness endpoint (includes database check)
curl http://localhost:8001/api/v1/health/ready | jq

# Test startup endpoint
curl http://localhost:8001/api/v1/health/startup | jq

# Stop port forward
lsof -ti:8001 | xargs kill
```

### Access OpenAPI Documentation

```bash
# Port forward if not already running
kubectl port-forward -n api-service-local svc/api-service 8001:8000 &

# Open in browser
open http://localhost:8001/docs
```

The OpenAPI (Swagger) documentation provides:
- Interactive API testing
- Request/response schemas
- Authentication flows
- All available endpoints

## API Endpoints

### Health Check Endpoints

- `GET /api/v1/health/live` - Liveness probe
- `GET /api/v1/health/ready` - Readiness probe (includes DB check)
- `GET /api/v1/health/startup` - Startup probe

### Authentication Endpoints

- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Refresh access token

### Documentation Endpoints

- `GET /docs` - Swagger UI
- `GET /redoc` - ReDoc UI
- `GET /openapi.json` - OpenAPI schema

## Troubleshooting

### Pods Not Starting

**Check logs:**
```bash
kubectl logs -n api-service-local -l app=api-service --tail=100
```

**Common issues:**
1. Database connection errors - verify secret contains correct DATABASE_URL
2. Secret not found - ensure `api-service-secret` exists
3. Image pull errors - verify image is loaded into minikube

### Health Checks Failing

**Verify probe paths match application routes:**
```bash
# Deployment should use these paths:
# livenessProbe: /api/v1/health/live
# readinessProbe: /api/v1/health/ready
# startupProbe: /api/v1/health/startup

kubectl get deployment api-service -n api-service-local -o yaml | grep -A 5 "Probe"
```

**Update probe paths if needed:**
```bash
kubectl patch deployment api-service -n api-service-local --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/path", "value": "/api/v1/health/live"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path", "value": "/api/v1/health/ready"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/startupProbe/httpGet/path", "value": "/api/v1/health/startup"}
]'
```

### Database Connection Issues

**Test database connectivity:**
```bash
# From PostgreSQL pod
kubectl exec -n postgresql-local postgresql-0 -- psql -U solidity -d blocksecops -c "SELECT 1;"

# Verify connection string in secret
kubectl get secret api-service-secret -n api-service-local -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

**Recreate secret if needed:**
```bash
kubectl delete secret api-service-secret -n api-service-local
kubectl create secret generic api-service-secret -n api-service-local \
  --from-literal=DATABASE_URL='postgresql+asyncpg://solidity:solidity-local-password@postgresql.postgresql-local.svc.cluster.local:5432/blocksecops' \
  --from-literal=REDIS_URL='redis://redis-master.redis-local.svc.cluster.local:6379/0' \
  --from-literal=JWT_SECRET_KEY='local-dev-jwt-secret-key-change-in-production' \
  --from-literal=SESSION_SECRET='local-dev-session-secret-change-in-production'

# Restart pods to pick up new secret
kubectl rollout restart deployment/api-service -n api-service-local
```

### High Memory Usage / Excessive Scaling

The HorizontalPodAutoscaler may scale pods excessively in local development:

```bash
# Check HPA status
kubectl get hpa -n api-service-local

# Adjust limits for local development
kubectl patch hpa api-service-hpa -n api-service-local --type='json' -p='[
  {"op": "replace", "path": "/spec/minReplicas", "value": 2},
  {"op": "replace", "path": "/spec/maxReplicas", "value": 5}
]'

# Scale deployment manually if needed
kubectl scale deployment api-service -n api-service-local --replicas=3
```

## Development Workflow

### View Logs

```bash
# Follow logs from all pods
kubectl logs -f -n api-service-local -l app=api-service

# Logs from specific pod
kubectl logs -f -n api-service-local <pod-name>
```

### Restart After Code Changes

```bash
# Rebuild image
cd /Users/pwner/Git/ABS/blocksecops-api-service
docker build -t localhost:8080/library/api-service:latest .
minikube image load localhost:8080/library/api-service:latest

# Restart deployment
kubectl rollout restart deployment/api-service -n api-service-local

# Wait for rollout to complete
kubectl rollout status deployment/api-service -n api-service-local
```

### Test Authentication Flow

```bash
# Register a new user
curl -X POST http://localhost:8001/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}' | jq

# Login
curl -X POST http://localhost:8001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}' | jq

# Save access token from response
export ACCESS_TOKEN="<token-from-login-response>"

# Use token for authenticated requests (when implemented)
curl -X GET http://localhost:8001/api/v1/user/profile \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq
```

## Production Considerations

When deploying to staging or production environments:

1. **Secrets Management**
   - Use Vault or AWS Secrets Manager
   - Rotate JWT secret keys regularly
   - Use strong, random session secrets

2. **Database**
   - Use managed PostgreSQL (AWS RDS, etc.)
   - Enable SSL/TLS connections
   - Configure connection pooling appropriately
   - Set up automated backups

3. **Scaling**
   - Adjust HPA thresholds based on load testing
   - Set appropriate resource requests/limits
   - Consider using VPA (Vertical Pod Autoscaler)

4. **Security**
   - Enable network policies
   - Use pod security policies
   - Implement rate limiting
   - Enable CORS only for trusted origins
   - Use HTTPS/TLS for all external connections

5. **Monitoring**
   - Set up alerts for health check failures
   - Monitor database connection pool
   - Track authentication failures
   - Monitor API response times

## Summary

The API service is now deployed and provides:
- ✅ Health check endpoints for Kubernetes probes
- ✅ JWT-based authentication system
- ✅ Database with auto-migration on startup
- ✅ OpenAPI documentation at /docs
- ✅ Automatic table creation (users, sessions)
- ✅ HPA for autoscaling (2-5 replicas in local)

**Service Access:**
- Internal: `http://api-service.api-service-local.svc.cluster.local:8000`
- Port Forward: `kubectl port-forward -n api-service-local svc/api-service 8001:8000`
- OpenAPI Docs: `http://localhost:8001/docs`
