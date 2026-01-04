# API Service Local Development Configuration

**Last Updated**: October 9, 2025

## Overview

This document describes the local development configuration for the API Service, including dependency management, Kubernetes deployment, and troubleshooting common issues.

## Dependencies

### Python Requirements

The API service uses Python 3.13 with the following critical dependencies:

#### Core Framework
```python
fastapi>=0.104.1,<1.0.0
uvicorn[standard]>=0.24.0,<1.0.0
pydantic>=2.5.0,<3.0.0
pydantic-settings>=2.1.0,<3.0.0
```

#### Database
```python
sqlalchemy>=2.0.23,<3.0.0
alembic>=1.13.0,<2.0.0
asyncpg>=0.29.0,<1.0.0  # PostgreSQL async driver
```

#### Redis
```python
redis>=5.0.1,<6.0.0
hiredis>=2.2.3,<3.0.0
```

#### Authentication (Critical)
```python
python-jose[cryptography]>=3.3.0,<4.0.0
bcrypt==4.2.1  # MUST be pinned to 4.2.1
python-multipart>=0.0.6,<1.0.0
requests>=2.31.0,<3.0.0  # For Supabase JWKS verification
supabase>=2.0.0,<3.0.0  # Supabase authentication client
```

**IMPORTANT**: bcrypt must be pinned to version 4.2.1 due to compatibility issues:
- bcrypt 5.x removed the `__about__` module
- passlib 1.7.4 (transitive dependency) requires `bcrypt.__about__`
- Using bcrypt 5.x causes: `AttributeError: module 'bcrypt' has no attribute '__about__'`

**Supabase Authentication** (Added November 13, 2025):
- System migrated from custom cookie-based auth to Supabase Auth
- Production uses ES256 JWT tokens (ECDSA P-256) with JWKS verification
- Auto-detects algorithm from JWKS (supports both ES256 and RS256)
- JWKS endpoint: `/.well-known/jwks.json` (standard RFC location)
- Local development supports HS256 fallback for testing without Supabase

## Configuration Management

### Settings Architecture

The API service uses Pydantic Settings for configuration management:

**File**: `src/infrastructure/config.py`

```python
from functools import lru_cache
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

    # Configuration fields...
    database_url: PostgresDsn
    redis_url: RedisDsn
    jwt_secret_key: str
    # ...

@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()
```

### Usage Pattern

When importing settings in application code:

```python
# CORRECT
from src.infrastructure.config import get_settings

settings = get_settings()
redis_url = str(settings.redis_url)  # Convert Pydantic types to strings

# INCORRECT
from src.infrastructure.config import settings  # Does not exist!
```

**Important Type Conversions**:
- `RedisDsn` objects must be converted to strings: `str(settings.redis_url)`
- `PostgresDsn` objects must be converted to strings: `str(settings.database_url)`

## Kubernetes Configuration

### Image Versioning

**Local Development Strategy** (Updated November 16, 2025):

For rapid local development iteration, use `:latest` tag with proper rebuild workflow:

```yaml
# Local Development (k8s/overlays/local/deployment-patch.yaml)
spec:
  containers:
  - name: api-service
    image: blocksecops-api-service:latest  # Use :latest for local dev
```

**Local Development Workflow:**
1. Set minikube Docker environment: `eval $(minikube docker-env)`
2. Build with `:latest` tag: `docker build -t blocksecops-api-service:latest .`
3. Apply configuration: `kubectl apply -k k8s/overlays/local`
4. Force rollout: `kubectl rollout restart deployment/api-service -n api-service-local`

**Production/Staging Strategy:**

Always use semantic versioning for production and staging environments:

```yaml
# Production/Staging
images:
- name: api-service
  newTag: 0.1.1-bcrypt-fix
```

**Why versioned tags for production?**
1. Forces Kubernetes to recognize image changes
2. Enables rollback to specific versions
3. Provides audit trail
4. Clear version tracking
5. Enterprise production best practice

**Why `:latest` acceptable for local?**
1. Rapid iteration without version bumps
2. No rollback requirements in local environment
3. Explicit `rollout restart` forces pod recreation
4. Developer convenience for feature development

### Local Development Overlay

**File**: `k8s/overlays/local/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- ../../base/

namespace: api-service-local

images:
- name: api-service
  newTag: latest  # Use :latest for local development

labels:
- includeSelectors: true
  pairs:
    app.kubernetes.io/name: api-service
    app.kubernetes.io/version: latest
    environment: local
```

### Deployment Patch

**File**: `k8s/overlays/local/deployment-patch.yaml`

Key configurations for local development:

