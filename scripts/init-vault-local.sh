#!/bin/bash
#
# Vault Local Development Initialization Script
#
# This script populates HashiCorp Vault with secrets required for local development.
# It must be run after Vault is deployed and unsealed in the Minikube cluster.
#
# Usage:
#   ./scripts/init-vault-local.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Vault Local Development Initialization${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if Vault pod is running
echo -e "${YELLOW}Checking Vault status...${NC}"
if ! kubectl get pod -n vault-local vault-0 &>/dev/null; then
    echo -e "${RED}Error: Vault pod not found in vault-local namespace${NC}"
    echo "Please deploy Vault first:"
    echo "  kubectl apply -k /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/vault/"
    exit 1
fi

# Wait for Vault to be ready
echo -e "${YELLOW}Waiting for Vault pod to be ready...${NC}"
kubectl wait --for=condition=ready pod/vault-0 -n vault-local --timeout=60s

# Check if Vault is unsealed
VAULT_SEALED=$(kubectl exec -n vault-local vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed')
if [ "$VAULT_SEALED" = "true" ]; then
    echo -e "${RED}Error: Vault is sealed${NC}"
    echo "Vault must be unsealed before initializing secrets"
    exit 1
fi

echo -e "${GREEN}✓ Vault is running and unsealed${NC}"
echo

# Function to put secrets into Vault
vault_kv_put() {
    local path=$1
    shift
    echo -e "${YELLOW}  → Writing secrets to ${path}${NC}"
    kubectl exec -n vault-local vault-0 -- vault kv put "$path" "$@" >/dev/null
}

echo -e "${BLUE}Populating Vault with local development secrets...${NC}"
echo

# ============================================
# Infrastructure Secrets (Shared)
# ============================================
echo -e "${BLUE}[1/7] Infrastructure secrets...${NC}"

# PostgreSQL (shared across all services)
# Path: secret/postgresql - ESO with version: v2 handles /data/ prefix automatically
vault_kv_put "secret/postgresql" \
    POSTGRES_DB="solidity_security" \
    POSTGRES_USER="postgres" \
    POSTGRES_PASSWORD="postgres" \
    POSTGRES_REPLICATION_USER="replicator" \
    POSTGRES_REPLICATION_PASSWORD="replicator-password"

# Redis (shared across all services)
# Path: secret/redis - ESO with version: v2 handles /data/ prefix automatically
vault_kv_put "secret/redis" \
    password="redis123"

echo -e "${GREEN}✓ Infrastructure secrets populated${NC}"
echo

# ============================================
# API Service Secrets
# ============================================
echo -e "${BLUE}[2/7] API Service secrets...${NC}"

# JWT Configuration
vault_kv_put "secret/local/api-service/jwt" \
    secret_key="local-dev-jwt-secret-key-change-in-production"

# Session Configuration
vault_kv_put "secret/local/api-service/session" \
    secret="local-dev-session-secret-change-in-production"

# OAuth Configuration (optional)
vault_kv_put "secret/local/api-service/oauth" \
    client_id="local-dev-oauth-client-id" \
    client_secret="local-dev-oauth-client-secret"

echo -e "${GREEN}✓ API Service secrets populated${NC}"
echo

# ============================================
# Data Service Secrets
# ============================================
echo -e "${BLUE}[3/7] Data Service secrets...${NC}"

vault_kv_put "secret/local/data-service/database" \
    username="postgres" \
    password="postgres" \
    host="postgresql.postgresql-local.svc.cluster.local" \
    port="5432" \
    name="solidity_security"

vault_kv_put "secret/local/data-service/database-read" \
    username="postgres" \
    password="postgres" \
    host="postgresql.postgresql-local.svc.cluster.local" \
    port="5432"

vault_kv_put "secret/local/data-service/redis" \
    host="redis-master.redis-local.svc.cluster.local" \
    port="6379" \
    password="redis123"

vault_kv_put "secret/local/data-service/encryption" \
    key="local-dev-encryption-key-change-in-production"

vault_kv_put "secret/local/data-service/vault" \
    token="dev-only-token"

echo -e "${GREEN}✓ Data Service secrets populated${NC}"
echo

# ============================================
# Tool Integration Secrets
# ============================================
echo -e "${BLUE}[4/7] Tool Integration secrets...${NC}"

vault_kv_put "secret/local/tool-integration/credentials" \
    credentials="local-dev-tool-credentials"

vault_kv_put "secret/local/tool-integration/redis" \
    host="redis-master.redis-local.svc.cluster.local" \
    port="6379" \
    password="redis123"

vault_kv_put "secret/local/tool-integration/database" \
    user="postgres" \
    password="postgres" \
    host="postgresql.postgresql-local.svc.cluster.local" \
    port="5432" \
    name="solidity_security"

echo -e "${GREEN}✓ Tool Integration secrets populated${NC}"
echo

# ============================================
# Notification Service Secrets
# ============================================
echo -e "${BLUE}[5/7] Notification Service secrets...${NC}"

vault_kv_put "secret/local/notification/database" \
    username="postgres" \
    password="postgres" \
    host="postgresql.postgresql-local.svc.cluster.local" \
    port="5432" \
    name="solidity_security"

vault_kv_put "secret/local/notification/redis" \
    host="redis-master.redis-local.svc.cluster.local" \
    port="6379" \
    password="redis123"

vault_kv_put "secret/local/notification/smtp" \
    host="localhost" \
    port="587" \
    user="" \
    password=""

vault_kv_put "secret/local/notification/webhooks" \
    slack_url="" \
    teams_url="" \
    discord_url="" \
    webhook_secret=""

echo -e "${GREEN}✓ Notification Service secrets populated${NC}"
echo

# ============================================
# Orchestration Service Secrets (if needed)
# ============================================
echo -e "${BLUE}[6/7] Orchestration Service secrets...${NC}"

vault_kv_put "secret/local/orchestration/database" \
    username="postgres" \
    password="postgres" \
    host="postgresql.postgresql-local.svc.cluster.local" \
    port="5432" \
    name="solidity_security"

vault_kv_put "secret/local/orchestration/redis" \
    host="redis-master.redis-local.svc.cluster.local" \
    port="6379" \
    password="redis123"

echo -e "${GREEN}✓ Orchestration Service secrets populated${NC}"
echo

# ============================================
# Intelligence Engine Secrets
# ============================================
echo -e "${BLUE}[7/7] Intelligence Engine secrets...${NC}"

# Database URL (asyncpg format)
vault_kv_put "secret/local/intelligence-engine/database" \
    url="postgresql+asyncpg://postgres:postgres@postgresql.postgresql-local.svc.cluster.local:5432/solidity_security"

# Redis URL
vault_kv_put "secret/local/intelligence-engine/redis" \
    url="redis://:redis123@redis-master.redis-local.svc.cluster.local:6379/0"

# ML Model API Key (placeholder for local development)
vault_kv_put "secret/local/intelligence-engine/ml" \
    api_key="local-dev-ml-api-key-placeholder"

# API Service URL (internal cluster URL)
vault_kv_put "secret/local/intelligence-engine/api" \
    url="http://api-service.api-service-local.svc.cluster.local:8000"

echo -e "${GREEN}✓ Intelligence Engine secrets populated${NC}"
echo

# ============================================
# Verification
# ============================================
echo -e "${BLUE}Verifying secrets were created...${NC}"
echo

SECRET_PATHS=(
    "secret/postgresql"
    "secret/redis"
    "secret/local/api-service/jwt"
    "secret/local/api-service/session"
    "secret/local/data-service/database"
    "secret/local/tool-integration/database"
    "secret/local/notification/database"
    "secret/local/orchestration/database"
    "secret/local/intelligence-engine/database"
)

FAILED=0
for path in "${SECRET_PATHS[@]}"; do
    if kubectl exec -n vault-local vault-0 -- vault kv get "$path" &>/dev/null; then
        echo -e "${GREEN}  ✓ ${path}${NC}"
    else
        echo -e "${RED}  ✗ ${path}${NC}"
        FAILED=1
    fi
done

echo

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ Vault initialization complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Verify External Secrets are syncing:"
    echo "     kubectl get externalsecrets -A"
    echo
    echo "  2. Check for any sync errors:"
    echo "     kubectl describe externalsecret -n api-service-local api-service-secrets"
    echo
    echo "  3. Verify secrets were created:"
    echo "     kubectl get secrets -n api-service-local | grep vault"
    echo
    echo -e "${YELLOW}Note: External Secrets will sync automatically within 30 seconds.${NC}"
    echo
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ Some secrets failed to create${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
