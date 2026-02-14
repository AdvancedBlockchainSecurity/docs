# Miscellaneous Endpoints

This document covers smaller endpoint groups that do not warrant their own dedicated file. All endpoints require authentication and are prefixed with `/api/v1` unless otherwise noted.

---

## Annotations

Annotations allow users to attach notes and context to scan results and vulnerabilities.

### POST /api/v1/annotations

Create a new annotation.

```bash
curl -X POST https://api.blocksecops.com/api/v1/annotations \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "vulnerability",
    "entity_id": "vuln_abc123",
    "content": "This is a known false positive in our proxy pattern",
    "type": "false_positive"
  }'
```

**Response 201:**

```json
{
  "id": "ann_001",
  "entity_type": "vulnerability",
  "entity_id": "vuln_abc123",
  "content": "This is a known false positive in our proxy pattern",
  "type": "false_positive",
  "author_id": "usr_abc123",
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/annotations

List annotations with filtering.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/annotations?entity_type=vulnerability&page=1&limit=25" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "annotations": [
    {
      "id": "ann_001",
      "entity_type": "vulnerability",
      "entity_id": "vuln_abc123",
      "content": "This is a known false positive in our proxy pattern",
      "type": "false_positive",
      "author_id": "usr_abc123",
      "author_name": "Jane Doe",
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 15
}
```

### POST /api/v1/annotations/bulk

Create multiple annotations in a single request.

```bash
curl -X POST https://api.blocksecops.com/api/v1/annotations/bulk \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "annotations": [
      {
        "entity_type": "vulnerability",
        "entity_id": "vuln_001",
        "content": "False positive",
        "type": "false_positive"
      },
      {
        "entity_type": "vulnerability",
        "entity_id": "vuln_002",
        "content": "Accepted risk",
        "type": "accepted_risk"
      }
    ]
  }'
```

**Response 201:**

```json
{
  "created": 2,
  "annotations": [ ... ]
}
```

### GET /api/v1/annotations/scan/{scan_id}

List all annotations for a specific scan.

```bash
curl -X GET https://api.blocksecops.com/api/v1/annotations/scan/scan_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "annotations": [ ... ],
  "total": 5
}
```

### GET /api/v1/annotations/vulnerability/{vulnerability_id}

List all annotations for a specific vulnerability.

```bash
curl -X GET https://api.blocksecops.com/api/v1/annotations/vulnerability/vuln_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "annotations": [ ... ],
  "total": 2
}
```

### DELETE /api/v1/annotations/{id}

Delete an annotation.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/annotations/ann_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

### GET /api/v1/annotations/{id}/history

Retrieve the edit history of an annotation.

```bash
curl -X GET https://api.blocksecops.com/api/v1/annotations/ann_001/history \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "history": [
    {
      "version": 2,
      "content": "This is a known false positive in our proxy pattern",
      "edited_by": "usr_abc123",
      "edited_at": "2026-02-14T14:00:00Z"
    },
    {
      "version": 1,
      "content": "Possible false positive",
      "edited_by": "usr_abc123",
      "edited_at": "2026-02-14T12:00:00Z"
    }
  ]
}
```

---

## Assignments

Manage vulnerability and finding assignments to team members.

### POST /api/v1/assignments

Create a new assignment.

```bash
curl -X POST https://api.blocksecops.com/api/v1/assignments \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "vulnerability",
    "entity_id": "vuln_abc123",
    "assignee_id": "usr_def456",
    "priority": "high",
    "due_date": "2026-02-21T00:00:00Z"
  }'
```

**Response 201:**

```json
{
  "id": "asgn_001",
  "entity_type": "vulnerability",
  "entity_id": "vuln_abc123",
  "assignee_id": "usr_def456",
  "assigned_by": "usr_abc123",
  "priority": "high",
  "status": "open",
  "due_date": "2026-02-21T00:00:00Z",
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/assignments

List all assignments with filtering.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/assignments?status=open&priority=high" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "assignments": [ ... ],
  "total": 8
}
```

### GET /api/v1/assignments/my

List assignments assigned to the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/assignments/my \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "assignments": [ ... ],
  "total": 3
}
```

### GET /api/v1/assignments/stats

Retrieve assignment statistics.

```bash
curl -X GET https://api.blocksecops.com/api/v1/assignments/stats \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "total": 25,
  "open": 8,
  "in_progress": 10,
  "completed": 7,
  "overdue": 2,
  "by_priority": {
    "critical": 3,
    "high": 8,
    "medium": 10,
    "low": 4
  }
}
```

### GET /api/v1/assignments/{id}

Retrieve a specific assignment.

```bash
curl -X GET https://api.blocksecops.com/api/v1/assignments/asgn_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:** Returns the full assignment object.

