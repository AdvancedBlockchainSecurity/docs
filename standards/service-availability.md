# Service Availability Standards

**Version:** 1.0.0
**Last Updated:** January 15, 2026
**Status:** Active

## Core Principle

> **Services MUST be always available without manual intervention.**

After cluster start, all services should be accessible immediately without running additional commands like port-forwards.

---

## Why This Matters

| Manual Port-Forwards | Always-Available Access |
|---------------------|------------------------|
| Requires setup every time | Works immediately |
| Processes can die silently | Infrastructure-managed |
| Not production-like | Mirrors production |
| Creates friction | Seamless development |
| Not suitable for pre-prod | Suitable for all environments |

---

## Environment Access Matrix

| Environment | Method | Access Pattern | One-Time Setup |
|-------------|--------|----------------|----------------|
| **Local (minikube)** | `minikube tunnel` + LoadBalancer | `http://127.0.0.1:3000` | Start tunnel in tmux |
| **Server (kubeadm)** | hostPort 80/443 + Traefik | `http://app.blocksecops.local` | DNS entries |
| **Production (GCP)** | GCP Load Balancer | `https://app.blocksecops.com` | None (managed) |

---

## Anti-Pattern: Manual Port-Forwards for Regular Access

**DO NOT** use port-forwards as the primary access method:

```bash
# WRONG - Manual port-forward for regular development
kubectl port-forward -n traefik-local svc/traefik 3000:80 &
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &
# ... more port-forwards

# RIGHT - Use always-available access
# Local: minikube tunnel (one-time setup)
# Server: hostPort with DNS (one-time setup)
# Production: managed infrastructure
```

---

## When Port-Forwards ARE Acceptable

Use manual port-forwards only for:

| Use Case | Why |
|----------|-----|
| Direct database access | PostgreSQL is internal-only by design |
| Direct Redis access | Redis is internal-only by design |
| Debugging specific pod | Need to bypass ingress |
| Accessing Vault UI | Internal service without external route |
| Prometheus/Grafana | Monitoring is optional |
| One-off troubleshooting | Temporary access |

---

## Setup Per Environment

### Local Development (minikube)

**One-Time Setup:**
```bash
# Start minikube tunnel (runs persistently)
tmux new -s tunnel -d 'minikube tunnel'
```

**Verification:**
```bash
curl http://127.0.0.1:3000/api/v1/health/live
```

**Requirements:**
- Services must use `type: LoadBalancer`
- minikube tunnel must be running

### Server Environment (kubeadm)

**One-Time Setup:**
```bash
# On server (for local API testing)
echo "127.0.0.1  app.blocksecops.local" | sudo tee -a /etc/hosts

# On client machines
echo "192.168.86.225  app.blocksecops.local" | sudo tee -a /etc/hosts
```

**Verification:**
```bash
curl http://app.blocksecops.local/api/v1/health/live
```

**Requirements:**
- Traefik with hostPort 80/443 deployed
- DNS entries configured

### Production (GCP)

**Setup:** Managed by infrastructure - no manual setup required.

**Verification:**
```bash
curl https://app.blocksecops.com/api/v1/health/live
```

---

## Startup Verification Checklist

After cluster start or restart, verify services are accessible:

### Local (minikube)

```bash
# 1. Check tunnel is running
pgrep -f "minikube tunnel" || echo "Tunnel not running!"

# 2. Check services have external IPs
kubectl get svc -A | grep LoadBalancer

# 3. Test access
curl http://127.0.0.1:3000/api/v1/health/live
```

### Server (kubeadm)

```bash
# 1. Check Traefik is running
kubectl get pods -n traefik-local

# 2. Check hostPort is active
curl http://127.0.0.1/api/v1/health/live

# 3. Test domain access
curl http://app.blocksecops.local/api/v1/health/live
```

### Production (GCP)

```bash
# 1. Check load balancer
kubectl get svc -n traefik

# 2. Test access
curl https://app.blocksecops.com/api/v1/health/live
```

---

## Troubleshooting

### Services Not Accessible After Cluster Start

**Local (minikube):**
1. Check if tunnel is running: `pgrep -f "minikube tunnel"`
2. If not, start it: `tmux new -s tunnel -d 'minikube tunnel'`
3. Check services have external IPs: `kubectl get svc -A`

**Server (kubeadm):**
1. Check Traefik is running: `kubectl get pods -n traefik-local`
2. Check DNS resolves: `ping app.blocksecops.local`
3. If DNS fails, check /etc/hosts entry

### Connection Refused Errors

1. Check if pods are running: `kubectl get pods -A`
2. Check if service has endpoints: `kubectl get endpoints -n <namespace>`
3. Check Traefik logs: `kubectl logs -n traefik-local -l app.kubernetes.io/name=traefik`

---

## Related Standards

- [Service Access Standards](./port-forwarding.md) - Environment-specific access patterns
- [Domain Management](./domain-management.md) - DNS and domain configuration
- [Core Development Rules](./core-development-rules.md) - Development workflow
