# Monitoring Endpoints

All monitoring endpoints are prefixed with `/api/v1/monitoring` and require authentication.

---

## Monitored Contracts

### POST /api/v1/monitoring/contracts

Add a contract to continuous monitoring.

```bash
curl -X POST https://api.blocksecops.com/api/v1/monitoring/contracts \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "address": "0xdead...beef",
    "chain": "ethereum",
    "name": "My DeFi Protocol",
    "alert_types": ["large_transfer", "ownership_change", "proxy_upgrade"],
    "thresholds": {
      "large_transfer_eth": 100
    }
  }'
```

**Request Body:**

| Field        | Type     | Required | Description                           |
|--------------|----------|----------|---------------------------------------|
| address      | string   | Yes      | Contract address                      |
| chain        | string   | Yes      | Blockchain network (ethereum, polygon, base, etc.) |
| name         | string   | No       | Human-readable name                   |
| alert_types  | string[] | No       | Alert types to enable (default: all)  |
| thresholds   | object   | No       | Custom thresholds for alerts          |

**Response 201:**

```json
{
  "id": "mon_abc123",
  "address": "0xdead...beef",
  "chain": "ethereum",
  "name": "My DeFi Protocol",
  "status": "active",
  "alert_types": ["large_transfer", "ownership_change", "proxy_upgrade"],
  "thresholds": {
    "large_transfer_eth": 100
  },
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/monitoring/contracts

List all monitored contracts.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/monitoring/contracts?page=1&limit=25" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "contracts": [
    {
      "id": "mon_abc123",
      "address": "0xdead...beef",
      "chain": "ethereum",
      "name": "My DeFi Protocol",
      "status": "active",
      "alert_count": 3,
      "last_alert_at": "2026-02-13T16:00:00Z",
      "created_at": "2026-02-01T10:00:00Z"
    }
  ],
  "total": 5
}
```

### GET /api/v1/monitoring/contracts/{id}

Retrieve details for a specific monitored contract.

```bash
curl -X GET https://api.blocksecops.com/api/v1/monitoring/contracts/mon_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "mon_abc123",
  "address": "0xdead...beef",
  "chain": "ethereum",
  "name": "My DeFi Protocol",
  "status": "active",
  "alert_types": ["large_transfer", "ownership_change", "proxy_upgrade"],
  "thresholds": {
    "large_transfer_eth": 100
  },
  "webhook_url": "https://example.com/hooks/monitoring",
  "alert_count": 3,
  "unacknowledged_alerts": 1,
  "last_alert_at": "2026-02-13T16:00:00Z",
  "last_checked_at": "2026-02-14T12:00:00Z",
  "created_at": "2026-02-01T10:00:00Z"
}
```

### PATCH /api/v1/monitoring/contracts/{id}

Update a monitored contract's configuration.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/monitoring/contracts/mon_abc123 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My DeFi Protocol v2",
    "alert_types": ["large_transfer", "ownership_change", "proxy_upgrade", "flash_loan_detected"],
    "thresholds": {
      "large_transfer_eth": 50
    }
  }'
```

**Response 200:** Returns the updated monitored contract object.

### DELETE /api/v1/monitoring/contracts/{id}

Remove a contract from monitoring.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/monitoring/contracts/mon_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

### POST /api/v1/monitoring/contracts/{id}/webhook

Set or update the webhook URL for a monitored contract's alerts.

```bash
curl -X POST https://api.blocksecops.com/api/v1/monitoring/contracts/mon_abc123/webhook \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com/hooks/monitoring",
    "events": ["alert.created", "alert.resolved"]
  }'
```

**Response 200:**

```json
{
  "id": "mon_abc123",
  "webhook_url": "https://example.com/hooks/monitoring",
  "webhook_events": ["alert.created", "alert.resolved"],
  "webhook_secret": "mwhsec_abc123...",
  "updated_at": "2026-02-14T12:00:00Z"
}
```

> **Note:** The `webhook_secret` is returned only when the webhook is first set or updated. Store it securely for payload verification.

---

## Alerts

### GET /api/v1/monitoring/alerts

List monitoring alerts with filtering.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/monitoring/alerts?page=1&limit=25&severity=high&acknowledged=false" \
  -H "Authorization: Bearer <token>"
```

**Query Parameters:**

| Parameter    | Type   | Description                           |
|--------------|--------|---------------------------------------|
| page         | int    | Page number (default: 1)              |
| limit        | int    | Items per page (default: 25)          |
| contract_id  | string | Filter by monitored contract          |
| type         | string | Filter by alert type                  |
| severity     | string | Filter: critical, high, medium, low   |
| acknowledged | bool   | Filter by acknowledgment status       |

**Response 200:**

