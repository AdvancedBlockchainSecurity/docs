# GCP Scaling & Resources

## Node Pools

### Default Pool (`apogee-production-default`)

| Setting | Value |
|---------|-------|
| Machine type | `e2-standard-2` (2 vCPU, 8 GB RAM) |
| Disk | 100 GB pd-ssd |
| Min nodes | 2 |
| Max nodes | 2 |
| Location policy | BALANCED |
| Auto-repair | Yes |
| Auto-upgrade | Yes |
| Allocatable per node | 1930m CPU, ~6 GB RAM |

### Scanner Pool (`apogee-production-scanners`)

| Setting | Value |
|---------|-------|
| Machine type | `e2-standard-4` (4 vCPU, 16 GB RAM) |
| Disk | 200 GB pd-ssd |
| Min nodes | 0 (scales to zero) |
| Max nodes | 3 |
| Location policy | ANY |
| Auto-repair | Yes |
| Auto-upgrade | Yes |

Scanner pool nodes spin up on demand when scanner Jobs are created and scale back to zero when idle. Nodes have taints to prevent non-scanner workloads from scheduling.

## Resource Usage (Typical)

### Node Utilization

| Node | CPU | Memory |
|------|-----|--------|
| Node 1 | ~25% (492m / 1930m) | ~47% (2855 Mi / 6 GB) |
| Node 2 | ~12% (242m / 1930m) | ~41% (2526 Mi / 6 GB) |

### Top Pods by Memory

| Pod | Memory |
|-----|--------|
| api-service | ~329 Mi |
| celery-worker | ~240 Mi |
| tool-integration (x2) | ~115 Mi each |
| intelligence-engine | ~43 Mi |
| postgresql | ~31 Mi |

## Horizontal Pod Autoscalers

| Service | Min | Max | CPU Target | Memory Target |
|---------|-----|-----|------------|---------------|
| tool-integration | 2 | 10 | 75% | 85% |

Other services use fixed replica counts. Add HPAs as traffic grows.

## Service Replica Counts

| Replicas | Services |
|----------|----------|
| 2 | dashboard, tool-integration |
| 1 | api-service, celery-worker, data-service, intelligence-engine, notification, orchestration, contract-parser, admin-portal |
| 1 (StatefulSet) | postgresql, redis |

## Scaling Guidance

### When to scale the default pool

- CPU consistently > 70% across both nodes
- Pods stuck in Pending due to insufficient resources
- Increase `maxNodeCount` in Terraform, then `terraform apply`

### When to add HPAs

- Service receives variable external traffic (api-service, dashboard)
- Service has bursty workloads (intelligence-engine during batch analysis)

### HPA template

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <service>-hpa
  namespace: <service>-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <service>
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 75
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 85
```

## Database Resources

| Database | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|----------|-------------|-----------|----------------|--------------|---------|
| PostgreSQL | 200m | 1000m | 256 Mi | 1 Gi | 10 Gi (standard-rwo) |
| Redis | 50m | 200m | 64 Mi | 256 Mi | 1 Gi (premium-rwo) |
