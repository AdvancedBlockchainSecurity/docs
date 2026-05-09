# Enhanced Contract Details Tests (Phase 3.4)

**Priority**: P2 - Medium
**Last Tested**: May 9, 2026 (compiler version wired against `contract.compiler_version`)
**Feature**: Contract Metadata, Security Score, Dependencies, Inheritance

**Implementation note (2026-05-09):** The Compiler Version field in `ContractMetadataPanel.tsx` was previously hardcoded to mock `0.8.20`. As of dashboard 0.53.4 (paired with api-service 0.43.11), it now reads from `contract.compiler_version` populated at upload time by `language_detector.py`. Two new derived fields are also surfaced on `GET /contracts/{id}`:

- `compiler_version_supported` — `true` / `false` / `null` (unparseable)
- `min_supported_solidity_version` — `"0.8.12"` (sourced from the platform-wide policy file `src/domain/entities/solidity_version.py`)

The contract detail page (`/contracts/{id}`) shows a **Solidity version chip** near the language/framework labels and an inline yellow `ValidationNoticeBanner` above the metadata panel when `compiler_version_supported === false`. The contracts list page (`/contracts`) has a new **Compiler** column (default-visible) showing the version per row.

---

## 1. Contract Metadata Panel

### 1.1 Compiler Settings Display
- [ ] Solidity version displayed correctly from `contract.compiler_version` (e.g., "v0.8.20") — no longer mock data
- [ ] When `compiler_version` is null: "Solidity version: detection pending" rendered de-emphasized
- [ ] When `compiler_version_supported === false`: amber unsupported badge rendered next to the version (dark-mode aware)
- [ ] EVM version displayed (e.g., "paris")
- [ ] Optimization status shown (Enabled/Disabled)
- [ ] Optimization runs count shown when enabled
- [ ] License type displayed (e.g., "MIT")

### 1.2 Deployment Details Display
- [ ] Deployment timestamp formatted correctly
- [ ] Deployer address displayed (truncated)
- [ ] Block number displayed with # prefix
- [ ] Transaction hash displayed (truncated)
- [ ] Copy button works for deployer address
- [ ] Copy button works for transaction hash

### 1.3 Size & Hashes Display
- [ ] Contract bytecode size in bytes/KB
- [ ] Warning shown if size > 24KB
- [ ] Init code size displayed
- [ ] Bytecode hash displayed
- [ ] Source hash displayed

### 1.4 Proxy Information
- [ ] Proxy badge shown for proxy contracts
- [ ] Implementation address displayed
- [ ] Copy button works for implementation address
- [ ] Proxy section hidden for non-proxy contracts

### 1.5 Panel Behavior
- [ ] Panel expands/collapses on header click
- [ ] Chevron icon rotates on expand/collapse
- [ ] Verified badge shown when contract verified
- [ ] Loading spinner during data fetch
- [ ] Empty state when no metadata available

---

## 2. Security Score Panel

### 2.1 Overall Score Display
- [ ] Circular gauge renders correctly
- [ ] Score number displayed in center (0-100)
- [ ] "out of 100" label shown
- [ ] Letter grade displayed (A-F)
- [ ] Grade badge has correct color

### 2.2 Score Coloring
- [ ] Score >= 90: Green, Grade A
- [ ] Score >= 80: Green, Grade B
- [ ] Score >= 70: Yellow, Grade C
- [ ] Score >= 60: Orange, Grade D
- [ ] Score < 60: Red, Grade F

### 2.3 Trend Indicator
- [ ] Up arrow for improving score (green)
- [ ] Down arrow for declining score (red)
- [ ] Dash for stable score (gray)
- [ ] Score change value displayed (+/- N)

### 2.4 Category Breakdown
- [ ] All categories displayed with progress bars
- [ ] Category name shown
- [ ] Category score shown (N/100)
- [ ] Issues count shown per category
- [ ] Bar color reflects score (green/yellow/red)

### 2.5 Risk Factors
- [ ] Risk factors section displayed
- [ ] Severity badge shown (critical/high/medium/low)
- [ ] Risk name displayed
- [ ] Risk description displayed
- [ ] Impact statement displayed
- [ ] Correct border colors per severity

### 2.6 Checks Summary
- [ ] "Passed X of Y security checks" displayed
- [ ] Passed count in green
- [ ] Total count emphasized

### 2.7 Navigation
- [ ] "View Full Security Analysis" link present
- [ ] Link navigates to /contracts/{id}/security
- [ ] Arrow icon displayed next to link

---

## 3. Dependency Tree Panel

### 3.1 Tab Navigation
- [ ] "All" tab shows all dependencies
- [ ] "Libraries" tab filters to libraries only
- [ ] "Interfaces" tab filters to interfaces only
- [ ] "Contracts" tab filters to contracts only
- [ ] Tab counts match filtered items
- [ ] Active tab highlighted

### 3.2 Dependency Cards
- [ ] Dependency name displayed
- [ ] Type badge shown (library/interface/contract/abstract)
- [ ] Source badge shown (openzeppelin/solmate/internal/external)
- [ ] Version displayed when available
- [ ] File path displayed (truncated if long)
- [ ] Usage count displayed

### 3.3 Function Tags
- [ ] Function names displayed as tags
- [ ] Maximum 5 functions shown
- [ ] "+N more" shown when functions > 5
- [ ] Function tags have () suffix

