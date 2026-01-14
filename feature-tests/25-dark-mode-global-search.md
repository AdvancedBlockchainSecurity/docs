# Feature Test: Dark Mode & Global Search

**Feature ID**: 25
**Version**: 1.3.1
**Added**: v0.14.0 (Dashboard), v0.6.0 (API)
**Updated**: v0.29.0 (Dashboard) - Advanced Search rename, Contracts page search, Contract links, Filter layout fix
**Last Updated**: 2026-01-13

---

## Overview

Test guide for Dark Mode theme switching and Global Search (Command Palette) features.

---

## Prerequisites

- [ ] Dashboard running at http://127.0.0.1:3000
- [ ] API service running (accessible via Traefik)
- [ ] User logged in with valid account
- [ ] At least one contract with source code uploaded

---

## Test 1: Dark Mode Toggle

### 1.1 Light Mode

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to dashboard | Page loads with current theme |
| 2 | Click theme dropdown in top-right | Dropdown shows: Light, Dark, System |
| 3 | Select "Light" | Background becomes white/light gray |
| 4 | Verify sidebar | Sidebar has light theme colors |
| 5 | Verify cards | Cards have white background |

### 1.2 Dark Mode

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Click theme dropdown | Dropdown opens |
| 2 | Select "Dark" | Background becomes dark gray/black |
| 3 | Verify text | Text is light colored (readable) |
| 4 | Verify tables | Tables have dark backgrounds |
| 5 | Verify modals | Modals have dark theme |

### 1.3 System Mode

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select "System" in theme dropdown | Theme matches OS preference |
| 2 | (Mac) System Preferences > Appearance > Light | Dashboard switches to light |
| 3 | (Mac) System Preferences > Appearance > Dark | Dashboard switches to dark |

### 1.4 Persistence

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Select "Dark" mode | Theme changes to dark |
| 2 | Refresh page (F5 or Cmd+R) | Theme remains dark |
| 3 | Close and reopen browser tab | Theme remains dark |
| 4 | Open DevTools > Application > localStorage | `blocksecops-theme` = "dark" |

---

## Test 2: Global Search (Command Palette)

### 2.1 Opening the Palette

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Press `Cmd+K` (Mac) or `Ctrl+K` (Win/Linux) | Command palette opens |
| 2 | Click "Search..." button in top bar | Command palette opens |
| 3 | Press `Escape` | Palette closes |
| 4 | Click outside the palette | Palette closes |

### 2.2 Search Functionality

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Open palette, type "a" | No results (min 2 chars) |
| 2 | Type "re" | Results appear after 300ms delay |
| 3 | Type "reentrancy" | Contracts and vulnerabilities shown |
| 4 | Clear input, type "transfer" | Source code matches with line numbers |

### 2.3 Result Types

| Query | Expected Results |
|-------|------------------|
| Contract name (e.g., "Token") | Contract with folder icon |
| Vulnerability title (e.g., "reentrancy") | Vulnerability with shield icon |
| Source code keyword (e.g., "withdraw") | Contract with "Line X: code snippet" |
| Project name | Project with folder icon |

### 2.4 Keyboard Navigation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Type search query, get results | First result highlighted |
| 2 | Press `↓` (down arrow) | Next result highlighted |
| 3 | Press `↑` (up arrow) | Previous result highlighted |
| 4 | Press `Enter` | Navigate to selected result |

### 2.5 Mouse Navigation

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Hover over a result | Result gets highlighted |
| 2 | Click on a result | Navigate to that item |

---

## Test 3: API Endpoint

### 3.1 Quick Search API

