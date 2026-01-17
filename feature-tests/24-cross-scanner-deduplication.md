# Cross-Scanner Deduplication Testing

**Feature**: Intelligence Layer - Cross-Scanner Deduplication
**Version**: v0.8.0 (pattern_code fix in v0.10.6)
**Last Tested**: 2026-01-16
**Status**: PASS

> **Fix (January 16, 2026)**: API v0.10.6 adds fallback to canonical finding's pattern_code when group's pattern_code is null.

---

## Overview

Tests for the deduplication engine that automatically identifies and groups duplicate vulnerability findings across multiple security scanners.

---

## Test Environment

| Component | Value |
|-----------|-------|
| Platform | Minikube (local) |
| API Service | v0.1.13 |
| Test User | jasonbrailowbizop@mail.com |
| Access URL | http://127.0.0.1:3000 |

---

## API Endpoints Tested

### 1. Deduplication Stats

**Endpoint**: `GET /api/v1/deduplication/stats`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/stats" | jq '.'
```

**Expected Response**:
```json
{
  "total_groups": 137,
  "total_findings_deduplicated": 421,
  "average_group_size": 3.07,
  "confidence_breakdown": {
    "exact": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "location": 137,
    "fuzzy": 0,
    "semantic": 0
  }
}
```

**Status**: [x] PASS (2025-12-25)

---

### 2. List Deduplication Groups

**Endpoint**: `GET /api/v1/deduplication/groups`

**Parameters**:
| Param | Type | Description |
|-------|------|-------------|
| limit | int | Results per page (default: 50) |
| offset | int | Pagination offset |
| pattern_code | string | Filter by BVD pattern code |
| severity | string | Filter by severity |
| min_scanner_count | int | Minimum scanners (default: 2) |

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups?limit=5" | jq '.'
```

**Expected Response**:
```json
{
  "groups": [
    {
      "id": "uuid",
      "project_id": "uuid",
      "canonical_finding_id": "uuid",
      "pattern_code": null,
      "confidence_level": "location",
      "finding_count": 2,
      "scanner_count": 2,
      "first_seen": "2025-12-24T01:25:42.680455Z",
      "last_seen": "2025-12-24T18:04:46.440225Z",
      "canonical_finding_title": "Constable States",
      "canonical_finding_severity": "low"
    }
  ],
  "total": 137,
  "limit": 5,
  "offset": 0
}
```

**Status**: [x] PASS (2025-12-25)

---

### 3. Get Group Details

**Endpoint**: `GET /api/v1/deduplication/groups/{group_id}`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
GROUP_ID="f992caa5-9f03-490c-81a6-abf1b1d5db2d"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups/${GROUP_ID}" | jq '.'
```

**Expected Response**:
```json
{
  "id": "f992caa5-9f03-490c-81a6-abf1b1d5db2d",
  "project_id": "27ef7de0-d303-4365-a16a-984a09ed9d07",
  "canonical_finding_id": "be9fd373-181d-4ec9-8683-8214519adff5",
  "pattern_code": null,
  "confidence_level": "location",
  "matched_fingerprints": ["fingerprint_code"],
  "finding_count": 2,
  "scanner_count": 2,
  "first_seen": "2025-12-24T01:25:42.680455Z",
  "last_seen": "2025-12-24T18:04:46.440225Z",
  "findings": [
    {
      "id": "be9fd373-181d-4ec9-8683-8214519adff5",
      "scanner_id": "slither",
      "pattern_code": null,
      "severity": "low",
      "title": "Constable States",
      "file_path": null,
      "line_number": 18,
      "match_confidence": "location",
      "is_canonical": true,
      "added_at": "2025-12-24T01:25:45.271893Z"
    },
    {
      "id": "2eb800a1-6f57-4cd4-8eee-b9242265877a",
      "scanner_id": "aderyn",
      "pattern_code": null,
      "severity": "medium",
      "title": "State Variable Could Be Constant",
      "file_path": null,
      "line_number": 18,
      "match_confidence": "location",
      "is_canonical": false,
      "added_at": "2025-12-24T01:25:42.680455Z"
    }
  ]
}
```

**Verification Points**:
- [x] Group contains findings from multiple scanners (slither, aderyn)
- [x] One finding marked as `is_canonical: true`
- [x] Findings matched by location (same line number: 18)
- [x] Scanners report different titles for same issue

**Status**: [x] PASS (2025-12-25)

---

## UI Testing

### Deduplication List Page

**URL**: `http://127.0.0.1:3000/deduplication`

