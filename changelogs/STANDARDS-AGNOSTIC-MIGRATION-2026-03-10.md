# Standards Infrastructure-Agnostic Migration

**Date:** 2026-03-10
**Type:** Documentation Restructuring
**Status:** Complete

## Summary

Restructured platform development standards to be infrastructure-agnostic. Standards now define the **what** (rules, patterns, requirements) without coupling to a specific cluster (local kubeadm, GCP GKE, or future environments). Environment-specific operational details have been moved to this changelog for historical reference.

---

## Moved Content: Database Corruption Incident (October 16, 2025)

**Original Location:** `docs/standards/database-management.md`

### What Happened

On October 16, 2025, a simple CORS configuration change resulted in complete loss of the local development database:

1. **Initial Change:** Updated CORS configuration in `configmap-patch.yaml` to prioritize `127.0.0.1`
2. **Applied Change:** Ran `kubectl apply -k k8s/overlays/local/api-service`
3. **Unintended Effect:** Kustomize also created/updated an ExternalSecret, changing database credentials
4. **First Problem:** API service couldn't authenticate to PostgreSQL (wrong password)
5. **Troubleshooting:** Multiple PostgreSQL restarts while attempting to fix authentication
6. **Second Problem:** Discovered PostgreSQL required SSL connections (from Sprint 14 Security Hardening)
7. **Attempted Fix:** Created local overlay to disable SSL for development
8. **Critical Failure:** PostgreSQL `pg_authid` file corrupted during multiple restarts
9. **Data Loss:** Database files intact but no users/roles exist - authentication system destroyed
10. **No Recovery:** No backups available - 10 days of development data lost permanently

### Root Causes

1. No backups — No automated or manual backups of local development database
2. Dangerous changes — Applied configuration changes to running database without safety net
3. Incomplete understanding — Didn't realize ExternalSecret would be created
4. Multiple restarts — Restarted PostgreSQL multiple times during troubleshooting
5. No verification — Didn't verify backup before making changes

### Lessons Learned

1. ALWAYS create backups before any database-related changes
2. Test configuration changes in isolation before applying to running systems
3. Understand cascading effects of Kustomize and other tools
4. Minimize restarts during troubleshooting — each restart increases corruption risk
5. Verify assumptions — Don't assume local environment is safe to break

---

## Moved Content: GCP Migration Checklist (Domain Management)

**Original Location:** `docs/standards/domain-management.md`

### Prerequisites

- [x] GCP project created
- [x] GKE cluster provisioned
- [x] DNS A record: `app.0xapogee.com` → GCP Load Balancer IP
- [x] DNS A record: `admin.0xapogee.com` → GCP Load Balancer IP

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
| Self-signed TLS certificates | Google-managed via Certificate Manager | Terraform-managed |
| Sensitive values in ConfigMaps | GCP Secret Manager | Migrate secrets |

**Priority 2 - Core Infrastructure:**

| Current State | GCP Target | Action |
|---------------|------------|--------|
| Harbor registry (local) | Google Artifact Registry | Migrate container images |
| PostgreSQL (local) | Self-hosted on GKE (pgvector StatefulSet) | Migrate `solidity_security` database |

**Priority 3 - Authentication & Observability:**

| Current State | GCP Target | Action |
|---------------|------------|--------|
| Supabase Auth | Keep Supabase | Update Site URL and Redirect URLs |
| Local logging | Cloud Monitoring + Cloud Logging | Integrate for centralized observability |

---

## Moved Content: Harbor Registry Domain Exception

**Original Location:** `docs/standards/domain-management.md`

The container registry domain `harbor.blocksecops.local` was **not** part of the application domain rebrand. Harbor had its own TLS certificate, IngressRoute, and DNS entry. This was specific to the local kubeadm environment and is no longer relevant after the GCP migration.

Until the GCP migration was completed, all `kustomization.yaml` files used `harbor.blocksecops.local/blocksecops/` as the image registry prefix. Post-migration, the registry is `us-west1-docker.pkg.dev/<project>/apogee/`.

Regression tests used negative lookbehind regex `(?<!harbor\.)blocksecops\.local` to correctly exclude harbor references from legacy domain checks. See `docs/feature-tests/82-cors-domain-regression.md`.

---

## Moved Content: Nginx Migration Timeline

**Original Location:** `docs/standards/ingress-networking.md`

### Timeline

- **Q4 2025**: New services must use Traefik
- **Q1 2026**: Migrate all existing services
- **Q2 2026**: Remove Nginx Ingress Controller

### Migration Checklist

- [x] Create IngressRoute/IngressRouteTCP equivalent
- [x] Create Middleware for CORS/headers
- [x] Test routing from inside cluster
- [x] Test routing from external access
- [x] Verify logs and metrics
- [x] Update documentation
- [x] Remove old nginx Ingress resource
- [x] Update application configuration if needed

### Common Migration Patterns

| Nginx Feature | Traefik Equivalent |
|--------------|-------------------|
| `nginx.ingress.kubernetes.io/cors-*` annotations | CORS Middleware |
| `nginx.ingress.kubernetes.io/rewrite-target` | IngressRoute path matching |
| `nginx.ingress.kubernetes.io/backend-protocol: "TCP"` | IngressRouteTCP |
| `nginx.ingress.kubernetes.io/ssl-redirect` | TLS configuration |

---

## Moved Content: CronJob Version Drift Incident (February 2026)

**Original Location:** `docs/standards/kustomize-standards.md`

**Root Cause (February 2026 incident):** During rapid version iteration (30+ bumps in 4 days), `kubectl apply -k` was missed after bumping from 0.29.5 to 0.29.7. The CronJob continued running 0.29.5 for 2 days, producing failed jobs. The Deployment also remained at 0.29.5 but appeared functional after a `kubectl rollout restart`.

---

## Moved Content: Server Environment Configuration (kubeadm)

**Original Location:** `docs/standards/domain-management.md`, `docs/standards/service-availability.md`

### Server (PowerEdge R720)

- **Access:** `https://app.0xapogee.com`
- **Node IP:** `192.168.86.225`
- **TLS:** Self-signed certificate via cert-manager with local CA issuer

**DNS Setup (one-time):**
```bash
# On server
echo "127.0.0.1  app.0xapogee.com harbor.blocksecops.local" | sudo tee -a /etc/hosts

# On client machines
echo "192.168.86.225  app.0xapogee.com harbor.blocksecops.local" | sudo tee -a /etc/hosts
```

### Service Access Matrix (Historical)

| Environment | Method | Access Pattern | One-Time Setup |
|-------------|--------|----------------|----------------|
| **Local (kubeadm)** | hostPort 80/443 + Traefik (TLS) | `https://app.0xapogee.com` | DNS entries |
| **Server (kubeadm)** | hostPort 80/443 + Traefik | `http://app.0xapogee.com` | DNS entries |
| **Production (GCP)** | GKE Gateway + Cloudflare | `https://app.0xapogee.com` | None (managed) |

---

## Moved Content: Smoke Test Environment-Specific Details

**Original Location:** `docs/standards/smoke-test.md`

Historical environment settings for the kubeadm-based server:

| Setting | Value |
|---------|-------|
| **Server access** | `https://app.0xapogee.com` (Traefik with hostPort 80/443) |
| **Admin access** | `http://admin.0xapogee.com` (Traefik hostPort 80) |
| **Cluster type** | kubeadm with containerd |
| **Registry** | Harbor at `harbor.blocksecops.local` |
| **curl flag** | Use `-sk` for HTTPS (self-signed cert) |
