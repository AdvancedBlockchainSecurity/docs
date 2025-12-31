# Frontend Build-Time Environment Variables

**Part of:** [Platform Development Standards](./INDEX.md)
**Version:** 1.0.0
**Last Updated:** December 30, 2025
**Status:** Active

## Overview

This document defines standards for managing build-time environment variables in Vite-based frontend applications. Unlike backend services where secrets are injected at runtime via Kubernetes Secrets, Vite applications require environment variables at **build time** because they are baked into the static JavaScript bundle.

---

## How Vite Environment Variables Work

**Critical Understanding:** Vite replaces `import.meta.env.VITE_*` references with actual values **during the build process**. These values become part of the compiled JavaScript and cannot be changed at runtime.

```
┌─────────────────────────────────────────────────────────────┐
│                     BUILD TIME                              │
│  Source: import.meta.env.VITE_API_URL                       │
│  Output: "https://api.example.com"  (hardcoded in JS)       │
└─────────────────────────────────────────────────────────────┘
```

**Implications:**
- Environment variables must be available when `npm run build` executes
- Changing values requires rebuilding the application
- All `VITE_*` variables are visible in the browser (view source)

---

## Security Classification

### Public Variables (Safe to Expose)

These values are intentionally public and designed to be visible in browser code:

| Variable | Example | Why It's Safe |
|----------|---------|---------------|
| `VITE_SUPABASE_URL` | `https://xxx.supabase.co` | Public endpoint, protected by RLS |
| `VITE_SUPABASE_ANON_KEY` | `eyJhbGci...` | Anonymous key, RLS enforces access |
| `VITE_WS_URL` | `ws://127.0.0.1:8003/ws` | WebSocket endpoint, auth required |
| `VITE_WALLETCONNECT_PROJECT_ID` | `abc123...` | Public project identifier |
| `VITE_USE_TESTNET` | `true` | Feature flag, no security impact |
| `VITE_API_URL` | `https://api.example.com` | Public API endpoint |

### Private Variables (Never in Frontend)

These values must **NEVER** be in frontend code:

| Variable Type | Where It Belongs |
|---------------|------------------|
| Database credentials | Vault → Backend only |
| API secret keys | Vault → Backend only |
| JWT signing secrets | Vault → Backend only |
| Private keys | Vault → Backend only |
| Admin tokens | Vault → Backend only |

---

## Standard: Pass Build Args, Never Hardcode

**MANDATORY:** Build-time environment variables MUST be passed as Docker build arguments, NOT hardcoded in Dockerfiles.

### Correct Pattern

```dockerfile
# Dockerfile
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
ARG VITE_WS_URL=ws://127.0.0.1:8003/ws

ENV VITE_SUPABASE_URL=${VITE_SUPABASE_URL} \
    VITE_SUPABASE_ANON_KEY=${VITE_SUPABASE_ANON_KEY} \
    VITE_WS_URL=${VITE_WS_URL}

RUN npm run build
```

```bash
# Build command - values from .env.local
source .env.local
docker build \
  --build-arg VITE_SUPABASE_URL=$VITE_SUPABASE_URL \
  --build-arg VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY \
  -t blocksecops-dashboard:0.19.0 .
```

### Incorrect Pattern (DO NOT USE)

```dockerfile
# ❌ WRONG - Hardcoded values in Dockerfile
ARG VITE_SUPABASE_URL=https://xxx.supabase.co
ARG VITE_SUPABASE_ANON_KEY=eyJhbGci...actual_key_here
```

**Why this is wrong:**
- Values are committed to Git
- Cannot use different values per environment without changing Dockerfile
- Encourages bad habits that lead to real secret exposure

---

## Environment Files

### `.env.local` (Local Development Values)

Store local development values in `.env.local`. This file is gitignored and contains actual values for local builds.

```bash
# .env.local - NOT committed to Git
VITE_SUPABASE_URL=https://huzjlpypdlelqnbjvxad.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
VITE_WS_ENABLED=true
VITE_WS_URL=ws://127.0.0.1:8003/ws
VITE_WALLETCONNECT_PROJECT_ID=your_project_id
VITE_USE_TESTNET=true
```

### `.env.example` (Template)

Document required variables in `.env.example`. This file IS committed to Git.

```bash
# .env.example - Committed to Git (template only)
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
VITE_WS_ENABLED=true
VITE_WS_URL=ws://127.0.0.1:8003/ws
VITE_WALLETCONNECT_PROJECT_ID=
VITE_USE_TESTNET=true
```

