# Sprint 5: Frontend Development & Integration

**Duration**: Weeks 9-10 (2 weeks)
**Status**: Planning
**Technical Milestone**: Complete React-based user interface with real-time updates

---

## Overview

Sprint 5 transforms the backend security analysis platform into a complete user-facing application by building a modern React-based frontend. This sprint focuses on creating an intuitive user interface for contract upload, real-time analysis tracking, findings management, and comprehensive dashboard visualization.

### Key Objectives

1. **UI Core Components**: Build reusable component library with Tailwind CSS
2. **Dashboard Application**: Create metrics visualization with real-time updates
3. **Findings Management**: Implement comprehensive findings table with filtering
4. **Analysis Workflow**: Build contract upload and analysis tracking interface
5. **Real-Time Updates**: Integrate WebSocket for live status updates
6. **Platform Integration**: Deploy all frontend services to staging via ArgoCD

---

## Technical Milestone

**Deliverable**: Production-ready frontend application with complete user workflow from contract upload to results visualization

**Success Criteria**:
- UI component library operational
- Dashboard displaying real-time metrics
- Findings table with advanced filtering and sorting
- Contract upload workflow functional
- WebSocket integration providing live updates
- All frontend services deployed to staging
- End-to-end user workflow tested
- All acceptance criteria met

---

## Epic 1: UI Core Component Library

### Epic Goal
Create a comprehensive, reusable component library that serves as the foundation for all frontend applications.

### Tasks

#### Task 5.1: UI Core Project Setup

**Story**: As a frontend developer, I need a well-structured component library project so that I can build reusable UI components efficiently.

**Acceptance Criteria**:
- [ ] Vite + React + TypeScript project initialized
- [ ] Tailwind CSS configured with custom theme
- [ ] Storybook setup for component documentation
- [ ] ESLint and Prettier configured
- [ ] Component library build pipeline
- [ ] Package.json configured for npm publishing
- [ ] README with setup instructions

**Tech Stack**:
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "tailwindcss": "^3.4.0",
    "clsx": "^2.1.0",
    "lucide-react": "^0.300.0"
  },
  "devDependencies": {
    "@storybook/react": "^7.6.0",
    "vite": "^5.0.0",
    "typescript": "^5.3.0"
  }
}
```

**Estimated Time**: 6 hours

**Dependencies**: None

---

#### Task 5.2: Design System & Theming

**Story**: As a designer, I need a consistent design system so that all UI components follow the same visual language.

**Acceptance Criteria**:
- [ ] Color palette defined (primary, secondary, success, error, warning)
- [ ] Typography scale configured
- [ ] Spacing system defined
- [ ] Border radius and shadow utilities
- [ ] Dark mode support
- [ ] Design tokens documented
- [ ] Tailwind theme configuration complete

**Design System Configuration**:
```typescript
// tailwind.config.js
export default {
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f9ff',
          500: '#3b82f6',
          900: '#1e3a8a',
        },
        danger: {
          50: '#fef2f2',
          500: '#ef4444',
          900: '#7f1d1d',
        },
        success: {
          500: '#10b981',
        },
        warning: {
          500: '#f59e0b',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['Fira Code', 'monospace'],
      }
    }
  }
}
```

**Estimated Time**: 6 hours

**Dependencies**: Task 5.1

---

#### Task 5.3: Base UI Components

**Story**: As a developer, I need foundational UI components so that I can compose complex interfaces.

**Acceptance Criteria**:
- [ ] Button component (variants, sizes, states)
- [ ] Input component (text, password, search)
- [ ] Select/Dropdown component
- [ ] Card component
- [ ] Badge component
- [ ] Spinner/Loading component
- [ ] All components have Storybook stories
- [ ] Accessibility (ARIA labels, keyboard nav)
- [ ] Unit tests with React Testing Library

**Button Component Example**:
```typescript
// src/components/Button/Button.tsx
interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  disabled?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
}

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'md',
  loading,
  disabled,
  children,
  onClick
}) => {
  return (
    <button
      className={clsx(
        'btn',
        `btn-${variant}`,
        `btn-${size}`,
        loading && 'btn-loading',
        disabled && 'btn-disabled'
      )}
      onClick={onClick}
      disabled={disabled || loading}
    >
      {loading && <Spinner />}
      {children}
    </button>
  );
};
```

**Estimated Time**: 12 hours

**Dependencies**: Task 5.2

---

#### Task 5.4: Layout Components

**Story**: As a developer, I need layout components so that I can structure pages consistently.

**Acceptance Criteria**:
- [ ] Container component (max-width, padding)
- [ ] Grid component (responsive columns)
- [ ] Stack component (vertical/horizontal spacing)
- [ ] Sidebar layout component
- [ ] Header/Navbar component
- [ ] Footer component
- [ ] Responsive breakpoints working
- [ ] Storybook stories for all layouts

**Layout Components**:
```typescript
// src/components/Layout/AppLayout.tsx
interface AppLayoutProps {
  sidebar: React.ReactNode;
  header: React.ReactNode;
  children: React.ReactNode;
}

