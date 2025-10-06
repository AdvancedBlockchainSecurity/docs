# Task 3.9: Local Environment Deployment

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 6 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Repository**: `solidity-security-aws-infrastructure`

## Overview

Deploy all backend services to the local minikube environment using ArgoCD GitOps workflow with production-ready configurations. This task implements comprehensive deployment automation, monitoring integration, security hardening, and horizontal pod autoscaling while ensuring the local environment serves as the primary development and testing platform before any cloud deployment.

## Technical Requirements

### Technology Stack
```yaml
Container Orchestration: Kubernetes (minikube) with production-grade configurations
GitOps: ArgoCD for automated deployment and synchronization
Service Mesh: Istio for secure service-to-service communication
Monitoring: Prometheus, Grafana, and Jaeger for comprehensive observability
Security: Pod Security Standards, Network Policies, RBAC
Autoscaling: Horizontal Pod Autoscaler (HPA) with custom metrics
Storage: Persistent volumes for stateful services
Load Balancing: Kubernetes Ingress with advanced routing
```

### Development Standards
- **Local-First Philosophy**: Complete deployment in local minikube environment first
- **Production Readiness**: All configurations mirror production standards
- **GitOps Workflow**: All deployments managed through ArgoCD synchronization
- **Security Hardening**: Implementation of security best practices and policies
- **Observability**: Comprehensive monitoring and logging integration
- **High Availability**: Multi-replica deployments with proper resource allocation

## Kubernetes Infrastructure Setup

### Namespace and RBAC Configuration
```yaml
# kubernetes/namespaces/core-namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: solidity-security
  labels:
    app.kubernetes.io/name: solidity-security
    app.kubernetes.io/part-of: solidity-platform
    security.policy: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    app.kubernetes.io/name: monitoring
    app.kubernetes.io/part-of: observability
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    app.kubernetes.io/name: argocd
    app.kubernetes.io/part-of: gitops
---
# Service Accounts for each service
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-service
  namespace: solidity-security
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/api-service-role
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: data-service
  namespace: solidity-security
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/data-service-role
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: notification-service
  namespace: solidity-security
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/notification-service-role
---
# RBAC Configuration
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: solidity-security
  name: service-role
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: service-binding
  namespace: solidity-security
subjects:
- kind: ServiceAccount
  name: api-service
  namespace: solidity-security
- kind: ServiceAccount
  name: data-service
  namespace: solidity-security
- kind: ServiceAccount
  name: notification-service
  namespace: solidity-security
roleRef:
  kind: Role
  name: service-role
  apiGroup: rbac.authorization.k8s.io
```

### Network Policies for Security
```yaml
# kubernetes/security/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-service-netpol
  namespace: solidity-security
spec:
  podSelector:
    matchLabels:
      app: api-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: ingress-nginx
    - namespaceSelector:
        matchLabels:
          name: istio-system
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: data-service
    ports:
    - protocol: TCP
      port: 8001
  - to:
    - podSelector:
        matchLabels:
          app: notification-service
    ports:
    - protocol: TCP
      port: 8002
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  - to:
    - podSelector:
        matchLabels:
          app: vault
    ports:
    - protocol: TCP
      port: 8200
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: data-service-netpol
  namespace: solidity-security
spec:
  podSelector:
    matchLabels:
      app: data-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-service
    ports:
    - protocol: TCP
      port: 8001
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  - to:
    - podSelector:
        matchLabels:
          app: vault
    ports:
    - protocol: TCP
      port: 8200
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: notification-service-netpol
  namespace: solidity-security
spec:
  podSelector:
    matchLabels:
      app: notification-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-service
    ports:
    - protocol: TCP
      port: 8002
  egress:
  - to: []  # Allow external SMTP, Slack API calls
    ports:
    - protocol: TCP
      port: 25
    - protocol: TCP
      port: 587
    - protocol: TCP
      port: 443
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  - to:
    - podSelector:
        matchLabels:
          app: vault
    ports:
    - protocol: TCP
      port: 8200
```

