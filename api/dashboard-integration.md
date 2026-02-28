# Dashboard API Integration

**Last Updated**: 2025-12-23
**Product Name**: Apogee Dashboard

## Overview

The Apogee Dashboard is fully integrated with the FastAPI backend, providing real-time security analysis data through a modern React-based interface.

## Architecture

### Technology Stack

**Frontend**:
- React 18.2.0
- TypeScript 5.2.2
- Vite 5.0.0 (build tool)
- React Query (TanStack Query) 5.8.4 - Data fetching and caching
- Axios 1.6.2 - HTTP client
- Recharts 2.8.0 - Data visualization
- Tailwind CSS 3.3.6 - Styling

**Backend**:
- FastAPI (Python)
- PostgreSQL (database)
- JWT authentication
- RESTful API endpoints

### Data Flow

```
User Browser
    ↓
React Components (DashboardLive.tsx)
    ↓
React Query Hooks (useDashboardData.ts)
    ↓
API Client Layer (lib/api/*.ts)
    ↓
Axios HTTP Client (with interceptors)
    ↓
FastAPI Backend (localhost:8001/api/v1)
    ↓
PostgreSQL Database
```

### Complete Scan Integration Flow ✅ **Verified October 14, 2025**

The complete end-to-end scan integration is now fully operational:

```
Apogee Dashboard
    ↓ (Create Contract)
API Service: POST /api/v1/contracts
    ↓
Database: Contract stored
    ↓ (Trigger Scan)
API Service: POST /api/v1/scans
    ↓ (HTTP Request)
Tool Integration: POST /scans/trigger
    ↓ (Kubernetes Job Creation)
Slither Scanner: Static Analysis (~35 seconds)
    ↓ (Results)
Tool Integration: Receive scan results
    ↓ (HTTP Request)
API Service: POST /scans/{id}/results
    ↓ (Store Vulnerabilities)
Database: Vulnerabilities & scan stats persisted ✅
    ↓ (Query Results)
Dashboard: GET /api/v1/scans/{id}/vulnerabilities
    ↓
User: View vulnerability details
```

**Key Fix** (v0.3.12): Resolved VulnerabilityModel schema bug that was preventing vulnerability storage. See [API-SCHEMA-FIX-2025-10-14.md](/Users/pwner/Git/ABS/docs/API-SCHEMA-FIX-2025-10-14.md) for details.

**Verified Scan**: ID `f66377d9-8833-4018-9831-7733d01bb4cd` successfully completed with critical reentrancy vulnerability stored in database.

## API Client Layer

### Type-Safe API Clients

All API interactions are handled through dedicated TypeScript client modules:

#### 1. Contracts API (`lib/api/contracts.ts`)

```typescript
// List contracts with pagination
await contractsApi.listContracts({
  skip: 0,
  limit: 10,
  network: 'ethereum',
  status: 'pending'
});

// Get specific contract
await contractsApi.getContract(contractId);

// Create new contract
await contractsApi.createContract({
  name: 'MyToken',
  address: '0x123...',
  network: 'ethereum',
  source_code: '...'
});
```

**Endpoints**:
- `GET /api/v1/contracts` - List contracts
- `GET /api/v1/contracts/{id}` - Get contract details
- `POST /api/v1/contracts` - Create contract
- `PATCH /api/v1/contracts/{id}` - Update contract
- `DELETE /api/v1/contracts/{id}` - Delete contract

#### 2. Scans API (`lib/api/scans.ts`)

```typescript
// List scans
await scansApi.listScans({
  skip: 0,
  limit: 10,
  status: 'completed'
});

// Create new scan
await scansApi.createScan({
  contract_id: contractId,
  scan_type: 'full'
});
```

**Endpoints**:
- `GET /api/v1/scans` - List scans
- `GET /api/v1/scans/{id}` - Get scan details
- `POST /api/v1/scans` - Create scan

#### 3. Vulnerabilities API (`lib/api/vulnerabilities.ts`)