export const AppLayout: React.FC<AppLayoutProps> = ({
  sidebar,
  header,
  children
}) => {
  return (
    <div className="flex h-screen">
      <aside className="w-64 bg-gray-900">{sidebar}</aside>
      <div className="flex-1 flex flex-col">
        <header className="h-16 border-b">{header}</header>
        <main className="flex-1 overflow-auto p-6">{children}</main>
      </div>
    </div>
  );
};
```

**Estimated Time**: 10 hours

**Dependencies**: Task 5.3

---

#### Task 5.5: Authentication Components

**Story**: As a user, I need authentication screens so that I can log in and access the platform.

**Acceptance Criteria**:
- [ ] Login form component
- [ ] Registration form component
- [ ] Password reset form
- [ ] Form validation with react-hook-form
- [ ] Error message display
- [ ] Loading states during auth
- [ ] Responsive design
- [ ] Accessibility compliant

**Login Form Implementation**:
```typescript
// src/components/Auth/LoginForm.tsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

export const LoginForm: React.FC = () => {
  const { register, handleSubmit, formState: { errors } } = useForm({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (data) => {
    // Handle login
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Input
        label="Email"
        error={errors.email?.message}
        {...register('email')}
      />
      <Input
        type="password"
        label="Password"
        error={errors.password?.message}
        {...register('password')}
      />
      <Button type="submit">Sign In</Button>
    </form>
  );
};
```

**Estimated Time**: 10 hours

**Dependencies**: Task 5.3

---

#### Task 5.6: Data Table Component

**Story**: As a developer, I need a powerful table component so that I can display large datasets with sorting, filtering, and pagination.

**Acceptance Criteria**:
- [ ] TanStack Table integration
- [ ] Sorting (single and multi-column)
- [ ] Filtering (text, select, range)
- [ ] Pagination controls
- [ ] Row selection
- [ ] Column visibility toggle
- [ ] Responsive design (stacked on mobile)
- [ ] Performance optimization for large datasets

**Table Implementation**:
```typescript
// src/components/DataTable/DataTable.tsx
import { useReactTable, getCoreRowModel } from '@tanstack/react-table';

interface DataTableProps<T> {
  data: T[];
  columns: ColumnDef<T>[];
  pagination?: boolean;
  sorting?: boolean;
  filtering?: boolean;
}

export function DataTable<T>({
  data,
  columns,
  pagination,
  sorting,
  filtering
}: DataTableProps<T>) {
  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    // ... additional features
  });

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full divide-y divide-gray-200">
        {/* Table implementation */}
      </table>
    </div>
  );
}
```

**Estimated Time**: 12 hours

**Dependencies**: Task 5.3

---

#### Task 5.7: UI Core Library Deployment

**Story**: As a platform, I need the UI core library published so that other frontend applications can use it.

**Acceptance Criteria**:
- [ ] Library built and bundled
- [ ] Published to npm registry (or internal registry)
- [ ] Storybook deployed for documentation
- [ ] Component API documentation complete
- [ ] Usage examples provided
- [ ] Version 0.1.0 released

**Estimated Time**: 6 hours

**Dependencies**: All previous UI core tasks

---

## Epic 2: Dashboard Application

### Epic Goal
Build main dashboard application with metrics visualization and real-time updates.

### Tasks

#### Task 5.8: Dashboard Project Setup & Routing

**Story**: As a developer, I need a dashboard application structure so that I can build out features systematically.

**Acceptance Criteria**:
- [ ] Vite + React + TypeScript project initialized
- [ ] React Router configured
- [ ] UI Core library imported
- [ ] Authentication routing (protected routes)
- [ ] Layout structure implemented
- [ ] Navigation sidebar created
- [ ] 404 page created

**Router Configuration**:
```typescript
// src/App.tsx
import { BrowserRouter, Routes, Route } from 'react-router-dom';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<ProtectedRoute />}>
          <Route path="/" element={<DashboardPage />} />
          <Route path="/analyses" element={<AnalysesPage />} />
          <Route path="/findings" element={<FindingsPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Route>
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </BrowserRouter>
  );
}
```

**Estimated Time**: 8 hours

**Dependencies**: Task 5.7 (UI Core library)

---

#### Task 5.9: API Client & Data Fetching

**Story**: As a frontend developer, I need an API client so that I can fetch data from backend services efficiently.

**Acceptance Criteria**:
- [ ] Axios configured with base URL
- [ ] Request/response interceptors for auth
- [ ] TanStack Query setup for data fetching
- [ ] Automatic token refresh logic
- [ ] Error handling utilities
- [ ] Loading states managed
- [ ] Cache configuration optimized

**API Client Implementation**:
```typescript
// src/lib/api-client.ts
import axios from 'axios';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  withCredentials: true,
});

// Request interceptor for auth token
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor for token refresh
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      // Attempt token refresh
      const refreshed = await refreshToken();
      if (refreshed) {
        return apiClient.request(error.config);
      }
    }
    return Promise.reject(error);
  }
);
```

**TanStack Query Setup**:
```typescript
// src/hooks/useAnalyses.ts
import { useQuery } from '@tanstack/react-query';