### 3.4 Suggestions Section
- [ ] Outdated warnings displayed (yellow)
- [ ] Warning icon shown
- [ ] Alternative recommendations displayed (blue)
- [ ] "from X to Y" format shown
- [ ] Reason displayed

### 3.5 Panel Behavior
- [ ] Total dependency count in header badge
- [ ] Panel expands/collapses
- [ ] Loading state displayed
- [ ] Empty state when no dependencies

---

## 4. Inheritance Tree Panel

### 4.1 Tree Visualization
- [ ] Root contract displayed at top
- [ ] Child contracts indented correctly
- [ ] Connection lines rendered between nodes
- [ ] Expand/collapse buttons on nodes with children
- [ ] Node expansion state persisted during session

### 4.2 Node Information
- [ ] Contract name displayed
- [ ] Type badge (contract/abstract/interface/library)
- [ ] Source badge (openzeppelin/solmate/internal/external)
- [ ] File path displayed

### 4.3 Node Details (when enabled)
- [ ] Functions list displayed
- [ ] Modifiers list displayed
- [ ] Function/modifier counts shown
- [ ] Details toggle checkbox works

### 4.4 Tree Controls
- [ ] "Expand All" expands all nodes
- [ ] "Collapse All" collapses to root only
- [ ] "Show details" checkbox toggles details

### 4.5 C3 Linearization
- [ ] Linearization order displayed
- [ ] Contract names as badges
- [ ] Arrow icons between contracts
- [ ] Correct method resolution order

### 4.6 Diamond Inheritance Warning
- [ ] Warning displayed when diamond pattern detected
- [ ] Warning icon shown (yellow)
- [ ] Affected contracts listed
- [ ] Hidden when no diamond pattern

### 4.7 Function Overrides
- [ ] Override section displayed when applicable
- [ ] Function name shown
- [ ] "defined in" contracts listed
- [ ] "resolved to" contract highlighted
- [ ] Arrow showing resolution direction

### 4.8 Panel Behavior
- [ ] Depth count in header
- [ ] Parent count in header
- [ ] Panel expands/collapses
- [ ] Loading state displayed
- [ ] Empty state when no inheritance

---

## 5. Integration in ContractDetail Page

### 5.0 Solidity Version Header Chip & Unsupported Notice (2026-05-09)
- [ ] Header chip near language/framework labels reads `Solidity vX.Y.Z` from `contract.compiler_version`
- [ ] Chip is hidden when `contract.language !== 'solidity'`
- [ ] When `contract.compiler_version_supported === false`, an inline yellow `ValidationNoticeBanner` renders above the metadata panel:
  > "This contract uses Solidity {version}; Apogee scans Solidity ≥{min_supported_solidity_version}. Update the pragma to enable scanning. [Language support →]"
- [ ] The notice uses the `bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800 text-amber-900 dark:text-amber-100` palette (dark-mode aware)
- [ ] Notice is hidden when `compiler_version_supported === true` or `null`
- [ ] CTA links to `/language-support` docs page

### 5.1 Panel Order
- [ ] Security Score Panel appears after Recent Scans
- [ ] Contract Metadata Panel appears after Security Score
- [ ] Code Quality Panel appears (existing)
- [ ] Gas Analysis Panel appears (existing)
- [ ] Contract Structure Panel appears (existing)
- [ ] Dependency Tree Panel appears after Contract Structure
- [ ] Inheritance Tree Panel appears after Dependency Tree
- [ ] Source Code Viewer appears last

### 5.2 Expand/Collapse All
- [ ] "Expand All" button expands all panels
- [ ] "Collapse All" button collapses all panels
- [ ] New panels respect expand/collapse

### 5.3 Responsive Layout
- [ ] Panels render correctly on desktop
- [ ] Panels render correctly on tablet
- [ ] Panels render correctly on mobile
- [ ] Text truncates appropriately
- [ ] Badges wrap correctly

---

## 6. Component Exports

- [ ] `ContractMetadataPanel` exported from index.ts
- [ ] `SecurityScorePanel` exported from index.ts
- [ ] `DependencyTreePanel` exported from index.ts
- [ ] `InheritanceTreePanel` exported from index.ts
- [ ] `ValidationNoticeBanner` exported from `src/components/common/` (added 2026-05-09)
- [ ] No TypeScript compilation errors
- [ ] No console errors on render

---

## 7. Contracts List — Compiler Column (2026-05-09)

### 7.1 Default Visibility
- [ ] `Compiler` column appears by default in `/contracts` (added to `DEFAULT_COLUMNS`)
- [ ] Old localStorage `contracts-visible-columns` keys are orphaned after the storage key bumped to `contracts-visible-columns-v2`; users see the new default once

### 7.2 Column Content
- [ ] Cell renders `contract.compiler_version` for each row (e.g., `0.8.20`)
- [ ] When `compiler_version` is null, cell shows muted dash placeholder
- [ ] Toggle the column off via column-picker — column disappears
- [ ] Toggle back on — column reappears

### 7.3 Language Filter
- [ ] Language filter dropdown only lists Tier 1 languages (Solidity, Vyper, Rust)
- [ ] Tier 2/3 entries (e.g., Cairo, Move, Go) are hidden — they were aspirational placeholders that misled users into filtering for unscannable languages

---

## Test Notes

_Record enhanced contract details test results here:_

```
[Date] | [Test] | [Result] | [Notes]
```
