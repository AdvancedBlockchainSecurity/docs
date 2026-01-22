# System Monitoring

Monitor platform health, performance metrics, and usage statistics.

## Overview

BlockSecOps provides monitoring capabilities for:
- Platform health and status
- Scan performance metrics
- Usage statistics
- Notification delivery tracking

---

## Health Check

### API Health Endpoint

```bash
curl https://api.blocksecops.com/health
```

Response:
```json
{
  "status": "healthy",
  "version": "0.7.1",
  "timestamp": "2026-01-04T12:00:00Z"
}
```

### Component Status

| Component | Endpoint | Description |
|-----------|----------|-------------|
| API | `/health` | Core API service |
| Database | `/health/db` | Database connectivity |
| Redis | `/health/cache` | Cache service |
| Scanners | `/health/scanners` | Scanner availability |

---

## Usage Statistics

### Get Platform Statistics

```bash
curl -X GET https://api.blocksecops.com/api/v1/statistics \
  -H "Authorization: Bearer $TOKEN"
```

### Response

```json
{
  "scans": {
    "total": 1234,
    "completed": 1180,
    "failed": 54,
    "pending": 0,
    "this_month": 89
  },
  "contracts": {
    "total": 567,
    "by_language": {
      "solidity": 512,
      "vyper": 45,
      "rust": 10
    }
  },
  "vulnerabilities": {
    "total": 3456,
    "by_severity": {
      "critical": 23,
      "high": 178,
      "medium": 892,
      "low": 1456,
      "informational": 907
    }
  }
}
```

### Risk Statistics

```bash
curl -X GET https://api.blocksecops.com/api/v1/statistics/risk \
  -H "Authorization: Bearer $TOKEN"
```

Returns per-project risk breakdown:
```json
{
  "projects": [
    {
      "project_id": "uuid",
      "project_name": "My DeFi App",
      "risk_score": 75,
      "risk_level": "HIGH",
      "vulnerabilities": {
        "critical": 2,
        "high": 8,
        "medium": 15
      }
    }
  ],
  "overall_risk_score": 45,
  "overall_risk_level": "MEDIUM"
}
```

---

## Scan Metrics

### Recent Scans

```bash
curl -X GET "https://api.blocksecops.com/api/v1/scans?limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

### Scan Duration

Track scan performance:
```json
{
  "scan_id": "uuid",
  "duration_seconds": 45,
  "scanners_run": 8,
  "findings_count": 12,
  "status": "completed"
}
```

### Average Scan Times by Scanner

| Scanner | Avg Time | Max Time |
|---------|----------|----------|
| Slither | 15s | 60s |
| Mythril | 120s | 300s |
| Aderyn | 8s | 30s |
| Semgrep | 5s | 20s |

---

## Notification Monitoring

### Channel Statistics

```bash
curl -X GET https://api.blocksecops.com/api/v1/notification-channels \
  -H "Authorization: Bearer $TOKEN"
```

Each channel includes:
- `total_notifications` - Total attempts
- `successful_notifications` - Successful deliveries
- `failed_notifications` - Failed deliveries
- `last_triggered_at` - Last attempt time

### Delivery Success Rate

Calculate delivery success rate:
```
success_rate = successful_notifications / total_notifications * 100
```

### Delivery History

```bash
curl -X GET "https://api.blocksecops.com/api/v1/notification-channels/{id}/deliveries?limit=100" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Alerting

### Recommended Alerts

| Metric | Threshold | Action |
|--------|-----------|--------|
| API response time | > 5s | Investigate load |
| Scan failure rate | > 10% | Check scanner health |
| Notification failures | > 5% | Verify webhooks |
| Database connections | > 80% | Scale connection pool |
| Queue depth | > 100 | Add scanner capacity |

### Setting Up Alerts

Use notification channels to alert on platform events:

```bash
curl -X POST https://api.blocksecops.com/api/v1/notification-channels \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Platform Alerts",
    "channel_type": "slack",
    "webhook_url": "https://hooks.slack.com/...",
    "events": ["scan.failed"]
  }'
```

---

## Logging

### Log Levels

| Level | Description |
|-------|-------------|
| `debug` | Detailed debugging (local only) |
| `info` | Normal operation events |
| `warn` | Warning conditions |
| `error` | Error conditions |

### Log Access

Logs are available through:
- Container logs (Kubernetes)
- CloudWatch (AWS deployment)
- Application logging endpoint (enterprise)

---

## Performance Optimization

### Scan Queue Management

- Scans are queued and processed by priority
- Enterprise tier gets priority processing
- Long-running scans (>5 min) may be split

### Rate Limits

| Tier | Web Requests/min | Concurrent Scans | API Access |
|------|------------------|------------------|------------|
| Developer | 60 | 1 | No |
| Team | 120 | 2 | No |
| Growth | 300 | 5 | Yes (300 req/min) |
| Enterprise | Custom | Custom | Yes (Custom) |

> **Note:** API access is only available on Growth and Enterprise tiers.

### Caching

- Scan results cached for 24 hours
- Statistics cached for 5 minutes
- User profiles cached for 15 minutes

---

## Troubleshooting

### High Scan Failure Rate

1. Check scanner health: `/health/scanners`
2. Review failed scan logs
3. Check for unsupported Solidity versions
4. Verify contract syntax

### Slow Response Times

1. Check database connection pool
2. Review query performance
3. Check Redis cache hit rates
4. Scale API instances if needed

### Notification Delivery Issues

1. Check delivery history for errors
2. Verify webhook URLs are valid
3. Test webhook connectivity
4. Check rate limits on target platform