```typescript
// List all vulnerabilities
await vulnerabilitiesApi.listVulnerabilities({
  severity: 'critical',
  status: 'open'
});

// Get vulnerabilities for a contract
await vulnerabilitiesApi.listVulnerabilitiesByContract(contractId);

// Update vulnerability status
await vulnerabilitiesApi.updateVulnerabilityStatus(vulnId, {
  status: 'fixed'
});
```

**Endpoints**:
- `GET /api/v1/vulnerabilities` - List vulnerabilities
- `GET /api/v1/vulnerabilities/{id}` - Get vulnerability details
- `GET /api/v1/vulnerabilities/contracts/{id}/vulnerabilities` - Get by contract
- `PATCH /api/v1/vulnerabilities/{id}/status` - Update status

#### 4. Statistics API (`lib/api/statistics.ts`)

```typescript
// Get dashboard statistics
await statisticsApi.getDashboardStatistics();
// Returns: { total_scans, total_vulnerabilities, contracts_scanned, average_risk_score }

// Get 30-day scan history
await statisticsApi.getScanHistory();
// Returns: { history: [{ date, scans, vulnerabilities }] }
```

**Endpoints**:
- `GET /api/v1/statistics/dashboard` - Dashboard stats
- `GET /api/v1/statistics/scan-history` - Historical data

#### 5. Users API (`lib/api/users.ts`)

```typescript
// Get current user profile
await usersApi.getCurrentUser();

// Update profile
await usersApi.updateCurrentUser({
  email: 'new@example.com'
});
```

**Endpoints**:
- `GET /api/v1/users/me` - Get user profile
- `PATCH /api/v1/users/me` - Update profile

#### 6. Analytics API (`lib/api/analytics.ts`) ✨ **NEW** (October 2025)

```typescript
// Get tool effectiveness metrics (last 30 days)
await analyticsApi.getToolEffectiveness(30);

// Get vulnerability trends over time
await analyticsApi.getVulnerabilityTrends(30);

// Get cross-project health comparison
await analyticsApi.getProjectComparison();

// Get combined analytics summary (efficient single request)
await analyticsApi.getAnalyticsSummary();
```

**Endpoints**:
- `GET /api/v1/analytics/tools` - Tool effectiveness metrics
- `GET /api/v1/analytics/trends` - Vulnerability trends over time
- `GET /api/v1/analytics/projects` - Cross-project health comparison
- `GET /api/v1/analytics/summary` - Combined analytics summary

**Features**:
- **Tool Effectiveness**: Identifies which scanner tools find the most vulnerabilities
- **Vulnerability Trends**: Tracks new vs resolved vulnerabilities over time (1-365 days)
- **Project Health Scores**: Calculates project health (0-100 scale) based on vulnerability severity
- **Health Formula**: `100 - (critical×10 + high×5 + medium×2 + low×0.5)`
- **User-Scoped Data**: All analytics respect user isolation (multi-tenancy)
- **Configurable Time Ranges**: 7, 14, 30, 90, 180, 365 days

#### 7. API Keys API (`lib/api/apiKeys.ts`) ✨ **NEW** (December 2025)

```typescript
// List all API keys
await apiKeysApi.listApiKeys();

// Create new API key
await apiKeysApi.createApiKey({
  name: 'CI/CD Integration',
  scopes: ['scans:read', 'scans:write', 'contracts:read'],
  expires_at: '2025-06-01T00:00:00Z'
});

// Revoke API key
await apiKeysApi.revokeApiKey(keyId);

// Regenerate API key secret
await apiKeysApi.regenerateApiKey(keyId);

// Get API key usage statistics
await apiKeysApi.getApiKeyUsage(keyId);
```

**Endpoints**:
- `GET /api/v1/api-keys` - List all API keys
- `POST /api/v1/api-keys` - Create new API key (returns secret once)
- `GET /api/v1/api-keys/{id}` - Get API key details
- `PATCH /api/v1/api-keys/{id}` - Update API key
- `DELETE /api/v1/api-keys/{id}` - Revoke API key
- `POST /api/v1/api-keys/{id}/regenerate` - Regenerate secret
- `GET /api/v1/api-keys/{id}/usage` - Get usage statistics

