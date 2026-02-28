# Task 3.10: SSL Configuration and Domain Setup

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 3 hours
**Owner**: DevOps Team
**Priority**: P0 (Critical)
**Repository**: `blocksecops-aws-infrastructure`

## Overview

Configure SSL certificates and domain routing for all backend services using cert-manager for automated Let's Encrypt certificate provisioning, CloudFlare DNS for domain validation, and Kubernetes Ingress for SSL termination. This task establishes secure HTTPS access patterns for local development while preparing the infrastructure for future staging and production deployments.

## Technical Requirements

### Technology Stack
```yaml
Certificate Management: cert-manager with Let's Encrypt ACME provider
DNS Provider: CloudFlare for DNS-01 challenge validation
Load Balancer: NGINX Ingress Controller for local development, AWS Application Load Balancer (ALB) for staging/production with SSL termination
Security Headers: Comprehensive HTTPS enforcement and security policies
Domain Management: Subdomain configuration for service-specific access
Certificate Automation: Auto-renewal with monitoring and alerting
Local Development: mkcert for local SSL certificate generation
```

### Development Standards
- **Local-First Development**: Local SSL certificates for development environment
- **Security First**: HTTPS enforcement with proper security headers
- **Automation**: Automated certificate provisioning and renewal
- **Monitoring**: Certificate expiration monitoring and alerting
- **Scalability**: Domain structure supporting future growth
- **Compliance**: SSL/TLS best practices implementation

## Domain Architecture

### Domain Structure Design
```yaml
# Local Development Environment
Local Domains:
  api.local.dev: API service (port-forward to localhost:8000)
  data.local.dev: Data service (port-forward to localhost:8001)
  notifications.local.dev: Notification service (port-forward to localhost:8002)
  monitoring.local.dev: Grafana dashboard (port-forward to localhost:3001)
  argocd.local.dev: ArgoCD interface (port-forward to localhost:8080)

# Future Staging Environment (infrastructure ready)
Staging Domains:
  api.staging.advancedblockchainsecurity.com: API Gateway
  data.staging.advancedblockchainsecurity.com: Data Service
  notifications.staging.advancedblockchainsecurity.com: Notification Service
  monitoring.staging.advancedblockchainsecurity.com: Monitoring Dashboard
  argocd.staging.advancedblockchainsecurity.com: GitOps Interface

# Future Production Environment (infrastructure ready)
Production Domains:
  api.app.advancedblockchainsecurity.com: Production API
  data.app.advancedblockchainsecurity.com: Production Data Service
  notifications.app.advancedblockchainsecurity.com: Production Notifications
  monitoring.app.advancedblockchainsecurity.com: Production Monitoring
  argocd.app.advancedblockchainsecurity.com: Production GitOps
```

### CloudFlare DNS Configuration
```yaml
# DNS Records for Future Deployment
DNS_RECORDS:
  # Staging Environment
  staging_api:
    type: "A"
    name: "api.staging"
    content: "{{ ALB_IP_ADDRESS }}"
    ttl: 300
    proxied: true

  staging_data:
    type: "CNAME"
    name: "data.staging"
    content: "api.staging.advancedblockchainsecurity.com"
    ttl: 300
    proxied: true

  staging_notifications:
    type: "CNAME"
    name: "notifications.staging"
    content: "api.staging.advancedblockchainsecurity.com"
    ttl: 300
    proxied: true

  staging_monitoring:
    type: "CNAME"
    name: "monitoring.staging"
    content: "api.staging.advancedblockchainsecurity.com"
    ttl: 300
    proxied: true

  # Production Environment
  production_api:
    type: "A"
    name: "api.app"
    content: "{{ PRODUCTION_ALB_IP }}"
    ttl: 300
    proxied: true

  production_data:
    type: "CNAME"
    name: "data.app"
    content: "api.app.advancedblockchainsecurity.com"
    ttl: 300
    proxied: true

  production_notifications:
    type: "CNAME"
    name: "notifications.app"
    content: "api.app.advancedblockchainsecurity.com"
    ttl: 300
    proxied: true

  production_monitoring:
    type: "CNAME"
    name: "monitoring.app"
    content: "api.app.advancedblockchainsecurity.com"
    ttl: 300
    proxied: true
```

