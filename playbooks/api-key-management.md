# Playbook: API Key Management

**Version:** 1.0.0
**Last Updated:** February 1, 2026
**Audience:** Developer | Admin

## Overview

This playbook covers creating, scoping, rotating, and revoking API keys for programmatic access to the BlockSecOps platform. API keys enable CI/CD integrations, CLI tools, and automated scanning workflows.

---

## Prerequisites

- [ ] Active BlockSecOps account
- [ ] Authenticated session (email/password or wallet)
- [ ] Growth or Enterprise tier subscription (API keys not available on Free tier)
- [ ] Understanding of required scopes for your use case

---

## Workflow Diagram

```mermaid
flowchart LR
    A[Navigate to API Keys] --> B[Create New Key]
    B --> C[Name & Description]
    C --> D[Select Scopes]
    D --> E[Set Expiration]
    E --> F[Generate Key]
    F --> G[Copy & Store Key]
    G --> H[Use in Application]
```

---

## API Key Scopes Reference

| Scope | Description | Use Case |
|-------|-------------|----------|
| `read:scans` | View scan results | Read-only dashboards, reporting |
| `write:scans` | Create and manage scans | CI/CD pipelines, automated scanning |
| `read:vulnerabilities` | View vulnerability details | Security reporting, integrations |
| `write:vulnerabilities` | Update vulnerability status | Triage workflows, bulk updates |
| `read:projects` | View project information | Project listing, overview |
| `write:projects` | Create and manage projects | Automated project setup |
| `read:contracts` | View contract details | Contract analysis tools |
| `write:contracts` | Upload and manage contracts | CI/CD contract upload |
| `admin:organization` | Organization administration | Team management, settings |

---

## Steps

### Step 1: Navigate to API Keys

**Dashboard:**
1. Click your profile icon in the top-right corner
2. Select **Settings** from the dropdown
3. Click **API Keys** in the left sidebar
4. Or navigate directly to `https://app.0xapogee.com/settings/api-keys`

### Step 2: Create New API Key

**Dashboard:**
1. Click **Create API Key** button
2. Enter a descriptive name (e.g., "GitHub Actions CI", "Jenkins Production")
3. Add an optional description

**API:**
```bash
curl -X POST "https://app.0xapogee.com/api/v1/api_keys" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "GitHub Actions CI",
    "description": "API key for GitHub Actions CI/CD pipeline",
    "scopes": ["read:scans", "write:scans", "read:vulnerabilities"],
    "expires_at": "2027-02-01T00:00:00Z"
  }'
```

### Step 3: Select Scopes

**Dashboard:**
1. Check the boxes for required scopes
2. Follow the principle of least privilege - only select what's needed

**Common Scope Combinations:**

| Use Case | Recommended Scopes |
|----------|-------------------|
| CI/CD Scanning | `write:scans`, `read:scans`, `write:contracts`, `read:vulnerabilities` |
| Read-Only Reporting | `read:scans`, `read:vulnerabilities`, `read:projects` |
| Full Automation | `write:scans`, `read:scans`, `write:contracts`, `read:contracts`, `write:vulnerabilities`, `read:vulnerabilities` |
| Admin Tools | All scopes including `admin:organization` |

### Step 4: Set Expiration

**Dashboard:**
1. Select expiration period:
   - **30 days** - Short-term testing
   - **90 days** - Standard CI/CD keys
   - **1 year** - Long-running integrations
   - **Custom** - Specify exact date
   - **Never** - No expiration (not recommended)

**Best Practice:** Set expiration to align with your security rotation policy (typically 90 days).

### Step 5: Generate and Store Key

**Dashboard:**
1. Click **Generate API Key**
2. **IMPORTANT:** Copy the API key immediately
3. The full key is only shown once and cannot be retrieved later
4. Store securely in a password manager or secrets vault

**API Response:**
```json
{
  "id": "key_abc123def456",
  "name": "GitHub Actions CI",
  "key": "bso_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "scopes": ["read:scans", "write:scans", "read:vulnerabilities"],
  "created_at": "2026-02-01T10:00:00Z",
  "expires_at": "2027-02-01T00:00:00Z",
  "last_used_at": null
}
```

**Key Format:**
- Production keys: `bso_live_xxxxxxxx...`
- Test/sandbox keys: `bso_test_xxxxxxxx...`

---

## Managing Existing Keys

### List API Keys

