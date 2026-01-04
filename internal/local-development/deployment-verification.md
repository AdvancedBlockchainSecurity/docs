# Local Development Environment Verification Guide

> **⚠️ Use this guide to verify your local development environment setup**

## Overview

This guide provides step-by-step verification procedures to ensure your local development environment is properly configured and all components are functioning correctly.

## Prerequisites Check

### Required Software Verification

```bash
# Check all required tools are installed
docker --version          # Expected: 28.4.0+
minikube version          # Expected: v1.37.0+
kubectl version --client # Expected: v1.34.1+
helm version              # Expected: v3.19.0+
node --version            # Expected: v24.9.0+
python3 --version         # Expected: 3.11+ or 3.13+
rustc --version           # Expected: 1.90.0+
```

**Expected Output:**
```
Docker version 28.4.0, build d8eb465f86
minikube version: v1.37.0
Client Version: v1.34.1
version.BuildInfo{Version:"v3.19.0",...}
v24.9.0
Python 3.13.7
rustc 1.90.0
```

## Infrastructure Verification

### 1. minikube Cluster Status ✅

```bash
# Check cluster is running
minikube status
```

**Expected Output:**
```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

```bash
# Verify cluster info
kubectl cluster-info
```

**Expected Output:**
```
Kubernetes control plane is running at https://127.0.0.1:62016
CoreDNS is running at https://127.0.0.1:62016/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### 2. Namespace Structure ✅

```bash
# Check all namespaces exist
kubectl get namespaces
```

**Expected Output:**
```
NAME                STATUS   AGE
default             Active   30m
ingress-nginx       Active   30m
kube-node-lease     Active   30m
kube-public         Active   30m
kube-system         Active   30m
monitoring          Active   25m
blocksecops   Active   20m
```

### 3. Infrastructure Pods Health ✅

```bash
# Check all infrastructure pods are running
kubectl get pods -A | grep -E "(postgresql|redis|vault|grafana|prometheus)"
```

**Expected Output:**
```
default      postgresql-7db7b4766b-xxxxx                              1/1     Running   0          15m
default      redis-master-bb7548d4-xxxxx                             1/1     Running   0          15m
default      vault-0                                                 1/1     Running   0          20m
monitoring   monitoring-grafana-7dfd97dbf9-xxxxx                     3/3     Running   0          18m
monitoring   prometheus-monitoring-kube-prometheus-prometheus-0      2/2     Running   0          18m
```

## Database Connectivity Verification

### PostgreSQL Database ✅

```bash
# Get PostgreSQL pod name
POSTGRES_POD=$(kubectl get pods -l app=postgresql -o jsonpath='{.items[0].metadata.name}')

# Test database connection and version
kubectl exec $POSTGRES_POD -- psql -U postgres -d soliditysecurity -c "SELECT version();"
```

**Expected Output:**
```
                                               version
--------------------------------------------------------------------------------------------------------------
 PostgreSQL 15.14 (Debian 15.14-1.pgdg13+1) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
(1 row)
```

```bash
# Test database exists
kubectl exec $POSTGRES_POD -- psql -U postgres -c "\l" | grep soliditysecurity
```

**Expected Output:**
```
 soliditysecurity | postgres | UTF8     | ...
```

### Redis Cache ✅

```bash
# Get Redis pod name
REDIS_POD=$(kubectl get pods -l app=redis,role=master -o jsonpath='{.items[0].metadata.name}')

# Test Redis connectivity
kubectl exec $REDIS_POD -- redis-cli ping
```

**Expected Output:**
```
PONG
```

```bash
# Test Redis info
kubectl exec $REDIS_POD -- redis-cli info server | head -5
```

**Expected Output:**
```
# Server
redis_version:7.x.x
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:...
```

### Vault Service ✅

```bash
# Test Vault status
kubectl exec vault-0 -- vault status
```

**Expected Output:**
```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    1
Threshold       1
Version         1.x.x
...
```

## Service Configuration Verification

### ConfigMap Values ✅

```bash
# Check service configuration
kubectl get configmap service-config -n blocksecops -o yaml
```

**Expected Output:**
```yaml
apiVersion: v1
data:
  DATABASE_URL: postgresql://postgres:dev-password@postgresql.default.svc.cluster.local:5432/soliditysecurity
  REDIS_URL: redis://redis-master.default.svc.cluster.local:6379
  VAULT_URL: http://vault.default.svc.cluster.local:8200
  VAULT_TOKEN: dev-root-token
kind: ConfigMap
metadata:
  name: service-config
  namespace: blocksecops
```

### DNS Resolution ✅

```bash
# Test cross-namespace DNS resolution
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup postgresql.default.svc.cluster.local
```

