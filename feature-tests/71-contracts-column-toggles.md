# Feature Test 71: Contracts List Column Toggles

**Version:** Dashboard 0.45.13
**Date:** 2026-02-19
**Status:** Ready for Testing

## Prerequisites

- Dashboard deployed at version 0.45.13
- At least 2-3 contracts uploaded with varying data (projects, tags, networks)
- Clear localStorage for `contracts-visible-columns` key before testing (optional, for clean state)

---

## Test 1: Minimal Default View

**Page:** `/contracts`

- [ ] 1.1 Visit `/contracts` with no localStorage data for `contracts-visible-columns`
- [ ] 1.2 Verify table shows only 3 columns: checkbox, Contract, Actions
- [ ] 1.3 Verify Scan and Delete buttons are visible as icon-only buttons (no text)
- [ ] 1.4 Hover over Scan button, verify tooltip shows "Scan"
- [ ] 1.5 Hover over Delete button, verify tooltip shows "Delete"
- [ ] 1.6 Verify no "View →" column exists
- [ ] 1.7 Verify table does not have horizontal scrollbar at normal viewport width

## Test 2: Columns Dropdown

**Page:** `/contracts`

- [ ] 2.1 Locate "Columns" button between search input and language filter
- [ ] 2.2 Click "Columns" button, verify dropdown opens
- [ ] 2.3 Verify dropdown lists 8 optional columns: Projects, Tags, Type, Language, Network, Lines of Code, Status, Created
- [ ] 2.4 Verify all 8 checkboxes are unchecked by default
- [ ] 2.5 Verify "Show All" and "Hide All" buttons appear at bottom of dropdown
- [ ] 2.6 Click outside the dropdown, verify it closes
- [ ] 2.7 Click "Columns" button again, verify dropdown toggles open/closed

## Test 3: Toggle Individual Columns

**Page:** `/contracts`

- [ ] 3.1 Open Columns dropdown, check "Language" checkbox
- [ ] 3.2 Verify Language column appears in the table with correct data
- [ ] 3.3 Check "Network" checkbox
- [ ] 3.4 Verify Network column appears alongside Language
- [ ] 3.5 Uncheck "Language" checkbox
- [ ] 3.6 Verify Language column disappears, Network remains
- [ ] 3.7 Verify badge on Columns button shows "1" (one column enabled)

## Test 4: Show All / Hide All

**Page:** `/contracts`

- [ ] 4.1 Open Columns dropdown, click "Show All"
- [ ] 4.2 Verify all 8 checkboxes become checked
- [ ] 4.3 Verify all 8 optional columns appear in the table
- [ ] 4.4 Verify badge on Columns button shows "8"
- [ ] 4.5 Click "Hide All"
- [ ] 4.6 Verify all checkboxes become unchecked
- [ ] 4.7 Verify table returns to minimal 3-column view
- [ ] 4.8 Verify badge disappears from Columns button

## Test 5: localStorage Persistence

**Page:** `/contracts`

- [ ] 5.1 Enable Language, Network, and Status columns
- [ ] 5.2 Reload the page (F5 or browser refresh)
- [ ] 5.3 Verify Language, Network, and Status columns are still visible
- [ ] 5.4 Open Columns dropdown, verify those 3 checkboxes are checked
- [ ] 5.5 Open browser DevTools → Application → Local Storage
- [ ] 5.6 Verify key `contracts-visible-columns` exists with value `["language","network","status"]`
- [ ] 5.7 Delete the localStorage key, reload page
- [ ] 5.8 Verify table returns to minimal default view (all columns hidden)

## Test 6: Horizontal Scroll

**Page:** `/contracts`

- [ ] 6.1 Click "Show All" to enable all 8 optional columns
- [ ] 6.2 Resize browser window to a narrow width (e.g., 1024px)
- [ ] 6.3 Verify horizontal scrollbar appears on the table container
- [ ] 6.4 Scroll horizontally, verify all columns and data are accessible
- [ ] 6.5 Verify Actions column (Scan/Delete) is reachable via scroll

## Test 7: Action Buttons Functionality

**Page:** `/contracts`

- [ ] 7.1 In minimal view, click Scan icon button on any contract
- [ ] 7.2 Verify scan is triggered (spinner appears on button)
- [ ] 7.3 Click Delete icon button on any contract
- [ ] 7.4 Verify delete confirmation modal appears
- [ ] 7.5 Cancel the delete, verify no deletion occurs
- [ ] 7.6 Click on a contract row (not on action buttons), verify navigation to `/contracts/{id}`

## Test 8: Interaction with Existing Features

**Page:** `/contracts`

- [ ] 8.1 Use the search input to filter contracts, verify column toggles still work
- [ ] 8.2 Use the language filter dropdown, verify column toggles still work
- [ ] 8.3 Select multiple contracts via checkboxes, verify batch action bar appears
- [ ] 8.4 With columns enabled, verify project badges are clickable and navigate to `/projects/{id}`
- [ ] 8.5 Verify select-all checkbox in header still works correctly

---

## Test Notes

| Date | Tester | Result | Notes |
|------|--------|--------|-------|
| | | | |
