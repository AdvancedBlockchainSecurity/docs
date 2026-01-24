# Integrations Database Tables

**Status:** Planned (Frontend Implemented, Awaiting Backend)
**Date:** January 23, 2026
**Migration Number:** TBD

---

## Overview

Database tables required for the platform integrations feature (GitHub, GitLab, Bitbucket, Jira).

---

## Tables

### integrations

Main table storing integration connections.

```sql
CREATE TABLE integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    provider VARCHAR(20) NOT NULL CHECK (provider IN ('github', 'gitlab', 'bitbucket', 'jira')),
    name VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'connected', 'expired', 'error')),

    -- OAuth tokens (encrypted)
    access_token_encrypted BYTEA,
    refresh_token_encrypted BYTEA,
    token_expires_at TIMESTAMPTZ,

    -- External account info
    external_account_id VARCHAR(255),
    external_username VARCHAR(255),
    external_avatar_url TEXT,

    -- Jira-specific fields
    jira_cloud_id VARCHAR(255),
    jira_site_url TEXT,

    -- Settings (JSON)
    settings JSONB NOT NULL DEFAULT '{}',

    -- Stats
    repos_synced INTEGER NOT NULL DEFAULT 0,
    last_sync_at TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    UNIQUE (organization_id, provider, external_account_id)
);

CREATE INDEX idx_integrations_org ON integrations(organization_id);
CREATE INDEX idx_integrations_provider ON integrations(provider);
CREATE INDEX idx_integrations_status ON integrations(status);
```

### integration_repositories

Repositories connected via VCS integrations.

```sql
CREATE TABLE integration_repositories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_id UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,

    -- External repo info
    external_repo_id VARCHAR(255) NOT NULL,
    repo_name VARCHAR(255) NOT NULL,
    repo_full_name VARCHAR(500) NOT NULL,
    repo_url TEXT NOT NULL,
    default_branch VARCHAR(255),
    is_private BOOLEAN NOT NULL DEFAULT false,

    -- Scan settings
    auto_scan_enabled BOOLEAN NOT NULL DEFAULT false,
    scan_on_push BOOLEAN NOT NULL DEFAULT false,
    scan_on_pr BOOLEAN NOT NULL DEFAULT false,

    -- Sync state
    last_synced_at TIMESTAMPTZ,
    last_synced_commit VARCHAR(40),
    contracts_found INTEGER NOT NULL DEFAULT 0,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'synced', 'error')),
    sync_error TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    UNIQUE (integration_id, external_repo_id)
);

CREATE INDEX idx_int_repos_integration ON integration_repositories(integration_id);
CREATE INDEX idx_int_repos_project ON integration_repositories(project_id);
CREATE INDEX idx_int_repos_sync_status ON integration_repositories(sync_status);
```

### jira_project_mappings

Jira project mappings for vulnerability sync.

```sql
CREATE TABLE jira_project_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_id UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
    blocksecops_project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,

    -- Jira project info
    jira_project_id VARCHAR(255) NOT NULL,
    jira_project_key VARCHAR(20) NOT NULL,
    jira_project_name VARCHAR(255) NOT NULL,

    -- Sync settings
    issue_type VARCHAR(50) NOT NULL DEFAULT 'Bug',
    auto_create_issues BOOLEAN NOT NULL DEFAULT false,
    min_severity_to_sync VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (min_severity_to_sync IN ('critical', 'high', 'medium', 'low')),

    -- Field mappings (JSON)
    field_mappings JSONB NOT NULL DEFAULT '{}',

    -- Stats
    issues_created INTEGER NOT NULL DEFAULT 0,
    last_sync_at TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    UNIQUE (integration_id, blocksecops_project_id, jira_project_id)
);

CREATE INDEX idx_jira_mappings_integration ON jira_project_mappings(integration_id);
CREATE INDEX idx_jira_mappings_project ON jira_project_mappings(blocksecops_project_id);
```

### jira_issue_links

Track which vulnerabilities have been synced to Jira.

```sql
CREATE TABLE jira_issue_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mapping_id UUID NOT NULL REFERENCES jira_project_mappings(id) ON DELETE CASCADE,
    vulnerability_id UUID NOT NULL REFERENCES vulnerabilities(id) ON DELETE CASCADE,

    -- Jira issue info
    jira_issue_id VARCHAR(255) NOT NULL,
    jira_issue_key VARCHAR(50) NOT NULL,
    jira_issue_url TEXT NOT NULL,

    -- Sync state
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_direction VARCHAR(20) NOT NULL DEFAULT 'to_jira' CHECK (sync_direction IN ('to_jira', 'from_jira', 'bidirectional')),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    UNIQUE (mapping_id, vulnerability_id)
);

CREATE INDEX idx_jira_links_mapping ON jira_issue_links(mapping_id);
CREATE INDEX idx_jira_links_vuln ON jira_issue_links(vulnerability_id);
CREATE INDEX idx_jira_links_issue ON jira_issue_links(jira_issue_key);
```

---

## Encryption

OAuth tokens must be encrypted at rest using Vault Transit secrets engine:

```python
# Example: Encrypt access token before storage
encrypted_token = vault_client.secrets.transit.encrypt_data(
    name='integrations',
    plaintext=base64.b64encode(access_token.encode()).decode()
)
```

---

## Tier Enforcement

Backend should enforce tier requirements:

| Provider | Required Tier | Check |
|----------|---------------|-------|
| github | team | `user.tier >= 'team'` |
| gitlab | team | `user.tier >= 'team'` |
| bitbucket | team | `user.tier >= 'team'` |
| jira | enterprise | `user.tier == 'enterprise'` |

---

## Related Documentation

- [Frontend Implementation](../../TaskDocs-BlockSecOps/phases/2026-01-23-platform-integrations.md)
- [Feature Tests](../feature-tests/44-platform-integrations.md)
- [User Documentation](../../blocksecops-docs/platform/integrations/README.md)
