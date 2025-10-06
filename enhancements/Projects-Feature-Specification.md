# Feature Specification: Project Grouping & Transaction Hash Support

**Version**: 1.0
**Date**: October 6, 2025
**Status**: Approved for Implementation
**Owner**: Backend Team

---

## Executive Summary

This specification defines two major enhancements to the Solidity Security Platform:

1. **Transaction Hash Integration** - Enable contract scanning via blockchain transaction hash
2. **Project Grouping** - Allow customers to organize multiple contracts into logical projects

### Business Value

**Transaction Hash Support**:
- Reduces onboarding friction by 60% (estimated)
- Eliminates manual data entry errors
- Enables automatic contract verification
- Supports verification of deployed bytecode against source

**Project Grouping**:
- Aligns platform with customer mental models (projects, not isolated contracts)
- Enables holistic security assessment across multi-contract systems
- Supports enterprise customers with complex DeFi/DAO infrastructures
- Facilitates compliance reporting at project level

### Target Users

- **DeFi Developers**: Managing 5-20 contracts per protocol
- **NFT Projects**: Managing 2-5 contracts per collection
- **DAO Builders**: Managing 3-10 governance contracts
- **Security Auditors**: Reviewing multi-contract systems
- **Enterprise Teams**: Coordinating across multiple developers

---

## Feature 1: Transaction Hash Support

### User Stories

**Story 1: Quick Contract Addition**
> As a developer who just deployed a contract,
> I want to paste my deployment transaction hash,
> So that the platform automatically fetches my contract details and starts scanning.

**Story 2: Verification**
> As a security-conscious developer,
> I want to verify that my deployed bytecode matches my source code,
> So that I can ensure no malicious changes were introduced during deployment.

**Story 3: Historical Analysis**
> As an auditor,
> I want to see when a contract was deployed and on which block,
> So that I can correlate vulnerabilities with deployment timeline.

### Functional Requirements

#### FR-1: Transaction Hash Input
- System SHALL accept Ethereum transaction hash (0x followed by 64 hexadecimal characters)
- System SHALL support multiple networks (Ethereum Mainnet, Polygon, Arbitrum, Optimism)
- System SHALL validate transaction hash format before blockchain lookup

#### FR-2: Automatic Contract Discovery
- System SHALL fetch transaction receipt from blockchain
- System SHALL extract contract address from receipt
- System SHALL fetch deployed bytecode
- System SHALL fetch source code if verified on Etherscan/Polygonscan

#### FR-3: Deployment Metadata
- System SHALL store deployment block number
- System SHALL store deployment timestamp
- System SHALL calculate contract age in days
- System SHALL track verification status

#### FR-4: Source Code Verification
- System SHALL compare user-provided source code with verified source (if available)
- System SHALL compare compiled bytecode hash with deployed bytecode hash
- System SHALL flag mismatches as security warnings

### Non-Functional Requirements

#### NFR-1: Performance
- Transaction lookup SHALL complete within 5 seconds (90th percentile)
- System SHALL cache blockchain responses for 24 hours
- System SHALL implement exponential backoff for API failures

#### NFR-2: Reliability
- System SHALL gracefully handle network timeouts
- System SHALL retry failed blockchain API calls up to 3 times
- System SHALL provide clear error messages for invalid transactions

#### NFR-3: Security
- System SHALL validate transaction created a contract (not EOA transfer)
- System SHALL rate limit blockchain API calls (20 per hour per user)
- System SHALL not expose blockchain API keys to clients

### API Specification

**Endpoint**: `POST /api/v1/contracts/from-transaction`

**Request Body**:
```json
{
  "name": "MyToken",
  "transaction_hash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "network": "ethereum",
  "source_code": "pragma solidity ^0.8.0; ...",  // Optional
  "expected_address": "0xabcd..."  // Optional - for validation
}
```