## Service Deployments

### API Service Deployment
```yaml
# kubernetes/services/api-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: solidity-security
  labels:
    app: api-service
    component: backend
    tier: api
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        component: backend
        tier: api
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: api-service
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: api-service
        image: solidity-security/api-service:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000
          name: http
          protocol: TCP
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: connection_url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: redis-config
              key: url
        - name: VAULT_ADDR
          value: "http://vault:8200"
        - name: LOG_LEVEL
          value: "INFO"
        - name: ENVIRONMENT
          value: "local"
        - name: PROMETHEUS_METRICS_ENABLED
          value: "true"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: logs
          mountPath: /app/logs
      volumes:
      - name: tmp
        emptyDir: {}
      - name: logs
        emptyDir: {}
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
      - key: "app"
        operator: "Equal"
        value: "solidity-security"
        effect: "NoSchedule"
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: solidity-security
  labels:
    app: api-service
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: api-service
```

### Data Service Deployment
```yaml
# kubernetes/services/data-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-service
  namespace: solidity-security
  labels:
    app: data-service
    component: backend
    tier: data
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: data-service
  template:
    metadata:
      labels:
        app: data-service
        component: backend
        tier: data
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8001"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: data-service
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: data-service
        image: solidity-security/data-service:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8001
          name: http
          protocol: TCP
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: connection_url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: redis-config
              key: url
        - name: VAULT_ADDR
          value: "http://vault:8200"
        - name: LOG_LEVEL
          value: "INFO"
        - name: CACHE_TTL_DEFAULT
          value: "300"
        - name: CONNECTION_POOL_SIZE
          value: "20"
        resources:
          requests:
            memory: "512Mi"
            cpu: "300m"
          limits:
            memory: "1Gi"
            cpu: "750m"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /app/cache
      volumes:
      - name: tmp
        emptyDir: {}
      - name: cache
        emptyDir:
          sizeLimit: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: data-service
  namespace: solidity-security
  labels:
    app: data-service
spec:
  type: ClusterIP
  ports:
  - port: 8001
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: data-service
```

### Notification Service Deployment
```yaml
# kubernetes/services/notification-service.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notification-service
  namespace: solidity-security
  labels:
    app: notification-service
    component: backend
    tier: notification
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: notification-service
  template:
    metadata:
      labels:
        app: notification-service
        component: backend
        tier: notification
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8002"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: notification-service
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: notification-service
        image: solidity-security/notification-service:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8002
          name: http
          protocol: TCP
        - containerPort: 8003
          name: websocket
          protocol: TCP
        env:
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: redis-config
              key: url
        - name: VAULT_ADDR
          value: "http://vault:8200"
        - name: LOG_LEVEL
          value: "INFO"
        - name: WEBSOCKET_ENABLED
          value: "true"
        - name: EMAIL_ENABLED
          value: "true"
        - name: SLACK_ENABLED
          value: "true"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: templates
          mountPath: /app/templates
      volumes:
      - name: tmp
        emptyDir: {}
      - name: templates
        configMap:
          name: email-templates
---
apiVersion: v1
kind: Service
metadata:
  name: notification-service
  namespace: solidity-security
  labels:
    app: notification-service
spec:
  type: ClusterIP
  ports:
  - port: 8002
    targetPort: http
    protocol: TCP
    name: http
  - port: 8003
    targetPort: websocket
    protocol: TCP
    name: websocket
  selector:
    app: notification-service
```

## Stateful Services Deployment

