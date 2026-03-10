# Domain Management Standards

**Version:** 3.0.0
**Last Updated:** March 10, 2026
**Status:** Active

## Overview

This document defines the domain configuration strategy for Apogee across environments.

| Environment | Domain | TLS | Purpose |
|-------------|--------|-----|---------|
| Development | Configured per environment | Self-signed or managed | Pre-production testing |
| Production | `app.0xapogee.com` | Google-managed (Certificate Manager) | Production dashboard + API |
| Production | `admin.0xapogee.com` | Google-managed (Certificate Manager) | Production admin portal |

---

## Source of Truth

### Platform URL Configuration

The platform URL flows through a single chain of trust:

```
config.py defaults (production)     →  app.0xapogee.com (used when no ConfigMap)
        ↓ overridden by
ConfigMap per environment            →  <env-domain> (environment overlay)
        ↓ read by
Base deployment (env var mappings)   →  CORS_ORIGINS, ALLOWED_HOSTS, DASHBOARD_BASE_URL
        ↓ injected into
Application (pydantic-settings)      →  Settings.cors_origins, .allowed_hosts, .dashboard_base_url
```

| Layer | File | Role |
|-------|------|------|
| **Application defaults** | `api-service/src/infrastructure/config.py` | Production-first defaults (`app.0xapogee.com`) |
| **Env var mappings** | `api-service/k8s/base/api-service/deployment.yaml` | Maps ConfigMap keys → env vars (single source of truth for all environments) |
| **Environment values** | `api-service/k8s/overlays/<env>/api-service/configmap-patch.yaml` | Per-environment overrides (`<env-domain>`) |
| **Ingress routing** | `gcp-infrastructure/k8s/overlays/<env>/*/ingressroute.yaml` | Traefik Host rules + TLS |
| **Ingress CORS** | `gcp-infrastructure/k8s/overlays/<env>/*/middleware-cors.yaml` | Traefik CORS allowed origins |
| **Supabase** | Supabase Dashboard → Authentication → URL Configuration | Email verification redirect URL (external) |

### Key Principles

1. **Production is the default** — `config.py` defaults target `app.0xapogee.com`. No ConfigMap needed for production.
2. **ConfigMap is the environment override** — The environment overlay ConfigMap sets environment-specific domain values.
3. **Base deployment owns env mappings** — All env var → ConfigMap mappings live in the base deployment, never in overlay patches.
4. **No hardcoded URLs in overlays** — Overlay deployment patches must not contain hardcoded URL values; use `valueFrom.configMapKeyRef` in the base.

### Platform URL Variables

| ConfigMap Key | Env Var | config.py Default | Environment Override |
|---------------|---------|-------------------|----------------------|
| `cors_origins` | `CORS_ORIGINS` | `https://app.0xapogee.com` | `https://<env-domain>` |
| `allowed_hosts` | `ALLOWED_HOSTS` | `app.0xapogee.com` | `<env-domain>` |
| `dashboard_base_url` | `DASHBOARD_BASE_URL` | `https://app.0xapogee.com` | `https://<env-domain>` |

### Switching Between Environments

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

> **Note:** Historical environment details (PowerEdge R720 server configuration) moved to `changelogs/STANDARDS-AGNOSTIC-MIGRATION-2026-03-10.md`.

### Production (GCP)

**Access:** `https://app.0xapogee.com`

**TLS:** Google-managed certificates via Certificate Manager. Cloudflare proxy (Full Strict SSL).

| Service | URL |
|---------|-----|
| Dashboard | `https://app.0xapogee.com` |
| Admin Portal | `https://admin.0xapogee.com` |
| API | `https://app.0xapogee.com/api/v1/...` |

**No ConfigMap overrides needed** for `cors_origins`, `allowed_hosts`, or `dashboard_base_url` — the `config.py` production defaults apply automatically.

---

## TLS Architecture

Development environments use cert-manager with self-signed CA. Production uses managed certificates.

### Production (GCP)

```
Cloudflare                    GKE Gateway API               Browser
──────────                    ───────────────               ───────
Edge TLS termination     →    Certificate Manager      →    Valid certificate
  ↓                           (Google-managed certs)
Full (Strict) SSL mode        Gateway: gke-l7-global-external-managed
  ↓                           Cert Map: apogee-cert-map
Proxied A record         →    Static IP: 34.149.16.104
                              Domains: app.0xapogee.com, admin.0xapogee.com
```

Internal database TLS uses cert-manager self-signed CA (same as development environments).

---

## Supabase Project Settings (External)

Supabase email verification links redirect to the **Site URL** configured in the Supabase Dashboard. This is external to the codebase and must be updated manually when switching environments.

| Setting | Location | Development Value | Production Value |
|---------|----------|-------------------|------------------|
| Site URL | Authentication → URL Configuration | `https://<env-domain>` | `https://app.0xapogee.com` |
| Redirect URLs | Authentication → URL Configuration | `https://<env-domain>/**` | `https://app.0xapogee.com/**` |

**How to update:**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → Select project
2. Navigate to **Authentication** → **URL Configuration**
3. Update **Site URL** and **Redirect URLs** to match the target environment

See [Supabase User Creation Pipeline](../pipelines/supabase-user-creation-pipeline.md) for how the redirect URL affects the signup flow.

---

## Troubleshooting

### CORS Errors

**Symptom:** Browser console shows "Access-Control-Allow-Origin" errors

**Solution:**
1. Check API service config: `kubectl exec -n <service-namespace> deployment/api-service -- env | grep CORS`
2. Verify ConfigMap: `kubectl get configmap api-service-config -n <service-namespace> -o yaml | grep cors`
3. Check Traefik middleware: `kubectl get middleware -n <service-namespace> -o yaml`
4. Ensure all three match the current domain (including `https://` protocol)

### DNS Not Resolving

**Symptom:** Environment domain doesn't resolve

**Solution:**
1. Verify DNS configuration (e.g., /etc/hosts for development, DNS records for production)
2. Flush DNS cache: `sudo systemd-resolve --flush-caches`
3. Test with IP directly: `curl -k https://<node-ip>`

### TLS Certificate Errors

**Symptom:** Browser shows certificate warning or curl fails with SSL error

**Solution:**
1. Check certificate: `kubectl get certificate -n <ingress-namespace>`
2. Check secret: `kubectl get secret <tls-secret-name> -n <ingress-namespace>`
3. Use `-k` flag with curl for self-signed certs in development environments
4. Import the local CA into browser trust store for persistent trust

---

## Security Considerations

### All Environments

1. **Always use HTTPS** — Both development and production use TLS
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

*Last Updated: March 10, 2026*