**Success Response** (201 Created):
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "660e8400-e29b-41d4-a716-446655440001",
  "name": "MyToken",
  "address": "0xabcdef1234567890abcdef1234567890abcdef12",
  "transaction_hash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "network": "ethereum",
  "block_number": 18500000,
  "deployment_date": "2025-10-05T14:30:00Z",
  "bytecode": "0x608060405234801561001057600080fd5b50...",
  "lines_of_code": 0,
  "status": "pending",
  "verified_source": false,
  "created_at": "2025-10-06T10:00:00Z"
}
```

**Error Responses**:

| Code | Reason | Response |
|------|--------|----------|
| 400 | Invalid hash format | `{"detail": "Transaction hash must be 0x followed by 64 hex characters"}` |
| 404 | Transaction not found | `{"detail": "Transaction not found on ethereum network"}` |
| 400 | Not a contract deployment | `{"detail": "Transaction did not create a contract"}` |
| 429 | Rate limit exceeded | `{"detail": "Blockchain API rate limit exceeded. Try again in 60 seconds"}` |
| 503 | Blockchain API unavailable | `{"detail": "Blockchain service temporarily unavailable"}` |

---

## Feature 2: Project Grouping

### User Stories

**Story 1: Project Creation**
> As a DeFi developer with multiple related contracts,
> I want to create a project called "Staking Protocol v2",
> So that I can group my Token, Staking, and Rewards contracts together.

**Story 2: Aggregated Vulnerability View**
> As a security lead,
> I want to see total critical vulnerabilities across all 8 contracts in my DAO project,
> So that I can prioritize remediation at the project level.

**Story 3: Project Dashboard**
> As a project manager,
> I want a single dashboard showing all security metrics for my NFT marketplace,
> So that I can report to stakeholders without manual aggregation.

### Functional Requirements

#### FR-5: Project Management
- System SHALL allow users to create projects with name and description
- System SHALL allow users to add/remove contracts from projects
- System SHALL allow users to delete projects (contracts remain, only unlinked)
- System SHALL allow users to add tags to projects (e.g., "defi", "v1.0", "mainnet")

#### FR-6: Contract-Project Association
- Contract MAY belong to zero or one project
- Moving contract to different project SHALL unlink from previous project
- Deleting project SHALL NOT delete contracts (only unlinks)
- System SHALL track when contract was added to project

#### FR-7: Aggregated Statistics
- System SHALL calculate total vulnerabilities across all project contracts
- System SHALL calculate project risk score (weighted by severity)
- System SHALL show vulnerability breakdown by contract
- System SHALL show scan history across all contracts
- System SHALL calculate total lines of code in project

#### FR-8: Project Dashboard
- System SHALL display project summary card with key metrics
- System SHALL list all contracts in project with individual stats
- System SHALL highlight highest-risk contracts
- System SHALL show last scan date across all contracts

### Non-Functional Requirements

#### NFR-4: Performance
- Project statistics query SHALL complete within 2 seconds
- System SHALL cache project statistics for 5 minutes
- System SHALL invalidate cache on new scan/vulnerability

#### NFR-5: Scalability
- System SHALL support projects with up to 100 contracts
- System SHALL efficiently query projects with 1000+ vulnerabilities
- Database queries SHALL use proper indexes

#### NFR-6: Data Integrity
- System SHALL prevent orphaned contracts (contract without user)
- System SHALL prevent circular dependencies
- System SHALL use database constraints for referential integrity

### Data Model

**Projects Table**:
```sql
CREATE TABLE projects (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    tags TEXT[],
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT projects_name_length CHECK (char_length(name) >= 1)
);

CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_projects_tags ON projects USING GIN(tags);
```

**Contracts Table Update**:
```sql
ALTER TABLE contracts
ADD COLUMN project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

CREATE INDEX idx_contracts_project_id ON contracts(project_id);
```

### API Specification

#### Project CRUD

**Create Project**: `POST /api/v1/projects`

Request:
```json
{
  "name": "DeFi Platform v1.0",
  "description": "Main staking and governance protocol",
  "tags": ["defi", "staking", "governance", "mainnet"]
}
```

Response (201):
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "name": "DeFi Platform v1.0",
  "description": "Main staking and governance protocol",
  "tags": ["defi", "staking", "governance", "mainnet"],
  "contract_count": 0,
  "total_vulnerabilities": {"critical": 0, "high": 0, "medium": 0, "low": 0},
  "risk_score": 0,
  "created_at": "2025-10-06T10:00:00Z",
  "updated_at": "2025-10-06T10:00:00Z"
}
```