export function useAnalyses() {
  return useQuery({
    queryKey: ['analyses'],
    queryFn: () => apiClient.get('/api/v1/analyses').then(res => res.data),
    refetchInterval: 30000, // Refetch every 30s
  });
}
```

**Estimated Time**: 10 hours

**Dependencies**: Task 5.8

---

#### Task 5.10: WebSocket Integration for Real-Time Updates

**Story**: As a user, I want real-time updates on my analyses so that I don't need to refresh the page.

**Acceptance Criteria**:
- [ ] WebSocket client implemented
- [ ] Connection management (connect, disconnect, reconnect)
- [ ] Authentication over WebSocket
- [ ] Event handlers for analysis updates
- [ ] React context for WebSocket state
- [ ] Automatic reconnection on disconnect
- [ ] Integration with TanStack Query cache

**WebSocket Implementation**:
```typescript
// src/lib/websocket.ts
export class WebSocketClient {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;

  connect(token: string) {
    const wsUrl = `${import.meta.env.VITE_WS_URL}?token=${token}`;
    this.ws = new WebSocket(wsUrl);

    this.ws.onopen = () => {
      console.log('WebSocket connected');
      this.reconnectAttempts = 0;
    };

    this.ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      this.handleMessage(message);
    };

    this.ws.onclose = () => {
      this.handleReconnect();
    };
  }

  private handleMessage(message: any) {
    if (message.type === 'analysis.status_update') {
      // Update TanStack Query cache
      queryClient.setQueryData(['analyses', message.analysis_id], message.data);
    }
  }
}
```

**React Context**:
```typescript
// src/contexts/WebSocketContext.tsx
export const WebSocketProvider: React.FC = ({ children }) => {
  const [client] = useState(() => new WebSocketClient());

  useEffect(() => {
    const token = getAccessToken();
    if (token) {
      client.connect(token);
    }
    return () => client.disconnect();
  }, []);

  return (
    <WebSocketContext.Provider value={{ client }}>
      {children}
    </WebSocketContext.Provider>
  );
};
```

**Estimated Time**: 12 hours

**Dependencies**: Task 5.9, Sprint 3 Notification Service

---

#### Task 5.11: Dashboard Overview Page

**Story**: As a user, I want a dashboard overview so that I can quickly see key metrics and recent activity.

**Acceptance Criteria**:
- [ ] Summary statistics cards (total analyses, findings, contracts)
- [ ] Recent analyses list
- [ ] Severity distribution chart (pie/donut)
- [ ] Analyses over time chart (line/area)
- [ ] Top vulnerability types chart (bar)
- [ ] Real-time updates via WebSocket
- [ ] Responsive design

**Dashboard Components**:
```typescript
// src/pages/DashboardPage.tsx
export const DashboardPage: React.FC = () => {
  const { data: stats } = useStats();
  const { data: recentAnalyses } = useRecentAnalyses();

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">Dashboard</h1>

      <div className="grid grid-cols-4 gap-4">
        <StatCard title="Total Analyses" value={stats.totalAnalyses} />
        <StatCard title="Findings" value={stats.totalFindings} />
        <StatCard title="Contracts" value={stats.totalContracts} />
        <StatCard title="Critical Issues" value={stats.criticalFindings} />
      </div>

      <div className="grid grid-cols-2 gap-6">
        <Card>
          <CardHeader>Analyses Over Time</CardHeader>
          <AnalysesTimeChart data={stats.timeSeriesData} />
        </Card>

        <Card>
          <CardHeader>Severity Distribution</CardHeader>
          <SeverityPieChart data={stats.severityDistribution} />
        </Card>
      </div>

      <Card>
        <CardHeader>Recent Analyses</CardHeader>
        <RecentAnalysesList analyses={recentAnalyses} />
      </Card>
    </div>
  );
};
```

**Estimated Time**: 12 hours

**Dependencies**: Task 5.10

---

#### Task 5.12: Charts & Visualizations (Recharts)

**Story**: As a user, I want visual charts so that I can understand security metrics at a glance.

**Acceptance Criteria**:
- [ ] Recharts library integrated
- [ ] Line chart for time series data
- [ ] Pie/Donut chart for distributions
- [ ] Bar chart for comparisons
- [ ] Chart components reusable
- [ ] Tooltips with detailed info
- [ ] Responsive and mobile-friendly
- [ ] Color-coded by severity

**Chart Components**:
```typescript
// src/components/Charts/SeverityPieChart.tsx
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts';

const SEVERITY_COLORS = {
  critical: '#dc2626',
  high: '#f59e0b',
  medium: '#3b82f6',
  low: '#10b981',
  info: '#6b7280',
};

