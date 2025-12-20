# Task 2.10: Frontend Service Kustomize Templates

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 4 hours
**Owner**: Frontend/DevOps Team
**Priority**: P1 (High)
**Day**: 9-10

## Objective

Create production-ready Kustomize base configurations and environment-specific overlays for all 4 frontend services, enabling consistent deployment and configuration management across local, staging, and production environments.

## Technical Requirements

### Frontend Services Architecture
```yaml
Frontend Services (4 services):
├── ui-core (Shared React Components)
├── dashboard (Main Dashboard Interface)
├── findings (Finding Management Interface)
└── analysis (Analysis Workflow Interface)
```

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

### Kustomize Structure Template
```yaml
frontend-services/
├── ui-core/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── virtual-service.yaml
│   │   └── service-monitor.yaml
│   └── overlays/
│       ├── local/
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── deployment-patch.yaml
│       │   ├── configmap-patch.yaml
│       │   └── nginx-ingress.yaml
│       ├── staging/
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── deployment-patch.yaml
│       │   ├── configmap-patch.yaml
│       │   ├── hpa.yaml
│       │   └── alb-ingress.yaml
│       └── production/
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           ├── deployment-patch.yaml
│           ├── configmap-patch.yaml
│           ├── hpa.yaml
│           ├── pdb.yaml
│           ├── network-policy.yaml
│           └── alb-ingress.yaml
├── dashboard/
├── findings/
└── analysis/
```

## Deliverables

### Service-Specific Template Configurations

#### 1. UI Core Service (Shared Components)
```yaml
# ui-core/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ui-core
  labels:
    app: ui-core
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ui-core
      version: v1
  template:
    metadata:
      labels:
        app: ui-core
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: ui-core
        image: ui-core:latest
        ports:
        - containerPort: 80
          name: http
        env:
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: ui-core-config
              key: node-env
        - name: API_BASE_URL
          valueFrom:
            configMapKeyRef:
              name: ui-core-config
              key: api-base-url
        - name: STORYBOOK_PORT
          value: "6006"
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: nginx-cache
          mountPath: /var/cache/nginx
        - name: nginx-run
          mountPath: /var/run
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: nginx-cache
        emptyDir: {}
      - name: nginx-run
        emptyDir: {}
```

#### 2. Dashboard Service (Main Interface)
```yaml
# dashboard/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dashboard
  labels:
    app: dashboard
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: dashboard
      version: v1
  template:
    metadata:
      labels:
        app: dashboard
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: dashboard
        image: dashboard:latest
        ports:
        - containerPort: 80
          name: http
        env:
        - name: REACT_APP_API_URL
          valueFrom:
            configMapKeyRef:
              name: dashboard-config
              key: api-url
        - name: REACT_APP_WS_URL
          valueFrom:
            configMapKeyRef:
              name: dashboard-config
              key: websocket-url
        - name: REACT_APP_ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: dashboard-config
              key: environment
        - name: REACT_APP_SENTRY_DSN
          valueFrom:
            configMapKeyRef:
              name: dashboard-config
              key: sentry-dsn
              optional: true
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: nginx-cache
          mountPath: /var/cache/nginx
        - name: nginx-run
          mountPath: /var/run
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: nginx-cache
        emptyDir: {}
      - name: nginx-run
        emptyDir: {}
```

#### 3. Findings Service (Finding Management)
```yaml
# findings/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: findings
  labels:
    app: findings
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: findings
      version: v1
  template:
    metadata:
      labels:
        app: findings
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: findings
        image: findings:latest
        ports:
        - containerPort: 80
          name: http
        env:
        - name: REACT_APP_API_URL
          valueFrom:
            configMapKeyRef:
              name: findings-config
              key: api-url
        - name: REACT_APP_DATA_SERVICE_URL
          valueFrom:
            configMapKeyRef:
              name: findings-config
              key: data-service-url
        - name: REACT_APP_PAGINATION_SIZE
          valueFrom:
            configMapKeyRef:
              name: findings-config
              key: pagination-size
        - name: REACT_APP_EXPORT_FORMATS
          valueFrom:
            configMapKeyRef:
              name: findings-config
              key: export-formats
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 80
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: nginx-cache
          mountPath: /var/cache/nginx
        - name: nginx-run
          mountPath: /var/run
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: nginx-cache
        emptyDir: {}
      - name: nginx-run
        emptyDir: {}
```

