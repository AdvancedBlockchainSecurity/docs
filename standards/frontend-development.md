# Frontend Development Standards

**Version:** 0.1.0
**Last Updated:** November 13, 2025
**Status:** Active

## Overview

The Apogee Frontend is a React + TypeScript application built with Vite that provides the user-facing authentication interface for the platform. It integrates with Supabase Auth for authentication and the API Service for user data and quota management.

**Repository:** `/Users/pwner/Git/ABS/blocksecops-frontend`
**Technology Stack:** React 18.2, TypeScript 5.3, Vite 5.0, Supabase, Zustand, Tailwind CSS
**Primary Purpose:** User authentication, registration, quota display, tier management

## Port Assignments

**MANDATORY port for frontend:**

| Service | Port | Purpose | Notes |
|---------|------|---------|-------|
| Frontend | 3002 | Authentication UI | React Vite dev server |

**Related Services:**

| Service | Port | Purpose | Notes |
|---------|------|---------|-------|
| Dashboard | 3000 | Main Dashboard UI | Primary user interface |
| API Service | 8000 | Backend API | Required for user data |
| Notification | 8003 | WebSocket | For real-time updates |

## Proper Frontend Startup Procedure

### Step 1: Verify Dependencies

**CRITICAL:** API Service must be running and healthy BEFORE starting frontend.

```bash
# 1. Verify cluster is running
kubectl get nodes

# 2. Check API Service is deployed and running
kubectl get pods -n api-service-local

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# api-service-xxxxx             1/1     Running   0          1d

# 3. Verify API Service has endpoints
kubectl get endpoints -n api-service-local api-service

# ✅ GOOD: Shows IP addresses
# NAME          ENDPOINTS         AGE
# api-service   10.244.0.14:8000  2d

# ❌ BAD: No endpoints (selector mismatch)
# NAME          ENDPOINTS   AGE
# api-service   <none>      2d
```

