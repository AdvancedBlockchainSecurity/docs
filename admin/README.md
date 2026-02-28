# Administration Guide

Platform administration documentation for Apogee operators and system administrators.

## Overview

This section covers administrative tasks for managing the Apogee platform, including:

- User and team management
- Notification channel configuration
- CLI tool deployment
- System monitoring and maintenance

## Admin Documentation

| Document | Description |
|----------|-------------|
| [Platform Admin Panel](./platform-admin.md) | **NEW** - Internal admin panel with MFA, user management, emergency actions |
| [Notification Channels](./notification-channels.md) | Managing webhook notifications for Slack, Teams, Discord |
| [CLI Deployment](./cli-deployment.md) | Deploying and configuring the CLI tool for organizations |
| [User Management](./user-management.md) | Managing users, tiers, and quotas |
| [System Monitoring](./monitoring.md) | Platform health and performance monitoring |

## Quick Links

### Notification Administration
- [Configure Slack webhooks](./notification-channels.md#slack-configuration)
- [Configure Teams webhooks](./notification-channels.md#teams-configuration)
- [Configure Discord webhooks](./notification-channels.md#discord-configuration)
- [Monitor delivery rates](./notification-channels.md#monitoring-deliveries)
- [Troubleshoot failed notifications](./notification-channels.md#troubleshooting)

### CLI Administration
- [Organization-wide deployment](./cli-deployment.md#organization-deployment)
- [API key management](./cli-deployment.md#api-key-management)
- [Pre-commit hook rollout](./cli-deployment.md#pre-commit-rollout)
- [CI/CD integration patterns](./cli-deployment.md#cicd-patterns)

## Prerequisites

Admin operations require:
- Platform admin access or enterprise tier subscription
- API access with appropriate permissions
- For CLI deployment: ability to manage organization repositories

## Related Documentation

- [API Endpoints Reference](../api/endpoints-reference.md)
- [Database Schema](../database/SCHEMA.md)
- [Feature Tests](../feature-tests/README.md)
