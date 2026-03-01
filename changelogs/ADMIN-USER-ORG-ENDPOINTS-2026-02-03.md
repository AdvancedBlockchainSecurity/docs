# Admin User & Organization Management Endpoints

**Date:** 2026-02-03
**Service:** blocksecops-api-service
**Version:** 0.22.4
**Phase:** 4.7 - Admin Portal Isolation

---

## Summary

Added complete CRUD (Create, Read, Update, Delete) endpoints for user and organization management in the admin portal. These endpoints enable platform administrators to manage users and organizations through the admin portal interface.

---

## New Endpoints

### User Management (`/admin/users`)

| Method | Endpoint | Role Required | Description |
|--------|----------|---------------|-------------|
| GET | `/admin/users` | support_admin+ | List users with filters |
| GET | `/admin/users/{id}` | support_admin+ | Get user detail with quota |
| PATCH | `/admin/users/{id}` | platform_admin+ | Update user |
| POST | `/admin/users/{id}/disable` | platform_admin+ | Disable user |
| POST | `/admin/users/{id}/enable` | platform_admin+ | Enable user |
| DELETE | `/admin/users/{id}` | super_admin | Soft delete user |

**Query Parameters (GET /admin/users):**
- `search` - Search by email or display name
- `tier` - Filter by tier (developer, team, growth, enterprise)
- `is_active` - Filter by active status
- `is_superuser` - Filter by admin status
- `page`, `page_size` - Pagination

### Organization Management (`/admin/organizations`)

| Method | Endpoint | Role Required | Description |
|--------|----------|---------------|-------------|
| GET | `/admin/organizations` | support_admin+ | List organizations |
| GET | `/admin/organizations/{id}` | support_admin+ | Get org detail with members |
| PATCH | `/admin/organizations/{id}` | platform_admin+ | Update organization |
| DELETE | `/admin/organizations/{id}` | super_admin | Soft delete organization |

**Query Parameters (GET /admin/organizations):**
- `search` - Search by name or slug
- `is_active` - Filter by active status
- `page`, `page_size` - Pagination

---

## New Files

```
blocksecops-api-service/src/presentation/api/v1/endpoints/admin/
├── users.py          # NEW - User management endpoints
├── organizations.py  # NEW - Organization management endpoints
└── __init__.py       # Updated - Register new routers
```

---

## Security

- All endpoints use `require_admin_role_portal()` dependency
- Role hierarchy enforced: super_admin > platform_admin > support_admin
- All actions logged to `admin_audit_logs` table
- Reason required (min 10 chars) for destructive actions
- Soft delete preserves data integrity (sets `is_active=False`)
- User deletion anonymizes email to prevent data leakage

---

## Deployment

```bash
# Build and push
cd /home/pwner/Git/blocksecops-api-service
docker build -t harbor.blocksecops.local/blocksecops/api-service:0.22.4 .
docker push harbor.blocksecops.local/blocksecops/api-service:0.22.4

# Deploy
kubectl apply -k k8s/overlays/local/
kubectl rollout status deployment/api-service -n api-service-local
```

---

## Testing

```bash
# Test users endpoint (requires admin session)
curl -s http://admin.0xapogee.local/api/v1/admin/users

# Test organizations endpoint
curl -s http://admin.0xapogee.local/api/v1/admin/organizations

# Expected: 401 Unauthorized (authentication required)
```

---

## Related Documentation

- [Platform Admin Guide](../admin/platform-admin.md)
- [Feature Test: Admin Portal Isolation](../feature-tests/55-admin-portal-isolation.md)
- [Admin Portal Deployment Playbook](../playbooks/admin-portal-deployment.md)

---

## Version Updates

| Component | Old Version | New Version |
|-----------|-------------|-------------|
| API Service (pyproject.toml) | 0.22.3 | 0.22.4 |
| API Service (kustomization) | 0.22.0 | 0.22.4 |
