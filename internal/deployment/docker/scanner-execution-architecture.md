# Scanner Execution Architecture - Kubernetes Jobs

> **Note (February 2026):** This document captures the original architecture decision from October 2025. For the current implementation with 15 scanners, callback-based result collection, dead-letter queues, and Prometheus metrics, see [Scanner Job Execution Pipeline](/home/pwner/Git/docs/pipelines/scanner-job-execution-pipeline.md).

## Overview

The Tool Integration service executes security scanners as isolated Kubernetes Jobs rather than embedded Python packages. This provides production-grade isolation, scalability, and security.

## Architecture Decision

**Decision**: Use Kubernetes Jobs for scanner execution instead of Docker-in-Docker or sidecar containers.

**Date**: October 2025

**Status**: Approved — Implemented with 15 scanner images (6 Solidity static, 3 Solidity fuzzing, 2 Vyper, 4 Solana/Rust)

## Rationale

### Why Kubernetes Jobs?

1. **Security Benefits**
   - No Docker socket mounting required (eliminates privileged access risk)
   - Each scan runs in isolated pod with its own network namespace
   - Pod security policies enforced per scanner
   - Network policies can isolate scanner traffic
   - Principle of least privilege - tool-integration only needs K8s Job creation permissions

2. **Operational Benefits**
   - Native K8s resource management and scheduling
   - Automatic cleanup with TTL (time-to-live) after completion
   - Resource limits per scan prevent resource exhaustion (CPU/memory quotas)
   - Built-in logging and monitoring through K8s
   - Easy to track scan history via Job resources
   - Horizontal scaling handled by K8s scheduler

3. **Scalability**
   - K8s scheduler distributes workload across nodes
   - Can run hundreds of concurrent scans
   - Auto-scaling based on queue depth
   - Resource quotas prevent system overload

### Why NOT alternatives?

**Docker-in-Docker (DinD)**:
- ❌ Security anti-pattern - requires privileged containers
- ❌ Pod has Docker daemon access
- ❌ Hard to track resource usage per scan
- ❌ Potential for resource leaks

**Sidecar Containers**:
- ❌ All scanners always running (waste resources)
- ❌ Doesn't scale with number of scanner types
- ❌ Pre-defined scanners only - no dynamic loading

## Problem Statement

### Dependency Hell

Each security scanner has conflicting Python dependencies:

**Mythril Requirements**:
```
eth-account>=0.8.0
eth-keyfile<0.9.0
hexbytes<0.3.0
ckzg<2
```

**Slither Requirements**:
```
web3<8,>=7.10
  which requires eth-account>=0.13.6
  which requires ckzg>=2.0.0
```

**Conflict**: `ckzg<2` vs `ckzg>=2.0.0`

### Solution

Run each scanner in its own Docker container with isolated dependencies:

```
Scanner Images:
- slither: trailofbits/eth-security-toolbox (includes slither, echidna)
- mythril: mythril/myth:latest
- aderyn: custom build (Rust-based)
```

## Implementation

### High-Level Flow

```
User submits scan request
         ↓
API service creates scan record
         ↓
Tool-integration service receives scan task
         ↓
Creates Kubernetes Job for scanner
         ↓
K8s schedules Job pod
         ↓
Scanner executes in isolated pod
         ↓
Results written to shared storage or API
         ↓
Job completes and auto-deletes (TTL)
         ↓
Tool-integration aggregates results
```

### Tool-Integration Service Changes

**Add kubernetes Python library**:
```python
# requirements/base.txt
kubernetes>=28.1.0,<29.0.0
```