### PATCH /api/v1/assignments/{id}

Update an assignment (status, priority, assignee, due date).

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/assignments/asgn_001 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress",
    "priority": "critical"
  }'
```

**Response 200:** Returns the updated assignment object.

### DELETE /api/v1/assignments/{id}

Delete an assignment.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/assignments/asgn_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## Comments

Threaded comments on entities (vulnerabilities, scans, contracts).

### POST /api/v1/comments

Create a comment.

```bash
curl -X POST https://api.blocksecops.com/api/v1/comments \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "vulnerability",
    "entity_id": "vuln_abc123",
    "content": "I have confirmed this is exploitable. We should fix immediately.",
    "parent_id": null
  }'
```

**Response 201:**

```json
{
  "id": "cmt_001",
  "entity_type": "vulnerability",
  "entity_id": "vuln_abc123",
  "content": "I have confirmed this is exploitable. We should fix immediately.",
  "author_id": "usr_abc123",
  "author_name": "Jane Doe",
  "parent_id": null,
  "reply_count": 0,
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/comments/entity/{entity_type}/{entity_id}

List comments for a specific entity.

```bash
curl -X GET https://api.blocksecops.com/api/v1/comments/entity/vulnerability/vuln_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "comments": [
    {
      "id": "cmt_001",
      "content": "I have confirmed this is exploitable. We should fix immediately.",
      "author_id": "usr_abc123",
      "author_name": "Jane Doe",
      "parent_id": null,
      "reply_count": 1,
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 3
}
```

### GET /api/v1/comments/threads

List comment threads for the current user's workspace.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/comments/threads?page=1&limit=25" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "threads": [
    {
      "entity_type": "vulnerability",
      "entity_id": "vuln_abc123",
      "entity_name": "Reentrancy in withdraw()",
      "comment_count": 3,
      "last_comment_at": "2026-02-14T14:00:00Z",
      "participants": ["Jane Doe", "Bob Smith"]
    }
  ],
  "total": 10
}
```

### GET /api/v1/comments/mentions

List comments where the authenticated user is mentioned.

```bash
curl -X GET https://api.blocksecops.com/api/v1/comments/mentions \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "mentions": [
    {
      "comment_id": "cmt_005",
      "content": "Hey @jane, can you review this finding?",
      "author_name": "Bob Smith",
      "entity_type": "vulnerability",
      "entity_id": "vuln_def456",
      "created_at": "2026-02-14T13:00:00Z"
    }
  ],
  "total": 2
}
```

### GET /api/v1/comments/my

List comments authored by the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/comments/my \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "comments": [ ... ],
  "total": 15
}
```

### GET /api/v1/comments/{id}

Retrieve a specific comment.

```bash
curl -X GET https://api.blocksecops.com/api/v1/comments/cmt_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:** Returns the full comment object.

### PATCH /api/v1/comments/{id}

Edit a comment. Only the author can edit their own comments.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/comments/cmt_001 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "I have confirmed this is exploitable. Critical priority - fix in next release."
  }'
```

**Response 200:** Returns the updated comment object.

### DELETE /api/v1/comments/{id}

Delete a comment.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/comments/cmt_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## Favorites

Bookmark entities for quick access.

### POST /api/v1/favorites

Add an entity to favorites.

```bash
curl -X POST https://api.blocksecops.com/api/v1/favorites \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "contract",
    "entity_id": "contract_abc123"
  }'
```

**Response 201:**

```json
{
  "id": "fav_001",
  "entity_type": "contract",
  "entity_id": "contract_abc123",
  "position": 1,
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/favorites

List all favorites for the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/favorites \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "favorites": [
    {
      "id": "fav_001",
      "entity_type": "contract",
      "entity_id": "contract_abc123",
      "entity_name": "My DeFi Protocol",
      "position": 1,
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 5
}
```

### GET /api/v1/favorites/check/{entity_type}/{entity_id}

Check if a specific entity is favorited.

```bash
curl -X GET https://api.blocksecops.com/api/v1/favorites/check/contract/contract_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "is_favorited": true,
  "favorite_id": "fav_001"
}
```

