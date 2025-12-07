# x402 Pay-Per-Scan Tests (Phase 3.4)

**Priority**: P1 - High
**Last Tested**: 2025-12-03
**Feature**: USDC Micropayments on Base Blockchain
**Automated Tests**: 59 tests (30 unit + 29 integration)

## Test Coverage

### Automated Tests
- **Unit Tests**: `tests/unit/services/test_payment_services.py` (32 tests) ✅ ALL PASSING
  - `TestPricingService` - 11 tests ✅
  - `TestCreditService` - 10 tests ✅
  - `TestPaymentService` - 11 tests ✅
- **Integration Tests**: `tests/integration/test_payment_api.py` (29 tests)
  - `TestPaymentEndpoints` - 20 tests
  - `TestCreditPackageDetails` - 5 tests
  - `TestPricingTiers` - 4 tests

### API Endpoint Verification (2025-12-03)
- `GET /api/v1/payments/packages` - ✅ Verified (4 packages returned)
- `GET /api/v1/payments/prices` - ✅ Verified (4 pricing tiers returned)

---

## Manual Test Checklist

## 1. Credit Balance API

### 1.1 Get Credit Balance
- [ ] `GET /api/v1/payments/credits` returns user balance
- [ ] Returns 0 credits for new users
- [ ] Returns correct balance after purchase
- [ ] Requires authentication (401 without token)
- [ ] Response includes `balance`, `user_id`, `last_updated`

### 1.2 Credit History
- [ ] `GET /api/v1/payments/credits/history` returns transaction list
- [ ] Returns empty list for new users
- [ ] Shows purchases with `type: purchase`
- [ ] Shows usage with `type: usage`
- [ ] Pagination works correctly (limit/offset)
- [ ] Sorted by date descending (newest first)

---

## 2. Credit Usage API

### 2.1 Use Credits for Scan
- [ ] `POST /api/v1/payments/credits/use` deducts credits
- [ ] Correct credits deducted based on scan complexity
- [ ] Returns updated balance after deduction
- [ ] Insufficient credits returns 402 Payment Required
- [ ] Invalid scan_id returns 404
- [ ] Creates credit transaction record

### 2.2 Complexity-Based Pricing
- [ ] Simple scan (1-5 files): 0.5 credits deducted
- [ ] Standard scan (6-25 files): 1.0 credits deducted
- [ ] Complex scan (26-100 files): 2.0 credits deducted
- [ ] Large scan (100+ files): 5.0 credits deducted

---

## 3. Public Endpoints

### 3.1 Credit Packages
- [ ] `GET /api/v1/payments/packages` returns all packages
- [ ] No authentication required (public endpoint)
- [ ] Returns Starter, Pro, Enterprise packages
- [ ] Each package has `id`, `name`, `credits`, `price_usd`, `discount_percent`
- [ ] Prices match specification:
  - Starter: 10 credits, $8.00, 20% discount
  - Pro: 50 credits, $35.00, 30% discount
  - Enterprise: 200 credits, $120.00, 40% discount

### 3.2 Scan Pricing
- [ ] `GET /api/v1/payments/prices` returns pricing tiers
- [ ] No authentication required (public endpoint)
- [ ] Returns all complexity tiers
- [ ] Each tier has `complexity`, `file_range`, `price_usd`
- [ ] Prices match specification:
  - Simple: 1-5 files, $0.50
  - Standard: 6-25 files, $1.00
  - Complex: 26-100 files, $2.00
  - Large: 100+ files, $5.00

---

## 4. Payment Flow API

### 4.1 Initiate Payment
- [ ] `POST /api/v1/payments/initiate` creates payment request
- [ ] Requires authentication
- [ ] Requires `package_id` in request body
- [ ] Invalid package_id returns 400
- [ ] Returns `payment_id`, `amount_usdc`, `recipient_address`
- [ ] Returns `chain_id: 8453` (Base mainnet)
- [ ] Payment record created with `status: pending`

### 4.2 Verify Payment
- [ ] `POST /api/v1/payments/verify` confirms blockchain payment
- [ ] Requires `payment_id` and `transaction_hash`
- [ ] Valid transaction credits user account
- [ ] Payment status updated to `completed`
- [ ] Invalid transaction hash returns 400
- [ ] Already verified payment returns 409
- [ ] Expired payment returns 410