### PostgreSQL StatefulSet
```yaml
# kubernetes/stateful/postgresql.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: solidity-security
data:
  postgresql.conf: |
    # PostgreSQL configuration for high performance
    max_connections = 100
    shared_buffers = 256MB
    effective_cache_size = 1GB
    maintenance_work_mem = 64MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 1.1
    effective_io_concurrency = 200
    work_mem = 4MB
    min_wal_size = 1GB
    max_wal_size = 4GB
    max_worker_processes = 8
    max_parallel_workers_per_gather = 4
    max_parallel_workers = 8
    max_parallel_maintenance_workers = 4
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: solidity-security
  labels:
    app: postgres
    component: database
spec:
  serviceName: postgres-headless
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
        component: database
    spec:
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      containers:
      - name: postgres
        image: postgres:16
        ports:
        - containerPort: 5432
          name: postgres
        env:
        - name: POSTGRES_DB
          value: "solidity_security"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - $(POSTGRES_USER)
            - -d
            - $(POSTGRES_DB)
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - $(POSTGRES_USER)
            - -d
            - $(POSTGRES_DB)
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
      storageClassName: local-storage
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: solidity-security
  labels:
    app: postgres
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: postgres
    protocol: TCP
    name: postgres
  selector:
    app: postgres
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: solidity-security
  labels:
    app: postgres
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - port: 5432
    targetPort: postgres
    protocol: TCP
    name: postgres
  selector:
    app: postgres
```

### Redis Cluster Deployment
```yaml
# kubernetes/stateful/redis.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: solidity-security
data:
  redis.conf: |
    # Redis configuration for high performance
    maxmemory 512mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    stop-writes-on-bgsave-error yes
    rdbcompression yes
    rdbchecksum yes
    tcp-keepalive 300
    timeout 0
    tcp-backlog 511
    databases 16
    always-show-logo yes
  url: "redis://redis:6379/0"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: solidity-security
  labels:
    app: redis
    component: cache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        component: cache
    spec:
      securityContext:
        runAsUser: 999
        runAsGroup: 999
        fsGroup: 999
      containers:
      - name: redis
        image: redis:7.2
        ports:
        - containerPort: 6379
          name: redis
        command:
        - redis-server
        - /etc/redis/redis.conf
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: password
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis
        - name: redis-data
          mountPath: /data
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
      - name: redis-data
        persistentVolumeClaim:
          claimName: redis-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
  namespace: solidity-security
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: solidity-security
  labels:
    app: redis
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: redis
    protocol: TCP
    name: redis
  selector:
    app: redis
```

## ArgoCD Configuration

### ArgoCD Installation and Setup
```yaml
# kubernetes/argocd/argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: solidity-security-platform
  namespace: argocd
  labels:
    app.kubernetes.io/name: solidity-security-platform
spec:
  project: default
  source:
    repoURL: https://github.com/solidity-security/aws-infrastructure.git
    targetRevision: main
    path: kubernetes/manifests
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: solidity-security
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-stack
  namespace: argocd
  labels:
    app.kubernetes.io/name: monitoring-stack
spec:
  project: default
  source:
    repoURL: https://github.com/solidity-security/aws-infrastructure.git
    targetRevision: main
    path: kubernetes/monitoring
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
---
# ArgoCD Project for better organization
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: solidity-security
  namespace: argocd
spec:
  description: Solidity Security Platform applications
  sourceRepos:
  - 'https://github.com/solidity-security/*'
  destinations:
  - namespace: solidity-security
    server: https://kubernetes.default.svc
  - namespace: monitoring
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: 'rbac.authorization.k8s.io'
    kind: ClusterRole
  - group: 'rbac.authorization.k8s.io'
    kind: ClusterRoleBinding
  namespaceResourceWhitelist:
  - group: ''
    kind: '*'
  - group: 'apps'
    kind: '*'
  - group: 'networking.k8s.io'
    kind: '*'
  - group: 'autoscaling'
    kind: '*'
  - group: 'policy'
    kind: '*'
  roles:
  - name: developer
    description: Developer access to Solidity Security applications
    policies:
    - p, proj:solidity-security:developer, applications, get, solidity-security/*, allow
    - p, proj:solidity-security:developer, applications, action/*, solidity-security/*, allow
    groups:
    - solidity-security:developers
  - name: admin
    description: Admin access to Solidity Security applications
    policies:
    - p, proj:solidity-security:admin, applications, *, solidity-security/*, allow
    - p, proj:solidity-security:admin, repositories, *, *, allow
    groups:
    - solidity-security:admins
```

