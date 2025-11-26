# API Response Validation Tests

**Priority**: P2 - Medium
**Last Tested**: _Not yet tested_

---

## 1. Upload Response

### Endpoint: `POST /api/v1/upload`

### 1.1 Required Fields
- [ ] `contract_id` - UUID format
- [ ] `filename` - matches uploaded file
- [ ] `status` - "success" or "failed"
- [ ] `message` - descriptive message

### 1.2 Multi-File Fields
- [ ] `is_multi_file` - boolean, true for archives
- [ ] `file_count` - integer, matches extracted files
- [ ] `files` - array of FileInfo objects
- [ ] `main_file_path` - string, path to main file

### 1.3 Framework Fields (Phase 3.2)
- [ ] `framework` - "foundry", "hardhat", or "plain"
- [ ] `framework_config` - object with parsed config (or null)

### 1.4 FileInfo Object
```json
{
  "path": "contracts/Token.sol",
  "size": 1234,
  "lines_of_code": 50
}
```
- [ ] `path` - relative path string
- [ ] `size` - integer bytes
- [ ] `lines_of_code` - integer

### Example Response
```json
{
  "contract_id": "550e8400-e29b-41d4-a716-446655440000",
  "filename": "project.zip",
  "status": "success",
  "message": "Archive uploaded [foundry]: 12 files, 500 total lines of code",
  "is_multi_file": true,
  "file_count": 12,
  "files": [...],
  "main_file_path": "src/Token.sol",
  "framework": "foundry",
  "framework_config": {
    "solc_version": "0.8.20",
    "src_dir": "src",
    "remappings": ["@openzeppelin/=lib/openzeppelin-contracts/"]
  }
}
```

---

## 2. Contract Response

### Endpoint: `GET /api/v1/contracts/{id}`

### 2.1 Required Fields
- [ ] `id` - UUID
- [ ] `name` - string
- [ ] `status` - "uploaded", "scanning", "scanned", "failed"
- [ ] `created_at` - ISO datetime
- [ ] `updated_at` - ISO datetime

### 2.2 Optional Fields
- [ ] `address` - contract address (if set)
- [ ] `network` - blockchain network
- [ ] `source_code` - source for single file
- [ ] `lines_of_code` - integer

### 2.3 Multi-File Fields
- [ ] `is_multi_file` - boolean
- [ ] `file_count` - integer
- [ ] `total_lines_of_code` - integer
- [ ] `main_file_path` - string

### 2.4 Language Fields (Phase 3.1)
- [ ] `language` - "solidity", "vyper", "rust", etc.
- [ ] `compiler_version` - string
- [ ] `language_metadata` - object

### 2.5 Framework Fields (Phase 3.2)
- [ ] `framework` - "foundry", "hardhat", "plain"
- [ ] `framework_config` - JSONB object

---

## 3. Scan Response

### Endpoint: `POST /api/v1/scans`

### 3.1 Trigger Response
- [ ] `scan_id` - UUID
- [ ] `contract_id` - UUID
- [ ] `status` - "queued"
- [ ] `scanners` - array of scanner names
- [ ] `created_at` - ISO datetime

### 3.2 Status Response
### Endpoint: `GET /api/v1/scans/{id}`
- [ ] `id` - UUID
- [ ] `status` - "queued", "running", "completed", "failed"
- [ ] `progress` - integer 0-100 (if available)
- [ ] `started_at` - ISO datetime (if started)
- [ ] `completed_at` - ISO datetime (if completed)

---

## 4. Scan Results Response

### Endpoint: `GET /api/v1/scans/{id}/results`

### 4.1 Results Structure
```json
{
  "scan_id": "uuid",
  "contract_id": "uuid",
  "findings": [...],
  "summary": {
    "total": 10,
    "critical": 1,
    "high": 2,
    "medium": 3,
    "low": 4
  }
}
```

### 4.2 Finding Object
- [ ] `id` - unique finding ID
- [ ] `type` - vulnerability type
- [ ] `severity` - "critical", "high", "medium", "low", "info"
- [ ] `title` - short description
- [ ] `description` - detailed description
- [ ] `file_path` - where found
- [ ] `line_start` - starting line number
- [ ] `line_end` - ending line number
- [ ] `scanner` - which scanner found it
- [ ] `confidence` - confidence level

---

## 5. Project Response

### Endpoint: `GET /api/v1/projects/{id}`

- [ ] `id` - UUID
- [ ] `name` - string
- [ ] `description` - string (nullable)
- [ ] `user_id` - UUID
- [ ] `contract_count` - integer
- [ ] `contracts` - array (optional)
- [ ] `created_at` - ISO datetime
- [ ] `updated_at` - ISO datetime

---

## 6. Error Response Format

### Standard Error Response
```json
{
  "detail": "Error message"
}
```
or
```json
{
  "detail": {
    "error": "error_code",
    "message": "Human readable message",
    "field": "additional_info"
  }
}
```

### 6.1 Quota Error Response (402)
- [ ] `error` = "quota_exceeded" or "too_many_files"
- [ ] `message` - human readable
- [ ] `tier` - current tier
- [ ] `upgrade_url` - path to upgrade
- [ ] `upgrade_message` - upgrade suggestion

### 6.2 Size Error Response (413)
- [ ] `error` = "file_too_large"
- [ ] `file_size_mb` - actual size
- [ ] `max_size_mb` - tier limit
- [ ] `tier` - current tier

---

## 7. HTTP Status Codes

- [ ] 200 - Success (GET, PUT)
- [ ] 201 - Created (POST)
- [ ] 400 - Bad Request (validation error)
- [ ] 401 - Unauthorized (not logged in)
- [ ] 402 - Payment Required (quota exceeded)
- [ ] 403 - Forbidden (not your resource)
- [ ] 404 - Not Found
- [ ] 413 - Payload Too Large (file size)
- [ ] 500 - Internal Server Error

---

## Test Notes

_Record API validation test results here:_

```
[Date] | [Endpoint] | [Field] | [Result] | [Notes]
```
