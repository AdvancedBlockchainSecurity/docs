# Dashboard Production Build Tests

Manual testing checklist for dashboard production server and build process.

## Prerequisites

- Minikube running with all services
- Port-forwards active per [port-forwarding.md](/docs/standards/port-forwarding.md)
- `.env.local` file exists in `blocksecops-dashboard/` with valid Supabase credentials

---

## 1. Production Build Process

### 1.1 Environment File Validation
| Test | Expected | Status |
|------|----------|--------|
| [ ] `.env.local` exists | File present in `blocksecops-dashboard/` | |
| [ ] `VITE_SUPABASE_URL` is set | Valid Supabase project URL | |
| [ ] `VITE_SUPABASE_ANON_KEY` is set | Valid Supabase anon key | |
| [ ] `.env.example` exists | Template for new developers | |

### 1.2 Docker Build with Build Args
```bash
# Switch to minikube Docker daemon
eval $(minikube docker-env)

# Source environment variables
cd /Users/pwner/Git/ABS
source blocksecops-dashboard/.env.local

# Build with required build args
docker build --no-cache \
  --build-arg VITE_SUPABASE_URL=$VITE_SUPABASE_URL \
  --build-arg VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY \
  --build-arg VITE_WS_URL=$VITE_WS_URL \
  --build-arg VITE_WS_ENABLED=$VITE_WS_ENABLED \
  -t blocksecops-dashboard:0.19.0 \
  -f blocksecops-dashboard/Dockerfile .
```

| Test | Expected | Status |
|------|----------|--------|
| [ ] Build completes without errors | Exit code 0 | |
| [ ] Build arg validation passes | No "ERROR: VITE_SUPABASE_URL build arg is required" | |
| [ ] Image tagged correctly | `blocksecops-dashboard:0.19.0` visible in `docker images` | |

### 1.3 Build Failure Cases (Negative Tests)
```bash
# Test: Build without VITE_SUPABASE_URL should fail
docker build --no-cache -t test:fail -f blocksecops-dashboard/Dockerfile .
```

| Test | Expected | Status |
|------|----------|--------|
| [ ] Build fails without VITE_SUPABASE_URL | Error message about missing build arg | |
| [ ] Build fails without VITE_SUPABASE_ANON_KEY | Error message about missing build arg | |

---

## 2. Production Server Operation

### 2.1 Static File Serving
| Test | Expected | Status |
|------|----------|--------|
| [ ] Dashboard serves at http://127.0.0.1:3000 | HTML page loads (via Traefik) | |
| [ ] Static assets load correctly | CSS, JS files return 200 | |
| [ ] No "Cannot GET" errors | All routes handled by SPA | |
| [ ] Server is `serve -s dist` (not `npm run dev`) | Check container logs | |

### 2.2 Environment Variables Baked In
```bash
# Check that Supabase URL is baked into the JS bundle
kubectl exec -n dashboard-local deploy/blocksecops-dashboard -- \
  grep -l "supabase" /usr/share/nginx/html/assets/*.js
```

| Test | Expected | Status |
|------|----------|--------|
| [ ] Supabase URL present in JS bundle | URL found in minified JS | |
| [ ] No "Missing Supabase credentials" error | Dashboard loads without credential errors | |
| [ ] Environment variables are NOT in browser `process.env` | Vite bakes them at build time | |

---

## 3. Authentication Flow

### 3.1 Supabase Connection
| Test | Expected | Status |
|------|----------|--------|
| [ ] Login page loads | Email/password form displayed | |
| [ ] Login with valid credentials | Redirects to dashboard | |
| [ ] Auth token stored | Check localStorage for `sb-*` keys | |
| [ ] Protected routes require auth | Redirects to login if not authenticated | |

### 3.2 Session Persistence
| Test | Expected | Status |
|------|----------|--------|
| [ ] Refresh page maintains session | User stays logged in | |
| [ ] Token refresh works | Session continues after token expires | |
| [ ] Logout clears session | All `sb-*` keys removed from localStorage | |

---

## 4. API Integration via Traefik

### 4.1 API Routing
| Test | Expected | Status |
|------|----------|--------|
| [ ] API calls go through Traefik | `http://127.0.0.1:3000/api/v1/*` works | |
| [ ] Health endpoint accessible | `/api/v1/health/live` returns 200 | |
| [ ] Authenticated API calls work | Dashboard can fetch scans, projects | |

### 4.2 CORS Configuration
| Test | Expected | Status |
|------|----------|--------|
| [ ] No CORS errors in browser console | Traefik handles CORS | |
| [ ] Preflight requests succeed | OPTIONS requests return 200 | |

