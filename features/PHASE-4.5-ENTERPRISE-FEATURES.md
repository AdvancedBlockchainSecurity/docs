# Phase 4.5: Enterprise Features

## Overview

Phase 4.5 introduces enterprise-grade features for BlockSecOps:
- **Webhooks**: Real-time event notifications for scans and vulnerabilities
- **RBAC**: Role-Based Access Control with organizations and teams
- **SSO**: Single Sign-On integration (SAML 2.0 and OIDC)
- **API Keys**: Programmatic access with scoped permissions
- **Audit Logging**: Comprehensive audit trail for compliance

## Features

### 1. Webhook System

Real-time HTTP callbacks for scan events and vulnerability detection.

#### Event Types

| Event | Description | Payload |
|-------|-------------|---------|
| `scan.started` | Scan execution begins | scan_id, contract_id, scanners |
| `scan.completed` | Scan completes successfully | scan_id, vulnerability_counts |
| `scan.failed` | Scan fails | scan_id, error_message |
| `vulnerability.detected` | New vulnerability found | vulnerability details |
| `vulnerability.critical` | Critical severity issue | vulnerability details |
| `contract.added` | New contract uploaded | contract_id, name |
| `contract.deleted` | Contract removed | contract_id |

#### Webhook Signature Verification

All webhook payloads are signed using HMAC-SHA256:

```python
import hmac
import hashlib

def verify_webhook_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)
```

#### Webhook Headers

| Header | Description |
|--------|-------------|
| `X-BlockSecOps-Signature` | HMAC-SHA256 signature |
| `X-BlockSecOps-Event` | Event type |
| `X-BlockSecOps-Delivery` | Unique delivery ID |
| `X-BlockSecOps-Timestamp` | Unix timestamp |

#### Retry Policy

- 3 retry attempts (configurable)
- Exponential backoff: 1s, 5s, 30s
- Maximum timeout: 30 seconds per request
- Failed deliveries logged for debugging

### 2. Role-Based Access Control (RBAC)

Multi-tenant access control with organizations and roles.

#### System Roles

| Role | Permissions |
|------|-------------|
| `owner` | Full access, billing, member management |
| `admin` | All operations except billing/ownership |
| `developer` | Create/read contracts, trigger scans |
| `viewer` | Read-only access to results |
| `auditor` | Read access + audit log viewing |

#### Permission Matrix

| Permission | Owner | Admin | Developer | Viewer | Auditor |
|------------|-------|-------|-----------|--------|---------|
| `contracts.create` | ✓ | ✓ | ✓ | - | - |
| `contracts.read` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `contracts.delete` | ✓ | ✓ | - | - | - |
| `scans.create` | ✓ | ✓ | ✓ | - | - |
| `scans.read` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `vulnerabilities.read` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `webhooks.manage` | ✓ | ✓ | - | - | - |
| `members.invite` | ✓ | ✓ | - | - | - |
| `members.remove` | ✓ | ✓ | - | - | - |
| `roles.manage` | ✓ | - | - | - | - |
| `billing.manage` | ✓ | - | - | - | - |
| `audit.read` | ✓ | ✓ | - | - | ✓ |

#### Custom Roles

Enterprise tier users can create custom roles:

```json
{
  "name": "security_analyst",
  "display_name": "Security Analyst",
  "permissions": [
    "contracts.read",
    "scans.create",
    "scans.read",
    "vulnerabilities.read",
    "vulnerabilities.update"
  ]
}
```

### 3. Single Sign-On (SSO)

Enterprise SSO integration supporting SAML 2.0 and OIDC.

#### Supported Providers

| Provider | Protocol | Status |
|----------|----------|--------|
| Okta | SAML/OIDC | Supported |
| Azure AD | SAML/OIDC | Supported |
| Google Workspace | OIDC | Supported |
| OneLogin | SAML | Supported |
| Auth0 | OIDC | Supported |
| Custom SAML | SAML 2.0 | Supported |
| Custom OIDC | OIDC 1.0 | Supported |

#### Domain-Based SSO

Organizations can enforce SSO for their domain:

```json
{
  "sso_enabled": true,
  "sso_provider": "saml",
  "sso_domain": "example.com",
  "sso_config": {
    "idp_entity_id": "https://idp.example.com",
    "idp_sso_url": "https://idp.example.com/sso/saml",
    "idp_certificate": "-----BEGIN CERTIFICATE-----...",
    "sp_entity_id": "https://blocksecops.com/saml/example-org"
  }
}
```

Users with `@example.com` emails are automatically redirected to SSO.

### 4. API Keys

Programmatic API access with scoped permissions.

#### Key Format

```
bso_live_1a2b3c4d5e6f7g8h...
```

- Prefix: `bso_live_` or `bso_test_`
- 32-character random token
- Only shown once on creation

#### Scopes

| Scope | Description |
|-------|-------------|
| `contracts:read` | Read contract data |
| `contracts:write` | Create/update contracts |
| `scans:read` | Read scan results |
| `scans:write` | Trigger scans |
| `vulnerabilities:read` | Read vulnerabilities |
| `webhooks:manage` | Manage webhooks |