export const SeverityPieChart: React.FC<{ data: SeverityData[] }> = ({ data }) => {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <PieChart>
        <Pie
          data={data}
          dataKey="count"
          nameKey="severity"
          cx="50%"
          cy="50%"
          innerRadius={60}
          outerRadius={90}
        >
          {data.map((entry) => (
            <Cell key={entry.severity} fill={SEVERITY_COLORS[entry.severity]} />
          ))}
        </Pie>
        <Tooltip />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  );
};
```

**Estimated Time**: 10 hours

**Dependencies**: Task 5.11

---

#### Task 5.13: Dashboard Application Deployment

**Story**: As a DevOps engineer, I need to deploy the dashboard application so that users can access it in staging.

**Acceptance Criteria**:
- [ ] Production build optimized
- [ ] Nginx Docker image for serving
- [ ] Kubernetes manifests created
- [ ] Environment variables configured
- [ ] Deployed via ArgoCD
- [ ] Service accessible via AWS ALB
- [ ] SSL/TLS configured
- [ ] Health check endpoint

**Nginx Configuration**:
```nginx
# nginx.conf
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://api-service:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /ws {
        proxy_pass http://notification-service:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

**Estimated Time**: 8 hours

**Dependencies**: Task 5.12

---

## Epic 3: Findings Management Application

### Epic Goal
Build comprehensive findings management interface with advanced filtering and bulk operations.

### Tasks

#### Task 5.14: Findings Table Implementation

**Story**: As a security analyst, I want to see all findings in a table so that I can review and manage them efficiently.

**Acceptance Criteria**:
- [ ] Findings table with all key columns
- [ ] Severity badge with color coding
- [ ] Status indicator (open, acknowledged, fixed)
- [ ] Tool source display
- [ ] Location information (file, line)
- [ ] Click to expand finding details
- [ ] Pagination (25, 50, 100 per page)
- [ ] Loading and error states

**Findings Table Columns**:
```typescript
// src/components/Findings/FindingsTable.tsx
const columns: ColumnDef<Finding>[] = [
  {
    accessorKey: 'severity',
    header: 'Severity',
    cell: ({ row }) => <SeverityBadge severity={row.original.severity} />,
  },
  {
    accessorKey: 'title',
    header: 'Title',
    cell: ({ row }) => (
      <button onClick={() => openDetails(row.original)}>
        {row.original.title}
      </button>
    ),
  },
  {
    accessorKey: 'tool',
    header: 'Tool',
  },
  {
    accessorKey: 'location',
    header: 'Location',
    cell: ({ row }) => `${row.original.file}:${row.original.line}`,
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => <StatusBadge status={row.original.status} />,
  },
];
```

**Estimated Time**: 12 hours

**Dependencies**: Task 5.6 (DataTable component)

---

#### Task 5.15: Advanced Filtering System

**Story**: As a user, I want to filter findings by multiple criteria so that I can focus on relevant issues.

**Acceptance Criteria**:
- [ ] Severity filter (multi-select)
- [ ] Status filter (multi-select)
- [ ] Tool filter (multi-select)
- [ ] Contract filter (select)
- [ ] Search by keyword
- [ ] Date range filter
- [ ] Filter state persisted in URL
- [ ] Clear all filters button

**Filter Implementation**:
```typescript
// src/components/Findings/FindingsFilters.tsx
export const FindingsFilters: React.FC = () => {
  const [filters, setFilters] = useSearchParams();

  return (
    <div className="flex gap-4 flex-wrap">
      <MultiSelect
        label="Severity"
        options={['critical', 'high', 'medium', 'low', 'info']}
        value={filters.getAll('severity')}
        onChange={(values) => setFilters({ severity: values })}
      />

      <MultiSelect
        label="Status"
        options={['open', 'acknowledged', 'fixed', 'false_positive']}
        value={filters.getAll('status')}
        onChange={(values) => setFilters({ status: values })}
      />

      <Select
        label="Tool"
        options={['slither', 'aderyn', 'mythril']}
        value={filters.get('tool')}
        onChange={(value) => setFilters({ tool: value })}
      />

      <Input
        type="search"
        placeholder="Search findings..."
        value={filters.get('search') || ''}
        onChange={(e) => setFilters({ search: e.target.value })}
      />
    </div>
  );
};
```

**Estimated Time**: 10 hours

**Dependencies**: Task 5.14

---

#### Task 5.16: Sorting & Column Management

**Story**: As a user, I want to sort findings and customize visible columns so that I can organize data my way.

**Acceptance Criteria**:
- [ ] Click column header to sort
- [ ] Multi-column sorting support
- [ ] Sort direction indicator (arrows)
- [ ] Column visibility toggle
- [ ] Column reordering (drag and drop)
- [ ] Column width resizing
- [ ] Preferences saved to localStorage

**Sorting Implementation**:
```typescript
// src/hooks/useFindings.ts
export function useFindings(filters: FindingsFilters) {
  const [sorting, setSorting] = useState<SortingState>([]);

  return useQuery({
    queryKey: ['findings', filters, sorting],
    queryFn: async () => {
      const params = new URLSearchParams({
        ...filters,
        sort: sorting.map(s => `${s.id}:${s.desc ? 'desc' : 'asc'}`).join(','),
      });
      return apiClient.get(`/api/v1/findings?${params}`);
    },
  });
}
```

**Estimated Time**: 8 hours

**Dependencies**: Task 5.15

---

