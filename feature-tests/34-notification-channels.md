# 34. Notification Channels

Test Slack, Teams, and Discord webhook notification integrations.

---

## Prerequisites

- [ ] Authenticated user account
- [ ] Slack webhook URL (from Slack workspace settings)
- [ ] Teams webhook URL (from Teams channel connectors)
- [ ] Discord webhook URL (from Discord server settings)

---

## 1. API Endpoints

### 1.1 List Available Events

```bash
GET /api/v1/notification-channels/events
```

**Expected Response:**
```json
{
  "events": [
    {"id": "scan.completed", "name": "Scan Completed", "description": "When a scan finishes successfully"},
    {"id": "scan.failed", "name": "Scan Failed", "description": "When a scan encounters an error"},
    {"id": "vulnerability.critical", "name": "Critical Vulnerability", "description": "Critical severity vulnerability found"},
    {"id": "vulnerability.high", "name": "High Vulnerability", "description": "High severity vulnerability found"}
  ]
}
```

- [ ] Returns list of event types
- [ ] Each event has id, name, description

---

### 1.2 Create Notification Channel

```bash
POST /api/v1/notification-channels
Content-Type: application/json

{
  "name": "My Slack Channel",
  "channel_type": "slack",
  "webhook_url": "https://hooks.slack.com/services/...",
  "events": ["scan.completed", "vulnerability.critical"],
  "filters": {
    "min_severity": "high",
    "project_ids": []
  }
}
```

**Expected Response (201):**
```json
{
  "id": "uuid",
  "name": "My Slack Channel",
  "channel_type": "slack",
  "events": ["scan.completed", "vulnerability.critical"],
  "is_active": true,
  "created_at": "2026-01-04T..."
}
```

- [ ] Slack channel creation succeeds
- [ ] Teams channel creation succeeds
- [ ] Discord channel creation succeeds
- [ ] Invalid webhook URL rejected (400)
- [ ] Invalid channel_type rejected (400)

---

### 1.3 List Notification Channels

```bash
GET /api/v1/notification-channels
```

