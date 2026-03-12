# Local Cluster Health Check

**Version:** 1.0.0
**Created:** February 28, 2026
**Last Updated:** February 28, 2026
**Cluster:** debian-server (single-node kubeadm)
**Registry:** Harbor at `harbor.blocksecops.local`
**Platform URL:** `https://app.0xapogee.com`

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| [ ] | Not checked |
| [x] | Healthy |
| [!] | Unhealthy — requires action |
| [~] | Degraded — investigate |

---

## Table of Contents

1. [Node Health](#1-node-health)
2. [Pod Status](#2-pod-status)
3. [Application Services](#3-application-services)
4. [Infrastructure Services](#4-infrastructure-services)
5. [External Access (Traefik)](#5-external-access-traefik)
6. [Internal Service Health](#6-internal-service-health)
7. [Database Health](#7-database-health)
8. [Redis Health](#8-redis-health)
9. [Vault & Secrets](#9-vault--secrets)
10. [Certificates](#10-certificates)
11. [Image Versions & Drift](#11-image-versions--drift)
12. [CronJobs](#12-cronjobs)
13. [HPAs & Scaling](#13-hpas--scaling)
14. [NetworkPolicies](#14-networkpolicies)
15. [IngressRoutes](#15-ingressroutes)
16. [Storage & Disk](#16-storage--disk)
17. [Resource Utilization](#17-resource-utilization)
18. [Stale Resources Cleanup](#18-stale-resources-cleanup)
19. [Scan Pipeline Health](#19-scan-pipeline-health)
20. [WebSocket & Real-Time](#20-websocket--real-time)
21. [Harbor Registry](#21-harbor-registry)
22. [DNS & Domain Resolution](#22-dns--domain-resolution)

---

## 1. Node Health

**Check:**
```bash
kubectl get nodes -o wide
kubectl top nodes
```

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 1.1 | Node `debian-server` status | Ready | | [ ] |
| 1.2 | Kubernetes version | v1.32.x | | [ ] |
| 1.3 | Container runtime | Docker 29.x | | [ ] |
| 1.4 | Node CPU usage | < 30% idle, < 80% critical | | [ ] |
| 1.5 | Node memory usage | < 40% idle, < 85% critical | | [ ] |
| 1.6 | Node conditions (DiskPressure, MemoryPressure, PIDPressure) | All False | | [ ] |

```bash
# Quick node condition check
kubectl get nodes -o jsonpath='{range .items[0].status.conditions[*]}{.type}: {.status}{"\n"}{end}'
# Expected: Ready: True, all others: False
```

---

## 2. Pod Status

**Check:**
```bash
kubectl get pods -A --no-headers | grep -c Running
kubectl get pods -A --field-selector='status.phase!=Running' --no-headers | grep -v "kube-system"
```

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 2.1 | Total running pods | 44-47 | | [ ] |
| 2.2 | Non-running pods (excl kube-system) | 0 | | [ ] |
| 2.3 | CrashLoopBackOff pods | 0 | | [ ] |
| 2.4 | Pods in Pending state | 0 | | [ ] |
| 2.5 | Pods in Error state | 0 | | [ ] |
| 2.6 | Container restarts (last 24h) | < 5 per pod | | [ ] |

```bash
# Check for crash-looping pods
kubectl get pods -A | grep -E "CrashLoopBackOff|Error|Pending|ImagePullBackOff"
# Expected: empty output

# Check high restart counts
kubectl get pods -A --no-headers | awk '$5 > 5 {print $0}'
# Expected: empty output
```

---

## 3. Application Services

### 3.1 Application Deployments

| # | Namespace | Deployment | Replicas | Ready | revisionHistoryLimit | Status |
|---|-----------|-----------|----------|-------|---------------------|--------|
| 3.1.1 | api-service-local | api-service | 1 | | 3 | [ ] |
| 3.1.2 | api-service-local | celery-worker | 1 | | 3 | [ ] |
| 3.1.3 | admin-portal-local | admin-portal | 1 | | 3 | [ ] |
| 3.1.4 | dashboard-local | dashboard | 1 | | 3 | [ ] |
| 3.1.5 | data-service-local | data-service | 1 | | 3 | [ ] |
| 3.1.6 | intelligence-engine-local | intelligence-engine | 1 | | 3 | [ ] |
| 3.1.7 | notification-local | notification | 1 | | 3 | [ ] |
| 3.1.8 | orchestration-local | orchestration | 1 | | 3 | [ ] |
| 3.1.9 | tool-integration-local | tool-integration | 2 (HPA min) | | 3 | [ ] |
| 3.1.10 | contract-parser-local | contract-parser | 1 | | 3 | [ ] |

```bash
# Verify all application deployments
for ns_dep in \
  "api-service-local/api-service" \
  "api-service-local/celery-worker" \
  "admin-portal-local/admin-portal" \
  "dashboard-local/dashboard" \
  "data-service-local/data-service" \
  "intelligence-engine-local/intelligence-engine" \
  "notification-local/notification" \
  "orchestration-local/orchestration" \
  "tool-integration-local/tool-integration" \
  "contract-parser-local/contract-parser" \
; do
  NS=$(echo "$ns_dep" | cut -d/ -f1)
  DEP=$(echo "$ns_dep" | cut -d/ -f2)
  READY=$(kubectl get deployment -n "$NS" "$DEP" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  DESIRED=$(kubectl get deployment -n "$NS" "$DEP" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  RHL=$(kubectl get deployment -n "$NS" "$DEP" -o jsonpath='{.spec.revisionHistoryLimit}' 2>/dev/null)
  printf "  %-40s Ready: %s/%s  RHL: %s\n" "$ns_dep" "${READY:-0}" "${DESIRED:-?}" "${RHL:-?}"
done
```

### 3.2 Application Pod Health

| # | Check | Expected | Status |
|---|-------|----------|--------|
| 3.2.1 | All pods pass liveness probes | No probe failures in logs | [ ] |
| 3.2.2 | All pods pass readiness probes | All endpoints show Ready | [ ] |
| 3.2.3 | Orchestration pod: all 4 containers running | 4/4 Ready | [ ] |

```bash
# Check orchestration pod (multi-container)
kubectl get pod -n orchestration-local -l app.kubernetes.io/name=orchestration -o jsonpath='{.items[0].status.containerStatuses[*].name}' 2>/dev/null
```

---

## 4. Infrastructure Services

### 4.1 Infrastructure Deployments

| # | Namespace | Service | Expected Pods | Ready | Status |
|---|-----------|---------|---------------|-------|--------|
| 4.1.1 | postgresql-local | PostgreSQL (StatefulSet) | 1 | | [ ] |
| 4.1.2 | postgresql-local | postgres-exporter | 1 | | [ ] |
| 4.1.3 | redis-local | Redis | 1 | | [ ] |
| 4.1.4 | redis-local | redis-exporter | 1 | | [ ] |
| 4.1.5 | vault-local | Vault (StatefulSet) | 1 | | [ ] |
| 4.1.6 | traefik-local | Traefik | 1 | | [ ] |
| 4.1.7 | cert-manager-local | cert-manager | 1 | | [ ] |
| 4.1.8 | cert-manager-local | cert-manager-cainjector | 1 | | [ ] |
| 4.1.9 | cert-manager-local | cert-manager-webhook | 1 | | [ ] |
| 4.1.10 | external-secrets-local | external-secrets | 1 | | [ ] |
| 4.1.11 | external-secrets-local | external-secrets-webhook | 1 | | [ ] |
| 4.1.12 | external-secrets-local | external-secrets-cert-controller | 0 (scaled down) | | [ ] |
| 4.1.13 | monitoring-local | Prometheus | 0-1 (optional) | | [ ] |
| 4.1.14 | monitoring-local | prometheus-adapter | 0-1 (optional) | | [ ] |

### 4.2 Harbor Registry

| # | Namespace | Component | Expected Pods | Ready | Status |
|---|-----------|-----------|---------------|-------|--------|
| 4.2.1 | harbor-local | harbor-core | 1 | | [ ] |
| 4.2.2 | harbor-local | harbor-database (StatefulSet) | 1 | | [ ] |
| 4.2.3 | harbor-local | harbor-jobservice | 1 | | [ ] |
| 4.2.4 | harbor-local | harbor-nginx | 1 | | [ ] |
| 4.2.5 | harbor-local | harbor-portal | 1 | | [ ] |
| 4.2.6 | harbor-local | harbor-redis (StatefulSet) | 1 | | [ ] |
| 4.2.7 | harbor-local | harbor-registry | 1 | | [ ] |

### 4.3 System Components

| # | Namespace | Component | Expected Pods | Ready | Status |
|---|-----------|-----------|---------------|-------|--------|
| 4.3.1 | kube-system | CoreDNS | 2 | | [ ] |
| 4.3.2 | kube-system | metrics-server | 1 | | [ ] |
| 4.3.3 | kube-flannel | Flannel CNI (DaemonSet) | 1 | | [ ] |
| 4.3.4 | local-path-storage | local-path-provisioner | 1 | | [ ] |

```bash
# Quick infrastructure pod check
kubectl get pods -n postgresql-local --no-headers
kubectl get pods -n redis-local --no-headers
kubectl get pods -n vault-local --no-headers
kubectl get pods -n traefik-local --no-headers
kubectl get pods -n harbor-local --no-headers
kubectl get pods -n kube-system --no-headers
```

---

## 5. External Access (Traefik)

| # | Check | URL | Expected | Actual | Status |
|---|-------|-----|----------|--------|--------|
| 5.1 | Dashboard loads | `https://app.0xapogee.com/` | 200 | | [ ] |
| 5.2 | API health live | `https://app.0xapogee.com/api/v1/health/live` | 200 + `"status":"healthy"` | | [ ] |
| 5.3 | API health ready | `https://app.0xapogee.com/api/v1/health/ready` | 200 + `"ready":true` | | [ ] |
| 5.4 | API OpenAPI docs | `https://app.0xapogee.com/docs` | 200 | | [ ] |
| 5.5 | Admin portal | `http://admin.0xapogee.com/` | 200 | | [ ] |
| 5.6 | HTTP -> HTTPS redirect | `http://app.0xapogee.com/` | 301/302 to HTTPS | | [ ] |
| 5.7 | Harbor UI | `https://harbor.blocksecops.local/` | 200 | | [ ] |

```bash
# Run all external access checks
echo "Dashboard:     $(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.com/)"
echo "API health:    $(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.com/api/v1/health/live)"
echo "API ready:     $(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.com/api/v1/health/ready)"
echo "API docs:      $(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.com/docs)"
echo "Admin portal:  $(curl -s -o /dev/null -w '%{http_code}' http://admin.0xapogee.com/)"
echo "HTTP redirect: $(curl -sk -o /dev/null -w '%{http_code}' http://app.0xapogee.com/)"
echo "Harbor:        $(curl -sk -o /dev/null -w '%{http_code}' https://harbor.blocksecops.local/)"
```

---

## 6. Internal Service Health

Run from inside the cluster (via `kubectl exec` on the API service pod):

| # | Service | Health URL | Expected Response | Status |
|---|---------|-----------|-------------------|--------|
| 6.1 | tool-integration | `:8005/health` | `"status":"healthy"` | [ ] |
| 6.2 | orchestration | `:8004/health` | `"status":"alive"` | [ ] |
| 6.3 | notification | `:8003/health` | `"status":"alive"` | [ ] |
| 6.4 | intelligence-engine | `:80/health` | `"status":"healthy"` | [ ] |
| 6.5 | data-service | `:8001/health` | `"status":"healthy"` | [ ] |
| 6.6 | contract-parser | `:80/health` | `"status":"OK"` | [ ] |

```bash
for check in \
  "tool-integration|tool-integration.tool-integration-local.svc.cluster.local:8005/health" \
  "orchestration|orchestration.orchestration-local.svc.cluster.local:8004/health" \
  "notification|notification.notification-local.svc.cluster.local:8003/health" \
  "intelligence-engine|intelligence-engine.intelligence-engine-local.svc.cluster.local:80/health" \
  "data-service|data-service.data-service-local.svc.cluster.local:8001/health" \
  "contract-parser|contract-parser.contract-parser-local.svc.cluster.local:80/health" \
; do
  svc=$(echo "$check" | cut -d'|' -f1)
  url=$(echo "$check" | cut -d'|' -f2)
  echo -n "$svc: "
  kubectl exec -n api-service-local deployment/api-service -- curl -s -m 5 "http://$url" 2>/dev/null | head -c 200
  echo ""
done
```

---

## 7. Database Health

### 7.1 PostgreSQL Connectivity

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 7.1.1 | PostgreSQL pod running | Running | | [ ] |
| 7.1.2 | Database `solidity_security` accessible | `SELECT 1` returns 1 | | [ ] |
| 7.1.3 | User `blocksecops` can authenticate | No auth errors | | [ ] |
| 7.1.4 | SSL enabled | `ssl = on` | | [ ] |
| 7.1.5 | Active SSL connections from services | > 0 SSL connections | | [ ] |

```bash
# Basic connectivity
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "SELECT 1;"

# SSL status
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -c "SHOW ssl;"

# Active SSL connections
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security \
  -c "SELECT pid, usename, datname, ssl, client_addr FROM pg_stat_ssl JOIN pg_stat_activity USING (pid) WHERE datname IS NOT NULL;"
```

### 7.2 Database Schema & Data Integrity

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 7.2.1 | Table count | ~88 | | [ ] |
| 7.2.2 | Users table has records | >= 1 | | [ ] |
| 7.2.3 | Vulnerability patterns loaded | >= 393 | | [ ] |
| 7.2.4 | Scanner-to-pattern mappings | >= 637 | | [ ] |
| 7.2.5 | No `info` severity in patterns (post-migration) | 0 | | [ ] |
| 7.2.6 | Alembic migration head matches applied | Heads match current | | [ ] |

```bash
# Table count
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';"

# Key record counts
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT 'users' as tbl, COUNT(*) FROM users
   UNION ALL SELECT 'scans', COUNT(*) FROM scans
   UNION ALL SELECT 'vulnerabilities', COUNT(*) FROM vulnerabilities
   UNION ALL SELECT 'contracts', COUNT(*) FROM contracts
   UNION ALL SELECT 'vulnerability_patterns', COUNT(*) FROM vulnerability_patterns
   UNION ALL SELECT 'pattern_tool_mappings', COUNT(*) FROM pattern_tool_mappings;"

# No info severity
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM vulnerability_patterns WHERE severity IN ('info', 'informational');"
```

### 7.3 Database Performance

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 7.3.1 | Active connections | < max_connections (100) | | [ ] |
| 7.3.2 | Longest running query | < 60s | | [ ] |
| 7.3.3 | Dead tuples (bloat) | < 10% of live tuples | | [ ] |
| 7.3.4 | Lock contention | No long-held locks | | [ ] |

```bash
# Active connections
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM pg_stat_activity WHERE datname='solidity_security';"

# Longest running query
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT pid, now() - query_start AS duration, state, LEFT(query, 80) AS query
   FROM pg_stat_activity
   WHERE datname = 'solidity_security' AND state != 'idle'
   ORDER BY duration DESC LIMIT 5;"

# Table bloat (top 5 by dead tuples)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT relname, n_live_tup, n_dead_tup,
     CASE WHEN n_live_tup > 0 THEN round(100.0 * n_dead_tup / n_live_tup, 1) ELSE 0 END AS dead_pct
   FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 5;"

# Lock contention
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT pid, mode, granted, LEFT(query, 60) AS query
   FROM pg_locks l JOIN pg_stat_activity a USING (pid)
   WHERE NOT granted;"
```

---

## 8. Redis Health

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 8.1 | Redis pod running | Running | | [ ] |
| 8.2 | Redis PING | PONG | | [ ] |
| 8.3 | Connected clients | < 100 | | [ ] |
| 8.4 | Memory usage | < 256Mi | | [ ] |
| 8.5 | Keyspace hit rate | > 80% (if cache active) | | [ ] |

```bash
# Redis pod status
kubectl get pod -n redis-local -l app.kubernetes.io/name=redis --no-headers

# Redis PING
kubectl exec -n redis-local deployment/redis -- redis-cli PING

# Redis INFO (key metrics)
kubectl exec -n redis-local deployment/redis -- redis-cli INFO stats | grep -E "connected_clients|used_memory_human|keyspace_hits|keyspace_misses"

# Hit rate calculation
kubectl exec -n redis-local deployment/redis -- redis-cli INFO stats | \
  awk -F: '/keyspace_hits/{h=$2}/keyspace_misses/{m=$2}END{if(h+m>0) printf "Hit rate: %.1f%%\n",100*h/(h+m); else print "No keyspace activity"}'
```

---

## 9. Vault & Secrets

### 9.1 Vault Status

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 9.1.1 | Vault pod running | Running | | [ ] |
| 9.1.2 | Vault unsealed | `sealed: false` | | [ ] |
| 9.1.3 | Vault initialized | `initialized: true` | | [ ] |

```bash
kubectl exec -n vault-local vault-0 -- vault status -format=json 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Sealed: {d[\"sealed\"]}, Initialized: {d[\"initialized\"]}')"
```

### 9.2 ExternalSecrets

| # | Namespace | ExternalSecret | Store | Synced | Status |
|---|-----------|---------------|-------|--------|--------|
| 9.2.1 | api-service-local | api-service-secret | vault-backend | | [ ] |
| 9.2.2 | data-service-local | data-service-secrets | vault-backend | | [ ] |
| 9.2.3 | intelligence-engine-local | intelligence-engine-secrets | vault-backend | | [ ] |
| 9.2.4 | notification-local | notification-secrets | vault-backend | | [ ] |
| 9.2.5 | orchestration-local | orchestration-secrets | vault-backend | | [ ] |
| 9.2.6 | postgresql-local | postgresql-secret | vault-backend | | [ ] |
| 9.2.7 | redis-local | redis-secret | vault-backend | | [ ] |

```bash
# All ExternalSecrets status
kubectl get externalsecrets -A
# All should show STATUS: SecretSynced, READY: True

# Count unsynced
UNSYNCED=$(kubectl get externalsecret -A --no-headers 2>/dev/null | grep -v "SecretSynced" | wc -l)
echo "Unsynced ExternalSecrets: $UNSYNCED (expected: 0)"
```

### 9.3 Encryption Check

| # | Check | Expected | Status |
|---|-------|----------|--------|
| 9.3.1 | Encryption configured (API readiness check) | `encryption_configured: true` | [ ] |
| 9.3.2 | No plaintext secrets in Git | 0 matches | [ ] |

```bash
# Encryption configured
curl -sk https://app.0xapogee.com/api/v1/health/ready | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('checks',{}).get('encryption_configured') else 'FAIL')"

# Plaintext secret scan (basic grep)
grep -rn "password\|secret_key\|api_key" \
  /home/pwner/Git/blocksecops-gcp-infrastructure/k8s/ \
  --include="*.yaml" --include="*.yml" | \
  grep -v "secretKeyRef\|ExternalSecret\|SecretStore\|#\|kind: Secret\|metadata:" | head -10
# Expected: empty or only references, no actual values
```

---

## 10. Certificates

| # | Namespace | Certificate | Secret | Ready | Expiry Check | Status |
|---|-----------|------------|--------|-------|-------------|--------|
| 10.1 | cert-manager-local | local-ca-certificate | local-ca-secret | | | [ ] |
| 10.2 | cert-manager-local | local-wildcard-certificate | local-wildcard-tls | | | [ ] |
| 10.3 | external-secrets-local | external-secrets-webhook | external-secrets-webhook | | | [ ] |
| 10.4 | harbor-local | harbor-tls | harbor-tls-secret | | | [ ] |
| 10.5 | openclaw | openclaw-certificate | openclaw-tls | | | [ ] |
| 10.6 | postgresql-local | postgresql-certificate | postgresql-tls | | | [ ] |
| 10.7 | redis-local | redis-certificate | redis-tls | | | [ ] |
| 10.8 | traefik-local | app-tls | app-tls-secret | | | [ ] |

```bash
# All certificates with ready status
kubectl get certificates -A
# All should show READY: True

# Check for certificates expiring within 30 days
kubectl get certificates -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: expires {.status.notAfter}{"\n"}{end}'
```

---

## 11. Image Versions & Drift

### 11.1 Running Image Versions

| # | Service | Expected Version | Running Version | Match | Status |
|---|---------|-----------------|-----------------|-------|--------|
| 11.1.1 | api-service | 0.29.41 | | | [ ] |
| 11.1.2 | dashboard | 0.46.11 | | | [ ] |
| 11.1.3 | admin-portal | 0.7.6 | | | [ ] |
| 11.1.4 | tool-integration | 0.5.10 | | | [ ] |
| 11.1.5 | orchestration | 0.10.8 | | | [ ] |
| 11.1.6 | notification | 0.2.6 | | | [ ] |
| 11.1.7 | intelligence-engine | 0.3.7 | | | [ ] |
| 11.1.8 | data-service | 0.2.7 | | | [ ] |
| 11.1.9 | contract-parser | 0.2.2 | | | [ ] |

```bash
# Check all running versions
for ns_svc in \
  "api-service-local/api-service" \
  "dashboard-local/dashboard" \
  "admin-portal-local/admin-portal" \
  "tool-integration-local/tool-integration" \
  "orchestration-local/orchestration" \
  "notification-local/notification" \
  "intelligence-engine-local/intelligence-engine" \
  "data-service-local/data-service" \
  "contract-parser-local/contract-parser" \
; do
  NS=$(echo "$ns_svc" | cut -d/ -f1)
  SVC=$(echo "$ns_svc" | cut -d/ -f2)
  IMG=$(kubectl get deployment -n "$NS" "$SVC" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
  printf "  %-25s %s\n" "$SVC:" "$IMG"
done
```

### 11.2 Version Drift Check

| # | Check | Expected | Status |
|---|-------|----------|--------|
| 11.2.1 | Source (pyproject.toml/package.json) matches kustomization `newTag` | All match | [ ] |
| 11.2.2 | Kustomization `newTag` matches running cluster image | All match | [ ] |
| 11.2.3 | CronJob images match parent Deployment images | No drift | [ ] |
| 11.2.4 | No `:latest` tags in running containers | 0 matches | [ ] |

```bash
# Full version drift check
/home/pwner/Git/scripts/check-version-drift.sh
# Expected: all services show "OK"

# CronJob drift check
echo "=== CronJob Version Drift ==="
for ns in $(kubectl get cronjob -A --no-headers 2>/dev/null | awk '{print $1}' | sort -u); do
  for cj in $(kubectl get cronjob -n "$ns" --no-headers 2>/dev/null | awk '{print $1}'); do
    CJ_IMG=$(kubectl get cronjob -n "$ns" "$cj" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}' 2>/dev/null)
    echo "  $ns/$cj: $CJ_IMG"
  done
done

# No :latest tags
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | grep -c ":latest"
# Expected: 0
```

---

## 12. CronJobs

| # | Namespace | CronJob | Schedule | Last Run | Last Status | Status |
|---|-----------|---------|----------|----------|-------------|--------|
| 12.1 | api-service-local | deduplication-maintenance | `0 2 * * 0` (Sun 02:00 UTC) | | | [ ] |

```bash
# CronJob status
kubectl get cronjobs -A

# Recent job history
kubectl get jobs -A --sort-by=.status.startTime | tail -5

# Check for failed jobs
kubectl get jobs -A --no-headers | awk '$3==0 && $4>0 {print "FAILED:", $1, $2}'
# Expected: empty output
```

---

## 13. HPAs & Scaling

| # | Namespace | HPA | Min | Max | Current | Metrics Working | Status |
|---|-----------|-----|-----|-----|---------|-----------------|--------|
| 13.1 | data-service-local | data-service-hpa | 1 | 3 | | | [ ] |
| 13.2 | tool-integration-local | tool-integration-hpa | 2 | 10 | | | [ ] |
| 13.3 | openclaw | openclaw-gateway | 2 | 5 | | | [ ] |

```bash
# HPA status
kubectl get hpa -A

# Check ScalingActive condition
kubectl get hpa -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: ScalingActive={.status.conditions[?(@.type=="ScalingActive")].status}{"\n"}{end}'
# Expected: all ScalingActive=True
```

---

## 14. NetworkPolicies

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 14.1 | Total NetworkPolicies | 60+ | | [ ] |
| 14.2 | All application namespaces have `default-deny-all` | Yes | | [ ] |
| 14.3 | Infrastructure namespaces have policies | No (known gap) | | [~] |

```bash
# Total count
kubectl get networkpolicy -A --no-headers | wc -l

# Per-namespace count
for ns in api-service-local contract-parser-local dashboard-local data-service-local \
  intelligence-engine-local notification-local orchestration-local tool-integration-local; do
  COUNT=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l)
  echo "  $ns: $COUNT"
done
```

---

## 15. IngressRoutes

| # | Namespace | IngressRoute | Host | Routes To | Status |
|---|-----------|-------------|------|-----------|--------|
| 15.1 | dashboard-local | dashboard-server | `app.0xapogee.com` (excl /api/v1, /ws) | dashboard:3000 | [ ] |
| 15.2 | api-service-local | api-service-server | `app.0xapogee.com` && `/api/v1` | api-service:8000 | [ ] |
| 15.3 | notification-local | notification-websocket | `app.0xapogee.com` && `/ws` | notification:8003 | [ ] |
| 15.4 | admin-portal-local | admin-portal-ingressroute-server | `admin.0xapogee.com` | admin-portal:3000 / api-service:8000 | [ ] |
| 15.5 | tool-integration-local | tool-integration-server | `app.0xapogee.com` && `/api/v1/tool-integration` | tool-integration:8005 | [ ] |
| 15.6 | harbor-local | harbor-server | `harbor.blocksecops.local` | harbor:80 | [ ] |
| 15.7 | traefik-local | app-http-redirect | `app.0xapogee.com` (HTTP) | Redirect HTTPS | [ ] |

```bash
kubectl get ingressroute -A
# Verify no stale/conflicting IngressRoutes
```

---

## 16. Storage & Disk

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 16.1 | Root filesystem usage | < 80% | | [ ] |
| 16.2 | Docker/containerd storage | < 80% | | [ ] |
| 16.3 | PostgreSQL PV healthy | Bound | | [ ] |
| 16.4 | Harbor PVs healthy | All Bound | | [ ] |
| 16.5 | Vault PV healthy | Bound | | [ ] |

```bash
# Disk usage
df -h / | awk 'NR==2 {printf "Root: %s used (%s)\n", $5, ($5+0 > 80 ? "WARNING" : "OK")}'

# Docker storage
docker system df 2>/dev/null || echo "Docker CLI not available on this node"

# PersistentVolumeClaims
kubectl get pvc -A
# All should show STATUS: Bound

# PV usage (if metrics available)
kubectl get pv
```

---

## 17. Resource Utilization

| # | Check | Warning Threshold | Critical Threshold | Actual | Status |
|---|-------|-------------------|--------------------|--------|--------|
| 17.1 | Node CPU | > 50% | > 80% | | [ ] |
| 17.2 | Node memory | > 60% | > 85% | | [ ] |
| 17.3 | Disk usage | > 75% | > 90% | | [ ] |

```bash
# Node resource usage
kubectl top nodes

# Top pod resource consumers
echo "=== Top CPU Pods ==="
kubectl top pods -A --sort-by=cpu --no-headers | head -10

echo "=== Top Memory Pods ==="
kubectl top pods -A --sort-by=memory --no-headers | head -10
```

### 17.1 Per-Service Resource Check

| # | Service | CPU Limit | Memory Limit | Limits Set | Status |
|---|---------|-----------|-------------|------------|--------|
| 17.1.1 | api-service | | | | [ ] |
| 17.1.2 | dashboard | | | | [ ] |
| 17.1.3 | orchestration | | | | [ ] |
| 17.1.4 | tool-integration | | | | [ ] |
| 17.1.5 | intelligence-engine | | | | [ ] |

```bash
# Check resource limits are set on all containers
kubectl get pods -A -o json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for pod in data['items']:
    ns = pod['metadata']['namespace']
    if not ns.endswith('-local') or ns in ('kube-system',):
        continue
    for c in pod['spec']['containers']:
        limits = c.get('resources', {}).get('limits', {})
        if not limits.get('cpu') or not limits.get('memory'):
            print(f'  MISSING LIMITS: {ns}/{pod[\"metadata\"][\"name\"]} container={c[\"name\"]}')
" 2>/dev/null
# Expected: empty output (all containers have limits)
```

---

## 18. Stale Resources Cleanup

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 18.1 | Stale ReplicaSets (0/0/0 desired/current/ready) | < 20 | | [ ] |
| 18.2 | Completed/Failed pods (non kube-system) | 0 | | [ ] |
| 18.3 | Orphan ConfigMaps | None unexpected | | [ ] |
| 18.4 | Orphan scanner pods | 0 | | [ ] |

```bash
# Stale ReplicaSets
STALE_RS=$(kubectl get rs -A --no-headers | awk '$3==0 && $4==0' | wc -l)
echo "Stale ReplicaSets: $STALE_RS (warning if > 20)"

# Completed/Failed pods
kubectl get pods -A --field-selector='status.phase!=Running' --no-headers | grep -v "kube-system"
# Expected: empty

# Orphan scanner pods
kubectl get pods -A -l app=scanner-job --no-headers 2>/dev/null
# Expected: empty (or only currently running scans)
```

---

## 19. Scan Pipeline Health

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 19.1 | Stale scans (queued/running > 1 hour) | 0 | | [ ] |
| 19.2 | Failed scans without error_message | 0 | | [ ] |
| 19.3 | Scanner pods can be scheduled | Yes | | [ ] |
| 19.4 | Tool integration service reachable from orchestration | Health check passes | | [ ] |

```bash
# Stale scans
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM scans WHERE status IN ('queued','running') AND created_at < NOW() - INTERVAL '1 hour';"

# Failed scans missing error
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM scans WHERE status='failed' AND error_message IS NULL;"

# Recent scan status distribution
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT status, COUNT(*) FROM scans GROUP BY status ORDER BY COUNT(*) DESC;"
```

---

## 20. WebSocket & Real-Time

| # | Check | Expected | Status |
|---|-------|----------|--------|
| 20.1 | WebSocket upgrade (via HTTP/1.1) | 101 Switching Protocols | [ ] |
| 20.2 | Notification service reachable | Health check passes | [ ] |

```bash
# WebSocket upgrade test (must use HTTP/1.1)
WS_CODE=$(curl -sk --http1.1 \
  -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -o /dev/null -w "%{http_code}" \
  https://app.0xapogee.com/ws/ 2>/dev/null)
echo "WebSocket upgrade: $WS_CODE (expected: 101)"
```

---

## 21. Harbor Registry

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 21.1 | Harbor API accessible | 200 | | [ ] |
| 21.2 | `blocksecops` project exists | Yes | | [ ] |
| 21.3 | Immutable tag rules configured | Enabled | | [ ] |
| 21.4 | Registry storage usage | < 80% | | [ ] |
| 21.5 | All 7 Harbor pods running | 7/7 | | [ ] |

```bash
# Harbor API health
curl -sk -o /dev/null -w "%{http_code}" https://harbor.blocksecops.local/api/v2.0/health

# Project exists
curl -sk -u admin:${HARBOR_PASSWORD} https://harbor.blocksecops.local/api/v2.0/projects?name=blocksecops | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d else 'NOT FOUND')"

# Immutable tag rules
curl -sk -u admin:${HARBOR_PASSWORD} \
  https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/immutabletagrules | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{len(d)} rules configured')"

# Harbor pod count
HARBOR_PODS=$(kubectl get pods -n harbor-local --no-headers | grep -c Running)
echo "Harbor running pods: $HARBOR_PODS/7"
```

---

## 22. DNS & Domain Resolution

| # | Check | Domain | Expected Resolution | Status |
|---|-------|--------|---------------------|--------|
| 22.1 | Platform domain | `app.0xapogee.com` | 127.0.0.1 (on server) | [ ] |
| 22.2 | Admin domain | `admin.0xapogee.com` | 127.0.0.1 (on server) | [ ] |
| 22.3 | Harbor domain | `harbor.blocksecops.local` | 127.0.0.1 (on server) | [ ] |
| 22.4 | Cluster DNS (CoreDNS) | `kubernetes.default.svc.cluster.local` | Resolves | [ ] |

```bash
# Local DNS resolution (on server)
for domain in app.0xapogee.com admin.0xapogee.com harbor.blocksecops.local; do
  IP=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}')
  echo "  $domain -> ${IP:-NOT RESOLVED}"
done

# Cluster DNS working
kubectl exec -n api-service-local deployment/api-service -- \
  nslookup kubernetes.default.svc.cluster.local 2>/dev/null | head -5
```

---

## Quick Health Check Script

Copy-paste this for a fast cluster health sweep:

```bash
#!/bin/bash
# Local Cluster Health Check — Quick Sweep
# Run: bash docs/audit/LOCAL-CLUSTER-HEALTH-CHECK.sh

set -uo pipefail
PASS=0; FAIL=0; WARN=0

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }
warn() { echo "  WARN: $1"; ((WARN++)); }

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then pass "$name"; else fail "$name (expected=$expected, got=$actual)"; fi
}

echo "=========================================="
echo " Apogee Local Cluster Health Check"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

echo ""
echo "=== 1. Node ==="
NODE_STATUS=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
check "Node Ready" "True" "$NODE_STATUS"

echo ""
echo "=== 2. Pods ==="
RUNNING=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c Running)
NON_RUNNING=$(kubectl get pods -A --field-selector='status.phase!=Running' --no-headers 2>/dev/null | grep -cv "kube-system" || echo 0)
echo "  Running pods: $RUNNING (expected: 44-47)"
if [ "$RUNNING" -ge 40 ]; then pass "Sufficient pods running"; else fail "Low pod count: $RUNNING"; fi
check "No non-running pods" "0" "$NON_RUNNING"

echo ""
echo "=== 3. External Access ==="
check "Dashboard" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.com/ 2>/dev/null)"
check "API health" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.com/api/v1/health/live 2>/dev/null)"
check "API ready" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://app.0xapogee.com/api/v1/health/ready 2>/dev/null)"
check "Admin portal" "200" "$(curl -s -o /dev/null -w '%{http_code}' http://admin.0xapogee.com/ 2>/dev/null)"
check "Harbor" "200" "$(curl -sk -o /dev/null -w '%{http_code}' https://harbor.blocksecops.local/ 2>/dev/null)"

echo ""
echo "=== 4. Infrastructure ==="
check "PostgreSQL" "Running" "$(kubectl get pod -n postgresql-local postgresql-0 --no-headers -o custom-columns=S:.status.phase 2>/dev/null)"
check "Redis" "Running" "$(kubectl get pod -n redis-local -l app.kubernetes.io/name=redis --no-headers -o custom-columns=S:.status.phase 2>/dev/null | head -1)"
check "Vault" "Running" "$(kubectl get pod -n vault-local vault-0 --no-headers -o custom-columns=S:.status.phase 2>/dev/null)"
check "Traefik" "Running" "$(kubectl get pod -n traefik-local -l app.kubernetes.io/name=traefik --no-headers -o custom-columns=S:.status.phase 2>/dev/null)"

VAULT_SEALED=$(kubectl exec -n vault-local vault-0 -- vault status -format=json 2>/dev/null | python3 -c "import sys,json; print('false' if not json.load(sys.stdin)['sealed'] else 'true')" 2>/dev/null)
check "Vault unsealed" "false" "$VAULT_SEALED"

echo ""
echo "=== 5. Database ==="
DB_OK=$(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -t -c "SELECT 1;" 2>/dev/null | tr -d ' ')
check "DB query" "1" "$DB_OK"

SSL_ON=$(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -t -c "SHOW ssl;" 2>/dev/null | tr -d ' ')
check "DB SSL" "on" "$SSL_ON"

echo ""
echo "=== 6. Secrets & Certs ==="
UNSYNCED=$(kubectl get externalsecret -A --no-headers 2>/dev/null | grep -v "SecretSynced" | wc -l | tr -d ' ')
check "ExternalSecrets synced" "0" "$UNSYNCED"

CERTS_NOT_READY=$(kubectl get certificates -A --no-headers 2>/dev/null | grep -v "True" | wc -l | tr -d ' ')
check "Certificates ready" "0" "$CERTS_NOT_READY"

echo ""
echo "=== 7. Internal Services ==="
for svc_url in \
  "tool-integration|tool-integration.tool-integration-local.svc.cluster.local:8005/health" \
  "orchestration|orchestration.orchestration-local.svc.cluster.local:8004/health" \
  "notification|notification.notification-local.svc.cluster.local:8003/health" \
  "intelligence|intelligence-engine.intelligence-engine-local.svc.cluster.local:80/health" \
  "data-service|data-service.data-service-local.svc.cluster.local:8001/health" \
  "contract-parser|contract-parser.contract-parser-local.svc.cluster.local:80/health" \
; do
  svc=$(echo "$svc_url" | cut -d'|' -f1)
  url=$(echo "$svc_url" | cut -d'|' -f2)
  resp=$(kubectl exec -n api-service-local deployment/api-service -- curl -s -m 5 "http://$url" 2>/dev/null)
  if echo "$resp" | grep -q '"status"'; then pass "$svc"; else fail "$svc"; fi
done

echo ""
echo "=== 8. Scan Health ==="
STALE=$(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -t -c \
  "SELECT COUNT(*) FROM scans WHERE status IN ('queued','running') AND created_at < NOW() - INTERVAL '1 hour';" 2>/dev/null | tr -d ' ')
check "No stale scans" "0" "$STALE"

echo ""
echo "=== 9. Disk ==="
DISK_PCT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_PCT" -lt 80 ]; then pass "Disk usage ${DISK_PCT}%"; elif [ "$DISK_PCT" -lt 90 ]; then warn "Disk usage ${DISK_PCT}%"; else fail "Disk usage ${DISK_PCT}%"; fi

echo ""
echo "=== 10. Stale Resources ==="
STALE_RS=$(kubectl get rs -A --no-headers | awk '$3==0 && $4==0' | wc -l)
if [ "$STALE_RS" -lt 20 ]; then pass "Stale ReplicaSets: $STALE_RS"; else warn "Stale ReplicaSets: $STALE_RS (> 20)"; fi

echo ""
echo "=========================================="
echo " RESULTS: $PASS passed, $FAIL failed, $WARN warnings"
[ "$FAIL" -eq 0 ] && echo " STATUS: HEALTHY" || echo " STATUS: $FAIL CHECKS FAILED"
echo "=========================================="
```

---

## When to Run This Health Check

| Event | Priority |
|-------|----------|
| Morning daily check | Recommended |
| After cluster reboot | Required |
| After any `kubectl apply -k` | Required |
| After `kubectl rollout restart` | Required |
| After database migration | Required |
| After infrastructure changes (Traefik, Vault, certs) | Required |
| After docker build + push | Required |
| Before running the comprehensive platform audit | Required |
| After recovering from an incident | Required |

---

## Related Documents

- [Cluster Baseline](../standards/cluster-baseline.md) — Expected healthy cluster state
- [Smoke Test Standards](../standards/smoke-test.md) — Post-deployment smoke tests
- [Comprehensive Platform Audit](./COMPREHENSIVE-PLATFORM-AUDIT.md) — Full platform audit checklist
- [Port Forwarding / Service Access](../standards/port-forwarding.md) — Service URLs and ports
- [Docker Image Versioning](../standards/docker-image-versioning.md) — Version tracking
