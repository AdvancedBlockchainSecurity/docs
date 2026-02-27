# Notification Channels Administration

Manage webhook notification channels for Slack, Microsoft Teams, and Discord.

## Overview

Notification channels enable automated alerts when security events occur:
- Scan completions
- Critical/high vulnerabilities detected
- Scan failures

Each user can configure multiple notification channels with custom event subscriptions and filters.

## Supported Platforms

| Platform | Format | Features |
|----------|--------|----------|
| Slack | Block Kit | Color-coded severity, action buttons, rich formatting |
| Microsoft Teams | Adaptive Cards | Fact sets, action URLs, team channels |
| Discord | Rich Embeds | Colored sidebar, field layouts, server integration |

---

## Slack Configuration

### Creating a Slack Webhook

1. Go to [Slack API Apps](https://api.slack.com/apps)
2. Create a new app or select existing app
3. Navigate to **Incoming Webhooks**
4. Activate incoming webhooks
5. Click **Add New Webhook to Workspace**
6. Select the channel for notifications
7. Copy the webhook URL

### Slack Webhook URL Format
```
https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
```

### Slack Message Format

Notifications use Slack Block Kit for rich formatting:

```json
{
  "blocks": [
    {
      "type": "header",
      "text": {"type": "plain_text", "text": "Critical Vulnerability Found"}
    },
    {
      "type": "section",
      "fields": [
        {"type": "mrkdwn", "text": "*Contract:*\nMyToken.sol"},
        {"type": "mrkdwn", "text": "*Severity:*\nCritical"}
      ]
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": {"type": "plain_text", "text": "View Details"},
          "url": "https://app.0xapogee.com/scans/..."
        }
      ]
    }
  ]
}
```

### Slack Best Practices

- Create a dedicated `#security-alerts` channel
- Use channel-specific webhooks (not workspace-wide)
- Set appropriate notification preferences in Slack
- Consider separate channels for critical vs. informational alerts

---

## Teams Configuration

### Creating a Teams Webhook

1. Open Microsoft Teams
2. Navigate to the target channel
3. Click **...** (More options) > **Connectors**
4. Find **Incoming Webhook** and click **Configure**
5. Provide a name (e.g., "BlockSecOps Alerts")
6. Optionally upload a custom icon
7. Click **Create** and copy the webhook URL

### Teams Webhook URL Format
```
https://outlook.office.com/webhook/GUID/IncomingWebhook/GUID/GUID
```

### Teams Message Format

Notifications use Adaptive Cards:

```json
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "FF0000",
  "summary": "Critical Vulnerability Found",
  "sections": [{
    "activityTitle": "Critical Vulnerability Found",
    "facts": [
      {"name": "Contract", "value": "MyToken.sol"},
      {"name": "Severity", "value": "Critical"},
      {"name": "Scanner", "value": "Slither"}
    ]
  }],
  "potentialAction": [{
    "@type": "OpenUri",
    "name": "View Details",
    "targets": [{"os": "default", "uri": "https://app.0xapogee.com/..."}]
  }]
}
```

### Teams Best Practices

- Use a dedicated channel for security notifications
- Configure channel notification settings appropriately
- Consider using Teams tags to mention security team members
- Set up channel moderation if needed

---

## Discord Configuration

### Creating a Discord Webhook

1. Open Discord and navigate to your server
2. Click the gear icon next to the channel name
3. Select **Integrations** > **Webhooks**
4. Click **New Webhook**
5. Configure name and avatar (optional)
6. Click **Copy Webhook URL**

### Discord Webhook URL Format
```
https://discord.com/api/webhooks/CHANNEL_ID/TOKEN
```

### Discord Message Format

Notifications use rich embeds:

```json
{
  "embeds": [{
    "title": "Critical Vulnerability Found",
    "color": 16711680,
    "fields": [
      {"name": "Contract", "value": "MyToken.sol", "inline": true},
      {"name": "Severity", "value": "Critical", "inline": true},
      {"name": "Scanner", "value": "Slither", "inline": true}
    ],
    "footer": {"text": "BlockSecOps Security Scanner"},
    "timestamp": "2026-01-04T10:00:00Z"
  }]
}
```

### Discord Best Practices

- Create a dedicated `#security-alerts` channel
- Set appropriate channel permissions
- Consider using Discord roles for @mentions
- Use category organization for security channels

---

## API Management

### Creating a Notification Channel

```bash
curl -X POST https://api.0xapogee.com/api/v1/notification-channels \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Security Alerts - Slack",
    "channel_type": "slack",
    "webhook_url": "https://hooks.slack.com/services/...",
    "events": ["scan.completed", "vulnerability.critical", "vulnerability.high"],
    "filters": {
      "min_severity": "high",
      "project_ids": []
    }
  }'
```

### Available Events

| Event | Description |
|-------|-------------|
| `scan.completed` | Triggered when a scan finishes successfully |
| `scan.failed` | Triggered when a scan encounters an error |
| `vulnerability.critical` | Triggered for critical severity findings |
| `vulnerability.high` | Triggered for high severity findings |

### Event Filters

| Filter | Type | Description |
|--------|------|-------------|
| `min_severity` | string | Minimum severity to trigger: `critical`, `high`, `medium`, `low` |
| `project_ids` | array | Limit to specific projects (empty = all projects) |

### Listing Channels

```bash
curl -X GET https://api.0xapogee.com/api/v1/notification-channels \
  -H "Authorization: Bearer $TOKEN"
```

### Testing a Channel

```bash
curl -X POST https://api.0xapogee.com/api/v1/notification-channels/{id}/test \
  -H "Authorization: Bearer $TOKEN"
```

### Updating a Channel

```bash
curl -X PUT https://api.0xapogee.com/api/v1/notification-channels/{id} \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name",
    "events": ["vulnerability.critical"],
    "is_active": true
  }'
```

### Deleting a Channel

```bash
curl -X DELETE https://api.0xapogee.com/api/v1/notification-channels/{id} \
  -H "Authorization: Bearer $TOKEN"
```

---

## Monitoring Deliveries

### Viewing Delivery History

```bash
curl -X GET "https://api.0xapogee.com/api/v1/notification-channels/{id}/deliveries?limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

### Response Example

```json
{
  "deliveries": [
    {
      "id": "uuid",
      "event_type": "scan.completed",
      "success": true,
      "status_code": 200,
      "duration_ms": 156,
      "error_message": null,
      "created_at": "2026-01-04T10:00:00Z"
    },
    {
      "id": "uuid",
      "event_type": "vulnerability.critical",
      "success": false,
      "status_code": 504,
      "duration_ms": 30000,
      "error_message": "Gateway timeout",
      "created_at": "2026-01-03T15:30:00Z"
    }
  ],
  "total": 45,
  "limit": 20,
  "offset": 0
}
```

### Channel Statistics

Each channel tracks:
- `total_notifications` - Total delivery attempts
- `successful_notifications` - Successful deliveries (2xx response)
- `failed_notifications` - Failed deliveries
- `last_triggered_at` - Last notification attempt
- `last_success_at` - Last successful delivery
- `last_failure_at` - Last failed delivery
- `last_error` - Most recent error message

---

## Troubleshooting

### Common Issues

#### 1. Invalid Webhook URL
**Symptom**: 400 error on channel creation

**Solution**: Verify the webhook URL format matches the expected pattern for the platform.

#### 2. Webhook Timeout
**Symptom**: Deliveries fail with timeout errors

**Causes**:
- Slack/Teams/Discord service outage
- Network connectivity issues
- Webhook endpoint overloaded

**Solution**:
- Check platform status pages
- Review network configuration
- Consider rate limiting notification frequency

#### 3. 403 Forbidden
**Symptom**: Webhook returns 403

**Causes**:
- Webhook was revoked or deleted
- Channel permissions changed
- IP restrictions on webhook

**Solution**:
- Regenerate the webhook URL
- Verify channel permissions
- Check IP allowlists

#### 4. Rate Limiting
**Symptom**: 429 Too Many Requests

**Causes**:
- Too many notifications in short period
- Platform rate limits exceeded

**Solution**:
- Increase `min_severity` filter to reduce volume
- Use project filters to limit scope
- Consider batching notifications (future feature)

### Webhook URL Validation

The system validates webhook URLs on creation:

| Platform | URL Pattern |
|----------|-------------|
| Slack | `https://hooks.slack.com/services/*` |
| Teams | `https://*.office.com/webhook/*` or `https://*.office365.com/webhook/*` |
| Discord | `https://discord.com/api/webhooks/*` or `https://discordapp.com/api/webhooks/*` |

### Testing Connectivity

Use the test endpoint to verify webhook connectivity:

```bash
curl -X POST https://api.0xapogee.com/api/v1/notification-channels/{id}/test \
  -H "Authorization: Bearer $TOKEN"
```

A successful test returns:
```json
{
  "success": true,
  "message": "Test notification sent successfully",
  "status_code": 200,
  "duration_ms": 245
}
```

A failed test returns error details:
```json
{
  "success": false,
  "message": "Webhook delivery failed",
  "status_code": 404,
  "error": "Webhook not found or deleted"
}
```

---

## Dashboard Interface

### Accessing the Dashboard

Navigate to **Admin > Notifications** in the sidebar, or go to `/notification-channels`.

> **Note**: Requires "Startup" tier or higher. Free/Developer tier users will see an upgrade prompt.

### Channel Management Page

The main page displays:

| Element | Description |
|---------|-------------|
| Stats Cards | Total channels, active count, delivered/failed totals |
| Channels Table | List of all configured channels with status and stats |
| Add Channel Button | Opens create modal |

### Creating a Channel

1. Click **Add Channel**
2. Select channel type (Slack, Teams, or Discord)
3. Enter a descriptive name
4. Paste the webhook URL
5. Select events to subscribe to
6. (Optional) Set minimum severity filter
7. Click **Create Channel**

### Managing Channels

Each channel row has action buttons:

| Button | Action |
|--------|--------|
| Test (play icon) | Send test notification |
| History (clock icon) | View delivery history |
| Edit (pencil icon) | Modify channel settings |
| Delete (trash icon) | Remove channel |

Click the status badge (Active/Paused) to quickly toggle the channel.

### Editing a Channel

- Change the channel name
- Modify subscribed events
- Adjust severity filter
- Toggle active/inactive status

> **Note**: Webhook URL cannot be changed after creation. Delete and recreate the channel if the URL needs to change.

### Viewing Delivery History

1. Click the history button on a channel
2. View summary statistics (total, success, failed)
3. Filter by status: All / Delivered / Failed
4. Each entry shows:
   - Event type
   - Success/failure status
   - Timestamp and relative time
   - HTTP status code
   - Response duration
   - Error message (if failed)

### Testing a Channel

1. Click the test button on a channel
2. Click **Send Test** in the modal
3. Wait for response
4. View success/failure result with:
   - HTTP status code
   - Response time
   - Error details (if failed)
5. Click **Try Again** if the test failed

---

## Security Considerations

### Webhook URL Security

- Webhook URLs contain secrets - treat them as credentials
- Never log or expose webhook URLs in error messages
- Rotate webhooks if potentially compromised
- Use HTTPS-only webhooks (enforced by all platforms)

### Access Control

- Each user can only manage their own notification channels
- Channels cannot be shared between users (use team features for shared notifications)
- API authentication required for all channel operations
- Dashboard requires "Startup" tier or higher

### Data in Notifications

Notifications include:
- Contract names and scan IDs
- Vulnerability counts and severities
- Links to dashboard (authenticated)

Notifications do NOT include:
- Full vulnerability details
- Source code snippets
- User credentials or tokens