#### 4. Analysis Service (Analysis Workflow)
```yaml
# analysis/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: analysis
  labels:
    app: analysis
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: analysis
      version: v1
  template:
    metadata:
      labels:
        app: analysis
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      containers:
      - name: analysis
        image: analysis:latest
        ports:
        - containerPort: 80
          name: http
        env:
        - name: REACT_APP_API_URL
          valueFrom:
            configMapKeyRef:
              name: analysis-config
              key: api-url
        - name: REACT_APP_UPLOAD_MAX_SIZE
          valueFrom:
            configMapKeyRef:
              name: analysis-config
              key: upload-max-size
        - name: REACT_APP_SUPPORTED_FORMATS
          valueFrom:
            configMapKeyRef:
              name: analysis-config
              key: supported-formats
        - name: REACT_APP_WS_URL
          valueFrom:
            configMapKeyRef:
              name: analysis-config
              key: websocket-url
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 80
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
        securityContext:
          runAsNonRoot: true
          runAsUser: 1001
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: nginx-cache
          mountPath: /var/cache/nginx
        - name: nginx-run
          mountPath: /var/run
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: nginx-cache
        emptyDir: {}
      - name: nginx-run
        emptyDir: {}
```

### Istio VirtualService Configuration
```yaml
# Example VirtualService for Dashboard
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: dashboard
  namespace: dashboard
spec:
  hosts:
  - dashboard
  - dashboard.staging.advancedblockchainsecurity.com
  gateways:
  - istio-system/dashboard-gateway
  - mesh
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: dashboard
        port:
          number: 80
    headers:
      response:
        add:
          X-Frame-Options: DENY
          X-Content-Type-Options: nosniff
          X-XSS-Protection: "1; mode=block"
          Strict-Transport-Security: "max-age=31536000; includeSubDomains"
          Content-Security-Policy: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: https:;"
```

### Environment-Specific Configuration

#### ConfigMap Templates
```yaml
# dashboard/base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-config
data:
  environment: "base"
  api-url: "http://api-service:8000"
  websocket-url: "ws://notification:3001"
  sentry-dsn: ""
  features-enabled: "analytics,export,notifications"
  theme-default: "light"
  language-default: "en"
```

#### Local Environment Patches
```yaml
# dashboard/overlays/local/configmap-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-config
data:
  environment: "local"
  api-url: "http://api.local.advancedblockchainsecurity.com"
  websocket-url: "ws://notification.local.advancedblockchainsecurity.com"
  features-enabled: "analytics,export,notifications,debug"
  debug-enabled: "true"
```

#### Staging Environment Configuration
```yaml
# dashboard/overlays/staging/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dashboard-hpa
  namespace: dashboard
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dashboard
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
    scaleUp:
      stabilizationWindowSeconds: 60
```

#### Production Environment Security
```yaml
# dashboard/overlays/production/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dashboard-network-policy
  namespace: dashboard
spec:
  podSelector:
    matchLabels:
      app: dashboard
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: api-service
    ports:
    - protocol: TCP
      port: 8000
  - to:
    - namespaceSelector:
        matchLabels:
          name: notification
    ports:
    - protocol: TCP
      port: 3000
    - protocol: TCP
      port: 3001
  - to: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### Ingress Configuration

#### NGINX Ingress (Local)
```yaml
# ui-core/overlays/local/nginx-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ui-core-ingress
  namespace: ui-core
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: selfsigned-issuer
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - ui-core.local.advancedblockchainsecurity.com
    secretName: ui-core-local-tls
  rules:
  - host: ui-core.local.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ui-core
            port:
              number: 80
```

#### ALB Ingress (Staging/Production)
```yaml
# dashboard/overlays/staging/alb-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dashboard-ingress
  namespace: dashboard
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-west-2:123456789:certificate/cert-id
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
spec:
  rules:
  - host: dashboard.staging.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dashboard
            port:
              number: 80
```

### Build and Deployment Configuration
```yaml
# Dockerfile optimization example
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

# Security headers and optimization
RUN addgroup -g 1001 -S nginx && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

USER 1001

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Implementation Steps

### Phase 1: Base Template Creation (2 hours)
1. Create Kustomize base manifests for all 4 frontend services
2. Configure common resources (Deployment, Service, ConfigMap)
3. Set up Istio VirtualService templates for service mesh integration
4. Configure health checks and monitoring endpoints
5. Add ServiceMonitor for Prometheus integration

### Phase 2: Environment Overlays (1.5 hours)
1. Create local environment overlays with development settings
2. Configure staging overlays with production-like settings and ALB ingress
3. Create production overlays with security hardening and optimization
4. Set up HPA and PDB for staging and production environments
5. Configure environment-specific ConfigMaps and settings

### Phase 3: Ingress and Security Configuration (30 minutes)
1. Configure NGINX ingress for local development
2. Set up ALB ingress for staging and production environments
3. Configure security policies and network restrictions
4. Add CSP headers and security configurations
5. Test ingress routing and SSL termination

## Success Criteria & Validation

