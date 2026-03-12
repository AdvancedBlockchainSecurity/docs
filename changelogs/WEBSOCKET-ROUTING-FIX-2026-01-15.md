# WebSocket Routing and Scanner Effectiveness Fix

**Date:** January 15, 2026
**Author:** Apogee Team
**Services Affected:** dashboard, notification, api-service, gcp-infrastructure

## Summary

Fixed WebSocket connectivity for real-time notifications by routing WebSocket traffic through Traefik instead of direct port access. Also fixed a KeyError bug in the scanner-effectiveness analytics endpoint.

## Changes

### 1. WebSocket Routing Through Traefik

**Problem:** Dashboard was trying to connect to `ws://127.0.0.1:8003/ws` directly instead of routing through Traefik at `ws://app.0xapogee.com/ws`. This caused WebSocket connection failures and the dashboard showing "Offline" status.

**Solution:**
- Created IngressRoute for WebSocket traffic at `/ws` path
- Updated dashboard IngressRoute to exclude `/ws` path
- Updated dashboard Dockerfile default VITE_WS_URL

**Files Modified:**

| Repository | File | Change |
|------------|------|--------|
| blocksecops-notification | `k8s/overlays/local/ingressroute-ws.yaml` | NEW - WebSocket IngressRoute for local |
| blocksecops-notification | `k8s/overlays/local/kustomization.yaml` | Added ingressroute-ws.yaml resource |
| blocksecops-notification | `k8s/overlays/production/ingressroute-ws.yaml` | NEW - WebSocket IngressRoute for production |
| blocksecops-notification | `k8s/overlays/production/kustomization.yaml` | Added ingressroute-ws.yaml resource |
| blocksecops-dashboard | `Dockerfile` | Changed default VITE_WS_URL from `ws://127.0.0.1:8003/ws` to `ws://app.0xapogee.com/ws` |
| blocksecops-dashboard | `k8s/overlays/local/configmap-patch.yaml` | Updated ws_url to `ws://app.0xapogee.com/ws` |
| blocksecops-gcp-infrastructure | `k8s/overlays/server/dashboard/ingressroute.yaml` | Added `!PathPrefix(/ws)` to exclude WebSocket from dashboard route |

### 2. Scanner Effectiveness KeyError Fix

**Problem:** The `/api/v1/analytics/scanner-effectiveness` endpoint was returning 500 error due to a KeyError. Some vulnerability records had scanner_ids (like `state-change-without-event`) that weren't in the VALID_SCANNER_IDS list.

**Solution:** Added check to only count scanner_ids that are in the valid scanner list.

**File Modified:**
- `blocksecops-api-service/src/presentation/api/v1/endpoints/analytics.py` (line 780-783)

**Code Change:**
```python
# Before
for fp, scanners in all_fingerprints.items():
    if len(scanners) == 1:
        scanner_id = list(scanners)[0]
        unique_by_scanner[scanner_id] += 1
        total_unique += 1

# After
for fp, scanners in all_fingerprints.items():
    if len(scanners) == 1:
        scanner_id = list(scanners)[0]
        # Only count if scanner_id is in our valid scanner list
        if scanner_id in unique_by_scanner:
            unique_by_scanner[scanner_id] += 1
            total_unique += 1
```

## WebSocket IngressRoute Configuration

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
    - match: Host(`app.0xapogee.com`) && PathPrefix(`/ws`)
      kind: Rule
      priority: 100
      services:
        - name: notification
          port: 8003
```

### Production Environment (HTTPS)

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
    - match: Host(`app.0xapogee.com`) && PathPrefix(`/ws`)
      kind: Rule
      services:
        - name: notification
          port: 8003
  tls:
    certResolver: letsencrypt-prod
```

## Testing

### WebSocket Connection Test

```bash
# Test WebSocket upgrade through Traefik
curl -s -o /dev/null -w "%{http_code}" \
  -H "Host: app.0xapogee.com" \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  http://127.0.0.1/ws

# Expected: 101 (Switching Protocols)
```

### Scanner Effectiveness Test

```bash
# Test endpoint returns 200 (with valid auth)
curl -s -o /dev/null -w "%{http_code}" \
  -H "Host: app.0xapogee.com" \
  -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1/api/v1/analytics/scanner-effectiveness?time_range=all_time"

# Expected: 200
```

## Deployment Notes

1. **Dashboard Image Rebuild Required:** The dashboard image must be rebuilt with the new Dockerfile default for VITE_WS_URL. Build args for VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are still required.

2. **API Service Rebuild Required:** The API service image must be rebuilt after the scanner-effectiveness fix.

3. **Image Import:** For kubeadm environments, images must be imported to containerd:
   ```bash
   sudo docker save <image>:<tag> | sudo ctr -n k8s.io images import -
   ```

## Rollback Plan

If issues arise:

1. **WebSocket:** Revert IngressRoute changes and update VITE_WS_URL back to direct port access
2. **Scanner Effectiveness:** The fix is additive and safe; no rollback needed

## Verification Checklist

- [x] WebSocket upgrade returns 101 through Traefik
- [x] Dashboard shows "Online" status
- [x] Scanner effectiveness page loads without error
- [x] SolidityDefend appears in scanner list
- [x] All scanners with findings are displayed
