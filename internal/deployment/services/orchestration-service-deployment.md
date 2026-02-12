# Orchestration Service Deployment

## Overview

The BlockSecOps Orchestration Service is a FastAPI-based REST API that manages smart contract security scanning workflows. It exposes 11 security scanners through HTTP endpoints, providing programmatic access to vulnerability detection, code quality analysis, gas optimization, fuzzing, and formal verification tools.

**Current Version**: 0.7.14-parser-fix (Phase 4D - Parser Fixes Deployed)
**Previous Version**: 0.7.13-fix (Phase 4D - Tree-sitter API Fix)
**Architecture**: FastAPI with background task execution
**Port**: 8004
**Documentation**: Auto-generated OpenAPI at `/api/v1/docs`

## Latest Updates (October 24, 2025)

### v0.7.14-parser-fix - Parser Data Extraction Fix

**Status**: ✅ Deployed to Kubernetes (4:30 PM PT)

**Critical Fix**: All 6 vulnerability parsers updated to extract required fields for enrichment system.

**Parsers Fixed**:
- SlitherParser - Added `detector_id`, `file_path`, `function_name`, `contract_name`
- AderynParser - Added all required enrichment fields
- SemgrepParser - Added `detector_id`, `file_path`, `contract_name`
- MythrilParser - Fixed signature, severity mapping, added all fields
- WakeParser - Fixed signature, severity mapping, added all fields
- FournalyzerParser - Fixed signature and data format

**Impact**: Enables pattern matching and fingerprinting for all vulnerability findings.

**Documentation**: See `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/03-phase-4-intelligence/PHASE-4D-PARSER-CLASSIFICATION-FIX-COMPLETE.md`

### v0.7.13-fix - Tree-sitter API Compatibility Fix

**Status**: ✅ Deployed and Verified

**Fix**: Updated AST hasher to support both old and new tree-sitter API versions.

**Evidence**: Enrichment service successfully initializes and processes findings.

## Architecture

### Components (v0.7.0)

1. **FastAPI REST Server** (`orchestration`)
   - HTTP API on port 8004
   - Background task execution for async scanner runs
   - OpenAPI documentation at `/api/v1/docs`
   - Health probes for Kubernetes

2. **Scanner Registry** (11 Scanners)
   - Slither, Aderyn, Mythril, Wake (Vulnerability Detection)
   - Solhint, Semgrep (Code Quality)
   - Echidna, Medusa, Foundry Fuzz (Fuzzing)
   - Halmos (Formal Verification)
   - 4naly3er (Gas Optimization)

3. **Parser Registry** (11 Parsers)
   - Type-based finding classification
   - Unified `ParsedFinding` format
   - Scanner-specific output transformation

### Key Features

- **11 Security Scanners**: Complete security analysis suite via REST API
- **Async Execution**: Background tasks for non-blocking scanner execution
- **Type-Safe API**: Pydantic models for request/response validation
- **Auto Documentation**: OpenAPI/Swagger UI automatically generated
- **Scanner Management**: List scanners, check availability, execute scans
- **Result Retrieval**: Get scan status, findings, and complete results
- **CORS Enabled**: Configured for local development and production

## Prerequisites

- Kubernetes cluster (Minikube for local development)
- Docker registry for container images
- 11 security scanner binaries (built into Docker image)

**Note**: v0.7.0 uses in-memory storage for scan results. Database persistence will be added in Phase 6.

## Environment Configuration

### Required Environment Variables

```bash
# Service Configuration
SERVICE_NAME=blocksecops-orchestration
SERVICE_VERSION=0.7.0
ENVIRONMENT=local

# API Server
API_HOST=0.0.0.0
API_PORT=8004

# Logging
LOG_LEVEL=INFO
LOG_JSON=true                  # JSON structured logging

# CORS Origins (comma-separated)
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000

# Scanner Defaults
DEFAULT_SCANNER_TIMEOUT=300    # Default timeout in seconds
```

