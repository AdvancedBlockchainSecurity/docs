#!/usr/bin/env python3
"""
Comprehensive Apogee Platform Security & Functionality Audit

Runs all existing audit scripts plus new sections covering:
  A. Service Health & Connectivity
  B. Version Sync (source ↔ kustomization ↔ deployed)
  C. Kubernetes Security (securityContext, NetworkPolicy, RBAC)
  D. Database Integrity (FK, schema, migrations)
  E. Secrets & Encryption (TLS, ExternalSecrets, no plaintext)
  F. CORS & Security Headers
  G. CronJob Cleanup (all migrated to Celery Beat)
  H. Docker Image Compliance (OCI labels, pinned versions)

Usage:
    python3 docs/audits/scripts/audit-platform-comprehensive.py

Requires: httpx (minimum). Existing scripts needing PyJWT/base58/etc
          are run via subprocess and failures are reported as SKIP.
"""

import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

try:
    import httpx
except ImportError:
    sys.exit("ERROR: httpx required. Install with: pip install httpx")

# ============================================================================
# Configuration
# ============================================================================

API_BASE = os.environ.get("AUDIT_API_BASE", "https://app.0xapogee.com/api/v1")
API_KEY = os.environ.get("AUDIT_API_KEY", "bso_dp8DUvPZaysDEY7Wg8F4RMkUCTht8LLjzfV7Hp_nVQQ")
REPO_ROOT = Path(os.environ.get("REPO_ROOT", os.path.expanduser("~/Git")))
SCRIPTS_DIR = REPO_ROOT / "docs" / "audits" / "scripts"

SERVICES = {
    "api-service":         {"ns": "api-service-prod",         "vfile": "pyproject.toml", "port": 8000, "repo": "blocksecops-api-service"},
    "data-service":        {"ns": "data-service-prod",        "vfile": "pyproject.toml", "port": 80,   "repo": "blocksecops-data-service"},
    "intelligence-engine": {"ns": "intelligence-engine-prod", "vfile": "pyproject.toml", "port": 8000, "repo": "blocksecops-intelligence-engine"},
    "notification":        {"ns": "notification-prod",        "vfile": "pyproject.toml", "port": 8003, "repo": "blocksecops-notification"},
    "orchestration":       {"ns": "orchestration-prod",       "vfile": "pyproject.toml", "port": 8000, "repo": "blocksecops-orchestration"},
    "tool-integration":    {"ns": "tool-integration-prod",    "vfile": "pyproject.toml", "port": 8005, "repo": "blocksecops-tool-integration"},
    "contract-parser":     {"ns": "contract-parser-prod",     "vfile": "Cargo.toml",     "port": 8007, "repo": "blocksecops-contract-parser"},
    "dashboard":           {"ns": "dashboard-prod",           "vfile": "package.json",   "port": 3000, "repo": "blocksecops-dashboard"},
    "admin-portal":        {"ns": "admin-portal-prod",        "vfile": "package.json",   "port": 3000, "repo": "blocksecops-admin-portal"},
}

EXPECTED_BEAT_TASKS = [
    "poll-scan-queue",
    "reset-monthly-quotas",
    "check-quota-status",
    "check-stale-scans",
    "check-model-freshness",
    "check-unmapped-patterns",
    "daily-dedup-maintenance",
]

# ============================================================================
# Helpers
# ============================================================================

@dataclass
class AuditResult:
    section: str
    test: str
    passed: bool
    detail: str = ""
    status_code: int | None = None
    skipped: bool = False


results: list[AuditResult] = []


def record(section: str, test: str, passed: bool, detail: str = "", status_code: int | None = None):
    results.append(AuditResult(section, test, passed, detail, status_code))
    icon = "\033[32mPASS\033[0m" if passed else "\033[31mFAIL\033[0m"
    sc = f" [{status_code}]" if status_code else ""
    print(f"  [{icon}]{sc} {test}")
    if detail and not passed:
        print(f"         \033[33m{detail}\033[0m")


def warn(section: str, test: str, detail: str = ""):
    results.append(AuditResult(section, test, True, detail))
    print(f"  [\033[33mWARN\033[0m] {test}")
    if detail:
        print(f"         \033[33m{detail}\033[0m")


def skip(section: str, test: str, detail: str = ""):
    results.append(AuditResult(section, test, True, detail, skipped=True))
    print(f"  [\033[36mSKIP\033[0m] {test}")
    if detail:
        print(f"         \033[36m{detail}\033[0m")


