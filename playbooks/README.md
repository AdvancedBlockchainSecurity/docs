# Playbooks

Step-by-step operational guides for common tasks.

## Available Playbooks

### Authentication & Wallet

| Playbook | Description |
|----------|-------------|
| [Connect Wallet](connect-wallet.md) | MetaMask/WalletConnect SIWE authentication for x402 payments |
| [Link Wallet to Account](link-wallet-to-account.md) | Add wallet to existing email account |
| [API Key Management](api-key-management.md) | Create, scope, and rotate API keys |

### CI/CD Integration

| Playbook | Description |
|----------|-------------|
| [GitHub Actions Integration](cicd-github-actions.md) | Scan on PR, block merge on critical findings |
| [GitLab CI Integration](cicd-gitlab-ci.md) | GitLab pipeline integration |
| [Jenkins Integration](cicd-jenkins.md) | Jenkins pipeline scanning |
| [Generic Webhook CI/CD](cicd-webhook-generic.md) | Any CI system using webhooks + API |

### ChatOps & Notifications

| Playbook | Description |
|----------|-------------|
| [Slack Integration](chatops-slack.md) | Slack notifications and alerts |
| [Microsoft Teams Integration](chatops-teams.md) | Teams channel notifications |
| [Discord Integration](chatops-discord.md) | Discord webhook alerts |
| [Email Notifications](notifications-email.md) | Email alert configuration |

### Organization & Team Management

| Playbook | Description |
|----------|-------------|
| [Organization, Team, and Project Setup](organization-team-setup.md) | Complete guide for organizations, teams, projects, and user access |
| [Create Organization](create-organization.md) | Enterprise org setup |
| [Create and Manage Teams](create-team.md) | Team creation and member management |
| [Configure Roles and Permissions](configure-roles.md) | RBAC setup (owner/admin/developer/auditor/guest) |
| [Invite Team Members](invite-team-members.md) | Invite external users to org/team |

### Project & Scanning Workflows

| Playbook | Description |
|----------|-------------|
| [Create Project](create-project.md) | Set up a new scanning project |
| [Run First Scan](run-first-scan.md) | Upload contract and run scan |
| [Batch Scanning](batch-scanning.md) | Scan multiple contracts at once |
| [Schedule Recurring Scans](schedule-scans.md) | Automated scan scheduling |

### Developer Integration

| Playbook | Description |
|----------|-------------|
| [VS Code Extension Setup](ide-vscode.md) | Install and configure VS Code extension |
| [JetBrains Plugin Setup](ide-jetbrains.md) | IntelliJ/WebStorm plugin setup |
| [CLI Installation](cli-installation.md) | Install and configure BlockSecOps CLI |

### Issue Tracking Integration

| Playbook | Description |
|----------|-------------|
| [JIRA Integration](integration-jira.md) | Create JIRA issues from vulnerabilities |
| [GitHub Issues Integration](integration-github-issues.md) | Sync findings to GitHub Issues |

### Deployment

| Playbook | Description |
|----------|-------------|
| [Deploy New Image](deploy-new-image.md) | Build, push, and deploy a new Docker image to the cluster |
| [Upgrade Scanner Image](upgrade-scanner-image.md) | Upgrade a scanner image with dual versioning (tool + wrapper) |
| [Docker Cleanup](docker-cleanup.md) | Safely clean up Docker images and build cache without affecting Harbor |

### Pricing & Billing

| Playbook | Description |
|----------|-------------|
| [Adjust Pricing](adjust-pricing.md) | Update pricing tiers, quotas, features, and credit packages using the centralized tier config |
| [Adjust Rate Limits](adjust-rate-limits.md) | Update endpoint-specific rate limits via centralized configuration |

### Platform Admin Panel

| Playbook | Description |
|----------|-------------|
| [Admin CLI Commands](admin-cli-commands.md) | All admin CLI commands: create-admin, list, reset-mfa, unlock-mfa, set-tier |
| [Admin Account Setup](admin-account-setup.md) | Create admin accounts and configure MFA |
| [Admin MFA Lockout Reset](admin-mfa-lockout-reset.md) | Reset MFA lockout for admins who exceeded failed attempts |
| [Admin Session Management](admin-session-management.md) | View, revoke, and troubleshoot admin sessions |
| [Admin Emergency Operations](admin-emergency-operations.md) | Emergency disable users, revoke admin access, incident response |

### AI/ML Operations

| Playbook | Description |
|----------|-------------|
| [AI/ML Comprehensive Audit](ai-ml-audit-playbook.md) | Audit all AI/ML features: patterns, deduplication, ML endpoints, frontend components |
| [SCM PR Creation from AI Repair](scm-pr-creation.md) | Create GitHub/GitLab pull requests directly from AI-generated code repairs |

## Playbook Format

Each playbook follows this structure:

1. **Overview** - What the playbook accomplishes
2. **Prerequisites** - What you need before starting
3. **Workflow Diagram** - Mermaid flowchart of the process
4. **Steps** - Numbered steps with Dashboard UI and API methods
5. **Verification** - How to confirm success
6. **Troubleshooting** - Common issues and fixes
7. **Checklist** - Summary checklist
8. **Related Playbooks** - Links to related guides

## Quick Start by Role

### End Users
1. [Connect Wallet](connect-wallet.md) or sign up with email
2. [Create Project](create-project.md)
3. [Run First Scan](run-first-scan.md)

### Developers
1. [API Key Management](api-key-management.md)
2. [CLI Installation](cli-installation.md) or [VS Code Extension](ide-vscode.md)
3. [GitHub Actions Integration](cicd-github-actions.md)

### Team Leads / Admins
1. [Create Organization](create-organization.md)
2. [Create and Manage Teams](create-team.md)
3. [Configure Roles and Permissions](configure-roles.md)
4. [Slack Integration](chatops-slack.md)

## Contributing

When adding a new playbook:

1. Use the existing playbooks as a template
2. Include all sections listed above
3. Include both Dashboard and API methods where applicable
4. Add mermaid workflow diagrams
5. Test all commands before documenting
6. Keep commands copy-pasteable
7. Add to this README's table
8. Link to related playbooks
