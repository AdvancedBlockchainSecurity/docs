# Enterprise Features Frontend

**Last Updated**: 2026-01-13
**Dashboard Version**: 0.30.1
**Status**: Production Ready

---

## Overview

The Apogee Dashboard v0.13.0 includes full frontend implementation for Phase 4.5 enterprise features. These features provide enterprise-grade management capabilities with tier-based access control.

## Feature Summary

| Feature | Route | Tier | Status |
|---------|-------|------|--------|
| API Keys | `/api-keys` | Pro+ | ✅ Complete |
| Webhooks | `/webhooks` | Pro+ | ✅ Complete |
| Audit Logs | `/audit-logs` | Enterprise | ✅ Complete |
| Organizations | `/organizations` | Enterprise | ✅ Complete |

---

## Tier Gating System

### TierGate Component

Location: `src/components/common/TierGate.tsx`

The `TierGate` component enforces tier-based access to enterprise features.

```tsx
import { TierGate } from '@/components/common/TierGate';

// Usage
<TierGate requiredTier="pro" featureName="API Keys">
  <ApiKeysPage />
</TierGate>
```

**Props**:
| Prop | Type | Description |
|------|------|-------------|
| `requiredTier` | `'free' \| 'developer' \| 'startup' \| 'professional' \| 'enterprise'` | Minimum tier required |
| `featureName` | `string` | Feature name for upgrade prompt |
| `children` | `ReactNode` | Content to render if authorized |
| `mode` | `'block' \| 'preview'` | Display mode (default: 'block') |
| `showUpgradePrompt` | `boolean` | Show upgrade prompt when blocked |

**Behavior**:
- Checks `user.tier` from `AuthContext`
- Tier hierarchy: `free` < `developer` < `startup` < `professional` < `enterprise`
- Shows upgrade prompt with pricing link for insufficient tier
- Renders children for authorized users

### TierGate Display Modes (v0.30.0)

**Block Mode** (default):
- Completely hides content for unauthorized users
- Shows upgrade prompt instead of content
- Use for fully restricted features

```tsx
<TierGate requiredTier="enterprise" featureName="SSO">
  <SSOConfiguration />
</TierGate>
```

**Preview Mode** (new in v0.30.0):
- Shows content with visual "greyed out" overlay
- Displays upgrade badge on top of content
- Allows users to see what they're missing
- Creates upsell opportunity

```tsx
<TierGate requiredTier="developer" featureName="Quality Gates" mode="preview">
  <QualityGatePanel projectId={projectId} />
</TierGate>
```

**Preview Mode Styling**:
- Greyed overlay with 50% opacity
- Purple "Upgrade to {tier}" badge positioned top-right
- Badge links to /pricing page
- Content is visible but not interactive
- Hover effects disabled on greyed content

---

## UpgradeBanner Component (v0.30.1)

Location: `src/components/common/UpgradeBanner.tsx`

Global dismissible banner that promotes tier upgrades across the application.

### Usage

```tsx
// In App.tsx (global placement)
{isAuthenticated && <UpgradeBanner />}

// With custom configuration
<UpgradeBanner
  reappearAfterDays={14}
  targetTier="professional"
  highlightFeature="Unlimited Scans"
/>
```

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `storageKey` | `string` | `'upgrade-banner-dismissed'` | localStorage key for dismissal state |
| `reappearAfterDays` | `number` | `7` | Days before banner reappears after dismissal |
| `targetTier` | `Tier` | auto | Target tier to promote (auto: next tier up) |
| `message` | `string` | auto | Custom message text |
| `highlightFeature` | `string` | - | Single feature to highlight |

### Behavior

1. **Automatic Tier Detection**: Shows next tier up from user's current tier
2. **Feature Highlights**: Displays up to 3 key features of the target tier
3. **Dismissible**: User can dismiss with X button
4. **Reappearance**: Returns after configurable days (default: 7)
5. **Enterprise Hidden**: Never shows for Enterprise tier users

### Tier-Specific Highlights

| Current Tier | Target Tier | Highlighted Features |
|--------------|-------------|---------------------|
| Free | Developer | Quality Gates, CI/CD Integration, Priority Support |
| Developer | Startup | Team Collaboration, 100 AI Explanations/month, Advanced Analytics |
| Startup | Professional | 500 AI Explanations/month, Custom Integrations, Dedicated Support |
| Professional | Enterprise | Unlimited AI, SSO/SAML, Custom SLAs, Project Access Control |

### Hook: useUpgradeBanner

```tsx
import { useUpgradeBanner } from '@/components/common/UpgradeBanner';

const { resetBanner, dismissBanner, isDismissed } = useUpgradeBanner();

// Force banner to show again
resetBanner();

// Programmatically dismiss
dismissBanner();

// Check current state
if (isDismissed()) { /* ... */ }
```

---

### Sidebar Integration

The ADMIN section in the sidebar uses tier gating:

```tsx
// Sidebar.tsx
const ADMIN_ITEMS = [
  { name: 'API Keys', href: '/api-keys', icon: KeyIcon, requiredTier: 'pro' },
  { name: 'Webhooks', href: '/webhooks', icon: BellIcon, requiredTier: 'pro' },
  { name: 'Audit Logs', href: '/audit-logs', icon: DocumentIcon, requiredTier: 'enterprise' },
  { name: 'Organizations', href: '/organizations', icon: BuildingIcon, requiredTier: 'enterprise' },
];

// Items only rendered if user.tier >= requiredTier
```

---

## API Keys Management

### Page Location
`src/pages/ApiKeys.tsx`

### Components
- `ApiKeyTable.tsx` - List and manage API keys
- `CreateApiKeyModal.tsx` - Create new API key
- `ApiKeySecretDisplay.tsx` - One-time secret display

### Features

**List View**:
- Table with name, scopes, created date, last used, status
- Search and filter functionality
- Revoke action with confirmation dialog

**Create Modal**:
- Name input (required)
- Scope selection (multi-select checkboxes)
- Optional expiration date picker
- Secret displayed once after creation (copy button)

**Security**:
- Secret only shown once after creation
- Copy-to-clipboard with visual feedback
- Masked display after initial view

### API Integration

```typescript
// useApiKeys.ts
export const API_KEY_QUERY_KEYS = {
  all: ['api-keys'] as const,
  lists: () => [...API_KEY_QUERY_KEYS.all, 'list'] as const,
  detail: (id: string) => [...API_KEY_QUERY_KEYS.all, 'detail', id] as const,
};

export const useApiKeys = () =>
  useQuery({
    queryKey: API_KEY_QUERY_KEYS.lists(),
    queryFn: apiKeysApi.listApiKeys,
  });

export const useCreateApiKey = () =>
  useMutation({
    mutationFn: apiKeysApi.createApiKey,
    onSuccess: () => queryClient.invalidateQueries(API_KEY_QUERY_KEYS.lists()),
  });
```

### Available Scopes

| Scope | Description |
|-------|-------------|
| `scans:read` | View scan results |
| `scans:write` | Create and manage scans |
| `contracts:read` | View contracts |
| `contracts:write` | Create and manage contracts |
| `vulnerabilities:read` | View vulnerabilities |
| `vulnerabilities:write` | Update vulnerability status |

---

## Webhooks Management

### Page Location
`src/pages/Webhooks.tsx`

### Components
- `WebhookTable.tsx` - List webhooks with status indicators
- `CreateWebhookModal.tsx` - Configure new webhook
- `WebhookDeliveryHistory.tsx` - View delivery attempts

### Features

**List View**:
- URL, events subscribed, status (active/inactive)
- Last delivery status indicator (success/failure)
- Toggle active/inactive
- Test and delete actions

**Create/Edit Modal**:
- URL input (required, validated)
- Event selection (multi-select)
- Optional HMAC secret input
- Active/inactive toggle

**Delivery History**:
- Timestamp, response status, duration
- Request/response body preview
- Retry action for failed deliveries

### Webhook Events

| Event | Description |
|-------|-------------|
| `scan.started` | Scan initiated |
| `scan.completed` | Scan finished successfully |
| `scan.failed` | Scan encountered error |
| `vulnerability.found` | New vulnerability detected |
| `vulnerability.resolved` | Vulnerability marked resolved |

### HMAC Verification

Webhooks support HMAC-SHA256 signature verification:

```typescript
// Signature header: X-Apogee-Signature
const signature = createHmac('sha256', secret)
  .update(JSON.stringify(payload))
  .digest('hex');
```

---

## Audit Logs

### Page Location
`src/pages/AuditLogs.tsx`

### Components
- `AuditLogTable.tsx` - Paginated log display
- `AuditLogFilters.tsx` - Advanced filtering
- `ExportAuditLogs.tsx` - CSV/JSON export

### Features

**List View**:
- Timestamp, action, user, resource, IP address
- Expandable row for full details
- Infinite scroll pagination

**Filtering**:
- Date range picker
- Action category filter
- User filter (autocomplete)
- Search by resource ID

**Export**:
- Export to CSV or JSON
- Apply current filters to export
- Download via browser

### Action Categories

| Category | Actions |
|----------|---------|
| `auth` | login, logout, password_change, mfa_enable |
| `scan` | create, delete, complete, fail |
| `contract` | create, update, delete |
| `vulnerability` | status_change, assign |
| `api_key` | create, revoke, regenerate |
| `webhook` | create, update, delete, test |
| `organization` | create, update, delete, member_add, member_remove |
| `user` | profile_update, settings_change |

### Data Retention

- Default: 90 days
- Enterprise: Configurable up to 365 days
- Export recommended for compliance archival

---

## Organizations & RBAC

### Page Location
`src/pages/Organizations.tsx`

### Components
- `CreateOrganizationModal.tsx` - Create organization
- `MembersList.tsx` - Manage organization members
- `AddMemberModal.tsx` - Invite or add members
- `RolesList.tsx` - View and create custom roles