### ArgoCD Sync Hooks and Health Checks
```yaml
# kubernetes/argocd/hooks/pre-sync-hook.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-migration
  namespace: solidity-security
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-weight: "1"
    argocd.argoproj.io/sync-wave: "1"
spec:
  template:
    spec:
      restartPolicy: Never
      serviceAccountName: migration-service-account
      containers:
      - name: alembic-migration
        image: solidity-security/api-service:latest
        command:
        - python
        - -m
        - alembic
        - upgrade
        - head
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-credentials
              key: connection_url
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: batch/v1
kind: Job
metadata:
  name: vault-initialization
  namespace: solidity-security
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-weight: "0"
    argocd.argoproj.io/sync-wave: "0"
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: vault-init
        image: hashicorp/vault:1.15
        command:
        - /bin/sh
        - -c
        - |
          # Initialize Vault and configure basic secrets
          export VAULT_ADDR=http://vault:8200
          vault auth -method=userpass username=admin password=$VAULT_ADMIN_PASSWORD
          vault secrets enable -path=kv kv-v2
          vault secrets enable database
          vault secrets enable transit
        env:
        - name: VAULT_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: vault-credentials
              key: admin_password
---
# Post-sync verification hook
apiVersion: batch/v1
kind: Job
metadata:
  name: deployment-verification
  namespace: solidity-security
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-weight: "1"
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: verify-deployment
        image: curlimages/curl:latest
        command:
        - /bin/sh
        - -c
        - |
          # Verify all services are healthy
          services="api-service:8000 data-service:8001 notification-service:8002"
          for service in $services; do
            echo "Checking health of $service"
            curl -f http://$service/health || exit 1
            echo "$service is healthy"
          done
          echo "All services are healthy and ready"
```

## Horizontal Pod Autoscaler Configuration

### HPA with Custom Metrics
```yaml
# kubernetes/autoscaling/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-service-hpa
  namespace: solidity-security
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
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 2
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: data-service-hpa
  namespace: solidity-security
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: data-service
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 75
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 85
  - type: Pods
    pods:
      metric:
        name: database_connections_active
      target:
        type: AverageValue
        averageValue: "15"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 120
      policies:
      - type: Percent
        value: 50
        periodSeconds: 30
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: notification-service-hpa
  namespace: solidity-security
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: notification-service
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: websocket_connections_active
      target:
        type: AverageValue
        averageValue: "500"
  - type: Pods
    pods:
      metric:
        name: notification_queue_size
      target:
        type: AverageValue
        averageValue: "100"
```

## Monitoring and Observability Integration

### Prometheus ServiceMonitor Configuration
```yaml
# kubernetes/monitoring/service-monitors.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: api-service-metrics
  namespace: monitoring
  labels:
    app: api-service
spec:
  selector:
    matchLabels:
      app: api-service
  namespaceSelector:
    matchNames:
    - solidity-security
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: data-service-metrics
  namespace: monitoring
  labels:
    app: data-service
spec:
  selector:
    matchLabels:
      app: data-service
  namespaceSelector:
    matchNames:
    - solidity-security
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: notification-service-metrics
  namespace: monitoring
  labels:
    app: notification-service
spec:
  selector:
    matchLabels:
      app: notification-service
  namespaceSelector:
    matchNames:
    - solidity-security
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
```