**List Projects**: `GET /api/v1/projects?skip=0&limit=20`

Response (200):
```json
{
  "projects": [
    {
      "id": "uuid",
      "name": "DeFi Platform v1.0",
      "description": "...",
      "contract_count": 5,
      "total_vulnerabilities": {"critical": 2, "high": 5, "medium": 8, "low": 3},
      "risk_score": 65.5,
      "created_at": "2025-10-01T10:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 20
}
```

**Get Project Details**: `GET /api/v1/projects/{id}`

Response (200):
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "name": "DeFi Platform v1.0",
  "description": "Main staking and governance protocol",
  "tags": ["defi", "staking", "governance"],
  "contract_count": 5,
  "contracts": [
    {
      "id": "uuid1",
      "name": "TokenContract",
      "address": "0x1234...",
      "status": "scanned",
      "vulnerabilities": {"critical": 1, "high": 2, "medium": 3, "low": 1}
    },
    {
      "id": "uuid2",
      "name": "StakingContract",
      "address": "0x5678...",
      "status": "scanned",
      "vulnerabilities": {"critical": 0, "high": 3, "medium": 2, "low": 1}
    }
  ],
  "total_vulnerabilities": {"critical": 2, "high": 5, "medium": 8, "low": 3},
  "risk_score": 65.5,
  "created_at": "2025-10-01T10:00:00Z",
  "updated_at": "2025-10-06T10:00:00Z"
}
```

**Update Project**: `PUT /api/v1/projects/{id}`

Request:
```json
{
  "name": "DeFi Platform v1.1",
  "description": "Updated with new governance features",
  "tags": ["defi", "staking", "governance", "v1.1", "mainnet"]
}
```

**Delete Project**: `DELETE /api/v1/projects/{id}`

Response (204): No content (contracts remain, unlinked)

#### Project-Contract Association

**Add Contract to Project**: `POST /api/v1/projects/{project_id}/contracts/{contract_id}`

Response (200):
```json
{
  "message": "Contract added to project",
  "project_id": "uuid",
  "contract_id": "uuid"
}
```

**Remove Contract from Project**: `DELETE /api/v1/projects/{project_id}/contracts/{contract_id}`

Response (204): No content

#### Project Analytics

**Project Statistics**: `GET /api/v1/projects/{id}/statistics`

Response (200):
```json
{
  "project_id": "uuid",
  "project_name": "DeFi Platform v1.0",
  "total_contracts": 5,
  "total_scans": 12,
  "total_lines_of_code": 2450,
  "contracts": [
    {
      "id": "uuid1",
      "name": "TokenContract",
      "address": "0x1234...",
      "lines_of_code": 450,
      "scan_count": 3,
      "last_scan_date": "2025-10-05T14:00:00Z",
      "vulnerabilities": {"critical": 1, "high": 2, "medium": 3, "low": 1}
    }
  ],
  "vulnerabilities": {
    "critical": 3,
    "high": 7,
    "medium": 15,
    "low": 7
  },
  "vulnerability_trend": [
    {"date": "2025-10-01", "critical": 5, "high": 10, "medium": 18, "low": 8},
    {"date": "2025-10-06", "critical": 3, "high": 7, "medium": 15, "low": 7}
  ],
  "risk_score": 78.5,
  "risk_level": "high",
  "last_scan_date": "2025-10-06T14:30:00Z"
}
```

**Project Vulnerabilities**: `GET /api/v1/projects/{id}/vulnerabilities`

Response (200): Same as GET /api/v1/vulnerabilities but filtered to project contracts

---

## UI/UX Considerations

### Project Creation Flow
1. User clicks "Create Project" button
2. Modal appears with form (name, description, tags)
3. User submits, project created
4. User redirected to project dashboard
5. Empty state shows "Add contracts to get started"

### Adding Contracts to Project
- **Option 1**: Drag-and-drop from contracts list to project card
- **Option 2**: Select multiple contracts → "Add to Project" bulk action
- **Option 3**: Create new contract → Select project in form

### Project Dashboard Layout
```
+----------------------------------------------------------+
|  DeFi Platform v1.0                    [Edit] [Delete]   |
|  Main staking and governance protocol                    |
|  Tags: defi, staking, governance, mainnet                |
+----------------------------------------------------------+
|  Risk Score: 78.5 (High)    |  Last Scan: 2 hours ago   |
|  5 Contracts | 12 Scans     |  2.4K Lines of Code       |
+----------------------------------------------------------+
|  Vulnerabilities:                                        |
|  🔴 Critical: 3   🟠 High: 7   🟡 Medium: 15   ⚪ Low: 7 |
+----------------------------------------------------------+
|  Contracts in This Project:                              |
|  +------------------------------------------------------+|
|  | TokenContract        0x1234...  ⚠️ 1 Critical       ||
|  | StakingContract      0x5678...  ✅ No Critical      ||
|  | GovernanceContract   0x9abc...  ⚠️ 2 Critical       ||
|  | TreasuryContract     0xdef0...  ✅ No Critical      ||
|  | OracleContract       0x1111...  ✅ No Critical      ||
|  +------------------------------------------------------+|
+----------------------------------------------------------+
```

---

## Testing Strategy

### Unit Tests
- [ ] Project CRUD operations
- [ ] Contract-project association
- [ ] Risk score calculation
- [ ] Statistics aggregation
- [ ] Transaction hash validation
- [ ] Blockchain service mocking

### Integration Tests
- [ ] Create project → Add contracts → View statistics
- [ ] Fetch contract via transaction hash → Verify bytecode
- [ ] Multi-user project isolation
- [ ] Project deletion (contracts remain)

### End-to-End Tests
- [ ] Full project workflow in UI
- [ ] Transaction hash flow with real Ethereum testnet
- [ ] Performance test: 50 contracts in project
- [ ] Concurrent user access to same project

---

## Deployment Strategy

### Phase 1: Database Migration
1. Deploy migration to add projects table
2. Deploy migration to add project_id to contracts
3. Verify indexes created
4. Verify no downtime

### Phase 2: API Deployment
1. Deploy API with new endpoints (disabled)
2. Run smoke tests
3. Enable project endpoints via feature flag
4. Monitor error rates

### Phase 3: UI Deployment
1. Deploy UI with project management interface
2. Enable for beta users (10%)
3. Gather feedback
4. Gradual rollout to 100%

---

## Success Criteria

### Transaction Hash Feature
- ✅ 80% of new contracts added via transaction hash (within 3 months)
- ✅ 95% success rate for blockchain fetches
- ✅ Average time to add contract reduced from 2 minutes to 30 seconds
- ✅ Less than 1% invalid transaction hash errors

### Project Grouping Feature
- ✅ 50% of active users create at least one project (within 3 months)
- ✅ Average 3-7 contracts per project
- ✅ 90% of users view project statistics weekly
- ✅ Customer satisfaction score increases by 15 points

---

## Appendix

### Blockchain API Costs

| Provider | Free Tier | Paid Tier | Cost per 1M Calls |
|----------|-----------|-----------|-------------------|
| Etherscan | 5 calls/sec | 100 calls/sec | $0 (API key required) |
| Polygonscan | 5 calls/sec | 100 calls/sec | $0 (API key required) |
| Infura | 100k calls/day | 1M calls/day | $50/month |
| Alchemy | 300M compute units/month | Custom | $199/month (starter) |

**Recommendation**: Use Etherscan/Polygonscan as primary, Infura as fallback.

### Database Schema Complete

See: `/Users/pwner/Git/ABS/TaskDocs/SolidityOps/api/API-Enhancement-Projects-and-Transactions.md`

---

**Document Approvers**:
- [ ] Product Manager
- [ ] Engineering Lead
- [ ] Security Lead
- [ ] UX Designer