```yaml
spec:
  replicas: 1  # Single replica for local dev
  template:
    spec:
      containers:
      - name: api-service
        image: blocksecops-api-service:latest  # Local dev uses :latest
        resources:
          requests:
            memory: "64Mi"   # Minimal for local
            cpu: "50m"
          limits:
            memory: "256Mi"  # Conservative limit
            cpu: "200m"
        env:
        - name: ENVIRONMENT
          value: "local"
        - name: LOG_LEVEL
          value: "debug"
        - name: REDIS_URL
          value: "redis://:redis-local-password@redis.redis-local.svc.cluster.local:6379"
          # IMPORTANT: Include password in URL for authentication
        - name: SUPABASE_URL
          valueFrom:
            secretKeyRef:
              name: api-service-secret
              key: SUPABASE_URL
        - name: SUPABASE_ANON_KEY
          valueFrom:
            secretKeyRef:
              name: api-service-secret
              key: SUPABASE_ANON_KEY
        - name: JWT_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: api-service-secret
              key: JWT_SECRET_KEY
```

**Supabase Configuration** (Added November 13, 2025):

The API service requires Supabase credentials for JWT verification:

- `SUPABASE_URL`: Supabase project URL (e.g., `https://[project-ref].supabase.co`)
- `SUPABASE_ANON_KEY`: Supabase anonymous key for client-side auth
- `JWT_SECRET_KEY`: Secret key for HS256 fallback (local testing only)

**Setting Supabase Secrets:**

```bash
# Get credentials from ~/.zshrc or Supabase dashboard
export SUPABASE_URL="https://huzjlpypdlelqnbjvxad.supabase.co"
export SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Update Kubernetes secret
kubectl patch secret api-service-secret -n api-service-local \
  --type=json \
  -p="[
    {\"op\": \"add\", \"path\": \"/data/SUPABASE_URL\", \"value\": \"$(echo -n $SUPABASE_URL | base64)\"},
    {\"op\": \"add\", \"path\": \"/data/SUPABASE_ANON_KEY\", \"value\": \"$(echo -n $SUPABASE_ANON_KEY | base64)\"}
  ]"

# Restart deployment to pick up new secrets
kubectl rollout restart deployment/api-service -n api-service-local
```

### Redis Authentication

Local Redis instance requires authentication. URL format:

```
redis://:password@host:port/db
```

Example:
```
redis://:redis-local-password@redis.redis-local.svc.cluster.local:6379/0
```

**Common Error**: If password is missing:
```
redis.exceptions.AuthenticationError: Authentication required
```

**Solution**: Update deployment-patch.yaml with authenticated URL.

## Resource Management

### Local Development Resources

For local Minikube development on MacBook (16GB RAM):

**Per Service**:
- Replicas: 1 (no HPA)
- Memory Request: 64Mi
- Memory Limit: 256Mi
- CPU Request: 50m
- CPU Limit: 200m

**Why?**
- Conserves limited laptop resources
- HPA unnecessary for local development
- Allows running full stack (8+ services) simultaneously
- Production uses different resource profiles

### Memory Optimization

If experiencing memory pressure:

1. **Check current usage**:
   ```bash
   kubectl top nodes
   ```

2. **Scale down services**:
   ```bash
   kubectl scale deployment <service> --replicas=1 -n <namespace>
   ```

3. **Delete HPAs in local namespaces**:
   ```bash
   kubectl get hpa -A | grep local
   kubectl delete hpa <hpa-name> -n <namespace>
   ```

4. **Disable Grafana** (if not actively monitoring):
   ```bash
   kubectl scale deployment grafana --replicas=0 -n monitoring-local
   ```

Expected local memory usage: **60-70%** of Minikube allocation

## Deployment Workflow

### Building and Deploying Changes

1. **Set Minikube Docker environment**:
   ```bash
   eval $(minikube docker-env)
   ```

2. **Build with versioned tag**:
   ```bash
   docker build -t api-service:0.1.2 .
   ```

3. **Update kustomization.yaml**:
   ```yaml
   images:
   - name: api-service
     newTag: 0.1.2
   ```

4. **Apply configuration**:
   ```bash
   kubectl apply -k k8s/overlays/local
   ```

5. **Verify deployment**:
   ```bash
   kubectl rollout status deployment/api-service -n api-service-local
   kubectl get pods -n api-service-local
   ```

6. **Check image is correct**:
   ```bash
   kubectl get pods -n api-service-local -o jsonpath='{.items[0].spec.containers[0].image}'
   ```

## Troubleshooting

### Issue: bcrypt AttributeError

**Error**:
```
AttributeError: module 'bcrypt' has no attribute '__about__'
password cannot be longer than 72 bytes, truncate manually if necessary
```