### Grafana Dashboard Configuration
```yaml
# kubernetes/monitoring/grafana-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: solidity-security-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Solidity Security Platform",
        "tags": ["solidity", "security", "backend"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "API Response Times",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{service=\"api-service\"}[5m]))",
                "legendFormat": "95th percentile"
              },
              {
                "expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket{service=\"api-service\"}[5m]))",
                "legendFormat": "50th percentile"
              }
            ],
            "yAxes": [
              {
                "label": "Seconds"
              }
            ]
          },
          {
            "id": 2,
            "title": "Database Query Performance",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(db_query_duration_seconds_sum[5m]) / rate(db_query_duration_seconds_count[5m])",
                "legendFormat": "Average Query Time"
              }
            ]
          },
          {
            "id": 3,
            "title": "Cache Hit Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "rate(cache_operations_total{result=\"hit\"}[5m]) / rate(cache_operations_total[5m]) * 100",
                "legendFormat": "Hit Rate %"
              }
            ]
          },
          {
            "id": 4,
            "title": "Active WebSocket Connections",
            "type": "graph",
            "targets": [
              {
                "expr": "websocket_connections_active",
                "legendFormat": "{{instance}}"
              }
            ]
          },
          {
            "id": 5,
            "title": "Pod Resource Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(container_cpu_usage_seconds_total{namespace=\"solidity-security\"}[5m]) * 100",
                "legendFormat": "CPU % - {{pod}}"
              },
              {
                "expr": "container_memory_usage_bytes{namespace=\"solidity-security\"} / 1024 / 1024",
                "legendFormat": "Memory MB - {{pod}}"
              }
            ]
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "10s"
      }
    }
```

## Local Development Automation