### PUT /api/v1/favorites/reorder

Reorder favorites.

```bash
curl -X PUT https://api.blocksecops.com/api/v1/favorites/reorder \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "order": ["fav_003", "fav_001", "fav_002"]
  }'
```

**Response 200:**

```json
{
  "message": "Favorites reordered successfully"
}
```

### DELETE /api/v1/favorites/{entity_type}/{entity_id}

Remove an entity from favorites.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/favorites/contract/contract_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## Feedback

Submit and view user feedback.

### POST /api/v1/feedback

Submit feedback.

```bash
curl -X POST https://api.blocksecops.com/api/v1/feedback \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "feature_request",
    "subject": "Support for Vyper contracts",
    "message": "It would be great if BlockSecOps could scan Vyper contracts in addition to Solidity.",
    "page_url": "https://app.blocksecops.com/scans"
  }'
```

**Response 201:**

```json
{
  "id": "fb_001",
  "type": "feature_request",
  "subject": "Support for Vyper contracts",
  "status": "submitted",
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/feedback/my-submissions

List feedback submitted by the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/feedback/my-submissions \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "submissions": [
    {
      "id": "fb_001",
      "type": "feature_request",
      "subject": "Support for Vyper contracts",
      "status": "under_review",
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 2
}
```

### GET /api/v1/feedback/{id}

Retrieve a specific feedback submission.

```bash
curl -X GET https://api.blocksecops.com/api/v1/feedback/fb_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:** Returns the full feedback object.

---

## Roles

### GET /api/v1/roles

List available roles. Requires organization membership.

```bash
curl -X GET https://api.blocksecops.com/api/v1/roles \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "roles": [
    {
      "id": "role_owner",
      "name": "Owner",
      "description": "Full access to all organization resources",
      "permissions": ["*"],
      "is_system": true
    },
    {
      "id": "role_admin",
      "name": "Admin",
      "description": "Manage members, scans, and settings",
      "permissions": ["members.manage", "scans.manage", "settings.manage"],
      "is_system": true
    },
    {
      "id": "role_member",
      "name": "Member",
      "description": "Create and view scans",
      "permissions": ["scans.create", "scans.read", "contracts.read"],
      "is_system": true
    }
  ]
}
```

---

## Saved Searches

Persist and execute saved search queries.

### GET /api/v1/saved-searches

List saved searches.

```bash
curl -X GET https://api.blocksecops.com/api/v1/saved-searches \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "saved_searches": [
    {
      "id": "ss_001",
      "name": "Critical reentrancy findings",
      "entity_type": "vulnerability",
      "query": {
        "severity": "critical",
        "type": "reentrancy",
        "status": "open"
      },
      "result_count": 5,
      "last_executed_at": "2026-02-14T10:00:00Z",
      "created_at": "2026-02-01T09:00:00Z"
    }
  ],
  "total": 3
}
```

### POST /api/v1/saved-searches

Create a saved search.

```bash
curl -X POST https://api.blocksecops.com/api/v1/saved-searches \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Critical reentrancy findings",
    "entity_type": "vulnerability",
    "query": {
      "severity": "critical",
      "type": "reentrancy",
      "status": "open"
    }
  }'
```

**Response 201:** Returns the created saved search object.

### GET /api/v1/saved-searches/{id}

Retrieve a saved search.

```bash
curl -X GET https://api.blocksecops.com/api/v1/saved-searches/ss_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:** Returns the saved search object.

### PUT /api/v1/saved-searches/{id}

Update a saved search.

```bash
curl -X PUT https://api.blocksecops.com/api/v1/saved-searches/ss_001 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Critical reentrancy - active",
    "query": {
      "severity": "critical",
      "type": "reentrancy",
      "status": "open"
    }
  }'
```

**Response 200:** Returns the updated saved search object.

### DELETE /api/v1/saved-searches/{id}

Delete a saved search.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/saved-searches/ss_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

### POST /api/v1/saved-searches/{id}/execute

Execute a saved search and return results.

```bash
curl -X POST https://api.blocksecops.com/api/v1/saved-searches/ss_001/execute \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "search_id": "ss_001",
  "results": [
    {
      "id": "vuln_abc123",
      "type": "reentrancy",
      "severity": "critical",
      "contract": "0xdead...beef",
      "location": "withdraw():L45"
    }
  ],
  "total": 5,
  "executed_at": "2026-02-14T12:00:00Z"
}
```

