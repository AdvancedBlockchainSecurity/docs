# API Documentation

**Last Updated**: December 23, 2025
**API Version**: v1.3
**Base URL**: `https://api.blocksecops.com/api/v1`

---

## Overview

Complete API reference and integration guides for the BlockSecOps Platform. This directory contains documentation for all REST API endpoints, authentication flows, and integration patterns.

---

## Contents

### 📚 Core API Reference

- **[Endpoints Reference](endpoints-reference.md)** - Complete API endpoint documentation
  - All REST endpoints with request/response schemas
  - Authentication requirements
  - Example requests and responses
  - Error codes and handling

- **[Scanner Results API](scanner-results-api.md)** - Scanner result retrieval endpoints
  - Fetching scan results by contract ID
  - Vulnerability data structures
  - Gas analysis endpoints
  - Code quality metrics

### 💳 Payment API (Phase 3.4)

- **x402 Pay-Per-Scan Integration** - USDC micropayments on Base blockchain
  - Credit balance management (`GET /payments/credits`)
  - Credit packages with volume discounts (`GET /payments/packages`)
  - Scan pricing tiers (`GET /payments/prices`)
  - Payment initiation and verification (`POST /payments/initiate`, `/verify`)
  - Admin credit gifting (`POST /payments/admin/gift`)
  - See [Endpoints Reference](endpoints-reference.md#payments-phase-34---x402-pay-per-scan) for full documentation

### 🏢 Enterprise API (Phase 4.5)

- **Organizations & RBAC** - Multi-tenant team management
  - Create/manage organizations (`/api/v1/organizations`)
  - Role management with 5 system roles (`/api/v1/organizations/{id}/roles`)
  - Member management and invitations (`/api/v1/organizations/{id}/members`)
  - See [Endpoints Reference](endpoints-reference.md#organizations-phase-45---enterprise)

- **API Key Management** - Programmatic access control
  - Create API keys with scoped permissions (`/api/v1/api-keys`)
  - Configurable rate limits (per minute/hour)
  - Usage statistics and regeneration
  - See [Endpoints Reference](endpoints-reference.md#api-keys-phase-45---enterprise)

- **Audit Logging** - Compliance-grade activity tracking
  - Query and filter audit events (`/api/v1/audit-logs`)
  - Export to CSV/JSON formats
  - Summary statistics and reporting
  - See [Endpoints Reference](endpoints-reference.md#audit-logs-phase-45---enterprise)

- **Webhooks** - Event notification system
  - Subscribe to scan and vulnerability events (`/api/v1/webhooks`)
  - HMAC-SHA256 signature verification
  - Delivery history and retry logic
  - See [Endpoints Reference](endpoints-reference.md#webhooks-phase-45---enterprise)

### 🔧 Integration Guides

- **[Language Detection Guide](language-detection-guide.md)** - Multi-language contract detection
  - Automatic language detection (Solidity, Vyper, Cairo, Rust)
  - Language-specific scanning workflows
  - Scanner routing based on language

- **[Dashboard Integration](dashboard-integration.md)** - Frontend integration guide
  - WebSocket real-time updates
  - API client setup
  - Error handling best practices

---

## Quick Start

### 1. Authentication

All API requests require Supabase Auth JWT token:

```typescript
// Get token from Supabase
const { data: { session } } = await supabase.auth.getSession()

// Make API request
const response = await fetch('https://api.blocksecops.com/api/v1/contracts', {
  headers: {
    'Authorization': `Bearer ${session.access_token}`,
    'Content-Type': 'application/json'
  }
})
```

See **[Authentication System](../architecture/authentication-system.md)** for details.

### 2. Upload Contract

```bash
curl -X POST https://api.blocksecops.com/api/v1/contracts/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@MyContract.sol" \
  -F "name=MyContract" \
  -F "language=solidity"
```

### 3. Trigger Scan

```bash
curl -X POST https://api.blocksecops.com/api/v1/scans \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"contract_id": "contract-uuid", "scanners": ["slither", "aderyn"]}'
```

### 4. Get Results

```bash
curl -X GET https://api.blocksecops.com/api/v1/scans/{scan_id}/results \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## API Features

### Multi-Language Support
- **Solidity** (11 scanners)
- **Vyper** (2 scanners)
- **Rust/Solana** (4 scanners)
- **Cairo** (3 scanners)

### Security Analysis
- Static analysis (13 tools)
- Fuzzing (7 tools)
- Symbolic execution (2 tools)
- Formal verification (3 tools)
- SBOM generation

### Tier-Based Access
- **Free**: 10 scans/month, 100 KB max file size
- **Pro**: 100 scans/month, 1 MB max file size
- **Enterprise**: Unlimited scans, 10 MB max file size
- **Enterprise Broker**: Unlimited scans with white-label access

### Pay-Per-Scan (x402)
- **Alternative to subscriptions** - Pay per scan when quota exceeded
- **USDC on Base** - Instant, fee-free blockchain payments
- **Credit packages** - Volume discounts (20-40% off)
- **Pricing tiers** - $0.50-$5.00 based on scan complexity

---

## Related Documentation

### Architecture
- [API Service Architecture](../architecture/api-service-architecture.md) - DDD + Clean Architecture design
- [Authentication System](../architecture/authentication-system.md) - Supabase Auth integration

### Deployment
- [API Service Deployment](../deployment/api-service-deployment.md) - Production deployment
- [Local Configuration](../deployment/api-service-local-configuration.md) - Local development setup

### Development
- [Testing Guide](../development/testing-guide.md) - API testing strategies
- [CI/CD Automation](../development/ci-cd-automation.md) - Automated deployment

---

## OpenAPI Documentation

Interactive API documentation available at:
- **Local**: `http://localhost:8000/docs`
- **Production**: `https://api.blocksecops.com/docs`

---

## Support

For API issues or questions:
- Check [Troubleshooting Guide](../deployment/README.md)
- Review [Known Issues](../deployment/CHANGELOG.md)
- Contact: support@blocksecops.com

---

**Maintained by**: BlockSecOps Backend Team
**Last Review**: December 23, 2025
