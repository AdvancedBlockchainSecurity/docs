# Service Availability Standards

**Version:** 2.0.0
**Last Updated:** March 10, 2026
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

| Environment | Method | Access Pattern |
|-------------|--------|----------------|
| Development | Ingress controller with hostPort/NodePort | `https://<env-domain>` |
| Production | Managed load balancer | `https://app.0xapogee.com` |

---

## Anti-Pattern: Manual Port-Forwards for Regular Access

**DO NOT** use port-forwards as the primary access method:

```bash
# WRONG - Manual port-forward for regular development
kubectl port-forward -n <ingress-namespace> svc/traefik 3000:80 &
kubectl port-forward -n <service>-<env> svc/api-service 8000:8000 &
# ... more port-forwards

# RIGHT - Use always-available access
# Development: hostPort 80/443 + Traefik with DNS (one-time setup)
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

Each environment has its own one-time setup. See environment-specific documentation for details.

### Production (GCP)

**Setup:** Managed by infrastructure - no manual setup required.

**Verification:**
```bash
curl https://app.0xapogee.com/api/v1/health/live
```

---

## Startup Verification Checklist

After cluster start or restart, verify services are accessible:

```bash
# 1. Check ingress controller is running
kubectl get pods -n <ingress-namespace>

# 2. Check services are healthy
curl https://<env-domain>/api/v1/health/live
```

### Production (GCP)

```bash
# 1. Check Gateway is programmed
kubectl get gateway apogee-gateway -n ingress-prod

# 2. Check all services are running
kubectl get pods -A | grep -E "prod.*Running"

# 3. Test access (via Cloudflare)
curl https://app.0xapogee.com/api/v1/health/live
```

---

## Troubleshooting

### Services Not Accessible After Cluster Start

1. Check ingress controller is running: `kubectl get pods -n <ingress-namespace>`
2. Check hostPort/NodePort is active: `curl -k https://<node-ip>/api/v1/health/live`
3. If DNS fails, check DNS configuration for your environment

### Connection Refused Errors

1. Check if pods are running: `kubectl get pods -A`
2. Check if service has endpoints: `kubectl get endpoints -n <namespace>`
3. Check ingress controller logs: `kubectl logs -n <ingress-namespace> -l app.kubernetes.io/name=traefik`

---

## Related Standards

- [Domain Management](./domain-management.md) - Environment-specific access patterns
- [Domain Management](./domain-management.md) - DNS and domain configuration
- [Core Development Rules](./core-development-rules.md) - Development workflow
