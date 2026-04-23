#!/usr/bin/env python3
"""
Comprehensive Scanning System Audit

Validates the entire scanning pipeline, scanner images, batch scanning,
stale recovery, quota enforcement, Celery Beat automation, and security:
  1. Scan pipeline (upload, trigger, results, post-scan hooks)
  2. Batch scanning (creation, quota, status tracking)
  3. Scanner images (ConfigMap, KJM defaults, versions, Dockerfiles)
  4. Stale scan recovery (Celery Beat, retry logic)
  5. Quota enforcement (monthly limits, reset, tier checking)
  6. Automation (Celery Beat schedule, no stale CronJobs)
  7. Security (NetworkPolicy, non-root, resource limits, deadlines)

Usage:
    python3 docs/audits/scripts/audit-scanning-system.py

Requires: httpx (in api-service venv or pip install httpx)
"""

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
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

EXPECTED_SCANNERS = [
    "slither", "aderyn", "semgrep", "solhint", "wake", "soliditydefend",
    "echidna", "medusa", "halmos", "vyper", "moccasin", "sol-azy",
    "sec3-xray", "trident", "cargo-fuzz-solana", "rustdefend",
]

FOUNDRY_SCANNERS = ["aderyn", "slither", "wake"]


def _scanner_uses_solidity_base(scanner: str) -> bool:
    """True if the scanner's Dockerfile FROMs scanner-base-solidity.

    The shared base image (rolled out 2026-04-19) provides solc + forge-std
    pre-installed for 7 Solidity scanners: slither, aderyn, wake, halmos,
    mythril, echidna, medusa. Their own Dockerfiles just do
    `FROM .../scanner-base-solidity:${BASE_IMAGE_TAG}` — the C6 / C7 per-
    Dockerfile solc + forge-std checks should skip them to avoid false-
    positive failures.
    """
    dockerfile = REPO_ROOT / f"blocksecops-tool-integration/scanner-images/{scanner}/Dockerfile"
    if not dockerfile.exists():
        return False
    try:
        content = dockerfile.read_text()
    except OSError:
        return False
    return bool(re.search(r"FROM\s+\S*scanner-base-solidity:", content))

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


def api_get(path: str) -> httpx.Response:
    """GET request with API key auth."""
    with httpx.Client(timeout=30.0) as client:
        return client.get(f"{API_BASE}/{path}", headers={"X-API-Key": API_KEY})