**Expected Output:**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      postgresql.default.svc.cluster.local
Address 1: 10.102.69.15 postgresql.default.svc.cluster.local
```

## Container Registry Verification

### Local Registry ✅

```bash
# Check local registry is running
docker ps | grep registry
```

**Expected Output:**
```
66cf15436293   registry:2   "/entrypoint.sh /etc…"   30 minutes ago   Up 30 minutes   0.0.0.0:5000->5000/tcp   registry
```

```bash
# Test registry API
curl http://localhost:5000/v2/_catalog
```

**Expected Output:**
```json
{"repositories":["blocksecops-api-service"]}
```

```bash
# Check specific image exists
curl http://localhost:5000/v2/blocksecops-api-service/tags/list
```

**Expected Output:**
```json
{"name":"blocksecops-api-service","tags":["dev"]}
```

## Shared Library Verification

### Python Package ✅

```bash
# Test shared library import
python3 -c "import solidity_shared; print('✅ Shared library imported successfully')"
```

**Expected Output:**
```
✅ Shared library imported successfully
```

```bash
# Check installed version
python3 -c "import solidity_shared; print(f'Version: {getattr(solidity_shared, \"__version__\", \"0.1.0\")}')"
```

```bash
# Verify package location
python3 -c "import solidity_shared; print(f'Location: {solidity_shared.__file__}')"
```

### Wheel File Verification ✅

```bash
# Check wheel exists in service directories
ls -la /Users/pwner/Git/ABS/blocksecops-api-service/blocksecops_shared-0.1.0-py3-none-any.whl
```

**Expected Output:**
```
-rw-r--r--  1 pwner  staff  XXXXX Oct  2 XX:XX blocksecops_shared-0.1.0-py3-none-any.whl
```

## Monitoring Stack Verification

### Grafana Access ✅

```bash
# Set up port forwarding for Grafana
kubectl port-forward svc/monitoring-grafana 3001:80 -n monitoring &
```

```bash
# Test Grafana connectivity (in another terminal)
curl -s http://localhost:3001/api/health
```

**Expected Output:**
```json
{"commit":"...","database":"ok","version":"..."}
```

**Manual Verification:**
1. Open browser to `http://localhost:3001`
2. Login with `admin` / `admin`
3. Verify dashboards are loaded
4. Check data sources show "connected"

### Prometheus Metrics ✅

```bash
# Port forward Prometheus (if needed)
kubectl port-forward svc/prometheus-monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &
```

```bash
# Test Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'
```

**Expected Output:**
```
5  # (or similar number indicating active targets)
```

## Application Service Verification

### API Service Image ✅

```bash
# Pull and test the built API service image
docker pull localhost:5000/blocksecops-api-service:dev
```

```bash
# Test image can start (without running)
docker run --rm localhost:5000/blocksecops-api-service:dev python3 -c "import solidity_shared; print('API service image working')"
```

**Expected Output:**
```
API service image working
```

### Image Dependencies ✅

```bash
# Check shared library is in the image
docker run --rm localhost:5000/blocksecops-api-service:dev pip list | grep solidity
```

**Expected Output:**
```
blocksecops-shared  0.1.0
```

## Network and Ingress Verification

### Ingress Controller ✅

```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx
```

**Expected Output:**
```
NAME                                       READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-xxxxx       0/1     Completed   0          30m
ingress-nginx-admission-patch-xxxxx        0/1     Completed   0          30m
ingress-nginx-controller-xxxxxxxxx-xxxxx   1/1     Running     0          30m
```

### Ingress Resources ✅

```bash
# Check created ingress resources
kubectl get ingress -A
```

**Expected Output:**
```
NAMESPACE    NAME                   CLASS   HOSTS                        ADDRESS        PORTS   AGE
monitoring   blocksecops-ingress    nginx   grafana.blocksecops.local    192.168.49.2   80      10m
default      vault-ingress          nginx   vault.blocksecops.local      192.168.49.2   80      10m
```

## Performance and Resource Verification

### Resource Usage ✅

```bash
# Check node resource usage
kubectl top nodes
```

**Expected Output:**
```
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
minikube   500m         8%     3000Mi          50%
```

```bash
# Check pod resource usage
kubectl top pods -A | head -10
```

### Storage Verification ✅

```bash
# Check available storage
kubectl get pv
kubectl get pvc -A
```

**Note:** In local development, most storage uses `emptyDir`, so PVC list may be empty.

## Troubleshooting Failed Verifications

### Common Issues and Solutions

#### 1. Pods Not Running
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>
```

#### 2. Database Connection Failures
```bash
# Check service endpoints
kubectl get endpoints postgresql redis-master -n default

# Test from within cluster
kubectl run debug --image=busybox --rm -it --restart=Never -- telnet postgresql.default.svc.cluster.local 5432
```

#### 3. Registry Access Issues
```bash
# Restart registry if needed
docker restart registry

