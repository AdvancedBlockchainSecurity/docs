# Admin Portal v0.3.1 - HTTPS IngressRoute Fix

## Version 0.3.1 - February 6, 2026

**Date:** 2026-02-06
**Component:** blocksecops-admin-portal (0.3.0 -> 0.3.1)
**Type:** Bug Fix / Infrastructure
**Priority:** High
**Status:** Complete

### Summary

Added the missing HTTPS (`websecure`) IngressRoute for the admin portal. Without this, the entire admin portal was unreachable over HTTPS (port 443) on the server environment where traffic arrives via TLS. This was the root cause of "Stale Scans not showing" - the admin portal pages, API proxy, and scan monitoring were all inaccessible over HTTPS.

### Issues Resolved

1. **Admin portal unreachable over HTTPS** - No `websecure` entryPoint IngressRoute existed; only the `web` (HTTP) IngressRoute was configured
2. **"Stale Scans not showing"** - The scan monitoring page at `https://admin.0xapogee.local/scan-monitoring` returned 404 because the entire admin portal had no HTTPS route
3. **API proxy broken over HTTPS** - `https://admin.0xapogee.local/api/v1/*` requests to api-service also failed

### Added

- **`ingressroute-server.yaml`** - New HTTPS IngressRoute for admin portal:
  - `entryPoints: [websecure]`
  - Route 1: `Host(admin.0xapogee.local) && PathPrefix(/api/v1)` -> `api-service:8000` in `api-service-local`
  - Route 2: `Host(admin.0xapogee.local) && !PathPrefix(/api/v1)` -> `admin-portal:3000` with `admin-security-headers` middleware
  - `tls: {}` (uses Traefik default certificate)

### Changed

- Version bump: `0.3.0` to `0.3.1` (PATCH - infrastructure fix)
- `kustomization.yaml`: Added `ingressroute-server.yaml` to resources, updated `newTag` and `app.kubernetes.io/version`

### Code Changes

**New Files:**
- `k8s/overlays/local/ingressroute-server.yaml` - HTTPS IngressRoute (29 lines)

**Files Modified:**
- `k8s/overlays/local/kustomization.yaml` - Added resource reference, version bumps
- `package.json` (line 3) - Version `0.3.0` -> `0.3.1`

**New IngressRoute:**
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: admin-portal-ingressroute-server
  namespace: admin-portal-local
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`admin.0xapogee.local`) && PathPrefix(`/api/v1`)
      kind: Rule
      services:
        - name: api-service
          namespace: api-service-local
          port: 8000
    - match: Host(`admin.0xapogee.local`) && !PathPrefix(`/api/v1`)
      kind: Rule
      services:
        - name: admin-portal
          port: 3000
      middlewares:
        - name: admin-security-headers
          namespace: admin-portal-local
  tls: {}
```

### Testing

**Verification Results:**
- `curl -sk https://admin.0xapogee.local/` - **200** (was 404)
- `curl -sk https://admin.0xapogee.local/scan-monitoring` - **200** (was 404)
- `curl -sk https://admin.0xapogee.local/api/v1/health/live` - Returns API health JSON
- HTTP route (`web` entryPoint) continues working unchanged

### Impact

- **User Impact:** Admin portal fully accessible over HTTPS - scan monitoring, customer management, and all admin pages now load correctly
- **Root Cause Resolution:** "Stale Scans not showing" smoke test failure is resolved
- **Breaking Changes:** None
- **Pattern:** Follows existing `api-service-server` and `dashboard-server` IngressRoute pattern (websecure entryPoint + tls: {})

### Deployment

```bash
cd /home/pwner/Git/blocksecops-admin-portal

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
  -t harbor.0xapogee.local/blocksecops/admin-portal:0.3.1 .

docker push harbor.0xapogee.local/blocksecops/admin-portal:0.3.1
kubectl apply -k k8s/overlays/local/
kubectl rollout restart deploy/admin-portal -n admin-portal-local
```

### Related Documentation

- [Ingress Networking Standards](../standards/ingress-networking.md) - Updated with server HTTPS pattern
- [Admin Portal v0.3.0 Changelog](ADMIN-PORTAL-V0.3.0-2026-02-06.md) - Previous version (P12 TLS comment)
- [API Service v0.27.5 Changelog](API-SERVICE-V0.27.5-SECURITY-FIXES-2026-02-06.md) - Companion fix

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.3.1 | 2026-02-06 | HTTPS IngressRoute fix |
| 0.3.0 | 2026-02-06 | New pages, export, MFA, session tracking, UX overhaul |
| 0.2.0 | 2026-02-05 | ML Models page, retrain functionality |

---

**Maintained By:** Apogee Team
**Status:** Complete
