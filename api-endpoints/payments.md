# Payment Endpoints

All payment endpoints are prefixed with `/api/v1/payments` and require authentication unless otherwise noted.

---

## GET /api/v1/payments/packages

Retrieve available credit packages for purchase.

```bash
curl -X GET https://api.blocksecops.com/api/v1/payments/packages \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "packages": [
    {
      "id": "pkg_starter",
      "name": "Starter",
      "credits": 10,
      "price_usd": 30.00,
      "price_per_credit_usd": 3.00,
      "savings_percent": 0
    },
    {
      "id": "pkg_builder",
      "name": "Builder",
      "credits": 50,
      "price_usd": 125.00,
      "price_per_credit_usd": 2.50,
      "savings_percent": 17
    },
    {
      "id": "pkg_pro",
      "name": "Pro",
      "credits": 200,
      "price_usd": 400.00,
      "price_per_credit_usd": 2.00,
      "savings_percent": 33
    },
    {
      "id": "pkg_bulk",
      "name": "Bulk",
      "credits": 1000,
      "price_usd": 1500.00,
      "price_per_credit_usd": 1.50,
      "savings_percent": 50
    }
  ]
}
```

---

## GET /api/v1/payments/prices

Retrieve per-scan pricing based on contract size. Prices are denominated in USDC on Base network.

```bash
curl -X GET https://api.blocksecops.com/api/v1/payments/prices \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "prices": [
    {
      "tier": "micro",
      "description": "Contracts under 100 lines",
      "max_lines": 100,
      "price_usd": 3.00,
      "price_usdc": "3000000",
      "chain": "base"
    },
    {
      "tier": "small",
      "description": "Contracts 100-500 lines",
      "max_lines": 500,
      "price_usd": 7.00,
      "price_usdc": "7000000",
      "chain": "base"
    },
    {
      "tier": "medium",
      "description": "Contracts 500-2000 lines",
      "max_lines": 2000,
      "price_usd": 15.00,
      "price_usdc": "15000000",
      "chain": "base"
    },
    {
      "tier": "large",
      "description": "Contracts over 2000 lines",
      "max_lines": null,
      "price_usd": 25.00,
      "price_usdc": "25000000",
      "chain": "base"
    }
  ],
  "currency": "USDC",
  "network": "Base (Ethereum L2)",
  "usdc_contract": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
}
```

---

## GET /api/v1/payments/credits

Retrieve the current credit balance for the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/payments/credits \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "balance": 35,
  "total_purchased": 50,
  "total_used": 15,
  "has_credits": true
}
```

---

## GET /api/v1/payments/credits/history

Retrieve credit transaction history.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/payments/credits/history?page=1&limit=25" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "transactions": [
    {
      "id": "ctx_001",
      "type": "purchase",
      "amount": 50,
      "balance_after": 50,
      "description": "Builder package purchase",
      "payment_id": "pay_abc123",
      "created_at": "2026-02-10T14:00:00Z"
    },
    {
      "id": "ctx_002",
      "type": "usage",
      "amount": -1,
      "balance_after": 49,
      "description": "Scan: 0xdead...beef (medium)",
      "scan_id": "scan_abc123",
      "created_at": "2026-02-11T09:00:00Z"
    },
    {
      "id": "ctx_003",
      "type": "gift",
      "amount": 5,
      "balance_after": 40,
      "description": "Admin credit gift",
      "created_at": "2026-02-12T16:00:00Z"
    }
  ],
  "total": 16,
  "page": 1,
  "limit": 25
}
```

---

## POST /api/v1/payments/credits/use

Use credits for a scan. Called internally during scan initiation, but can also be invoked directly.

```bash
curl -X POST https://api.blocksecops.com/api/v1/payments/credits/use \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 1,
    "scan_id": "scan_abc123",
    "description": "Scan: 0xdead...beef"
  }'
```

**Response 200:**

```json
{
  "transaction_id": "ctx_015",
  "credits_used": 1,
  "balance_remaining": 34,
  "scan_id": "scan_abc123"
}
```

**Response 402 (insufficient credits):**

```json
{
  "error": "insufficient_credits",
  "message": "Not enough credits. Balance: 0, Required: 1",
  "balance": 0,
  "required": 1
}
```

---

## GET /api/v1/payments/history

