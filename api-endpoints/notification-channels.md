# Notification Channels

**Base URL:** `/api/v1/notification-channels`
**Auth:** Bearer JWT required
**Tier:** Growth+

## Overview

Notification channels configure where alerts are sent (email, Slack, Teams, webhooks). Each channel subscribes to specific event types.

## Endpoints

### Create Channel

```
POST /api/v1/notification-channels
```

**Request Body:**
```json
{
  "name": "Security Alerts - Slack",
  "type": "slack",
  "config": {
    "webhook_url": "https://hooks.slack.com/services/..."
  },
  "events": ["vulnerability.critical", "scan.failed"]
}
```

### List Channels

```
GET /api/v1/notification-channels
```

**Response (200):**
```json
{
  "channels": [],
  "total": 0,
  "page": 1,
  "page_size": 50
}
```

### Get Available Events

```
GET /api/v1/notification-channels/events
```

**Response (200):**
```json
{
  "events": [
    {"id": "scan.started", "name": "Scan Started", "description": "Triggered when a scan begins execution"},
    {"id": "scan.completed", "name": "Scan Completed", "description": "Triggered when a scan completes successfully"},
    {"id": "scan.failed", "name": "Scan Failed", "description": "Triggered when a scan fails"},
    {"id": "vulnerability.detected", "name": "Vulnerability Detected", "description": "Triggered for each new vulnerability detected"},
    {"id": "vulnerability.critical", "name": "Critical Vulnerability", "description": "Triggered for critical severity vulnerabilities"},
    {"id": "contract.added", "name": "Contract Added", "description": "Triggered when a new contract is added"},
    {"id": "contract.deleted", "name": "Contract Deleted", "description": "Triggered when a contract is deleted"}
  ]
}
```

### Get Channel

```
GET /api/v1/notification-channels/{channel_id}
```

### Update Channel

```
PATCH /api/v1/notification-channels/{channel_id}
```

### Delete Channel

```
DELETE /api/v1/notification-channels/{channel_id}
```

### Get Deliveries

```
GET /api/v1/notification-channels/{channel_id}/deliveries
```

### Test Channel

```
POST /api/v1/notification-channels/{channel_id}/test
```

Sends a test notification to verify the channel configuration.

## Audit Results

| Endpoint | Status | Notes |
|----------|--------|-------|
| GET /notification-channels | 200 | 0 channels |
| GET /events | 200 | 7 event types |