### Kubernetes ConfigMap

Create a ConfigMap with service configuration:

```bash
kubectl create configmap orchestration-config \
  --namespace orchestration-local \
  --from-literal=log_level="INFO" \
  --from-literal=api_port="8004"
```

## Deployment Steps

### 1. Build Docker Image

```bash
cd /path/to/blocksecops-orchestration

# Build with all 12 scanner binaries
docker build -t blocksecops-orchestration:0.7.0 .

# For Minikube local development
minikube image load blocksecops-orchestration:0.7.0
```

**Image Size**: ~6.24GB (includes all scanner binaries and Solidity compilers)
**Build Time**: ~60 seconds (with cached layers)

### 2. Deploy to Kubernetes

```bash
# Deploy to local environment
kubectl apply -k k8s/overlays/local/orchestration

# Verify deployment
kubectl get pods -n orchestration-local
kubectl logs -n orchestration-local deployment/orchestration --tail=50
```

**Expected Output**:
```
📡 Orchestration API starting up
📦 Loaded 12 scanners (12 available)
🔧 Loaded 12 parsers
INFO:     Uvicorn running on http://0.0.0.0:8004 (Press CTRL+C to quit)
```

### 3. Verify API Access

```bash
# Port-forward to access API locally
kubectl port-forward -n orchestration-local svc/orchestration 8004:8004

# Test health endpoint
curl http://localhost:8004/api/v1/health/live

# List all scanners
curl http://localhost:8004/api/v1/scanners

# Access OpenAPI documentation
open http://localhost:8004/api/v1/docs
```

### 4. Test Scanner Execution

```bash
# Execute a scan (example contract path)
curl -X POST http://localhost:8004/api/v1/scans \
  -H "Content-Type: application/json" \
  -d '{
    "scanner_id": "slither",
    "contract_path": "/contracts/test.sol",
    "timeout": 300
  }'

# Response will include scan_id
# {
#   "scan_id": "550e8400-e29b-41d4-a716-446655440000",
#   "status": "RUNNING",
#   ...
# }

# Check scan status
SCAN_ID="550e8400-e29b-41d4-a716-446655440000"
curl http://localhost:8004/api/v1/scans/$SCAN_ID/status

# Get full results when completed
curl http://localhost:8004/api/v1/scans/$SCAN_ID
```

## Architecture Decisions

### Gevent Pool vs Prefork Pool

**Decision**: Use gevent pool for Celery workers

**Rationale**:
- **High Concurrency**: Gevent allows 100 concurrent tasks vs 4 with prefork
- **I/O Bound Workload**: Scans spend most time waiting for Slither subprocess
- **Resource Efficiency**: Lower memory overhead per task
- **25x Performance**: Increased throughput from 50 to 1000+ scans/hour per worker

**Trade-offs**:
- Requires synchronous database operations (psycopg2 instead of asyncpg)
- Not suitable for CPU-bound tasks (Slither runs in subprocess, so not affected)

### Dual Database Session Support

**Problem**: Event loop conflicts between Celery workers and async database drivers

**Solution**: Separate database drivers for different use cases
- **Sync (psycopg2)**: Celery workers with gevent pool
- **Async (asyncpg)**: API service with FastAPI

**Implementation**:
```python
# Sync session for workers
from blocksecops_orchestration.core.database import get_db_session

with get_db_session() as session:
    result = session.execute(select(ScanModel).where(...))
    scans = result.scalars().all()

# Async session for API service
from blocksecops_orchestration.core.database import get_async_db_session

async with get_async_db_session() as session:
    result = await session.execute(select(ScanModel).where(...))
    scans = result.scalars().all()
```

### RedBeat Scheduler

**Decision**: Use RedBeat instead of PersistentScheduler

**Rationale**:
- **Read-Only Filesystem**: Kubernetes security context prevents writing to filesystem
- **Distributed Environment**: Redis-based schedule works across multiple beat instances
- **No Persistence Required**: Schedule configuration in code, not filesystem

