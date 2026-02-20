# Ingress and Networking Standards

**Standard ID**: NET-001
**Version**: 1.1.0
**Last Updated**: 2026-01-15
**Status**: Active

## Overview

This document defines the standards for ingress controllers, routing, and networking in BlockSecOps platform infrastructure across all environments (local, staging, production).

## Ingress Controller Standard

### Official Ingress Controller: Traefik v3.6+

**Traefik** is the official and only supported ingress controller for BlockSecOps platform.

- **Current Version**: v3.6.2
- **Minimum Version**: v3.6.0
- **Update Policy**: Minor version updates (3.x) applied automatically; major version updates require testing and approval

### Deprecated Technologies

**Nginx Ingress Controller** - DEPRECATED
- **EOL Date**: March 31, 2026
- **Status**: Legacy support only, no new deployments
- **Migration Required**: All nginx Ingress resources must be migrated to Traefik by Q1 2026

## Traefik Architecture

### EntryPoints Configuration

Traefik uses entryPoints to define ports where it listens for incoming traffic:

```yaml
entryPoints:
  web:
    address: ":80"      # HTTP traffic
  websecure:
    address: ":443"     # HTTPS traffic
  postgres:
    address: ":5432"    # PostgreSQL TCP traffic
  redis:
    address: ":6379"    # Redis TCP traffic
  metrics:
    address: ":9100"    # Prometheus metrics
```

### Providers Configuration

```yaml
providers:
  kubernetesIngress:
    allowExternalNameServices: true
    allowEmptyServices: false
    ingressClass: traefik
  kubernetesCRD:
    allowExternalNameServices: true
    allowEmptyServices: false
    allowCrossNamespace: true  # Enable cross-namespace routing
```

## Resource Types

### 1. IngressRoute (HTTP/HTTPS Services)

Use IngressRoute for HTTP and HTTPS traffic routing.

**When to use**:
- Web applications (Dashboard, Frontend)
- REST APIs (API Service)
- Any service using HTTP/HTTPS protocols

**Example**: HTTP service with CORS middleware

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: api-service
  namespace: api-service-local
  labels:
    app.kubernetes.io/name: api-service
    app.kubernetes.io/instance: api-service-local
    app.kubernetes.io/component: backend-api
    environment: local
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`api.local.example.com`)
      kind: Rule
      middlewares:
        - name: api-service-cors
          namespace: api-service-local
      services:
        - name: api-service
          port: 8000
```

**Multiple Routes Example**:

```yaml
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`api.example.com`)
      kind: Rule
      middlewares:
        - name: api-cors
      services:
        - name: api-service
          port: 8000
    - match: Host(`localhost`) && PathPrefix(`/api`)
      kind: Rule
      middlewares:
        - name: api-cors
      services:
        - name: api-service
          port: 8000
```

### 2. IngressRouteTCP (TCP Services)

Use IngressRouteTCP for non-HTTP TCP protocol routing.

**When to use**:
- Databases (PostgreSQL, MySQL, MongoDB)
- Key-value stores (Redis, Memcached)
- Message queues (RabbitMQ, Kafka)
- Any service using raw TCP protocols

**Example**: PostgreSQL routing

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: postgresql
  namespace: postgresql-local
  labels:
    app.kubernetes.io/name: postgresql
    app.kubernetes.io/component: infrastructure-database
    environment: local
spec:
  entryPoints:
    - postgres
  routes:
    - match: HostSNI(`*`)
      services:
        - name: postgresql
          port: 5432
```

**Note**: For TCP routes, `HostSNI(`*`)` matches all TLS SNI hostnames. For non-TLS TCP, this is the standard pattern.

### 3. Middleware

Middleware provides request/response processing capabilities.

#### CORS Middleware (Production-Ready Template)

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: <service>-cors
  namespace: <namespace>
