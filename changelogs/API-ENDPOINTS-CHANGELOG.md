# API Endpoints Changelog

**Source**: Consolidated from `blocksecops-docs/api/endpoints-reference.md`
**Last Updated**: December 26, 2025

---

## v1.3.0 (2025-12-23)

**Added - Phase 4.5 Enterprise Feature Endpoints**:
- Organizations RBAC (`/api/v1/organizations/*`) - 12 endpoints for org/role/member management
- API Key Management (`/api/v1/api-keys/*`) - 8 endpoints for key creation, scopes, rate limits
- Audit Logging (`/api/v1/audit-logs/*`) - 6 endpoints for query, filter, and export
- Webhooks (`/api/v1/webhooks/*`) - Event notification system

**Database Schema Updates**:
- `api_keys`: Added `rate_limit_per_minute`, `rate_limit_per_hour`, `revoked_at` columns
- `organizations`: Added `stripe_subscription_id`, `sso_enabled`, `sso_provider`, `sso_config`, `sso_domain` columns
- `organization_members`: Added `is_active` column

**Tier Access Control**:
- Organizations: Enterprise only for create/update/delete
- API Keys: Pro+ for create/modify, all tiers for view
- Audit Logs: Enterprise only
- API Key Scopes: Public (no auth required)

**Technical**:
- API Service version 0.5.0
- 31 new enterprise endpoints total
- SHA-256 hashed API key storage with `bso_` prefix
- HMAC-SHA256 webhook signatures with `whsec_` prefix

---

## v1.2.3 (2025-12-11)

**Added - Phase 3.1b Sprint 3**:
- Favorites API endpoints (`/favorites/*`)
- Vulnerability Annotations API endpoints (`/annotations/*`)
- CopyButton and CopyableText UI components
- FavoriteButton and FavoritesWidget components
- AnnotationBadge, AnnotationDropdown, AnnotationHistory components

**Database**:
- Migration 016: `user_favorites` table
- Migration 017: `vulnerability_annotations` and `vulnerability_annotation_history` tables

**Technical**:
- Optimistic UI updates for favorites and annotations
- Annotation history for audit trail
- Bulk annotation support (max 100 per request)
- API version 0.7.0, Dashboard version 0.9.2

---

## v1.2.2 (2025-12-11)

**Added - Phase 3.1b Task 22**:
- Scan Comparison endpoint (`GET /scans/compare`)
- Compare two scans to identify new, fixed, and unchanged vulnerabilities
- Fingerprint-based vulnerability matching using Intelligence Layer
- Summary by severity breakdown
- Dashboard Scan Comparison page (`/scans/compare`)
- Same-contract filtering for meaningful comparisons
- Scanner scope filtering (All Scanners vs Same Scanner Only)

**Technical**:
- ScanComparisonService using fingerprint-based matching
- Vulnerability status classification: new, fixed, unchanged, modified
- Response includes scan metadata, vulnerability details, and severity summary
- API version 0.6.0, Dashboard version 0.9.1

---

## v1.2.1 (2025-12-10)

**Added - Phase 3.1b Task 21**:
- User Activity Log endpoint (`GET /users/me/activity`)
- Activity log with pagination, filtering, and summary statistics
- Database table `user_activity_logs` with migration 015
- Dashboard Activity Log page (`/activity`)

**Technical**:
- Activity types: file_upload, contract_created/deleted, scan_started/completed/failed, payment, credit_purchase, credit_used
- Aggregated summary: scans completed, scans failed, total credits used, total payments
- Links to related contracts and scans for easy navigation
- API version 0.5.0, Dashboard version 0.9.0

---

## v1.2.0 (2025-12-07)

**Added - Phase 3.4 Frontend Complete**:
- PaymentModal component with multi-step payment flow
- PaymentContext provider for global payment state
- CreditBalance widget (header, compact, full modes)
- Credits page with package selection and purchase
- CreditHistory page for transaction history
- Pricing page with x402 Pay-Per-Scan section
- wagmi Web3 integration (MetaMask, WalletConnect, Coinbase Wallet)

**Technical**:
- Dashboard now uses real API data (no mock data)
- USDC on Base mainnet (0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)
- Base Sepolia testnet support for development

---

## v1.1.1 (2025-12-02)

**Added**:
- Enhanced 402 response with `payment_options` for x402 integration
- Payment options include credit balance, pricing tiers, and USDC payment details
- Backend tests: 30 unit tests + 29 integration tests for payment services

**Technical**:
- Scan endpoint returns payment options in 402 quota exceeded response
- Frontend can now offer pay-per-scan option when quota exceeded
- All payment endpoints tested and verified (100% success rate)

---

## v1.1.0 (2025-12-01)

**Added**:
- x402 Payment endpoints (Phase 3.4)
- Credit balance management (`GET /payments/credits`)
- Credit usage tracking (`POST /payments/credits/use`)
- Credit transaction history (`GET /payments/credits/history`)
- Credit package listing (`GET /payments/packages`)
- Scan pricing tiers (`GET /payments/prices`)
- Payment initiation (`POST /payments/initiate`)
- Payment verification (`POST /payments/verify`)
- Payment history (`GET /payments/history`)
- Admin credit gifting (`POST /payments/admin/gift`)
- Admin payment stats (`GET /payments/admin/stats`)

**Technical**:
- x402 protocol support for USDC on Base blockchain
- Credit packages with volume discounts (20-40%)
- Per-scan pricing based on complexity ($0.50-$5.00)
- Full transaction history and audit trail

---

## v1.0.0 (2025-10-06)

**Added**:
- Complete CRUD operations for contracts
- Scan management endpoints
- Vulnerability tracking with status updates
- Dashboard statistics aggregation
- 30-day historical data
- File upload for Solidity files
- User profile management
- Health check endpoints

**Tested**:
- All 14 endpoints tested and verified
- 100% success rate
- Comprehensive test suite created