#### Rate Limits

| Tier | Per Minute | Per Hour |
|------|------------|----------|
| Free | 30 | 500 |
| Pro | 60 | 1000 |
| Enterprise | 120 | 5000 |

### 5. Audit Logging

Comprehensive audit trail for compliance and security.

#### Logged Events

- Authentication events (login, logout, failed attempts)
- Resource creation/modification/deletion
- Permission changes
- API key usage
- Webhook deliveries
- SSO events

#### Log Entry Structure

```json
{
  "id": "uuid",
  "action": "scan.create",
  "user_id": "uuid",
  "organization_id": "uuid",
  "resource_type": "scan",
  "resource_id": "uuid",
  "ip_address": "192.168.1.1",
  "user_agent": "Mozilla/5.0...",
  "old_values": null,
  "new_values": {"status": "pending"},
  "success": true,
  "created_at": "2025-11-30T12:00:00Z"
}
```

## Database Schema

### New Tables

```sql
-- Webhooks
CREATE TABLE webhooks (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    organization_id UUID REFERENCES organizations(id),
    name VARCHAR(255) NOT NULL,
    url VARCHAR(2048) NOT NULL,
    secret VARCHAR(255) NOT NULL,
    events JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    retry_count INTEGER DEFAULT 3,
    timeout_seconds INTEGER DEFAULT 30,
    total_deliveries INTEGER DEFAULT 0,
    successful_deliveries INTEGER DEFAULT 0,
    failed_deliveries INTEGER DEFAULT 0,
    last_triggered_at TIMESTAMP WITH TIME ZONE,
    last_success_at TIMESTAMP WITH TIME ZONE,
    last_failure_at TIMESTAMP WITH TIME ZONE,
    last_error TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Webhook Deliveries
CREATE TABLE webhook_deliveries (
    id UUID PRIMARY KEY,
    webhook_id UUID REFERENCES webhooks(id),
    event_type VARCHAR(50) NOT NULL,
    event_id VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status_code INTEGER,
    response_body TEXT,
    attempt_number INTEGER DEFAULT 1,
    success BOOLEAN DEFAULT false,
    error_message TEXT,
    duration_ms INTEGER,
    triggered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivered_at TIMESTAMP WITH TIME ZONE
);

-- Organizations
CREATE TABLE organizations (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    tier VARCHAR(50) DEFAULT 'free',
    sso_enabled BOOLEAN DEFAULT false,
    sso_provider VARCHAR(50),
    sso_config JSONB,
    sso_domain VARCHAR(255),
    owner_id UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Roles
CREATE TABLE roles (
    id UUID PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id),
    name VARCHAR(100) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '[]',
    is_system_role BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organization Members
CREATE TABLE organization_members (
    id UUID PRIMARY KEY,
    organization_id UUID REFERENCES organizations(id),
    user_id UUID REFERENCES users(id),
    role_id UUID REFERENCES roles(id),
    invited_by UUID,
    invited_at TIMESTAMP WITH TIME ZONE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    UNIQUE(organization_id, user_id)
);

-- API Keys
CREATE TABLE api_keys (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    organization_id UUID REFERENCES organizations(id),
    name VARCHAR(255) NOT NULL,
    key_prefix VARCHAR(10) NOT NULL,
    key_hash VARCHAR(255) NOT NULL,
    scopes JSONB DEFAULT '[]',
    rate_limit_per_minute INTEGER DEFAULT 60,
    rate_limit_per_hour INTEGER DEFAULT 1000,
    last_used_at TIMESTAMP WITH TIME ZONE,
    total_requests INTEGER DEFAULT 0,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    revoked_at TIMESTAMP WITH TIME ZONE
);

-- Audit Logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    organization_id UUID REFERENCES organizations(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    request_id VARCHAR(100),
    old_values JSONB,
    new_values JSONB,
    metadata JSONB,
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX ix_webhooks_user_id ON webhooks(user_id);
CREATE INDEX ix_webhook_deliveries_webhook_id ON webhook_deliveries(webhook_id);
CREATE INDEX ix_organizations_slug ON organizations(slug);
CREATE INDEX ix_organizations_sso_domain ON organizations(sso_domain);
CREATE INDEX ix_organization_members_user_id ON organization_members(user_id);
CREATE INDEX ix_api_keys_key_prefix ON api_keys(key_prefix);
CREATE INDEX ix_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX ix_audit_logs_action ON audit_logs(action);
CREATE INDEX ix_audit_logs_created_at ON audit_logs(created_at);
```

## API Endpoints

### Webhooks

```http
# List event types
GET /api/v1/webhooks/events

# Create webhook
POST /api/v1/webhooks
{
  "name": "Scan Notifications",
  "url": "https://api.example.com/webhooks",
  "events": ["scan.completed", "vulnerability.critical"]
}

# List webhooks
GET /api/v1/webhooks

# Get webhook
GET /api/v1/webhooks/{id}

# Update webhook
PATCH /api/v1/webhooks/{id}

# Delete webhook
DELETE /api/v1/webhooks/{id}

# Rotate secret
POST /api/v1/webhooks/{id}/rotate-secret

# Get delivery history
GET /api/v1/webhooks/{id}/deliveries
```