### 4.3 Payment History
- [ ] `GET /api/v1/payments/history` returns payment list
- [ ] Shows all payment attempts (pending, completed, failed)
- [ ] Each payment has `id`, `amount_usdc`, `credits`, `status`, `created_at`
- [ ] Pagination works correctly

---

## 5. Admin Endpoints

### 5.1 Gift Credits
- [ ] `POST /api/v1/payments/admin/gift` adds credits to user
- [ ] Requires admin authentication
- [ ] Non-admin returns 403 Forbidden
- [ ] Requires `user_id` and `credits` in request
- [ ] Creates credit transaction with `type: gift`
- [ ] Optional `reason` field for audit trail

### 5.2 Payment Stats
- [ ] `GET /api/v1/payments/admin/stats` returns statistics
- [ ] Requires admin authentication
- [ ] Returns `total_revenue`, `total_credits_sold`, `total_credits_used`
- [ ] Returns `active_users` (users with credits)
- [ ] Returns `payment_count` by status

---

## 6. Frontend - Credit Display

### 6.1 Dashboard Credit Widget
- [x] Credit balance displayed in Credits page (/credits)
- [x] Shows "0 credits" for new users
- [ ] Updates after purchase
- [ ] Updates after scan usage
- [x] "Buy Credits" button visible (via sidebar BILLING section)

### 6.2 Low Balance Warning
- [ ] Warning shown when credits < 5
- [ ] Warning shown before scan if insufficient credits
- [ ] "Buy Credits" CTA in warning

---

## 7. Frontend - Purchase Flow

### 7.1 Credit Package Selection
- [x] Package selection page shows all packages (/credits)
- [x] Discount percentages displayed
- [x] Price per credit calculated and shown
- [ ] "Best Value" badge on Enterprise package

### 7.2 Wallet Connection
- [x] "Connect Wallet" button triggers wallet connection
- [x] Coinbase Wallet connection flow works
- [x] WalletConnect option available
- [ ] Network check for Base mainnet (chain 8453)
- [ ] Prompt to switch network if wrong network

### 7.3 Payment Transaction
- [ ] USDC approval transaction if needed
- [ ] Transfer transaction to recipient address
- [ ] Transaction pending state shown
- [ ] Transaction hash displayed
- [ ] "Verifying payment..." state shown

### 7.4 Payment Confirmation
- [ ] Success message after verification
- [ ] Credits added to balance immediately
- [ ] Receipt/confirmation email sent
- [ ] Transaction history updated

### 7.5 Payment Errors
- [ ] User rejects transaction - handled gracefully
- [ ] Insufficient USDC balance - error shown
- [ ] Network error - retry option
- [ ] Verification timeout - support contact shown

---

## 8. Frontend - Scan Credit Usage

### 8.1 Pre-Scan Credit Check
- [ ] Credit cost shown before starting scan
- [ ] "Insufficient credits" blocks scan start
- [ ] "Buy Credits" option when insufficient
- [ ] Credit deduction shown in scan confirmation

### 8.2 Post-Scan Credit Update
- [ ] Balance updates after scan completes
- [ ] Credit usage shown in scan results
- [ ] Transaction appears in credit history

---

## 9. Database & Migration

### 9.1 Migration `014_add_x402_payments`
- [ ] Migration runs successfully
- [ ] `credit_packages` table created
- [ ] `scan_credits` table created
- [ ] `payment_transactions` table created
- [ ] `credit_transactions` table created

### 9.2 Data Integrity
- [ ] Foreign keys to users table work
- [ ] Unique constraint on payment transaction_hash
- [ ] Index on user_id for fast lookups
- [ ] Decimal precision correct for USDC amounts

### 9.3 Seed Data
- [ ] Default credit packages seeded
- [ ] Package pricing matches specification

---

## 10. Blockchain Integration

### 10.1 Base Network Configuration
- [ ] Chain ID 8453 configured correctly
- [ ] USDC contract address correct (Base mainnet)
- [ ] Recipient wallet address configured
- [ ] RPC endpoint configured

### 10.2 Transaction Verification
- [ ] Transaction hash validation
- [ ] Amount verification matches expected
- [ ] Recipient verification matches expected
- [ ] Block confirmations checked (min 3)

