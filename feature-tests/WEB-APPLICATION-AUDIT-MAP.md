# BlockSecOps Web Application Functionality Audit Map

**Version:** 1.0.0
**Created:** January 22, 2026
**Purpose:** Comprehensive mapping of all user actions, API calls, and testable functionality

## Overview

This document provides a complete audit map of the BlockSecOps web application, detailing every page, user action, and API endpoint for functionality testing and verification.

### Application Stack
- **Frontend:** React 18 + TypeScript + Vite
- **State Management:** TanStack React Query + React Context
- **Authentication:** Supabase (email/password, OAuth, wallet)
- **Web3:** Wagmi (Ethereum) + Solana adapters
- **API Base:** `/api/v1` (relative path via Traefik)

### Authentication Methods
1. Email/Password (Supabase)
2. OAuth Providers: Google, GitHub, Microsoft, Discord, Slack, BitBucket, X/Twitter
3. Ethereum Wallets: MetaMask, WalletConnect
4. Solana Wallets: Phantom, Solflare

---

## Table of Contents

1. [Authentication Pages (5)](#1-authentication-pages)
2. [Home Section (3)](#2-home-section)
3. [Intelligence Section (6)](#3-intelligence-section)
4. [Contracts Section (3)](#4-contracts-section)
5. [Projects Section (2)](#5-projects-section)
6. [Scanners Section (4)](#6-scanners-section)
7. [Admin Section (6)](#7-admin-section)
8. [Billing Section (4)](#8-billing-section)
9. [Settings (1)](#9-settings-section)
10. [Global Components](#10-global-components)

---

## 1. Authentication Pages

### 1.1 Login (`/login`)
**Component:** `src/pages/Login.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Submit email/password | Form submit button | Supabase `signInWithPassword` | Redirect to `/` on success |
| Click "Register" link | Text link | None | Navigate to `/register` |
| Click "Forgot Password" | Text link | None | Navigate to `/forgot-password` |
| Click OAuth provider | OAuth buttons (7) | Supabase `signInWithOAuth` | OAuth flow redirect |
| Connect Ethereum wallet | WalletConnect button | `POST /auth/wallet/verify` | Wallet signature verification |
| Connect Solana wallet | Solana button | `POST /auth/solana/verify` | Wallet signature verification |
| Remember me checkbox | Checkbox | None | Session persistence toggle |

### 1.2 Register (`/register`)
**Component:** `src/pages/Register.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Submit registration form | Form submit button | Supabase `signUp` | Email verification sent |
| Click "Login" link | Text link | None | Navigate to `/login` |
| Connect wallet (register) | Wallet buttons | `POST /auth/wallet/register` | Account created with wallet |

### 1.3 Verify Email (`/verify-email`)
**Component:** `src/pages/VerifyEmail.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Enter verification code | Code input | Supabase `verifyOtp` | Account verified |
| Resend verification | Resend button | Supabase `resend` | New email sent |

### 1.4 Forgot Password (`/forgot-password`)
**Component:** `src/pages/ForgotPassword.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Submit email | Form submit button | Supabase `resetPasswordForEmail` | Reset email sent |
| Click "Back to login" | Text link | None | Navigate to `/login` |

### 1.5 Reset Password (`/reset-password`)
**Component:** `src/pages/ResetPassword.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Submit new password | Form submit button | Supabase `updateUser` | Password updated |

---

## 2. Home Section

### 2.1 Dashboard (`/`)
**Component:** `src/pages/Dashboard.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /users/quota` | Quota bar displayed |
| View page | Page load | `GET /statistics/dashboard` | Stats cards populated |
| View page | Page load | `GET /statistics/scan-history` | Scan history chart rendered |
| View page | Page load | `GET /vulnerabilities?limit=5` | Recent vulns displayed |
| View page | Page load | `GET /contracts?limit=5&status=scanned` | Recent contracts displayed |
| Click "Critical Only" filter | Quick filter button | None | Navigate to `/advanced-search?severities=critical` |
| Click "High Confidence" filter | Quick filter button | None | Navigate to `/advanced-search?min_confidence=0.8` |
| Click "Slither Findings" filter | Quick filter button | None | Navigate to `/advanced-search?scanners=slither` |
| Click "Reentrancy" filter | Quick filter button | None | Navigate to `/advanced-search?categories=reentrancy` |
| Click "Advanced Search" | Button | None | Navigate to `/advanced-search` |
| Click "Upgrade" | Button (developer tier) | None | Navigate to `/pricing` |
| Click vulnerability row | Table row | None | Navigate to `/vulnerabilities/{id}` |
| Click contract row | Table row | None | Navigate to `/contracts/{id}` |

### 2.2 Dashboard Analytics (`/analytics`)
**Component:** `src/pages/DashboardAnalytics.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /analytics/summary` | Analytics summary displayed |
| View page | Page load | `GET /analytics/vulnerability-trends` | Trends chart rendered |
| View page | Page load | `GET /analytics/scanner-comparison` | Scanner comparison chart |
| Change date range | Date picker | Refetch analytics with new range | Data updated |
| Export report | Export button | `GET /analytics/export?format=pdf` | PDF downloaded |

### 2.3 Activity Log (`/activity`)
**Component:** `src/pages/ActivityLog.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /users/activity?limit=50` | Activity list displayed |
| Filter by action type | Dropdown | `GET /users/activity?action={type}` | Filtered results |
| Load more | Load more button | `GET /users/activity?cursor={cursor}` | More activities appended |

---

## 3. Intelligence Section

### 3.1 Vulnerabilities List (`/vulnerabilities`)
**Component:** `src/pages/VulnerabilitiesList.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /vulnerabilities` | Vuln list displayed |
| Filter by severity | Dropdown | `GET /vulnerabilities?severity={value}` | Filtered results |
| Filter by status | Dropdown | `GET /vulnerabilities?status={value}` | Filtered results |
| Filter by scanner | Dropdown | `GET /vulnerabilities?scanner_id={value}` | Filtered results |
| Search vulnerabilities | Search input | `GET /vulnerabilities?search={query}` | Search results |
| Click vulnerability row | Table row | None | Navigate to `/vulnerabilities/{id}` |
| Bulk update status | Bulk action | `PATCH /vulnerabilities/bulk` | Status updated |
| Export vulnerabilities | Export button | `GET /vulnerabilities/export?format=csv` | CSV downloaded |

### 3.2 Vulnerability Detail (`/vulnerabilities/:id`)
**Component:** `src/pages/VulnerabilityDetail.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /vulnerabilities/{id}` | Vuln detail displayed |
| Update status | Status dropdown | `PATCH /vulnerabilities/{id}` | Status changed |
| Add annotation | Annotation form | `POST /annotations` | Annotation saved |
| Mark false positive | Button | `PATCH /vulnerabilities/{id}?status=false_positive` | Marked as FP |
| View code context | Code viewer | None | Source code displayed |
| View similar patterns | Pattern section | `GET /patterns/{pattern_code}` | Related patterns shown |

### 3.3 Deduplication List (`/deduplication`)
**Component:** `src/pages/DeduplicationList.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /deduplication/groups` | Groups listed |
| Filter by confidence | Dropdown | `GET /deduplication/groups?confidence={level}` | Filtered groups |
| Click group row | Table row | None | Navigate to `/deduplication/{id}` |
| Merge groups | Bulk action | `POST /deduplication/groups/merge` | Groups merged |

### 3.4 Deduplication Detail (`/deduplication/:id`)
**Component:** `src/pages/DeduplicationDetail.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /deduplication/groups/{id}` | Group detail displayed |
| Set canonical finding | Radio button | `PATCH /deduplication/groups/{id}/canonical` | Canonical updated |
| Remove finding from group | Remove button | `POST /deduplication/ungroup` | Finding ungrouped |
| View all instances | Instances list | None | All related findings shown |

### 3.5 Patterns List (`/patterns`)
**Component:** `src/pages/PatternsList.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /patterns` | Patterns listed |
| Filter by category | Dropdown | `GET /patterns?category={value}` | Filtered patterns |
| Filter by severity | Dropdown | `GET /patterns?severity={value}` | Filtered patterns |
| Search patterns | Search input | `GET /patterns?search={query}` | Search results |
| Click pattern row | Table row | None | Navigate to `/patterns/{id}` |

### 3.6 Pattern Detail (`/patterns/:id`)
**Component:** `src/pages/PatternDetail.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /patterns/{id}` | Pattern detail displayed |
| View statistics | Stats section | `GET /patterns/{id}/statistics` | Usage stats shown |
| View related vulns | Related section | `GET /vulnerabilities?pattern_code={code}` | Related vulns listed |

---

## 4. Contracts Section

### 4.1 Contracts List (`/contracts`)
**Component:** `src/pages/ContractsList.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /contracts` | Contract list displayed |
| Upload contract | Upload button | Modal opens | Upload modal shown |
| Submit file upload | Modal submit | `POST /upload` (multipart) | Contract created |
| Filter by language | Dropdown | `GET /contracts?language={value}` | Filtered results |
| Search contracts | Search input | Local filter | Filtered table |
| Select contract | Checkbox | None | Selection state updated |
| Select all | Header checkbox | None | All selected |
| Click "Batch Scan" | Floating action | Modal opens | Batch scan modal shown |
| Clear selection | Clear button | None | Selection cleared |
| Click "Scan" | Row button | `POST /scans` | Scan triggered |
| Click "Delete" | Row button | Confirmation modal | Delete modal shown |
| Confirm delete | Modal button | `DELETE /contracts/{id}` | Contract deleted |
| Click contract row | Table row | None | Navigate to `/contracts/{id}` |
| Click project badge | Project link | None | Navigate to `/projects/{id}` |
| Toggle column visibility | "Columns" dropdown | None (localStorage) | Optional columns shown/hidden |
| Show all columns | "Show All" button | None (localStorage) | All 8 optional columns visible |
| Hide all columns | "Hide All" button | None (localStorage) | Minimal view (checkbox, contract, actions) |

### 4.2 Contract Detail (`/contracts/:id`)
**Component:** `src/pages/ContractDetail.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /contracts/{id}` | Contract detail displayed |
| View page | Page load | `GET /scans?contract_id={id}` | Scan history shown |
| View page | Page load | `GET /vulnerabilities?contract_id={id}` | Vulns listed |
| Trigger new scan | Scan button | `POST /scans` | New scan created |
| View scan results | Scan row click | None | Navigate to `/scans/{id}` |
| Edit contract name | Edit button | `PATCH /contracts/{id}` | Name updated |
| Add to project | Project dropdown | `POST /projects/{id}/contracts` | Added to project |
| Add tag | Tag input | `POST /tags/assign` | Tag assigned |
| Remove tag | Tag remove button | `DELETE /tags/unassign` | Tag removed |
| View source code | Code tab | None | Source code displayed |
| Toggle favorite | Star button | `POST /favorites` or `DELETE /favorites/{id}` | Favorite toggled |
| Compare scans | Compare button | None | Navigate to `/scans/compare?ids={a},{b}` |

### 4.3 Advanced Search (`/advanced-search`)
**Component:** `src/pages/Search.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | None | Empty search form |
| Submit search | Search button | `POST /search/advanced` | Results displayed |
| Filter by severity | Checkbox group | Included in search | Filtered results |
| Filter by scanner | Checkbox group | Included in search | Filtered results |
| Filter by category | Dropdown | Included in search | Filtered results |
| Filter by date range | Date picker | Included in search | Filtered results |
| Filter by confidence | Slider | Included in search | Filtered results |
| Save search | Save button | `POST /saved-searches` | Search saved |
| Load saved search | Saved search list | `GET /saved-searches/{id}/execute` | Search executed |
| Export results | Export button | `GET /search/export?format=csv` | CSV downloaded |

---

## 5. Projects Section

### 5.1 Projects List (`/projects`)
**Component:** `src/pages/Projects.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /projects` | Project list displayed |
| Create project | Create button | Modal opens | Create modal shown |
| Submit create | Modal submit | `POST /projects` | Project created |
| Search projects | Search input | `GET /projects?search={query}` | Search results |
| Filter by status | Dropdown | `GET /projects?status={value}` | Filtered results |
| Click project card | Project card | None | Navigate to `/projects/{id}` |
| Delete project | Delete button | `DELETE /projects/{id}` | Project deleted |
| Toggle view mode | Toggle button | None | Grid/List view changed |

### 5.2 Project Detail (`/projects/:id`)
**Component:** `src/pages/ProjectDetail.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /projects/{id}` | Project detail displayed |
| View page | Page load | `GET /contracts?project_id={id}` | Contracts listed |
| Edit project | Edit button | `PATCH /projects/{id}` | Project updated |
| Add contract | Add button | `POST /projects/{id}/contracts` | Contract added |
| Remove contract | Remove button | `DELETE /projects/{id}/contracts/{cid}` | Contract removed |
| Configure quality gate | QG button | `POST /quality-gates` | QG configured |
| View quality gate | QG status | `GET /quality-gates/{project_id}` | QG status shown |
| Grant team access | Access dropdown | `POST /project-access/team` | Team access granted |
| Grant user access | Access dropdown | `POST /project-access/user` | User access granted |
| Revoke access | Revoke button | `DELETE /project-access/{id}` | Access revoked |

---

## 6. Scanners Section

### 6.1 Batch Scan (`/batches`)
**Component:** `src/pages/BatchScan.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /scans/batch` | Batch list displayed |
| Create batch scan | Create button | Modal opens | Batch modal shown |
| Select contracts | Contract checkboxes | None | Selection updated |
| Select scanners | Scanner checkboxes | None | Selection updated |
| Submit batch | Submit button | `POST /scans/batch` | Batch created |
| View batch status | Batch row | `GET /scans/batch/{id}` | Status displayed |
| Cancel batch | Cancel button | `POST /scans/batch/{id}/cancel` | Batch cancelled |

### 6.2 Scanner Comparison (`/scanners`)
**Component:** `src/pages/ScannerComparison.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /scanners` | Scanner list displayed |
| View page | Page load | `GET /analytics/scanner-comparison` | Comparison data loaded |
| Filter by language | Dropdown | `GET /scanners?language={value}` | Filtered scanners |
| Filter by category | Dropdown | `GET /scanners?category={value}` | Filtered scanners |
| Compare scanners | Select + Compare | `POST /analytics/scanner-comparison` | Comparison shown |
| View scanner details | Scanner card | None | Expanded details |

### 6.3 Scanner Effectiveness (`/analytics/scanner-effectiveness`)
**Component:** `src/pages/ScannerEffectiveness.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /analytics/scanner-effectiveness` | Effectiveness data |
| Change date range | Date picker | Refetch with new range | Data updated |
| Filter by category | Dropdown | Filter data | Chart updated |
| Export report | Export button | `GET /analytics/export` | Report downloaded |

### 6.4 Scan Results (`/scans/:id`)
**Component:** `src/pages/ScanResults.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /scans/{id}` | Scan detail displayed |
| View page | Page load | `GET /scans/{id}/vulnerabilities/breakdown` | Vulns categorized |
| Filter vulns | Filter dropdowns | Local filter | Filtered list |
| Export report | Export button | `GET /scans/{id}/export?format=pdf` | PDF downloaded |
| Export SARIF | Export button | `GET /scans/{id}/export?format=sarif` | SARIF downloaded |
| Compare with scan | Compare button | None | Navigate to `/scans/compare` |
| Delete scan | Delete button | `DELETE /scans/{id}` | Scan deleted |

### 6.5 Scan Comparison (`/scans/compare`)
**Component:** `src/pages/ScanComparison.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load (with params) | `GET /scans/compare?scan_id_a={a}&scan_id_b={b}` | Comparison displayed |
| Select scan A | Dropdown | Update URL params | Scan A selected |
| Select scan B | Dropdown | Update URL params | Scan B selected |
| View diff | Comparison view | None | New/fixed/unchanged shown |
| Filter by status | Filter buttons | Local filter | Filtered diff |

---

## 7. Admin Section

### 7.1 API Keys (`/api-keys`)
**Component:** `src/pages/ApiKeys.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /api-keys` | API keys listed |
| Create key | Create button | Modal opens | Create modal shown |
| Submit create | Modal submit | `POST /api-keys` | Key created, secret shown |
| Copy key secret | Copy button | None | Copied to clipboard |
| Toggle show revoked | Checkbox | `GET /api-keys?include_revoked=true` | Revoked keys shown |
| Edit key | Edit button | `PATCH /api-keys/{id}` | Key updated |
| Revoke key | Revoke button | `DELETE /api-keys/{id}` | Key revoked |
| Regenerate key | Regenerate button | `POST /api-keys/{id}/regenerate` | New secret generated |
| View usage | Usage button | `GET /api-keys/{id}/usage` | Usage stats shown |

### 7.2 Webhooks (`/webhooks`)
**Component:** `src/pages/Webhooks.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /webhooks` | Webhooks listed |
| Create webhook | Create button | `POST /webhooks` | Webhook created |
| Edit webhook | Edit button | `PATCH /webhooks/{id}` | Webhook updated |
| Delete webhook | Delete button | `DELETE /webhooks/{id}` | Webhook deleted |
| Test webhook | Test button | `POST /webhooks/{id}/test` | Test payload sent |
| View deliveries | Deliveries button | `GET /webhooks/{id}/deliveries` | Deliveries listed |
| Retry delivery | Retry button | `POST /webhooks/{id}/deliveries/{did}/retry` | Delivery retried |

### 7.3 Notification Channels (`/notification-channels`)
**Component:** `src/pages/NotificationChannels.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /notifications/channels` | Channels listed |
| Create channel | Create button | `POST /notifications/channels` | Channel created |
| Edit channel | Edit button | `PATCH /notifications/channels/{id}` | Channel updated |
| Delete channel | Delete button | `DELETE /notifications/channels/{id}` | Channel deleted |
| Test channel | Test button | `POST /notifications/channels/{id}/test` | Test notification sent |
| Toggle enabled | Toggle switch | `PATCH /notifications/channels/{id}` | Enabled state changed |

### 7.4 Audit Logs (`/audit-logs`)
**Component:** `src/pages/AuditLogs.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /audit-logs` | Audit logs listed |
| Filter by action | Dropdown | `GET /audit-logs?action={value}` | Filtered logs |
| Filter by date range | Date picker | `GET /audit-logs?start={s}&end={e}` | Filtered logs |
| Filter by user | User dropdown | `GET /audit-logs?user_id={id}` | Filtered logs |
| View log detail | Log row | Modal opens | Detail modal shown |
| Export CSV | Export button | `GET /audit-logs/export?format=csv` | CSV downloaded |
| Export JSON | Export button | `GET /audit-logs/export?format=json` | JSON downloaded |
| View summary | Summary tab | `GET /audit-logs/summary` | Summary displayed |

### 7.5 Organizations (`/organizations`)
**Component:** `src/pages/Organizations.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /organizations` | Organizations listed |
| Create organization | Create button | `POST /organizations` | Org created |
| Edit organization | Edit button | `PATCH /organizations/{id}` | Org updated |
| View members | Members tab | `GET /organizations/{id}/members` | Members listed |
| Add member | Add button | `POST /organizations/{id}/members` | Member added |
| Remove member | Remove button | `DELETE /organizations/{id}/members/{uid}` | Member removed |
| Update member role | Role dropdown | `PATCH /organizations/{id}/members/{uid}` | Role updated |
| View roles | Roles tab | `GET /organizations/{id}/roles` | Roles listed |
| Create role | Create role button | `POST /organizations/{id}/roles` | Role created |

### 7.6 Teams (`/teams`)
**Component:** `src/pages/Teams.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /teams` | Teams listed |
| Create team | Create button | `POST /teams` | Team created |
| Edit team | Edit button | `PATCH /teams/{id}` | Team updated |
| Delete team | Delete button | `DELETE /teams/{id}` | Team deleted |
| Add member | Add button | `POST /teams/{id}/members` | Member added |
| Remove member | Remove button | `DELETE /teams/{id}/members/{uid}` | Member removed |
| Update member role | Role dropdown | `PATCH /teams/{id}/members/{uid}` | Role updated |

---

## 8. Billing Section

### 8.1 Billing (`/billing`)
**Component:** `src/pages/Billing.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /billing/subscription` | Subscription displayed |
| View page | Page load | `GET /users/quota` | Usage shown |
| View page | Page load | `GET /billing/history` | History shown |
| Click "Upgrade" | Upgrade button | None | Navigate to `/pricing` |
| Click "Buy Credits" | Quick link | None | Navigate to `/credits` |
| Click "Credit History" | Quick link | None | Navigate to `/credits/history` |
| Click "View Plans" | Quick link | None | Navigate to `/pricing` |
| Manage subscription | Manage button | `POST /billing/portal` | Stripe portal opened |
| Cancel subscription | Cancel button | `POST /billing/subscription/cancel` | Cancellation initiated |

### 8.2 Credits (`/credits`)
**Component:** `src/pages/Credits.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /payments/credits` | Balance displayed |
| View page | Page load | `GET /payments/packages` | Packages listed |
| Purchase package | Buy button | `POST /payments/checkout` | Stripe checkout opened |
| View history | History link | None | Navigate to `/credits/history` |

### 8.3 Credit History (`/credits/history`)
**Component:** `src/pages/CreditHistory.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /payments/credits/history` | History listed |
| Filter by type | Type dropdown | `GET /payments/credits/history?type={value}` | Filtered history |
| Filter by date | Date picker | `GET /payments/credits/history?start={s}&end={e}` | Filtered history |
| Load more | Load more button | Pagination | More records loaded |

### 8.4 Pricing (`/pricing`)
**Component:** `src/pages/Pricing.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /pricing` (or static) | Pricing tiers displayed |
| Select monthly/yearly | Toggle | None | Prices updated |
| Click "Get Started" | Tier button | `POST /billing/checkout` | Stripe checkout opened |
| Compare features | Feature table | None | Comparison shown |
| View enterprise | Enterprise card | None | Contact modal shown |

---

## 9. Settings Section

### 9.1 User Settings (`/settings`)
**Component:** `src/pages/Settings.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| View page | Page load | `GET /users/me` | User info displayed |
| Update profile | Profile form | `PATCH /users/me` | Profile updated |
| Change password | Password form | Supabase `updateUser` | Password changed |
| Update preferences | Preference toggles | `PATCH /users/preferences` | Preferences saved |
| Link wallet | Connect wallet button | `POST /auth/wallet/link` | Wallet linked |
| Unlink wallet | Unlink button | `DELETE /auth/wallet/unlink` | Wallet unlinked |
| Link OAuth | OAuth buttons | Supabase `linkIdentity` | Provider linked |
| Delete account | Delete button | `DELETE /users/me` | Account deleted |

---

## 10. Global Components

### 10.1 Sidebar Navigation
**Component:** `src/components/navigation/Sidebar.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Click nav item | Nav link | None | Navigate to route |
| Click logo | Logo | None | Navigate to `/` |
| Click Settings | Settings link | None | Navigate to `/settings` |
| Click Send Feedback | Feedback button | Modal opens | Feedback modal shown |
| Submit feedback | Feedback form | `POST /feedback` | Feedback submitted |
| Mobile menu toggle | Menu button | None | Sidebar toggles |

### 10.2 TopBar
**Component:** `src/components/navigation/TopBar.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Click menu (mobile) | Menu button | None | Sidebar opens |
| Click search | Search icon | None | Command palette opens |
| Click notifications | Bell icon | None | Notification dropdown |
| Mark notification read | Notification item | `PATCH /notifications/{id}` | Marked as read |
| Click user avatar | User menu | None | User dropdown opens |
| Click logout | Logout option | Supabase `signOut` | User logged out |

### 10.3 Command Palette (Cmd+K)
**Component:** `src/components/common/CommandPalette.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Open (Cmd+K) | Keyboard shortcut | None | Palette opens |
| Type search | Search input | `GET /search/quick?q={query}` | Results shown |
| Select result | Result item | None | Navigate to item |
| Close (Esc) | Keyboard shortcut | None | Palette closes |

### 10.4 Upgrade Banner
**Component:** `src/components/common/UpgradeBanner.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Click upgrade | Upgrade button | None | Navigate to `/pricing` |
| Dismiss banner | Close button | localStorage | Banner hidden |

### 10.5 Payment Modal
**Component:** `src/components/payment/PaymentModal.tsx`

| User Action | Element | API Call | Expected Outcome |
|-------------|---------|----------|------------------|
| Open (on 402) | Auto-trigger | None | Modal shown |
| Select package | Package option | None | Selection updated |
| Submit payment | Pay button | `POST /payments/checkout` | Stripe checkout |
| Close | Close button | None | Modal closed |

### 10.6 Notification Handler (WebSocket)
**Component:** `src/components/common/NotificationHandler.tsx`

| Event | Trigger | API Call | Expected Outcome |
|-------|---------|----------|------------------|
| Connect | Page load | WebSocket connect | Connection established |
| Scan complete | Server push | None | Toast notification |
| New vulnerability | Server push | None | Toast notification |
| Quota warning | Server push | None | Banner shown |

---

## API Endpoint Summary

### Authentication
- `POST /auth/login` - Email/password login
- `POST /auth/register` - User registration
- `POST /auth/wallet/verify` - Wallet authentication
- `POST /auth/solana/verify` - Solana wallet auth

### Contracts
- `GET /contracts` - List contracts
- `GET /contracts/{id}` - Get contract
- `POST /contracts` - Create contract
- `POST /upload` - Upload contract file
- `PATCH /contracts/{id}` - Update contract
- `DELETE /contracts/{id}` - Delete contract
- `GET /contracts/check-name` - Check name availability

### Scans
- `GET /scans` - List scans
- `GET /scans/{id}` - Get scan
- `POST /scans` - Create scan
- `GET /scans/{id}/export` - Export report
- `DELETE /scans/{id}` - Delete scan
- `GET /scans/compare` - Compare scans
- `POST /scans/batch` - Create batch scan
- `GET /scans/batch` - List batch scans

### Vulnerabilities
- `GET /vulnerabilities` - List vulnerabilities
- `GET /vulnerabilities/{id}` - Get vulnerability
- `PATCH /vulnerabilities/{id}` - Update status
- `GET /vulnerabilities/export` - Export vulns

### Intelligence
- `GET /deduplication/groups` - List groups
- `GET /deduplication/groups/{id}` - Get group
- `POST /deduplication/groups/merge` - Merge groups
- `GET /patterns` - List patterns
- `GET /patterns/{id}` - Get pattern

### Admin
- `GET /api-keys` - List API keys
- `POST /api-keys` - Create key
- `PATCH /api-keys/{id}` - Update key
- `DELETE /api-keys/{id}` - Revoke key
- `GET /webhooks` - List webhooks
- `POST /webhooks` - Create webhook
- `GET /audit-logs` - List audit logs
- `GET /organizations` - List organizations
- `GET /teams` - List teams

### Billing
- `GET /billing/subscription` - Get subscription
- `POST /billing/checkout` - Create checkout
- `POST /billing/portal` - Get portal URL
- `GET /payments/credits` - Get balance
- `GET /payments/packages` - List packages

### Analytics
- `GET /statistics/dashboard` - Dashboard stats
- `GET /statistics/scan-history` - Scan history
- `GET /analytics/summary` - Analytics summary
- `GET /analytics/scanner-comparison` - Scanner comparison
- `GET /analytics/scanner-effectiveness` - Effectiveness data

---

## Testing Checklist

Use this document as a testing guide:

- [ ] All 37 pages load without errors
- [ ] All authentication methods work
- [ ] All CRUD operations function correctly
- [ ] All filters and search work
- [ ] All exports download valid files
- [ ] All modals open and close properly
- [ ] All navigation works
- [ ] WebSocket notifications received
- [ ] Payment flows complete
- [ ] Error states display correctly
- [ ] Loading states show appropriately
- [ ] Mobile responsive design works

---

**Document Maintenance:**
- Update when new pages or features are added
- Update when API endpoints change
- Review quarterly for accuracy