### Features

**Organization Management**:
- Create new organization with name and slug
- Edit organization details
- Delete organization (owner only)
- View organization statistics

**Member Management**:
- List members with roles
- Add member by email (with invitation)
- Change member role
- Remove member from organization

**Role Management**:
- View default roles with permissions
- Create custom roles (admin only)
- Edit custom role permissions
- Delete custom roles

### Default Roles

| Role | Permissions |
|------|-------------|
| **Owner** | Full access, can delete organization |
| **Admin** | Full access except org deletion |
| **Member** | Read/write scans and contracts |
| **Viewer** | Read-only access |
| **Analyst** | Read + vulnerability management |

### Permission Matrix

| Permission | Owner | Admin | Member | Viewer | Analyst |
|------------|-------|-------|--------|--------|---------|
| View scans | ✅ | ✅ | ✅ | ✅ | ✅ |
| Create scans | ✅ | ✅ | ✅ | ❌ | ❌ |
| View contracts | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manage contracts | ✅ | ✅ | ✅ | ❌ | ❌ |
| Update vulnerabilities | ✅ | ✅ | ✅ | ❌ | ✅ |
| Manage members | ✅ | ✅ | ❌ | ❌ | ❌ |
| Manage roles | ✅ | ✅ | ❌ | ❌ | ❌ |
| Billing access | ✅ | ✅ | ❌ | ❌ | ❌ |
| Delete organization | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## Shared Patterns

### Modal Pattern

All enterprise modals follow the same pattern:

```tsx
// Using Headless UI Dialog
import { Dialog } from '@headlessui/react';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
}

function CreateModal({ isOpen, onClose, onSuccess }: ModalProps) {
  const form = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  const mutation = useCreateMutation();

  const onSubmit = async (data: FormData) => {
    await mutation.mutateAsync(data);
    onSuccess?.();
    onClose();
  };

  return (
    <Dialog open={isOpen} onClose={onClose}>
      <Dialog.Panel>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          {/* Form fields */}
          <div className="flex justify-end gap-2">
            <button type="button" onClick={onClose}>Cancel</button>
            <button type="submit">Create</button>
          </div>
        </form>
      </Dialog.Panel>
    </Dialog>
  );
}
```

### Table Pattern

```tsx
// Reusable table structure
<table className="min-w-full divide-y divide-gray-200">
  <thead className="bg-gray-50">
    <tr>
      <th>Column</th>
    </tr>
  </thead>
  <tbody className="bg-white divide-y divide-gray-200">
    {items.map((item) => (
      <tr key={item.id}>
        <td>{item.value}</td>
      </tr>
    ))}
  </tbody>
</table>
```

### Error Handling

```tsx
// Consistent error display
{error && (
  <div className="bg-red-50 border-l-4 border-red-400 p-4">
    <p className="text-red-700">{getErrorMessage(error)}</p>
  </div>
)}
```

---

## Testing Checklist

### API Keys
- [ ] List API keys displays correctly
- [ ] Create API key modal opens/closes
- [ ] Secret displays once after creation
- [ ] Copy button works
- [ ] Revoke confirmation dialog works
- [ ] Revoked keys show disabled state

### Webhooks
- [ ] List webhooks with status indicators
- [ ] Create webhook with validation
- [ ] Edit existing webhook
- [ ] Test delivery sends request
- [ ] Delivery history shows responses
- [ ] Toggle active/inactive

### Audit Logs
- [ ] Logs load with pagination
- [ ] Date range filter works
- [ ] Action filter works
- [ ] Export to CSV downloads file
- [ ] Export to JSON downloads file
- [ ] Search by resource ID

### Organizations
- [ ] List user's organizations
- [ ] Create organization with slug
- [ ] View organization members
- [ ] Add member by email
- [ ] Change member role
- [ ] Remove member
- [ ] View available roles

### Tier Gating
- [ ] Free user cannot access API Keys
- [ ] Free user cannot access Webhooks
- [ ] Pro user can access API Keys
- [ ] Pro user can access Webhooks
- [ ] Pro user cannot access Audit Logs
- [ ] Pro user cannot access Organizations
- [ ] Enterprise user can access all features

---

## Troubleshooting

### "Upgrade Required" message
- Verify user tier in database: `SELECT tier FROM users WHERE id = ?`
- Check AuthContext is providing correct user data
- Ensure login token is fresh (re-login if needed)

### API calls failing
- Check API service is running: `kubectl get pods -n api-service-local`
- Verify port forward active: `lsof -i :8001`
- Check browser console for CORS errors

### Modals not closing
- Ensure mutation completes before closing
- Check for unhandled promise rejections
- Verify form validation passes

---

## Related Documentation

- [Dashboard Integration](./dashboard-integration.md) - API integration details
- [Authentication Frontend](./authentication-frontend.md) - Auth context
- [PHASE-4.5-OVERVIEW.md](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/phases/04-phase-4.5-enterprise-features/PHASE-4.5-OVERVIEW.md) - Phase overview
