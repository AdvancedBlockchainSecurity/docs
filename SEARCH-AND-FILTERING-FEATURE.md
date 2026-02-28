# Search & Filtering Feature - Complete Implementation

**Date**: October 18, 2025
**Status**: ✅ COMPLETE
**Phase**: Phase 3 - Week 6 - Day 6

---

## Overview

Advanced search and filtering system for Apogee platform, allowing users to search across contracts, scans, and vulnerabilities with comprehensive filters, saved search queries, and export functionality.

---

## Features Implemented

### 1. Advanced Search API (Backend)

**File**: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/search.py` (767 lines)

**Endpoints**:
```
POST   /api/v1/search                  - Advanced search with multi-filter support
POST   /api/v1/search/export           - Export results to CSV/JSON
GET    /api/v1/search/saved            - List saved searches
POST   /api/v1/search/saved            - Create saved search
POST   /api/v1/search/saved/{id}/execute - Execute saved search
DELETE /api/v1/search/saved/{id}      - Delete saved search
```

**Filter Capabilities**:
- Text query (searches titles, descriptions, code snippets)
- Project IDs filter
- Contract IDs filter
- Languages filter (solidity, vyper, rust, move, cairo)
- Networks filter (ethereum, polygon, bsc, etc.)
- Scanner IDs filter (slither, mythril, aderyn, etc.)
- Categories filter (reentrancy, access_control, arithmetic, etc.)
- Minimum confidence threshold (0.0-1.0)
- Severities filter (critical, high, medium, low)
- Vulnerability statuses filter (open, acknowledged, fixed, false_positive)
- Scan statuses filter (queued, running, completed, failed)
- Date range filters (date_from, date_to)
- Vulnerability count filters (min, max)
- Critical vulnerability presence flag
- Source code availability flag
- Pagination (skip, limit)
- Sorting (sort_by, sort_order)

**Performance**:
- Query time tracking (returns execution time in milliseconds)
- Optimized database queries with proper indexing
- Limited results for export (10,000 max)
- Pagination support for large result sets

**Export Formats**:
- **CSV**: All vulnerability fields including Migration 004 scanner metadata
- **JSON**: Structured export with full vulnerability details

### 2. Saved Searches API (Backend)

**File**: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/saved_searches.py` (348 lines)

**Endpoints**:
```
GET    /api/v1/saved-searches              - List all saved searches
POST   /api/v1/saved-searches              - Create new saved search
GET    /api/v1/saved-searches/{id}         - Get specific saved search
PUT    /api/v1/saved-searches/{id}         - Update saved search
DELETE /api/v1/saved-searches/{id}         - Delete saved search
POST   /api/v1/saved-searches/{id}/execute - Execute and track usage
```

**Features**:
- User-scoped saved searches
- Execution count tracking
- Last executed timestamp
- Name uniqueness validation
- Optional descriptions
- Full search parameter persistence

### 3. Search Schemas (Backend)

**File**: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/schemas/search.py` (230 lines)

**Pydantic Models**:
```python
- SearchRequest           # All search filter parameters
- SearchResponse          # Results grouped by type
- ContractSearchResult    # Contract with aggregated data
- ScanSearchResult        # Scan with related data
- VulnerabilitySearchResult # Vulnerability with context
- SavedSearch             # Saved query with metadata
- SavedSearchCreate       # Create saved search request
- SavedSearchListResponse # Paginated saved searches
```

**Field Validation**:
- Query string max length: 500 characters
- Confidence range: 0.0-1.0
- Pagination limits: skip >= 0, limit 1-1000
- Sort order pattern: ^(asc|desc)$
- Comprehensive field descriptions and examples

### 4. Search Page (Frontend)

**File**: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/pages/Search.tsx` (563 lines)

**UI Components**:
- Search bar with debouncing (500ms delay)
- Filter chips for quick selection:
  - Severity filters (critical, high, medium, low)
  - Scanner filters (dynamic from API)
  - Category filters (dynamic from API)
  - Confidence slider (0-100%)
- Active filter count display
- Reset all filters button
- Results summary with query time
- Save search dialog with name and description
- Export buttons (CSV and JSON)

