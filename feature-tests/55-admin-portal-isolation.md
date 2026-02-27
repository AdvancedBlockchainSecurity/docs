# Feature Test: Admin Portal Isolation

**Feature:** Phase 4.7 - Admin Portal Isolation
**Status:** Complete
**Date:** 2026-02-02

---

## Overview

Testing the separated admin portal at `admin.0xapogee.com` with network-level isolation (IP allowlist). Uses the same Supabase project as customer dashboard - security enforced through IP restrictions, MFA, and role-based access.

---

## Prerequisites

- [ ] Supabase credentials configured (same as customer dashboard)
- [ ] Admin user account has `is_superuser=True` and valid `admin_role` in database
- [ ] IP allowlist configured in Traefik middleware (production)
- [ ] Admin portal deployed (local or production)

---

## Test Cases

### 1. Authentication & Network Isolation

#### 1.1 Admin Login

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to admin portal (`admin.0xapogee.com`) | Login page displayed |
| 2 | Enter admin credentials (BlockSecOps account) | Redirected to MFA verification |
| 3 | Enter invalid credentials | Generic error message (no username enumeration) |

#### 1.2 IP Allowlist Restriction (Production)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Access from non-allowlisted IP | Connection refused / 403 |
| 2 | Access from allowlisted IP | Login page displayed |

#### 1.3 Role Verification

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login with account without `admin_role` | Access denied (404) |
| 2 | Login with valid `admin_role` | MFA verification displayed |

#### 1.4 Cross-Origin Cookie Isolation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login to admin portal | Session cookie set for `admin.0xapogee.com` |
| 2 | Check customer dashboard cookies | No admin session cookie visible |
| 3 | Login to customer dashboard | Customer session cookie set |
| 4 | Check admin portal | Admin session still valid |

---

### 2. MFA Security

#### 2.1 MFA Setup

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click "Set up new authenticator" | QR code displayed |
| 2 | Scan QR code with authenticator app | Code generated |
| 3 | Enter valid code | MFA enabled, redirected to dashboard |
| 4 | QR code is data: URI | No external URLs in QR code |

#### 2.2 MFA Rate Limiting (Client-Side)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enter invalid MFA code | "Invalid code" error |
| 2 | Enter invalid code 4 more times | "4 attempts remaining" → "1 attempt remaining" |
| 3 | Enter invalid code 6th time | "Too many attempts. Try again in X seconds." |
| 4 | Wait 5 minutes | Lockout cleared, can attempt again |

#### 2.3 MFA Rate Limiting (Server-Side)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Rapidly submit 4+ codes via API | Rate limited (429) |
| 2 | After 5 failed attempts | Account locked for 15 minutes |

---

### 3. XSS Protection

#### 3.1 Token Storage

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login successfully | Session established |
| 2 | Open browser DevTools → Application → Local Storage | No tokens in localStorage |
| 3 | Open browser DevTools → Application → Session Storage | No tokens in sessionStorage |
| 4 | Refresh page | User must re-authenticate (memory-only storage) |

#### 3.2 Admin Session Cookie

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login and complete MFA | Admin session cookie set |
| 2 | Check cookie properties | `httpOnly: true`, `SameSite: strict` |
| 3 | Attempt to read cookie via JavaScript | Cookie not accessible |

---

### 4. Input Validation

#### 4.1 Emergency Actions - User ID Validation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to Emergency page | Form displayed |
| 2 | Enter invalid user ID (not UUID) | "Invalid user ID format" error |
| 3 | Enter SQL injection attempt | Input sanitized, error displayed |
| 4 | Enter XSS payload | Input sanitized, no script execution |
| 5 | Enter valid UUID | Form proceeds |

#### 4.2 Reason Field Sanitization

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enter `<script>alert('xss')</script>` in reason | Tags stripped |
| 2 | Enter `javascript:alert('xss')` in reason | Removed |
| 3 | Enter reason > 500 characters | Truncated to 500 |

---

### 5. Confirmation Dialogs

#### 5.1 Destructive Actions

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click "Revoke Sessions" | Confirmation dialog appears |
| 2 | Dialog shows warning | "This action cannot be undone" |
| 3 | Click "Cancel" | Action not performed |
| 4 | Click "Confirm" | Action performed, logged |

#### 5.2 Impersonation Start

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enter reason (min 20 chars) | "Continue" button enabled |
| 2 | Click "Continue" | Confirmation dialog appears |
| 3 | Dialog shows user email | Correct user displayed |
| 4 | Click "Confirm Impersonation" | Token generated |