## Local Development SSL Setup

### mkcert Configuration for Local Development
```bash
#!/bin/bash
# scripts/setup-local-ssl.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Install mkcert if not present
install_mkcert() {
    if command -v mkcert &> /dev/null; then
        log_info "mkcert is already installed"
        return
    fi

    log_info "Installing mkcert..."

    case "$(uname -s)" in
        Darwin*)
            if command -v brew &> /dev/null; then
                brew install mkcert
            else
                log_warn "Homebrew not found. Please install mkcert manually from https://github.com/FiloSottile/mkcert"
                exit 1
            fi
            ;;
        Linux*)
            # Download latest release
            MKCERT_VERSION=$(curl -s https://api.github.com/repos/FiloSottile/mkcert/releases/latest | grep tag_name | cut -d '"' -f 4)
            curl -L -o mkcert "https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-amd64"
            chmod +x mkcert
            sudo mv mkcert /usr/local/bin/
            ;;
        *)
            log_warn "Unsupported operating system. Please install mkcert manually."
            exit 1
            ;;
    esac

    log_info "mkcert installed successfully"
}

# Setup local CA
setup_local_ca() {
    log_info "Setting up local Certificate Authority..."
    mkcert -install
    log_info "Local CA installed and trusted"
}

# Generate certificates for local domains
generate_local_certificates() {
    log_info "Generating SSL certificates for local development..."

    # Create certificates directory
    mkdir -p ./certs/local

    # Generate certificate for all local domains
    cd ./certs/local

    mkcert \
        "*.local.dev" \
        "api.local.dev" \
        "data.local.dev" \
        "notifications.local.dev" \
        "monitoring.local.dev" \
        "argocd.local.dev" \
        "localhost" \
        "127.0.0.1"

    # Rename files for consistency
    mv _wildcard.local.dev+6.pem local-dev.crt
    mv _wildcard.local.dev+6-key.pem local-dev.key

    cd ../..

    log_info "Local SSL certificates generated successfully"
    log_info "Certificate: ./certs/local/local-dev.crt"
    log_info "Private Key: ./certs/local/local-dev.key"
}

# Create Kubernetes secret for local certificates
create_kubernetes_secret() {
    log_info "Creating Kubernetes secret for local SSL certificates..."

    kubectl create namespace 0xapogee --dry-run=client -o yaml | kubectl apply -f -

    kubectl create secret tls local-dev-tls \
        --cert=./certs/local/local-dev.crt \
        --key=./certs/local/local-dev.key \
        --namespace=blocksecops \
        --dry-run=client -o yaml | kubectl apply -f -

    log_info "Kubernetes TLS secret created successfully"
}

# Update /etc/hosts for local development
update_hosts_file() {
    log_info "Updating /etc/hosts file for local development..."

    # Backup existing hosts file
    sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

    # Remove existing local.dev entries
    sudo sed -i.bak '/\.local\.dev/d' /etc/hosts

    # Add new entries
    cat << EOF | sudo tee -a /etc/hosts

# Apogee Platform - Local Development
127.0.0.1 api.local.dev
127.0.0.1 data.local.dev
127.0.0.1 notifications.local.dev
127.0.0.1 monitoring.local.dev
127.0.0.1 argocd.local.dev
EOF

    log_info "/etc/hosts updated successfully"
    log_info "Local domains will resolve to 127.0.0.1"
}

# Main function
main() {
    log_info "Setting up SSL for local development environment..."

    install_mkcert
    setup_local_ca
    generate_local_certificates
    create_kubernetes_secret
    update_hosts_file

    log_info "Local SSL setup completed successfully!"
    log_info ""
    log_info "Local domains available:"
    log_info "  https://api.local.dev (with port-forward to 8000)"
    log_info "  https://data.local.dev (with port-forward to 8001)"
    log_info "  https://notifications.local.dev (with port-forward to 8002)"
    log_info "  https://monitoring.local.dev (with port-forward to 3001)"
    log_info "  https://argocd.local.dev (with port-forward to 8080)"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up local SSL configuration..."

    # Remove Kubernetes secret
    kubectl delete secret local-dev-tls --namespace=0xapogee --ignore-not-found=true

    # Remove certificates
    rm -rf ./certs/local

    # Restore hosts file
    if [ -f /etc/hosts.backup.* ]; then
        BACKUP_FILE=$(ls -t /etc/hosts.backup.* | head -n 1)
        sudo cp "$BACKUP_FILE" /etc/hosts
        log_info "Hosts file restored from backup"
    fi

    log_info "Local SSL cleanup completed"
}

# Handle command line arguments
case "${1:-setup}" in
    setup)
        main
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Usage: $0 [setup|cleanup]"
        exit 1
        ;;
esac
```