**Test Steps**:
1. [x] Navigate to `/deduplication`
2. [x] Verify filter controls are visible (pattern code, severity, min scanners)
3. [x] Verify stats summary shows (total groups, findings, avg scanners)
4. [x] Verify groups list displays with clickable items
5. [x] Click a group to view details
6. [x] Verify detail page shows all grouped findings
7. [x] Verify canonical finding is highlighted

**Status**: [x] PASS (2025-12-26) - Dashboard v0.15.1

---

### Frontend Type Alignment Fix (v0.15.1)

**Issue**: Frontend TypeScript interfaces did not match API response structure, causing runtime errors on deduplication pages.

**Errors Fixed**:
- `DeduplicationGroupCard.tsx:122` - `fingerprint_code.substring()` undefined
- `DeduplicationDetail.tsx:147` - `group.fingerprint_code.slice()` undefined
- `DeduplicationDetail.tsx:113` - Missing import for `DeduplicationGroupCard`

**Solution**: Updated frontend types to match actual API response:
```typescript
// DeduplicationGroup - list view
interface DeduplicationGroup {
  id: string;
  canonical_finding_id: string;
  canonical_finding_title?: string;  // Added
  canonical_finding_severity?: string; // Added
  pattern_code?: string;
  confidence_level: ConfidenceLevel;
  finding_count: number;
  scanner_count: number;
  first_seen: string;
  last_seen: string;
}

// DeduplicationGroupDetail - detail view
interface DeduplicationGroupDetail extends DeduplicationGroup {
  matched_fingerprints: string[];  // Added
  findings: DuplicateFinding[];
}
```

**Files Modified**:
- `src/lib/api/deduplication.ts` - Type definitions
- `src/components/intelligence/DeduplicationGroupCard.tsx` - Display logic
- `src/pages/DeduplicationDetail.tsx` - Page display and imports

---

## Test Data Summary

| Metric | Value |
|--------|-------|
| Total Deduplication Groups | 137 |
| Total Findings Deduplicated | 421 |
| Average Group Size | 3.07 |
| Primary Match Type | Location-based |

---

## Known Issues

### 1. DNS Resolution After Cluster Restart

**Issue**: After laptop crash/minikube restart, external DNS resolution fails from pods.

**Symptom**: Token validation fails with "Failed to resolve 'huzjlpypdlelqnbjvxad.supabase.co'"

**Root Cause**: CoreDNS forwards to Docker Desktop DNS (192.168.65.254) which times out after cluster restart.

**Fix Applied**:
```bash
# Update CoreDNS to use Google DNS directly
kubectl get configmap coredns -n kube-system -o json | \
  jq '.data.Corefile |= sub("forward . /etc/resolv.conf"; "forward . 8.8.8.8 8.8.4.4")' | \
  kubectl apply -f -

# Restart CoreDNS
kubectl delete pod -n kube-system -l k8s-app=kube-dns

# Add control-plane hostname
minikube ssh "echo '192.168.49.2 control-plane.minikube.internal' | sudo tee -a /etc/hosts"
```

**Status**: Fixed

---

## Test Script

Save as `/tmp/test_dedup.sh`:

```bash
#!/bin/bash
# Cross-Scanner Deduplication Test Script

TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh 2>/dev/null)

echo "=== Deduplication Stats ==="
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/stats" | jq '.'

echo ""
echo "=== Deduplication Groups (first 3) ==="
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups?limit=3" | jq '.'

echo ""
echo "=== Group Detail (first group) ==="
GROUP_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups?limit=1" | jq -r '.groups[0].id')
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups/${GROUP_ID}" | jq '.'
```

---

## References

- Technical Documentation: `/Users/pwner/Git/ABS/blocksecops-docs/features/deduplication-engine.md`
- API Implementation: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/deduplication.py`
- Dashboard Page: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/pages/DeduplicationList.tsx`

---

**Last Updated**: 2025-12-26
**Tested By**: Claude Code (Automated)
**Dashboard Version**: v0.15.1
