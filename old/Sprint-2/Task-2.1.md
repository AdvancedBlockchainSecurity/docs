# Task 2.1: Istio CRDs and Control Plane Installation

**Sprint**: 2 - Kubernetes Infrastructure & ArgoCD Bootstrap
**Estimated Time**: 6 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Day**: 1-2

## Objective

Deploy Istio service mesh foundation including CRDs, control plane, and gateway configuration with automatic sidecar injection across all environments.

## Technical Requirements

### Core Components to Deploy
- **Istio CRDs**: Custom Resource Definitions via Helm installation
- **Istio Control Plane**: istiod deployment via Kustomize in istio-local, istio-staging, istio-production namespaces
- **Istio Gateway**: Ingress traffic management configuration
- **Sidecar Injection**: Automatic Envoy proxy injection for application namespaces
- **mTLS Configuration**: PERMISSIVE mode for gradual adoption

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

### Kustomize Structure Implementation
```yaml
istio-system/
├── base/
│   ├── kustomization.yaml
│   ├── istio-crds.yaml
│   ├── istio-control-plane.yaml
│   ├── istio-gateway.yaml
│   └── sidecar-injection.yaml
└── overlays/
    ├── local/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   └── istio-config-patch.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   ├── namespace.yaml
    │   ├── istio-config-patch.yaml
    │   └── gateway-patch.yaml
    └── production/
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── istio-config-patch.yaml
        ├── gateway-patch.yaml
        └── security-policies.yaml
```

### Environment-Specific Configurations

**Local Environment (istio-local)**:
- Lightweight resource allocation
- Development-friendly logging levels
- Self-signed certificates for testing
- Simplified gateway configuration

**Staging Environment (istio-staging)**:
- Production-like resource allocation
- Comprehensive logging for testing
- Let's Encrypt certificates
- Full gateway configuration with SSL

**Production Environment (istio-production)**:
- Optimized resource allocation
- Security-focused logging
- Production SSL certificates
- Security policies and network restrictions

## Deliverables

### Istio Installation Components
1. **Helm CRD Installation**:
   - Istio base chart with all required CRDs
   - Proper RBAC permissions for Istio controllers
   - CRD validation and webhook configurations

2. **Control Plane Deployment**:
   - istiod deployment with HA configuration
   - Pilot, Citadel, and Galley components
   - Resource limits and requests properly configured
   - Health checks and readiness probes

3. **Gateway Configuration**:
   - Istio Gateway resource for ingress traffic
   - Virtual Service routing configurations
   - Load balancing and traffic distribution
   - SSL/TLS termination setup

4. **Namespace Configuration**:
   - Automatic sidecar injection labels
   - Network policies for Istio components
   - Resource quotas for service mesh overhead
   - RBAC configurations for application access

### Security Configuration
1. **mTLS Setup**:
   - PeerAuthentication policies in PERMISSIVE mode
   - Certificate rotation and management
   - Root CA configuration and trust establishment
   - Workload identity establishment

2. **Traffic Policies**:
   - Default traffic policies for service communication
   - Circuit breaker configurations
   - Retry and timeout policies
   - Load balancing algorithms

## Implementation Steps

### Phase 1: Helm CRD Installation (2 hours)
1. Install Istio base chart with CRDs
2. Verify CRD installation and validation
3. Configure webhook and admission controllers
4. Test CRD functionality with sample resources

### Phase 2: Control Plane Deployment (3 hours)
1. Create Kustomize base manifests for istiod
2. Configure environment-specific overlays
3. Deploy control plane to all environments
4. Verify control plane health and functionality

### Phase 3: Gateway and Injection Setup (1 hour)
1. Configure Istio Gateway resources
2. Enable automatic sidecar injection
3. Test sidecar injection with sample workloads
4. Validate gateway traffic routing

## Success Criteria & Validation

### Istio Control Plane Requirements
- [ ] Istio CRDs installed successfully via Helm
- [ ] istiod control plane operational in istio-local, istio-staging, istio-production namespaces
- [ ] Control plane components pass all health checks
- [ ] Istio configuration deployed via Kustomize overlays
- [ ] Control plane resource utilization within expected ranges

### Gateway and Traffic Management Requirements
- [ ] Istio Gateway routing external traffic properly
- [ ] Virtual Services configured for ingress routing
- [ ] Load balancing working across service instances
- [ ] SSL/TLS termination operational at gateway level
- [ ] Gateway health checks passing consistently

### Sidecar Injection Requirements
- [ ] Automatic sidecar injection enabled for application namespaces
- [ ] Envoy proxy sidecars deployed with workloads
- [ ] Sidecar configuration appropriate for each environment
- [ ] Proxy startup and health checks functioning
- [ ] Service mesh communication established

