# Domain Management Standards

**Version:** 2.1.0
**Last Updated:** February 27, 2026
**Status:** Active

## Overview

This document defines the domain configuration strategy for Apogee across environments.

| Environment | Domain | TLS | Purpose |
|-------------|--------|-----|---------|
| **Server (kubeadm)** | `app.0xapogee.local` | Self-signed (cert-manager + local CA) | Pre-production testing on PowerEdge R720 |
| **Production (GCP)** | `app.0xapogee.com` | Let's Encrypt (cert-manager) | Production deployment |

---

## Source of Truth

### Platform URL Configuration

The platform URL flows through a single chain of trust:

```
config.py defaults (production)     →  app.0xapogee.com (used when no ConfigMap)
        ↓ overridden by
ConfigMap per environment            →  app.0xapogee.local (local overlay)
        ↓ read by
Base deployment (env var mappings)   →  CORS_ORIGINS, ALLOWED_HOSTS, DASHBOARD_BASE_URL
        ↓ injected into
Application (pydantic-settings)      →  Settings.cors_origins, .allowed_hosts, .dashboard_base_url
```

| Layer | File | Role |
|-------|------|------|
| **Application defaults** | `api-service/src/infrastructure/config.py` | Production-first defaults (`app.0xapogee.com`) |
| **Env var mappings** | `api-service/k8s/base/api-service/deployment.yaml` | Maps ConfigMap keys → env vars (single source of truth for all environments) |
| **Environment values** | `api-service/k8s/overlays/local/api-service/configmap-patch.yaml` | Per-environment overrides (`app.0xapogee.local`) |
| **Ingress routing** | `gcp-infrastructure/k8s/overlays/local/*/ingressroute.yaml` | Traefik Host rules + TLS |
| **Ingress CORS** | `gcp-infrastructure/k8s/overlays/local/*/middleware-cors.yaml` | Traefik CORS allowed origins |
| **Supabase** | Supabase Dashboard → Authentication → URL Configuration | Email verification redirect URL (external) |

### Key Principles

1. **Production is the default** — `config.py` defaults target `app.0xapogee.com`. No ConfigMap needed for production.
2. **ConfigMap is the local override** — The local overlay ConfigMap sets `app.0xapogee.local` values.
3. **Base deployment owns env mappings** — All env var → ConfigMap mappings live in the base deployment, never in overlay patches.
4. **No hardcoded URLs in overlays** — Overlay deployment patches must not contain hardcoded URL values; use `valueFrom.configMapKeyRef` in the base.

### Platform URL Variables

| ConfigMap Key | Env Var | config.py Default | Local Override |
|---------------|---------|-------------------|----------------|
| `cors_origins` | `CORS_ORIGINS` | `https://app.0xapogee.com` | `https://app.0xapogee.local` |
| `allowed_hosts` | `ALLOWED_HOSTS` | `app.0xapogee.com` | `app.0xapogee.local` |
| `dashboard_base_url` | `DASHBOARD_BASE_URL` | `https://app.0xapogee.com` | `https://app.0xapogee.local` |

### Switching from .local to .com

To switch environments, update these locations:

| Location | What to Change |
|----------|----------------|
| API Service ConfigMap | `cors_origins`, `allowed_hosts`, `dashboard_base_url` |
| Traefik IngressRoutes | Host match rules |
| Traefik CORS Middlewares | `accessControlAllowOriginList` |
| Traefik TLS Certificates | `dnsNames` in Certificate resource |
| Supabase Dashboard | Site URL + Redirect URLs |
| Dashboard Dockerfile | `VITE_WS_URL` build arg (if WebSocket domain differs) |

For production, the API Service ConfigMap entries for `cors_origins`, `allowed_hosts`, and `dashboard_base_url` can be omitted — the `config.py` defaults will be used.

---

## Environment Configuration

### Server (PowerEdge R720)

**Access:** `https://app.0xapogee.local`

**Node IP:** `192.168.86.225`

**TLS:** Self-signed certificate via cert-manager with local CA issuer. HTTP (port 80) redirects to HTTPS (port 443).

| Service | URL |
|---------|-----|
| Dashboard | `https://app.0xapogee.local` |
| API | `https://app.0xapogee.local/api/v1/...` |
| Harbor | `https://harbor.blocksecops.local` |

**DNS Setup (one-time):**

```bash
# On server (required for local API testing and health checks)
echo "127.0.0.1  app.0xapogee.local harbor.blocksecops.local" | sudo tee -a /etc/hosts

# On client machines
echo "192.168.86.225  app.0xapogee.local harbor.blocksecops.local" | sudo tee -a /etc/hosts
```