```json
{
  "alerts": [
    {
      "id": "alert_001",
      "contract_id": "mon_abc123",
      "type": "large_transfer",
      "severity": "high",
      "title": "Large ETH transfer detected",
      "description": "150 ETH transferred from contract 0xdead...beef to 0x1234...abcd",
      "metadata": {
        "amount_eth": 150,
        "from": "0xdead...beef",
        "to": "0x1234...abcd",
        "tx_hash": "0xfeed...cafe"
      },
      "acknowledged": false,
      "created_at": "2026-02-13T16:00:00Z"
    }
  ],
  "total": 8,
  "page": 1,
  "limit": 25
}
```

### GET /api/v1/monitoring/alerts/{id}

Retrieve a specific alert with full details.

```bash
curl -X GET https://api.blocksecops.com/api/v1/monitoring/alerts/alert_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "alert_001",
  "contract_id": "mon_abc123",
  "contract_address": "0xdead...beef",
  "contract_name": "My DeFi Protocol",
  "chain": "ethereum",
  "type": "large_transfer",
  "severity": "high",
  "title": "Large ETH transfer detected",
  "description": "150 ETH transferred from contract 0xdead...beef to 0x1234...abcd",
  "metadata": {
    "amount_eth": 150,
    "from": "0xdead...beef",
    "to": "0x1234...abcd",
    "tx_hash": "0xfeed...cafe",
    "block_number": 19234567,
    "gas_used": 21000
  },
  "acknowledged": false,
  "acknowledged_by": null,
  "acknowledged_at": null,
  "created_at": "2026-02-13T16:00:00Z"
}
```

### PATCH /api/v1/monitoring/alerts/{id}/acknowledge

Acknowledge an alert.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/monitoring/alerts/alert_001/acknowledge \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "note": "Investigated - this was an authorized treasury transfer"
  }'
```

**Response 200:**

```json
{
  "id": "alert_001",
  "acknowledged": true,
  "acknowledged_by": "usr_abc123",
  "acknowledged_at": "2026-02-14T12:00:00Z",
  "note": "Investigated - this was an authorized treasury transfer"
}
```

### POST /api/v1/monitoring/alerts/acknowledge-bulk

Acknowledge multiple alerts at once.

```bash
curl -X POST https://api.blocksecops.com/api/v1/monitoring/alerts/acknowledge-bulk \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_ids": ["alert_001", "alert_002", "alert_003"],
    "note": "Batch acknowledged - reviewed during weekly audit"
  }'
```

**Response 200:**

```json
{
  "acknowledged": 3,
  "acknowledged_by": "usr_abc123",
  "acknowledged_at": "2026-02-14T12:00:00Z"
}
```

---

## Alert Types

### GET /api/v1/monitoring/alert-types

List all available monitoring alert types.

```bash
curl -X GET https://api.blocksecops.com/api/v1/monitoring/alert-types \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "alert_types": [
    {
      "type": "large_transfer",
      "name": "Large Transfer",
      "description": "Detects transfers exceeding the configured threshold",
      "default_severity": "high",
      "configurable_threshold": true,
      "threshold_field": "large_transfer_eth",
      "threshold_default": 100
    },
    {
      "type": "ownership_change",
      "name": "Ownership Change",
      "description": "Detects changes to contract ownership (e.g., transferOwnership)",
      "default_severity": "critical",
      "configurable_threshold": false
    },
    {
      "type": "unusual_function_call",
      "name": "Unusual Function Call",
      "description": "Detects calls to rarely-used or sensitive functions",
      "default_severity": "medium",
      "configurable_threshold": false
    },
    {
      "type": "flash_loan_detected",
      "name": "Flash Loan Detected",
      "description": "Detects flash loan interactions with the monitored contract",
      "default_severity": "high",
      "configurable_threshold": false
    },
    {
      "type": "proxy_upgrade",
      "name": "Proxy Upgrade",
      "description": "Detects upgrades to proxy contract implementations",
      "default_severity": "critical",
      "configurable_threshold": false
    },
    {
      "type": "pause_state_change",
      "name": "Pause State Change",
      "description": "Detects when a contract is paused or unpaused",
      "default_severity": "high",
      "configurable_threshold": false
    }
  ]
}
```

---

## Statistics

### GET /api/v1/monitoring/stats

Retrieve aggregate monitoring statistics.

```bash
curl -X GET https://api.blocksecops.com/api/v1/monitoring/stats \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "total_contracts": 5,
  "active_contracts": 4,
  "paused_contracts": 1,
  "total_alerts": 42,
  "unacknowledged_alerts": 3,
  "alerts_today": 2,
  "alerts_by_type": {
    "large_transfer": 15,
    "ownership_change": 3,
    "unusual_function_call": 8,
    "flash_loan_detected": 5,
    "proxy_upgrade": 2,
    "pause_state_change": 9
  },
  "alerts_by_severity": {
    "critical": 5,
    "high": 20,
    "medium": 12,
    "low": 5
  }
}
```