#### Task 5.17: Finding Detail Modal

**Story**: As a security analyst, I want detailed information about a finding so that I can understand and remediate it.

**Acceptance Criteria**:
- [ ] Modal dialog with full finding details
- [ ] Code snippet with syntax highlighting
- [ ] Line numbers and context
- [ ] Remediation guidance
- [ ] References and documentation links
- [ ] Status change buttons
- [ ] Comment/note section
- [ ] Similar findings section

**Detail Modal Implementation**:
```typescript
// src/components/Findings/FindingDetailModal.tsx
export const FindingDetailModal: React.FC<{ finding: Finding }> = ({ finding }) => {
  return (
    <Modal size="xl">
      <ModalHeader>
        <div className="flex items-center gap-3">
          <SeverityBadge severity={finding.severity} />
          <h2>{finding.title}</h2>
        </div>
      </ModalHeader>

      <ModalBody>
        <div className="space-y-6">
          <Section title="Description">
            <p>{finding.description}</p>
          </Section>

          <Section title="Location">
            <CodeBlock
              code={finding.code_snippet}
              language="solidity"
              lineNumbers
              highlightLines={[finding.line]}
            />
          </Section>

          <Section title="Remediation">
            <p>{finding.remediation}</p>
          </Section>

          <Section title="References">
            <ul>
              {finding.references.map(ref => (
                <li key={ref.url}>
                  <a href={ref.url} target="_blank">{ref.title}</a>
                </li>
              ))}
            </ul>
          </Section>
        </div>
      </ModalBody>

      <ModalFooter>
        <Button onClick={() => updateStatus('acknowledged')}>
          Acknowledge
        </Button>
        <Button variant="success" onClick={() => updateStatus('fixed')}>
          Mark Fixed
        </Button>
      </ModalFooter>
    </Modal>
  );
};
```

**Estimated Time**: 10 hours

**Dependencies**: Task 5.14

---

#### Task 5.18: Bulk Operations

**Story**: As a user, I want to perform bulk actions on findings so that I can manage many findings efficiently.

**Acceptance Criteria**:
- [ ] Row selection checkboxes
- [ ] Select all / deselect all
- [ ] Bulk status change
- [ ] Bulk export (CSV, JSON)
- [ ] Bulk delete
- [ ] Confirmation dialogs for destructive actions
- [ ] Success/error notifications
- [ ] Selection count indicator

**Bulk Operations Implementation**:
```typescript
// src/components/Findings/BulkActions.tsx
export const BulkActions: React.FC<{ selectedIds: string[] }> = ({ selectedIds }) => {
  const updateStatusMutation = useMutation({
    mutationFn: (status: FindingStatus) =>
      apiClient.post('/api/v1/findings/bulk-update', {
        finding_ids: selectedIds,
        status,
      }),
    onSuccess: () => {
      toast.success(`Updated ${selectedIds.length} findings`);
      queryClient.invalidateQueries(['findings']);
    },
  });

  return (
    <div className="flex gap-2">
      <span>{selectedIds.length} selected</span>
      <Button onClick={() => updateStatusMutation.mutate('acknowledged')}>
        Acknowledge Selected
      </Button>
      <Button variant="success" onClick={() => updateStatusMutation.mutate('fixed')}>
        Mark Fixed
      </Button>
      <Button variant="danger" onClick={() => confirmDelete()}>
        Delete Selected
      </Button>
    </div>
  );
};
```

**Estimated Time**: 8 hours

**Dependencies**: Task 5.17

---

#### Task 5.19: Findings Application Deployment

**Story**: As a DevOps engineer, I need to deploy the findings application so that it's accessible in staging.

**Acceptance Criteria**:
- [ ] Production build created
- [ ] Docker image built
- [ ] Kubernetes manifests created
- [ ] Deployed via ArgoCD
- [ ] Service accessible via ALB
- [ ] Performance optimized
- [ ] Monitoring configured

**Estimated Time**: 6 hours

**Dependencies**: Task 5.18

---

## Epic 4: Analysis Workflow Application

### Epic Goal
Build contract upload and analysis tracking interface with real-time progress updates.

### Tasks

#### Task 5.20: Contract Upload Interface

**Story**: As a user, I want to upload contracts for analysis so that I can assess their security.

**Acceptance Criteria**:
- [ ] Drag-and-drop file upload
- [ ] File validation (Solidity files only)
- [ ] Multiple file upload support
- [ ] File size validation
- [ ] Upload progress indicator
- [ ] File preview before submission
- [ ] Remove files before upload
- [ ] Error handling for upload failures

**Upload Component**:
```typescript
// src/components/Analysis/ContractUpload.tsx
export const ContractUpload: React.FC = () => {
  const [files, setFiles] = useState<File[]>([]);
  const uploadMutation = useMutation({
    mutationFn: (formData: FormData) =>
      apiClient.post('/api/v1/contracts/upload', formData),
  });

  const handleDrop = (acceptedFiles: File[]) => {
    const validFiles = acceptedFiles.filter(f => f.name.endsWith('.sol'));
    setFiles([...files, ...validFiles]);
  };

  return (
    <Dropzone
      onDrop={handleDrop}
      accept={{ 'text/x-solidity': ['.sol'] }}
      multiple
    >
      <div className="border-2 border-dashed p-8 text-center">
        <UploadIcon className="mx-auto h-12 w-12" />
        <p>Drag & drop Solidity files here</p>
        <p className="text-sm text-gray-500">or click to browse</p>
      </div>
    </Dropzone>
  );
};
```