**Verification:**
```bash
# From server (use -k for self-signed cert)
curl -k https://app.0xapogee.local/api/v1/health/live

# From client machine
curl -k https://app.0xapogee.local/api/v1/health/live
```

**Key Files:**

| Repository | File | Purpose |
|------------|------|---------|
| blocksecops-api-service | `k8s/overlays/local/api-service/configmap-patch.yaml` | CORS, allowed hosts, dashboard URL |
| blocksecops-api-service | `k8s/base/api-service/deployment.yaml` | Env var mappings (source of truth) |
| blocksecops-gcp-infrastructure | `k8s/overlays/local/api-service/ingressroute.yaml` | API routing (`websecure` entrypoint) |
| blocksecops-gcp-infrastructure | `k8s/overlays/local/dashboard/ingressroute.yaml` | Dashboard routing (`websecure` entrypoint) |
| blocksecops-gcp-infrastructure | `k8s/overlays/local/api-service/middleware-cors.yaml` | Traefik CORS for API |
| blocksecops-gcp-infrastructure | `k8s/overlays/local/dashboard/middleware-cors.yaml` | Traefik CORS for dashboard |
| blocksecops-gcp-infrastructure | `k8s/overlays/local/traefik/certificate.yaml` | TLS cert for `app.0xapogee.local` |
| blocksecops-gcp-infrastructure | `k8s/overlays/local/traefik/tlsstore.yaml` | Default TLS store |
| blocksecops-gcp-infrastructure | `k8s/overlays/local/traefik/redirect-https.yaml` | HTTP → HTTPS redirect |

### Production (GCP)

**Access:** `https://app.0xapogee.com`

**TLS:** Let's Encrypt via cert-manager with `letsencrypt-prod` ClusterIssuer.

| Service | URL |
|---------|-----|
| Dashboard | `https://app.0xapogee.com` |
| API | `https://app.0xapogee.com/api/v1/...` |

**No ConfigMap overrides needed** for `cors_origins`, `allowed_hosts`, or `dashboard_base_url` — the `config.py` production defaults apply automatically.

---

## TLS Architecture

### Server (Self-Signed)

```
cert-manager                     Traefik                        Browser
────────────                     ───────                        ───────
selfsigned-cluster-issuer   →    TLSStore (default cert)   →    Self-signed warning
  ↓                              websecure entrypoint (443)      (accept for testing)
local-ca-issuer             →    IngressRoutes use tls: {}
  ↓
Certificate: app-tls
  secretName: app-tls-secret
  dnsNames: [app.0xapogee.local]
```

### Production (Let's Encrypt)

```
cert-manager                     Traefik                        Browser
────────────                     ───────                        ───────
letsencrypt-prod issuer     →    TLSStore (default cert)   →    Valid certificate
  ↓                              websecure entrypoint (443)
Certificate: blocksecops-tls
  secretName: blocksecops-tls-secret
  dnsNames: [app.0xapogee.com]
```

---

## Supabase Project Settings (External)

Supabase email verification links redirect to the **Site URL** configured in the Supabase Dashboard. This is external to the codebase and must be updated manually when switching environments.

| Setting | Location | Server Value | Production Value |
|---------|----------|-------------|------------------|
| Site URL | Authentication → URL Configuration | `https://app.0xapogee.local` | `https://app.0xapogee.com` |
| Redirect URLs | Authentication → URL Configuration | `https://app.0xapogee.local/**` | `https://app.0xapogee.com/**` |

**How to update:**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → Select project
2. Navigate to **Authentication** → **URL Configuration**
3. Update **Site URL** and **Redirect URLs** to match the target environment

See [Supabase User Creation Pipeline](../pipelines/supabase-user-creation-pipeline.md) for how the redirect URL affects the signup flow.

---

## GCP Migration Checklist

When ready to deploy to GCP with `app.0xapogee.com`:

### Prerequisites

- [ ] GCP project created
- [ ] GKE cluster provisioned
- [ ] DNS A record: `app.0xapogee.com` → GCP Load Balancer IP

### Platform URL Changes

| Component | Action | Notes |
|-----------|--------|-------|
| API Service ConfigMap | Remove `cors_origins`, `allowed_hosts`, `dashboard_base_url` overrides | Production defaults in config.py apply |
| Traefik IngressRoutes | Update Host rules to `app.0xapogee.com` | New production overlay |
| Traefik CORS Middlewares | Update origins to `https://app.0xapogee.com` | New production overlay |
| Traefik TLS Certificate | Use `letsencrypt-prod` issuer, `dnsNames: [app.0xapogee.com]` | Replace self-signed |
| Supabase Dashboard | Update Site URL to `https://app.0xapogee.com` | Manual, external |
| Dashboard build | `VITE_WS_URL=wss://app.0xapogee.com/ws` | Build arg |

