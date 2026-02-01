# Playbook: Slack Integration

**Version:** 1.0.0
**Last Updated:** February 1, 2026
**Audience:** Admin | Team Lead

## Overview

This playbook guides you through integrating BlockSecOps with Slack for real-time notifications about security scans, vulnerability discoveries, and platform events. Configure channel-specific alerts and customize notification triggers.

---

## Prerequisites

- [ ] BlockSecOps account with Growth or Enterprise tier
- [ ] Slack workspace admin access (or permission to add apps)
- [ ] Slack channel(s) designated for security notifications
- [ ] Organization owner or admin role in BlockSecOps

---

## Workflow Diagram

```mermaid
flowchart LR
    A[BlockSecOps Event] --> B[Notification Service]
    B --> C{Channel Config?}
    C -->|Matches| D[Format Message]
    D --> E[Send to Slack]
    E --> F[Slack Channel]
    C -->|No Match| G[Skip Notification]
```

---

## Steps

### Step 1: Create Slack Webhook URL

**Slack:**
1. Go to [Slack API Apps](https://api.slack.com/apps)
2. Click **Create New App**
3. Select **From scratch**
4. Name: `BlockSecOps Notifications`
5. Select your workspace
6. Click **Create App**

**Configure Incoming Webhooks:**
1. In the app settings, click **Incoming Webhooks**
2. Toggle **Activate Incoming Webhooks** to On
3. Click **Add New Webhook to Workspace**
4. Select the channel for notifications (e.g., `#security-alerts`)
5. Click **Allow**
6. Copy the **Webhook URL** (starts with `https://hooks.slack.com/services/...`)

### Step 2: Add Slack Integration in BlockSecOps

**Dashboard:**
1. Navigate to **Settings > Integrations**
2. Click **Add Integration**
3. Select **Slack**
4. Enter the webhook URL from Step 1
5. Name the integration (e.g., "Security Alerts Channel")
6. Click **Save**

**API:**
```bash
curl -X POST "https://app.blocksecops.com/api/v1/notification_channels" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Security Alerts Channel",
    "type": "slack",
    "config": {
      "webhook_url": "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
    },
    "enabled": true
  }'
```

### Step 3: Configure Notification Triggers

**Dashboard:**
1. After adding the integration, click **Configure**
2. Select which events trigger notifications:

| Event | Description | Recommended |
|-------|-------------|-------------|
| Scan Started | Notification when scan begins | Optional |
| Scan Completed | Summary when scan finishes | Yes |
| Critical Vulnerability Found | Immediate alert for critical issues | Yes |
| High Vulnerability Found | Alert for high-severity issues | Yes |
| Scan Failed | Alert when scan errors occur | Yes |
| Weekly Summary | Weekly vulnerability digest | Optional |

3. Click **Save Configuration**

**API:**
```bash
curl -X PATCH "https://app.blocksecops.com/api/v1/notification_channels/{channel_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "triggers": [
      "scan_completed",
      "vulnerability_critical",
      "vulnerability_high",
      "scan_failed"
    ]
  }'
```

### Step 4: Configure Channel-Specific Routing (Optional)

For different notification types to different channels:

**Dashboard:**
1. Create multiple Slack integrations (repeat Steps 1-3)
2. Configure each with different triggers:
   - `#security-critical` - Critical/High vulnerabilities only
   - `#security-scans` - All scan events
   - `#security-weekly` - Weekly summaries

**API:**
```bash
# Critical alerts channel
curl -X POST "https://app.blocksecops.com/api/v1/notification_channels" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Critical Alerts",
    "type": "slack",
    "config": {
      "webhook_url": "https://hooks.slack.com/services/..."
    },
    "triggers": ["vulnerability_critical"]
  }'

# Scan updates channel
curl -X POST "https://app.blocksecops.com/api/v1/notification_channels" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Scan Updates",
    "type": "slack",
    "config": {
      "webhook_url": "https://hooks.slack.com/services/..."
    },
    "triggers": ["scan_started", "scan_completed", "scan_failed"]
  }'
```

### Step 5: Test the Integration

**Dashboard:**
1. Click **Test** next to the Slack integration
2. A test message is sent to the configured channel
3. Verify the message appears in Slack

**API:**
```bash
curl -X POST "https://app.blocksecops.com/api/v1/notification_channels/{channel_id}/test" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

---

## Message Formats

### Scan Completed

```
:mag: *Scan Completed*
*Project:* MyToken
*Status:* Completed with findings
*Duration:* 2m 34s

*Findings:*
:red_circle: Critical: 2
:orange_circle: High: 5
:yellow_circle: Medium: 12
:white_circle: Low: 8

<https://app.blocksecops.com/scans/abc123|View Full Report>
```

### Critical Vulnerability Alert

```
:rotating_light: *Critical Vulnerability Detected*

*Vulnerability:* Reentrancy in withdraw()
*Contract:* contracts/Vault.sol
*Line:* 142
*Severity:* Critical

*Description:* External call before state update allows reentrancy attack.

<https://app.blocksecops.com/vulnerabilities/xyz789|View Details>
```

### Weekly Summary

```
:chart_with_upwards_trend: *Weekly Security Summary*
*Period:* Jan 27 - Feb 1, 2026

*Scans:* 24 completed
*New Vulnerabilities:* 47

*By Severity:*
:red_circle: Critical: 3
:orange_circle: High: 12
:yellow_circle: Medium: 18
:white_circle: Low: 14

*Top Issues:*
1. Reentrancy (8 occurrences)
2. Unchecked Return Values (6 occurrences)
3. Integer Overflow (5 occurrences)

<https://app.blocksecops.com/reports/weekly|View Full Report>
```

---

## Advanced Configuration

### Filter by Project

Send notifications only for specific projects:

**API:**
```bash
curl -X PATCH "https://app.blocksecops.com/api/v1/notification_channels/{channel_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filters": {
      "projects": ["proj_abc123", "proj_def456"]
    }
  }'