### Template Completeness Requirements
- [ ] All 4 frontend services have complete Kustomize base templates
- [ ] Deployment, Service, ConfigMap, and VirtualService resources configured
- [ ] Health checks and monitoring endpoints functional
- [ ] Security contexts and policies configured
- [ ] Build optimization and asset serving configured

### Environment Configuration Requirements
- [ ] Local development overlays with NGINX ingress working
- [ ] Staging overlays with ALB ingress and production-like configuration
- [ ] Production overlays with security hardening and optimization
- [ ] Environment-specific ConfigMaps providing appropriate settings
- [ ] HPA and PDB ensuring service availability and scalability

### Ingress and Access Requirements
- [ ] NGINX ingress routing working for local development
- [ ] ALB ingress routing working for staging and production
- [ ] SSL termination functional with cert-manager certificates
- [ ] Security headers and CSP policies enforced
- [ ] Static asset serving optimized with appropriate caching

### Integration Requirements
- [ ] Istio service mesh integration operational
- [ ] Prometheus monitoring integration functional
- [ ] Service-to-service communication through service mesh
- [ ] ArgoCD application deployment ready
- [ ] Environment variable injection working correctly

## Testing & Validation

### Template Validation
1. **Kustomize Build Testing**:
   ```bash
   # Test each frontend service template
   kubectl kustomize frontend-services/ui-core/overlays/staging
   kubectl kustomize frontend-services/dashboard/overlays/staging
   kubectl kustomize frontend-services/findings/overlays/staging
   kubectl kustomize frontend-services/analysis/overlays/staging
   ```

2. **Resource Validation**:
   ```bash
   # Validate Kubernetes resources
   kubectl apply --dry-run=client -k frontend-services/dashboard/overlays/staging
   kubectl apply --dry-run=server -k frontend-services/dashboard/overlays/staging
   ```

### Deployment Testing
1. **Local Environment**:
   ```bash
   kubectl apply -k frontend-services/dashboard/overlays/local
   kubectl get pods -n dashboard
   kubectl logs -n dashboard deployment/dashboard
   ```

2. **Ingress Testing**:
   ```bash
   # Test NGINX ingress (local)
   curl -I https://dashboard.local.advancedblockchainsecurity.com

   # Test ALB ingress (staging)
   curl -I https://dashboard.staging.advancedblockchainsecurity.com
   ```

## Integration Requirements

### Dependencies
- **From Task 2.1**: Istio service mesh operational
- **From Task 2.3**: cert-manager for SSL certificates
- **From Task 2.4**: Ingress controllers (NGINX and ALB) functional

### Integration Points
- **Task 2.8**: ArgoCD application definitions for frontend services
- **Task 2.11**: Inter-service communication testing
- **Task 2.9**: Backend service integration

### Post-Task Validation
- **Frontend Templates Ready**: All frontend services ready for deployment
- **Environment Consistency**: Consistent deployment across all environments
- **Ingress Access**: External access configured for all environments
- **Monitoring Integrated**: Frontend service monitoring and observability functional

## Troubleshooting Guide

### Common Issues
1. **Static Asset Serving Problems**:
   - Check nginx configuration and asset paths
   - Verify build process and artifact generation
   - Review caching headers and policies
   - Check file permissions and ownership

2. **Environment Variable Issues**:
   - Verify ConfigMap content and format
   - Check environment variable injection in pods
   - Review build-time vs runtime configuration
   - Validate API endpoint accessibility

3. **Ingress Routing Problems**:
   - Check ingress controller status and configuration
   - Verify DNS resolution and routing rules
   - Review SSL certificate status and validity
   - Monitor ingress controller logs

### Monitoring and Debugging
1. **Frontend Application Logs**:
   ```bash
   kubectl logs -n dashboard deployment/dashboard
   kubectl logs -n ui-core deployment/ui-core -f
   ```

2. **Ingress Debugging**:
   ```bash
   kubectl describe ingress dashboard-ingress -n dashboard
   kubectl get events -n dashboard
   ```

## Risk Assessment

### High Risk Items
- **Asset Serving**: Static asset serving and caching configuration
- **Environment Configuration**: Proper environment variable injection
- **Security Headers**: CSP and security header implementation

### Medium Risk Items
- **Ingress Configuration**: Complex ingress routing and SSL setup
- **Build Optimization**: Frontend build and deployment optimization
- **Cross-Origin Requests**: CORS configuration and API access

### Mitigation Strategies
- **Testing Strategy**: Comprehensive testing of asset serving and routing
- **Configuration Validation**: Automated validation of environment configurations
- **Security Review**: Regular review of security headers and policies
- **Performance Monitoring**: Continuous monitoring of frontend performance

This task creates the foundation for deploying all frontend applications with consistent configuration, security, and performance optimization across all environments.