**State Management**:
- URL params sync for shareable links
- React Query for data fetching
- Debounced search input
- Filter state management
- Loading and error states

**Results Display**:
- **Contracts Section**:
  - Contract name, language, network
  - Scan count, vulnerability count
  - Severity breakdown badges
  - Health score percentage
  - Hover interactions

- **Vulnerabilities Section**:
  - Severity badge with color coding
  - Category tag
  - Scanner badge
  - Confidence indicator
  - Title and description
  - Contract name and language
  - Line number (if available)
  - Detection date
  - Expandable details

- **Empty State**:
  - Search icon
  - Helpful message
  - Suggestions for adjusting filters

### 5. Saved Searches Panel (Frontend)

**File**: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/components/search/SavedSearchesPanel.tsx` (235 lines)

**Features**:
- Sidebar panel on search page
- List of saved searches with:
  - Name and description
  - Filter summary (query, severities, scanners, categories, confidence)
  - Creation date
  - Last executed date
  - Execution count badge
- Actions per saved search:
  - **Run** button - executes search and navigates with params
  - **Delete** button with confirmation (two-step delete)
- Loading states
- Error handling
- Empty state with helpful message
- Pagination support (50 per page)

### 6. Search API Client (Frontend)

**File**: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/lib/api/search.ts` (110 lines)

**Methods**:
```typescript
advancedSearch(filters: SearchFilters): Promise<SearchResponse>
exportSearchResults(filters: SearchFilters, format: 'csv'|'json'): Promise<Blob>
getAvailableScanners(): Promise<string[]>
getAvailableCategories(): Promise<string[]>
```

**Features**:
- TypeScript type definitions for all requests/responses
- Axios-based HTTP client
- Blob handling for file exports
- Error handling
- Response type validation

### 7. Saved Searches API Client (Frontend)

**File**: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/lib/api/saved-searches.ts`

**Methods**:
```typescript
listSavedSearches(skip: number, limit: number): Promise<SavedSearchListResponse>
createSavedSearch(data: SavedSearchCreate): Promise<SavedSearch>
getSavedSearch(id: string): Promise<SavedSearch>
updateSavedSearch(id: string, data: SavedSearchCreate): Promise<SavedSearch>
deleteSavedSearch(id: string): Promise<void>
executeSavedSearch(id: string): Promise<SavedSearch>
```

---

## Navigation Integration

**File**: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/App.tsx`

- Search page added to main navigation (line 27)
- Route configured at `/search` (line 145)
- Protected route requiring authentication
- Search icon in navigation bar

---

## Database Schema

**Table**: `saved_searches` (from Migration 004)

```sql
CREATE TABLE saved_searches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    search_params JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_executed_at TIMESTAMP,
    execution_count INTEGER NOT NULL DEFAULT 0,
    UNIQUE(user_id, name)
);

CREATE INDEX idx_saved_searches_user_id ON saved_searches(user_id);
CREATE INDEX idx_saved_searches_created_at ON saved_searches(created_at DESC);
```

---

## User Workflows

### Workflow 1: Basic Search
1. User navigates to Search page (`/search`)
2. User enters search query in text input
3. Results appear after 500ms debounce delay
4. User can see contracts and vulnerabilities matching query
5. Query time displayed in results header

### Workflow 2: Filtered Search
1. User clicks severity filter chips (e.g., "Critical", "High")
2. User selects scanner filters
3. User adjusts confidence slider
4. Filters combine with AND logic
5. Results update in real-time
6. URL params update for shareable link
7. Active filter count shown in badge

### Workflow 3: Save Search
1. User configures search filters
2. User clicks "Save Search" button
3. Modal appears with name and description fields
4. User enters name (required) and description (optional)
5. User clicks "Save" button
6. Search saved to database
7. Appears in Saved Searches panel

### Workflow 4: Execute Saved Search
1. User sees saved searches in sidebar panel
2. User clicks "Run" button on saved search
3. Backend updates `last_executed_at` and increments `execution_count`
4. Frontend navigates to `/search` with query params
5. Filters applied automatically
6. Results display immediately

