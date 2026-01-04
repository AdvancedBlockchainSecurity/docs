# Database Exporters

**Last Updated**: December 12, 2025
**Status**: Deployed (Local Environment)

---

## Overview

Database exporters collect metrics from PostgreSQL and Redis, exposing them in Prometheus format for monitoring and alerting.

## Deployed Exporters

| Exporter | Image | Port | Namespace |
|----------|-------|------|-----------|
| postgres-exporter | prometheuscommunity/postgres-exporter:v0.15.0 | 9187 | postgresql-local |
| redis-exporter | oliver006/redis_exporter:v1.55.0 | 9121 | redis-local |

---

## PostgreSQL Exporter

### Deployment

```yaml
# Location: k8s/overlays/local/postgresql/postgres-exporter.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-exporter
  namespace: postgresql-local
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-exporter
  template:
    metadata:
      labels:
        app: postgres-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9187"
    spec:
      containers:
        - name: postgres-exporter
          image: prometheuscommunity/postgres-exporter:v0.15.0
          ports:
            - containerPort: 9187
              name: metrics
          env:
            - name: DATA_SOURCE_NAME
              value: "postgresql://postgres:postgres@postgresql:5432/solidity_security?sslmode=disable"
```

### Key Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `pg_up` | Gauge | Database availability (1 = up, 0 = down) |
| `pg_stat_activity_count` | Gauge | Active connections by state |
| `pg_database_size_bytes` | Gauge | Database size in bytes |
| `pg_stat_user_tables_n_tup_ins` | Counter | Rows inserted |
| `pg_stat_user_tables_n_tup_upd` | Counter | Rows updated |
| `pg_stat_user_tables_n_tup_del` | Counter | Rows deleted |
| `pg_stat_user_tables_seq_scan` | Counter | Sequential scans |
| `pg_stat_user_tables_idx_scan` | Counter | Index scans |
| `pg_locks_count` | Gauge | Active locks by mode |

### Useful Prometheus Queries

```promql
# Database availability
pg_up{job="postgres-exporter"}

# Active connections
sum(pg_stat_activity_count{datname="solidity_security"})

# Database size (MB)
pg_database_size_bytes{datname="solidity_security"} / 1024 / 1024

# Rows per second (insert/update/delete)
rate(pg_stat_user_tables_n_tup_ins[5m])
rate(pg_stat_user_tables_n_tup_upd[5m])
rate(pg_stat_user_tables_n_tup_del[5m])

# Cache hit ratio
pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read)
```

---

## Redis Exporter

### Deployment

```yaml
# Location: k8s/overlays/local/redis/redis-exporter.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-exporter
  namespace: redis-local
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis-exporter
  template:
    metadata:
      labels:
        app: redis-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9121"
    spec:
      containers:
        - name: redis-exporter
          image: oliver006/redis_exporter:v1.55.0
          ports:
            - containerPort: 9121
              name: metrics
          env:
            - name: REDIS_ADDR
              value: "redis://redis:6379"
            - name: REDIS_PASSWORD
              value: "redis-local-password"
```

### Key Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `redis_up` | Gauge | Redis availability (1 = up, 0 = down) |
| `redis_connected_clients` | Gauge | Connected clients |
| `redis_memory_used_bytes` | Gauge | Memory usage |
| `redis_memory_max_bytes` | Gauge | Max memory configured |
| `redis_commands_processed_total` | Counter | Commands processed |
| `redis_keyspace_hits_total` | Counter | Key lookup hits |
| `redis_keyspace_misses_total` | Counter | Key lookup misses |
| `redis_db_keys` | Gauge | Keys per database |
| `redis_expired_keys_total` | Counter | Expired keys |
| `redis_evicted_keys_total` | Counter | Evicted keys |

### Useful Prometheus Queries

```promql
# Redis availability
redis_up{job="redis-exporter"}

# Connected clients
redis_connected_clients

# Memory usage (MB)
redis_memory_used_bytes / 1024 / 1024

# Memory utilization percentage
redis_memory_used_bytes / redis_memory_max_bytes * 100

# Commands per second
rate(redis_commands_processed_total[5m])

# Cache hit ratio
redis_keyspace_hits_total / (redis_keyspace_hits_total + redis_keyspace_misses_total)

# Total keys
sum(redis_db_keys)
```

---

## Verification

### Check Exporter Status

```bash
# PostgreSQL Exporter
kubectl get pods -n postgresql-local -l app=postgres-exporter
kubectl logs -n postgresql-local -l app=postgres-exporter --tail=20

# Redis Exporter
kubectl get pods -n redis-local -l app=redis-exporter
kubectl logs -n redis-local -l app=redis-exporter --tail=20
```

### Test Metrics Endpoints

```bash
# PostgreSQL metrics (from within cluster)
kubectl exec -n postgresql-local deployment/postgres-exporter -- curl -s localhost:9187/metrics | head -30

# Redis metrics (from within cluster)
kubectl exec -n redis-local deployment/redis-exporter -- curl -s localhost:9121/metrics | head -30
```

### Port Forward for Local Access

```bash
# PostgreSQL exporter
kubectl port-forward -n postgresql-local svc/postgres-exporter 9187:9187 &

# Redis exporter
kubectl port-forward -n redis-local svc/redis-exporter 9121:9121 &

# Test locally
curl http://127.0.0.1:9187/metrics | head -30
curl http://127.0.0.1:9121/metrics | head -30
```

---

## Prometheus Scrape Configuration

The exporters are automatically discovered by Prometheus through pod annotations:

```yaml
# Pod annotations for auto-discovery
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9187"  # or "9121" for Redis
```

Verify Prometheus is scraping:

```bash
# Check Prometheus targets
curl -s http://127.0.0.1:9091/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("exporter")) | {job: .labels.job, health: .health}'
```

---

## Troubleshooting

### PostgreSQL Exporter Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| `pg_up = 0` | Connection refused | Check PostgreSQL service is running |
| Auth error in logs | Wrong credentials | Verify DATA_SOURCE_NAME credentials |
| No metrics | Pod not running | Check pod status and logs |

### Redis Exporter Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| `redis_up = 0` | Connection refused | Check Redis service is running |
| `NOAUTH required` | Missing password | Add REDIS_PASSWORD env var |
| Metrics timeout | Redis overloaded | Check Redis memory/connections |

### Common Fixes

```bash
# Restart exporter pod
kubectl rollout restart deployment/postgres-exporter -n postgresql-local
kubectl rollout restart deployment/redis-exporter -n redis-local

# Check service connectivity
kubectl exec -n postgresql-local deployment/postgres-exporter -- nc -zv postgresql 5432
kubectl exec -n redis-local deployment/redis-exporter -- nc -zv redis 6379
```

---

## Related Documentation

- [Prometheus Configuration](prometheus-configuration.md)
- [Grafana Dashboards](grafana-dashboards.md)
- [Local Deployment Guide](local-deployment.md)
- [Port Forwarding Standards](/Users/pwner/Git/ABS/docs/standards/port-forwarding.md)

---

**Document Owner:** Infrastructure Team
**Last Updated:** December 12, 2025