**Solution**:
1. Verify `requirements/base.txt` has: `bcrypt==4.2.1`
2. Rebuild Docker image
3. Redeploy with new image tag

### Issue: ImportError for settings

**Error**:
```
ImportError: cannot import name 'settings' from 'src.infrastructure.config'
```

**Solution**:
```python
# Change from:
from src.infrastructure.config import settings

# To:
from src.infrastructure.config import get_settings
settings = get_settings()
```

### Issue: Redis Type Error

**Error**:
```
AttributeError: 'RedisDsn' object has no attribute 'decode'
```

**Solution**:
```python
# Convert Pydantic type to string
redis_client = aioredis.from_url(
    str(settings.redis_url),  # Add str() conversion
    encoding="utf-8"
)
```

### Issue: Redis Authentication Error

**Error**:
```
redis.exceptions.AuthenticationError: Authentication required
```

**Solution**:
Update `k8s/overlays/local/deployment-patch.yaml`:
```yaml
- name: REDIS_URL
  value: "redis://:redis-local-password@redis.redis-local.svc.cluster.local:6379"
```

### Issue: Pods Using Old Image

**Symptoms**:
- Rebuilt Docker image but changes not reflected
- `kubectl describe pod` shows old image ID

**Solution**:
1. Use versioned tags instead of `:latest`
2. Update kustomization.yaml with new version
3. Apply configuration: `kubectl apply -k k8s/overlays/local`
4. Force rollout: `kubectl rollout restart deployment/api-service -n api-service-local`

### Issue: HPA Overriding Replica Count

**Symptoms**:
- Set `replicas: 1` but deployment has multiple pods
- `kubectl get hpa` shows active HPA

**Solution**:
```bash
kubectl delete hpa api-service-hpa -n api-service-local
kubectl scale deployment api-service --replicas=1 -n api-service-local
```

## Testing

### Port Forwarding

```bash
kubectl port-forward -n api-service-local svc/api-service 8000:8000
```

### API Health Check

```bash
curl http://localhost:8000/
# Expected: {"message":"BlockSecOps API Service","status":"running","version":"0.1.0"}
```

### Authentication Test (Supabase)

**Updated November 13, 2025** - Authentication is now handled by Supabase.

1. **Check User Quota** (authenticated endpoint):
   ```bash
   # Generate test JWT token first (see integration tests for token generation)
   TOKEN="eyJhbGci..."  # HS256 token for local testing

   curl -X GET http://localhost:8000/api/v1/users/quota \
     -H "Authorization: Bearer $TOKEN"
   ```

2. **Expected Response**:
   ```json
   {
     "tier": "free",
     "monthly_scan_limit": 10,
     "monthly_scans_used": 0,
     "scans_remaining": 10,
     "percentage_used": 0.0,
     "quota_reset_at": "2025-12-01T00:00:00+00:00",
     "days_until_reset": 15,
     "last_scan_at": null,
     "max_files_per_scan": 25,
     "scan_priority": 25,
     "webhooks_enabled": false,
     "api_access_enabled": false
   }
   ```

3. **Unauthenticated Request** (should fail):
   ```bash
   curl -X GET http://localhost:8000/api/v1/users/quota
   # Returns: {"detail":[{"type":"missing","loc":["header","authorization"],"msg":"Field required"}]}
   ```

**JWT Token Generation for Testing:**

See integration tests in `tests/conftest.py` for the `authenticated_session` fixture that demonstrates how to generate valid HS256 JWT tokens for local testing without a Supabase instance.

### End-to-End Workflow Test

See `/Users/pwner/Git/ABS/TaskDocs/BlockSecOps/api-test-results-summary.md` for comprehensive test scripts.

## Security Considerations

### Local Development Secrets

Local development uses simplified secrets:

```yaml
JWT_SECRET_KEY: "local-dev-jwt-secret-key-change-in-production"
SESSION_SECRET: "local-dev-session-secret-change-in-production"
REDIS_PASSWORD: "redis-local-password"
```

**NEVER use these values in staging or production environments.**

### Production Differences

Production configuration differs significantly:

1. **Secrets**: Managed via HashiCorp Vault and External Secrets Operator
2. **Replicas**: 3+ with HPA (min: 2, max: 10)
3. **Resources**: Much higher memory/CPU allocations
4. **TLS**: All communications encrypted
5. **Network Policies**: Strict ingress/egress rules

## References

- [Scanner Execution Architecture](./scanner-execution-architecture.md)
- [Kubernetes Deployment Guide](../local-development/kubernetes-setup.md)
- [API Documentation](../api/README.md)

---

**Maintainer**: Backend Team
**Last Verified**: October 9, 2025
**Next Review**: November 2025
