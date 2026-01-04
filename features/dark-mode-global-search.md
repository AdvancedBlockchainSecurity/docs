# Dark Mode & Global Search

**Version:** 1.0.0
**Added:** v0.14.0 (Dashboard), v0.6.0 (API)
**Last Updated:** 2025-12-26

---

## Overview

Two user experience enhancements for the BlockSecOps Dashboard:

1. **Dark Mode** - Theme switching between light, dark, and system preference
2. **Global Search (Command Palette)** - Quick search across all entities with Cmd+K / Ctrl+K

---

## Dark Mode

### Features

- **Three modes**: Light, Dark, System (follows OS preference)
- **Persistent**: Theme choice saved to localStorage
- **Real-time**: System mode updates automatically when OS theme changes

### Usage

1. Click the theme dropdown in the top-right of the navigation bar
2. Select Light, Dark, or System
3. Theme applies immediately and persists across sessions

### Technical Implementation

| Component | File | Purpose |
|-----------|------|---------|
| ThemeContext | `src/contexts/ThemeContext.tsx` | State management |
| ThemeToggle | `src/components/common/ThemeToggle.tsx` | UI dropdown |
| Tailwind Config | `tailwind.config.js` | `darkMode: 'class'` |
| CSS Variables | `src/index.css` | Semantic color tokens |

### CSS Classes

All components use Tailwind's `dark:` prefix for dark mode styles:

```jsx
// Example
<div className="bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100">
  Content
</div>
```

---

## Global Search (Command Palette)

### Features

- **Keyboard shortcut**: `Cmd+K` (Mac) or `Ctrl+K` (Windows/Linux)
- **Search scope**: Projects, Contracts, Source Code, Vulnerabilities
- **Source code search**: Shows line numbers and code snippets
- **Keyboard navigation**: Arrow keys to navigate, Enter to select
- **Debounced**: 300ms delay to reduce API calls

### Usage

1. Press `Cmd+K` or click the Search button in the top bar
2. Type at least 2 characters to search
3. Use `↑↓` arrows to navigate results
4. Press `Enter` to go to the selected item
5. Press `Escape` to close

### Search Result Types

| Type | Icon | Subtitle Shows |
|------|------|----------------|
| Project | 📁 Folder | Description |
| Contract | 📄 Document | Line match from source code |
| Scan | 🕐 Clock | Scanner used |
| Vulnerability | 🛡️ Shield | Severity - Scanner |

### API Endpoint

```
GET /api/v1/search/quick?q=<query>&limit=<n>
```

**Parameters:**
- `q` (required): Search query (min 2 characters)
- `limit` (optional): Max results per type (default: 10, max: 20)

**Response:**
```json
{
  "query": "transfer",
  "results": [
    {
      "id": "uuid",
      "type": "contract",
      "title": "Token.sol",
      "subtitle": "Line 87: function transfer(address to, uint256 amount)",
      "url": "/contracts/uuid"
    }
  ],
  "total": 10,
  "query_time_ms": 12.5
}
```

### Source Code Search

When searching contracts, the API searches within `source_code` field and extracts:
- Line number of first match
- Code snippet showing the match context

Example result:
```json
{
  "type": "contract",
  "title": "VulnerableAMM.sol",
  "subtitle": "Line 178: // Direct token transfers can decrease K"
}
```

---

## Technical Details

### Frontend Components

| File | Description |
|------|-------------|
| `src/components/common/CommandPalette.tsx` | Main search dialog |
| `src/hooks/useDebounce.ts` | Debounce hook for search |
| `src/lib/api/search.ts` | API client function |

### Backend Implementation

| File | Description |
|------|-------------|
| `src/presentation/api/v1/endpoints/search.py` | GET /search/quick endpoint |
| `src/presentation/schemas/search.py` | QuickSearchResult, QuickSearchResponse |

### Performance

Typical query response times:
- Simple queries: 9-15ms
- Source code search: 200-350ms (first query)
- Cached queries: <50ms

---

## Configuration

### Theme Storage

Theme preference stored in localStorage:
```javascript
localStorage.getItem('blocksecops-theme') // 'light' | 'dark' | 'system'
```

### CSS Variables

Available CSS custom properties in `:root` and `.dark`:
- `--background`
- `--background-card`
- `--foreground`
- `--foreground-muted`
- `--border`
- `--primary`
- `--destructive`

---

## Troubleshooting

### Dark Mode Not Working

1. Check browser console for errors
2. Verify `dark` class is on `<html>` element
3. Clear localStorage: `localStorage.removeItem('blocksecops-theme')`

### Search Not Returning Results

1. Ensure query is at least 2 characters
2. Check authentication token is valid
3. Verify API service is running: `curl http://127.0.0.1:3000/api/v1/health/live`

### Command Palette Not Opening

1. Check for conflicting keyboard shortcuts
2. Try clicking the Search button instead
3. Verify user is authenticated (palette only shown for logged-in users)

---

## See Also

- [Dashboard Integration](../api/dashboard-integration.md)
- [API Endpoints Reference](../api/endpoints-reference.md)
- [Frontend Development Standards](/docs/standards/frontend-development.md)
