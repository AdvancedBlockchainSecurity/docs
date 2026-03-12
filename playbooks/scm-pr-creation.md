# SCM Pull Request Creation from AI Repair

**Last Updated:** February 19, 2026

## Overview

Create pull requests directly from AI-generated code repairs. After generating a repair for a vulnerability, users can push the fix to their connected GitHub or GitLab repository as a pull request — without leaving the Apogee dashboard.

## Prerequisites

- Team+ tier subscription
- SCM integration connected (GitHub or GitLab) via Settings → Integrations
- Repository linked to a project
- AI repair generated for a vulnerability with a `file_path`

## Workflow Diagram

```mermaid
flowchart TD
    A[View Vulnerability Detail] --> B[Generate AI Repair]
    B --> C{Repair successful?}
    C -->|Yes| D[Click 'Create Pull Request']
    C -->|No| E[Fix errors, retry]
    D --> F[Confirm branch name + PR title]
    F --> G[POST /integrations/{id}/repositories/{repo_id}/pull-requests]
    G --> H{SCM Provider}
    H -->|GitHub| I[GitHub REST API v3]
    H -->|GitLab| J[GitLab REST API v4]
    I --> K[PR URL returned]
    J --> K
    K --> L[PR link displayed on repair card]
```

## Steps

### Dashboard UI

1. Navigate to a vulnerability detail page (`/vulnerabilities/:id`)
2. Click **"Generate AI Repair"** in the AI Actions panel
3. Wait for repair to complete
4. Click **"Create Pull Request"** on the repair card (visible when repair has `file_path` and SCM integration is connected)
5. Review the pre-filled fields:
   - **Branch name:** `blocksecops/fix-{vulnerability_id_short}`
   - **PR title:** `fix: {vulnerability title}`
   - **PR body:** Auto-generated with vulnerability details and repair explanation
   - **Base branch:** `main` (configurable)
6. Click **"Create"**
7. PR URL is displayed — click to view on GitHub/GitLab

### API Method

```bash
# Create PR from repair
curl -X POST https://app.0xapogee.com/api/v1/integrations/{integration_id}/repositories/{repo_id}/pull-requests \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "repair_id": "uuid-of-repair",
    "branch_name": "blocksecops/fix-reentrancy",
    "pr_title": "fix: Patch reentrancy vulnerability in withdraw()",
    "pr_body": "## AI-Generated Fix\n\nPatches reentrancy vulnerability detected by SolidityDefend.\n\n### Changes\n- Add ReentrancyGuard modifier\n- Move state update before external call",
    "base_branch": "main"
  }'
```

**Response:**

```json
{
  "pr_url": "https://github.com/org/repo/pull/42",
  "pr_number": 42,
  "branch_name": "blocksecops/fix-reentrancy",
  "status": "created"
}
```

## Verification

- [ ] PR appears on GitHub/GitLab with correct title and body
- [ ] Branch contains the repaired file with correct diff
- [ ] PR URL is clickable from the dashboard repair card
- [ ] Branch name is sanitized (no special characters)

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "Create PR" button not visible | No SCM integration connected or repair has no `file_path` | Connect GitHub/GitLab in Settings → Integrations |
| 403 Forbidden | User not member of organization that owns integration | Verify org membership |
| "Integration not connected" | OAuth token expired or revoked | Re-authorize integration |
| Branch already exists | Previous PR attempt created the branch | Use a different branch name or delete the old branch |

## Security Notes

- Branch names are sanitized: `[^a-zA-Z0-9._/-]` replaced with `-`, max 100 characters
- OAuth tokens are decrypted only at use time and never logged
- Integration must have `status="connected"` — disconnected integrations cannot create PRs
- User must have verified org membership before PR creation

## Checklist

- [ ] SCM integration connected and authorized
- [ ] AI repair generated successfully
- [ ] PR title and body reviewed
- [ ] Branch name confirmed
- [ ] PR created and URL accessible

## Related Playbooks

- [GitHub Actions Integration](cicd-github-actions.md)
- [GitLab CI Integration](cicd-gitlab-ci.md)
- [API Key Management](api-key-management.md)

## Related Documentation

- [AI Features Workflow](../workflows/ai-features-workflow.md) — Full AI workflow including SCM PR creation
- [AI Code Repair Pipeline](../pipelines/ai-code-repair-pipeline.md) — Repair generation details
- [Platform Integrations Tests](../feature-tests/44-platform-integrations.md) — Integration test cases