**Estimated Time**: 10 hours

**Dependencies**: Task 5.7 (UI Core)

---

#### Task 5.21: URL-Based Contract Import

**Story**: As a user, I want to analyze contracts by providing a blockchain explorer URL so that I don't need to manually download source code.

**Acceptance Criteria**:
- [ ] URL input field with validation
- [ ] Network selection dropdown
- [ ] Address extraction and validation
- [ ] Source code preview after fetch
- [ ] Loading state during fetch
- [ ] Error handling for invalid URLs
- [ ] Integration with backend URL scanning endpoint

**URL Import Component**:
```typescript
// src/components/Analysis/URLImport.tsx
export const URLImport: React.FC = () => {
  const [url, setUrl] = useState('');
  const [network, setNetwork] = useState('ethereum');

  const fetchMutation = useMutation({
    mutationFn: () =>
      apiClient.post('/api/v1/contracts/from-url', { url, network }),
    onSuccess: (data) => {
      navigate(`/analyses/${data.analysis_id}`);
    },
  });

  return (
    <Card>
      <CardHeader>Import from Blockchain Explorer</CardHeader>
      <CardBody>
        <Input
          label="Explorer URL"
          placeholder="https://etherscan.io/address/0x..."
          value={url}
          onChange={(e) => setUrl(e.target.value)}
        />
        <Select
          label="Network"
          options={SUPPORTED_NETWORKS}
          value={network}
          onChange={setNetwork}
        />
        <Button onClick={() => fetchMutation.mutate()}>
          Import & Analyze
        </Button>
      </CardBody>
    </Card>
  );
};
```

**Estimated Time**: 8 hours

**Dependencies**: Task 5.20, Sprint 4 URL scanning endpoint

---

#### Task 5.22: Analysis Configuration

**Story**: As a user, I want to configure analysis options so that I can customize the security scan.

**Acceptance Criteria**:
- [ ] Tool selection (multi-select: Slither, Aderyn, Mythril)
- [ ] Priority selection (high, normal, low)
- [ ] Notification preferences
- [ ] Analysis name/description
- [ ] Form validation with react-hook-form
- [ ] Default settings from user preferences
- [ ] Save configuration as template

**Configuration Form**:
```typescript
// src/components/Analysis/AnalysisConfig.tsx
export const AnalysisConfig: React.FC = () => {
  const { register, handleSubmit } = useForm({
    defaultValues: {
      tools: ['slither', 'aderyn', 'mythril'],
      priority: 'normal',
      notify_on_completion: true,
    },
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <MultiSelect
        label="Security Tools"
        options={AVAILABLE_TOOLS}
        {...register('tools')}
      />

      <Select
        label="Priority"
        options={['high', 'normal', 'low']}
        {...register('priority')}
      />

      <Checkbox
        label="Notify me when analysis completes"
        {...register('notify_on_completion')}
      />

      <Button type="submit">Start Analysis</Button>
    </form>
  );
};
```

**Estimated Time**: 8 hours

**Dependencies**: Task 5.21

---

#### Task 5.23: Real-Time Analysis Progress Tracking

**Story**: As a user, I want to see real-time progress of my analysis so that I know what's happening.

**Acceptance Criteria**:
- [ ] Progress bar showing overall completion
- [ ] Per-tool status indicators
- [ ] Live log stream
- [ ] Estimated time remaining
- [ ] Tool execution order visualization
- [ ] WebSocket integration for updates
- [ ] Ability to cancel analysis
- [ ] Error display if analysis fails

**Progress Tracker**:
```typescript
// src/components/Analysis/AnalysisProgress.tsx
export const AnalysisProgress: React.FC<{ analysisId: string }> = ({ analysisId }) => {
  const { data: status } = useAnalysisStatus(analysisId);

  return (
    <Card>
      <CardHeader>Analysis Progress</CardHeader>
      <CardBody>
        <ProgressBar value={status.progress_percentage} />

        <div className="mt-4 space-y-3">
          {status.tools.map(tool => (
            <div key={tool.name} className="flex items-center gap-3">
              <ToolIcon name={tool.name} />
              <span>{tool.name}</span>
              <StatusBadge status={tool.status} />
              {tool.status === 'running' && <Spinner size="sm" />}
            </div>
          ))}
        </div>

        {status.estimated_completion && (
          <p className="mt-4 text-sm text-gray-500">
            Estimated completion: {formatDuration(status.estimated_completion)}
          </p>
        )}
      </CardBody>
    </Card>
  );
};

// Custom hook with WebSocket updates
function useAnalysisStatus(analysisId: string) {
  const { client } = useWebSocket();

  return useQuery({
    queryKey: ['analysis', analysisId, 'status'],
    queryFn: () => apiClient.get(`/api/v1/analyses/${analysisId}/status`),
    // WebSocket updates will invalidate this query
  });
}
```

