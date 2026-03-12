# GCP Networking

## VPC

| Setting | Value |
|---------|-------|
| Name | `apogee-production-vpc` |
| Auto-create subnets | No (custom) |
| Routing mode | Regional |

## Subnets

| Subnet | CIDR | Purpose | Private Google Access |
|--------|------|---------|----------------------|
| `apogee-production-gke-subnet` | `10.0.0.0/20` | GKE nodes | Yes |
| `apogee-production-database-subnet` | `10.0.16.0/24` | Unused (was for Cloud SQL) | Yes |
| `apogee-production-redis-subnet` | `10.0.17.0/24` | Unused (was for Memorystore) | Yes |
| `gke-...-pe-subnet` | `172.16.0.0/28` | GKE master peering | No |

**Note:** Database and Redis subnets are unused — both services run in-cluster as StatefulSets on the GKE subnet. These subnets can be deleted to reduce clutter.

## IP Ranges

| Resource | Address | Type | Status |
|----------|---------|------|--------|
| Load balancer | `34.149.16.104` | Global external | In use |
| Cloud NAT | `136.109.182.120` | Regional external | In use (auto-allocated) |
| Service networking | `10.3.0.0` | Internal | Reserved (unused — was for Cloud SQL peering) |

## Firewall Rules

### Custom Rules (Terraform-managed, logging enabled)

| Rule | Direction | Source | Allow | Target |
|------|-----------|--------|-------|--------|
| `allow-health-checks` | Ingress | `130.211.0.0/22`, `35.191.0.0/16` | TCP 80, 443, 8080, 8000, 3000 | `gke-node` |
| `allow-iap` | Ingress | `35.235.240.0/20` | TCP 22 | `gke-node` |
| `allow-internal` | Ingress | `10.0.0.0/16` | All protocols | `gke-node` |
| `allow-master-to-nodes` | Ingress | `10.0.0.0/16`, `172.16.0.0/28` | TCP 443, 8443, 10250 | `gke-node` |
| `deny-all-ingress` | Ingress | `0.0.0.0/0` | (none — deny) | All (priority 65534) |

### GKE Auto-Created Rules (logging disabled)

| Rule | Source | Allow | Target |
|------|--------|-------|--------|
| `gke-...-all` | `10.1.0.0/16` (pod CIDR) | All protocols | GKE nodes |
| `gke-...-exkubelet` | `0.0.0.0/0` | (deny) | GKE nodes |
| `gke-...-inkubelet` | `10.1.0.0/16` | TCP 10255 | GKE nodes |
| `gke-...-vms` | `10.0.0.0/20` | TCP 1-65535, UDP, ICMP | GKE nodes |
| `gkegw1-...-global` | `130.211.0.0/22`, `35.191.0.0/16` | TCP 0-65535 | (no tags) |

## Cloud NAT

All egress from private GKE nodes goes through Cloud NAT.

| Setting | Value |
|---------|-------|
| Router | `apogee-production-router` |
| NAT gateway | `apogee-production-nat` |
| IP allocation | Auto (single IP) |
| Dynamic port allocation | Enabled |
| Min ports per VM | 64 |
| Endpoint-independent mapping | Disabled |
| Logging | Errors only |

## DNS

| Record | Value | Managed By |
|--------|-------|------------|
| `app.0xapogee.com` | Cloudflare proxy → `34.149.16.104` | Cloudflare |

Traffic flow:
```
Client → Cloudflare (TLS termination + CDN) → GCP LB (34.149.16.104) → GKE Gateway → Pod
```

## Internal Service DNS

Services communicate via Kubernetes DNS:

```
<service>.<namespace>.svc.cluster.local:<port>

Examples:
  postgresql.postgresql-prod.svc.cluster.local:5432
  redis.redis-prod.svc.cluster.local:6379
  api-service.api-service-prod.svc.cluster.local:8000
  data-service.data-service-prod.svc.cluster.local:80
  intelligence-engine.intelligence-engine-prod.svc.cluster.local:80
  contract-parser.contract-parser-prod.svc.cluster.local:80
  orchestration.orchestration-prod.svc.cluster.local:8004
  notification.notification-prod.svc.cluster.local:8003
  tool-integration.tool-integration-prod.svc.cluster.local:8005
  dashboard.dashboard-prod.svc.cluster.local:3000
  admin-portal.admin-portal-prod.svc.cluster.local:3000
```

## Scanner Pod Networking

Scanner Jobs run in the `tool-integration-prod` namespace with label `app: scanner`. After analysis, scanner pods POST results to tool-integration via the CALLBACK_URL.

**Traffic flow:**
```
Scanner Pod (app=scanner) → tool-integration.tool-integration-prod.svc.cluster.local:8005 → /api/v1/scans/{scan_id}/results
```

**NetworkPolicy requirements (v0.5.26+):**

| Policy | Applies To | Direction | Allows |
|--------|-----------|-----------|--------|
| `scanner-network-policy` | `app: scanner` | Egress | DNS (53/UDP+TCP), tool-integration (8005/TCP) |
| `tool-integration-network-policy` | `app: tool-integration` | Ingress | FROM `app: scanner` on 8005/TCP |

Both policies are defined in `k8s/base/` and inherited by all overlays. The GCP overlay additionally patches `tool-integration-network-policy` with namespace-scoped selectors via `networkpolicy-patch.yaml`.

**Verification:**
```bash
kubectl get networkpolicy -n tool-integration-prod -l app=scanner
kubectl describe networkpolicy tool-integration-network-policy -n tool-integration-prod | grep -A3 "app: scanner"
```

## GKE Gateway Routes

| Path | Backend | Namespace |
|------|---------|-----------|
| `/api/v1/*` | api-service:8000 | api-service-prod |
| `/ws/*` | notification:8003 | notification-prod |
| `/admin/*` | admin-portal:3000 | admin-portal-prod |
| `/*` (default) | dashboard:3000 | dashboard-prod |