**Scopes**:
- `scans:read` - View scans
- `scans:write` - Create/manage scans
- `contracts:read` - View contracts
- `contracts:write` - Create/manage contracts
- `vulnerabilities:read` - View vulnerabilities
- `vulnerabilities:write` - Update vulnerability status

**Tier Requirement**: Pro+ (tier-gated in frontend)

#### 8. Webhooks API (`lib/api/webhooks.ts`) ✨ **NEW** (December 2025)

```typescript
// List all webhooks
await webhooksApi.listWebhooks();

// Create webhook
await webhooksApi.createWebhook({
  url: 'https://api.example.com/webhooks/blocksecops',
  events: ['scan.completed', 'vulnerability.found'],
  secret: 'optional-hmac-secret'
});

// Test webhook delivery
await webhooksApi.testWebhook(webhookId);

// Get delivery history
await webhooksApi.getWebhookDeliveries(webhookId);
```

**Endpoints**:
- `GET /api/v1/webhooks` - List webhooks
- `POST /api/v1/webhooks` - Create webhook
- `GET /api/v1/webhooks/{id}` - Get webhook details
- `PATCH /api/v1/webhooks/{id}` - Update webhook
- `DELETE /api/v1/webhooks/{id}` - Delete webhook
- `POST /api/v1/webhooks/{id}/test` - Send test delivery
- `GET /api/v1/webhooks/{id}/deliveries` - Get delivery history

**Events**:
- `scan.started` - Scan has been initiated
- `scan.completed` - Scan finished successfully
- `scan.failed` - Scan encountered an error
- `vulnerability.found` - New vulnerability detected
- `vulnerability.resolved` - Vulnerability marked as resolved

**Tier Requirement**: Pro+

#### 9. Audit Logs API (`lib/api/auditLogs.ts`) ✨ **NEW** (December 2025)

```typescript
// List audit logs with filters
await auditLogsApi.listAuditLogs({
  action: 'scan.create',
  user_id: 'uuid',
  start_date: '2025-12-01',
  end_date: '2025-12-23',
  skip: 0,
  limit: 50
});

// Get audit log summary
await auditLogsApi.getAuditLogSummary();

// Export audit logs to CSV
await auditLogsApi.exportAuditLogs({
  format: 'csv',
  start_date: '2025-12-01',
  end_date: '2025-12-23'
});
```

**Endpoints**:
- `GET /api/v1/audit-logs` - List audit logs with filtering
- `GET /api/v1/audit-logs/{id}` - Get audit log details
- `GET /api/v1/audit-logs/summary` - Get summary statistics
- `GET /api/v1/audit-logs/export/csv` - Export to CSV
- `GET /api/v1/audit-logs/export/json` - Export to JSON

**Action Categories**:
- `auth.*` - Authentication events (login, logout, password change)
- `scan.*` - Scan operations (create, delete, complete)
- `contract.*` - Contract operations
- `vulnerability.*` - Vulnerability status changes
- `api_key.*` - API key management
- `webhook.*` - Webhook configuration
- `organization.*` - Organization changes
- `user.*` - User profile updates

**Tier Requirement**: Enterprise

#### 10. Organizations API (`lib/api/organizations.ts`) ✨ **NEW** (December 2025)

```typescript
// List organizations
await organizationsApi.listOrganizations();

// Create organization
await organizationsApi.createOrganization({
  name: 'Acme Corp',
  slug: 'acme-corp'
});

// Manage members
await organizationsApi.addMember(orgId, {
  user_id: 'user-uuid',
  role_id: 'role-uuid'
});

// Manage roles
await organizationsApi.createRole(orgId, {
  name: 'Security Analyst',
  permissions: ['scans:read', 'vulnerabilities:read', 'vulnerabilities:write']
});
```

**Organization Endpoints**:
- `GET /api/v1/organizations` - List user's organizations
- `POST /api/v1/organizations` - Create organization
- `GET /api/v1/organizations/{id}` - Get organization details
- `PATCH /api/v1/organizations/{id}` - Update organization
- `DELETE /api/v1/organizations/{id}` - Delete organization