## cert-manager Installation and Configuration

### cert-manager Setup for Future Cloud Deployment
```yaml
# kubernetes/ssl/cert-manager.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    app.kubernetes.io/name: cert-manager
    app.kubernetes.io/part-of: cert-manager
---
# Install cert-manager CRDs
apiVersion: v1
kind: ConfigMap
metadata:
  name: cert-manager-install
  namespace: cert-manager
data:
  install.sh: |
    #!/bin/bash
    set -e

    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

    # Wait for cert-manager to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager

    echo "cert-manager installation completed"
---
# CloudFlare API Token Secret
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
type: Opaque
stringData:
  api-token: "YOUR_CLOUDFLARE_API_TOKEN"  # Replace with actual token
---
# Let's Encrypt ClusterIssuer for Staging
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # The ACME server URL
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: devops@advancedblockchainsecurity.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-staging
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          class: nginx
    # Enable the DNS-01 challenge provider
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
      selector:
        dnsNames:
        - "*.staging.advancedblockchainsecurity.com"
        - "staging.advancedblockchainsecurity.com"
---
# Let's Encrypt ClusterIssuer for Production
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: devops@advancedblockchainsecurity.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          class: nginx
    # Enable the DNS-01 challenge provider
    - dns01:
        cloudflare:
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
      selector:
        dnsNames:
        - "*.app.advancedblockchainsecurity.com"
        - "app.advancedblockchainsecurity.com"
        - "*.staging.advancedblockchainsecurity.com"
        - "staging.advancedblockchainsecurity.com"
```

### Certificate Definitions for Future Deployment
```yaml
# kubernetes/ssl/certificates.yaml
# Staging Environment Certificates
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: staging-wildcard-cert
  namespace: blocksecops
spec:
  secretName: staging-wildcard-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
  - "*.staging.advancedblockchainsecurity.com"
  - "staging.advancedblockchainsecurity.com"
---
# Production Environment Certificates
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: production-wildcard-cert
  namespace: blocksecops
spec:
  secretName: production-wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.app.advancedblockchainsecurity.com"
  - "app.advancedblockchainsecurity.com"
---
# Certificate for monitoring namespace
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: monitoring-cert
  namespace: monitoring
spec:
  secretName: monitoring-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "monitoring.app.advancedblockchainsecurity.com"
  - "monitoring.staging.advancedblockchainsecurity.com"
---
# Certificate for ArgoCD namespace
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-cert
  namespace: argocd
spec:
  secretName: argocd-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "argocd.app.advancedblockchainsecurity.com"
  - "argocd.staging.advancedblockchainsecurity.com"
```

## Ingress Configuration