---

## Build Workflow

### Local Development Build

```bash
# 1. Ensure .env.local exists with required values
cat .env.local

# 2. Switch to minikube's Docker daemon
eval $(minikube docker-env)

# 3. Source environment variables and build
cd /Users/pwner/Git/ABS
source blocksecops-dashboard/.env.local

docker build \
  --build-arg VITE_SUPABASE_URL=$VITE_SUPABASE_URL \
  --build-arg VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY \
  --build-arg VITE_WS_URL=$VITE_WS_URL \
  --build-arg VITE_WS_ENABLED=$VITE_WS_ENABLED \
  -t blocksecops-dashboard:0.19.0 \
  -f blocksecops-dashboard/Dockerfile .

# 4. Tag as latest
docker tag blocksecops-dashboard:0.19.0 blocksecops-dashboard:latest

# 5. Deploy
kubectl apply -k blocksecops-dashboard/k8s/overlays/local/
```

### CI/CD Pipeline Build

For staging/production, values come from CI/CD secrets:

```yaml
# GitHub Actions example
- name: Build Dashboard
  run: |
    docker build \
      --build-arg VITE_SUPABASE_URL=${{ secrets.VITE_SUPABASE_URL }} \
      --build-arg VITE_SUPABASE_ANON_KEY=${{ secrets.VITE_SUPABASE_ANON_KEY }} \
      -t blocksecops-dashboard:${{ github.sha }} .
```

---

## Dockerfile Template

Standard Dockerfile structure for Vite applications:

```dockerfile
# Multi-stage build for Vite React application
FROM node:20-alpine AS builder

# Build-time environment variables (NO DEFAULT VALUES for secrets)
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY
# Non-sensitive defaults are OK
ARG VITE_WS_ENABLED=true
ARG VITE_WS_URL=ws://127.0.0.1:8003/ws

# Validate required build args
RUN if [ -z "$VITE_SUPABASE_URL" ]; then echo "VITE_SUPABASE_URL is required" && exit 1; fi
RUN if [ -z "$VITE_SUPABASE_ANON_KEY" ]; then echo "VITE_SUPABASE_ANON_KEY is required" && exit 1; fi

# Set environment for Vite build
ENV VITE_SUPABASE_URL=${VITE_SUPABASE_URL} \
    VITE_SUPABASE_ANON_KEY=${VITE_SUPABASE_ANON_KEY} \
    VITE_WS_ENABLED=${VITE_WS_ENABLED} \
    VITE_WS_URL=${VITE_WS_URL}

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS runtime
RUN npm install -g serve
WORKDIR /app
COPY --from=builder /app/dist ./dist
EXPOSE 3000
CMD ["serve", "-s", "dist", "-l", "3000"]
```

---

## Compliance Checklist

Before merging frontend code:

- [ ] No hardcoded `VITE_*` values in Dockerfile (except non-sensitive defaults)
- [ ] All required variables documented in `.env.example`
- [ ] `.env.local` is in `.gitignore`
- [ ] Build args passed via command line or CI/CD secrets
- [ ] No private keys, passwords, or backend secrets in `VITE_*` variables
- [ ] Variables are correctly typed in `vite-env.d.ts`

---

## Troubleshooting

### Error: "Missing credentials" at runtime

**Cause:** Build args were not passed during `docker build`.

**Solution:**
```bash
# Verify environment variables are set
echo $VITE_SUPABASE_URL

# Rebuild with explicit build args
source .env.local
docker build --build-arg VITE_SUPABASE_URL=$VITE_SUPABASE_URL ...
```

### Error: "undefined" for environment variable

**Cause:** Variable name mismatch or not prefixed with `VITE_`.

**Solution:**
```typescript
// Only VITE_ prefixed vars are exposed to client code
console.log(import.meta.env.VITE_API_URL);     // ✅ Works
console.log(import.meta.env.API_URL);           // ❌ undefined
```

### Values not updating after rebuild

**Cause:** Docker cache or old image still deployed.

**Solution:**
```bash
# Build with --no-cache
docker build --no-cache --build-arg ... -t app:new .

# Force deployment update
kubectl rollout restart deployment/dashboard -n dashboard-local
```

---

## Related Standards

- [Secrets Management](./secrets-management.md) - Backend secret management via Vault
- [Build Workflow](./build-workflow.md) - Docker build procedures
- [Dashboard Development](./dashboard-development.md) - Dashboard development workflow
- [Docker Image Versioning](./docker-image-versioning.md) - Image tagging standards
