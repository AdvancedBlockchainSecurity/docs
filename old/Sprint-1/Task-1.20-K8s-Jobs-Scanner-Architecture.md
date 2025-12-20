# Task 1.20: Kubernetes Jobs Scanner Architecture

**Sprint**: Sprint 1 (Extended)
**Date**: October 8, 2025
**Status**: 🟡 Architecture Defined, Implementation Pending
**Priority**: P0 (Critical for Sprint 4)

## Overview

Define and document the Kubernetes Jobs-based scanner execution architecture for tool-integration service, replacing embedded Python packages to resolve dependency conflicts.

## Problem Statement

### Dependency Hell

Cannot install multiple security scanners as Python packages due to conflicting dependencies:

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
  requires eth-account>=0.13.6
  requires ckzg>=2.0.0
```

**Conflict**: `ckzg<2` vs `ckzg>=2.0.0` - Cannot be resolved.

## Solution: Kubernetes Jobs

### Architecture Decision

**Decision**: Use Kubernetes Jobs for scanner execution instead of:
- ❌ Docker-in-Docker (security anti-pattern, requires privileged access)
- ❌ Sidecar containers (wastes resources, doesn't scale)
- ✅ Kubernetes Jobs (native K8s, secure, scalable)

### Benefits

**Security**:
- No Docker socket mounting required
- Pod-level isolation with network policies
- Resource quotas prevent DoS
- Audit trail for all scanner executions

**Operations**:
- Native K8s monitoring and logging
- Automatic cleanup (TTL)
- Easy to debug (kubectl logs)
- Standard K8s tooling

**Scalability**:
- Hundreds of concurrent scans
- K8s handles scheduling
- Auto-scaling based on demand
- Resource limits prevent exhaustion

## Documentation Created

### Technical Documentation
**File**: `/Users/pwner/Git/ABS/blocksecops-docs/deployment/scanner-execution-architecture.md`

**Contents**:
- Architecture decision rationale
- Implementation guide with code examples
- RBAC configuration
- Job template specifications
- Resource limits per scanner
- Monitoring and troubleshooting

### Task Documentation
**File**: `/Users/pwner/Git/ABS/TaskDocs/SolidityOps/k8s-jobs-scanner-implementation.md`

**Contents**:
- Implementation plan
- Code templates for KubernetesJobManager
- Testing plan
- Deployment steps
- Success criteria

## Implementation Plan

### Phase 1: Add Kubernetes Client (Sprint 4)
- Add `kubernetes>=28.1.0` to requirements/base.txt
- Test in-cluster config loading

### Phase 2: RBAC Setup (Sprint 4)
- Create ServiceAccount for tool-integration
- Create Role with Job management permissions
- Create RoleBinding

### Phase 3: Implement Job Manager (Sprint 4)
- Create `KubernetesJobManager` class
- Implement job creation logic
- Implement job monitoring
- Implement result collection

### Phase 4: Integration (Sprint 4)
- Integrate with scan orchestration
- Update scanner adapters
- End-to-end testing

## Scanner-Specific Configuration

### Mythril
- Image: `mythril/myth:latest`
- Memory: 2Gi (symbolic execution is memory-intensive)
- CPU: 1000m
- Timeout: 600s

### Slither
- Image: `trailofbits/eth-security-toolbox:latest`
- Memory: 1Gi
- CPU: 500m
- Timeout: 300s

### Aderyn
- Image: `scanner-aderyn:0.1.0` (custom build)
- Memory: 512Mi (Rust is efficient)
- CPU: 250m
- Timeout: 180s

## RBAC Configuration

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
  name: scanner-job-manager
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

## Testing Strategy

### Unit Tests
- Job template generation
- Job status monitoring
- Error handling

### Integration Tests
- Full scan workflow with K8s Jobs
- Result collection
- Job cleanup

### Load Tests
- Concurrent scanner executions
- Resource limit enforcement
- Auto-scaling behavior

## Success Criteria

- [x] Architecture documented
- [x] Technical documentation created
- [x] Task documentation created
- [ ] Kubernetes library added to requirements
- [ ] RBAC resources created
- [ ] KubernetesJobManager implemented
- [ ] Integration with scan workflow complete
- [ ] Tests passing
- [ ] Scanner Jobs running successfully in Minikube

## Timeline

**Sprint 4** (Weeks 7-8):
- Week 1: Add dependency, create RBAC, implement KubernetesJobManager
- Week 2: Integration, testing, deployment

## Related Documentation

- Sprint Plan: `/Users/pwner/Git/ABS/docs/sprint-plan_new.md` (Sprint 4)
- Development Plan: `/Users/pwner/Git/ABS/docs/development-plan_new.md` (Sprint 4)
- Technical Docs: `/Users/pwner/Git/ABS/blocksecops-docs/deployment/scanner-execution-architecture.md`
- Task Docs: `/Users/pwner/Git/ABS/TaskDocs/SolidityOps/k8s-jobs-scanner-implementation.md`

## References

- Kubernetes Jobs: https://kubernetes.io/docs/concepts/workloads/controllers/job/
- Python Kubernetes Client: https://github.com/kubernetes-client/python
- Scanner Images:
  - Slither: https://hub.docker.com/r/trailofbits/eth-security-toolbox
  - Mythril: https://hub.docker.com/r/mythril/myth

## Notes

This architectural decision resolves the dependency conflicts blocking tool-integration deployment while providing production-grade isolation, security, and scalability for scanner execution.

The implementation will be completed in Sprint 4 alongside the core security tool integration work.