### Workflow 5: Export Results
1. User performs search with desired filters
2. User clicks "Export CSV" or "Export JSON" button
3. Frontend sends search filters to export endpoint
4. Backend generates file (limited to 10,000 results)
5. File downloads automatically with timestamp in filename
6. Includes all vulnerability details and scanner metadata

### Workflow 6: Delete Saved Search
1. User clicks delete icon on saved search
2. Confirmation buttons appear (Confirm/Cancel)
3. User clicks "Confirm"
4. Backend deletes saved search
5. Panel refreshes automatically

---

## Technical Implementation Details

### Backend Query Optimization

**Search Query Flow**:
1. Build base contract query with user filter
2. Apply project, language, network, source code filters
3. Execute contract query to get matching contract IDs
4. Build scan query filtered by matching contract IDs
5. Build vulnerability query filtered by matching contract IDs
6. Apply text search to vulnerability titles/descriptions
7. Execute count queries for pagination totals
8. Execute paginated queries for results
9. Aggregate scan counts and vulnerability counts per contract
10. Calculate health scores based on severity distribution
11. Return combined results with query time

**Performance Optimizations**:
- Subquery-based filtering to minimize data transfer
- Batch vulnerability count aggregation using SQL `func.count()`
- Limited result sets (20 scans, 50 vulnerabilities max per page)
- Database indexes on frequently queried fields
- Eager loading with `joinedload()` for related entities

### Frontend State Management

**URL Params Sync**:
```typescript
useEffect(() => {
  const params = new URLSearchParams();
  if (filters.query) params.set('q', filters.query);
  if (filters.severities?.length > 0) params.set('severities', filters.severities.join(','));
  // ... additional param setting
  setSearchParams(params);
}, [filters, setSearchParams]);
```

**Debounced Search**:
```typescript
useEffect(() => {
  const timer = setTimeout(() => {
    setDebouncedQuery(searchQuery);
    setFilters(prev => ({ ...prev, query: searchQuery }));
  }, 500);
  return () => clearTimeout(timer);
}, [searchQuery]);
```

**React Query Integration**:
```typescript
const { data: results, isLoading } = useQuery({
  queryKey: ['search', filters],
  queryFn: () => advancedSearch(filters),
  enabled: true, // Always search, even with empty filters
});
```

---

## Testing

### Manual Testing Checklist

**Search Functionality**:
- [ ] Text search returns matching vulnerabilities
- [ ] Text search works across titles and descriptions
- [ ] Empty search returns all results
- [ ] Debounce prevents excessive API calls

**Filters**:
- [ ] Severity filters work (critical, high, medium, low)
- [ ] Scanner filters work (slither, mythril, etc.)
- [ ] Category filters work (reentrancy, etc.)
- [ ] Confidence slider filters correctly
- [ ] Multiple filters combine with AND logic
- [ ] Reset all filters button clears everything
- [ ] Active filter count is accurate

**Saved Searches**:
- [ ] Save search creates entry in database
- [ ] Name validation prevents duplicates
- [ ] Execute saved search applies filters
- [ ] Execution count increments
- [ ] Last executed timestamp updates
- [ ] Delete saved search removes entry

**Export**:
- [ ] CSV export downloads with correct format
- [ ] JSON export downloads with correct structure
- [ ] Export includes all vulnerability fields
- [ ] Export limited to 10,000 results
- [ ] Filename includes timestamp

**UI/UX**:
- [ ] Loading states display during search
- [ ] Empty states show helpful messages
- [ ] Error states display when API fails
- [ ] Results update smoothly
- [ ] Pagination works correctly
- [ ] Query time displays accurately

### API Endpoint Testing

