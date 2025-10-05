# Task 2.9: Backend Service Kustomize Templates

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 8 hours
**Owner**: DevOps/Backend Team
**Priority**: P0 (Critical)
**Day**: 9-10

## Objective

Create production-ready Kustomize base configurations and environment-specific overlays for all 7 backend microservices, enabling consistent deployment across local, staging, and production environments.

## Technical Requirements

### Core Template Components
- **Kustomize Base Manifests**: Deployment, Service, ConfigMap, and other resources
- **Environment Overlays**: Local, staging, and production customizations
- **External Secret Integration**: HashiCorp Vault secret management
- **Istio Service Mesh**: VirtualService and DestinationRule configurations
- **IRSA Configuration**: IAM Roles for Service Accounts for AWS access

### Backend Services Architecture
```yaml
Backend Services (7 services):
├── api-service (FastAPI + DDD)
├── tool-integration (Hybrid Python/Rust)
├── intelligence-engine (Hybrid Python/Rust)
├── orchestration (Python Celery)
├── data-service (Hybrid Python/Rust)
├── notification (Node.js/TypeScript)
└── contract-parser (Pure Rust)
```

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`

### Kustomize Structure Template
```yaml
backend-services/
├── api-service/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── external-secret.yaml
│   │   ├── service-account.yaml
│   │   ├── virtual-service.yaml
│   │   ├── destination-rule.yaml
│   │   ├── service-monitor.yaml
│   │   └── network-policy.yaml
│   └── overlays/
│       ├── local/
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── deployment-patch.yaml
│       │   ├── configmap-patch.yaml
│       │   ├── service-patch.yaml
│       │   └── ingress.yaml
│       ├── staging/
│       │   ├── kustomization.yaml
│       │   ├── namespace.yaml
│       │   ├── deployment-patch.yaml
│       │   ├── configmap-patch.yaml
│       │   ├── hpa.yaml
│       │   ├── pdb.yaml
│       │   ├── alb-ingress.yaml
│       │   └── resource-limits.yaml
│       └── production/
│           ├── kustomization.yaml
│           ├── namespace.yaml
│           ├── deployment-patch.yaml
│           ├── configmap-patch.yaml
│           ├── hpa.yaml
│           ├── pdb.yaml
│           ├── network-policy.yaml
│           ├── resource-quota.yaml
│           ├── limit-range.yaml
│           ├── alb-ingress.yaml
│           └── security-context.yaml
├── tool-integration/
├── intelligence-engine/
├── orchestration/
├── data-service/
├── notification/
└── contract-parser/
```

## Deliverables

### Service-Specific Template Configurations

#### 1. API Service (FastAPI with DDD Architecture)
```yaml
# api-service/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  labels:
    app: api-service
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-service
      version: v1
  template:
    metadata:
      labels:
        app: api-service
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: api-service
      containers:
      - name: api-service
        image: api-service:latest
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: api-service-config
              key: environment
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: api-service-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: api-service-secrets
              key: redis-url
        - name: JWT_SIGNING_KEY
          valueFrom:
            secretKeyRef:
              name: api-service-secrets
              key: jwt-signing-key
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
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
```

#### 2. Tool Integration Service (Hybrid Python/Rust)
```yaml
# tool-integration/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tool-integration
  labels:
    app: tool-integration
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tool-integration
      version: v1
  template:
    metadata:
      labels:
        app: tool-integration
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: tool-integration
      containers:
      - name: tool-integration-python
        image: tool-integration-python:latest
        ports:
        - containerPort: 8001
          name: http
        env:
        - name: MYTHX_API_KEY
          valueFrom:
            secretKeyRef:
              name: tool-integration-secrets
              key: mythx-api-key
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: tool-integration-secrets
              key: github-token
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        - name: tool-cache
          mountPath: /app/cache
      - name: tool-integration-rust
        image: tool-integration-rust:latest
        ports:
        - containerPort: 8002
          name: rust-http
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
      volumes:
      - name: tmp-volume
        emptyDir: {}
      - name: tool-cache
        persistentVolumeClaim:
          claimName: tool-integration-cache
```

#### 3. Intelligence Engine Service (Hybrid Python/Rust)
```yaml
# intelligence-engine/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: intelligence-engine
  labels:
    app: intelligence-engine
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: intelligence-engine
      version: v1
  template:
    metadata:
      labels:
        app: intelligence-engine
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: intelligence-engine
      containers:
      - name: intelligence-engine-python
        image: intelligence-engine-python:latest
        ports:
        - containerPort: 8003
          name: http
        env:
        - name: MODEL_PATH
          value: "/app/models"
        - name: RUST_ENGINE_URL
          value: "http://localhost:8004"
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        volumeMounts:
        - name: model-storage
          mountPath: /app/models
      - name: intelligence-engine-rust
        image: intelligence-engine-rust:latest
        ports:
        - containerPort: 8004
          name: rust-http
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
      volumes:
      - name: model-storage
        persistentVolumeClaim:
          claimName: intelligence-engine-models
      - name: tmp-volume
        emptyDir: {}
