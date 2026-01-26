# Playbooks

Step-by-step operational guides for common tasks.

## Available Playbooks

### Deployment

| Playbook | Description |
|----------|-------------|
| [Deploy New Image](deploy-new-image.md) | Build, push, and deploy a new Docker image to the cluster |

### User & Organization Management

| Playbook | Description |
|----------|-------------|
| [Organization, Team, and Project Setup](organization-team-setup.md) | Create organizations, teams, projects, and manage user access |

### Platform Admin Panel

| Playbook | Description |
|----------|-------------|
| [Admin CLI Commands](admin-cli-commands.md) | All admin CLI commands: create-admin, list, reset-mfa, unlock-mfa, set-tier |
| [Admin Account Setup](admin-account-setup.md) | Create admin accounts and configure MFA |
| [Admin MFA Lockout Reset](admin-mfa-lockout-reset.md) | Reset MFA lockout for admins who exceeded failed attempts |
| [Admin Session Management](admin-session-management.md) | View, revoke, and troubleshoot admin sessions |
| [Admin Emergency Operations](admin-emergency-operations.md) | Emergency disable users, revoke admin access, incident response |

## Playbook Format

Each playbook follows this structure:

1. **Overview** - What the playbook accomplishes
2. **Prerequisites** - What you need before starting
3. **Steps** - Numbered steps with commands
4. **Verification** - How to confirm success
5. **Rollback** - How to undo if needed
6. **Troubleshooting** - Common issues and fixes
7. **Checklist** - Summary checklist

## Contributing

When adding a new playbook:

1. Use the existing playbooks as a template
2. Include all sections listed above
3. Test all commands before documenting
4. Keep commands copy-pasteable
5. Add to this README's table