### Infrastructure Migration

**Priority 1 - Security:**

| Current State | GCP Target | Action |
|---------------|------------|--------|
| Self-signed TLS certificates | Let's Encrypt via cert-manager | Replace ClusterIssuer |
| Sensitive values in ConfigMaps | GCP Secret Manager | Migrate secrets |

**Priority 2 - Core Infrastructure:**

| Current State | GCP Target | Action |
|---------------|------------|--------|
| Harbor registry (local) | Google Artifact Registry | Migrate container images |
| PostgreSQL (local) | Cloud SQL for PostgreSQL 15.4+ | Migrate `solidity_security` database |

**Priority 3 - Authentication & Observability:**

| Current State | GCP Target | Action |
|---------------|------------|--------|
| Supabase Auth | Keep Supabase | Update Site URL and Redirect URLs |
| Local logging | Cloud Monitoring + Cloud Logging | Integrate for centralized observability |

### Deployment Steps

```bash
# 1. Connect to GKE cluster
gcloud container clusters get-credentials blocksecops-prod --zone us-central1-a

# 2. Apply production overlays (no ConfigMap overrides needed for URLs)
kubectl apply -k k8s/overlays/gcp-production/api-service/
kubectl apply -k k8s/overlays/gcp-production/dashboard/

# 3. Verify TLS certificate
kubectl get certificate -A

# 4. Test HTTPS access
curl https://app.0xapogee.com/api/v1/health/live

# 5. Update Supabase Dashboard Site URL to https://app.0xapogee.com
```

---

## Troubleshooting

### CORS Errors

**Symptom:** Browser console shows "Access-Control-Allow-Origin" errors

**Solution:**
1. Check API service config: `kubectl exec -n api-service-local deployment/api-service -- env | grep CORS`
2. Verify ConfigMap: `kubectl get configmap api-service-config -n api-service-local -o yaml | grep cors`
3. Check Traefik middleware: `kubectl get middleware -n api-service-local -o yaml`
4. Ensure all three match the current domain (including `https://` protocol)

### DNS Not Resolving

**Symptom:** `app.0xapogee.local` doesn't resolve

**Solution:**
1. Verify /etc/hosts entry: `grep blocksecops /etc/hosts`
2. Flush DNS cache: `sudo systemd-resolve --flush-caches`
3. Test with IP directly: `curl -k https://192.168.86.225`

### TLS Certificate Errors

**Symptom:** Browser shows certificate warning or curl fails with SSL error

**Solution:**
1. Check certificate: `kubectl get certificate -n traefik-local`
2. Check secret: `kubectl get secret app-tls-secret -n traefik-local`
3. Use `-k` flag with curl for self-signed certs
4. Import the local CA into browser trust store for persistent trust

---

## Harbor Registry Domain Exception

The container registry domain `harbor.blocksecops.local` is **not** part of the application domain rebrand. Harbor has its own TLS certificate, IngressRoute, and DNS entry. Changing this domain requires coordinated infrastructure migration:

1. Issue new TLS certificate for `harbor.blocksecops.local`
2. Update Harbor IngressRoute Host rules
3. Update DNS entries on all nodes and clients
4. Re-trust the new registry on all kubelet nodes
5. Update all kustomization `newName` image references

Until this migration is completed, all `kustomization.yaml` files use `harbor.blocksecops.local/blocksecops/` as the image registry prefix.

**Regression tests** use negative lookbehind regex `(?<!harbor\.)blocksecops\.local` to correctly exclude harbor references from legacy domain checks. See [Feature Test 82](../feature-tests/82-cors-domain-regression.md).

---

## Security Considerations

### All Environments

1. **Always use HTTPS** — Both server and production use TLS
2. **Restrict CORS origins** — Only allow the specific domain, never use `*`
3. **Single origin per environment** — One domain in CORS, not multiple
4. **Credentials disabled** — Traefik CORS middleware sets `accessControlAllowCredentials: false`

### Production Requirements

1. **Valid TLS certificates** — Let's Encrypt, not self-signed
2. **HSTS headers** — Force HTTPS with Strict-Transport-Security
3. **CSP headers** — Configure Content-Security-Policy for frontend

---

**See Also:**
- [Service Availability](./service-availability.md) - Always-available access patterns
- [Kustomize Standards](./kustomize-standards.md) - Base/overlay patterns
- [Supabase User Creation Pipeline](../pipelines/supabase-user-creation-pipeline.md) - Signup redirect flow
- [Core Development Rules](./core-development-rules.md) - Development workflow

---

*Last Updated: February 27, 2026*
