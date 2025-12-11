# BlockSecOps Feature Test Checklists

**Created**: November 25, 2025
**Last Updated**: December 10, 2025 (added user activity logging tests)

---

## Overview

This directory contains manual testing checklists for all user-facing features of the BlockSecOps platform. Each file focuses on a specific feature area.

## Status Legend

| Status | Meaning |
|--------|---------|
| [ ] | Not tested |
| [x] | Passed |
| [!] | Failed - needs fix |
| [-] | Blocked/Cannot test |

---

## Test Files

| File | Description | Priority |
|------|-------------|----------|
| [01-authentication.md](./01-authentication.md) | Login, logout, registration, sessions | P0 |
| [02-quota-system.md](./02-quota-system.md) | Tier limits, scan quotas, file limits | P0 |
| [03-file-upload.md](./03-file-upload.md) | Single file and archive uploads | P0 |
| [04-framework-detection.md](./04-framework-detection.md) | Foundry, Hardhat, OpenZeppelin support | P1 |
| [05-projects.md](./05-projects.md) | Projects CRUD and dashboard | P1 |
| [06-scanning.md](./06-scanning.md) | Scan triggers, results, scanner selection | P0 |
| [07-pricing-page.md](./07-pricing-page.md) | Pricing display and upgrade flows | P2 |
| [08-api-responses.md](./08-api-responses.md) | API response validation | P2 |
| [09-error-handling.md](./09-error-handling.md) | Error messages and edge cases | P2 |
| [10-tier-upgrades.md](./10-tier-upgrades.md) | Free to Pro/Enterprise upgrade flows | P1 |
| [11-wallet-authentication.md](./11-wallet-authentication.md) | MetaMask/WalletConnect auth (Phase 3.3) | P1 |
| [12-enhanced-contract-details.md](./12-enhanced-contract-details.md) | Contract metadata, security score, dependencies (Phase 3.4) | P2 |
| [13-vyper-rust-scanners.md](./13-vyper-rust-scanners.md) | Vyper & Solana/Rust scanner integration (Phase 3.5) | P2 |
| [14-enterprise-features.md](./14-enterprise-features.md) | Webhooks, RBAC, SSO, API Keys, Audit Logs (Phase 4.5) | P1 |
| [15-x402-pay-per-scan.md](./15-x402-pay-per-scan.md) | USDC micropayments, credits, pricing (Phase 3.4) | P1 |
| [16-user-activity-logging.md](./16-user-activity-logging.md) | Activity log API, dashboard UI, activity tracking (Phase 3.1b) | P1 |

---

## Testing Priority

**P0 - Critical (Test First)**
- Authentication
- File upload
- Scanning
- Quota enforcement

**P1 - High (Test Next)**
- Framework detection (Foundry/Hardhat)
- Smart dependency extraction
- Projects feature
- Wallet authentication (MetaMask/WalletConnect)
- Enterprise features (Webhooks, RBAC, SSO, API Keys)
- x402 Pay-Per-Scan (USDC payments, credits)
- User Activity Logging (activity API, dashboard UI)

**P2 - Medium**
- Pricing page
- API response validation
- Error handling
- Enhanced contract details (metadata, security score, dependencies)
- Vyper & Solana/Rust scanner integration

---

## Test Data Resources

### Sample Projects
- Foundry: `TaskDocs-BlockSecOps/phases/03-phase-3.2-project-structure-support/test-projects/foundry-sample/`
- Hardhat: `TaskDocs-BlockSecOps/phases/03-phase-3.2-project-structure-support/test-projects/hardhat-sample/`

### Test Users
Create test users for each tier:
- Free tier test user
- Pro tier test user
- Enterprise tier test user

---

## Testing Notes

_Record test session notes here:_

```
[Date] | [Tester] | [File] | [Summary]
```

---

## Related Documentation

- Phase 3.2 README: `TaskDocs-BlockSecOps/phases/03-phase-3.2-project-structure-support/README.md`
- Quota Spec: `TaskDocs-BlockSecOps/phases/FREEMIUM-MODEL/PRICING-TIERS-SPECIFICATION.md`
- Framework Support: `blocksecops-docs/features/framework-support.md`
- ~~SBOM API: `blocksecops-docs/api/sbom-api.md`~~ (ROLLED BACK Nov 30, 2025)