### NGINX Ingress Controller Setup
```yaml
# kubernetes/ingress/nginx-ingress.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
---
# NGINX Ingress Controller Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
data:
  # SSL Configuration
  ssl-protocols: "TLSv1.2 TLSv1.3"
  ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
  ssl-prefer-server-ciphers: "true"
  ssl-session-cache: "shared:SSL:10m"
  ssl-session-timeout: "10m"

  # Security Headers
  add-headers: "blocksecops/security-headers"

  # Performance Configuration
  worker-processes: "auto"
  worker-connections: "1024"
  keepalive-timeout: "65"
  client-max-body-size: "100m"

  # Logging
  log-format-upstream: '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_length $request_time [$proxy_upstream_name] [$proxy_alternative_upstream_name] $upstream_addr $upstream_response_length $upstream_response_time $upstream_status $req_id'

  # Rate Limiting
  rate-limit-connections: "10"
  rate-limit-requests-per-second: "5"
---
# Security Headers ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-headers
  namespace: blocksecops
data:
  X-Frame-Options: "DENY"
  X-Content-Type-Options: "nosniff"
  X-XSS-Protection: "1; mode=block"
  Referrer-Policy: "strict-origin-when-cross-origin"
  Content-Security-Policy: "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' wss:;"
  Strict-Transport-Security: "max-age=31536000; includeSubDomains; preload"
  Permissions-Policy: "geolocation=(), microphone=(), camera=(), payment=(), usb=(), accelerometer=(), gyroscope=(), magnetometer=()"
```

### Local Development Ingress
```yaml
# kubernetes/ingress/local-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blocksecops-local
  namespace: blocksecops
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Frame-Options "DENY" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
spec:
  tls:
  - hosts:
    - api.local.dev
    - data.local.dev
    - notifications.local.dev
    - monitoring.local.dev
    - argocd.local.dev
    secretName: local-dev-tls
  rules:
  - host: api.local.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8000
  - host: data.local.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: data-service
            port:
              number: 8001
  - host: notifications.local.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: notification-service
            port:
              number: 8002
  - host: monitoring.local.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
  - host: argocd.local.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
```

### Staging Environment Ingress (Ready for Future Deployment)
```yaml
# kubernetes/ingress/staging-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blocksecops-staging
  namespace: blocksecops
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Frame-Options "DENY" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com;" always;
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  tls:
  - hosts:
    - api.staging.advancedblockchainsecurity.com
    - data.staging.advancedblockchainsecurity.com
    - notifications.staging.advancedblockchainsecurity.com
    secretName: staging-wildcard-tls
  rules:
  - host: api.staging.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8000
  - host: data.staging.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: data-service
            port:
              number: 8001
  - host: notifications.staging.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: notification-service
            port:
              number: 8002
```

### Production Environment Ingress (Ready for Future Deployment)
```yaml
# kubernetes/ingress/production-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blocksecops-production
  namespace: blocksecops
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/rate-limit: "1000"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://app.advancedblockchainsecurity.com"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Authorization, Content-Type, X-Requested-With"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      add_header X-Frame-Options "DENY" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header X-XSS-Protection "1; mode=block" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
      add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' wss:;" always;
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - api.app.advancedblockchainsecurity.com
    - data.app.advancedblockchainsecurity.com
    - notifications.app.advancedblockchainsecurity.com
    secretName: production-wildcard-tls
  rules:
  - host: api.app.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8000
  - host: data.app.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: data-service
            port:
              number: 8001
  - host: notifications.app.advancedblockchainsecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: notification-service
            port:
              number: 8002
```

## Certificate Monitoring and Automation