**Member Endpoints**:
- `GET /api/v1/organizations/{id}/members` - List members
- `POST /api/v1/organizations/{id}/members` - Add member
- `PATCH /api/v1/organizations/{id}/members/{member_id}` - Update member role
- `DELETE /api/v1/organizations/{id}/members/{member_id}` - Remove member

**Role Endpoints**:
- `GET /api/v1/organizations/{id}/roles` - List roles
- `POST /api/v1/organizations/{id}/roles` - Create custom role
- `PATCH /api/v1/organizations/{id}/roles/{role_id}` - Update role
- `DELETE /api/v1/organizations/{id}/roles/{role_id}` - Delete role

**Default Roles**:
- `owner` - Full access, can delete organization
- `admin` - Full access except delete organization
- `member` - Read/write for scans and contracts
- `viewer` - Read-only access
- `analyst` - Read + vulnerability status updates

**Tier Requirement**: Enterprise

## React Query Integration

### Data Fetching Hooks

All data fetching uses React Query hooks for automatic caching, background updates, and error handling.

#### Dashboard Statistics Hook

```typescript
import { useDashboardStatistics } from '../hooks/useDashboardData';

function DashboardComponent() {
  const {
    data: stats,
    isLoading,
    error
  } = useDashboardStatistics();

  if (isLoading) return <Loading />;
  if (error) return <Error message={error.message} />;

  return <div>Total Scans: {stats.total_scans}</div>;
}
```

**Features**:
- Auto-refresh every 30 seconds
- Caches data for 5 minutes
- Automatic retry on failure
- Loading and error states

#### Available Hooks

```typescript
// Dashboard statistics (30s refresh)
const { data } = useDashboardStatistics();

// 30-day scan history (60s refresh)
const { data } = useScanHistory();

// Recent contracts (30s refresh)
const { data } = useRecentContracts(limit);

// Recent vulnerabilities (30s refresh)
const { data } = useRecentVulnerabilities(limit);

// ✨ NEW: Analytics hooks (60s auto-refresh)
const { data } = useAnalyticsSummary();  // Combined analytics
const { data } = useToolEffectiveness(days);  // Tool metrics
const { data } = useVulnerabilityTrends(days);  // Trends over time
const { data } = useProjectComparison();  // Project health scores

// ✨ NEW: Enterprise hooks (December 2025)
const { data } = useApiKeys();  // List API keys
const { mutate } = useCreateApiKey();  // Create API key
const { mutate } = useRevokeApiKey();  // Revoke API key

const { data } = useWebhooks();  // List webhooks
const { mutate } = useCreateWebhook();  // Create webhook
const { mutate } = useTestWebhook();  // Test webhook delivery

const { data } = useAuditLogs(filters);  // List audit logs
const { data } = useAuditLogSummary();  // Get summary
const { mutate } = useExportAuditLogs();  // Export to CSV/JSON

const { data } = useOrganizations();  // List organizations
const { data } = useOrganization(orgId);  // Get organization details
const { data } = useOrganizationMembers(orgId);  // List members
const { data } = useOrganizationRoles(orgId);  // List roles
```

## Authentication

### JWT Token Management

The dashboard uses JWT bearer tokens for authentication:

```typescript
// Login
const response = await authApi.login({
  email: 'user@example.com',
  password: 'password'
});

// Tokens automatically stored in localStorage
localStorage.setItem('access_token', response.access_token);
localStorage.setItem('refresh_token', response.refresh_token);
```

### Automatic Token Refresh

Axios interceptors automatically handle token refresh:

```typescript
// On 401 response, attempt token refresh
if (error.response?.status === 401) {
  const refreshToken = localStorage.getItem('refresh_token');
  const response = await axios.post('/auth/refresh', { refreshToken });

  // Save new tokens
  localStorage.setItem('access_token', response.access_token);

  // Retry original request
  return apiClient(originalRequest);
}
```

## Dashboard Components

### Live Dashboard (`DashboardLive.tsx`)

The main dashboard component displays real-time data:

**Statistics Cards**:
- Total Scans
- Contracts Scanned
- Vulnerabilities Found
- Average Risk Score

**Visualizations**:
1. **Scan History Chart** (Line Chart)
   - 30-day trend of scans and vulnerabilities
   - Data from `/api/v1/statistics/scan-history`