- [ ] Returns array of user's channels
- [ ] Includes statistics (total, successful, failed notifications)
- [ ] Respects user ownership (cannot see other users' channels)

---

### 1.4 Get Channel by ID

```bash
GET /api/v1/notification-channels/{id}
```

- [ ] Returns channel details
- [ ] Returns 404 for non-existent ID
- [ ] Returns 403 for other user's channel

---

### 1.5 Update Channel

```bash
PUT /api/v1/notification-channels/{id}
Content-Type: application/json

{
  "name": "Updated Name",
  "events": ["scan.completed"],
  "is_active": false
}
```

- [ ] Name updates successfully
- [ ] Events update successfully
- [ ] is_active toggle works
- [ ] Cannot update other user's channel (403)

---

### 1.6 Delete Channel

```bash
DELETE /api/v1/notification-channels/{id}
```

- [ ] Returns 204 on success
- [ ] Channel no longer appears in list
- [ ] Delivery history deleted (cascade)
- [ ] Cannot delete other user's channel (403)

---

## 2. Test Notifications

### 2.1 Test Slack Channel

```bash
POST /api/v1/notification-channels/{id}/test
```

**Slack Expected Message:**
- Block Kit formatted message
- Color-coded severity (red for critical)
- Contract name and scan ID
- Action button linking to dashboard

- [ ] Test notification delivered to Slack
- [ ] Message formatted with Block Kit
- [ ] Severity color correct
- [ ] Links work

---

### 2.2 Test Teams Channel

```bash
POST /api/v1/notification-channels/{id}/test
```

**Teams Expected Message:**
- Adaptive Card format
- Fact sets for details
- Action URLs

- [ ] Test notification delivered to Teams
- [ ] Adaptive Card renders correctly
- [ ] Facts display properly
- [ ] Action buttons work

---

### 2.3 Test Discord Channel

```bash
POST /api/v1/notification-channels/{id}/test
```

**Discord Expected Message:**
- Rich embed format
- Colored sidebar based on severity
- Fields layout

- [ ] Test notification delivered to Discord
- [ ] Embed renders with color
- [ ] Fields display correctly
- [ ] Thumbnail/footer present

---

## 3. Delivery History

### 3.1 Get Delivery History

```bash
GET /api/v1/notification-channels/{id}/deliveries?limit=10
```

- [ ] Returns array of delivery attempts
- [ ] Includes status_code, success flag
- [ ] Includes duration_ms
- [ ] Most recent first

---

### 3.2 Delivery Tracking

After sending test notification:

- [ ] total_notifications increments
- [ ] successful_notifications increments on 200
- [ ] failed_notifications increments on error
- [ ] last_triggered_at updates
- [ ] last_success_at updates on success
- [ ] last_failure_at updates on failure
- [ ] last_error populated on failure

---

## 4. Event Filtering

### 4.1 Severity Filter

Create channel with:
```json
{
  "filters": {
    "min_severity": "high"
  }
}
```

- [ ] Critical vulnerabilities trigger notification
- [ ] High vulnerabilities trigger notification
- [ ] Medium vulnerabilities do NOT trigger notification
- [ ] Low vulnerabilities do NOT trigger notification

---

### 4.2 Project Filter

Create channel with:
```json
{
  "filters": {
    "project_ids": ["uuid-1", "uuid-2"]
  }
}
```

- [ ] Events from filtered projects trigger notification
- [ ] Events from other projects do NOT trigger notification

---

## 5. Error Handling

### 5.1 Invalid Webhook URL

- [ ] Invalid URL format rejected on create (400)
- [ ] Delivery to invalid URL captured in history
- [ ] failed_notifications increments
- [ ] last_error contains error message

---

### 5.2 Webhook Timeout

- [ ] 30-second timeout for webhook calls
- [ ] Timeout captured in delivery history
- [ ] failed_notifications increments

---

### 5.3 Rate Limiting

- [ ] API rate limits apply to test endpoint
- [ ] Webhook rate limits handled gracefully

---

## 6. Dashboard Integration

> **Note (February 5, 2026):** The standalone Notifications page (`/notification-channels`) has been removed from the sidebar and routing. Notification channel management is now exclusively available through the **Integrations Hub > ChatOps tab** (`/integrations?tab=chatops`). The API endpoints remain unchanged. The tests below still apply but the navigation path is now via Integrations Hub.

### 6.1 Channel Management Page

Navigate to: **Integrations Hub > ChatOps tab** (`/integrations?tab=chatops`)

**Stats Cards:**
- [ ] Total Channels count displays correctly
- [ ] Active Channels count displays correctly
- [ ] Delivered notifications count displays correctly
- [ ] Failed notifications count displays correctly

**Channels Table:**
- [ ] Lists all notification channels
- [ ] Shows channel type icon (Slack/Teams/Discord)
- [ ] Shows subscribed events with badges
- [ ] Shows delivery stats (success/failed)
- [ ] Shows last triggered time
- [ ] Status badge shows Active/Paused

**Actions:**
- [ ] Test button sends test notification
- [ ] History button opens delivery history
- [ ] Edit button opens edit modal
- [ ] Delete button opens confirmation
- [ ] Status badge toggles active/inactive

---

### 6.2 Create Channel Modal

Click **Add Channel** button:

- [ ] Channel type selector shows Slack/Teams/Discord with icons
- [ ] Name field validates (required, max 255 chars)
- [ ] Webhook URL field validates URL format
- [ ] Placeholder updates based on channel type
- [ ] Event checkboxes load from API
- [ ] At least one event required
- [ ] Severity filter dropdown works
- [ ] Create button submits form
- [ ] Success closes modal and refreshes list
- [ ] Error displays in modal

---

### 6.3 Edit Channel Modal

Click **Edit** button on a channel:

- [ ] Form pre-populated with channel data
- [ ] Active/Inactive toggle works
- [ ] Name can be changed
- [ ] Events can be modified
- [ ] Severity filter can be changed
- [ ] Webhook URL shown as read-only (cannot be changed)
- [ ] Save button disabled until changes made
- [ ] Success closes modal and refreshes list

---

### 6.4 Delete Channel Modal

Click **Delete** button on a channel:

- [ ] Shows channel name and type
- [ ] Shows notification statistics
- [ ] Warning about irreversible action
- [ ] Cancel button closes modal
- [ ] Delete button removes channel
- [ ] Success closes modal and refreshes list

---

### 6.5 Test Channel Modal

Click **Test** button on a channel:

- [ ] Shows channel name and type
- [ ] Send Test button triggers notification
- [ ] Loading state during send
- [ ] Success shows green checkmark with details
- [ ] Failure shows red X with error message
- [ ] Shows HTTP status code and duration
- [ ] Try Again button on failure

---

### 6.6 Delivery History Modal

Click **History** button on a channel:

- [ ] Shows channel stats summary
- [ ] Filter tabs: All / Delivered / Failed
- [ ] List of delivery attempts
- [ ] Each delivery shows:
  - [ ] Event type
  - [ ] Success/failure icon
  - [ ] Timestamp
  - [ ] HTTP status code
  - [ ] Duration
  - [ ] Error message (if failed)
- [ ] Relative time display (e.g., "2h ago")
- [ ] Empty state when no deliveries

---

### 6.7 Dark Mode Support

- [ ] All components support dark mode
- [ ] Icons visible in both modes
- [ ] Modal backgrounds appropriate
- [ ] Form inputs readable in dark mode

---

### 6.8 Access Control

- [ ] Page requires "growth" tier or higher (full API access)
- [ ] Developer/Team tier users see upgrade prompt
- [ ] Each user sees only their own channels

---

## Test Status

| Section | Status | Date | Tester |
|---------|--------|------|--------|
| 1.1 List Events | [ ] | | |
| 1.2 Create Channel | [ ] | | |
| 1.3 List Channels | [ ] | | |
| 1.4 Get Channel | [ ] | | |
| 1.5 Update Channel | [ ] | | |
| 1.6 Delete Channel | [ ] | | |
| 2.1 Test Slack | [ ] | | |
| 2.2 Test Teams | [ ] | | |
| 2.3 Test Discord | [ ] | | |
| 3.1 Delivery History | [ ] | | |
| 3.2 Delivery Tracking | [ ] | | |
| 4.1 Severity Filter | [ ] | | |
| 4.2 Project Filter | [ ] | | |
| 5.1 Invalid URL | [ ] | | |
| 5.2 Timeout | [ ] | | |
| 5.3 Rate Limiting | [ ] | | |
| 6.1 Channel Management Page | [ ] | | |
| 6.2 Create Channel Modal | [ ] | | |
| 6.3 Edit Channel Modal | [ ] | | |
| 6.4 Delete Channel Modal | [ ] | | |
| 6.5 Test Channel Modal | [ ] | | |
| 6.6 Delivery History Modal | [ ] | | |
| 6.7 Dark Mode Support | [ ] | | |
| 6.8 Access Control | [ ] | | |

---

## Notes

```
[Date] | [Tester] | [Note]
2026-01-04 | Claude Code | Feature implemented, API endpoints verified, test docs created
2026-01-04 | Claude Code | Dashboard UI implemented with full modal support
```