**Dashboard:**
1. Navigate to **Settings > API Keys**
2. View all active keys with last-used timestamps

**API:**
```bash
curl -X GET "https://app.0xapogee.com/api/v1/api_keys" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### View Key Details

**API:**
```bash
curl -X GET "https://app.0xapogee.com/api/v1/api_keys/{key_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Rotate API Key

To rotate a key (create new, revoke old):

**Dashboard:**
1. Navigate to **Settings > API Keys**
2. Click the **...** menu on the key to rotate
3. Select **Rotate Key**
4. Copy the new key immediately
5. Update your applications with the new key
6. The old key is automatically revoked

**API (Manual Rotation):**
```bash
# Step 1: Create new key with same scopes
NEW_KEY=$(curl -X POST "https://app.0xapogee.com/api/v1/api_keys" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "GitHub Actions CI (Rotated)",
    "scopes": ["read:scans", "write:scans", "read:vulnerabilities"],
    "expires_at": "2027-05-01T00:00:00Z"
  }')

# Step 2: Update applications with new key

# Step 3: Revoke old key
curl -X DELETE "https://app.0xapogee.com/api/v1/api_keys/{old_key_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Revoke API Key

**Dashboard:**
1. Navigate to **Settings > API Keys**
2. Click the **...** menu on the key to revoke
3. Select **Revoke Key**
4. Confirm revocation

**API:**
```bash
curl -X DELETE "https://app.0xapogee.com/api/v1/api_keys/{key_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

---

## Using API Keys

### Authentication Header

Include the API key in the `Authorization` header:

```bash
curl -X GET "https://app.0xapogee.com/api/v1/scans" \
  -H "Authorization: Bearer bso_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### Environment Variable (Recommended)

Store API key in environment variable:

```bash
export APOGEE_API_KEY="bso_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

curl -X GET "https://app.0xapogee.com/api/v1/scans" \
  -H "Authorization: Bearer $APOGEE_API_KEY"
```

### GitHub Actions Secret

```yaml
# .github/workflows/security-scan.yml
env:
  APOGEE_API_KEY: ${{ secrets.APOGEE_API_KEY }}
```

---

## Verification

Confirm API key works:

**API:**
```bash
# Test API key authentication
curl -X GET "https://app.0xapogee.com/api/v1/users/me" \
  -H "Authorization: Bearer $APOGEE_API_KEY"
```

Expected response:
```json
{
  "id": "user_xyz789",
  "email": "user@example.com",
  "api_key_id": "key_abc123def456",
  "api_key_scopes": ["read:scans", "write:scans", "read:vulnerabilities"]
}
```

### Verify Scopes

```bash
# This will fail if key lacks write:scans scope
curl -X POST "https://app.0xapogee.com/api/v1/scans" \
  -H "Authorization: Bearer $APOGEE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "proj_123", "contract_id": "contract_456"}'
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Invalid or expired API key | Generate new key, check expiration |
| 403 Forbidden | Missing required scope | Create new key with needed scopes |
| "API keys not available" | Free tier subscription | Upgrade to Growth or Enterprise tier |
| Key not working after rotation | Using old key | Update application with new key |
| Rate limit exceeded | Too many requests | Implement exponential backoff, contact support for limit increase |

---

## Security Best Practices

1. **Least Privilege:** Only grant scopes that are actually needed
2. **Short Expiration:** Prefer 90-day expiration over "Never expires"
3. **Secure Storage:** Use secrets managers (Vault, AWS Secrets Manager, GitHub Secrets)
4. **Regular Rotation:** Rotate keys at least quarterly
5. **Audit Usage:** Review `last_used_at` timestamps regularly
6. **Revoke Unused:** Delete keys that haven't been used in 30+ days
7. **Separate Keys:** Use different keys for different environments (dev, staging, prod)

---

## Checklist

- [ ] Navigated to API Keys settings
- [ ] Created new API key with descriptive name
- [ ] Selected appropriate scopes (least privilege)
- [ ] Set reasonable expiration date
- [ ] Copied and stored key securely
- [ ] Tested API key authentication
- [ ] Added key to application/CI configuration
- [ ] Documented key purpose and owner

---

## Related Playbooks

- [GitHub Actions Integration](./cicd-github-actions.md) - Use API keys in GitHub Actions
- [CLI Installation](./cli-installation.md) - Configure CLI with API key
- [Connect Wallet](./connect-wallet.md) - Alternative authentication method
