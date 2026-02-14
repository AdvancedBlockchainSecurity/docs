# Webhook Endpoints

All webhook endpoints are prefixed with `/api/v1/webhooks` and require authentication.

---

## POST /api/v1/webhooks

Create a new webhook.

```bash
curl -X POST https://api.blocksecops.com/api/v1/webhooks \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com/hooks/blocksecops",
    "events": ["scan.completed", "vulnerability.critical"],
    "description": "Notify on scan completion and critical findings",
    "active": true
  }'
```

**Request Body:**

| Field       | Type     | Required | Description                        |
|-------------|----------|----------|------------------------------------|
| url         | string   | Yes      | HTTPS endpoint to receive payloads |
| events      | string[] | Yes      | Event types to subscribe to        |
| description | string   | No       | Human-readable description         |
| active      | bool     | No       | Whether webhook is active (default: true) |

**Response 201:**

```json
{
  "id": "wh_abc123",
  "url": "https://example.com/hooks/blocksecops",
  "events": ["scan.completed", "vulnerability.critical"],
  "description": "Notify on scan completion and critical findings",
  "active": true,
  "secret": "whsec_abc123def456...",
  "created_at": "2026-02-14T12:00:00Z"
}
```

> **Important:** The `secret` is used to verify webhook signatures. It is only returned at creation time and when rotated. Store it securely.

---

## GET /api/v1/webhooks

List all webhooks for the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/webhooks \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "webhooks": [
    {
      "id": "wh_abc123",
      "url": "https://example.com/hooks/blocksecops",
      "events": ["scan.completed", "vulnerability.critical"],
      "description": "Notify on scan completion and critical findings",
      "active": true,
      "last_delivery_at": "2026-02-14T10:30:00Z",
      "last_delivery_status": "success",
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 1
}
```

---

## GET /api/v1/webhooks/events

List all available webhook event types.

```bash
curl -X GET https://api.blocksecops.com/api/v1/webhooks/events \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "events": [
    {
      "type": "scan.started",
      "description": "Fired when a new scan begins processing"
    },
    {
      "type": "scan.completed",
      "description": "Fired when a scan finishes successfully"
    },
    {
      "type": "scan.failed",
      "description": "Fired when a scan encounters an error and fails"
    },
    {
      "type": "vulnerability.detected",
      "description": "Fired when any new vulnerability is found during a scan"
    },
    {
      "type": "vulnerability.critical",
      "description": "Fired when a critical-severity vulnerability is found"
    },
    {
      "type": "contract.added",
      "description": "Fired when a new contract is added to the workspace"
    },
    {
      "type": "contract.deleted",
      "description": "Fired when a contract is removed from the workspace"
    }
  ]
}
```

---

## GET /api/v1/webhooks/{webhook_id}

Retrieve details for a specific webhook.

```bash
curl -X GET https://api.blocksecops.com/api/v1/webhooks/wh_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "wh_abc123",
  "url": "https://example.com/hooks/blocksecops",
  "events": ["scan.completed", "vulnerability.critical"],
  "description": "Notify on scan completion and critical findings",
  "active": true,
  "last_delivery_at": "2026-02-14T10:30:00Z",
  "last_delivery_status": "success",
  "failure_count": 0,
  "created_at": "2026-02-14T12:00:00Z",
  "updated_at": "2026-02-14T12:00:00Z"
}
```

---

## PATCH /api/v1/webhooks/{webhook_id}

Update a webhook's configuration.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/webhooks/wh_abc123 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "events": ["scan.completed", "scan.failed", "vulnerability.critical"],
    "active": true
  }'
```

**Response 200:**

```json
{
  "id": "wh_abc123",
  "url": "https://example.com/hooks/blocksecops",
  "events": ["scan.completed", "scan.failed", "vulnerability.critical"],
  "active": true,
  "updated_at": "2026-02-14T12:30:00Z"
}
```

---

## DELETE /api/v1/webhooks/{webhook_id}

Delete a webhook.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/webhooks/wh_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## GET /api/v1/webhooks/{webhook_id}/deliveries

Retrieve the delivery log for a webhook, showing recent delivery attempts and their outcomes.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/webhooks/wh_abc123/deliveries?page=1&limit=25" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "deliveries": [
    {
      "id": "del_001",
      "event_type": "scan.completed",
      "status": "success",
      "http_status": 200,
      "request_headers": {
        "Content-Type": "application/json",
        "X-BlockSecOps-Event": "scan.completed",
        "X-BlockSecOps-Signature": "sha256=abc123..."
      },
      "request_body": "{\"event\":\"scan.completed\",\"scan_id\":\"scan_abc123\",...}",
      "response_body": "{\"ok\":true}",
      "duration_ms": 245,
      "delivered_at": "2026-02-14T10:30:00Z"
    },
    {
      "id": "del_002",
      "event_type": "vulnerability.critical",
      "status": "failed",
      "http_status": 500,
      "error": "Server returned 500 Internal Server Error",
      "duration_ms": 1200,
      "retry_count": 2,
      "next_retry_at": "2026-02-14T11:00:00Z",
      "delivered_at": "2026-02-14T10:35:00Z"
    }
  ],
  "total": 42,
  "page": 1,
  "limit": 25
}
```

---

## POST /api/v1/webhooks/{webhook_id}/rotate-secret

Rotate the webhook signing secret. The old secret is immediately invalidated.

```bash
curl -X POST https://api.blocksecops.com/api/v1/webhooks/wh_abc123/rotate-secret \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "wh_abc123",
  "secret": "whsec_newkey789abc...",
  "rotated_at": "2026-02-14T12:00:00Z",
  "message": "Webhook secret rotated. Update your endpoint to use the new secret for signature verification."
}
```

> **Important:** After rotating, update your webhook receiver to verify signatures with the new secret. The old secret stops working immediately.

---

## Stripe Webhooks

Endpoints for managing the Stripe webhook integration used for payment event processing.

### POST /api/v1/webhooks/stripe

Handle incoming Stripe webhook events. This endpoint is called by Stripe directly.

```bash
curl -X POST https://api.blocksecops.com/api/v1/webhooks/stripe \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=1234567890,v1=abc123..." \
  -d '{
    "id": "evt_abc123",
    "type": "checkout.session.completed",
    "data": {
      "object": { ... }
    }
  }'
```

**Response 200:**

```json
{
  "received": true
}
```

**Handled Event Types:**
- `checkout.session.completed` - Payment completed
- `customer.subscription.updated` - Subscription changed
- `customer.subscription.deleted` - Subscription cancelled
- `invoice.payment_succeeded` - Invoice paid
- `invoice.payment_failed` - Payment failed

### GET /api/v1/webhooks/stripe/health

Check the health of the Stripe webhook integration.

```bash
curl -X GET https://api.blocksecops.com/api/v1/webhooks/stripe/health \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "status": "healthy",
  "last_event_received_at": "2026-02-14T10:45:00Z",
  "events_processed_today": 15,
  "events_failed_today": 0,
  "webhook_endpoint_id": "we_abc123"
}
```

---

## Webhook Signature Verification

All webhook deliveries include a signature header for payload verification.

**Header:** `X-BlockSecOps-Signature`

**Verification Example (Node.js):**

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, secret) {
  const expectedSignature = 'sha256=' +
    crypto.createHmac('sha256', secret)
      .update(payload, 'utf8')
      .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}
```

**Verification Example (Python):**

```python
import hmac
import hashlib

def verify_webhook_signature(payload: bytes, signature: str, secret: str) -> bool:
    expected = 'sha256=' + hmac.new(
        secret.encode(), payload, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, expected)
```