---

## 5. WebSocket Notifications (Optional)

### 5.1 WebSocket Connection
```bash
# Port-forward notification service
kubectl port-forward -n notification-local svc/notification 8003:8003 &
```

| Test | Expected | Status |
|------|----------|--------|
| [ ] WebSocket connects | Browser console shows "Connected to notification service" | |
| [ ] Connection status indicator | Green dot when connected | |
| [ ] Reconnection on disconnect | Auto-reconnects with backoff | |

### 5.2 Real-time Notifications
| Test | Expected | Status |
|------|----------|--------|
| [ ] Scan progress updates | Toast notifications during scan | |
| [ ] Scan completion notification | "Scan complete" toast with results link | |
| [ ] Vulnerability alerts | Alert toasts for critical findings | |

---

## 6. Production vs Development Server

### 6.1 Server Type Verification
```bash
# Check running process in container
kubectl exec -n dashboard-local deploy/blocksecops-dashboard -- ps aux
```

| Test | Expected | Status |
|------|----------|--------|
| [ ] NOT running Vite dev server | No `vite` process | |
| [ ] Running static file server | `serve` or `nginx` process | |
| [ ] Serving from `/dist` directory | Static build artifacts | |

### 6.2 Production Optimizations
| Test | Expected | Status |
|------|----------|--------|
| [ ] JS files are minified | No readable source code | |
| [ ] CSS is minified | No readable CSS | |
| [ ] Source maps NOT exposed | No `.map` files accessible | |
| [ ] Gzip compression enabled | Response headers show `content-encoding: gzip` | |

---

## 7. Error Scenarios

### 7.1 Missing Credentials Error (Historical Bug)
| Test | Expected | Status |
|------|----------|--------|
| [ ] No "Missing Supabase credentials" console error | Build args properly injected | |
| [ ] No "undefined" in credential error messages | All vars defined at build time | |

### 7.2 Build Validation
| Test | Expected | Status |
|------|----------|--------|
| [ ] TypeScript compilation succeeds | No type errors during build | |
| [ ] No console errors on page load | Clean browser console | |
| [ ] React strict mode warnings OK | Expected double-render in dev only | |

---

## 8. Image Versioning

### 8.1 Version Tag Standards
| Test | Expected | Status |
|------|----------|--------|
| [ ] Image uses semantic version tag | e.g., `0.19.0` | |
| [ ] `latest` tag updated | Points to current version | |
| [ ] Kustomization updated | `newTag: "0.19.0"` in overlay | |

### 8.2 Deployment Update
```bash
# Verify deployment uses correct image
kubectl get deploy -n dashboard-local blocksecops-dashboard -o jsonpath='{.spec.template.spec.containers[0].image}'
```

| Test | Expected | Status |
|------|----------|--------|
| [ ] Deployment uses new image tag | `blocksecops-dashboard:0.19.0` | |
| [ ] Pod is running new version | Check pod describe for image | |
| [ ] Rollout successful | `kubectl rollout status` shows complete | |

---

## Quick Test Script

```bash
#!/bin/bash
# Quick production dashboard verification

echo "=== Dashboard Production Build Verification ==="

# 1. Check port-forward
echo -n "Port 3000 (Traefik): "
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3000/ && echo " OK" || echo " FAIL"

# 2. Check API health
echo -n "API Health: "
curl -s http://127.0.0.1:3000/api/v1/health/live | jq -r '.status' 2>/dev/null || echo "FAIL"

# 3. Check Supabase URL in bundle
echo -n "Supabase URL baked in: "
kubectl exec -n dashboard-local deploy/blocksecops-dashboard -- \
  grep -q "supabase" /usr/share/nginx/html/assets/*.js 2>/dev/null && echo "OK" || echo "FAIL"

# 4. Check image version
echo -n "Image version: "
kubectl get deploy -n dashboard-local blocksecops-dashboard \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""

echo "=== Verification Complete ==="
```

---

## Related Documentation

- [Frontend Build Environment Variables](/docs/standards/frontend-build-env.md)
- [Dashboard Development Standards](/docs/standards/dashboard-development.md)
- [Port-Forwarding Standards](/docs/standards/port-forwarding.md)
- [Docker Image Versioning](/docs/standards/docker-image-versioning.md)
- [Notification System Frontend](/blocksecops-docs/frontend/notification-frontend.md)

---

## Test Notes

```
[Date] | [Tester] | [Result]
2025-12-30 | Claude Code | Initial creation - tests verified during dashboard 0.19.0 deployment
```
