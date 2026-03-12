# IngressRoute Stale Domain Fix

**Date:** 2026-02-28
**Type:** Configuration Fix
**Status:** Complete
**Severity:** Medium

## Summary

4 IngressRoutes in the local cluster retained old `blocksecops.local` domains after the Phase 1/2 Apogee rebrand. Source YAML files were correctly updated but `kubectl apply -k` was not run for all kustomization paths. Additionally, 3 production overlays still referenced `0xApogee.com`.

## Root Cause

Incomplete `kubectl apply -k` coverage during Phase 1/2 deployment. Some services have multiple kustomization paths (e.g., notification has both `k8s/overlays/local/kustomization.yaml` and `k8s/overlays/local/notification/kustomization.yaml`). Only one path was applied per service.

## Affected IngressRoutes (Local)

| IngressRoute | Old Domain | New Domain |
|---|---|---|
| `notification-local/notification-websocket` | `app.0xapogee.com` | `app.0xapogee.com` |
| `admin-portal-local/admin-portal-ingressroute` | `admin.0xapogee.com` | `admin.0xapogee.com` |
| `admin-portal-local/admin-portal-ingressroute-server` | `admin.0xapogee.com` | `admin.0xapogee.com` |
| `traefik-local/app-http-redirect` | `app.0xapogee.com` | `app.0xapogee.com` |

## Affected Production Overlays

| Repo | File | Change |
|---|---|---|
| blocksecops-admin-portal | `k8s/overlays/production/ingress.yaml` | Host, CSP connect-src |
| blocksecops-admin-portal | `k8s/overlays/production/kustomization.yaml` | Build arg comments, registry |
| blocksecops-dashboard | `k8s/overlays/production/ingressroute.yaml` | Host |
| blocksecops-dashboard | `k8s/overlays/production/configmap-patch.yaml` | API/WS URLs |
| blocksecops-dashboard | `k8s/overlays/production/middleware-security-headers.yaml` | CSP connect-src |
| blocksecops-api-service | `k8s/overlays/production/api-service/configmap-patch.yaml` | CORS, hosts, dashboard URL |

## Fix Applied

1. `kubectl apply -k` for notification, admin-portal, and traefik overlays
2. Updated production overlay files with `0xApogee.com` domains
3. Committed changes to all 3 repos

## Impact

- Admin portal was only reachable via legacy `admin.0xapogee.com` (still in `/etc/hosts`)
- WebSocket secondary IngressRoute was stale but primary route covered `/ws` — no functional impact
- HTTP→HTTPS redirect only triggered for old domain — no functional impact (HTTPS used directly)
- Production overlays not yet deployed — no production impact

## Prevention

- Run `kubectl diff -k` for every kustomization path after source changes
- Include IngressRoute domain verification in smoke test
- Track IngressRoutes as first-class deployment artifacts