**Estimated Time**: 12 hours

**Dependencies**: Task 5.10 (WebSocket), Task 5.22

---

#### Task 5.24: Analysis Results Display

**Story**: As a user, I want to see analysis results in a clear format so that I can review findings.

**Acceptance Criteria**:
- [ ] Results summary card (total findings, by severity)
- [ ] Findings list with severity badges
- [ ] Filter results by tool
- [ ] Export results (PDF, CSV, JSON)
- [ ] Share analysis link
- [ ] Download raw results
- [ ] View contract source with highlighted issues

**Results Display**:
```typescript
// src/components/Analysis/AnalysisResults.tsx
export const AnalysisResults: React.FC<{ analysisId: string }> = ({ analysisId }) => {
  const { data: analysis } = useAnalysis(analysisId);

  return (
    <div className="space-y-6">
      <ResultsSummary
        totalFindings={analysis.findings_count}
        bySeverity={analysis.severity_distribution}
      />

      <Card>
        <CardHeader>
          <div className="flex justify-between">
            <h3>Findings</h3>
            <div className="flex gap-2">
              <Button onClick={() => exportPDF()}>Export PDF</Button>
              <Button onClick={() => exportCSV()}>Export CSV</Button>
            </div>
          </div>
        </CardHeader>
        <CardBody>
          <FindingsList findings={analysis.findings} />
        </CardBody>
      </Card>

      <Card>
        <CardHeader>Contract Source</CardHeader>
        <CardBody>
          <CodeViewer
            code={analysis.contract.source_code}
            language="solidity"
            highlightedLines={getHighlightedLines(analysis.findings)}
          />
        </CardBody>
      </Card>
    </div>
  );
};
```

**Estimated Time**: 10 hours

**Dependencies**: Task 5.23

---

#### Task 5.25: Analysis History

**Story**: As a user, I want to see my past analyses so that I can track security over time.

**Acceptance Criteria**:
- [ ] Analysis history table
- [ ] Sorting by date, status, severity
- [ ] Filtering by contract, date range
- [ ] Search by contract name
- [ ] Click to view analysis details
- [ ] Delete old analyses
- [ ] Pagination for large history

**Estimated Time**: 8 hours

**Dependencies**: Task 5.24

---

#### Task 5.26: Analysis Application Deployment

**Story**: As a DevOps engineer, I need to deploy the analysis application so that users can upload and track analyses.

**Acceptance Criteria**:
- [ ] Production build optimized
- [ ] Docker image created
- [ ] Kubernetes manifests created
- [ ] Deployed via ArgoCD
- [ ] Service accessible via ALB
- [ ] File upload size limits configured
- [ ] Performance metrics tracked

**Estimated Time**: 6 hours

**Dependencies**: Task 5.25

---

## Sprint Backlog

### Week 1: UI Core & Dashboard Foundation

**Day 1**: UI Core Setup
- Task 5.1: UI Core project setup (6h)
- Task 5.2: Design system (6h)
- Task 5.3: Base UI components (12h, started)

**Day 2**: UI Components
- Task 5.3: Base UI components (completed)
- Task 5.4: Layout components (10h)
- Task 5.5: Auth components (10h, started)

**Day 3**: Components & Data Table
- Task 5.5: Auth components (completed)
- Task 5.6: Data table component (12h)

**Day 4**: Dashboard Foundation
- Task 5.7: UI Core deployment (6h)
- Task 5.8: Dashboard setup & routing (8h)
- Task 5.9: API client setup (10h, started)

**Day 5**: Dashboard Features
- Task 5.9: API client (completed)
- Task 5.10: WebSocket integration (12h)
- Task 5.11: Dashboard overview page (12h, started)

### Week 2: Findings & Analysis Applications

**Day 6**: Dashboard Completion
- Task 5.11: Dashboard overview (completed)
- Task 5.12: Charts & visualizations (10h)
- Task 5.13: Dashboard deployment (8h)

**Day 7**: Findings Application
- Task 5.14: Findings table (12h)
- Task 5.15: Advanced filtering (10h)

**Day 8**: Findings Features
- Task 5.16: Sorting & column management (8h)
- Task 5.17: Finding detail modal (10h)
- Task 5.18: Bulk operations (8h, started)

**Day 9**: Analysis Application
- Task 5.18: Bulk operations (completed)
- Task 5.19: Findings deployment (6h)
- Task 5.20: Contract upload interface (10h)
- Task 5.21: URL-based import (8h, started)

**Day 10**: Analysis Completion & Deployment
- Task 5.21: URL import (completed)
- Task 5.22: Analysis configuration (8h)
- Task 5.23: Real-time progress tracking (12h)
- Task 5.24: Analysis results display (10h, started)
- Task 5.25: Analysis history (8h)
- Task 5.26: Analysis deployment (6h)

---

## Acceptance Criteria