def run_psql(query: str) -> str:
    """Run a psql query via kubectl exec."""
    cmd = [
        "kubectl", "exec", "-n", "postgresql-prod", "pod/postgresql-0", "--",
        "psql", "-U", "blocksecops", "-d", "solidity_security",
        "-t", "-A", "-c", query,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    return result.stdout.strip()


def run_kubectl(cmd_args: list[str]) -> str:
    """Run kubectl command."""
    result = subprocess.run(cmd_args, capture_output=True, text=True, timeout=30)
    return result.stdout.strip()


def file_contains(filepath: Path, pattern: str) -> bool:
    """Check if a file contains a regex pattern."""
    if not filepath.exists():
        return False
    content = filepath.read_text()
    return bool(re.search(pattern, content))


def file_read(filepath: Path) -> str:
    """Read file contents, empty string if not found."""
    if not filepath.exists():
        return ""
    return filepath.read_text()


# ============================================================================
# Section A: Scan Pipeline
# ============================================================================

def audit_scan_pipeline():
    print("\n\033[1m=== A. Scan Pipeline ===\033[0m")

    # A1: API service healthy
    resp = api_get("health/live")
    if resp.status_code == 200:
        data = resp.json()
        version = data.get("version", "?")
        record("A", f"API service healthy (v{version})", data.get("status") == "healthy", "", resp.status_code)
    else:
        record("A", "API service healthy", False, f"HTTP {resp.status_code}", resp.status_code)

    # A2: Scans endpoint accessible
    resp2 = api_get("scans?limit=1")
    record("A", "Scans list endpoint accessible via API key", resp2.status_code == 200, "", resp2.status_code)

    # A3: Scan results storage endpoint exists (internal only)
    scans_file = REPO_ROOT / "blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py"
    has_results = file_contains(scans_file, r"/results")
    record("A", "Scan results storage endpoint exists", has_results)

    # A4: Post-scan dedup maintenance hook
    dedup_file = REPO_ROOT / "blocksecops-api-service/src/infrastructure/tasks/deduplication_maintenance.py"
    has_post_scan = file_contains(dedup_file, r"run_post_scan_maintenance")
    record("A", "Post-scan dedup maintenance hook exists", has_post_scan)

    # A5: Post-scan includes fingerprint backfill (5th task)
    has_backfill = file_contains(dedup_file, r"generate_missing_fingerprints.*contract_id")
    record("A", "Post-scan fingerprint backfill included", has_backfill)

    # A6: Post-scan pattern autodetect
    autodetect_file = REPO_ROOT / "blocksecops-api-service/src/application/services/pattern_autodetect_service.py"
    has_autodetect = file_contains(autodetect_file, r"run_autodetect")
    record("A", "Pattern autodetect service exists", has_autodetect)

    # A7: Scan status transitions in DB
    status_counts = run_psql("""
        SELECT status, COUNT(*) FROM scans
        GROUP BY status ORDER BY COUNT(*) DESC
    """)
    record("A", "Scan status data exists in DB", bool(status_counts), status_counts.replace("\n", ", "))

    # A8: Tool-integration scan trigger endpoint
    ti_scanners = REPO_ROOT / "blocksecops-tool-integration/src/scanners"
    kjm_file = ti_scanners / "kubernetes_job_manager.py"
    has_create_job = file_contains(kjm_file, r"def create_scanner_job")
    record("A", "KJM create_scanner_job exists", has_create_job)

    # A9: Scans have vulnerability counts
    total_scans = int(run_psql("SELECT COUNT(*) FROM scans WHERE status = 'completed'") or 0)
    with_vulns = int(run_psql("SELECT COUNT(*) FROM scans WHERE status = 'completed' AND total_vulnerabilities > 0") or 0)
    pct = (with_vulns * 100 // total_scans) if total_scans > 0 else 0
    record("A", f"Completed scans with vulnerabilities: {with_vulns}/{total_scans} ({pct}%)", total_scans > 0)


# ============================================================================
# Section B: Batch Scanning
# ============================================================================

def audit_batch_scanning():
    print("\n\033[1m=== B. Batch Scanning ===\033[0m")

    scans_file = REPO_ROOT / "blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py"
    content = file_read(scans_file)

    # B1: Batch scan endpoint exists
    has_batch = bool(re.search(r"/batch", content))
    record("B", "Batch scan endpoint exists", has_batch)

    # B2: Batch endpoint uses require_auth_with_scope
    has_scope = bool(re.search(r'require_auth_with_scope.*scans:create', content))
    record("B", "Batch endpoint uses require_auth_with_scope", has_scope)

    # B3: Batch respects quota
    has_quota_check = bool(re.search(r"monthly_scan_limit|scans_used", content))
    record("B", "Batch enforces monthly quota", has_quota_check)

    # B4: Global scan queue depth check
    has_depth = bool(re.search(r"_check_global_scan_queue_depth|MAX_GLOBAL_ACTIVE_SCANS", content))
    record("B", "Global scan queue depth limit exists", has_depth)

    # B5: Concurrent scan limit per user
    has_concurrent = bool(re.search(r"check_concurrent_scans", content))
    record("B", "Per-user concurrent scan limit exists", has_concurrent)

    # B6: Batch status endpoint
    has_batch_status = bool(re.search(r"batch.*status|batch_id.*status", content))
    record("B", "Batch status tracking endpoint exists", has_batch_status)

    # B7: Rate limiting on batch endpoint
    has_rate_limit = bool(re.search(r"rate_limit.*batch|batchScan", content))
    record("B", "Rate limiting on batch endpoint", has_rate_limit)

    # B8: Batch scan data in DB
    batch_count = int(run_psql("SELECT COUNT(*) FROM scan_batches") or 0) if "scan_batches" in run_psql("SELECT tablename FROM pg_tables WHERE tablename = 'scan_batches'") else -1
    if batch_count >= 0:
        record("B", f"Batch scan records in DB ({batch_count})", True)
    else:
        warn("B", "scan_batches table not found", "May use different table name")


# ============================================================================
# Section C: Scanner Images
# ============================================================================

def audit_scanner_images():
    print("\n\033[1m=== C. Scanner Images ===\033[0m")

    # C1: Scanner ConfigMap exists
    configmap_file = REPO_ROOT / "blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml"
    configmap_exists = configmap_file.exists()
    record("C", "Scanner versions ConfigMap file exists", configmap_exists)

    configmap_content = file_read(configmap_file)

    # C2: All scanners in ConfigMap SCANNER_METADATA
    missing_metadata = []
    for scanner in EXPECTED_SCANNERS:
        if f'"{scanner}"' not in configmap_content:
            missing_metadata.append(scanner)
    record("C", f"All {len(EXPECTED_SCANNERS)} scanners in SCANNER_METADATA", len(missing_metadata) == 0,
           f"missing: {missing_metadata}" if missing_metadata else "")

    # C3: All scanners have SCANNER_IMAGE_* entry
    missing_image = []
    for scanner in EXPECTED_SCANNERS:
        key = f"SCANNER_IMAGE_{scanner.upper().replace('-', '_')}"
        if key not in configmap_content:
            missing_image.append(scanner)
    record("C", f"All scanners have SCANNER_IMAGE_* entry", len(missing_image) == 0,
           f"missing: {missing_image}" if missing_image else "")

    # C4: All scanners have Dockerfile
    missing_dockerfile = []
    for scanner in EXPECTED_SCANNERS:
        dockerfile = REPO_ROOT / f"blocksecops-tool-integration/scanner-images/{scanner}/Dockerfile"
        if not dockerfile.exists():
            missing_dockerfile.append(scanner)
    record("C", f"All scanners have Dockerfile", len(missing_dockerfile) == 0,
           f"missing: {missing_dockerfile}" if missing_dockerfile else "")

    # C5: KJM default_images has all scanners
    kjm_file = REPO_ROOT / "blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py"
    kjm_content = file_read(kjm_file)
    missing_kjm = []
    for scanner in EXPECTED_SCANNERS:
        if f'"{scanner}"' not in kjm_content:
            missing_kjm.append(scanner)
    record("C", f"KJM default_images has all scanners", len(missing_kjm) == 0,
           f"missing: {missing_kjm}" if missing_kjm else "")

    # C6: Solc pre-installed (no runtime download) in Foundry scanners.
    # Skip scanners consuming scanner-base-solidity:1.0 — the base image
    # pre-installs solc across solc-select / Foundry SVM / wake-compilers
    # layouts, so per-Dockerfile inspection gives a false-negative on those.
    foundry_no_preinstall = []
    skipped_base_c6 = []
    for scanner in FOUNDRY_SCANNERS:
        if _scanner_uses_solidity_base(scanner):
            skipped_base_c6.append(scanner)
            continue
        dockerfile = REPO_ROOT / f"blocksecops-tool-integration/scanner-images/{scanner}/Dockerfile"
        content = file_read(dockerfile)
        if not re.search(r"solc-select|svm|solc.*install", content, re.IGNORECASE):
            foundry_no_preinstall.append(scanner)
    c6_note = f" (skipped {skipped_base_c6} — solc from scanner-base-solidity)" if skipped_base_c6 else ""
    record("C", f"Foundry scanners pre-install solc{c6_note}", len(foundry_no_preinstall) == 0,
           f"missing: {foundry_no_preinstall}" if foundry_no_preinstall else "")

    # C7: forge-std pre-installed for Foundry scanners (same base-image exception)
    no_forgestd = []
    skipped_base_c7 = []
    for scanner in FOUNDRY_SCANNERS:
        if _scanner_uses_solidity_base(scanner):
            skipped_base_c7.append(scanner)
            continue
        dockerfile = REPO_ROOT / f"blocksecops-tool-integration/scanner-images/{scanner}/Dockerfile"
        content = file_read(dockerfile)
        if "forge-std" not in content:
            no_forgestd.append(scanner)
    c7_note = f" (skipped {skipped_base_c7} — forge-std from scanner-base-solidity)" if skipped_base_c7 else ""
    record("C", f"Foundry scanners pre-install forge-std{c7_note}", len(no_forgestd) == 0,
           f"missing: {no_forgestd}" if no_forgestd else "")

    # C8: Scanner versions in DB match ConfigMap count
    db_scanner_count = int(run_psql("SELECT COUNT(*) FROM scanner_versions") or 0)
    record("C", f"scanner_versions DB rows ({db_scanner_count}) >= {len(EXPECTED_SCANNERS)}",
           db_scanner_count >= len(EXPECTED_SCANNERS))


# ============================================================================
# Section D: Stale Scan Recovery
# ============================================================================

def audit_stale_recovery():
    print("\n\033[1m=== D. Stale Scan Recovery ===\033[0m")

    # D1: check_stale_scans in Celery Beat
    celery_file = REPO_ROOT / "blocksecops-orchestration/src/blocksecops_orchestration/core/celery_app.py"
    celery_content = file_read(celery_file)
    has_stale = "check-stale-scans" in celery_content or "check_stale_scans" in celery_content
    record("D", "check-stale-scans in Celery Beat schedule", has_stale)

    # D2: Stale scan task implementation
    scan_tasks = REPO_ROOT / "blocksecops-orchestration/src/blocksecops_orchestration/tasks/scan_tasks_sync.py"
    scan_content = file_read(scan_tasks)
    has_stale_fn = "def check_stale_scans" in scan_content
    record("D", "check_stale_scans task implemented", has_stale_fn)

    # D3: Retry logic exists
    has_retry = "retry_count" in scan_content and "retry_limit" in scan_content
    record("D", "Stale scan retry logic with limits", has_retry)

    # D4: Atomic retry updates (prevent race conditions)
    has_atomic = "retry_count + 1" in scan_content or "retry_count=retry_count" in scan_content
    record("D", "Atomic retry count updates", has_atomic)

    # D5: K8s CronJob for stale recovery — should be eliminated if Celery Beat handles it
    cronjob_file = REPO_ROOT / "blocksecops-api-service/k8s/base/api-service/cronjob-stale-scan-recovery.yaml"
    cronjob_exists = cronjob_file.exists()
    if cronjob_exists and has_stale:
        warn("D", "Stale scan recovery CronJob still exists alongside Celery Beat task",
             "Consider removing CronJob since Celery Beat handles stale recovery every 30s")
    elif cronjob_exists and not has_stale:
        record("D", "Stale scan recovery runs via K8s CronJob", True)
    else:
        record("D", "No redundant stale recovery CronJob", True)

    # D6: No stale scans stuck in DB
    stale = int(run_psql("""
        SELECT COUNT(*) FROM scans
        WHERE status IN ('running', 'queued')
        AND created_at < NOW() - INTERVAL '2 hours'
    """) or 0)
    record("D", f"No scans stuck >2 hours ({stale} found)", stale == 0, f"found {stale}" if stale > 0 else "")


# ============================================================================
# Section E: Quota Enforcement
# ============================================================================

def audit_quota():
    print("\n\033[1m=== E. Quota Enforcement ===\033[0m")

    # E1: Monthly quota reset Celery Beat task
    celery_file = REPO_ROOT / "blocksecops-orchestration/src/blocksecops_orchestration/core/celery_app.py"
    celery_content = file_read(celery_file)
    has_reset = "reset-monthly-quotas" in celery_content or "reset_monthly_quotas" in celery_content
    record("E", "reset-monthly-quotas in Celery Beat", has_reset)

    # E2: Quota status check task
    has_status = "check-quota-status" in celery_content or "check_quota_status" in celery_content
    record("E", "check-quota-status in Celery Beat", has_status)

    # E3: Quota tasks implementation
    quota_tasks = REPO_ROOT / "blocksecops-orchestration/src/blocksecops_orchestration/tasks/quota_tasks_sync.py"
    has_quota_impl = quota_tasks.exists()
    record("E", "Quota tasks implementation file exists", has_quota_impl)

    # E4: Scan quota check in scan creation
    scans_file = REPO_ROOT / "blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py"
    scans_content = file_read(scans_file)
    has_quota = "monthly_scan_limit" in scans_content or "quota" in scans_content.lower()
    record("E", "Scan creation enforces quota", has_quota)

    # E5: HTTP 402 on quota exceeded
    has_402 = "402" in scans_content and "quota" in scans_content.lower()
    record("E", "HTTP 402 returned on quota exceeded", has_402)

    # E6: User quota table populated
    quota_users = int(run_psql("SELECT COUNT(*) FROM user_quotas") or 0) if "user_quotas" in run_psql("SELECT tablename FROM pg_tables WHERE tablename = 'user_quotas'") else -1
    if quota_users >= 0:
        record("E", f"User quota records ({quota_users})", quota_users > 0)
    else:
        # Try alternative — quotas might be on users table
        has_quota_field = run_psql("SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name LIKE '%quota%' LIMIT 1")
        record("E", "Quota tracking exists", bool(has_quota_field), f"field: {has_quota_field}" if has_quota_field else "No quota table or field found")


# ============================================================================
# Section F: Automation & Celery Beat
# ============================================================================

def audit_automation():
    print("\n\033[1m=== F. Automation & Celery Beat ===\033[0m")

    celery_file = REPO_ROOT / "blocksecops-orchestration/src/blocksecops_orchestration/core/celery_app.py"
    celery_content = file_read(celery_file)

    # Expected Beat entries
    expected_beats = {
        "poll-scan-queue": "Scan polling",
        "reset-monthly-quotas": "Monthly quota reset",
        "check-quota-status": "Daily quota check",
        "check-stale-scans": "Stale scan recovery",
        "check-model-freshness": "ML model freshness (02:00 UTC)",
        "check-unmapped-patterns": "Pattern autodetect (03:00 UTC)",
        "daily-dedup-maintenance": "Dedup maintenance (04:00 UTC)",
    }

    # F1-F7: Each Beat entry registered
    for key, desc in expected_beats.items():
        present = key in celery_content
        record("F", f"Celery Beat: {key} ({desc})", present)

    # F8: Orchestration deployed
    orch_img = run_kubectl([
        "kubectl", "get", "deployment", "orchestration", "-n", "orchestration-prod",
        "-o", "jsonpath={.spec.template.spec.containers[0].image}",
    ])
    orch_ver = orch_img.split(":")[-1] if ":" in orch_img else "?"
    record("F", f"Orchestration deployed (v{orch_ver})", bool(orch_img))

    # F9: Celery worker deployed
    worker_img = run_kubectl([
        "kubectl", "get", "deployment", "celery-worker", "-n", "api-service-prod",
        "-o", "jsonpath={.spec.template.spec.containers[0].image}",
    ])
    worker_ver = worker_img.split(":")[-1] if ":" in worker_img else "?"
    record("F", f"Celery worker deployed (v{worker_ver})", bool(worker_img))

    # F10: Internal service endpoints exist
    ml_file = REPO_ROOT / "blocksecops-api-service/src/presentation/api/v1/endpoints/ml.py"
    ml_content = file_read(ml_file)
    internal_endpoints = [
        "/internal/ml/execute-training",
        "/internal/patterns/autodetect",
        "/internal/patterns/seed",
        "/internal/intelligence/seed",
        "/internal/scanners/seed",
        "/internal/dedup/maintenance",
    ]
    missing_internal = [ep for ep in internal_endpoints if ep not in ml_content]
    record("F", f"Internal service endpoints ({len(internal_endpoints) - len(missing_internal)}/{len(internal_endpoints)})",
           len(missing_internal) == 0,
           f"missing: {missing_internal}" if missing_internal else "")

    # F11: Internal endpoints use verify_internal_service
    has_verify = "verify_internal_service" in ml_content
    record("F", "Internal endpoints use verify_internal_service auth", has_verify)

    # F12: Scanner version seeding in startup
    main_file = REPO_ROOT / "blocksecops-api-service/src/main.py"
    main_content = file_read(main_file)
    has_seed = "seed_scanner_versions" in main_content or "scanner_version_seed" in main_content
    record("F", "Scanner version seeding in startup lifespan", has_seed)

    # F13: Dedup CronJob eliminated (replaced by Celery Beat)
    dedup_cron = REPO_ROOT / "blocksecops-api-service/k8s/base/api-service/cronjob-deduplication.yaml"
    if dedup_cron.exists():
        warn("F", "Dedup CronJob still exists — should be removed (replaced by Celery Beat daily-dedup-maintenance)")
    else:
        record("F", "Dedup CronJob eliminated (Celery Beat replaces it)", True)


# ============================================================================
# Section G: Scanner Security
# ============================================================================

def audit_security():
    print("\n\033[1m=== G. Scanner Security ===\033[0m")

    kjm_file = REPO_ROOT / "blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py"
    kjm_content = file_read(kjm_file)

    # G1: Scanner Jobs run as non-root
    has_nonroot = "run_as_non_root" in kjm_content or "runAsNonRoot" in kjm_content
    record("G", "Scanner Jobs run as non-root", has_nonroot)

    # G2: Privilege escalation disabled
    has_no_escalation = "allow_privilege_escalation" in kjm_content or "allowPrivilegeEscalation" in kjm_content
    record("G", "Scanner Jobs disable privilege escalation", has_no_escalation)

    # G3: Read-only root filesystem
    has_readonly = "read_only_root_filesystem" in kjm_content or "readOnlyRootFilesystem" in kjm_content
    record("G", "Scanner Jobs use read-only root filesystem", has_readonly)

    # G4: Capabilities dropped
    has_drop = 'drop=["ALL"]' in kjm_content or "DROP" in kjm_content or "drop_all" in kjm_content
    record("G", "Scanner Jobs drop all capabilities", has_drop)

    # G5: Resource limits set
    has_limits = "limits" in kjm_content and "memory" in kjm_content
    record("G", "Scanner Jobs have resource limits", has_limits)

    # G6: activeDeadlineSeconds set
    has_deadline = "active_deadline_seconds" in kjm_content or "activeDeadlineSeconds" in kjm_content
    record("G", "Scanner Jobs have activeDeadlineSeconds", has_deadline)

    # G7: TTL for completed jobs
    has_ttl = "ttl_seconds_after_finished" in kjm_content or "ttlSecondsAfterFinished" in kjm_content
    record("G", "Scanner Jobs have TTL for cleanup", has_ttl)

    # G8: Scanner NetworkPolicy exists
    netpol_file = REPO_ROOT / "blocksecops-tool-integration/k8s/base/scanner-network-policy.yaml"
    has_netpol = netpol_file.exists()
    record("G", "Scanner NetworkPolicy file exists", has_netpol)

    if has_netpol:
        netpol_content = file_read(netpol_file)
        # G9: Egress restricted to tool-integration only
        has_egress_restrict = "Egress" in netpol_content and "8005" in netpol_content
        record("G", "Scanner egress restricted to tool-integration", has_egress_restrict)

    # G10: Seccomp profile
    has_seccomp = "seccomp" in kjm_content.lower() or "RuntimeDefault" in kjm_content
    record("G", "Scanner Jobs use seccomp RuntimeDefault", has_seccomp)

    # G11: Spot VM node scheduling
    has_spot = "gke-spot" in kjm_content or "spot" in kjm_content.lower()
    record("G", "Scanner Jobs target Spot VM nodes", has_spot)


# ============================================================================
# Section H: Data Integrity
# ============================================================================

def audit_data_integrity():
    print("\n\033[1m=== H. Data Integrity ===\033[0m")

    # H1: Total scans
    total = int(run_psql("SELECT COUNT(*) FROM scans") or 0)
    record("H", f"Total scans in DB: {total}", total > 0)

    # H2: Total vulnerabilities
    vulns = int(run_psql("SELECT COUNT(*) FROM vulnerabilities") or 0)
    record("H", f"Total vulnerabilities in DB: {vulns}", vulns > 0)

    # H3: All completed scans have scanner results
    no_results = int(run_psql("""
        SELECT COUNT(*) FROM scans
        WHERE status = 'completed'
        AND total_vulnerabilities IS NULL
    """) or 0)
    record("H", f"Completed scans with null vuln count: {no_results}", no_results == 0)

    # H4: Vulnerability fingerprint coverage
    total_v = int(run_psql("SELECT COUNT(*) FROM vulnerabilities") or 0)
    with_fp = int(run_psql("SELECT COUNT(*) FROM vulnerabilities WHERE fingerprint_code IS NOT NULL AND fingerprint_code != ''") or 0)
    pct = (with_fp * 100 // total_v) if total_v > 0 else 0
    record("H", f"Fingerprint coverage: {pct}% ({with_fp}/{total_v})", pct >= 90, f"expected >=90%")

    # H5: No empty-string fingerprints
    empty_fp = int(run_psql("SELECT COUNT(*) FROM vulnerabilities WHERE fingerprint_code = ''") or 0)
    record("H", f"No empty-string fingerprints ({empty_fp})", empty_fp == 0)

    # H6: Pattern coverage
    mapped = int(run_psql("SELECT COUNT(*) FROM vulnerabilities WHERE pattern_code IS NOT NULL") or 0)
    pct2 = (mapped * 100 // total_v) if total_v > 0 else 0
    record("H", f"Pattern coverage: {pct2}% ({mapped}/{total_v})", pct2 >= 90, f"expected >=90%")

    # H7: Scanner distribution
    scanner_dist = run_psql("""
        SELECT scanner_id, COUNT(*) FROM vulnerabilities
        WHERE scanner_id IS NOT NULL
        GROUP BY scanner_id ORDER BY COUNT(*) DESC LIMIT 10
    """)
    lines = [l for l in scanner_dist.split("\n") if l.strip()]
    record("H", f"Vulnerability scanner distribution ({len(lines)} scanners)", len(lines) > 0,
           scanner_dist.replace("\n", "; ")[:200])

    # H8: No scans without scanner association
    no_scanner = int(run_psql("""
        SELECT COUNT(*) FROM vulnerabilities WHERE scanner_id IS NULL
    """) or 0)
    record("H", f"Vulns without scanner_id: {no_scanner}", no_scanner == 0)


# ============================================================================
# Main
# ============================================================================

def main():
    start = datetime.now()
    print(f"\033[1m{'='*60}\033[0m")
    print(f"\033[1mApogee Scanning System Audit\033[0m")
    print(f"\033[1m{'='*60}\033[0m")
    print(f"Date: {start.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print(f"Target: {API_BASE}")
    print(f"Repo Root: {REPO_ROOT}")

    audit_scan_pipeline()
    audit_batch_scanning()
    audit_scanner_images()
    audit_stale_recovery()
    audit_quota()
    audit_automation()
    audit_security()
    audit_data_integrity()

    # Summary
    passed = sum(1 for r in results if r.passed)
    failed = sum(1 for r in results if not r.passed)
    total = len(results)
    elapsed = (datetime.now() - start).total_seconds()

    print(f"\n\033[1m{'='*60}\033[0m")
    print(f"\033[1mAudit Complete\033[0m")
    print(f"\033[1m{'='*60}\033[0m")
    print(f"  Total:  {total}")
    print(f"  Passed: \033[32m{passed}\033[0m")
    print(f"  Failed: \033[31m{failed}\033[0m")
    print(f"  Time:   {elapsed:.1f}s")

    if failed > 0:
        print(f"\n\033[31mFailed tests:\033[0m")
        for r in results:
            if not r.passed:
                print(f"  [{r.section}] {r.test}: {r.detail}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