spec:
  headers:
    accessControlAllowCredentials: true
    accessControlAllowMethods:
      - GET
      - POST
      - PUT
      - DELETE
      - OPTIONS
      - PATCH
    accessControlAllowOriginList:
      - "*"  # For production, specify allowed origins
    accessControlAllowHeaders:
      - "DNT"
      - "X-CustomHeader"
      - "Keep-Alive"
      - "User-Agent"
      - "X-Requested-With"
      - "If-Modified-Since"
      - "Cache-Control"
      - "Content-Type"
      - "Authorization"
    accessControlMaxAge: 100
    addVaryHeader: true
```

#### Other Common Middleware Types

**Headers Middleware**: Add/modify HTTP headers

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: default
spec:
  headers:
    customResponseHeaders:
      X-Frame-Options: "DENY"
      X-Content-Type-Options: "nosniff"
      X-XSS-Protection: "1; mode=block"
```

**RateLimit Middleware**: Limit request rates

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: default
spec:
  rateLimit:
    average: 100
    burst: 50
```

## Directory Structure Standards

### Service Overlay Directory Pattern

```
k8s/overlays/local/<service>/
├── kustomization.yaml
├── ingressroute.yaml          # For HTTP services (web entryPoint)
├── ingressroute-server.yaml   # For HTTPS services (websecure entryPoint)
├── ingressroute-tcp.yaml      # For TCP services
├── middleware-cors.yaml       # For CORS
└── middleware-*.yaml          # Other middlewares
```

**IMPORTANT:** Services accessed over HTTPS (server/production environments) need **both** `ingressroute.yaml` (HTTP) and `ingressroute-server.yaml` (HTTPS). Without the `websecure` IngressRoute, the service is unreachable when traffic arrives on port 443.

### Complete Example: HTTP Service with CORS

```
k8s/overlays/local/api-service/
├── kustomization.yaml
├── ingressroute.yaml
└── middleware-cors.yaml
```

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: api-service-local

resources:
  - middleware-cors.yaml
  - ingressroute.yaml
```

### Complete Example: TCP Service

```
k8s/overlays/local/postgresql/
├── kustomization.yaml
└── ingressroute-tcp.yaml
```

## Environment-Specific Configurations

### Local Environment (kubeadm)

**Access Pattern**: hostPort + Traefik
- HTTP: Port 80 (redirects to HTTPS)
- HTTPS: Port 443
- PostgreSQL: Port 31432
- Redis: Port 31379
- Traefik Dashboard: Port 31080

**Service Configuration**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: traefik-local
spec:
  type: NodePort
  ports:
    - name: web
      port: 80
      nodePort: 30180
      targetPort: web
    - name: websecure
      port: 443
      nodePort: 30543
      targetPort: websecure
    - name: postgres
      port: 5432
      nodePort: 31432
      targetPort: postgres
    - name: redis
      port: 6379
      nodePort: 31379
      targetPort: redis
```

**Testing Local Routing**:
```bash
# HTTP service test
curl -k -H "Host: app.blocksecops.local" https://127.0.0.1/api/v1/health/live

# From inside cluster
kubectl exec -n <namespace> <pod> -- \
  wget -qO- --header="Host: api.local.example.com" \
  http://traefik.traefik-local.svc.cluster.local/

# TCP service test
kubectl exec -n <namespace> <pod> -- \
  nc -zv traefik.traefik-local.svc.cluster.local 5432
```

### Staging/Production Environments

**Access Pattern**: LoadBalancer or External DNS
- Use cloud provider LoadBalancer
- Configure external-dns for automatic DNS management
- Enable TLS with cert-manager

## RBAC Requirements

Traefik requires cluster-wide permissions to discover and route to services:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: traefik-clusterrole
rules:
- apiGroups: [""]
  resources: [services, endpoints, secrets, configmaps, nodes, pods]
  verbs: [get, list, watch]
- apiGroups: [discovery.k8s.io]
  resources: [endpointslices]
  verbs: [get, list, watch]
- apiGroups: [networking.k8s.io]
  resources: [ingresses, ingressclasses]
  verbs: [get, list, watch]
- apiGroups: [networking.k8s.io]
  resources: [ingresses/status]
  verbs: [update]
- apiGroups: [traefik.io, traefik.containo.us]
  resources: [middlewares, ingressroutes, traefikservices, ingressroutetcps, ingressrouteudps, tlsoptions, tlsstores, serverstransports]
  verbs: [get, list, watch]
```

