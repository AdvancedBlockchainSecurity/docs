# Feature Test 82: CORS and Domain Regression Tests

**Date:** February 27, 2026
**Category:** Security / Infrastructure
**Status:** Automated (pytest)

## Overview

Automated regression test suites that prevent reintroduction of CORS wildcard origins and legacy domain references across all platform k8s configurations. These tests parse YAML files directly — no Kubernetes cluster required.

## Test Suites

### 1. Cross-Repo Regression Tests (41 tests)

**Location:** `blocksecops-api-service/tests/unit/infrastructure/test_domain_cors_regression.py`

**Run:** `pytest tests/unit/infrastructure/test_domain_cors_regression.py -v`

#### TestNoCORSWildcardAcrossRepos

Validates no `*` (wildcard) appears in CORS configuration across all 9 service repos.

| Test | What It Checks |
|------|---------------|
| `test_no_wildcard_cors_in_configmaps[<repo>]` | ConfigMap `CORS_ORIGINS` values are not wildcard |
| `test_no_wildcard_cors_in_middleware[<repo>]` | Traefik middleware `accessControlAllowOriginList` has no wildcard |
| `test_no_wildcard_cors_in_infra_repo` | gcp-infrastructure middleware files have no wildcard |

**Repos scanned:** api-service, notification, data-service, tool-integration, orchestration, intelligence-engine, contract-parser, dashboard, admin-portal

#### TestNoLegacyDomainsAcrossRepos

Validates no legacy domains remain in k8s YAML files.

| Test | What It Checks |
|------|---------------|
| `test_no_legacy_domains_in_k8s[<repo>]` | No `solidityops.com`, `soliditysecurity.dev`, `soliditysecurity.com`, or `blocksecops.com` |
| `test_no_blocksecops_local_except_harbor` | No `blocksecops.local` except `harbor.blocksecops.local` |

**Banned domain patterns:**
- `solidityops\.com`
- `soliditysecurity\.dev`
- `soliditysecurity\.com`
- `blocksecops\.com`
- `(?<!harbor\.)blocksecops\.local` (non-harbor references)

#### TestDashboardConfigMapURLs

| Test | What It Checks |
|------|---------------|
| `test_dashboard_configmap_urls_use_https` | All REACT_APP_* URLs in dashboard ConfigMap use HTTPS |
| `test_dashboard_configmap_no_legacy_domains` | No legacy domains in dashboard ConfigMap |
| `test_dashboard_configmap_uses_current_domain` | Dashboard ConfigMap URLs use `0xapogee` domain |

#### TestAPIServiceCORSDefaults

| Test | What It Checks |
|------|---------------|
| `test_base_configmap_cors_no_wildcard` | API service base configmap CORS is not wildcard |
| `test_base_configmap_cors_uses_https` | CORS origins use HTTPS |
| `test_base_configmap_allowed_hosts_no_wildcard` | allowed_hosts is not wildcard |
| `test_base_configmap_no_legacy_domains` | No legacy domains in base configmap |
| `test_ingress_patch_cors_no_wildcard` | nginx CORS annotation is not wildcard |

#### TestIngressRouteHostRules

| Test | What It Checks |
|------|---------------|
| `test_api_ingressroute_uses_current_domain` | API IngressRoute Host() uses `0xapogee` |
| `test_dashboard_ingressroute_uses_current_domain` | Dashboard IngressRoute Host() uses `0xapogee` or `localhost` |
| `test_tool_integration_ingressroute_uses_current_domain` | Tool Integration IngressRoute uses `0xapogee` |
| `test_notification_ingressroute_uses_current_domain` | Notification IngressRoute uses `0xapogee` |

---

### 2. Notification Service Tests (23 tests)

**Location:** `blocksecops-notification/tests/unit/infrastructure/`

**Run:** `pytest tests/unit/infrastructure/ -v`

#### test_config.py (14 tests)

| Test Class | Tests | What It Checks |
|-----------|-------|---------------|
| `TestSettingsDefaults` | 4 | Default values for app_name, cors_origins, ws_port, redis_url |
| `TestCORSOriginsValidation` | 6 | Wildcard rejection, HTTPS requirement, multiple origins, production domain, empty origin rejection |
| `TestSettingsFromEnvironment` | 2 | Environment variable overrides work correctly |
| `TestSettingsCaching` | 2 | Settings caching and cache clearing |

#### test_k8s_config_regression.py (9 tests)

| Test Class | Tests | What It Checks |
|-----------|-------|---------------|
| `TestNoCORSWildcard` | 3 | Local ConfigMap, notification ConfigMap, and CORS HTTPS requirement |
| `TestNoWildcardInTraefikMiddleware` | 3 | Middleware origins no wildcard, HTTPS, credentials disabled |
| `TestNoLegacyDomains` | 3 | No legacy domains in k8s YAML, IngressRoute uses current domain, base ingress uses current domain |

---

## Manual Verification (Optional)

### CORS Headers via Traefik

```bash
# Verify correct origin is reflected
curl -sk -X OPTIONS \
  -H "Origin: https://app.0xapogee.local" \
  -H "Access-Control-Request-Method: GET" \
  https://app.0xapogee.local/api/v1/health/live -I \
  | grep -i access-control

# Expected:
# access-control-allow-origin: https://app.0xapogee.local
# access-control-allow-methods: GET, POST, OPTIONS
# access-control-allow-headers: Content-Type, Authorization, ...

# Verify bad origin is rejected
curl -sk -X OPTIONS \
  -H "Origin: https://evil.example.com" \
  -H "Access-Control-Request-Method: GET" \
  https://app.0xapogee.local/api/v1/health/live -I \
  | grep -i access-control-allow-origin

# Expected: no access-control-allow-origin header
```

### Legacy Domain Scan

```bash
# Quick scan for any remaining legacy domains in k8s configs
grep -r "solidityops\|soliditysecurity" ~/Git/blocksecops-*/k8s/ --include="*.yaml" -l
# Expected: no results

# Check for non-harbor blocksecops.local
grep -rP '(?<!harbor\.)blocksecops\.local' ~/Git/blocksecops-*/k8s/ --include="*.yaml" -l
# Expected: no results
```

## Test Results (February 27, 2026)

| Suite | Tests | Passed | Failed |
|-------|-------|--------|--------|
| Cross-repo regression | 41 | 41 | 0 |
| Notification config | 14 | 14 | 0 |
| Notification k8s regression | 9 | 9 | 0 |
| **Total** | **64** | **64** | **0** |