**Configuration**:
```python
celery_app.start([
    "beat",
    "--loglevel=INFO",
    "--scheduler=redbeat.RedBeatScheduler",
])
```

**Lock Recovery (v0.9.10)**: RedBeat uses a Redis distributed lock to ensure only one beat instance runs at a time. The default lock timeout (1500s/25 min) and retry interval (300s/5 min) are too long for Kubernetes pod rollouts. The following settings in `celery_app.py` ensure beat recovers within ~45 seconds after a pod rollout:

```python
celery_app.conf.update(
    redbeat_lock_timeout=30,        # Lock TTL: 30s (default 1500s)
    beat_max_loop_interval=10,      # Lock retry: 10s (default 300s)
)
```

## Resource Configuration

### Worker Pod (v0.9.10)

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "500m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

### Beat Scheduler Pod

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "50m"
  limits:
    memory: "512Mi"
    cpu: "250m"
```

### Monitor Pod (Flower)

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "25m"
  limits:
    memory: "256Mi"
    cpu: "100m"
```

## Monitoring

### Prometheus Metrics

Key metrics to monitor:

- `celery_task_duration_seconds` - Task execution time
- `celery_task_total` - Total tasks processed
- `celery_task_failed_total` - Failed task count
- `celery_worker_pool_size` - Worker pool concurrency
- `celery_queue_length` - Queue depth

### Structured Logs

All logs include structured context:

```json
{
  "event": "scan_dispatched",
  "scan_id": "123e4567-e89b-12d3-a456-426614174000",
  "contract_id": "987fcdeb-51a2-43f1-b456-426614174abc",
  "timestamp": "2025-10-06T10:30:00Z",
  "service": "blocksecops-orchestration",
  "version": "0.1.5"
}
```

### Flower Dashboard

Access Flower for real-time monitoring:

```bash
kubectl port-forward -n orchestration-local svc/orchestration-monitor 5555:5555
```

Visit http://localhost:5555 to view:
- Active tasks and workers
- Task history and success rates
- Worker statistics
- Task routing and queues

## Troubleshooting

### Workers Not Processing Scans

1. **Check worker logs**:
```bash
kubectl logs -n orchestration-local deployment/orchestration-worker --tail=100
```

2. **Verify database connectivity**:
```bash
kubectl exec -n orchestration-local deployment/orchestration-worker -- \
  python -c "from blocksecops_orchestration.core.database import get_db_session; \
             with get_db_session() as s: print('DB connected')"
```

3. **Check Redis connectivity**:
```bash
kubectl exec -n orchestration-local deployment/orchestration-worker -- \
  celery -A blocksecops_orchestration.core.celery_app inspect ping
```

### Beat Scheduler Not Dispatching Tasks

1. **Check beat logs**:
```bash
kubectl logs -n orchestration-local deployment/orchestration-beat --tail=50
```

2. **Clear RedBeat lock** (if stuck):
```bash
kubectl exec -n redis-local deployment/redis -c redis -- \
  redis-cli -a redis-local-password DEL "redbeat::lock"
```

3. **Restart beat scheduler**:
```bash
kubectl rollout restart -n orchestration-local deployment/orchestration-beat
```

### Event Loop Errors

**Error**: `RuntimeError: Task got Future attached to a different loop`

**Cause**: Using async operations in Celery tasks with gevent pool

**Solution**: Convert all task code to synchronous operations:
- Use `get_db_session()` instead of `get_async_db_session()`
- Use `session.execute()` instead of `await session.execute()`
- Use `subprocess.run()` instead of `asyncio.create_subprocess_exec()`

### OOM Killed Containers

**Cause**: Insufficient memory limits for Slither execution

**Solution**: Increase resource limits in deployment:
```yaml
resources:
  limits:
    memory: "2Gi"  # Increase from 1Gi
```

## Performance Tuning

### Worker Concurrency

Adjust gevent pool size based on workload:

```python
# In scan_worker.py
celery_app.worker_main([
    "worker",
    "--pool=gevent",
    "--concurrency=200",  # Increase for more I/O-bound tasks
    # ...
])
```

### Database Connection Pool

Tune connection pool for concurrency:

```python
# In database.py
sync_engine = create_engine(
    database_url,
    pool_size=50,        # Increase for higher concurrency
    max_overflow=20,     # Additional connections during peak
    pool_pre_ping=True,
)
```

### Scan Batch Size

Adjust batch size for queue polling:

```bash
# Environment variable
SCAN_BATCH_SIZE=20  # Process more scans per poll
```

## Security Considerations

### Container Security

- Non-root user (UID 1000)
- Read-only root filesystem
- Dropped capabilities
- No privilege escalation

### Secret Management

**Current**: Kubernetes Secrets
**Future**: HashiCorp Vault integration (planned)

Store sensitive data in Vault:
- Database credentials
- Redis passwords
- JWT secret keys
- API tokens

### Network Policies

Apply Kubernetes NetworkPolicies to restrict traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: orchestration-network-policy
spec:
  podSelector:
    matchLabels:
      app: orchestration
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: api-local
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: postgresql-local
  - to:
    - namespaceSelector:
        matchLabels:
          name: redis-local
```

## Migration from Celery (v0.6.3 → v0.7.0)

### Breaking Changes

**Previous Architecture** (≤ v0.6.3):
- Celery workers with gevent pool
- Beat scheduler for periodic tasks
- Flower monitoring UI
- Dockerfile CMD: `python -m blocksecops_orchestration.workers.scan_worker`

**New Architecture** (v0.7.0+):
- FastAPI REST server
- Background task execution
- OpenAPI documentation
- Dockerfile CMD: `uvicorn blocksecops_orchestration.api.main:app --host 0.0.0.0 --port 8004`

### Migration Steps

1. **Update Health Check Paths**:
   ```yaml
   # Old
   livenessProbe:
     httpGet:
       path: /health

   # New
   livenessProbe:
     httpGet:
       path: /api/v1/health/live
   ```

2. **Update Service Integration**:
   - Replace Celery task calls with HTTP POST to `/api/v1/scans`
   - Poll `/api/v1/scans/{scan_id}/status` instead of Celery result backend
   - Use `/api/v1/scanners` to list available scanners

3. **Update Monitoring**:
   - Replace Flower with API metrics
   - Monitor `/api/v1/health/ready` for detailed status
   - Use OpenAPI docs at `/api/v1/docs` for endpoint reference

## Next Steps (Phase 6)

1. **Database Persistence**: Replace in-memory scan storage with PostgreSQL
2. **Result Pagination**: Add pagination for large scan result sets
3. **Advanced Filtering**: Query scans by status, scanner, date range
4. **Authentication**: Add JWT-based authentication for API access
5. **Rate Limiting**: Implement per-user quotas and rate limits
6. **Scan History**: Analytics and trends across scan history

## References

### Documentation

- **Repository**: `/Users/pwner/Git/ABS/blocksecops-orchestration`
- **REST API Architecture**: [orchestration-rest-api.md](../architecture/orchestration-rest-api.md)
- **Result Routing**: [orchestration-result-routing.md](../architecture/orchestration-result-routing.md)
- **Phase 5 Completion**: `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/06-phase-5-rest-api/PHASE-5-REST-API-COMPLETE.md`
- **CHANGELOG**: `/Users/pwner/Git/ABS/blocksecops-orchestration/CHANGELOG.md`

### Pull Requests

- **PR #25**: Phase 5 REST API Implementation (v0.7.0)
- **PR #8**: Event Loop Conflict Resolution (v0.1.5)

### External Resources

- **FastAPI Documentation**: https://fastapi.tiangolo.com/
- **OpenAPI Specification**: https://swagger.io/specification/
- **Pydantic**: https://docs.pydantic.dev/
- **Uvicorn**: https://www.uvicorn.org/