### Certificate Expiration Monitoring
```yaml
# kubernetes/monitoring/certificate-monitoring.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: certificate-expiration-alerts
  namespace: monitoring
  labels:
    app: prometheus
spec:
  groups:
  - name: certificate-expiration
    rules:
    - alert: CertificateExpiringSoon
      expr: (certmanager_certificate_expiration_timestamp_seconds - time()) / 86400 < 30
      for: 1h
      labels:
        severity: warning
        component: certificate
      annotations:
        summary: "Certificate expiring soon"
        description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} will expire in less than 30 days"

    - alert: CertificateExpiringSoon
      expr: (certmanager_certificate_expiration_timestamp_seconds - time()) / 86400 < 7
      for: 1h
      labels:
        severity: critical
        component: certificate
      annotations:
        summary: "Certificate expiring very soon"
        description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} will expire in less than 7 days"

    - alert: CertificateNotReady
      expr: certmanager_certificate_ready_status != 1
      for: 10m
      labels:
        severity: critical
        component: certificate
      annotations:
        summary: "Certificate not ready"
        description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} is not ready"

    - alert: CertManagerDown
      expr: up{job="cert-manager"} != 1
      for: 5m
      labels:
        severity: critical
        component: cert-manager
      annotations:
        summary: "cert-manager is down"
        description: "cert-manager has been down for more than 5 minutes"
---
# Certificate monitoring dashboard
apiVersion: v1
kind: ConfigMap
metadata:
  name: certificate-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Certificate Management",
        "tags": ["certificates", "ssl", "tls"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Certificate Expiration",
            "type": "graph",
            "targets": [
              {
                "expr": "(certmanager_certificate_expiration_timestamp_seconds - time()) / 86400",
                "legendFormat": "{{name}} ({{namespace}})"
              }
            ],
            "yAxes": [
              {
                "label": "Days until expiration"
              }
            ],
            "thresholds": [
              {
                "value": 30,
                "colorMode": "critical",
                "op": "lt"
              },
              {
                "value": 7,
                "colorMode": "critical",
                "op": "lt"
              }
            ]
          },
          {
            "id": 2,
            "title": "Certificate Status",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(certmanager_certificate_ready_status)",
                "legendFormat": "Ready Certificates"
              },
              {
                "expr": "count(certmanager_certificate_ready_status)",
                "legendFormat": "Total Certificates"
              }
            ]
          },
          {
            "id": 3,
            "title": "ACME Challenge Success Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(certmanager_acme_client_request_count{status=\"success\"}[5m])",
                "legendFormat": "Success Rate"
              },
              {
                "expr": "rate(certmanager_acme_client_request_count{status=\"error\"}[5m])",
                "legendFormat": "Error Rate"
              }
            ]
          }
        ],
        "time": {
          "from": "now-24h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
```