---

## 11. Error Handling

- [ ] 402 Payment Required for insufficient credits
- [ ] 400 Bad Request for invalid package/payment IDs
- [ ] 401 Unauthorized for missing auth token
- [ ] 403 Forbidden for non-admin accessing admin endpoints
- [ ] 409 Conflict for duplicate payment verification
- [ ] 410 Gone for expired payment requests
- [ ] 500 Internal Server Error handled gracefully

---

## 12. Edge Cases

- [ ] Concurrent credit usage doesn't cause negative balance
- [ ] Payment verification idempotent (can retry safely)
- [ ] Partial payment not credited
- [ ] Network timeout during verification - can retry
- [ ] User refresh during payment - state preserved

---

## 13. Local Development Testing

### 13.1 Option A: Base Sepolia Testnet (Recommended)
Use Base Sepolia testnet for realistic blockchain testing:

**Setup:**
```bash
# API Service environment variables
PAYMENT_CHAIN_ID=84532                                    # Base Sepolia
PAYMENT_USDC_ADDRESS=0x036CbD53842c5426634e7929541eC2318f3dCF7e  # Testnet USDC
PAYMENT_RECIPIENT_ADDRESS=YOUR_TEST_WALLET_ADDRESS

# Dashboard environment variable
VITE_USE_TESTNET=true
```

**Get Testnet USDC:**
1. Get Base Sepolia ETH: https://faucet.base.org
2. Swap for testnet USDC: https://app.uniswap.org (connect to Base Sepolia)
3. Or use Coinbase Wallet faucet

**Sepolia Tests:**
- [ ] TESTNET badge displays in PaymentModal
- [ ] Chain switches to Base Sepolia (84532) on wallet connect
- [ ] USDC balance fetched from Base Sepolia
- [ ] Transaction sent to correct Sepolia USDC contract
- [ ] Block explorer links point to sepolia.basescan.org
- [ ] Payment verification works with Sepolia transaction hash

**Test Steps:**
- [ ] Connect wallet to Base Sepolia network
- [ ] Verify testnet USDC balance shows in wallet
- [ ] Complete purchase flow with testnet tokens
- [ ] Verify credits added after verification

### 13.2 Option B: Admin Gift Credits (Quick Testing)
Skip blockchain payment entirely for rapid UI/API testing:

```bash
# Gift credits to test user via API
curl -X POST http://127.0.0.1:3000/api/v1/payments/admin/gift \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "YOUR_USER_ID", "credits": 100, "reason": "local testing"}'
```

**Test Steps:**
- [ ] Create test user and get user_id
- [ ] Gift 100 credits via admin endpoint
- [ ] Verify credits appear in dashboard
- [ ] Test scan with credits deduction

### 13.3 Option C: Mock Payment Mode
Enable mock mode to bypass blockchain verification:

```bash
# API Service environment variable
PAYMENT_MODE=mock
```

**Behavior in Mock Mode:**
- Payment initiation returns mock transaction data
- Verification always succeeds without blockchain check
- Credits added immediately
- Useful for frontend flow testing

### 13.4 Option D: Automated Test Suite
Run the comprehensive test suite (59 tests):

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Unit tests (30 tests)
.venv/bin/pytest tests/unit/services/test_payment_services.py -v

# Integration tests (29 tests)
.venv/bin/pytest tests/integration/test_payment_api.py -v

# All payment tests
.venv/bin/pytest -k "payment" -v
```

### 13.5 Quick Local Verification Checklist

**API Endpoints:**
```bash
# Check packages (public)
curl http://127.0.0.1:3000/api/v1/payments/packages | jq .

# Check pricing (public)
curl http://127.0.0.1:3000/api/v1/payments/prices | jq .

# Check user credits (requires auth)
curl -H "Authorization: Bearer TOKEN" \
  http://127.0.0.1:3000/api/v1/payments/credits | jq .
```

**Dashboard UI:**
- [ ] Navigate to http://127.0.0.1:3000/pricing
- [ ] Navigate to http://127.0.0.1:3000/credits
- [ ] Check BILLING section in sidebar
- [ ] No CSP errors in browser console (F12)

---

## Test Notes

_Record x402 payment test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