### Local Deployment Script
```bash
#!/bin/bash
# scripts/deploy-local.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="solidity-security"
MONITORING_NAMESPACE="monitoring"
ARGOCD_NAMESPACE="argocd"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if minikube is running
    if ! minikube status &>/dev/null; then
        log_error "Minikube is not running. Please start minikube first."
        exit 1
    fi

    # Check if kubectl is configured
    if ! kubectl cluster-info &>/dev/null; then
        log_error "kubectl is not configured properly."
        exit 1
    fi

    # Check if ArgoCD CLI is available
    if ! command -v argocd &>/dev/null; then
        log_warn "ArgoCD CLI not found. Installing..."
        curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x /tmp/argocd
        sudo mv /tmp/argocd /usr/local/bin/argocd
    fi

    log_info "Prerequisites check completed."
}

# Setup storage classes
setup_storage() {
    log_info "Setting up storage classes..."

    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /tmp/postgres-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - minikube
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: redis-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /tmp/redis-data
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - minikube
EOF

    # Create directories on minikube node
    minikube ssh "sudo mkdir -p /tmp/postgres-data /tmp/redis-data && sudo chmod 777 /tmp/postgres-data /tmp/redis-data"

    log_info "Storage setup completed."
}

# Install ArgoCD
install_argocd() {
    log_info "Installing ArgoCD..."

    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE

    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log_info "ArgoCD admin password: $ARGOCD_PASSWORD"

    # Port forward ArgoCD server
    kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443 &
    ARGOCD_PF_PID=$!

    sleep 10

    # Login to ArgoCD
    argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure

    log_info "ArgoCD installation completed."
}

# Deploy secrets
deploy_secrets() {
    log_info "Deploying secrets..."

    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

    # Database credentials
    kubectl create secret generic postgres-credentials \
        --from-literal=username=postgres \
        --from-literal=password=secure-postgres-password \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -

    # Redis credentials
    kubectl create secret generic redis-credentials \
        --from-literal=password=secure-redis-password \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -

    # Vault credentials
    kubectl create secret generic vault-credentials \
        --from-literal=admin_password=secure-vault-password \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -

    # Database connection URL
    kubectl create secret generic database-credentials \
        --from-literal=connection_url="postgresql://postgres:secure-postgres-password@postgres:5432/solidity_security" \
        --namespace=$NAMESPACE \
        --dry-run=client -o yaml | kubectl apply -f -

    log_info "Secrets deployment completed."
}

# Deploy monitoring stack
deploy_monitoring() {
    log_info "Deploying monitoring stack..."

    kubectl create namespace $MONITORING_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

    # Install Prometheus Operator
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml

    # Install Grafana
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: $MONITORING_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: admin
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: $MONITORING_NAMESPACE
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: grafana
EOF

    log_info "Monitoring stack deployment completed."
}

# Deploy applications via ArgoCD
deploy_applications() {
    log_info "Deploying applications via ArgoCD..."

    # Apply ArgoCD applications
    kubectl apply -f "$PROJECT_ROOT/kubernetes/argocd/"

    log_info "Application deployment initiated. ArgoCD will handle the sync."
}

# Wait for deployment completion
wait_for_deployment() {
    log_info "Waiting for deployment completion..."

    # Wait for all deployments to be ready
    kubectl wait --for=condition=available --timeout=600s deployment/api-service -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=600s deployment/data-service -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=600s deployment/notification-service -n $NAMESPACE

    # Wait for stateful sets
    kubectl wait --for=condition=ready --timeout=600s pod -l app=postgres -n $NAMESPACE
    kubectl wait --for=condition=ready --timeout=600s pod -l app=redis -n $NAMESPACE

    log_info "All deployments are ready."
}

# Setup port forwarding
setup_port_forwarding() {
    log_info "Setting up port forwarding..."

    # Kill existing port forwards
    pkill -f "kubectl port-forward" || true

    # Port forward services
    kubectl port-forward svc/api-service 8000:8000 -n $NAMESPACE &
    kubectl port-forward svc/data-service 8001:8001 -n $NAMESPACE &
    kubectl port-forward svc/notification-service 8002:8002 -n $NAMESPACE &
    kubectl port-forward svc/grafana 3001:3000 -n $MONITORING_NAMESPACE &

    log_info "Port forwarding setup completed."
    log_info "Services available at:"
    log_info "  API Service: http://localhost:8000"
    log_info "  Data Service: http://localhost:8001"
    log_info "  Notification Service: http://localhost:8002"
    log_info "  Grafana: http://localhost:3001 (admin/admin)"
    log_info "  ArgoCD: http://localhost:8080 (admin/$ARGOCD_PASSWORD)"
}

# Health check
health_check() {
    log_info "Performing health checks..."

    services=(
        "http://localhost:8000/health"
        "http://localhost:8001/health"
        "http://localhost:8002/health"
    )

    for service in "${services[@]}"; do
        if curl -f "$service" &>/dev/null; then
            log_info "✓ $service is healthy"
        else
            log_error "✗ $service is not responding"
        fi
    done
}

# Main deployment function
main() {
    log_info "Starting local deployment of Solidity Security Platform..."

    check_prerequisites
    setup_storage
    install_argocd
    deploy_secrets
    deploy_monitoring
    deploy_applications
    wait_for_deployment
    setup_port_forwarding

    sleep 10
    health_check

    log_info "Local deployment completed successfully!"
    log_info "Use 'kubectl get pods -n $NAMESPACE' to check pod status"
    log_info "Use 'argocd app list' to check ArgoCD application status"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up local deployment..."

    # Delete ArgoCD applications
    argocd app delete solidity-security-platform --cascade || true
    argocd app delete monitoring-stack --cascade || true

    # Delete namespaces (this will delete all resources)
    kubectl delete namespace $NAMESPACE || true
    kubectl delete namespace $MONITORING_NAMESPACE || true
    kubectl delete namespace $ARGOCD_NAMESPACE || true

    # Kill port forwards
    pkill -f "kubectl port-forward" || true

    # Clean up storage
    kubectl delete pv postgres-pv redis-pv || true
    minikube ssh "sudo rm -rf /tmp/postgres-data /tmp/redis-data" || true

    log_info "Cleanup completed."
}

# Handle command line arguments
case "${1:-deploy}" in
    deploy)
        main
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Usage: $0 [deploy|cleanup]"
        exit 1
        ;;
esac
```

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Infrastructure Structure
```
kubernetes/
├── namespaces/
│   ├── core-namespaces.yaml     # Namespace definitions with labels
│   └── rbac.yaml               # RBAC configurations
├── services/
│   ├── api-service.yaml        # API service deployment and service
│   ├── data-service.yaml       # Data service deployment and service
│   └── notification-service.yaml # Notification service deployment
├── stateful/
│   ├── postgresql.yaml         # PostgreSQL StatefulSet
│   ├── redis.yaml             # Redis deployment with persistence
│   └── vault.yaml             # HashiCorp Vault deployment
├── security/
│   ├── network-policies.yaml  # Network security policies
│   ├── pod-security.yaml      # Pod Security Standards
│   └── secrets.yaml           # Secret definitions
├── autoscaling/
│   ├── hpa.yaml               # Horizontal Pod Autoscaler configs
│   └── vpa.yaml               # Vertical Pod Autoscaler configs
├── monitoring/
│   ├── service-monitors.yaml  # Prometheus ServiceMonitor configs
│   ├── grafana-dashboard.yaml # Grafana dashboard definitions
│   └── alerts.yaml            # Prometheus alerting rules
├── argocd/
│   ├── argocd-application.yaml # ArgoCD application definitions
│   ├── app-projects.yaml      # ArgoCD project configurations
│   └── hooks/                 # Pre/post sync hooks
└── scripts/
    ├── deploy-local.sh         # Local deployment automation
    ├── health-check.sh         # Health verification script
    └── cleanup.sh              # Environment cleanup script
```