---

## Statistics

Dashboard and analytics statistics.

### GET /api/v1/statistics/dashboard

Retrieve dashboard summary statistics.

```bash
curl -X GET https://api.blocksecops.com/api/v1/statistics/dashboard \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "total_contracts": 25,
  "total_scans": 142,
  "total_vulnerabilities": 380,
  "critical_vulnerabilities": 12,
  "scans_this_month": 28,
  "avg_scan_duration_seconds": 145,
  "top_vulnerability_types": [
    { "type": "reentrancy", "count": 45 },
    { "type": "unchecked_return", "count": 38 },
    { "type": "integer_overflow", "count": 32 }
  ]
}
```

### GET /api/v1/statistics/risk

Retrieve risk distribution statistics.

```bash
curl -X GET https://api.blocksecops.com/api/v1/statistics/risk \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "risk_distribution": {
    "critical": 12,
    "high": 45,
    "medium": 120,
    "low": 85,
    "informational": 118
  },
  "risk_trend": [
    { "date": "2026-02-14", "critical": 12, "high": 45 },
    { "date": "2026-02-07", "critical": 14, "high": 48 },
    { "date": "2026-01-31", "critical": 15, "high": 50 }
  ],
  "average_risk_score": 42.5
}
```

### GET /api/v1/statistics/scan-history

Retrieve historical scan statistics.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/statistics/scan-history?period=30d" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "period": "30d",
  "scans_by_day": [
    { "date": "2026-02-14", "total": 8, "completed": 7, "failed": 1 },
    { "date": "2026-02-13", "total": 12, "completed": 12, "failed": 0 }
  ],
  "total_scans": 142,
  "success_rate": 0.95,
  "average_duration_seconds": 145
}
```

---

## Support Tickets

### POST /api/v1/support-tickets

Create a support ticket.

```bash
curl -X POST https://api.blocksecops.com/api/v1/support-tickets \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "Scan stuck in processing state",
    "description": "Scan scan_abc123 has been in processing for over 2 hours.",
    "priority": "high",
    "category": "scan_issue"
  }'
```

**Response 201:**

```json
{
  "id": "ticket_001",
  "subject": "Scan stuck in processing state",
  "status": "open",
  "priority": "high",
  "category": "scan_issue",
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/support-tickets

List support tickets for the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/support-tickets \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "tickets": [
    {
      "id": "ticket_001",
      "subject": "Scan stuck in processing state",
      "status": "in_progress",
      "priority": "high",
      "last_response_at": "2026-02-14T13:00:00Z",
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 2
}
```

### GET /api/v1/support-tickets/{id}

Retrieve a specific support ticket with conversation history.

```bash
curl -X GET https://api.blocksecops.com/api/v1/support-tickets/ticket_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "ticket_001",
  "subject": "Scan stuck in processing state",
  "description": "Scan scan_abc123 has been in processing for over 2 hours.",
  "status": "in_progress",
  "priority": "high",
  "category": "scan_issue",
  "messages": [
    {
      "id": "msg_001",
      "author": "Support Agent",
      "content": "We are investigating the stuck scan. We will force-restart it shortly.",
      "created_at": "2026-02-14T13:00:00Z"
    }
  ],
  "created_at": "2026-02-14T12:00:00Z"
}
```

---

## Upload

### POST /api/v1/upload

Upload a file (contract source code, supporting documentation, etc.).

```bash
curl -X POST https://api.blocksecops.com/api/v1/upload \
  -H "Authorization: Bearer <token>" \
  -F "file=@MyContract.sol" \
  -F "type=contract_source"
```

**Request:**

| Field | Type   | Required | Description                                    |
|-------|--------|----------|------------------------------------------------|
| file  | file   | Yes      | File to upload                                 |
| type  | string | Yes      | File type: contract_source, documentation, report |

**Response 200:**

```json
{
  "id": "file_abc123",
  "filename": "MyContract.sol",
  "type": "contract_source",
  "size_bytes": 4520,
  "mime_type": "text/plain",
  "url": "/api/v1/upload/file_abc123",
  "uploaded_at": "2026-02-14T12:00:00Z"
}
```

---

## Consent

Manage terms of service and data consent.

### GET /api/v1/consent/current

Retrieve the current consent status for the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/consent/current \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "tos_accepted": true,
  "tos_version": "2.1",
  "tos_accepted_at": "2025-06-15T10:30:00Z",
  "ml_data_consent": true,
  "ml_consent_given_at": "2025-06-15T10:30:00Z",
  "latest_tos_version": "2.1",
  "requires_new_acceptance": false
}
```

### POST /api/v1/consent/tos

Accept the terms of service.

```bash
curl -X POST https://api.blocksecops.com/api/v1/consent/tos \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "2.1",
    "ml_data_consent": true
  }'
```

**Response 200:**

```json
{
  "tos_accepted": true,
  "tos_version": "2.1",
  "ml_data_consent": true,
  "accepted_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/consent/versions

List all terms of service versions.

```bash
curl -X GET https://api.blocksecops.com/api/v1/consent/versions \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "versions": [
    {
      "version": "2.1",
      "published_at": "2025-12-01T00:00:00Z",
      "summary": "Updated data retention policy and ML training opt-out",
      "is_current": true
    },
    {
      "version": "2.0",
      "published_at": "2025-06-01T00:00:00Z",
      "summary": "Initial terms of service",
      "is_current": false
    }
  ]
}
```

### POST /api/v1/consent/withdraw-ml

Withdraw consent for ML data usage.

```bash
curl -X POST https://api.blocksecops.com/api/v1/consent/withdraw-ml \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "ml_data_consent": false,
  "withdrawn_at": "2026-02-14T12:00:00Z",
  "message": "ML data consent withdrawn. Your data will no longer be used for model training."
}
```

---

## Auth

Authentication endpoints supporting wallet-based auth and OAuth integrations.

### Wallet Authentication (Ethereum)

#### POST /api/v1/auth/wallet/nonce

Request a nonce for wallet signature verification.

```bash
curl -X POST https://api.blocksecops.com/api/v1/auth/wallet/nonce \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_address": "0x1234...abcd",
    "chain": "ethereum"
  }'