**Job Creation Logic**:
```python
from kubernetes import client, config

# Load in-cluster config
config.load_incluster_config()

# Create Job for scanner
def create_scanner_job(scan_id: str, scanner: str, contract_source: str):
    batch_v1 = client.BatchV1Api()

    # Create Job spec
    job = client.V1Job(
        metadata=client.V1ObjectMeta(
            name=f"scan-{scanner}-{scan_id}",
            namespace="tool-integration-local",
            labels={
                "app": "scanner",
                "scanner": scanner,
                "scan-id": scan_id
            }
        ),
        spec=client.V1JobSpec(
            ttl_seconds_after_finished=3600,  # Auto-delete after 1 hour
            backoff_limit=3,  # Retry failed jobs
            template=client.V1PodTemplateSpec(
                metadata=client.V1ObjectMeta(
                    labels={
                        "app": "scanner",
                        "scanner": scanner
                    }
                ),
                spec=client.V1PodSpec(
                    containers=[
                        client.V1Container(
                            name=scanner,
                            image=get_scanner_image(scanner),
                            command=get_scanner_command(scanner, contract_source),
                            resources=client.V1ResourceRequirements(
                                limits={"memory": "2Gi", "cpu": "1000m"},
                                requests={"memory": "512Mi", "cpu": "250m"}
                            ),
                            volume_mounts=[
                                client.V1VolumeMount(
                                    name="contract-storage",
                                    mount_path="/contracts"
                                )
                            ]
                        )
                    ],
                    volumes=[
                        client.V1Volume(
                            name="contract-storage",
                            persistent_volume_claim=client.V1PersistentVolumeClaimVolumeSource(
                                claim_name="contract-pvc"
                            )
                        )
                    ],
                    restart_policy="Never",
                    service_account_name="tool-integration-scanner"
                )
            )
        )
    )

    # Create Job
    batch_v1.create_namespaced_job(
        namespace="tool-integration-local",
        body=job
    )

    return job.metadata.name
```

### Scanner-Specific Configuration

**Mythril**:
```python
def get_scanner_image(scanner):
    images = {
        "mythril": "mythril/myth:latest",
        "slither": "trailofbits/eth-security-toolbox:latest",
        "aderyn": "scanner-aderyn:0.1.0"
    }
    return images[scanner]

def get_scanner_command(scanner, contract_path):
    commands = {
        "mythril": [
            "myth", "analyze",
            f"/contracts/{contract_path}",
            "-o", "json",
            "--execution-timeout", "600"
        ],
        "slither": [
            "slither", f"/contracts/{contract_path}",
            "--json", "/results/slither-output.json"
        ],
        # ... other scanners
    }
    return commands[scanner]
```

### Result Collection

**Option 1: Shared Storage (PVC)**:
```python
# Scanner writes results to /results/output.json
# Tool-integration reads from PVC after Job completion
```

**Option 2: API Callback**:
```python
# Scanner POSTs results to tool-integration API
# No shared storage required
```

**Option 3: K8s ConfigMap/Secret**:
```python
# Scanner writes results to ConfigMap
# Tool-integration reads ConfigMap
# Limited to 1MB data
```

### RBAC Configuration

**ServiceAccount**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tool-integration
  namespace: tool-integration-local
```

**Role**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: job-creator
  namespace: tool-integration-local
rules:
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create", "get", "list", "watch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
```

**RoleBinding**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tool-integration-job-creator
  namespace: tool-integration-local
subjects:
- kind: ServiceAccount
  name: tool-integration
  namespace: tool-integration-local
roleRef:
  kind: Role
  name: job-creator
  apiGroup: rbac.authorization.k8s.io
```

### Monitoring Job Status

```python
def wait_for_job_completion(job_name: str, timeout: int = 600):
    batch_v1 = client.BatchV1Api()
    start_time = time.time()

    while time.time() - start_time < timeout:
        job = batch_v1.read_namespaced_job(
            name=job_name,
            namespace="tool-integration-local"
        )

        if job.status.succeeded:
            return "completed"
        elif job.status.failed:
            return "failed"

        time.sleep(5)

    return "timeout"
```

### Resource Limits

**Per-Scanner Limits**:
```yaml
Mythril:
  memory: 2Gi (symbolic execution memory-intensive)
  cpu: 1000m
  timeout: 600s

Slither:
  memory: 1Gi
  cpu: 500m
  timeout: 300s

Aderyn:
  memory: 512Mi (Rust efficient)
  cpu: 250m
  timeout: 180s