```bash
# Get token
TOKEN=$(bash /path/to/get_token_fixed.sh)

# Test search
curl -s "http://127.0.0.1:3000/api/v1/search/quick?q=transfer&limit=5" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Response**:
```json
{
  "query": "transfer",
  "results": [
    {
      "id": "uuid",
      "type": "contract",
      "title": "ContractName.sol",
      "subtitle": "Line 20: function transfer(...)",
      "url": "/contracts/uuid"
    }
  ],
  "total": 5,
  "query_time_ms": 15.2
}
```

### 3.2 Edge Cases

| Test | Query | Expected |
|------|-------|----------|
| Empty query | `?q=` | 400 Bad Request |
| Single char | `?q=a` | 400 Bad Request |
| Very long query | `?q=<101 chars>` | 400 Bad Request |
| No auth token | (no header) | 401 Unauthorized |
| No matches | `?q=xyzabc123` | Empty results array |

---

## Test 4: Dark Mode + Search Combination

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Enable dark mode | Theme switches |
| 2 | Open command palette (Cmd+K) | Palette has dark background |
| 3 | Type search query | Input and results are readable |
| 4 | Navigate results | Highlight visible in dark mode |
| 5 | Switch to light mode | Palette updates to light theme |

---

## Test 5: Dark Mode Component Coverage (v0.15.1)

**Purpose**: Verify CSS overrides apply dark mode styling to all major UI components.

### 5.1 Dashboard Cards

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Enable dark mode | Theme switches | [ ] |
| 2 | Navigate to Dashboard (`/`) | Page loads | [ ] |
| 3 | Verify stat cards | Dark gray background (not white) | [ ] |
| 4 | Verify card text | Light text (gray-100), readable | [ ] |
| 5 | Verify card borders | Dark borders (gray-700) | [ ] |

### 5.2 Quota/Credits Cards

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Check header quota widget | Dark background, light text | [ ] |
| 2 | Navigate to Settings > Credits | Page loads | [ ] |
| 3 | Verify QuotaUsageCard | Dark gray background | [ ] |
| 4 | Verify progress bars | Visible with proper contrast | [ ] |

### 5.3 Settings Pages

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Settings (`/settings`) | Page loads | [ ] |
| 2 | Verify form inputs | Dark background, light text | [ ] |
| 3 | Verify select dropdowns | Dark background when opened | [ ] |
| 4 | Verify section cards | Dark backgrounds | [ ] |
| 5 | Navigate to Webhooks (`/webhooks`) | Page loads | [ ] |
| 6 | Verify webhook table | Dark rows, light text | [ ] |

### 5.4 Vulnerability Pages

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Vulnerabilities (`/vulnerabilities`) | Page loads | [ ] |
| 2 | Verify VulnerabilityCard components | Dark backgrounds | [ ] |
| 3 | Verify severity badges | Colored with proper contrast | [ ] |
| 4 | Click a vulnerability | Detail page loads | [ ] |
| 5 | Verify detail panels | Dark backgrounds throughout | [ ] |

### 5.5 Deduplication Pages

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Deduplication (`/deduplication`) | Page loads without errors | [ ] |
| 2 | Verify group cards | Dark backgrounds, readable text | [ ] |
| 3 | Click a group | Detail page loads | [ ] |
| 4 | Verify stats grid | All 4 stat cards have dark backgrounds | [ ] |
| 5 | Verify findings list | Dark row backgrounds | [ ] |
| 6 | Verify canonical badge | Green badge visible | [ ] |

### 5.6 Colored Alerts/Badges

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Find info box (blue) | Semi-transparent blue background | [ ] |
| 2 | Find success message (green) | Semi-transparent green background | [ ] |
| 3 | Find warning box (yellow) | Semi-transparent yellow background | [ ] |
| 4 | Find error message (red) | Semi-transparent red background | [ ] |
| 5 | Verify badge text | Light colored text (300 variants) | [ ] |

### 5.7 Contract Panels

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to Contracts (`/contracts`) | Page loads | [ ] |
| 2 | Click a contract | Detail page loads | [ ] |
| 3 | Verify CodeQualityPanel | Dark background | [ ] |
| 4 | Verify SecurityScorePanel | Dark background | [ ] |
| 5 | Verify GasAnalysisPanel | Dark background | [ ] |
| 6 | Verify all other panels | Dark backgrounds throughout | [ ] |

### 5.8 Modals

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open any modal (e.g., New Contract) | Modal appears | [ ] |
| 2 | Verify modal background | Dark gray (not white) | [ ] |
| 3 | Verify modal text | Light and readable | [ ] |
| 4 | Verify form inputs in modal | Dark inputs with light text | [ ] |
| 5 | Verify modal buttons | Proper contrast | [ ] |

---

## Test 6: Dark Mode Regression Tests

**Purpose**: Ensure no visual regressions from CSS overrides.

| Test | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Switch to Light mode | All backgrounds white, text dark | [ ] |
| 2 | Verify no dark artifacts in light mode | Clean light theme | [ ] |
| 3 | Toggle rapidly light→dark→light | No flickering or stuck states | [ ] |
| 4 | Refresh in dark mode | Theme persists correctly | [ ] |
| 5 | Check console for CSS errors | No errors | [ ] |

---

## Test 7: Intelligence Layer Dark Mode (v0.17.0)

**Purpose**: Verify all Intelligence Layer components support dark mode.

### 7.1 Deduplication Group Card

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Enable dark mode | Theme switches | [ ] |
| 2 | Navigate to Deduplication page | Page loads | [ ] |
| 3 | Verify group cards | Dark gray backgrounds | [ ] |
| 4 | Verify confidence badges | Proper contrast colors | [ ] |
| 5 | Verify buttons | Dark backgrounds, light text | [ ] |
| 6 | Hover over group card | Hover state visible | [ ] |

### 7.2 Deduplication Group List

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Verify loading skeleton | Dark placeholder colors | [ ] |
| 2 | Verify filter inputs | Dark backgrounds, light text | [ ] |
| 3 | Verify empty state | Readable text on dark background | [ ] |
| 4 | Verify pagination | Dark controls | [ ] |

### 7.3 Deduplication Indicator

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Find deduplication badge on vulnerability | Badge visible with contrast | [ ] |
| 2 | Click/hover to open popover | Popover has dark background | [ ] |
| 3 | Verify popover text | Light text, readable | [ ] |

### 7.4 Scanner Comparison View

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to scan results with multiple scanners | Comparison view loads | [ ] |
| 2 | Verify grid cells | Dark backgrounds | [ ] |
| 3 | Verify severity colors | Proper contrast on dark | [ ] |
| 4 | Verify footer section | Dark background, readable | [ ] |

### 7.5 Fingerprint Debug Panel

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open vulnerability detail with fingerprint | Panel loads | [ ] |
| 2 | Expand collapsible panel | Dark background | [ ] |
| 3 | Verify code blocks | Syntax highlighting visible | [ ] |
| 4 | Verify JSON display | Readable on dark background | [ ] |

### 7.6 Deduplication Insight Card

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Find insight card on dashboard | Card visible | [ ] |
| 2 | Verify gradient backgrounds | Semi-transparent dark gradients | [ ] |
| 3 | Verify text content | Light text, readable | [ ] |
| 4 | Hover over card | Hover state visible | [ ] |

---

## Test 8: Scanner Modal Dark Mode (v0.17.0)

**Purpose**: Verify Scanner Selection and Config modals support dark mode.

### 8.1 Scanner Selector

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Enable dark mode | Theme switches | [ ] |
| 2 | Click "Configure Security Scan" on contract | Modal opens | [ ] |
| 3 | Verify modal background | Dark gray (not white) | [ ] |
| 4 | Verify scanner rows | Dark backgrounds with contrast | [ ] |
| 5 | Hover over scanner row | Hover state visible on dark | [ ] |
| 6 | Verify preset selector | Dark dropdown, readable options | [ ] |
| 7 | Verify scanner badges | Colored with proper contrast | [ ] |
| 8 | Verify checkboxes | Visible on dark background | [ ] |

### 8.2 Scanner Config Modal

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Click gear icon on scanner | Config modal opens | [ ] |
| 2 | Verify modal container | Dark background | [ ] |
| 3 | Verify form inputs | Dark inputs, light text | [ ] |
| 4 | Verify select dropdowns | Dark options when opened | [ ] |
| 5 | Verify buttons | Proper contrast | [ ] |
| 6 | Close modal | Closes cleanly | [ ] |

### 8.3 Section Preferences Modal

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open Section Preferences modal | Modal opens | [ ] |
| 2 | Verify modal background | Dark gray | [ ] |
| 3 | Verify toggle switches | Visible on dark | [ ] |
| 4 | Verify section labels | Light text, readable | [ ] |

---

## Test 9: Advanced Search (Renamed from /search) (v0.29.0)

**Purpose**: Verify the search page rename from `/search` to `/advanced-search`.

### 9.1 URL and Navigation

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to `/advanced-search` | Advanced Search page loads | [ ] |
| 2 | Check sidebar | "Advanced Search" item under Contracts | [ ] |
| 3 | Click "Advanced Search" in sidebar | Navigates to `/advanced-search` | [ ] |
| 4 | Navigate to old `/search` URL | Should 404 (no redirect) | [ ] |

### 9.2 Saved Searches Integration

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Execute a saved search | Navigates to `/advanced-search?...` | [ ] |
| 2 | Verify URL parameters | Query params preserved | [ ] |
| 3 | Verify results display | Results load correctly | [ ] |

---

## Test 10: Contracts Page Search (v0.29.0)

**Purpose**: Verify the new client-side search functionality on the Contracts page.

### 10.1 Search Input

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to `/contracts` | Contracts page loads | [ ] |
| 2 | Verify search input presence | Input visible below header | [ ] |
| 3 | Verify placeholder text | "Search contracts by name or address..." | [ ] |
| 4 | Verify search icon | Magnifying glass icon on left | [ ] |

### 10.2 Search by Name

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Type contract name (e.g., "Token") | Results filter immediately | [ ] |
| 2 | Verify case-insensitive | "token" matches "Token" | [ ] |
| 3 | Verify partial match | "Tok" matches "TokenContract" | [ ] |
| 4 | Type non-existent name | Table shows empty state | [ ] |

### 10.3 Search by Address

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Type contract address | Results filter immediately | [ ] |
| 2 | Type partial address | Matches contracts with that substring | [ ] |
| 3 | Case insensitive | "0xABC" matches "0xabc" | [ ] |

### 10.4 Clear and Reset

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Type search query | Results filter | [ ] |
| 2 | Click X clear button | Query cleared, all contracts shown | [ ] |
| 3 | Verify clear button visibility | Only visible when query present | [ ] |

### 10.5 Select All with Filtered Results

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Type search query | Results filter | [ ] |
| 2 | Click "Select All" checkbox | Only filtered contracts selected | [ ] |
| 3 | Clear search | Selection count matches filtered count | [ ] |

---

## Test 11: Contract Links in Advanced Search (v0.29.0)

**Purpose**: Verify contract results in Advanced Search are clickable and navigate correctly.

### 11.1 Contract Result Click

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to `/advanced-search` | Page loads | [ ] |
| 2 | Search for contracts | Contract results appear | [ ] |
| 3 | Hover over contract result | Cursor changes to pointer, bg highlights | [ ] |
| 4 | Click on contract result | Navigates to `/contracts/{id}` | [ ] |

### 11.2 Visual Indicators

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | View contract results | Arrow (chevron-right) icon visible | [ ] |
| 2 | Hover over result | Background changes to gray-50 | [ ] |

### 11.3 Dark Mode Compatibility

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Enable dark mode | Theme switches | [ ] |
| 2 | Search for contracts | Results visible with proper contrast | [ ] |
| 3 | Hover over result | Hover state visible on dark background | [ ] |
| 4 | Click result | Navigation works correctly | [ ] |

---

## Test 12: Advanced Search Filter Layout (v0.29.0)

**Purpose**: Verify filter chips in Advanced Search don't overflow the content area.

### 12.1 Filter Wrapping

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Navigate to `/advanced-search` | Page loads | [ ] |
| 2 | Observe filter chips section | Filters organized in rows by type | [ ] |
| 3 | Verify Severity row | "Severity:" label, 4 chips wrap properly | [ ] |
| 4 | Verify Scanner row | "Scanners:" label, chips wrap to multiple lines | [ ] |
| 5 | Verify Category row | "Categories:" label, chips wrap properly | [ ] |
| 6 | Resize window narrower | Chips reflow without overflow | [ ] |

### 12.2 No Overflow Behind Sidebar

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Open Advanced Search with many filters | All filters visible | [ ] |
| 2 | Verify no horizontal scroll | Content stays within container | [ ] |
| 3 | Verify Saved Searches section | Filters don't overlap or hide behind it | [ ] |
| 4 | Toggle several filter chips | Active states visible, no layout shift | [ ] |

### 12.3 Dark Mode Filter Layout

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Enable dark mode | Theme switches | [ ] |
| 2 | Navigate to `/advanced-search` | Page loads | [ ] |
| 3 | Verify filter section labels | Labels readable (text-gray-500 in dark) | [ ] |
| 4 | Verify active/inactive chips | Proper contrast in dark mode | [ ] |
| 5 | Verify confidence slider | Visible and functional | [ ] |

---

## Known Issues

None at this time.

---

## Implementation Notes (v0.15.1)

### Dark Mode CSS-Level Overrides

**Problem**: Components used hardcoded Tailwind classes (`bg-white`, `text-gray-900`) without `dark:` variants, causing white cards on dark backgrounds.

**Solution**: Added ~450 lines of CSS overrides to `src/index.css` using `@layer utilities` to automatically apply dark styles:

```css
@layer utilities {
  /* Card/Panel backgrounds */
  .dark .bg-white {
    background-color: rgb(31 41 55); /* gray-800 */
  }

  /* Primary text */
  .dark .text-gray-900 {
    color: rgb(243 244 246); /* gray-100 */
  }

  /* Borders */
  .dark .border-gray-200 {
    border-color: rgb(55 65 81); /* gray-700 */
  }

  /* Form elements, alerts, shadows - see src/index.css */
}
```

**Advantages**:
- Single file change (1 file vs 94+ component files)
- No component refactoring required
- CSS specificity ensures dark mode applies correctly
- Easy rollback if needed

**Reference**: See `TASK-25-DARK-MODE-CSS-FIX.md` for full implementation details.

---

## Troubleshooting

### Dark Mode Not Applying

1. Check browser console for JavaScript errors
2. Verify `dark` class exists on `<html>` element
3. Clear localStorage: `localStorage.removeItem('blocksecops-theme')`
4. Hard refresh: `Cmd+Shift+R`

### Search Not Working

1. Verify API is reachable: `curl http://127.0.0.1:3000/api/v1/health/live`
2. Check authentication token is valid
3. Open DevTools Network tab, look for `/search/quick` requests
4. Verify user has at least one contract uploaded