### UI Core Library
- [ ] Component library published and usable
- [ ] 20+ reusable components created
- [ ] Storybook documentation deployed
- [ ] Dark mode support working
- [ ] Accessibility standards met (WCAG 2.1 AA)

### Dashboard Application
- [ ] Dashboard displaying real-time metrics
- [ ] Charts visualizing security data
- [ ] WebSocket updates working without page refresh
- [ ] Responsive design on mobile and desktop
- [ ] API integration functional

### Findings Management
- [ ] Findings table with all features (sorting, filtering, pagination)
- [ ] Advanced filtering by multiple criteria
- [ ] Finding detail modal with complete information
- [ ] Bulk operations working reliably
- [ ] Export functionality (CSV, JSON)

### Analysis Workflow
- [ ] Contract upload via drag-and-drop working
- [ ] URL-based contract import functional
- [ ] Real-time progress tracking via WebSocket
- [ ] Analysis configuration options working
- [ ] Results display comprehensive and clear
- [ ] Analysis history accessible

### Platform Integration
- [ ] All frontend services deployed to staging
- [ ] End-to-end workflow tested (upload → analyze → results)
- [ ] Authentication flow functional
- [ ] Service discovery working via AWS ALB
- [ ] SSL/TLS configured
- [ ] Monitoring and logging operational

---

## Risks & Mitigation

### Risk 1: WebSocket Stability
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Automatic reconnection logic
- Fallback to polling if WebSocket fails
- Connection status indicator
- Comprehensive error handling
- Load testing WebSocket under scale

### Risk 2: Performance with Large Datasets
**Impact**: Medium
**Probability**: High
**Mitigation**:
- Virtual scrolling for large tables
- Server-side pagination
- Debounced search/filters
- Lazy loading of components
- Code splitting for faster loads

### Risk 3: Browser Compatibility
**Impact**: Medium
**Probability**: Low
**Mitigation**:
- Modern browser targeting (last 2 versions)
- Polyfills for essential features
- Comprehensive browser testing
- Progressive enhancement strategy
- Clear browser requirements documented

### Risk 4: State Management Complexity
**Impact**: Medium
**Probability**: Medium
**Mitigation**:
- TanStack Query for server state
- React Context for global UI state
- Clear separation of concerns
- Comprehensive testing of state updates
- Documentation of state management patterns

### Risk 5: Real-Time Update Race Conditions
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Optimistic updates with rollback
- Conflict resolution strategies
- Event sequencing via timestamps
- Cache invalidation strategies
- Thorough testing of concurrent updates

---

## Success Metrics

### Performance Metrics
- First contentful paint: <1.5s
- Time to interactive: <3s
- Bundle size: <500KB (gzipped)
- WebSocket latency: <100ms
- Table rendering: <100ms for 1000 rows

### User Experience Metrics
- Task completion rate: >90%
- Error rate: <2%
- User satisfaction: >4/5
- Mobile responsiveness: 100% features
- Accessibility score: >90

### Technical Metrics
- Test coverage: >80%
- Lighthouse score: >90
- Build time: <2 minutes
- Deployment success rate: >95%
- Zero critical accessibility issues

---

## Documentation

### Component Documentation
- Storybook for all UI components
- Component API reference
- Usage examples and patterns
- Accessibility guidelines
- Theming customization guide

### Application Documentation
- User guide for all features
- API integration documentation
- WebSocket event reference
- State management patterns
- Deployment procedures

### Developer Documentation
- Project setup guide
- Development workflow
- Testing strategies
- Code style guide
- Troubleshooting common issues

---

## Dependencies

### External Dependencies
- React 18 with concurrent features
- TanStack Query for data fetching
- TanStack Table for advanced tables
- Recharts for data visualization
- React Hook Form for forms
- Tailwind CSS for styling

### Internal Dependencies
- Sprint 3: Backend API services
- Sprint 3: WebSocket notification service
- Sprint 4: Tool integration endpoints
- Sprint 4: Orchestration status tracking
- Sprint 4: URL scanning endpoints
- Sprint 2: ArgoCD for deployments

### Infrastructure Dependencies
- AWS ALB for ingress
- Nginx for serving static files
- SSL/TLS certificates
- Docker registry for images
- Kubernetes cluster

---

## Post-Sprint Activities

### Sprint Review
- Demo complete user workflow
- Show real-time updates in action
- Present dashboard visualizations
- Demonstrate findings management
- Review performance metrics

### Sprint Retrospective
- Frontend architecture decisions
- WebSocket integration challenges
- Component reusability assessment
- Performance optimization learnings
- Team collaboration effectiveness

### Backlog Grooming for Sprint 6
- Mythril integration requirements
- Multi-language architecture planning
- Advanced analytics features
- Enhanced intelligence engine
- Performance optimization needs

---

**Sprint 5 Team**: Frontend Engineers (3), UI/UX Designer (1), DevOps Engineer (1), QA Engineer (1)
**Sprint Goal**: Deliver production-ready frontend application with complete user workflow
**Definition of Done**: All acceptance criteria met, services deployed to staging, end-to-end tests passing, documentation complete, user workflow validated