# Check registry logs
docker logs registry
```

#### 4. Shared Library Import Errors
```bash
# Reinstall shared library
pip uninstall blocksecops-shared
pip install /path/to/blocksecops_shared-0.1.0-py3-none-any.whl
```

## Environment Health Score

Use this checklist to verify overall environment health:

- [ ] ✅ minikube cluster running
- [ ] ✅ All infrastructure pods healthy
- [ ] ✅ PostgreSQL accessible and responding
- [ ] ✅ Redis accessible and responding
- [ ] ✅ Vault unsealed and accessible
- [ ] ✅ Local registry operational with images
- [ ] ✅ Shared library importable
- [ ] ✅ Monitoring stack accessible
- [ ] ✅ DNS resolution working
- [ ] ✅ ConfigMap values correct
- [ ] ✅ Ingress controller running
- [ ] ✅ Resource usage within limits

**Environment Score: 12/12 = ✅ Fully Operational**

## Daily Verification Script

Save this as a quick daily check:

```bash
#!/bin/bash
# daily-env-check.sh

echo "🔍 Daily Environment Check"
echo "========================="

# Cluster
minikube status || echo "❌ minikube not running"

# Pods
UNHEALTHY=$(kubectl get pods -A | grep -v Running | grep -v Completed | wc -l)
if [ $UNHEALTHY -eq 1 ]; then
  echo "✅ All pods healthy"
else
  echo "❌ $((UNHEALTHY-1)) unhealthy pods"
fi

# Databases
kubectl exec -q $(kubectl get pods -l app=postgresql -o name) -- redis-cli ping >/dev/null 2>&1 && echo "✅ PostgreSQL" || echo "❌ PostgreSQL"
kubectl exec -q $(kubectl get pods -l app=redis -o name) -- redis-cli ping >/dev/null 2>&1 && echo "✅ Redis" || echo "❌ Redis"

# Registry
curl -s http://localhost:5000/v2/_catalog >/dev/null && echo "✅ Registry" || echo "❌ Registry"

# Shared library
python3 -c "import solidity_shared" 2>/dev/null && echo "✅ Shared library" || echo "❌ Shared library"

echo "========================="
echo "Check complete!"
```

## Phase 4 Intelligence Platform Verification

### Vulnerability Pattern Knowledge Base ✅

```bash
# Check vulnerability patterns are loaded
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "SELECT COUNT(*) as pattern_count FROM vulnerability_patterns;"
```

**Expected Output:**
```
 pattern_count
---------------
            30
(1 row)
```

```bash
# Check pattern-tool mappings
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "SELECT COUNT(*) as mapping_count FROM pattern_tool_mappings;"
```

**Expected Output:**
```
 mapping_count
---------------
            21
(1 row)
```

```bash
# Verify sample patterns
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "SELECT id, name, category, severity FROM vulnerability_patterns ORDER BY id LIMIT 5;"
```

**Expected Output:**
```
id    |                name                |    category    | severity
---------+------------------------------------+----------------+----------
 ACC-001 | Missing Access Control             | access-control | critical
 ACC-002 | Centralization Risk                | access-control | medium
 ACC-003 | Privilege Escalation               | access-control | high
 CON-001 | Constructor State Change           | construction   | medium
 DEL-001 | Delegatecall to Untrusted Contract | delegatecall   | critical
(5 rows)
```

### Database Migration Version ✅

```bash
# Check Alembic migration version (should be v009 for Phase 4)
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "SELECT * FROM alembic_version;"
```

**Expected Output:**
```
version_num
-------------
 009
(1 row)
```

### Intelligence Tables Verification ✅

```bash
# Check all Phase 4 tables exist
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "SELECT tablename FROM pg_tables WHERE schemaname='public' AND (tablename LIKE '%pattern%' OR tablename LIKE '%dedup%' OR tablename LIKE '%classification%' OR tablename LIKE '%trend%') ORDER BY tablename;"
```

**Expected Output:**
```
tablename
------------------------
 deduplication_groups
 pattern_tool_mappings
 vulnerability_classifications
 vulnerability_patterns
 vulnerability_trends
(5 rows)
```

### API Service Version ✅

```bash
# Check API service is running with correct version
kubectl get deployment api-service -n api-service-local -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Expected Output:**
```
api-service:0.4.4
```

```bash
# Verify pod is healthy
kubectl get pods -n api-service-local
```

**Expected Output:**
```
NAME                          READY   STATUS    RESTARTS   AGE
api-service-895596695-252nb   1/1     Running   0          XXm
```

---

**Verification Date**: October 22, 2025 (Updated for Phase 4)
**Environment**: Local Development minikube
**Status**: ✅ All verifications passing (including Phase 4 intelligence)
**Phase 4 Status**: ✅ Foundation deployed (v0.4.4, migration v009)
**Next Check**: Daily or after environment changes