### Security and mTLS Requirements
- [ ] mTLS communication working in PERMISSIVE mode
- [ ] Certificate rotation and management operational
- [ ] Workload identity properly established
- [ ] PeerAuthentication policies applied correctly
- [ ] Traffic policies enforced as configured

## Testing & Validation

### Functional Testing
1. **Control Plane Health**:
   ```bash
   kubectl get pods -n istio-system
   kubectl get services -n istio-system
   istioctl proxy-status
   istioctl analyze
   ```

2. **Gateway Functionality**:
   ```bash
   kubectl get gateway -A
   kubectl get virtualservice -A
   istioctl proxy-config cluster <gateway-pod>
   ```

3. **Sidecar Injection**:
   ```bash
   kubectl describe namespace <app-namespace>
   kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}'
   istioctl proxy-config bootstrap <app-pod>
   ```

### Performance Testing
1. **Resource Usage Monitoring**:
   - Control plane CPU and memory utilization
   - Sidecar proxy overhead measurement
   - Network latency impact assessment
   - Throughput comparison with and without mesh

2. **Scalability Testing**:
   - Control plane performance under load
   - Gateway capacity and connection limits
   - Sidecar injection speed and reliability
   - Configuration propagation latency

## Integration Requirements

### Dependencies
- **From Task 1.5**: EKS clusters operational and accessible
- **From Task 1.4**: HashiCorp Vault Community Edition for certificate storage
- **From Task 1.2**: VPC and networking infrastructure ready

### Integration Points
- **Task 2.2**: Istio observability components (Jaeger, Kiali)
- **Task 2.3**: cert-manager integration for certificate management
- **Task 2.4**: Load balancer integration for ingress traffic (NGINX for local, ALB for staging/production)
- **Task 2.9**: Backend service Istio configuration

### Post-Task Validation
- **Service Mesh Ready**: Infrastructure prepared for service deployment
- **Certificate Integration**: Ready for cert-manager SSL certificates
- **Observability Ready**: Prepared for monitoring component integration
- **Application Ready**: Namespaces configured for service deployment

## Troubleshooting Guide

### Common Issues
1. **CRD Installation Failures**:
   - Verify Helm repository and chart versions
   - Check cluster RBAC permissions
   - Validate Kubernetes version compatibility

2. **Control Plane Startup Issues**:
   - Review resource allocation and limits
   - Check persistent volume availability
   - Validate network policies and security groups

3. **Sidecar Injection Problems**:
   - Verify namespace labels and annotations
   - Check webhook configuration and certificates
   - Review admission controller logs

4. **Gateway Traffic Issues**:
   - Validate DNS resolution and routing
   - Check load balancer configuration (NGINX for local, ALB for staging/production)
   - Review security group and firewall rules

### Monitoring and Debugging
1. **Control Plane Logs**:
   ```bash
   kubectl logs -n istio-system deployment/istiod
   kubectl logs -n istio-system deployment/istio-proxy
   ```

2. **Configuration Validation**:
   ```bash
   istioctl analyze --all-namespaces
   istioctl proxy-config cluster <pod-name>
   istioctl proxy-config listeners <pod-name>
   ```

3. **Traffic Analysis**:
   ```bash
   istioctl proxy-config routes <pod-name>
   kubectl logs <pod-name> -c istio-proxy
   ```

## Risk Assessment

### High Risk Items
- **Service Mesh Complexity**: Gradual adoption strategy with PERMISSIVE mTLS
- **Resource Overhead**: Monitoring and optimization of sidecar impact
- **Certificate Management**: Proper integration with cert-manager for SSL

### Medium Risk Items
- **Configuration Drift**: GitOps workflow for consistent configuration
- **Network Policy Conflicts**: Careful coordination with existing policies
- **Performance Impact**: Baseline measurement and optimization

### Mitigation Strategies
- **Rollback Procedures**: Quick rollback to pre-mesh configuration
- **Performance Monitoring**: Real-time metrics and alerting
- **Training and Documentation**: Team education on service mesh concepts

## Documentation Requirements

### Technical Documentation
- Istio architecture and component interaction diagrams
- Service mesh traffic flow and security model
- Configuration management and update procedures
- Troubleshooting guide for common service mesh issues

### Operational Documentation
- Control plane monitoring and health check procedures
- Gateway configuration and management
- Sidecar injection troubleshooting and debugging
- Security policy management and updates

This task establishes the foundational service mesh infrastructure that will enable secure, observable, and manageable service-to-service communication for the entire Apogee Platform.