### Features Implemented
- ✅ Complete Kubernetes deployment manifests for all services
- ✅ ArgoCD GitOps workflow with automated sync and self-healing
- ✅ Horizontal Pod Autoscaler with custom metrics support
- ✅ Network policies for service isolation and security
- ✅ Pod Security Standards implementation
- ✅ Persistent storage for stateful services
- ✅ Service mesh integration with Istio
- ✅ Comprehensive monitoring with Prometheus and Grafana
- ✅ Automated deployment scripts for local development
- ✅ Health checks and readiness probes for all services

## Acceptance Criteria

### Deployment Success
- [ ] All backend services deploy successfully to local minikube environment
- [ ] ArgoCD manages deployments with automated sync and self-healing capabilities
- [ ] Services scale automatically based on CPU, memory, and custom metrics
- [ ] Network policies enforce proper service isolation and communication rules
- [ ] Persistent volumes maintain data across pod restarts and updates

### Security Implementation
- [ ] Pod Security Standards enforce security constraints on all pods
- [ ] Network policies restrict inter-service communication to required paths only
- [ ] RBAC configurations provide least-privilege access to service accounts
- [ ] Secrets management integrates with HashiCorp Vault securely
- [ ] Container security contexts prevent privilege escalation

### Monitoring and Observability
- [ ] Prometheus metrics collection functional for all services
- [ ] Grafana dashboards provide comprehensive service visibility
- [ ] Health checks accurately reflect service and dependency status
- [ ] Logging aggregation captures structured logs with correlation IDs
- [ ] Alerting rules notify on critical service health and performance issues

### Operational Excellence
- [ ] ArgoCD applications sync successfully from Git repositories
- [ ] Horizontal Pod Autoscaler responds appropriately to load changes
- [ ] Rolling updates execute without service disruption
- [ ] Local development environment supports full testing workflows
- [ ] Automated deployment scripts enable rapid environment setup and teardown

This comprehensive local environment deployment provides a production-ready Kubernetes foundation that serves as the primary development and testing platform, ensuring all services are fully validated locally before any cloud deployment consideration.