## Best Practices

### 1. Use Proper Labels

Always include standard Kubernetes labels:

```yaml
labels:
  app.kubernetes.io/name: <service-name>
  app.kubernetes.io/instance: <environment>-<service>
  app.kubernetes.io/component: <component-type>
  app.kubernetes.io/part-of: <application-name>
  environment: <local|staging|production>
```

### 2. Namespace Isolation

- Each service gets its own namespace
- Use `allowCrossNamespace: true` for Traefik to route between namespaces
- Apply NetworkPolicies to restrict traffic

### 3. Middleware Organization

- Create separate middleware files for each concern (CORS, headers, rate limiting)
- Reuse common middlewares across services
- Use descriptive names: `<service>-<purpose>` (e.g., `api-service-cors`)

### 4. Security

- Enable TLS for production environments
- Use cert-manager for automatic certificate management
- Implement rate limiting for public-facing APIs
- Apply security headers middleware
- Restrict CORS origins in production (don't use `"*"`)

### 5. Monitoring

- Enable Prometheus metrics (entryPoint: metrics)
- Monitor Traefik dashboard for routing status
- Set up alerts for routing failures
- Track request latency and error rates

## Testing Traefik Routing

### Verify IngressRoute Creation

```bash
kubectl get ingressroute -n <namespace>
kubectl describe ingressroute <name> -n <namespace>
```

### Test HTTP Routing from Inside Cluster

```bash
kubectl exec -n traefik-local deployment/traefik -- \
  wget -qO- --header="Host: example.com" http://localhost:80/
```

### Test TCP Routing

```bash
kubectl exec -n <namespace> <pod> -- \
  nc -zv traefik.traefik-local.svc.cluster.local <port>
```

### Check Traefik Logs

```bash
kubectl logs -n traefik-local deployment/traefik --tail=100
```

## WebSocket Routing

WebSocket connections require special handling in Traefik to ensure proper routing and connection upgrades.

### WebSocket IngressRoute Pattern

WebSocket traffic should be routed to a dedicated IngressRoute with higher priority to ensure it takes precedence over other routes.

**Key Configuration Points:**
- Use `PathPrefix(\`/ws\`)` to match WebSocket paths
- Set `priority: 100` to ensure WebSocket route is evaluated before other routes
- Exclude `/ws` path from other IngressRoutes using `!PathPrefix(\`/ws\`)`

### Local Environment (HTTP)

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: notification-websocket
  namespace: notification-local
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`app.blocksecops.local`) && PathPrefix(`/ws`)
      kind: Rule
      priority: 100
      services:
        - name: notification
          port: 8003
```

### Server Environment (HTTP with hostPort)

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: notification-websocket
  namespace: notification-local
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`app.blocksecops.local`) && PathPrefix(`/ws`)
      kind: Rule
      priority: 100
      services:
        - name: notification
          port: 8003
```

### Server Environment (HTTPS with self-signed/default cert)

For the server environment (kubeadm), use `tls: {}` to enable HTTPS with Traefik's default certificate:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: <service>-ingressroute-server
  namespace: <service>-local
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`<domain>.blocksecops.local`) && PathPrefix(`/api/v1`)
      kind: Rule
      services:
        - name: api-service
          namespace: api-service-local
          port: 8000
    - match: Host(`<domain>.blocksecops.local`) && !PathPrefix(`/api/v1`)
      kind: Rule
      services:
        - name: <service>
          port: 3000
      middlewares:
        - name: <service>-security-headers
          namespace: <service>-local
  tls: {}