### Automated Certificate Health Checks
```bash
#!/bin/bash
# scripts/check-certificates.sh

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check certificate status in Kubernetes
check_kubernetes_certificates() {
    log_info "Checking Kubernetes certificate status..."

    # Get all certificates across namespaces
    certificates=$(kubectl get certificates -A -o json)

    if [ "$(echo "$certificates" | jq '.items | length')" -eq 0 ]; then
        log_warn "No certificates found in cluster"
        return
    fi

    echo "$certificates" | jq -r '.items[] |
        "\(.metadata.namespace)/\(.metadata.name): Ready=\(.status.conditions[]? | select(.type=="Ready") | .status), " +
        "Issuer=\(.spec.issuerRef.name), " +
        "DNS=\(.spec.dnsNames | join(","))"' | while read -r line; do

        if [[ $line == *"Ready=True"* ]]; then
            log_info "✓ $line"
        else
            log_error "✗ $line"
        fi
    done
}

# Check certificate expiration
check_certificate_expiration() {
    log_info "Checking certificate expiration dates..."

    # Local development certificates
    if [ -f "./certs/local/local-dev.crt" ]; then
        expiry=$(openssl x509 -in ./certs/local/local-dev.crt -noout -enddate | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry" +%s)
        current_epoch=$(date +%s)
        days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

        if [ $days_until_expiry -lt 7 ]; then
            log_error "Local certificate expires in $days_until_expiry days ($expiry)"
        elif [ $days_until_expiry -lt 30 ]; then
            log_warn "Local certificate expires in $days_until_expiry days ($expiry)"
        else
            log_info "Local certificate expires in $days_until_expiry days ($expiry)"
        fi
    fi
}

# Check domain resolution
check_domain_resolution() {
    log_info "Checking domain resolution..."

    local_domains=(
        "api.local.dev"
        "data.local.dev"
        "notifications.local.dev"
        "monitoring.local.dev"
        "argocd.local.dev"
    )

    for domain in "${local_domains[@]}"; do
        if nslookup "$domain" >/dev/null 2>&1; then
            ip=$(nslookup "$domain" | grep "Address:" | tail -1 | awk '{print $2}')
            if [ "$ip" = "127.0.0.1" ]; then
                log_info "✓ $domain resolves to $ip"
            else
                log_warn "△ $domain resolves to $ip (expected 127.0.0.1)"
            fi
        else
            log_error "✗ $domain does not resolve"
        fi
    done
}

# Check SSL connectivity
check_ssl_connectivity() {
    log_info "Checking SSL connectivity..."

    # Check if services are running and accessible
    services=(
        "localhost:8000:api.local.dev"
        "localhost:8001:data.local.dev"
        "localhost:8002:notifications.local.dev"
        "localhost:3001:monitoring.local.dev"
        "localhost:8080:argocd.local.dev"
    )

    for service in "${services[@]}"; do
        IFS=':' read -r host port domain <<< "$service"

        if curl -k -s --connect-timeout 5 "https://$host:$port/health" >/dev/null 2>&1; then
            log_info "✓ $domain SSL endpoint accessible"
        else
            log_warn "△ $domain SSL endpoint not accessible (service may not be running)"
        fi
    done
}

# Check cert-manager status
check_cert_manager_status() {
    log_info "Checking cert-manager status..."

    if kubectl get namespace cert-manager >/dev/null 2>&1; then
        # Check cert-manager deployments
        deployments=("cert-manager" "cert-manager-cainjector" "cert-manager-webhook")

        for deployment in "${deployments[@]}"; do
            if kubectl get deployment "$deployment" -n cert-manager >/dev/null 2>&1; then
                status=$(kubectl get deployment "$deployment" -n cert-manager -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
                if [ "$status" = "True" ]; then
                    log_info "✓ $deployment is available"
                else
                    log_error "✗ $deployment is not available"
                fi
            else
                log_warn "△ $deployment not found (not installed for local development)"
            fi
        done

        # Check ClusterIssuers
        if kubectl get clusterissuers >/dev/null 2>&1; then
            kubectl get clusterissuers -o json | jq -r '.items[] |
                "\(.metadata.name): Ready=\(.status.conditions[]? | select(.type=="Ready") | .status)"' | while read -r line; do

                if [[ $line == *"Ready=True"* ]]; then
                    log_info "✓ ClusterIssuer $line"
                else
                    log_warn "△ ClusterIssuer $line"
                fi
            done
        else
            log_warn "△ No ClusterIssuers found (expected for local development)"
        fi
    else
        log_warn "△ cert-manager namespace not found (not installed for local development)"
    fi
}

# Generate certificate status report
generate_report() {
    log_info "Generating certificate status report..."

    report_file="certificate-status-$(date +%Y%m%d_%H%M%S).json"

    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "environment": "local-development",
  "certificates": {
    "kubernetes": $(kubectl get certificates -A -o json 2>/dev/null || echo '{"items": []}'),
    "local_files": []
  },
  "domain_resolution": {},
  "ssl_connectivity": {},
  "cert_manager_status": {}
}
EOF

    log_info "Certificate status report saved to: $report_file"
}

# Main function
main() {
    log_info "Starting certificate health check..."

    check_kubernetes_certificates
    check_certificate_expiration
    check_domain_resolution
    check_ssl_connectivity
    check_cert_manager_status
    generate_report

    log_info "Certificate health check completed"
}

# Handle command line arguments
case "${1:-check}" in
    check)
        main
        ;;
    k8s)
        check_kubernetes_certificates
        ;;
    expiry)
        check_certificate_expiration
        ;;
    domains)
        check_domain_resolution
        ;;
    ssl)
        check_ssl_connectivity
        ;;
    cert-manager)
        check_cert_manager_status
        ;;
    *)
        echo "Usage: $0 [check|k8s|expiry|domains|ssl|cert-manager]"
        exit 1
        ;;
esac
```

