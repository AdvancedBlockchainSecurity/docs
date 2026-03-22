# Playbook: Admin Portal Audit Procedure

**Version:** 1.0.0
**Last Updated:** 2026-03-22
**Audience:** Platform Engineer | Security Auditor

## Overview

Reusable procedure for auditing the admin portal (`admin.0xapogee.com`). Covers infrastructure, K8s security, API endpoints, auth, frontend, and Docker compliance. Run before each release or quarterly.

---

## Prerequisites

- kubectl access to production cluster
- curl available
- Access to `blocksecops-admin-portal/` and `blocksecops-api-service/` repos

---

## Phase 1: Infrastructure & Reachability

```bash
# 1. Pod running
kubectl get pods -n admin-portal-prod -o wide --no-headers

# 2. Service configured
kubectl get svc -n admin-portal-prod --no-headers

# 3. HTTPRoute
kubectl get httproute admin-routes -n ingress-prod -o jsonpath='{.spec.hostnames[0]}'

# 4. DNS resolution
nslookup admin.0xapogee.com 8.8.8.8

# 5. Gateway programmed
kubectl get gateway -n ingress-prod

# 6. Internal reachability (from admin pod itself)
kubectl exec -n admin-portal-prod deploy/admin-portal -- wget -q -O /dev/null --timeout=5 http://localhost:3000/

# 7. External HTTPS
curl -sk -o /dev/null -w "HTTP %{http_code}\n" "https://admin.0xapogee.com/"

# 8. Version sync
grep '"version"' blocksecops-admin-portal/package.json
grep 'newTag' blocksecops-admin-portal/k8s/overlays/gcp/kustomization.yaml
kubectl get deploy admin-portal -n admin-portal-prod -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Expected:** Pod 1/1 Running, Service :3000, DNS resolves to gateway IP, versions match.

---

## Phase 2: K8s Security

```bash
NS=admin-portal-prod
SVC=admin-portal

# Security context
kubectl get deploy $SVC -n $NS -o jsonpath='{.spec.revisionHistoryLimit}'           # expect: 3
kubectl get deploy $SVC -n $NS -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'  # expect: true
kubectl get deploy $SVC -n $NS -o jsonpath='{.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}'  # expect: true
kubectl get deploy $SVC -n $NS -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}'  # expect: false
kubectl get deploy $SVC -n $NS -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop}'  # expect: ["ALL"]
kubectl get deploy $SVC -n $NS -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}'  # expect: RuntimeDefault

# NetworkPolicy
kubectl get networkpolicy -n $NS --no-headers  # expect: default-deny-all + admin-portal-ingress + allow-dns + allow-gcp-health-checks

# Resources
kubectl get deploy $SVC -n $NS -o jsonpath='{.spec.template.spec.containers[0].resources}'

# Probes
kubectl get deploy $SVC -n $NS -o json | python3 -c "
import json,sys; c=json.load(sys.stdin)['spec']['template']['spec']['containers'][0]
for p in ['livenessProbe','readinessProbe','startupProbe']:
    print(f'{p}: {\"configured\" if c.get(p) else \"MISSING\"}')"
```

**Expected:** All security hardening in place per kubernetes-pod-lifecycle.md standard.

---

## Phase 3: API Endpoint Security

Test that all admin endpoints reject unauthenticated access:

```bash
BASE="https://app.0xapogee.com/api/v1"

for ep in \
  admin/users admin/organizations admin/system/stats admin/system/health \
  admin/system/config admin/audit/logs admin/audit/admin-actions \
  admin/audit/security-events admin/purchases/transactions \
  admin/purchases/subscriptions admin/purchases/stats \
  admin/scan-monitoring/stats admin/scan-monitoring/stale \
  admin/referrals/settings admin/auth/session admin/dependencies; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/$ep")
  echo "$code $ep"  # All should be 401
done
```

Test API key also rejected (admin requires JWT + MFA):

```bash
for ep in admin/users admin/system/stats admin/audit/logs; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/$ep" -H "X-API-Key: $API_KEY")
  echo "$code $ep"  # All should be 401
done
```

**Expected:** All return 401 or 403. No 200, no 500, no stack traces.

---

## Phase 4: Auth Security (code review)

Verify every admin endpoint file has auth guards:

```bash
for f in src/presentation/api/v1/endpoints/admin/*.py; do
  fname=$(basename "$f")
  [ "$fname" = "__init__.py" ] || [ "$fname" = "utils.py" ] && continue
  routes=$(grep -c "@router\.\(get\|post\|put\|patch\|delete\)" "$f")
  guards=$(grep -c "require_admin_role\|get_admin_user\|get_current_admin" "$f")
  echo "$fname: $routes routes, $guards guards"
done
```

**Expected:** Every file with routes has guards ≥ routes.

Check critical security features in `admin_dependencies.py`:

| Feature | Search Pattern | Expected |
|---------|---------------|----------|
| MFA verification | `mfa_verified` | Present |
| IP binding | `client_ip` or `ip_address` | Present |
| Token hashing | `sha256` or `hashlib` | Present |
| TOTP encryption | `encrypt` or `Fernet` | Present |
| Session timeout | `timedelta` | Present |
| Role hierarchy | `super_admin`, `platform_admin`, `support_admin` | All three defined |

Check MFA lockout in `auth.py`:
```bash
grep "MFA_MAX_ATTEMPTS\|lockout" src/presentation/api/v1/endpoints/admin/auth.py
```

Check audit logging coverage:
```bash
grep -c "log_admin_action" src/presentation/api/v1/endpoints/admin/*.py
```

**Expected:** All mutation endpoints have audit logging.

---

## Phase 5: Frontend Security (code review)

```bash
# No localStorage for auth tokens
grep -rn "localStorage.*token" src/ --include="*.tsx" --include="*.ts"
# Expected: only references stating NOT to use it

# No dangerouslySetInnerHTML
grep -rn "dangerouslySetInnerHTML" src/ --include="*.tsx"
# Expected: 0 matches

# Client-side rate limiting on login
grep -c "rateLimit\|loginAttempts\|MAX_ATTEMPTS" src/pages/AdminLogin.tsx
# Expected: > 0
```

---

## Phase 6: Docker Image Compliance

```bash
# Pinned base image (no :latest)
grep "^FROM" Dockerfile

# Non-root user
grep "USER\|appuser" Dockerfile

# OCI labels
grep -c "org.opencontainers.image" Dockerfile  # expect: ≥7

# Build args validated
grep "ARG.*VITE_" Dockerfile

# Health check
grep "HEALTHCHECK" Dockerfile

# Multi-stage build
grep -c "^FROM" Dockerfile  # expect: ≥2
```

---

## Phase 7: Regression Tests

Run the admin auth regression test suite:

```bash
cd blocksecops-api-service
python3 -m pytest tests/unit/admin/test_admin_auth_regression.py -v -o "addopts="
```

**Expected:** 13/13 pass.

---

## Sign-Off Checklist

- [ ] All pods Running, version synced
- [ ] K8s security: runAsNonRoot, readOnly, drop ALL, seccomp, default-deny
- [ ] All 16 admin endpoints reject unauthenticated access
- [ ] All admin endpoints reject API key (require JWT + MFA)
- [ ] Auth guards on every endpoint file
- [ ] MFA lockout, IP binding, token hashing implemented
- [ ] Audit logging on all mutation endpoints
- [ ] No localStorage tokens, no dangerouslySetInnerHTML
- [ ] Pinned Docker images, non-root, OCI labels
- [ ] Regression tests pass (13/13)
- [ ] DNS configured for admin.0xapogee.com

**Auditor:** _________________ **Date:** _________________