**If API Service has no endpoints:**
- Review [Local Development Setup - Kubernetes Service Selector Standards](./local-development-setup.md#kubernetes-service-selector-standards)
- Fix `includeSelectors: false` in kustomization.yaml
- Reapply: `kubectl apply -k /Users/pwner/Git/ABS/blocksecops-api-service/k8s/overlays/local/`

### Step 2: Start Required Port-Forwards

**MANDATORY:** Port-forward API Service before starting frontend.

```bash
# Kill any existing port-forwards
lsof -ti:8000 | xargs kill -9 2>/dev/null

# Wait for processes to die
sleep 2

# Start API Service port-forward
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
echo "✅ API Service port-forward started"

# Wait for port-forward to stabilize
sleep 3

# Verify port-forward is active
lsof -i :8000 | grep LISTEN
```

**Why use `deployment/api-service` instead of `svc/api-service`?**
- Port-forwarding to a **deployment** automatically handles pod restarts
- When a pod is replaced (during rollout), deployment port-forward reconnects automatically
- Service port-forward will die when the old pod terminates

### Step 3: Verify API Health

**CRITICAL:** API must be healthy BEFORE starting frontend.

```bash
# Test API health endpoint
curl -s http://127.0.0.1:8000/api/v1/health/live | jq '.'

# Expected output:
# {
#   "status": "healthy",
#   "service": "Apogee API Service",
#   "version": "0.3.20",
#   "timestamp": "2025-11-13T18:25:00.123456"
# }

# Test API readiness (checks database connection)
curl -s http://127.0.0.1:8000/api/v1/health/ready | jq '.'

# Expected output:
# {
#   "status": "ready",
#   "database": "connected",
#   "redis": "connected"
# }
```

**If health checks fail:**

```bash
# 1. Check API logs for errors
kubectl logs -n api-service-local deployment/api-service --tail=50

# 2. Check port-forward logs
tail -50 /tmp/pf-api-service.log

# 3. Common issues:
#    - Port-forward died during pod restart
#    - Database connection failed
#    - Service has no endpoints
```

### Step 4: Configure Frontend Environment

**Verify frontend `.env.local` exists and is correct:**

```bash
# Check if file exists
cat /Users/pwner/Git/ABS/blocksecops-frontend/.env.local

# Expected content:
# VITE_API_BASE_URL=http://127.0.0.1:8000
# VITE_SUPABASE_URL=https://your-project.supabase.co
# VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

**If file is missing or incorrect, update it:**

```bash
# Update .env.local
cat > /Users/pwner/Git/ABS/blocksecops-frontend/.env.local <<'EOF'
# Frontend local development environment
# MANDATORY: Use 127.0.0.1 for local development
VITE_API_BASE_URL=http://127.0.0.1:8000

# Supabase Configuration
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
EOF

echo "✅ Frontend .env.local updated"
```

### Step 5: Start Frontend Development Server

```bash
# Navigate to frontend directory
cd /Users/pwner/Git/ABS/blocksecops-frontend

# Install dependencies (if not already installed)
npm install

# Start development server
npm run dev

# Expected output:
# VITE v5.0.8  ready in 500 ms
#
# ➜  Local:   http://localhost:3002/
# ➜  Network: use --host to expose
# ➜  press h to show help
```

**IMPORTANT:** Vite should start on port 3002 as configured in `vite.config.ts`.

**If frontend starts on wrong port:**

```bash
# 1. Stop the frontend (Ctrl+C)

# 2. Find what's using port 3002
lsof -i :3002

# 3. Kill the process
lsof -ti :3002 | xargs kill -9

# 4. Restart frontend
npm run dev

# 5. Verify it's on port 3002
lsof -i :3002 | grep LISTEN
```

### Step 6: Verify Frontend Connectivity

```bash
# 1. Open browser to http://127.0.0.1:3002

# 2. Open browser console (F12)

# 3. Check for connection errors
#    ✅ GOOD: No errors, login page loads
#    ❌ BAD: "Network Error", "ERR_CONNECTION_REFUSED"

# 4. If errors occur, check:
curl -s http://127.0.0.1:8000/api/v1/health/live

# 5. Try to access login page
curl -s http://127.0.0.1:3002 | grep "<title>"
# Should return: <title>Apogee Dashboard</title>
```

## Accessing Frontend in Kubernetes

### Deploy Frontend to Kubernetes

```bash
# 1. Build Docker image (follow docker-image-versioning.md)
cd /Users/pwner/Git/ABS/blocksecops-frontend
REGISTRY="${REGISTRY:-harbor.0xapogee.local}"
docker build --no-cache -t ${REGISTRY}/blocksecops/frontend:0.1.0 -f Dockerfile .

# 2. Push to Harbor registry
docker push ${REGISTRY}/blocksecops/frontend:0.1.0

# 3. Deploy to Kubernetes
kubectl apply -k k8s/overlays/local/

# 5. Verify deployment
kubectl get all -n frontend-local

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# pod/frontend-xxxxx              1/1     Running   0          1m
#
# NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
# service/frontend   ClusterIP   10.107.53.16   <none>        80/TCP    1m
#
# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/frontend   1/1     1            1           1m
```

### Access Frontend via Port-Forward

```bash
# Port-forward frontend service
kubectl port-forward -n frontend-local svc/frontend 3002:80 > /tmp/pf-frontend.log 2>&1 &

# Wait for port-forward to stabilize
sleep 3

# Verify port-forward is active
lsof -i :3002 | grep LISTEN

# Test health endpoint
curl -s http://127.0.0.1:3002/health

# Expected output:
# healthy

# Access frontend in browser
open http://127.0.0.1:3002
```

## Troubleshooting Frontend Issues

### Issue: "Network Error" or "ERR_CONNECTION_REFUSED"

**Root Cause:** API port-forward is not running.

**Solution:**

```bash
# 1. Check if API port-forward is running
ps aux | grep "port-forward.*8000" | grep -v grep

# 2. If not running, restart it
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &

# 3. Wait and test
sleep 3
curl http://127.0.0.1:8000/api/v1/health/live

# 4. Refresh frontend browser page
```

### Issue: Port-forward keeps dying

**Root Cause:** Port-forwarding to a specific pod that gets replaced during rollouts.

**Solution:** Use deployment-based port-forward (auto-reconnects):

```bash
# ❌ BAD: Port-forward to service or pod
kubectl port-forward -n frontend-local svc/frontend 3000:80 &
kubectl port-forward -n frontend-local pod/frontend-xxxxx 3000:80 &

# ✅ GOOD: Port-forward to deployment
kubectl port-forward -n frontend-local deployment/frontend 3000:80 &
```

### Issue: Frontend shows blank page or 404

**Root Cause:** Nginx routing issue or build artifacts missing.

**Solution:**

```bash
# 1. Check frontend pod logs
kubectl logs -n frontend-local deployment/frontend --tail=50

# 2. Check if index.html exists in container
kubectl exec -n frontend-local deployment/frontend -- ls -la /usr/share/nginx/html/

# Expected files:
# index.html
# assets/
# vite.svg

# 3. Rebuild and redeploy if files are missing
cd /Users/pwner/Git/ABS/blocksecops-frontend
REGISTRY="${REGISTRY:-harbor.0xapogee.local}"
docker build --no-cache -t ${REGISTRY}/blocksecops/frontend:0.1.0 -f Dockerfile .
docker push ${REGISTRY}/blocksecops/frontend:0.1.0
kubectl rollout restart deployment/frontend -n frontend-local
```

### Issue: Supabase authentication not working

**Root Cause:** Missing or incorrect Supabase credentials in `.env.local`.

**Solution:**

```bash
# 1. Verify .env.local has correct Supabase credentials
cat /Users/pwner/Git/ABS/blocksecops-frontend/.env.local | grep SUPABASE

# 2. Get credentials from Supabase dashboard
# https://app.supabase.com/project/YOUR_PROJECT/settings/api

# 3. Update .env.local with correct values
# VITE_SUPABASE_URL=https://xxx.supabase.co
# VITE_SUPABASE_ANON_KEY=eyJxxx...

# 4. Restart frontend dev server
npm run dev
```

### Issue: CORS errors in browser console

**Root Cause:** API Service CORS configuration doesn't allow frontend origin.

**Solution:**

```bash
# 1. Check CORS configuration in API Service
kubectl get configmap -n api-service-local api-service-config -o yaml | grep CORS

# 2. Verify CORS includes http://127.0.0.1:3002
# CORS_ORIGINS should include: http://127.0.0.1:3002,http://localhost:3002

# 3. If CORS needs updating, edit configmap-patch.yaml
cd /Users/pwner/Git/ABS/blocksecops-api-service
vim k8s/overlays/local/configmap-patch.yaml

# 4. Apply changes
kubectl apply -k k8s/overlays/local/

# 5. Restart API Service to pick up changes
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 6. Restart API port-forward (pod was replaced)
lsof -ti:8000 | xargs kill -9
sleep 2
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 &

# 7. Verify API is accessible
curl -s http://127.0.0.1:8000/api/v1/health/live

# 8. Refresh frontend browser page
```

## Frontend Development Workflow

### Daily development workflow:

```bash
# 1. Verify cluster is running
kubectl get nodes

# 2. Check API Service is healthy
kubectl get pods -n api-service-local

# 3. Start API port-forward (if not already running)
ps aux | grep "port-forward.*8000" | grep -v grep || {
  kubectl port-forward -n api-service-local deployment/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
  sleep 3
}

# 4. Verify API is healthy
curl -s http://127.0.0.1:8000/api/v1/health/ready | jq '.status'

# 5. Start frontend (if not already running)
cd /Users/pwner/Git/ABS/blocksecops-frontend
npm run dev

# 6. Open browser to http://127.0.0.1:3002

# 7. Develop and test features
```

### After code changes:

```bash
# For local development (npm run dev):
# 1. Save changes
# 2. Vite hot-reload will automatically update browser
# 3. Test changes in browser

# For Kubernetes deployment:
# 1. Commit changes to Git
cd /Users/pwner/Git/ABS/blocksecops-frontend
git add .
git commit -m "feat: add new feature"

# 2. Build new Docker image (increment version)
REGISTRY="${REGISTRY:-harbor.0xapogee.local}"
docker build --no-cache -t ${REGISTRY}/blocksecops/frontend:0.1.1 -f Dockerfile .

# 3. Push to Harbor registry
docker push ${REGISTRY}/blocksecops/frontend:0.1.1

# 4. Update kustomization.yaml with new version
vim k8s/base/frontend/kustomization.yaml
# Change newTag: 0.1.0 to newTag: 0.1.1

# 5. Apply changes
kubectl apply -k k8s/overlays/local/

# 6. Wait for rollout
kubectl rollout status -n frontend-local deployment/frontend

# 7. Verify deployment
kubectl get pods -n frontend-local

# 8. Test changes via port-forward
kubectl port-forward -n frontend-local svc/frontend 3002:80 &
sleep 2
curl -s http://127.0.0.1:3002/health
```

## Frontend Development Checklist

**Before starting development:**

- [ ] Cluster nodes ready (`kubectl get nodes`)
- [ ] API Service deployed and healthy (`kubectl get pods -n api-service-local`)
- [ ] API Service has endpoints (`kubectl get endpoints -n api-service-local api-service`)
- [ ] API port-forward active on 8000 (use deployment, not service!)
- [ ] API health check passing (`curl http://127.0.0.1:8000/api/v1/health/ready`)
- [ ] Frontend `.env.local` configured correctly
- [ ] Frontend running on port 3002
- [ ] Can access frontend at `http://127.0.0.1:3002`
- [ ] No console errors in browser (F12 → Console tab)
- [ ] Supabase credentials configured (if using auth features)

**After code changes:**

- [ ] Code changes committed to Git
- [ ] Docker image built with incremented version
- [ ] Image pushed to Harbor registry
- [ ] Kustomization updated with new version
- [ ] Deployment updated and rolled out successfully
- [ ] Health check passing (`curl http://127.0.0.1:3002/health`)
- [ ] Feature tested and verified in browser
- [ ] No console errors or warnings

## Frontend Architecture

### Technology Stack

- **React 18.2** - UI framework with hooks and functional components
- **TypeScript 5.3** - Type-safe JavaScript
- **Vite 5.0** - Build tool and dev server with hot module replacement
- **React Router 6.20** - Client-side routing
- **Zustand 4.4** - Lightweight state management
- **Supabase 2.39** - Authentication provider (JWT ES256)
- **Axios 1.6** - HTTP client with interceptors
- **Tailwind CSS 3.3** - Utility-first CSS framework

### Project Structure

```
blocksecops-frontend/
├── src/
│   ├── components/          # Reusable UI components
│   │   └── ProtectedRoute.tsx
│   ├── lib/                 # Core libraries and configs
│   │   ├── api.ts           # Axios client with auth interceptor
│   │   └── supabase.ts      # Supabase client configuration
│   ├── pages/               # Route components
│   │   ├── AuthCallback.tsx # OAuth callback handler
│   │   ├── DashboardPage.tsx # Main dashboard with quota
│   │   ├── LoginPage.tsx    # Login form
│   │   ├── SettingsPage.tsx # Tier comparison and settings
│   │   └── SignupPage.tsx   # Registration form
│   ├── store/               # Zustand state management
│   │   └── authStore.ts     # Authentication state
│   ├── types/               # TypeScript type definitions
│   │   └── index.ts         # User, Quota, EnhancedUser types
│   ├── App.tsx              # Root component with routing
│   ├── main.tsx             # Application entry point
│   ├── index.css            # Global styles with Tailwind
│   └── vite-env.d.ts        # Vite environment types
├── k8s/                     # Kubernetes manifests
│   ├── base/frontend/       # Base configuration
│   └── overlays/local/      # Local development overlay
├── Dockerfile               # Multi-stage production build
├── nginx.conf               # Nginx configuration for SPA
├── package.json             # Dependencies and scripts
├── tsconfig.json            # TypeScript configuration
├── tailwind.config.js       # Tailwind CSS configuration
├── vite.config.ts           # Vite build configuration
└── .env.local               # Local environment variables
```

### Authentication Flow

1. **User visits protected route** → Redirected to `/login`
2. **User submits credentials** → `authStore.signIn()` called
3. **Supabase authentication** → Returns session with JWT
4. **Store session** → Saved in authStore and localStorage
5. **Fetch user data** → Call `/users/me/enhanced` with JWT
6. **Store user data** → Includes tier, quota, scan limits
7. **Redirect to dashboard** → Protected route now accessible
8. **Auto-refresh** → Supabase automatically refreshes JWT

### API Integration

All API calls use the Axios client in `src/lib/api.ts` which:
- Automatically adds JWT token from Supabase to `Authorization` header
- Handles 401 errors by signing out and redirecting to login
- Provides centralized error handling
- Uses base URL from `VITE_API_BASE_URL` environment variable

### State Management

Uses Zustand for lightweight state management:
- **authStore** - User session, authentication state, quota data
- Auto-initializes on app load
- Listens for Supabase auth state changes
- Persists session in localStorage via Supabase

---

**See Also:**
- [Local Development Setup](./local-development-setup.md) - Local development standards and setup
- [Dashboard Development](./dashboard-development.md) - Dashboard-specific setup and workflows
- [Docker Image Versioning](./docker-image-versioning.md) - Docker build and versioning standards
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
