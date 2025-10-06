# Task 2.11: Inter-Service Communication and Networking

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 6 hours
**Owner**: Full Stack Team
**Priority**: P0 (Critical)
**Day**: 11-12

## Objective

Configure and validate secure service-to-service communication via Istio service mesh, implement network policies and security boundaries, and establish autoscaling and availability mechanisms for all services.

## Technical Requirements

### Service Communication Architecture
- **Istio Service Mesh**: Secure mTLS communication between all services
- **Network Policies**: Kubernetes network segmentation and security
- **Service Discovery**: DNS-based service discovery and load balancing
- **Circuit Breakers**: Fault tolerance and resilience patterns
- **Autoscaling**: Horizontal Pod Autoscaling and Pod Disruption Budgets

### Service Communication Matrix
```yaml
Service Communication Patterns:
├── Frontend → Backend Communication:
│   ├── Dashboard → API Service (HTTP/HTTPS)
│   ├── Findings → API Service + Data Service (HTTP/HTTPS)
│   ├── Analysis → API Service + Tool Integration (HTTP/HTTPS)
│   └── UI Core → All Services (Component Library)
├── Backend → Backend Communication:
│   ├── API Service → Data Service (HTTP + mTLS)
│   ├── API Service → Tool Integration (HTTP + mTLS)
│   ├── API Service → Notification (HTTP + mTLS)
│   ├── Tool Integration → Contract Parser (HTTP + mTLS)
│   ├── Tool Integration → Intelligence Engine (HTTP + mTLS)
│   ├── Orchestration → All Backend Services (HTTP + mTLS)
│   └── Intelligence Engine → Data Service (HTTP + mTLS)
├── External Dependencies:
│   ├── All Services → PostgreSQL (TCP + TLS)
│   ├── All Services → Redis (TCP + TLS)
│   ├── Tool Integration → MythX API (HTTPS)
│   ├── Notification → SMTP/Slack/Teams (HTTPS)
│   └── All Services → HashiCorp Vault (HTTPS + TLS)
└── Monitoring Communication:
    ├── Prometheus → All Services (HTTP metrics scraping)
    ├── Fluent Bit → Loki (HTTP log shipping)
    └── Jaeger → All Services (Trace collection)
```

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Network Policy Configuration
1. **Default Deny-All Policy**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny-all
     namespace: default
   spec:
     podSelector: {}
     policyTypes:
     - Ingress
     - Egress
   ```

2. **Service-Specific Network Policies**:
   ```yaml
   # API Service Network Policy
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
     # Allow traffic from frontend services
     - from:
       - namespaceSelector:
           matchLabels:
             name: dashboard
       - namespaceSelector:
           matchLabels:
             name: findings
       - namespaceSelector:
           matchLabels:
             name: analysis
       # Allow traffic from Istio gateway
       - namespaceSelector:
           matchLabels:
             name: istio-system
       ports:
       - protocol: TCP
         port: 8000
     egress:
     # Allow communication to data service
     - to:
       - namespaceSelector:
           matchLabels:
             name: data-service
       ports:
       - protocol: TCP
         port: 8005
     # Allow communication to tool integration
     - to:
       - namespaceSelector:
           matchLabels:
             name: tool-integration
       ports:
       - protocol: TCP
         port: 8001
     # Allow communication to notification service
     - to:
       - namespaceSelector:
           matchLabels:
             name: notification
       ports:
       - protocol: TCP
         port: 3000
     # Allow DNS resolution
     - to: {}
       ports:
       - protocol: TCP
         port: 53
       - protocol: UDP
         port: 53
     # Allow HTTPS to external services
     - to: {}
       ports:
       - protocol: TCP
         port: 443
   ```

3. **Cross-Namespace Communication Policies**:
   ```yaml
   # Tool Integration to Contract Parser
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: tool-integration-network-policy
     namespace: tool-integration
   spec:
     podSelector:
       matchLabels:
         app: tool-integration
     policyTypes:
     - Ingress
     - Egress
     ingress:
     - from:
       - namespaceSelector:
           matchLabels:
             name: api-service
       - namespaceSelector:
           matchLabels:
             name: orchestration
       ports:
       - protocol: TCP
         port: 8001
     egress:
     # Contract Parser communication
     - to:
       - namespaceSelector:
           matchLabels:
             name: contract-parser
       ports:
       - protocol: TCP
         port: 8007
     # Intelligence Engine communication
     - to:
       - namespaceSelector:
           matchLabels:
             name: intelligence-engine
       ports:
       - protocol: TCP
         port: 8003
     # External tool APIs (MythX, GitHub)
     - to: {}
       ports:
       - protocol: TCP
         port: 443
     # DNS resolution
     - to: {}
       ports:
       - protocol: TCP
         port: 53
       - protocol: UDP
         port: 53
   ```

### Istio Traffic Management
1. **DestinationRule for Circuit Breakers**:
   ```yaml
   apiVersion: networking.istio.io/v1beta1
   kind: DestinationRule
   metadata:
     name: api-service-circuit-breaker
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
           consecutiveGatewayErrors: 5
       circuitBreaker:
         consecutive5xxErrors: 5
         consecutiveGatewayErrors: 5
         interval: 30s
         baseEjectionTime: 30s
         maxEjectionPercent: 50
         minHealthPercent: 30
       outlierDetection:
         consecutive5xxErrors: 3
         consecutiveGatewayErrors: 3
         interval: 30s
         baseEjectionTime: 30s
         maxEjectionPercent: 20
         minHealthPercent: 50
     subsets:
     - name: v1
       labels:
         version: v1
   ```

2. **VirtualService for Traffic Routing**:
   ```yaml
   apiVersion: networking.istio.io/v1beta1
   kind: VirtualService
   metadata:
     name: api-service-routing
     namespace: api-service
   spec:
     hosts:
     - api-service
     http:
     - match:
       - uri:
           prefix: /api/v1/health
       route:
       - destination:
           host: api-service
           subset: v1
       timeout: 5s
     - match:
       - uri:
           prefix: /api/v1/
       route:
       - destination:
           host: api-service
           subset: v1
       timeout: 30s
       retries:
         attempts: 3
         perTryTimeout: 10s
         retryOn: 5xx,gateway-error,connect-failure,refused-stream
       fault:
         delay:
           percentage:
             value: 0.1
           fixedDelay: 1s
   ```

### Horizontal Pod Autoscaling (HPA)
1. **Backend Service HPA**:
   ```yaml
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
     maxReplicas: 20
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
           averageValue: "1000"
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
         - type: Pods
           value: 4
           periodSeconds: 60
         selectPolicy: Max
   ```

2. **Tool Integration HPA (Custom Metrics)**:
   ```yaml
   apiVersion: autoscaling/v2
   kind: HorizontalPodAutoscaler
   metadata:
     name: tool-integration-hpa
     namespace: tool-integration
   spec:
     scaleTargetRef:
       apiVersion: apps/v1
       kind: Deployment
       name: tool-integration
     minReplicas: 3
     maxReplicas: 15
     metrics:
     - type: Resource
       resource:
         name: cpu
         target:
           type: Utilization
           averageUtilization: 60
     - type: Pods
       pods:
         metric:
           name: active_analysis_jobs
         target:
           type: AverageValue
           averageValue: "5"
     - type: Pods
       pods:
         metric:
           name: tool_queue_length
         target:
           type: AverageValue
           averageValue: "10"
     behavior:
       scaleDown:
         stabilizationWindowSeconds: 600  # Longer stabilization for job processing
         policies:
         - type: Percent
           value: 25
           periodSeconds: 120
       scaleUp:
         stabilizationWindowSeconds: 120
         policies:
         - type: Pods
           value: 2
           periodSeconds: 60
   ```

### Pod Disruption Budgets (PDB)
1. **Critical Service PDB**:
   ```yaml
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: api-service-pdb
     namespace: api-service
   spec:
     minAvailable: "50%"
     selector:
       matchLabels:
         app: api-service
   ---
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: data-service-pdb
     namespace: data-service
   spec:
     minAvailable: 2
     selector:
       matchLabels:
         app: data-service
   ```

2. **Processing Service PDB**:
   ```yaml
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: tool-integration-pdb
     namespace: tool-integration
   spec:
     minAvailable: "33%"
     selector:
       matchLabels:
         app: tool-integration
   ---
   apiVersion: policy/v1
   kind: PodDisruptionBudget
   metadata:
     name: intelligence-engine-pdb
     namespace: intelligence-engine
   spec:
     minAvailable: 1
     selector:
       matchLabels:
         app: intelligence-engine
   ```

### Service Discovery and Load Balancing
1. **DNS-Based Service Discovery**:
   ```yaml
   # Service definitions with proper labels
   apiVersion: v1
   kind: Service
   metadata:
     name: api-service
     namespace: api-service
     labels:
       app: api-service
       service: api-service
       version: v1
   spec:
     ports:
     - port: 80
       targetPort: 8000
       name: http
     selector:
       app: api-service
       version: v1
     type: ClusterIP
   ```

2. **Load Balancing Configuration**:
   ```yaml
   # Istio load balancing with session affinity
   apiVersion: networking.istio.io/v1beta1
   kind: DestinationRule
   metadata:
     name: data-service-lb
     namespace: data-service
   spec:
     host: data-service
     trafficPolicy:
       loadBalancer:
         consistentHash:
           httpHeaderName: "user-id"  # Session affinity for stateful operations
       connectionPool:
         tcp:
           maxConnections: 50
         http:
           http1MaxPendingRequests: 25
           maxRequestsPerConnection: 5
   ```

### Database and External Service Communication
1. **Database Connection Configuration**:
   ```yaml
   # PostgreSQL service endpoint
   apiVersion: v1
   kind: Service
   metadata:
     name: postgresql
     namespace: data-service
   spec:
     ports:
     - port: 5432
       targetPort: 5432
       name: postgresql
     selector:
       app: postgresql
     type: ClusterIP
   ---
   # Redis service endpoint
   apiVersion: v1
   kind: Service
   metadata:
     name: redis
     namespace: data-service
   spec:
     ports:
     - port: 6379
       targetPort: 6379
       name: redis
     selector:
       app: redis
     type: ClusterIP
   ```

2. **External Service Access**:
   ```yaml
   # ServiceEntry for external APIs
   apiVersion: networking.istio.io/v1beta1
   kind: ServiceEntry
   metadata:
     name: mythx-api
     namespace: tool-integration
   spec:
     hosts:
     - api.mythx.io
     ports:
     - number: 443
       name: https
       protocol: HTTPS
     location: MESH_EXTERNAL
     resolution: DNS
   ---
   # VirtualService for external API routing
   apiVersion: networking.istio.io/v1beta1
   kind: VirtualService
   metadata:
     name: mythx-api-routing
     namespace: tool-integration
   spec:
     hosts:
     - api.mythx.io
     http:
     - timeout: 60s
       retries:
         attempts: 3
         perTryTimeout: 20s
   ```

## Implementation Steps

### Phase 1: Network Policy Implementation (2.5 hours)
1. Deploy default deny-all network policies to all namespaces
2. Configure service-specific network policies for each backend service
3. Set up cross-namespace communication policies
4. Configure external service access policies
5. Test network segmentation and isolation

### Phase 2: Istio Traffic Management (2 hours)
1. Configure DestinationRules with circuit breakers for all services
2. Set up VirtualServices for traffic routing and fault injection
3. Configure load balancing and session affinity
4. Implement retry policies and timeout configurations
5. Test service mesh communication and resilience

### Phase 3: Autoscaling and Availability (1.5 hours)
1. Deploy HPA configurations for all backend and frontend services
2. Configure PDB for critical services to ensure availability
3. Set up custom metrics for application-specific scaling
4. Test autoscaling behavior under load
5. Validate PDB enforcement during rolling updates

## Success Criteria & Validation

### Network Security Requirements
- [ ] Default deny-all policies blocking unauthorized traffic
- [ ] Service-specific policies allowing only required communication
- [ ] Cross-namespace communication working for authorized services
- [ ] External service access controlled and monitored
- [ ] Network policies enforced consistently across environments

### Service Mesh Communication Requirements
- [ ] mTLS communication working between all services
- [ ] Circuit breakers preventing cascading failures
- [ ] Load balancing distributing traffic appropriately
- [ ] Retry policies handling transient failures
- [ ] Service discovery working correctly via DNS

### Autoscaling and Availability Requirements
- [ ] HPA responding to CPU, memory, and custom metrics
- [ ] Scaling behavior optimized for each service type
- [ ] PDB maintaining service availability during disruptions
- [ ] Custom metrics accurately reflecting application load
- [ ] Rolling updates respecting availability constraints

### Integration Requirements
- [ ] Frontend services accessing backend APIs correctly
- [ ] Backend services communicating via service mesh
- [ ] Database connections working with connection pooling
- [ ] External API access functional with proper timeouts
- [ ] Monitoring and observability capturing all communications

## Testing & Validation

### Network Policy Testing
1. **Isolation Testing**:
   ```bash
   # Test blocked communication
   kubectl exec -it deployment/api-service -n api-service -- \
     curl -m 5 http://redis.data-service:6379

   # Should fail due to network policy

   # Test allowed communication
   kubectl exec -it deployment/api-service -n api-service -- \
     curl -m 5 http://data-service.data-service:8005/health

   # Should succeed
   ```

2. **Cross-Namespace Testing**:
   ```bash
   # Test frontend to backend communication
   kubectl exec -it deployment/dashboard -n dashboard -- \
     curl -m 10 http://api-service.api-service:8000/api/v1/health
   ```

### Service Mesh Testing
1. **mTLS Verification**:
   ```bash
   # Check mTLS status
   istioctl authn tls-check api-service.api-service.svc.cluster.local

   # Verify certificate rotation
   istioctl proxy-config secret deployment/api-service -n api-service
   ```

2. **Circuit Breaker Testing**:
   ```bash
   # Generate load to trigger circuit breaker
   kubectl run load-test --image=fortio/fortio --rm -it -- \
     load -qps 1000 -t 60s -c 50 http://api-service.api-service:8000/api/v1/health

   # Check circuit breaker status
   kubectl logs -n api-service deployment/api-service -c istio-proxy | grep circuit
   ```

### Autoscaling Testing
1. **Load Testing for HPA**:
   ```bash
   # Generate CPU load
   kubectl run cpu-load --image=progrium/stress --rm -it -- \
     --cpu 4 --timeout 300s

   # Monitor HPA scaling
   kubectl get hpa -n api-service -w
   kubectl top pods -n api-service
   ```

2. **PDB Validation**:
   ```bash
   # Trigger rolling update
   kubectl patch deployment api-service -n api-service \
     -p '{"spec":{"template":{"metadata":{"annotations":{"restart":"'$(date +%s)'"}}}}}'

   # Verify PDB enforcement
   kubectl get events -n api-service | grep PodDisruptionBudget
   ```

## Integration Requirements

### Dependencies
- **From Task 2.1**: Istio service mesh operational
- **From Task 2.9**: Backend service templates deployed
- **From Task 2.10**: Frontend service templates deployed

### Integration Points
- **Task 2.12**: ArgoCD application health checks
- **Task 2.13**: Platform integration testing
- **Task 2.6**: Monitoring integration for communication metrics

### Post-Task Validation
- **Secure Communication**: All service communication secured and monitored
- **Network Isolation**: Proper security boundaries enforced
- **High Availability**: Services resilient to failures and scaling appropriately
- **Performance Optimized**: Communication optimized for performance and reliability

## Troubleshooting Guide

### Common Issues
1. **Network Policy Blocking Communication**:
   - Review network policy selectors and rules
   - Check namespace labels and pod labels
   - Verify DNS resolution and service discovery
   - Monitor network policy logs and events

2. **Circuit Breaker Issues**:
   - Review circuit breaker thresholds and timing
   - Check service health and response times
   - Monitor Istio proxy logs and metrics
   - Adjust timeout and retry configurations

3. **Autoscaling Problems**:
   - Verify metrics availability and accuracy
   - Check resource requests and limits
   - Review HPA configuration and behavior
   - Monitor scaling events and performance

### Monitoring and Debugging
1. **Network Communication**:
   ```bash
   # Check service endpoints
   kubectl get endpoints -A

   # Test DNS resolution
   kubectl exec -it deployment/api-service -n api-service -- nslookup data-service.data-service

   # Monitor network traffic
   kubectl logs -n kube-system daemonset/fluent-bit | grep network
   ```

2. **Service Mesh Debugging**:
   ```bash
   # Check Istio configuration
   istioctl analyze --all-namespaces

   # Verify proxy configuration
   istioctl proxy-config cluster deployment/api-service -n api-service

   # Check mTLS status
   istioctl authn tls-check api-service.api-service.svc.cluster.local
   ```

## Risk Assessment

### High Risk Items
- **Network Policy Misconfiguration**: Blocking legitimate traffic or allowing unauthorized access
- **Circuit Breaker Tuning**: Balancing fault tolerance with service availability
- **Autoscaling Behavior**: Ensuring stable scaling without oscillation

### Medium Risk Items
- **Service Mesh Overhead**: Performance impact of mTLS and sidecar proxies
- **Custom Metrics**: Reliability and accuracy of custom scaling metrics
- **Cross-Namespace Communication**: Complex network policy interactions

### Mitigation Strategies
- **Gradual Rollout**: Phased implementation of network policies and restrictions
- **Comprehensive Testing**: Extensive testing of communication paths and failure scenarios
- **Monitoring and Alerting**: Real-time monitoring of communication health and performance
- **Rollback Procedures**: Quick rollback capabilities for network and traffic configurations

This task establishes secure, resilient, and scalable inter-service communication that forms the backbone of the entire platform architecture.