# Collapsible Sidebar & Quick Access Pins

**Priority**: P2 - Normal
**Last Tested**: 2026-02-09
**Scope**: Sidebar collapse/expand, quick access page pinning, localStorage persistence
**Dashboard Version**: 0.41.4

---

## 1. Sidebar Collapse/Expand

### 1.1 Toggle Button
- [ ] Chevron toggle button visible at bottom of sidebar (desktop only)
- [ ] ChevronDoubleLeftIcon shown when sidebar is expanded
- [ ] ChevronDoubleRightIcon shown when sidebar is collapsed
- [ ] Clicking toggle collapses sidebar from `w-64` (256px) to `w-16` (64px)
- [ ] Clicking again expands sidebar back to `w-64`

### 1.2 Collapsed State - Visual
- [ ] Logo area shows shield icon only (app name text hidden)
- [ ] Section headers show icon only, centered, no text
- [ ] Nav item labels hidden in collapsed state
- [ ] Section icons have `title` attribute for tooltip on hover
- [ ] Settings icon visible at bottom (collapsed)
- [ ] Help, Feedback, Terms links hidden when collapsed

### 1.3 Expanded State - Visual
- [ ] Full logo with app name visible
- [ ] Section headers show icon + text
- [ ] All nav items show icon + label
- [ ] All bottom links visible (Settings, Help, Feedback, Terms)

### 1.4 Transition Animation
- [ ] Width transition uses `transition-all duration-300`
- [ ] Smooth animation between collapsed/expanded states
- [ ] No layout jumps or flickering during transition
- [ ] Content area (`flex-1`) automatically expands/shrinks with sidebar

### 1.5 Persistence
- [ ] Collapse state saved to localStorage key `blocksecops-sidebar-collapsed`
- [ ] Refresh page — sidebar retains collapsed/expanded state
- [ ] Open new tab — sidebar reads persisted state
- [ ] Clear localStorage — sidebar defaults to expanded

---

## 2. Mobile Behavior

### 2.1 Mobile Sidebar
- [ ] Collapse toggle button hidden on mobile (below `lg` breakpoint)
- [ ] Sidebar still slides in/out as full-width overlay on mobile
- [ ] Mobile sidebar always shows expanded content (collapse state ignored)
- [ ] Hamburger menu opens/closes mobile sidebar as before

---

## 3. Quick Access Page Pins

### 3.1 Pin a Page
- [ ] Hover any nav item — pin icon (StarIcon outline) appears on right side
- [ ] Click pin icon — item added to Quick Access section at top of sidebar
- [ ] Pin icon changes to filled/solid (StarIconSolid) when pinned
- [ ] Maximum 5 items can be pinned
- [ ] Attempting to pin a 6th item — oldest item is not removed (pin icon hidden at max)

### 3.2 Unpin a Page
- [ ] Hover a pinned item in Quick Access section — X icon (XMarkIcon) appears
- [ ] Click X icon — item removed from Quick Access
- [ ] Pin icon on the original nav item reverts to outline (unpinned state)

### 3.3 Quick Access Section (Expanded)
- [ ] Section appears between logo and HOME section
- [ ] Header shows "QUICK ACCESS" label with StarIcon
- [ ] Lists pinned pages with name and navigation link
- [ ] Clicking a pinned page navigates to that route
- [ ] Empty state — Quick Access section hidden when no items pinned

### 3.4 Quick Access Section (Collapsed)
- [ ] Pinned pages shown as small star icons below logo area
- [ ] Each star icon has `title` tooltip with page name
- [ ] Clicking a star icon navigates to the pinned page

### 3.5 Persistence
- [ ] Quick access items saved to localStorage key `blocksecops-quick-access`
- [ ] Refresh page — pinned items persist
- [ ] Open new tab — pinned items loaded from storage
- [ ] Clear localStorage — quick access returns to empty state

---

## 4. Content Area Responsiveness

### 4.1 Layout Adaptation
- [ ] Main content uses `flex-1` — automatically fills available space
- [ ] Collapsing sidebar gives content area ~192px more width
- [ ] Expanding sidebar reduces content area back to original
- [ ] Tables, charts, and grids reflow appropriately
- [ ] No horizontal scrollbar introduced by collapse/expand

---

## 5. localStorage Helper API

### 5.1 quickAccess.ts Module
- [ ] `getQuickAccessItems()` returns array of `{ name, path }` objects
- [ ] `addQuickAccessItem({ name, path })` adds item, respects max 5 limit
- [ ] `removeQuickAccessItem(path)` removes item by path
- [ ] `isQuickAccessItem(path)` returns boolean
- [ ] Handles corrupted localStorage gracefully (returns defaults)
- [ ] Handles localStorage unavailable (private browsing) gracefully

---

## 6. Integration with Existing Features

### 6.1 Dark Mode Compatibility
- [ ] Collapsed sidebar renders correctly in dark mode
- [ ] Quick access icons have proper contrast in dark mode
- [ ] Transition animation works in dark mode

### 6.2 Theme Persistence
- [ ] Sidebar collapse + dark mode + quick access all persist independently
- [ ] No interference between localStorage keys

---

## Test Environment

| Component | Version |
|-----------|---------|
| Dashboard | 0.41.4 |
| Browser | Chrome/Firefox/Safari latest |
| Viewport | Desktop (1920x1080), Tablet (768px), Mobile (375px) |