2. **Severity Distribution** (Pie Chart)
   - Breakdown by severity (Critical/High/Medium/Low)
   - Calculated from real vulnerability data

3. **Top Vulnerability Categories** (Bar Chart)
   - Most common vulnerability types
   - Grouped by category field

**Data Tables**:
- Recent Contracts table with network, lines of code, status
- Clickable rows for future detail pages

**API Status Indicator**:
- Green pulse: API Connected
- Red: API Disconnected
- Shows service version when connected

### Analytics Dashboard (`DashboardAnalytics.tsx`) ✨ **NEW** (October 2025)

Comprehensive analytics dashboard with 4 major visualization components:

**Component 1: Summary Statistics Widgets** (6 widgets)
1. **Total Scans** - Blue icon with total scan count
2. **Critical Issues** - Red shield icon showing critical vulnerabilities
3. **Total Vulnerabilities** - Orange icon with total count
4. **Average Per Day** - Purple icon with daily average
5. **Projects Analyzed** - Green icon with project count
6. **Total Tools Used** - Indigo icon with tool count

**Component 2: Tool Effectiveness Chart**
- **Visualization**: Horizontal stacked bar chart (Recharts)
- **Data**: Shows vulnerabilities found per scanner tool
- **Color Coding**: Critical (red), High (orange), Medium (yellow), Low (lime)
- **Features**: Custom tooltip, summary statistics, responsive design
- **Sorting**: Sorted by total vulnerabilities (most effective first)

**Component 3: Vulnerability Trend Chart**
- **Visualization**: Dual-mode chart (stacked area / line chart)
- **Toggle**: Switch between cumulative view and individual severity trends
- **Data**: Daily vulnerability counts by severity over time
- **Summary Panel**: Shows total new, total resolved, net change, average per day
- **Date Formatting**: Human-readable (MMM DD format)

**Component 4: Project Health Cards**
- **Visualization**: Sortable card grid (1-3 columns responsive)
- **Data**: Project health scores, vulnerability breakdowns, scan counts
- **Health Indicator**: Color-coded health score with label
  - 80-100: Green (Excellent)
  - 60-79: Blue (Good)
  - 40-59: Yellow (Fair)
  - 20-39: Orange (Poor)
  - 0-19: Red (Critical)
- **Sorting Options**: Health score, total vulnerabilities, project name, last scan date
- **Metrics**: Contracts, scans, vulnerabilities, avg per contract, last scan timestamp

**Dashboard Features**:
- **Time Range Selector**: 7, 14, 30, 90, 180, 365 days
- **Auto-Refresh**: Every 60 seconds using React Query
- **Loading States**: Skeleton loaders for each component
- **Error Handling**: User-friendly error messages with retry
- **Responsive Design**: Mobile, tablet, desktop optimized
- **Empty States**: Helpful messages when no data available

**URL**: `/analytics` (accessible from main navigation)

## Error Handling

### Loading States

```typescript
if (isLoading) {
  return (
    <div className="flex items-center justify-center">
      <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600" />
      <p>Loading dashboard data...</p>
    </div>
  );
}
```

### Error States

```typescript
if (error) {
  return (
    <div className="bg-red-50 border-l-4 border-red-400 p-4">
      <h3>Failed to load dashboard data</h3>
      <p>{error.message}</p>
      <p>Make sure the API service is running and you are authenticated.</p>
    </div>
  );
}
```

### Network Error Recovery

- Automatic retry on network failures
- Exponential backoff
- User-friendly error messages
- Fallback to cached data when available

## Performance Optimization

### React Query Caching

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,  // 5 minutes
      cacheTime: 10 * 60 * 1000,  // 10 minutes
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});
```

### Code Splitting

The dashboard uses dynamic imports for route-based code splitting:

```typescript
const Dashboard = lazy(() => import('./pages/DashboardLive'));
```

### Bundle Size

- Production build: 662.93 kB
- Gzipped: 192.45 kB
- Build time: ~23 seconds

## Development Workflow

### Local Development

1. Start the API service:
```bash
kubectl port-forward -n api-service-local svc/api-service 8001:8000
```

2. Start the dashboard:
```bash
cd /Users/pwner/Git/ABS/blocksecops-dashboard
npm run dev
```

3. Set authentication token:
   - Open `file:///tmp/set-dashboard-auth.html`
   - Click "Set Authentication Token"
   - Navigate to `http://localhost:5173`