```

**Note:** `tls: {}` uses Traefik's default self-signed certificate. For production, use `certResolver` instead.

### Production Environment (HTTPS with Let's Encrypt)

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: notification-websocket
  namespace: notification-prod
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.blocksecops.com`) && PathPrefix(`/ws`)
      kind: Rule
      services:
        - name: notification
          port: 8003
  tls:
    certResolver: letsencrypt-prod
```

### Excluding WebSocket from Other Routes

When adding a WebSocket route, update existing IngressRoutes to exclude the `/ws` path:

```yaml
# Dashboard IngressRoute - Exclude /ws
spec:
  routes:
    - match: Host(`app.blocksecops.local`) && !PathPrefix(`/ws`) && !PathPrefix(`/api/v1`)
      kind: Rule
      services:
        - name: dashboard
          port: 3000
```

### Testing WebSocket Routing

**Test WebSocket upgrade through Traefik:**
```bash
# Test WebSocket upgrade returns 101 Switching Protocols
curl -s -o /dev/null -w "%{http_code}" \
  -H "Host: app.blocksecops.local" \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  http://127.0.0.1/ws

# Expected: 101
```

### WebSocket Client Configuration

Frontend applications should connect to WebSocket through Traefik, not directly to the service port:

| Environment | WebSocket URL |
|-------------|---------------|
| Local (kubeadm) | `wss://app.blocksecops.local/ws` |
| Server (kubeadm) | `wss://app.blocksecops.local/ws` |
| Production (GCP) | `wss://app.blocksecops.com/ws` |

**Note:** Use `wss://` for all server/staging/production environments. `ws://localhost` is acceptable only for pure local development where traffic stays on the machine.

**IMPORTANT:** Never use direct port access (e.g., `ws://127.0.0.1:8003/ws`) in production or server environments. Always route through the ingress controller.

---

## Migration from Nginx Ingress

### Migration Timeline

- **Q4 2025**: New services must use Traefik
- **Q1 2026**: Migrate all existing services
- **Q2 2026**: Remove Nginx Ingress Controller

### Migration Checklist

- [ ] Create IngressRoute/IngressRouteTCP equivalent
- [ ] Create Middleware for CORS/headers
- [ ] Test routing from inside cluster
- [ ] Test routing from external access
- [ ] Verify logs and metrics
- [ ] Update documentation
- [ ] Remove old nginx Ingress resource
- [ ] Update application configuration if needed

### Common Migration Patterns

| Nginx Feature | Traefik Equivalent |
|--------------|-------------------|
| `nginx.ingress.kubernetes.io/cors-*` annotations | CORS Middleware |
| `nginx.ingress.kubernetes.io/rewrite-target` | IngressRoute path matching |
| `nginx.ingress.kubernetes.io/backend-protocol: "TCP"` | IngressRouteTCP |
| `nginx.ingress.kubernetes.io/ssl-redirect` | TLS configuration |

## Troubleshooting

### IngressRoute Not Working

1. Check IngressRoute exists: `kubectl get ingressroute -n <namespace>`
2. Check service exists: `kubectl get svc -n <namespace>`
3. Check Traefik logs: `kubectl logs -n traefik-local deployment/traefik`
4. Verify RBAC permissions
5. Test from inside cluster first

### TCP Routing Issues

1. Verify entryPoint is configured in Traefik configmap
2. Check IngressRouteTCP uses correct entryPoint
3. Test with `nc -zv` from inside cluster
4. Verify service port matches IngressRouteTCP

### CORS Issues

1. Check middleware is applied to route
2. Verify middleware namespace matches IngressRoute reference
3. Test with browser dev tools network tab
4. Check `Access-Control-*` headers in response

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Traefik Kubernetes CRD](https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/)
- [Kustomize Structure Template](../architecture-templates/kubernetes-kustomize-structure-template.md)
- [Local Development Setup](./local-development-setup.md)