```

#### 4. Orchestration Service (Python Celery)
```yaml
# orchestration/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orchestration-worker
  labels:
    app: orchestration
    component: worker
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: orchestration
      component: worker
      version: v1
  template:
    metadata:
      labels:
        app: orchestration
        component: worker
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: orchestration
      containers:
      - name: celery-worker
        image: orchestration:latest
        command: ["celery", "worker", "-A", "orchestration.celery_app", "--loglevel=info"]
        env:
        - name: CELERY_BROKER_URL
          valueFrom:
            secretKeyRef:
              name: orchestration-secrets
              key: celery-broker-url
        - name: CELERY_RESULT_BACKEND
          valueFrom:
            secretKeyRef:
              name: orchestration-secrets
              key: celery-result-backend
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
        livenessProbe:
          exec:
            command:
            - celery
            - inspect
            - ping
            - -A
            - orchestration.celery_app
          initialDelaySeconds: 30
          periodSeconds: 60
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orchestration-beat
  labels:
    app: orchestration
    component: beat
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orchestration
      component: beat
      version: v1
  template:
    metadata:
      labels:
        app: orchestration
        component: beat
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: orchestration
      containers:
      - name: celery-beat
        image: orchestration:latest
        command: ["celery", "beat", "-A", "orchestration.celery_app", "--loglevel=info"]
        env:
        - name: CELERY_BROKER_URL
          valueFrom:
            secretKeyRef:
              name: orchestration-secrets
              key: celery-broker-url
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

#### 5. Data Service (Hybrid Python/Rust)
```yaml
# data-service/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-service
  labels:
    app: data-service
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: data-service
      version: v1
  template:
    metadata:
      labels:
        app: data-service
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: data-service
      containers:
      - name: data-service-python
        image: data-service-python:latest
        ports:
        - containerPort: 8005
          name: http
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: data-service-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: data-service-secrets
              key: redis-url
        - name: RUST_ENGINE_URL
          value: "http://localhost:8006"
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 8005
        readinessProbe:
          httpGet:
            path: /ready
            port: 8005
      - name: data-service-rust
        image: data-service-rust:latest
        ports:
        - containerPort: 8006
          name: rust-http
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
```

#### 6. Notification Service (Node.js/TypeScript)
```yaml
# notification/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification
  labels:
    app: notification
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: notification
      version: v1
  template:
    metadata:
      labels:
        app: notification
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: notification
      containers:
      - name: notification
        image: notification:latest
        ports:
        - containerPort: 3000
          name: http
        - containerPort: 3001
          name: websocket
        env:
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: notification-config
              key: node-env
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: notification-secrets
              key: redis-url
        - name: SMTP_HOST
          valueFrom:
            secretKeyRef:
              name: notification-secrets
              key: smtp-host
        - name: SMTP_USERNAME
          valueFrom:
            secretKeyRef:
              name: notification-secrets
              key: smtp-username
        - name: SMTP_PASSWORD
          valueFrom:
            secretKeyRef:
              name: notification-secrets
              key: smtp-password
        - name: SLACK_WEBHOOK_URL
          valueFrom:
            secretKeyRef:
              name: notification-secrets
              key: slack-webhook-url
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
            port: 3000
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
```

#### 7. Contract Parser Service (Pure Rust)
```yaml
# contract-parser/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: contract-parser
  labels:
    app: contract-parser
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: contract-parser
      version: v1
  template:
    metadata:
      labels:
        app: contract-parser
        version: v1
      annotations:
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: contract-parser
      containers:
      - name: contract-parser
        image: contract-parser:latest
        ports:
        - containerPort: 8007
          name: http
        env:
        - name: RUST_LOG
          value: "info"
        - name: S3_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: contract-parser-secrets
              key: s3-access-key
        - name: S3_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: contract-parser-secrets
              key: s3-secret-key
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: contract-parser-secrets
              key: redis-url
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        livenessProbe:
          httpGet:
            path: /health
            port: 8007
        readinessProbe:
          httpGet:
            path: /ready
            port: 8007
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
      volumes:
      - name: tmp-volume
        emptyDir: {}
```

### Istio Service Mesh Integration
```yaml
# Example VirtualService for API Service
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-service
  namespace: api-service
spec:
  hosts:
  - api-service
  - api.staging.advancedblockchainsecurity.com
  gateways:
  - istio-system/api-gateway
  - mesh
  http:
  - match:
    - uri:
        prefix: /api/v1/
    route:
    - destination:
        host: api-service
        port:
          number: 80
        subset: v1
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
      retryOn: 5xx,gateway-error,connect-failure,refused-stream

---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-service
  namespace: api-service
spec:
  host: api-service
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    circuitBreaker:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
  subsets:
  - name: v1
    labels:
      version: v1
```

### Environment-Specific Overlays