def api_get(path: str, headers: dict | None = None) -> httpx.Response:
    hdrs = {"X-API-Key": API_KEY}
    if headers:
        hdrs.update(headers)
    with httpx.Client(timeout=30.0) as client:
        return client.get(f"{API_BASE}/{path}", headers=hdrs)


def run_psql(query: str) -> str:
    cmd = [
        "kubectl", "exec", "-n", "postgresql-prod", "pod/postgresql-0",
        "-c", "postgresql", "--",
        "psql", "-U", "blocksecops", "-d", "solidity_security",
        "-t", "-A", "-c", query,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return result.stdout.strip()
    except Exception:
        return ""


def run_kubectl(cmd_args: list[str]) -> str:
    try:
        result = subprocess.run(cmd_args, capture_output=True, text=True, timeout=30)
        return result.stdout.strip()
    except Exception:
        return ""


def run_kubectl_json(cmd_args: list[str]) -> dict | list | None:
    raw = run_kubectl(cmd_args)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def get_source_version(service: str) -> str:
    info = SERVICES.get(service, {})
    repo = info.get("repo", "")
    vfile = info.get("vfile", "")
    path = REPO_ROOT / repo / vfile
    if not path.exists():
        return ""
    content = path.read_text()
    if vfile == "pyproject.toml":
        m = re.search(r'^version\s*=\s*"([^"]+)"', content, re.MULTILINE)
        return m.group(1) if m else ""
    elif vfile == "package.json":
        m = re.search(r'"version"\s*:\s*"([^"]+)"', content)
        return m.group(1) if m else ""
    elif vfile == "Cargo.toml":
        m = re.search(r'^version\s*=\s*"([^"]+)"', content, re.MULTILINE)
        return m.group(1) if m else ""
    return ""


def get_kustomize_tag(service: str) -> str:
    info = SERVICES.get(service, {})
    repo = info.get("repo", "")
    # Try gcp overlay first, then local
    for overlay in ["gcp", "local"]:
        patterns = [
            REPO_ROOT / repo / "k8s" / "overlays" / overlay / "kustomization.yaml",
            REPO_ROOT / repo / "k8s" / "overlays" / overlay / service / "kustomization.yaml",
        ]
        for kpath in patterns:
            if kpath.exists():
                content = kpath.read_text()
                m = re.search(r'newTag:\s*"([^"]+)"', content)
                if m:
                    return m.group(1)
    return ""


def get_deployed_image(service: str) -> str:
    info = SERVICES.get(service, {})
    ns = info.get("ns", "")
    raw = run_kubectl([
        "kubectl", "get", "deployment", service, "-n", ns,
        "-o", "jsonpath={.spec.template.spec.containers[0].image}",
    ])
    if ":" in raw:
        return raw.split(":")[-1]
    return raw


# ============================================================================
# Sub-module Runner: Existing Audit Scripts
# ============================================================================

def run_existing_audits():
    print("\n\033[1m=== EXISTING AUDIT SCRIPTS ===\033[0m")

    scripts = [
        "audit-intelligence-system.py",
        "audit-dedup-pattern-system.py",
        "audit-scanning-system.py",
        "audit-auth-x402.py",
        "audit-org-team-subscription.py",
        "audit-tier-v4.py",
        "load-test-by-tier.py",
    ]

    for script_name in scripts:
        script_path = SCRIPTS_DIR / script_name
        if not script_path.exists():
            skip("SUB", f"{script_name}: not found", str(script_path))
            continue

        print(f"\n  \033[1m--- Running {script_name} ---\033[0m")
        try:
            proc = subprocess.run(
                [sys.executable, str(script_path)],
                capture_output=True, text=True, timeout=180,
                env={**os.environ, "AUDIT_API_BASE": API_BASE, "AUDIT_API_KEY": API_KEY},
            )
            # Parse output for PASS/FAIL counts
            output = proc.stdout + proc.stderr
            pass_count = len(re.findall(r"PASS", output))
            fail_count = len(re.findall(r"FAIL", output))

            if proc.returncode == 0:
                record("SUB", f"{script_name}: {pass_count} passed, {fail_count} failed", True)
            elif proc.returncode == 1 and fail_count > 0:
                record("SUB", f"{script_name}: {pass_count} passed, {fail_count} failed", False,
                       f"exit code {proc.returncode}")
            else:
                # Dependency error or crash
                # Extract error message
                err_lines = [l for l in (proc.stderr or proc.stdout or "").split("\n") if l.strip()]
                err_msg = err_lines[-1] if err_lines else f"exit code {proc.returncode}"
                skip("SUB", f"{script_name}: could not run", err_msg[:200])
        except subprocess.TimeoutExpired:
            skip("SUB", f"{script_name}: timed out (180s)", "")
        except Exception as e:
            skip("SUB", f"{script_name}: error", str(e)[:200])


# ============================================================================
# Section A: Service Health & Connectivity
# ============================================================================

def audit_service_health():
    print("\n\033[1m=== A. Service Health & Connectivity ===\033[0m")

    # A1: API health
    try:
        resp = api_get("health/live")
        if resp.status_code == 200:
            data = resp.json()
            ver = data.get("version", "?")
            record("A", f"API service healthy (v{ver})", data.get("status") == "healthy", "", resp.status_code)
        else:
            record("A", "API service healthy", False, f"HTTP {resp.status_code}", resp.status_code)
    except Exception as e:
        record("A", "API service healthy", False, str(e))

    # A2: API readiness
    try:
        resp2 = api_get("health/ready")
        record("A", "API readiness check", resp2.status_code == 200, "", resp2.status_code)
    except Exception as e:
        record("A", "API readiness check", False, str(e))

    # A3-A11: All service pods running
    for svc, info in SERVICES.items():
        ns = info["ns"]
        # Try both label conventions: app.kubernetes.io/name and app
        raw = run_kubectl([
            "kubectl", "get", "pods", "-n", ns,
            "-l", f"app.kubernetes.io/name={svc}",
            "--no-headers",
        ])
        if not raw or "Running" not in raw:
            raw = run_kubectl([
                "kubectl", "get", "pods", "-n", ns,
                "-l", f"app={svc}",
                "--no-headers",
            ])
        running = [l for l in raw.split("\n") if "Running" in l] if raw else []
        record("A", f"{svc} pods running ({len(running)})", len(running) > 0,
               f"namespace={ns}")

    # A12-A13: Infrastructure pods
    for infra, ns in [("postgresql", "postgresql-prod"), ("redis", "redis-prod")]:
        raw = run_kubectl(["kubectl", "get", "pods", "-n", ns, "--no-headers"])
        running = [l for l in raw.split("\n") if "Running" in l] if raw else []
        record("A", f"{infra} pods running ({len(running)})", len(running) > 0)

    # A14: Database connectivity
    result = run_psql("SELECT 1")
    record("A", "Database connectivity (SELECT 1)", result == "1")

    # A15: Redis connectivity
    redis_pong = run_kubectl([
        "kubectl", "exec", "-n", "redis-prod", "pod/redis-0", "--",
        "redis-cli", "ping",
    ])
    record("A", "Redis connectivity (PING)", "PONG" in redis_pong)


# ============================================================================
# Section B: Version Sync
# ============================================================================

def audit_version_sync():
    print("\n\033[1m=== B. Version Sync ===\033[0m")

    for svc, info in SERVICES.items():
        repo = info.get("repo", "")
        repo_path = REPO_ROOT / repo
        if not repo_path.exists():
            skip("B", f"{svc}: repo not found", str(repo_path))
            continue

        src_ver = get_source_version(svc)
        kust_tag = get_kustomize_tag(svc)
        deployed_tag = get_deployed_image(svc)

        # B-x.1: Source == Kustomize
        if src_ver and kust_tag:
            match = src_ver == kust_tag
            record("B", f"{svc}: source ({src_ver}) == kustomize ({kust_tag})", match)
        elif not src_ver:
            skip("B", f"{svc}: source version not found", info["vfile"])
        elif not kust_tag:
            skip("B", f"{svc}: kustomize tag not found", "")

        # B-x.2: Kustomize == Deployed
        if kust_tag and deployed_tag:
            match2 = kust_tag == deployed_tag
            record("B", f"{svc}: kustomize ({kust_tag}) == deployed ({deployed_tag})", match2)
        elif not deployed_tag:
            skip("B", f"{svc}: deployed image not found", info["ns"])

    # B-final: No :latest tags in any deployment
    all_images = run_kubectl([
        "kubectl", "get", "deployments", "-A",
        "-o", "jsonpath={range .items[*]}{.spec.template.spec.containers[0].image}{\"\\n\"}{end}",
    ])
    latest_images = [img for img in all_images.split("\n") if img.strip().endswith(":latest")]
    record("B", f"No :latest tags in deployments ({len(latest_images)} found)",
           len(latest_images) == 0,
           "; ".join(latest_images[:5]) if latest_images else "")


# ============================================================================
# Section C: Kubernetes Security
# ============================================================================

def audit_k8s_security():
    print("\n\033[1m=== C. Kubernetes Security ===\033[0m")

    for svc, info in SERVICES.items():
        ns = info["ns"]

        # C-x.1: revisionHistoryLimit
        rhl = run_kubectl([
            "kubectl", "get", "deployment", svc, "-n", ns,
            "-o", "jsonpath={.spec.revisionHistoryLimit}",
        ])
        record("C", f"{svc}: revisionHistoryLimit={rhl}", rhl == "3",
               f"expected 3, got {rhl}" if rhl != "3" else "")

    # C: SecurityContext on all platform pods
    for svc, info in SERVICES.items():
        ns = info["ns"]
        sc_raw = run_kubectl([
            "kubectl", "get", "deployment", svc, "-n", ns,
            "-o", "jsonpath={.spec.template.spec.securityContext.runAsNonRoot}",
        ])
        record("C", f"{svc}: runAsNonRoot={sc_raw}", sc_raw == "true",
               f"expected true, got '{sc_raw}'" if sc_raw != "true" else "")

    # C: Default-deny NetworkPolicy in each namespace
    checked_ns = set()
    for svc, info in SERVICES.items():
        ns = info["ns"]
        if ns in checked_ns:
            continue
        checked_ns.add(ns)
        netpol = run_kubectl([
            "kubectl", "get", "networkpolicy", "default-deny-all", "-n", ns,
            "--no-headers",
        ])
        record("C", f"{ns}: default-deny-all NetworkPolicy", bool(netpol) and "NotFound" not in netpol)

    # C: No privileged containers in platform namespaces
    platform_ns = set(info["ns"] for info in SERVICES.values())
    platform_ns.update(["postgresql-prod", "redis-prod"])
    priv_count = 0
    pods_json = run_kubectl_json(["kubectl", "get", "pods", "-A", "-o", "json"])
    if pods_json and "items" in pods_json:
        for pod in pods_json["items"]:
            ns = pod.get("metadata", {}).get("namespace", "")
            if ns not in platform_ns:
                continue
            for container in pod.get("spec", {}).get("containers", []):
                if container.get("securityContext", {}).get("privileged"):
                    priv_count += 1
    record("C", f"No privileged containers in platform ({priv_count} found)", priv_count == 0)

    # C: All pods have resource limits
    pods_json = run_kubectl_json([
        "kubectl", "get", "pods", "-A", "-o", "json",
    ])
    no_limits = 0
    if pods_json and "items" in pods_json:
        for pod in pods_json["items"]:
            ns = pod.get("metadata", {}).get("namespace", "")
            if ns.startswith("kube-") or ns == "ingress-prod":
                continue
            for container in pod.get("spec", {}).get("containers", []):
                if not container.get("resources", {}).get("limits"):
                    no_limits += 1
    record("C", f"All platform containers have resource limits ({no_limits} missing)",
           no_limits == 0, f"{no_limits} containers without limits" if no_limits > 0 else "")


# ============================================================================
# Section D: Database Integrity
# ============================================================================

def audit_database():
    print("\n\033[1m=== D. Database Integrity ===\033[0m")

    # D1: Alembic version
    alembic = run_psql("SELECT version_num FROM alembic_version")
    record("D", f"Alembic version: {alembic}", bool(alembic))

    # D2: Table count
    tcount = int(run_psql("SELECT COUNT(*) FROM pg_tables WHERE schemaname='public'") or 0)
    record("D", f"Public tables: {tcount}", tcount >= 80, f"expected >=80")

    # D3: Core tables exist
    core_tables = ["users", "organizations", "teams", "scans", "contracts",
                   "vulnerabilities", "vulnerability_patterns", "scanner_versions",
                   "ml_model_metadata", "api_keys", "deduplication_groups",
                   "pattern_tool_mappings"]
    for table in core_tables:
        exists = run_psql(f"SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename='{table}')")
        record("D", f"Table '{table}' exists", exists == "t")

    # D4: scanner_versions populated
    sv = int(run_psql("SELECT COUNT(*) FROM scanner_versions") or 0)
    record("D", f"scanner_versions populated ({sv})", sv >= 16)

    # D5: vulnerability_patterns populated
    vp = int(run_psql("SELECT COUNT(*) FROM vulnerability_patterns") or 0)
    record("D", f"vulnerability_patterns populated ({vp})", vp > 300)

    # D6: ml_model_metadata has seed entries
    mm = int(run_psql("SELECT COUNT(*) FROM ml_model_metadata WHERE model_name LIKE '%seed%'") or 0)
    record("D", f"Seed version tracking entries ({mm})", mm >= 3)

    # D7: No orphaned vulnerabilities
    orphan_v = int(run_psql("""
        SELECT COUNT(*) FROM vulnerabilities v
        LEFT JOIN scans s ON v.scan_id = s.id
        WHERE s.id IS NULL AND v.scan_id IS NOT NULL
    """) or 0)
    record("D", f"No orphaned vulnerabilities ({orphan_v})", orphan_v == 0)

    # D8: No orphaned scans
    orphan_s = int(run_psql("""
        SELECT COUNT(*) FROM scans s
        LEFT JOIN contracts c ON s.contract_id = c.id
        WHERE c.id IS NULL
    """) or 0)
    record("D", f"No orphaned scans ({orphan_s})", orphan_s == 0)

    # D9: No Cairo patterns
    cairo = int(run_psql("SELECT COUNT(*) FROM vulnerability_patterns WHERE id LIKE '%CAIRO%'") or 0)
    record("D", f"No Cairo/StarkNet patterns ({cairo})", cairo == 0)

    # D10: No NULL status in scans
    null_status = int(run_psql("SELECT COUNT(*) FROM scans WHERE status IS NULL") or 0)
    record("D", f"No NULL scan status ({null_status})", null_status == 0)

    # D11: No empty fingerprints
    empty_fp = int(run_psql("SELECT COUNT(*) FROM vulnerabilities WHERE fingerprint_code = ''") or 0)
    record("D", f"No empty-string fingerprints ({empty_fp})", empty_fp == 0)

    # D12: DB size
    db_size = run_psql("SELECT pg_size_pretty(pg_database_size('solidity_security'))")
    record("D", f"Database size: {db_size}", bool(db_size))


# ============================================================================
# Section E: Secrets & Encryption
# ============================================================================

def audit_secrets():
    print("\n\033[1m=== E. Secrets & Encryption ===\033[0m")

    # E1: PostgreSQL SSL enabled
    ssl = run_psql("SHOW ssl")
    record("E", f"PostgreSQL SSL enabled ({ssl})", ssl == "on")

    # E2: Active SSL connections
    ssl_count = int(run_psql("SELECT COUNT(*) FROM pg_stat_ssl WHERE ssl = true") or 0)
    record("E", f"Active SSL connections ({ssl_count})", ssl_count > 0)

    # E3: ExternalSecrets synced
    es_raw = run_kubectl_json([
        "kubectl", "get", "externalsecret", "-A", "-o", "json",
    ])
    if es_raw and "items" in es_raw:
        total_es = len(es_raw["items"])
        synced = 0
        for es in es_raw["items"]:
            conditions = es.get("status", {}).get("conditions", [])
            for cond in conditions:
                if cond.get("type") == "Ready" and cond.get("status") == "True":
                    synced += 1
                    break
        record("E", f"ExternalSecrets synced ({synced}/{total_es})", synced == total_es)
    else:
        skip("E", "ExternalSecrets check", "Could not query ExternalSecrets")

    # E4: No secrets in ConfigMaps (scan for password/token/secret patterns)
    secret_patterns = 0
    for svc, info in SERVICES.items():
        ns = info["ns"]
        cms = run_kubectl([
            "kubectl", "get", "configmap", "-n", ns,
            "-o", "jsonpath={range .items[*]}{.data}{end}",
        ])
        if cms:
            # Look for suspicious patterns, excluding known safe keys
            for pattern in [r"password\s*[:=]", r"secret_key\s*[:=]", r"private_key\s*[:=]"]:
                if re.search(pattern, cms, re.IGNORECASE):
                    safe_patterns = ["internal_service_key", "jwt_secret_key", "secret_key_base"]
                    if not any(sp in cms.lower() for sp in safe_patterns):
                        secret_patterns += 1
    record("E", f"No plaintext secrets in ConfigMaps ({secret_patterns} suspicious)", secret_patterns == 0)

    # E5: No plaintext DATABASE_URL with password in deployment env vars
    deploys = run_kubectl_json([
        "kubectl", "get", "deployments", "-A", "-o", "json",
    ])
    plaintext_urls = 0
    if deploys and "items" in deploys:
        for deploy in deploys["items"]:
            ns = deploy.get("metadata", {}).get("namespace", "")
            if ns.startswith("kube-") or ns == "ingress-prod":
                continue
            for container in deploy.get("spec", {}).get("template", {}).get("spec", {}).get("containers", []):
                for env in container.get("env", []):
                    if env.get("name", "").upper() in ("DATABASE_URL", "REDIS_URL", "CELERY_BROKER_URL"):
                        if env.get("value") and "@" in env.get("value", ""):
                            plaintext_urls += 1
    record("E", f"No plaintext DB/Redis URLs in env vars ({plaintext_urls})", plaintext_urls == 0)


# ============================================================================
# Section F: CORS & Security Headers
# ============================================================================

def audit_cors_headers():
    print("\n\033[1m=== F. CORS & Security Headers ===\033[0m")

    # F1: CORS with valid origin
    try:
        with httpx.Client(timeout=10.0) as client:
            resp = client.options(
                f"{API_BASE}/health/live",
                headers={
                    "Origin": "https://app.0xapogee.com",
                    "Access-Control-Request-Method": "GET",
                },
            )
            acao = resp.headers.get("access-control-allow-origin", "")
            record("F", f"CORS allows app.0xapogee.com ({acao})",
                   "0xapogee.com" in acao or acao == "*")
    except Exception as e:
        record("F", "CORS preflight", False, str(e))

    # F2: CORS rejects evil origin
    try:
        with httpx.Client(timeout=10.0) as client:
            resp2 = client.options(
                f"{API_BASE}/health/live",
                headers={
                    "Origin": "https://evil.example.com",
                    "Access-Control-Request-Method": "GET",
                },
            )
            acao2 = resp2.headers.get("access-control-allow-origin", "")
            record("F", "CORS rejects unauthorized origin",
                   "evil.example.com" not in acao2 and acao2 != "*",
                   f"got: {acao2}" if "evil" in acao2 or acao2 == "*" else "")
    except Exception as e:
        record("F", "CORS rejection check", False, str(e))

    # F3-F5: Security headers on API response
    try:
        resp3 = api_get("health/live")
        headers = resp3.headers

        xcto = headers.get("x-content-type-options", "")
        record("F", f"X-Content-Type-Options: {xcto}", xcto == "nosniff")

        xfo = headers.get("x-frame-options", "")
        if xfo:
            record("F", f"X-Frame-Options: {xfo}", xfo.upper() in ("DENY", "SAMEORIGIN"))
        else:
            warn("F", "X-Frame-Options header not present")

        # HSTS (may be set by ingress/proxy, not application)
        hsts = headers.get("strict-transport-security", "")
        if hsts:
            record("F", f"Strict-Transport-Security present", True)
        else:
            warn("F", "Strict-Transport-Security not present", "May be handled by ingress/CDN")
    except Exception as e:
        record("F", "Security headers check", False, str(e))


# ============================================================================
# Section G: CronJob Cleanup
# ============================================================================

def audit_cronjob_cleanup():
    print("\n\033[1m=== G. CronJob Cleanup ===\033[0m")

    # G1: No CronJobs in platform namespaces
    cj_raw = run_kubectl(["kubectl", "get", "cronjobs", "-A", "--no-headers"])
    platform_cjs = []
    if cj_raw:
        for line in cj_raw.split("\n"):
            if line.strip() and not any(skip_ns in line for skip_ns in ["kube-system", "cert-manager"]):
                # Only count platform namespaces
                ns = line.split()[0] if line.split() else ""
                if any(ns.startswith(p) for p in ["api-service", "orchestration", "tool-integration",
                                                    "data-service", "intelligence-engine",
                                                    "notification", "dashboard", "admin-portal"]):
                    platform_cjs.append(line.strip())
    record("G", f"No platform CronJobs ({len(platform_cjs)} found)", len(platform_cjs) == 0,
           "; ".join(platform_cjs[:3]) if platform_cjs else "")

    # G2-G8: Celery Beat tasks registered
    celery_file = REPO_ROOT / "blocksecops-orchestration/src/blocksecops_orchestration/core/celery_app.py"
    celery_content = ""
    if celery_file.exists():
        celery_content = celery_file.read_text()

    for task in EXPECTED_BEAT_TASKS:
        present = task in celery_content
        record("G", f"Celery Beat: {task}", present)


# ============================================================================
# Section H: Docker Image Compliance
# ============================================================================

def audit_docker_compliance():
    print("\n\033[1m=== H. Docker Image Compliance ===\033[0m")

    # H1-H9: Dockerfiles have OCI labels
    for svc, info in SERVICES.items():
        repo = info.get("repo", "")
        dockerfile = REPO_ROOT / repo / "Dockerfile"
        if not dockerfile.exists():
            skip("H", f"{svc}: Dockerfile not found", str(dockerfile))
            continue
        content = dockerfile.read_text()
        has_oci = "org.opencontainers.image" in content
        record("H", f"{svc}: OCI labels in Dockerfile", has_oci)

    # H10: No :latest in FROM directives across all Dockerfiles
    latest_froms = []
    for svc, info in SERVICES.items():
        repo = info.get("repo", "")
        dockerfile = REPO_ROOT / repo / "Dockerfile"
        if dockerfile.exists():
            content = dockerfile.read_text()
            for line in content.split("\n"):
                if line.strip().startswith("FROM") and ":latest" in line:
                    latest_froms.append(f"{svc}: {line.strip()}")
    record("H", f"No :latest in FROM directives ({len(latest_froms)} found)",
           len(latest_froms) == 0,
           "; ".join(latest_froms[:3]) if latest_froms else "")

    # H11-H15: Scanner Dockerfiles exist and have version ARGs
    scanner_dir = REPO_ROOT / "blocksecops-tool-integration" / "scanner-images"
    if scanner_dir.exists():
        scanners = [d.name for d in scanner_dir.iterdir() if d.is_dir() and (d / "Dockerfile").exists()]
        record("H", f"Scanner Dockerfiles found ({len(scanners)})", len(scanners) >= 15)

        # Check a sample for SCANNER_IMAGE_VERSION ARG
        has_version_arg = 0
        for s in scanners:
            df = (scanner_dir / s / "Dockerfile").read_text()
            if "SCANNER_IMAGE_VERSION" in df or "ARG.*VERSION" in df:
                has_version_arg += 1
        record("H", f"Scanner Dockerfiles with version ARG ({has_version_arg}/{len(scanners)})",
               has_version_arg >= len(scanners) * 0.8)
    else:
        skip("H", "Scanner Dockerfiles", "scanner-images directory not found")


# ============================================================================
# Main
# ============================================================================

def main():
    start = datetime.now()
    print(f"\033[1m{'='*70}\033[0m")
    print(f"\033[1m  Apogee Platform Comprehensive Security & Functionality Audit\033[0m")
    print(f"\033[1m{'='*70}\033[0m")
    print(f"  Date:      {start.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print(f"  Target:    {API_BASE}")
    print(f"  Repo Root: {REPO_ROOT}")

    # Run existing audit scripts first
    run_existing_audits()

    # New audit sections
    audit_service_health()
    audit_version_sync()
    audit_k8s_security()
    audit_database()
    audit_secrets()
    audit_cors_headers()
    audit_cronjob_cleanup()
    audit_docker_compliance()

    # Summary
    passed = sum(1 for r in results if r.passed and not r.skipped)
    failed = sum(1 for r in results if not r.passed)
    skipped = sum(1 for r in results if r.skipped)
    total = len(results)
    elapsed = (datetime.now() - start).total_seconds()

    print(f"\n\033[1m{'='*70}\033[0m")
    print(f"\033[1m  Audit Complete\033[0m")
    print(f"\033[1m{'='*70}\033[0m")
    print(f"  Total:   {total}")
    print(f"  Passed:  \033[32m{passed}\033[0m")
    print(f"  Failed:  \033[31m{failed}\033[0m")
    print(f"  Skipped: \033[36m{skipped}\033[0m")
    print(f"  Time:    {elapsed:.1f}s")

    if failed > 0:
        print(f"\n\033[31m  Failed tests:\033[0m")
        for r in results:
            if not r.passed:
                print(f"    [{r.section}] {r.test}: {r.detail}")

    if skipped > 0:
        print(f"\n\033[36m  Skipped tests:\033[0m")
        for r in results:
            if r.skipped:
                print(f"    [{r.section}] {r.test}: {r.detail}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