Retrieve payment history.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/payments/history?page=1&limit=25" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "payments": [
    {
      "id": "pay_abc123",
      "type": "credit_purchase",
      "amount_usd": 125.00,
      "payment_method": "stripe",
      "status": "completed",
      "package": "Builder (50 credits)",
      "created_at": "2026-02-10T14:00:00Z"
    },
    {
      "id": "pay_def456",
      "type": "per_scan",
      "amount_usd": 15.00,
      "payment_method": "usdc_base",
      "status": "completed",
      "tx_hash": "0xabc123...",
      "created_at": "2026-02-08T11:30:00Z"
    }
  ],
  "total": 5,
  "page": 1,
  "limit": 25
}
```

---

## POST /api/v1/payments/initiate

Initiate a cryptocurrency payment on Base network.

```bash
curl -X POST https://api.blocksecops.com/api/v1/payments/initiate \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "package_id": "pkg_builder",
    "payment_method": "usdc_base",
    "wallet_address": "0x1234...abcd"
  }'
```

**Response 200:**

```json
{
  "payment_id": "pay_ghi789",
  "recipient_address": "0x5678...efgh",
  "amount_usdc": "125000000",
  "amount_display": "125.00 USDC",
  "chain": "base",
  "chain_id": 8453,
  "usdc_contract": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  "expires_at": "2026-02-14T12:30:00Z",
  "status": "pending"
}
```

---

## POST /api/v1/payments/verify

Verify a cryptocurrency payment by providing the transaction hash.

```bash
curl -X POST https://api.blocksecops.com/api/v1/payments/verify \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "payment_id": "pay_ghi789",
    "tx_hash": "0xabc123def456..."
  }'
```

**Response 200:**

```json
{
  "payment_id": "pay_ghi789",
  "status": "completed",
  "credits_added": 50,
  "new_balance": 85,
  "tx_hash": "0xabc123def456...",
  "confirmed_at": "2026-02-14T12:05:00Z"
}
```

**Response 400 (verification failed):**

```json
{
  "error": "verification_failed",
  "message": "Transaction not found or amount does not match",
  "payment_id": "pay_ghi789"
}
```

---

## POST /api/v1/payments/checkout/stripe

Create a Stripe checkout session for credit package purchase.

```bash
curl -X POST https://api.blocksecops.com/api/v1/payments/checkout/stripe \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "package_id": "pkg_builder",
    "success_url": "https://app.blocksecops.com/payments/success",
    "cancel_url": "https://app.blocksecops.com/payments/cancel"
  }'
```

**Response 200:**

```json
{
  "checkout_url": "https://checkout.stripe.com/c/pay/cs_live_abc123",
  "session_id": "cs_live_abc123",
  "payment_id": "pay_jkl012",
  "expires_at": "2026-02-14T13:00:00Z"
}
```

---

## GET /api/v1/payments/{payment_id}/receipt

Download a receipt for a completed payment.

```bash
curl -X GET https://api.blocksecops.com/api/v1/payments/pay_abc123/receipt \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "receipt": {
    "payment_id": "pay_abc123",
    "receipt_number": "RCT-2026-0042",
    "date": "2026-02-10T14:00:00Z",
    "item": "Builder Credit Package (50 credits)",
    "amount_usd": 125.00,
    "payment_method": "Visa ending in 4242",
    "status": "completed",
    "billing_details": {
      "name": "Jane Doe",
      "email": "jane@acme.com",
      "company": "Acme Security Corp"
    }
  }
}
```

---

## Admin Payment Endpoints

These endpoints require admin authentication.

### POST /api/v1/payments/admin/gift

Gift credits to a user account.

```bash
curl -X POST https://api.blocksecops.com/api/v1/payments/admin/gift \
  -H "Cookie: admin_session=<session_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "usr_abc123",
    "amount": 10,
    "reason": "Beta tester reward"
  }'
```

**Response 200:**

```json
{
  "transaction_id": "ctx_admin_001",
  "user_id": "usr_abc123",
  "credits_gifted": 10,
  "new_balance": 45,
  "gifted_by": "admin_usr_001",
  "reason": "Beta tester reward"
}
```

### GET /api/v1/payments/admin/stats

Retrieve payment statistics (admin only).

```bash
curl -X GET https://api.blocksecops.com/api/v1/payments/admin/stats \
  -H "Cookie: admin_session=<session_token>"
```

**Response 200:**

```json
{
  "total_revenue_usd": 78500.00,
  "revenue_this_month": 12400.00,
  "total_credits_sold": 52000,
  "total_credits_gifted": 1500,
  "total_credits_used": 38000,
  "payments_by_method": {
    "stripe": 420,
    "usdc_base": 85
  },
  "popular_packages": [
    { "package": "Builder", "purchases": 180 },
    { "package": "Pro", "purchases": 95 },
    { "package": "Starter", "purchases": 150 },
    { "package": "Bulk", "purchases": 20 }
  ]
}
```