### Organizations

```http
# Create organization
POST /api/v1/organizations
{
  "name": "Acme Corp",
  "slug": "acme-corp"
}

# List organizations
GET /api/v1/organizations

# Get organization
GET /api/v1/organizations/{id}

# Update organization
PATCH /api/v1/organizations/{id}

# Delete organization
DELETE /api/v1/organizations/{id}

# Invite member
POST /api/v1/organizations/{id}/members
{
  "email": "user@example.com",
  "role_id": "uuid"
}

# List members
GET /api/v1/organizations/{id}/members

# Update member role
PATCH /api/v1/organizations/{id}/members/{user_id}

# Remove member
DELETE /api/v1/organizations/{id}/members/{user_id}
```

### Roles

```http
# List roles
GET /api/v1/organizations/{id}/roles

# Create custom role
POST /api/v1/organizations/{id}/roles
{
  "name": "security_analyst",
  "display_name": "Security Analyst",
  "permissions": ["contracts.read", "scans.create"]
}

# Update role
PATCH /api/v1/organizations/{id}/roles/{role_id}

# Delete role
DELETE /api/v1/organizations/{id}/roles/{role_id}
```

### API Keys

```http
# Create API key
POST /api/v1/api-keys
{
  "name": "CI/CD Pipeline",
  "scopes": ["contracts:write", "scans:write"],
  "expires_in_days": 365
}

# List API keys
GET /api/v1/api-keys

# Revoke API key
DELETE /api/v1/api-keys/{id}

# Get API key usage
GET /api/v1/api-keys/{id}/usage
```

### Audit Logs

```http
# List audit logs (admin/auditor only)
GET /api/v1/audit-logs?action=scan.create&from=2025-01-01&to=2025-12-31

# Export audit logs
GET /api/v1/audit-logs/export?format=csv
```

### SSO Configuration

```http
# Get SSO config
GET /api/v1/organizations/{id}/sso

# Configure SAML
POST /api/v1/organizations/{id}/sso/saml
{
  "idp_entity_id": "https://idp.example.com",
  "idp_sso_url": "https://idp.example.com/sso",
  "idp_certificate": "-----BEGIN CERTIFICATE-----..."
}

# Configure OIDC
POST /api/v1/organizations/{id}/sso/oidc
{
  "issuer": "https://auth.example.com",
  "client_id": "...",
  "client_secret": "..."
}

# Test SSO
POST /api/v1/organizations/{id}/sso/test

# Enable/disable SSO
PATCH /api/v1/organizations/{id}/sso
{
  "enabled": true
}
```

## Frontend Components

### Webhook Management

```tsx
// Settings page
<WebhookSettings
  webhooks={webhooks}
  onCreateWebhook={handleCreate}
  onDeleteWebhook={handleDelete}
/>

// Webhook creation form
<WebhookForm
  onSubmit={createWebhook}
  eventTypes={eventTypes}
/>

// Delivery history
<WebhookDeliveryHistory
  webhookId={webhookId}
  deliveries={deliveries}
/>
```

### Organization Management

```tsx
// Organization switcher
<OrganizationSwitcher
  organizations={organizations}
  currentOrg={currentOrg}
  onSwitch={handleSwitch}
/>

// Member management
<MemberList
  members={members}
  roles={roles}
  onInvite={handleInvite}
  onRemove={handleRemove}
  onRoleChange={handleRoleChange}
/>

// Role editor
<RoleEditor
  role={role}
  permissions={allPermissions}
  onSave={handleSave}
/>
```

## Tier Availability

| Feature | Free | Pro | Enterprise |
|---------|------|-----|------------|
| Webhooks | - | 5 webhooks | Unlimited |
| Organizations | - | 1 org | Unlimited |
| Team Members | 1 | 5 | Unlimited |
| Custom Roles | - | - | ✓ |
| SSO (OIDC) | - | - | ✓ |
| SSO (SAML) | - | - | ✓ |
| API Keys | 1 | 5 | Unlimited |
| Audit Logs | 7 days | 30 days | 1 year |
| Audit Export | - | - | ✓ |

## Security Considerations

1. **Webhook Secrets**: Generated using cryptographically secure random bytes
2. **API Keys**: Stored as SHA-256 hashes, full key only shown once
3. **SSO**: Certificate validation for SAML, nonce validation for OIDC
4. **Audit Logs**: Immutable, timestamped, indexed for compliance
5. **Rate Limiting**: Per-key and per-user limits to prevent abuse
6. **Permission Validation**: Checked on every request, not cached

## Migration Notes

1. Run Alembic migration for new tables
2. Seed system roles for RBAC
3. Configure webhook delivery worker
4. Set up audit log retention policy
5. Test SSO with staging IdP before production

## Future Enhancements

1. **Webhook Filters**: Filter events by contract or severity
2. **IP Allowlisting**: Restrict API access by IP
3. **MFA Enforcement**: Require MFA for organization access
4. **SCIM Provisioning**: Automatic user provisioning
5. **Compliance Reports**: SOC 2, ISO 27001 compliance dashboards
