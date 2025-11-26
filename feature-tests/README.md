# BlockSecOps Feature Test Checklists

**Created**: November 25, 2025
**Last Updated**: November 25, 2025

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

**P2 - Medium**
- Pricing page
- API response validation
- Error handling

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