```

## Production Deployment

### Namespace Organization

```
tool-integration-local (Minikube)
  ├── tool-integration (orchestrator)
  ├── Jobs (ephemeral scanner pods)
  └── PVC (shared contract storage)

tool-integration-staging
  └── Same structure

tool-integration-production
  └── Same structure
```

### Auto-Scaling

**Horizontal Pod Autoscaler for tool-integration**:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: tool-integration-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tool-integration
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: pending_scans
      target:
        type: AverageValue
        averageValue: "10"
```

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: scanner-quota
  namespace: tool-integration-local
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    count/jobs.batch: "100"
```

## Benefits Summary

### Security
✅ No privileged containers required
✅ Pod-level isolation with network policies
✅ Resource quotas prevent DoS
✅ Audit trail for all scanner executions

### Operations
✅ Native K8s monitoring and logging
✅ Automatic cleanup (TTL)
✅ Easy to debug (kubectl logs)
✅ Standard K8s tooling

### Scalability
✅ Hundreds of concurrent scans
✅ K8s handles scheduling
✅ Auto-scaling based on demand
✅ Resource limits prevent exhaustion

### Maintainability
✅ Scanner updates = image updates
✅ No dependency conflicts
✅ Easy to add new scanners
✅ Versioned scanner images

## Migration Path

### Phase 1: Add Kubernetes client
- Add `kubernetes` library to requirements
- Test in-cluster config loading
- Implement basic Job creation

### Phase 2: Implement scanner Jobs
- Create Job templates for each scanner
- Implement result collection
- Test with single scanner

### Phase 3: RBAC setup
- Create ServiceAccount
- Configure Role and RoleBinding
- Test permissions

### Phase 4: Production deployment
- Deploy to staging
- Load testing
- Deploy to production

## References

- **Kubernetes Jobs Documentation**: https://kubernetes.io/docs/concepts/workloads/controllers/job/
- **Python Kubernetes Client**: https://github.com/kubernetes-client/python
- **Scanner Images**:
  - Slither: https://hub.docker.com/r/trailofbits/eth-security-toolbox
  - Mythril: https://hub.docker.com/r/mythril/myth

## Scanner Metadata Management (Updated 2025-10-19)

### ConfigMap-Based Version Control

Scanner metadata (tool versions, developers) is centrally managed in the `scanner-versions` ConfigMap as a single source of truth.

**Latest Update**: All 20 scanner versions updated to latest stable releases on 2025-10-19. Note: Manticore has been removed from the platform. See `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/MANTICORE-REMOVAL-COMPLETE.md` for details.

**Location**: `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

**Structure**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
data:
  # Scanner metadata (version, developer info)
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.4",
        "developer": "Trail of Bits"
      },
      "mythril": {
        "version": "0.24.8",
        "developer": "ConsenSys"
      },
      # ... all 20 scanners
    }

  # Scanner Docker image tags (used by tool-integration)
  SCANNER_IMAGE_SLITHER: "scanner-slither:0.3.2"
  SCANNER_IMAGE_ADERYN: "scanner-aderyn:0.7.2"
  SCANNER_IMAGE_SEMGREP: "scanner-semgrep:0.3.5"
  # ... see k8s/base/scanner-versions-configmap.yaml for all tags
```

### Integration with API Service

The API service automatically loads scanner metadata from the ConfigMap at startup:

**Environment Variable Injection**:
```yaml
# blocksecops-api-service/k8s/base/deployment.yaml
env:
  - name: SCANNER_METADATA
    valueFrom:
      configMapKeyRef:
        name: scanner-versions
        key: SCANNER_METADATA
```

**Python Loading Logic**:
```python
# blocksecops-api-service/src/infrastructure/scanner_config/scanners.py
import os
import json

def _load_scanner_metadata_from_env() -> Dict[str, dict]:
    """Load scanner metadata from SCANNER_METADATA env var."""
    metadata_json = os.getenv("SCANNER_METADATA", "{}")
    try:
        metadata = json.loads(metadata_json)
        logger.info(f"Loaded metadata for {len(metadata)} scanners from ConfigMap")
        return metadata
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse SCANNER_METADATA env var: {e}")
        return {}