## Security Headers and HTTPS Enforcement

### Enhanced Security Configuration
```yaml
# kubernetes/security/security-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: https-only-policy
  namespace: blocksecops
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 8443
---
# Pod Security Policy for HTTPS enforcement
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: https-required
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
```

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### SSL and Domain Structure
```
kubernetes/ssl/
├── cert-manager.yaml          # cert-manager installation and ClusterIssuers
├── certificates.yaml          # Certificate definitions for all environments
└── monitoring.yaml            # Certificate monitoring and alerting

kubernetes/ingress/
├── nginx-ingress.yaml         # NGINX Ingress Controller configuration
├── local-ingress.yaml         # Local development ingress rules
├── staging-ingress.yaml       # Staging environment ingress (ready)
└── production-ingress.yaml    # Production environment ingress (ready)

scripts/
├── setup-local-ssl.sh         # Local SSL certificate setup with mkcert
├── check-certificates.sh      # Certificate health monitoring script
└── deploy-ssl.sh              # SSL deployment automation

certs/
├── local/                     # Local development certificates
│   ├── local-dev.crt          # Local wildcard certificate
│   └── local-dev.key          # Local certificate private key
└── monitoring/                # Certificate monitoring scripts
    ├── cert-monitor.py         # Certificate expiration monitoring
    └── alert-configs.yaml     # Alerting configurations
```

### Features Implemented
- ✅ Local SSL certificate generation with mkcert for development
- ✅ cert-manager configuration for automated Let's Encrypt certificates
- ✅ NGINX Ingress Controller with security headers and SSL enforcement
- ✅ Domain structure supporting local, staging, and production environments
- ✅ CloudFlare DNS integration for DNS-01 challenge validation
- ✅ Certificate monitoring and expiration alerting
- ✅ Comprehensive security headers and HTTPS enforcement
- ✅ Automated certificate health checking and reporting
- ✅ Future-ready configurations for staging and production deployments

## Acceptance Criteria

### Local Development SSL
- [ ] Local SSL certificates generate successfully using mkcert
- [ ] All local domains (*.local.dev) resolve to 127.0.0.1
- [ ] HTTPS access works for all local services with trusted certificates
- [ ] Browser security warnings eliminated for local development
- [ ] /etc/hosts file updated correctly for local domain resolution

### Certificate Management
- [ ] cert-manager installed and configured for future cloud deployment
- [ ] ClusterIssuers configured for both staging and production Let's Encrypt
- [ ] Certificate definitions ready for staging and production domains
- [ ] DNS-01 challenge configured with CloudFlare API integration
- [ ] Certificate auto-renewal configured with proper monitoring

### Security Implementation
- [ ] NGINX Ingress Controller enforces HTTPS redirection
- [ ] Security headers properly configured (HSTS, CSP, X-Frame-Options, etc.)
- [ ] TLS 1.2+ protocols enforced with secure cipher suites
- [ ] Rate limiting configured to prevent abuse
- [ ] CORS policies configured for appropriate cross-origin access

### Monitoring and Operations
- [ ] Certificate expiration monitoring with 30-day and 7-day alerts
- [ ] Certificate status dashboard available in Grafana
- [ ] Automated health checks validate certificate and domain status
- [ ] Certificate renewal alerts notify of any issues
- [ ] Comprehensive logging of SSL/TLS connections and certificate events

This SSL configuration establishes secure HTTPS access for the local development environment while providing complete infrastructure readiness for future staging and production deployments with automated certificate management and comprehensive security enforcement.