### Command Palette Not Opening

1. Check for conflicting browser extensions
2. Verify user is logged in
3. Try clicking the Search button instead of keyboard shortcut

---

## API Test Commands

```bash
# Basic search
curl -s "http://127.0.0.1:3000/api/v1/search/quick?q=reentrancy&limit=10" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Source code search
curl -s "http://127.0.0.1:3000/api/v1/search/quick?q=withdraw&limit=5" \
  -H "Authorization: Bearer $TOKEN" | jq '.results[] | {title, subtitle}'

# Check response time
time curl -s "http://127.0.0.1:3000/api/v1/search/quick?q=transfer&limit=10" \
  -H "Authorization: Bearer $TOKEN" > /dev/null
```

---

## Sign-Off

| Tester | Date | Result |
|--------|------|--------|
| | | |

---

## Related Documentation

- [Feature Docs: Dark Mode & Global Search](/blocksecops-docs/features/dark-mode-global-search.md)
- [API Endpoints Reference](/blocksecops-docs/api/endpoints-reference.md)
- [Task 24 Implementation](/TaskDocs-BlockSecOps/phases/04-phase-4.5-enterprise-features/TASK-24-DARK-MODE-GLOBAL-SEARCH.md)
- [Task 25 CSS Fix](/TaskDocs-BlockSecOps/phases/04-phase-4.5-enterprise-features/TASK-25-DARK-MODE-CSS-FIX.md)