### Testing

```bash
# Run tests
npm test

# Type checking
npm run type-check

# Linting
npm run lint

# Build for production
npm run build
```

## API Testing

Comprehensive test scripts available:

```bash
# Test all endpoints
/tmp/test-api.sh

# Test vulnerabilities
/tmp/test-vulnerabilities.sh

# Test file upload
/tmp/test-upload.sh

# Test scan history
/tmp/test-scan-history.sh
```

**Results**: 14/14 endpoints passing (100% success rate)

## Deployment

### Production Build

```bash
npm run build
```

Output:
```
dist/index.html                   0.47 kB
dist/assets/index-zj84KrDI.css   13.90 kB (gzipped: 3.44 kB)
dist/assets/index-CWRXzC_4.js   662.93 kB (gzipped: 192.45 kB)
```

### Environment Variables

```bash
# .env.production
VITE_API_BASE_URL=https://api.soliditysecurity.com
```

### Docker Deployment

```dockerfile
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html
EXPOSE 80
```

## Security Considerations

### Token Security

- Access tokens stored in localStorage
- Automatic token refresh before expiry
- Tokens cleared on logout
- HTTPS required in production

### API Security

- JWT bearer token authentication
- Automatic 401 handling
- CORS configured for specific origins
- Rate limiting on API endpoints

### XSS Protection

- All user input sanitized
- React's built-in XSS protection
- Content Security Policy headers

## Troubleshooting

### Common Issues

**Dashboard shows "API Disconnected"**:
- Check API service is running: `kubectl get pods -n api-service-local`
- Check port forward: `lsof -i :8001`
- Verify network connectivity

**Authentication fails**:
- Check token expiry
- Verify credentials in Vault
- Check API logs: `kubectl logs -n api-service-local deployment/api-service`

**Data not updating**:
- Check browser console for errors
- Verify React Query cache settings
- Force refresh: Clear localStorage and reload

## Future Enhancements

### Recently Added ✅ (October 2025)

1. **Analytics Dashboard** ✅ **COMPLETE**
   - Tool effectiveness comparison (horizontal bar charts)
   - Vulnerability trends visualization (area/line charts)
   - Project health scoring (color-coded cards)
   - Summary statistics widgets
   - Configurable time ranges (7-365 days)
   - Auto-refresh every 60 seconds

### Planned Features

1. **Transaction Hash Support**
   - Scan contracts by transaction hash
   - Auto-populate contract details from blockchain
   - Blockchain explorer integration

2. **Advanced Search & Filtering** (Days 5-6)
   - Multi-select filters (project, language, tool, severity)
   - Saved searches
   - Export to CSV/JSON
   - Bulk actions (re-scan, mark as fixed)

3. **Real-Time Updates**
   - WebSocket support for live scan updates
   - Push notifications for new vulnerabilities
   - Live progress indicators

4. **Additional Pages**
   - Contracts list with search/filter
   - Vulnerability details page
   - Scan management page
   - File upload UI component

## Resources

**Documentation**:
- API Test Results: `/tmp/api-test-results-summary.md`
- Integration Summary: `/tmp/dashboard-integration-summary.md`
- Auth Helper: `/tmp/set-dashboard-auth.html`

**Code Repositories**:
- Dashboard: `https://github.com/AdvancedBlockchainSecurity/blocksecops-dashboard`
- API Service: `https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service`

**Pull Requests**:
- Dashboard Integration: [#5](https://github.com/AdvancedBlockchainSecurity/blocksecops-dashboard/pull/5) ✅ Merged

## Support

For issues or questions:
1. Check API health: `GET /api/v1/health/live`
2. Review browser console logs
3. Check API logs: `kubectl logs -n api-service-local deployment/api-service`
4. Refer to test scripts in `/tmp/` for working examples
