# Changelog: x402 Pay-Per-Scan Implementation

**Date**: December 2-3, 2025
**Version**: API Service 0.3.1, Dashboard 0.6.7
**Phase**: 3.4 - x402 Pay-Per-Scan Integration

---

## Summary

Completed backend implementation for x402 pay-per-scan feature, enabling USDC micropayments on Base blockchain for scan credits.

---

## Changes

### API Service (0.3.1)

#### New Features
- **Payment API Endpoints** (`/api/v1/payments/*`)
  - `GET /payments/packages` - List available credit packages
  - `GET /payments/prices` - Get current pricing ($1.00/scan base)
  - `GET /payments/credits` - Get user credit balance
  - `POST /payments/credits/use` - Consume credits for scan
  - `GET /payments/credits/history` - Credit transaction history
  - `POST /payments/initiate` - Initiate x402 payment flow

#### Database
- Added 4 new tables:
  - `credit_packages` - Pre-defined credit bundles
  - `scan_credits` - Per-user credit balance
  - `payment_transactions` - USDC payment records
  - `credit_transactions` - Credit audit trail
- Seeded default packages (Starter/Standard/Professional/Enterprise)

#### Bug Fixes
- Fixed SQLAlchemy ORM relationship mapping for payment models
- Removed invalid `credit_transactions` relationship from `ScanCreditModel`
- Added proper `credit_transactions` relationship to `UserModel`

### Dashboard (0.6.7)

#### New Features (December 3, 2025)
- **BILLING sidebar section** with Pricing and Credits navigation links
- **x402 Pay-Per-Scan section** on Pricing page with pricing tiers
- **Feature comparison x402 column** showing pay-per-scan features
- **Credits page** (`/credits`) with:
  - Credit balance display
  - Credit package selection cards
  - WalletConnectButton integration for USDC payments
  - Credit history link
- **CSP updates** for Coinbase wallet integration

#### Bug Fixes
- Added missing `getApiClient()` export to `src/lib/api/client.ts`
- Fixed white screen on login caused by wallet API import error
- Fixed Connect Wallet button text visibility on login page (white text on white background)

---

## Credit Packages

| Package | Credits | Price | Discount | Per-Scan |
|---------|---------|-------|----------|----------|
| Starter | 5 | $4.50 | 10% | $0.90 |
| Standard | 10 | $8.00 | 20% | $0.80 |
| Professional | 25 | $17.50 | 30% | $0.70 |
| Enterprise | 50 | $30.00 | 40% | $0.60 |

---

## Pull Requests

| Repository | PR | Description |
|------------|-----|-------------|
| blocksecops-api-service | #107 | fix: Resolve SQLAlchemy relationship mapping errors |
| blocksecops-dashboard | #62 | fix: Add missing getApiClient export |

---

## Remaining Work

### Backend - ✅ COMPLETE (December 2, 2025)
All backend tasks now complete:
- ✅ Unit tests for payment services (30 tests)
- ✅ Integration tests for payment endpoints (29 tests)
- ✅ Update scan endpoint to return 402 with credit purchase option

### Frontend - IN PROGRESS (December 3, 2025)
Completed:
- ✅ BILLING sidebar section with navigation
- ✅ x402 Pay-Per-Scan section on Pricing page
- ✅ x402 column in Feature Comparison table
- ✅ Credits page with balance display
- ✅ Credit package selection UI
- ✅ WalletConnectButton integration
- ✅ CSP updates for Coinbase domains

Remaining:
- [ ] PaymentModal component (USDC transaction flow)
- [ ] Network switching prompt (Base mainnet)
- [ ] Payment verification flow
- [ ] Credit history page (/credits/history)
- [ ] Low balance warnings
- [ ] E2E tests

---

## Related Documentation

- Migration docs: `/docs/database/MIGRATIONS.md`
- Schema docs: `/docs/database/SCHEMA.md`
- API docs: `/blocksecops-docs/api/endpoints-reference.md`
- Task docs: `/TaskDocs-Apogee/phases/04-phase-3.4-x402-pay-per-scan/`