```bash
# Test search endpoint
curl -X POST http://127.0.0.1:8000/api/v1/search \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "reentrancy",
    "severities": ["critical", "high"],
    "limit": 50,
    "skip": 0
  }'

# Test export endpoint
curl -X POST "http://127.0.0.1:8000/api/v1/search/export?format=csv" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "reentrancy",
    "severities": ["critical"]
  }' \
  --output vulnerabilities.csv

# Test saved searches list
curl -X GET "http://127.0.0.1:8000/api/v1/search/saved?skip=0&limit=50" \
  -H "Authorization: Bearer $TOKEN"

# Test create saved search
curl -X POST http://127.0.0.1:8000/api/v1/search/saved \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Critical Reentrancy Issues",
    "description": "All critical reentrancy vulnerabilities",
    "search_params": {
      "query": "reentrancy",
      "severities": ["critical"],
      "categories": ["reentrancy"]
    }
  }'

# Test execute saved search
curl -X POST http://127.0.0.1:8000/api/v1/search/saved/{search_id}/execute \
  -H "Authorization: Bearer $TOKEN"

# Test delete saved search
curl -X DELETE http://127.0.0.1:8000/api/v1/search/saved/{search_id} \
  -H "Authorization: Bearer $TOKEN"
```

---

## Files Created/Modified

### Backend
- ✅ `/blocksecops-api-service/src/presentation/api/v1/endpoints/search.py` (767 lines)
- ✅ `/blocksecops-api-service/src/presentation/api/v1/endpoints/saved_searches.py` (348 lines)
- ✅ `/blocksecops-api-service/src/presentation/schemas/search.py` (230 lines)

### Frontend
- ✅ `/blocksecops-dashboard/src/pages/Search.tsx` (563 lines)
- ✅ `/blocksecops-dashboard/src/components/search/SavedSearchesPanel.tsx` (235 lines)
- ✅ `/blocksecops-dashboard/src/lib/api/search.ts` (110 lines)
- ✅ `/blocksecops-dashboard/src/lib/api/saved-searches.ts` (existing)
- ✅ `/blocksecops-dashboard/src/App.tsx` (navigation integration)

### Documentation
- ✅ `/docs/SEARCH-AND-FILTERING-FEATURE.md` (this file)

**Total Lines**: 2,253 lines of code

---

## Success Metrics

**Implementation Completeness**: 100%
- [x] Backend search endpoint
- [x] Backend export endpoint
- [x] Backend saved searches CRUD
- [x] Frontend search page
- [x] Frontend saved searches panel
- [x] Frontend API clients
- [x] Navigation integration
- [x] URL params sync
- [x] Loading states
- [x] Error handling
- [x] Empty states

**Feature Completeness**: 100%
- [x] Text search
- [x] Multi-filter support (14 filter types)
- [x] Real-time filtering
- [x] Debounced input
- [x] Saved searches
- [x] Execute saved searches
- [x] Export to CSV
- [x] Export to JSON
- [x] Query time tracking
- [x] Pagination
- [x] Sorting
- [x] Health score calculation

---

## Migration 004 Integration

The Search & Filtering feature fully integrates with Migration 004 scanner metadata:

**Filters**:
- `scanner_ids` - Filter by scanner (slither, mythril, aderyn, etc.)
- `categories` - Filter by vulnerability category
- `min_confidence` - Filter by minimum confidence score

**Display**:
- Scanner badges in results
- Category tags in results
- Confidence indicators

**Export**:
- Scanner ID in CSV/JSON exports
- Category in CSV/JSON exports
- Confidence score in CSV/JSON exports

---

## Phase 3 Completion

**Week 6 - Day 6**: Search & Filtering ✅ COMPLETE

This completes the final task for Phase 3 Week 6 (Frontend Feature Completion).

**Week 6 Progress**: 100% (21h/21h)
- ✅ Day 1: Project Management UI (3h)
- ✅ Day 2: Findings Management (3h)
- ✅ Day 3: Scanner Configuration (2h)
- ✅ Day 4-5: Analytics Dashboard (3h) + Contract Analytics (5h)
- ✅ Day 6: **Search & Filtering (5h)** - THIS FEATURE

**Next Steps**:
- Phase 3 Week 7: Complete Tool Coverage (40h)
  - Implement remaining 11 scanners (37 total)
  - Docker images for all tools
  - Executor classes for each scanner
  - Integration tests
  - Documentation

---

**Last Updated**: October 18, 2025
**Status**: ✅ COMPLETE
**Version**: 1.0.0