```

**Response 200:**

```json
{
  "nonce": "Sign this message to authenticate with BlockSecOps: abc123def456",
  "expires_at": "2026-02-14T12:05:00Z"
}
```

#### POST /api/v1/auth/wallet/verify

Verify a signed message and authenticate.

```bash
curl -X POST https://api.blocksecops.com/api/v1/auth/wallet/verify \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_address": "0x1234...abcd",
    "signature": "0xabc123...",
    "chain": "ethereum"
  }'
```

**Response 200:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "usr_abc123",
    "wallet_address": "0x1234...abcd",
    "chain": "ethereum"
  }
}
```

### Wallet Authentication (Solana)

#### POST /api/v1/auth/wallet/solana/nonce

Request a nonce for Solana wallet signature verification.

```bash
curl -X POST https://api.blocksecops.com/api/v1/auth/wallet/solana/nonce \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_address": "ABC123...xyz"
  }'
```

**Response 200:**

```json
{
  "nonce": "Sign this message to authenticate with BlockSecOps: xyz789abc123",
  "expires_at": "2026-02-14T12:05:00Z"
}
```

#### POST /api/v1/auth/wallet/solana/verify

Verify a Solana wallet signature and authenticate.

```bash
curl -X POST https://api.blocksecops.com/api/v1/auth/wallet/solana/verify \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_address": "ABC123...xyz",
    "signature": "base58signature..."
  }'
```

**Response 200:** Same schema as Ethereum wallet verify.

### OAuth Callbacks

OAuth callback endpoints for third-party integrations. These are called by the OAuth providers after user authorization.

#### GET /api/v1/auth/callback/github

GitHub OAuth callback.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/auth/callback/github?code=abc123&state=xyz789"
```

**Response:** Redirects to the dashboard with session established.

#### GET /api/v1/auth/callback/gitlab

GitLab OAuth callback.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/auth/callback/gitlab?code=abc123&state=xyz789"
```

**Response:** Redirects to the dashboard with session established.

#### GET /api/v1/auth/callback/bitbucket

Bitbucket OAuth callback.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/auth/callback/bitbucket?code=abc123&state=xyz789"
```

**Response:** Redirects to the dashboard with session established.

#### GET /api/v1/auth/callback/jenkins

Jenkins OAuth callback.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/auth/callback/jenkins?code=abc123&state=xyz789"
```

**Response:** Redirects to the dashboard with session established.

#### GET /api/v1/auth/callback/jira

Jira OAuth callback.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/auth/callback/jira?code=abc123&state=xyz789"
```

**Response:** Redirects to the integration settings page with Jira connected.