#### Local Environment Patches
```yaml
# api-service/overlays/local/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: api-service
        image: api-service:dev
        env:
        - name: DEBUG
          value: "true"
        - name: LOG_LEVEL
          value: "debug"
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

#### Staging Environment Configuration
```yaml
# api-service/overlays/staging/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-service-hpa
  namespace: api-service
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
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
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
```

#### Production Environment Security
```yaml
# api-service/overlays/production/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-service-network-policy
  namespace: api-service
spec:
  podSelector:
    matchLabels:
      app: api-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: istio-system
    - namespaceSelector:
        matchLabels:
          name: dashboard
    - namespaceSelector:
        matchLabels:
          name: findings
    - namespaceSelector:
        matchLabels:
          name: analysis
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: data-service
    ports:
    - protocol: TCP
      port: 8005
  - to:
    - namespaceSelector:
        matchLabels:
          name: tool-integration
    ports:
    - protocol: TCP
      port: 8001
  - to:
    - namespaceSelector:
        matchLabels:
          name: notification
    ports:
    - protocol: TCP
      port: 3000
  - to: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

## Implementation Steps

### Phase 1: Base Template Creation (4 hours)
1. Create Kustomize base manifests for all 7 backend services
2. Configure common resources (Deployment, Service, ConfigMap)
3. Set up External Secret integration for each service
4. Configure Istio VirtualService and DestinationRule templates
5. Add ServiceMonitor for Prometheus integration

### Phase 2: Environment Overlays (3 hours)
1. Create local environment overlays with development settings
2. Configure staging overlays with production-like settings
3. Create production overlays with security and performance optimization
4. Set up HPA, PDB, and resource management for staging/production
5. Configure ingress resources for external access

### Phase 3: IRSA and Security Configuration (1 hour)
1. Configure service accounts with IRSA annotations
2. Set up network policies for production environment
3. Configure security contexts and pod security policies
4. Add resource quotas and limit ranges
5. Test security configurations and access controls

## Success Criteria & Validation

### Template Completeness Requirements
- [ ] All 7 backend services have complete Kustomize base templates
- [ ] Deployment, Service, ConfigMap, and External Secret resources configured
- [ ] Istio VirtualService and DestinationRule templates functional
- [ ] ServiceMonitor resources for Prometheus integration
- [ ] Network policies and security configurations complete

### Environment Overlay Requirements
- [ ] Local development overlays with appropriate resource limits
- [ ] Staging overlays with production-like configuration and HPA
- [ ] Production overlays with security hardening and optimization
- [ ] Environment-specific ingress configurations working
- [ ] Service-specific configuration customization functional

### Integration Requirements
- [ ] External Secrets integration working for all services
- [ ] Istio service mesh integration operational
- [ ] IRSA configuration providing appropriate AWS permissions
- [ ] Prometheus monitoring integration functional
- [ ] ArgoCD application deployment ready

### Security and Performance Requirements
- [ ] Network policies enforcing appropriate service communication
- [ ] Security contexts and pod security policies configured
- [ ] Resource limits and requests optimized for each environment
- [ ] HPA and PDB ensuring service availability and scalability
- [ ] Health checks and monitoring endpoints functional

## Testing & Validation

### Template Validation
1. **Kustomize Build Testing**:
   ```bash
   # Test each service template
   kubectl kustomize backend-services/api-service/overlays/staging
   kubectl kustomize backend-services/tool-integration/overlays/staging
   kubectl kustomize backend-services/intelligence-engine/overlays/staging
   kubectl kustomize backend-services/orchestration/overlays/staging
   kubectl kustomize backend-services/data-service/overlays/staging
   kubectl kustomize backend-services/notification/overlays/staging
   kubectl kustomize backend-services/contract-parser/overlays/staging
   ```

2. **Resource Validation**:
   ```bash
   # Validate Kubernetes resources
   kubectl apply --dry-run=client -k backend-services/api-service/overlays/staging
   kubectl apply --dry-run=server -k backend-services/api-service/overlays/staging
   ```

### Deployment Testing
1. **Local Environment**:
   ```bash
   kubectl apply -k backend-services/api-service/overlays/local
   kubectl get pods -n api-service
   kubectl logs -n api-service deployment/api-service
   ```

2. **External Secrets Integration**:
   ```bash
   kubectl get externalsecrets -n api-service
   kubectl get secrets -n api-service
   kubectl describe externalsecret api-service-secrets -n api-service
   ```

## Integration Requirements

### Dependencies
- **From Task 2.1**: Istio service mesh operational
- **From Task 2.5**: External Secrets Operator functional
- **From Task 2.7**: ArgoCD ready for application deployment

### Integration Points
- **Task 2.8**: ArgoCD application definitions for backend services
- **Task 2.11**: Inter-service communication and networking
- **Task 2.12**: GitOps workflow integration

### Post-Task Validation
- **Service Templates Ready**: All backend services ready for deployment
- **Environment Consistency**: Consistent deployment across all environments
- **Security Configured**: Production security policies and controls operational
- **Monitoring Integrated**: Service monitoring and observability functional

This task creates the foundation for deploying all backend microservices with consistent configuration, security, and monitoring across all environments using GitOps workflows.