---

### 6. Impersonation Token Security

#### 6.1 Token Display

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Start impersonation | Token field shows dots (hidden) |
| 2 | Click eye icon | Token revealed |
| 3 | Wait 30 seconds | Token auto-hidden |

#### 6.2 Clipboard Security

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click copy button | Token copied, checkmark shown |
| 2 | Paste immediately | Token value correct |
| 3 | Wait 30 seconds | Clipboard cleared |
| 4 | Paste again | Empty or different content |

---

### 7. Security Headers (Production)

#### 7.1 Response Headers

```bash
curl -I https://admin.0xapogee.com
```

| Header | Expected Value |
|--------|----------------|
| `X-Frame-Options` | `DENY` |
| `X-Content-Type-Options` | `nosniff` |
| `X-XSS-Protection` | `1; mode=block` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Content-Security-Policy` | `default-src 'self'; ...` |
| `Cross-Origin-Opener-Policy` | `same-origin` |
| `Cross-Origin-Embedder-Policy` | `require-corp` |
| `Cross-Origin-Resource-Policy` | `same-origin` |
| `Strict-Transport-Security` | `max-age=63072000; includeSubdomains; preload` |

---

### 8. Backend Compatibility

#### 8.1 Admin Supabase JWT Verification

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Send request with Admin Supabase JWT | Request accepted |
| 2 | Verify JWT verified against admin JWKS | Admin JWKS endpoint called |

#### 8.2 Admin Role Verification

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Login with account lacking `admin_role` | Access denied (404) |
| 2 | Login with valid `admin_role` | Access granted after MFA |

---

### 9. User Management Endpoints

#### 9.1 List Users

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/users` | User list displayed |
| 2 | Search by email | Filtered results returned |
| 3 | Filter by tier | Only matching tier users shown |
| 4 | Filter by status | Only matching status users shown |
| 5 | Paginate through results | Page navigation works |

#### 9.2 User Detail

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click user in list | User detail page opens |
| 2 | View quota information | Quota data displayed |
| 3 | View organization count | Org count shown |

#### 9.3 User Actions (platform_admin+)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Update user tier | Tier changes, audit log created |
| 2 | Disable user (with reason) | User disabled, reason logged |
| 3 | Enable user (with reason) | User enabled, reason logged |

#### 9.4 User Deletion (super_admin only)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Delete user as platform_admin | Access denied (403) |
| 2 | Delete user as super_admin | User soft deleted, email anonymized |

---

### 10. Organization Management Endpoints

#### 10.1 List Organizations

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to `/organizations` | Organization grid displayed |
| 2 | Search by name | Filtered results returned |
| 3 | View member count | Count displayed on card |
| 4 | View project count | Count displayed on card |

#### 10.2 Organization Detail

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click organization | Detail page opens |
| 2 | View member list | All members with roles shown |
| 3 | View owner email | Owner email displayed |

#### 10.3 Organization Actions (platform_admin+)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Update organization name | Name changes, audit log created |
| 2 | Update description | Description updated |

#### 10.4 Organization Deletion (super_admin only)

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Delete org as platform_admin | Access denied (403) |
| 2 | Delete org as super_admin | Organization soft deleted |

---

## Security Test Summary

| Security Control | Test Status | Notes |
|-----------------|-------------|-------|
| Network Isolation | ☐ | IP allowlist at ingress level |
| Role-Based Access | ☐ | `admin_role` check in database |
| XSS Protection (Tokens) | ☐ | Memory-only storage |
| XSS Protection (Cookies) | ☐ | httpOnly cookies |
| CSRF Protection | ☐ | SameSite=strict |
| Rate Limiting (Client) | ☐ | 5 attempts, 5-min lockout |
| Rate Limiting (Server) | ☐ | 3/min, 15-min lockout |
| Input Validation | ☐ | UUID regex, sanitization |
| Confirmation Dialogs | ☐ | Required for destructive actions |
| Token Auto-Hide | ☐ | 30 second timeout |
| Clipboard Auto-Clear | ☐ | 30 second timeout |
| Security Headers | ☐ | CSP, COOP, COEP, CORP |
| User CRUD Operations | ☐ | Proper role enforcement |
| Organization CRUD | ☐ | Proper role enforcement |

---

## Related Documentation

- [Platform Admin Guide](../admin/platform-admin.md)
- [Admin Portal Deployment](../playbooks/admin-portal-deployment.md)
- [Security Testing](./54-security-testing.md)