# Load at module initialization
_SCANNER_METADATA_FROM_CONFIG = _load_scanner_metadata_from_env()

class ScannerMetadata:
    def __init__(self, id, name, description, scanner_type, languages, ...):
        # Load version/developer from ConfigMap automatically
        config_metadata = _SCANNER_METADATA_FROM_CONFIG.get(id, {})
        self.version = version or config_metadata.get("version", "unknown")
        self.developer = developer or config_metadata.get("developer", "unknown")
```

### Version Update Workflow

**When a scanner tool version is updated**:

1. **Update ConfigMap**:
   ```bash
   # Edit scanner-versions-configmap.yaml
   vim blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml
   
   # Update version for the scanner
   # Example: Change slither version from "0.10.3" to "0.10.4"
   
   # Apply changes
   kubectl apply -f k8s/base/scanner-versions-configmap.yaml
   ```

2. **Restart API Service** (to reload env vars):
   ```bash
   kubectl rollout restart deployment/api-service -n api-service-local
   ```

3. **Verify Update**:
   ```bash
   curl http://localhost:8000/api/v1/scanners | jq '.scanners[] | select(.id=="slither") | {version, developer}'
   ```

### Benefits of ConfigMap Approach

**Production Sustainability**:
- ✅ Single source of truth for all scanner metadata
- ✅ Version updates don't require code changes
- ✅ Git tracks all version history
- ✅ Easy to audit what versions are running

**Operational Simplicity**:
- ✅ ConfigMap update → API service restart (simple workflow)
- ✅ No Docker image rebuilds for metadata changes
- ✅ Environment-specific overrides via Kustomize overlays
- ✅ Fail-safe defaults ("unknown") if ConfigMap unavailable

**Developer Experience**:
- ✅ Clear location for version management
- ✅ JSON validation on startup
- ✅ Comprehensive logging
- ✅ Type-safe Python access

### Integration with Tool-Integration Service

The tool-integration service reads scanner image tags from the same ConfigMap:

```python
# Example: KubernetesJobManager dynamically selects scanner images
def get_scanner_image(scanner_id: str) -> str:
    """Get scanner Docker image from environment (populated from ConfigMap)."""
    env_var = f"SCANNER_IMAGE_{scanner_id.upper().replace('-', '_')}"
    image = os.getenv(env_var, f"scanner-{scanner_id}:latest")
    logger.info(f"Using image {image} for scanner {scanner_id}")
    return image
```

### Multi-Environment Support

**Local Development**:
```yaml
# k8s/overlays/local/scanner-versions-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
data:
  # Override with development versions
  SCANNER_IMAGE_SLITHER: "scanner-slither:dev"
```

**Staging**:
```yaml
# k8s/overlays/staging/scanner-versions-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
data:
  # Test new scanner versions before production
  SCANNER_IMAGE_SLITHER: "scanner-slither:0.3.0-rc1"
```

**Production**:
```yaml
# Uses base ConfigMap with stable versions
# k8s/base/scanner-versions-configmap.yaml
```

### Monitoring and Alerts

**Recommended Monitoring**:

1. **Version Mismatch Detection**:
   - Scanners report their actual version in callback responses
   - API service compares vs ConfigMap expected version
   - Alert on mismatch (indicates stale Docker images)

2. **ConfigMap Update Tracking**:
   - Monitor ConfigMap changes via K8s audit logs
   - Alert on scanner version changes
   - Correlate with deployment events

3. **Fallback Detection**:
   - Monitor log messages for "unknown" version/developer
   - Indicates ConfigMap loading issues
   - Alert ops team for investigation

### References

- **ConfigMap Documentation**: https://kubernetes.io/docs/concepts/configuration/configmap/
- **Kustomize Overlays**: https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays
- **Scanner Metadata Refactoring Doc**: `/Users/pwner/Git/ABS/docs/SCANNER-METADATA-REFACTORING-2025-10-18.md`