```

### Filter by Severity

Only notify for specific severity levels:

**API:**
```bash
curl -X PATCH "https://app.blocksecops.com/api/v1/notification_channels/{channel_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filters": {
      "min_severity": "high"
    }
  }'
```

### Custom Message Format

Customize the Slack message format:

**API:**
```bash
curl -X PATCH "https://app.blocksecops.com/api/v1/notification_channels/{channel_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "message_template": "custom",
      "include_code_snippet": true,
      "mention_on_critical": "@security-team"
    }
  }'
```

---

## Verification

Confirm the integration is working:

**Dashboard:**
1. Navigate to **Settings > Integrations**
2. Check the Slack integration shows **Connected** status
3. View **Last Notification** timestamp

**API:**
```bash
# Check channel status
curl -X GET "https://app.blocksecops.com/api/v1/notification_channels/{channel_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# View notification history
curl -X GET "https://app.blocksecops.com/api/v1/notification_channels/{channel_id}/history" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Slack:**
1. Run a security scan
2. Verify notification appears in the configured channel
3. Check message formatting is correct

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "Webhook URL invalid" | Malformed or expired URL | Generate new webhook URL in Slack |
| Test message not arriving | Channel permissions | Verify bot has access to channel |
| "Channel not found" | Webhook for wrong channel | Create webhook for correct channel |
| Duplicate notifications | Multiple integrations configured | Remove duplicate integrations |
| Missing notifications | Triggers not configured | Add required event triggers |
| "Rate limited" | Too many notifications | Reduce trigger frequency, batch notifications |

### Debug Webhook

Test the webhook directly:
```bash
curl -X POST "https://hooks.slack.com/services/T00000000/B00000000/XXXX" \
  -H "Content-Type: application/json" \
  -d '{"text": "Test message from BlockSecOps"}'
```

---

## Checklist

- [ ] Slack app created in workspace
- [ ] Incoming webhook activated
- [ ] Webhook URL copied
- [ ] Integration added in BlockSecOps
- [ ] Notification triggers configured
- [ ] Test message received in Slack
- [ ] Channel routing configured (if using multiple channels)
- [ ] Filters applied (optional)
- [ ] Real scan notification verified

---

## Related Playbooks

- [Microsoft Teams Integration](./chatops-teams.md) - Teams notifications
- [Discord Integration](./chatops-discord.md) - Discord webhook alerts
- [Email Notifications](./notifications-email.md) - Email alert configuration
- [Create Organization](./create-organization.md) - Org-level notification settings
