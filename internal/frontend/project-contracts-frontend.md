# Project Contract Management Frontend

**Repository:** blocksecops-dashboard
**Version:** 0.5.11+
**Port:** 3000
**Status:** Production Ready
**Last Updated:** November 29, 2025

---

## Overview

The project contract management frontend allows users to associate existing contracts with projects. This enables organizing contracts into logical groups for security scanning and vulnerability tracking.

---

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Backend API                             │
│  POST /projects/{id}/contracts                              │
│  DELETE /projects/{id}/contracts/{contract_id}              │
│  GET /contracts (list available contracts)                  │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Projects API Client                      │
│  Location: src/lib/api/projects.ts                          │
│  Functions: addContractToProject, removeContractFromProject │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                 ContractSelectorModal                       │
│  Location: src/components/projects/ContractSelectorModal.tsx│
│  - Fetches available contracts                              │
│  - Filters by search query                                  │
│  - Multi-select with checkboxes                             │
│  - Calls API to associate contracts                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                   ProjectDetail Page                        │
│  Location: src/pages/ProjectDetail.tsx                      │
│  - "Add Existing" button                                    │
│  - "Upload New" button                                      │
│  - Contract list display                                    │
└─────────────────────────────────────────────────────────────┘
```

### Component Hierarchy

```
ProjectDetail
├── ContractSelectorModal (Add Existing)
├── ContractUploadModal (Upload New)
└── Contract List (displays associated contracts)
```

---

## Components

### 1. ContractSelectorModal (`src/components/projects/ContractSelectorModal.tsx`)

Modal for selecting existing contracts to add to a project.

**Props:**

```typescript
interface ContractSelectorModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  projectId: string;
  existingContractIds?: string[];  // Contracts already in project (filtered out)
}
```

**Features:**
- Lists all user contracts via `GET /contracts`
- Filters out contracts already associated with the project
- Search by name, network, or address
- Multi-select with checkboxes
- Shows contract metadata (network, language, lines of code, date)
- Bulk add selected contracts

**State:**
- `selectedContracts: Set<string>` - Selected contract IDs
- `searchQuery: string` - Filter text
- `isAdding: boolean` - Submission loading state
- `error: string | null` - Error message

**Usage:**

```typescript
<ContractSelectorModal
  isOpen={showContractSelector}
  onClose={() => setShowContractSelector(false)}
  onSuccess={() => {
    setShowContractSelector(false);
    refetch();
  }}
  projectId={projectId}
/>
```

---

### 2. ProjectDetail Page (`src/pages/ProjectDetail.tsx`)

Project detail view with contract management buttons.

**Contract Section UI:**

| Location | Buttons |
|----------|---------|
| Header (when contracts exist) | "Add Existing" (gray) + "Upload New" (blue) |
| Empty State (no contracts) | "Add Existing Contract" + "Upload New Contract" |

**State Variables:**
- `showContractModal: boolean` - ContractUploadModal visibility
- `showContractSelector: boolean` - ContractSelectorModal visibility

---

## API Integration

### Projects API (`src/lib/api/projects.ts`)

**Add Contract to Project:**

```typescript
export async function addContractToProject(
  projectId: string,
  contractId: string
): Promise<void> {
  await apiClient.post(`/projects/${projectId}/contracts`, {
    contract_id: contractId
  });
}
```

**Remove Contract from Project:**

```typescript
export async function removeContractFromProject(
  projectId: string,
  contractId: string
): Promise<void> {
  await apiClient.delete(`/projects/${projectId}/contracts/${contractId}`);
}
```

### Backend Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/projects/{id}/contracts` | Associate contract with project |
| DELETE | `/projects/{id}/contracts/{contract_id}` | Remove contract from project |

**Request Body (POST):**

```json
{
  "contract_id": "uuid-string"
}
```

**Response (POST):**

```json
{
  "message": "Contract added to project successfully"
}
```

---

## UI States

### Contract Selector Modal

| State | Visual |
|-------|--------|
| Loading | Spinner centered in modal |
| Empty (no contracts) | "No contracts available to add" message |
| Search no results | "No contracts match your search" message |
| Contracts available | Scrollable list with checkboxes |
| Adding | "Adding..." button with spinner |
| Error | Red error message above footer |

### Button States

| Selection | Button Text | State |
|-----------|-------------|-------|
| 0 selected | "Add Contracts" | Disabled (gray) |
| 1 selected | "Add 1 Contract" | Enabled (blue) |
| N selected | "Add N Contracts" | Enabled (blue) |

---

## Contract Card Display

Each contract in the selector shows:

```
┌─────────────────────────────────────────────────────────┐
│ [✓] ContractName  [ethereum]  [solidity]                │
│     0x1234...abcd  • 2 days ago  • 150 lines            │
└─────────────────────────────────────────────────────────┘
```

| Element | Description |
|---------|-------------|
| Checkbox | Selection state (checked = selected) |
| Name | Contract name (bold) |
| Network badge | Gray pill showing network (ethereum, polygon, etc.) |
| Language badge | Purple pill showing language (solidity, vyper, etc.) |
| Address | Truncated contract address (if available) |
| Date | Time since creation |
| Lines | Lines of code count |

---

## Error Handling

### Common Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| "Contract already associated with project" | Duplicate add attempt | Contract filtered from list |
| "Project not found" | Invalid project ID | Redirect to projects list |
| "Contract not found" | Invalid contract ID | Refresh contract list |
| Network error | API unreachable | Show error toast, retry |

---

## Query Invalidation

After successful contract association:

```typescript
await queryClient.invalidateQueries({ queryKey: ['project', projectId] });
await queryClient.invalidateQueries({ queryKey: ['projects'] });
```

This ensures:
- Project detail page refreshes with new contract count
- Projects list updates with new contract counts

---

## Styling

### Modal Styles

- **Backdrop:** `bg-black bg-opacity-50`
- **Modal:** `max-w-2xl bg-white rounded-xl shadow-xl`
- **Header:** `px-6 py-4 border-b border-gray-200`
- **Footer:** `bg-gray-50 rounded-b-xl`

### Contract Card Styles

| State | Border | Background |
|-------|--------|------------|
| Default | `border-gray-200` | White |
| Hover | `border-gray-300` | `bg-gray-50` |
| Selected | `border-blue-500` | `bg-blue-50` |

### Checkbox Styles

| State | Style |
|-------|-------|
| Unchecked | `border-gray-300` |
| Checked | `bg-blue-600 border-blue-600` with white checkmark |

---

## Related Documentation

- [Dashboard Development Standards](/Users/pwner/Git/ABS/docs/standards/dashboard-development.md)
- [Notification Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/notification-frontend.md)
- [Quota Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/quota-frontend.md)
- [Authentication Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/authentication-frontend.md)

---

## Version History

### v0.5.11 (November 29, 2025)
**Type:** MINOR (New Feature)
**Changes:**
- Created ContractSelectorModal component
- Added "Add Existing" button to ProjectDetail header
- Added "Add Existing Contract" to empty state
- Integrated with project-contract association API
- Multi-select with search filtering
- Query invalidation for data refresh

### v0.5.10 (November 29, 2025)
**Type:** PATCH (Bug Fix)
**Changes:**
- Fixed non-functional "Add Contract" button on ProjectDetail page
- Added ContractUploadModal integration
- Added state management for modal visibility
- Added data refresh via refetch() after upload
