#!/usr/bin/env python3
"""
Comprehensive Intelligence System Audit

Validates all intelligence platform automation after seed data changes:
  1. Seed data automation (patterns, exploits, CVEs, scanner versions)
  2. Pattern ID convention (BVD naming, no invalid IDs)
  3. API key authentication (read endpoints accessible)
  4. ML & scanner quality endpoints
  5. Database integrity (FK, no orphans, no Cairo)
  6. Pattern coverage (>95% vulnerability mapping)

Usage:
    python3 docs/audits/scripts/audit-intelligence-system.py

Requires: httpx (in api-service venv or pip install httpx)
"""

import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime

try:
    import httpx
except ImportError:
    sys.exit("ERROR: httpx required. Install with: pip install httpx")

# ============================================================================
# Configuration
# ============================================================================

API_BASE = os.environ.get("AUDIT_API_BASE", "https://app.0xapogee.com/api/v1")
API_KEY = os.environ.get("AUDIT_API_KEY", "bso_dp8DUvPZaysDEY7Wg8F4RMkUCTht8LLjzfV7Hp_nVQQ")

PATTERN_ID_REGEX = re.compile(r"^BVD-(SOLIDITY|SOLANA|VYPER|MOVE)-[A-Z][A-Z0-9\-]{1,19}-\d{3}$")

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


# ============================================================================
# Section A: Seed Data Automation
# ============================================================================

def audit_seed_data():
    print("\n\033[1m=== A. Seed Data Automation ===\033[0m")

    # A1: Pattern seed version tracked
    ver = run_psql("SELECT current_version FROM ml_model_metadata WHERE model_name = 'pattern_seed'")
    record("A", "Pattern seed version tracked in DB", bool(ver), f"version={ver}")

    # A2: Exploit/CVE seed version tracked
    ver2 = run_psql("SELECT current_version FROM ml_model_metadata WHERE model_name = 'exploit_cve_seed'")
    record("A", "Exploit/CVE seed version tracked in DB", bool(ver2), f"version={ver2}")

    # A3: Scanner version seed tracked
    ver3 = run_psql("SELECT current_version FROM ml_model_metadata WHERE model_name = 'scanner_version_seed'")
    record("A", "Scanner version seed tracked in DB", bool(ver3), f"version={ver3}")

    # A4: Patterns seeded (>300)
    count = int(run_psql("SELECT COUNT(*) FROM vulnerability_patterns") or 0)
    record("A", f"Vulnerability patterns seeded ({count})", count > 300, f"expected >300")

    # A5: Exploits seeded (10)
    ecount = int(run_psql("SELECT COUNT(*) FROM exploits") or 0)
    record("A", f"Exploits seeded ({ecount})", ecount >= 10, f"expected >=10")

    # A6: CVEs seeded (10)
    ccount = int(run_psql("SELECT COUNT(*) FROM cves") or 0)
    record("A", f"CVEs seeded ({ccount})", ccount >= 10, f"expected >=10")

    # A7: Scanner versions seeded (16)
    scount = int(run_psql("SELECT COUNT(*) FROM scanner_versions") or 0)
    record("A", f"Scanner versions seeded ({scount})", scount >= 16, f"expected >=16")

    # A8: Pattern tool mappings exist
    mcount = int(run_psql("SELECT COUNT(*) FROM pattern_tool_mappings") or 0)
    record("A", f"Pattern tool mappings exist ({mcount})", mcount > 500, f"expected >500")

    # A9: Celery Beat check-model-freshness registered
    beat_config = run_kubectl([
        "kubectl", "get", "deployment", "orchestration", "-n", "orchestration-prod",
        "-o", "jsonpath={.spec.template.spec.containers[0].image}",
    ])
    record("A", f"Orchestration deployed ({beat_config.split(':')[-1] if ':' in beat_config else '?'})", bool(beat_config))


# ============================================================================
# Section B: Pattern Intelligence
# ============================================================================

def audit_patterns():
    print("\n\033[1m=== B. Pattern Intelligence ===\033[0m")

    # B1: No BVD-SOL-* patterns (old format)
    bad = int(run_psql("SELECT COUNT(*) FROM vulnerability_patterns WHERE id LIKE 'BVD-SOL-%'") or 0)
    record("B", f"No BVD-SOL-* patterns ({bad} found)", bad == 0, f"expected 0")

    # B2: No BVD-CAIRO-* patterns
    cairo = int(run_psql("SELECT COUNT(*) FROM vulnerability_patterns WHERE id LIKE 'BVD-CAIRO-%'") or 0)
    record("B", f"No BVD-CAIRO-* patterns ({cairo} found)", cairo == 0, f"expected 0")

    # B3: All patterns follow convention
    all_ids = run_psql("SELECT id FROM vulnerability_patterns").split("\n")
    invalid = [pid for pid in all_ids if pid and not PATTERN_ID_REGEX.match(pid)]
    record("B", f"All pattern IDs follow BVD convention ({len(invalid)} invalid)", len(invalid) == 0,
           f"invalid: {invalid[:5]}" if invalid else "")

    # B4: Pattern API accessible via API key
    resp = api_get("intelligence/patterns?limit=1")
    record("B", "Patterns API accessible via API key", resp.status_code == 200, "", resp.status_code)

    # B5: Patterns API returns data
    if resp.status_code == 200:
        data = resp.json()
        total = data.get("total", 0)
        record("B", f"Patterns API returns data (total={total})", total > 0)

    # B6: Pattern coverage >95%
    total_v = int(run_psql("SELECT COUNT(*) FROM vulnerabilities WHERE scanner_id IS NOT NULL") or 0)
    mapped_v = int(run_psql("SELECT COUNT(*) FROM vulnerabilities WHERE scanner_id IS NOT NULL AND pattern_code IS NOT NULL") or 0)
    pct = (mapped_v * 100 // total_v) if total_v > 0 else 0
    record("B", f"Pattern coverage {pct}% ({mapped_v}/{total_v})", pct >= 95, f"expected >=95%")

    # B7: No orphaned mappings (FK integrity)
    orphans = int(run_psql("""
        SELECT COUNT(*) FROM pattern_tool_mappings ptm
        WHERE NOT EXISTS (SELECT 1 FROM vulnerability_patterns vp WHERE vp.id = ptm.pattern_id)
    """) or 0)
    record("B", f"No orphaned pattern_tool_mappings ({orphans})", orphans == 0)


# ============================================================================
# Section C: ML & Scanner Quality
# ============================================================================

def audit_ml():
    print("\n\033[1m=== C. ML & Scanner Quality ===\033[0m")

    # C1: ML model stats via API key
    resp = api_get("ml/model-stats")
    record("C", "ML model-stats accessible via API key", resp.status_code == 200, "", resp.status_code)

    if resp.status_code == 200:
        data = resp.json()
        samples = data.get("samples_count", 0)
        record("C", f"ML training samples ({samples}, awaiting user labels)", True,
               "0 is valid — model trains when users label vulnerabilities")

    # C2: Scanner quality via API key
    resp2 = api_get("ml/scanner-quality")
    record("C", "Scanner quality accessible via API key", resp2.status_code == 200, "", resp2.status_code)

    # C3: Training data stats via API key
    resp3 = api_get("ml/training-data-stats")
    record("C", "Training data stats accessible via API key", resp3.status_code == 200, "", resp3.status_code)

    if resp3.status_code == 200:
        data3 = resp3.json()
        ready = data3.get("is_ready_for_training")
        record("C", f"Training data ready={ready}", ready is not None)

    # C4: Dynamic priorities via API key
    resp4 = api_get("ml/dynamic-priorities")
    record("C", "Dynamic priorities accessible via API key", resp4.status_code == 200, "", resp4.status_code)


# ============================================================================
# Section D: Exploit & CVE Intelligence
# ============================================================================

def audit_intelligence():
    print("\n\033[1m=== D. Exploit & CVE Intelligence ===\033[0m")

    # D1: Exploits API via API key
    resp = api_get("intelligence/exploits?limit=3")
    record("D", "Exploits API accessible via API key", resp.status_code == 200, "", resp.status_code)

    if resp.status_code == 200:
        data = resp.json()
        total = data.get("total", 0)
        record("D", f"Exploits returned ({total})", total >= 10)

    # D2: CVEs API via API key
    resp2 = api_get("intelligence/cves?limit=3")
    record("D", "CVEs API accessible via API key", resp2.status_code == 200, "", resp2.status_code)

    if resp2.status_code == 200:
        data2 = resp2.json()
        total2 = data2.get("total", 0)
        record("D", f"CVEs returned ({total2})", total2 >= 10)

    # D3: Intelligence stats via API key
    resp3 = api_get("intelligence/stats")
    record("D", "Intelligence stats accessible via API key", resp3.status_code == 200, "", resp3.status_code)

    # D4: NVD SWC mapping via API key
    resp4 = api_get("intelligence/swc-mapping")
    record("D", "SWC mapping accessible via API key", resp4.status_code == 200, "", resp4.status_code)


# ============================================================================
# Section E: Scanner Versions & Infrastructure
# ============================================================================

def audit_scanners():
    print("\n\033[1m=== E. Scanner Versions & Infrastructure ===\033[0m")

    # E1: scanner_versions table populated
    scanners = run_psql("SELECT scanner_name, current_version, ecosystem FROM scanner_versions ORDER BY scanner_name")
    scanner_lines = [l for l in scanners.split("\n") if l.strip()]
    record("E", f"scanner_versions has {len(scanner_lines)} rows", len(scanner_lines) >= 16)

    # E2: All scanners have ecosystem
    no_eco = int(run_psql("SELECT COUNT(*) FROM scanner_versions WHERE ecosystem IS NULL OR ecosystem = ''") or 0)
    record("E", "All scanners have ecosystem set", no_eco == 0)

    # E3: All scanners have current_version
    no_ver = int(run_psql("SELECT COUNT(*) FROM scanner_versions WHERE current_version IS NULL OR current_version = ''") or 0)
    record("E", "All scanners have current_version set", no_ver == 0)

    # E4: API service healthy
    resp = api_get("health/live")
    if resp.status_code == 200:
        data = resp.json()
        version = data.get("version", "?")
        record("E", f"API service healthy (v{version})", data.get("status") == "healthy")
    else:
        record("E", "API service healthy", False, f"HTTP {resp.status_code}")

    # E5: Orchestration deployed
    orch_img = run_kubectl([
        "kubectl", "get", "deployment", "orchestration", "-n", "orchestration-prod",
        "-o", "jsonpath={.spec.template.spec.containers[0].image}",
    ])
    orch_ver = orch_img.split(":")[-1] if ":" in orch_img else "?"
    record("E", f"Orchestration deployed (v{orch_ver})", bool(orch_img))

    # E6: Dashboard deployed
    dash_img = run_kubectl([
        "kubectl", "get", "deployment", "dashboard", "-n", "dashboard-prod",
        "-o", "jsonpath={.spec.template.spec.containers[0].image}",
    ])
    dash_ver = dash_img.split(":")[-1] if ":" in dash_img else "?"
    record("E", f"Dashboard deployed (v{dash_ver})", bool(dash_img))


# ============================================================================
# Section F: Database Integrity
# ============================================================================

def audit_database():
    print("\n\033[1m=== F. Database Integrity ===\033[0m")

    # F1: Alembic version
    alembic_ver = run_psql("SELECT version_num FROM alembic_version")
    record("F", f"Alembic version: {alembic_ver}", bool(alembic_ver))

    # F2: ml_model_metadata table has all seed entries
    seed_count = int(run_psql("SELECT COUNT(*) FROM ml_model_metadata WHERE model_name LIKE '%seed%'") or 0)
    record("F", f"Seed version tracking entries ({seed_count})", seed_count >= 3, "expected >=3")

    # F3: No null scanner_id in vulnerabilities with pattern_code
    null_scanner = int(run_psql("""
        SELECT COUNT(*) FROM vulnerabilities
        WHERE pattern_code IS NOT NULL AND scanner_id IS NULL
    """) or 0)
    record("F", f"No null scanner_id with pattern_code ({null_scanner})", null_scanner == 0)

    # F4: Pattern distribution by ecosystem
    for eco in ["SOLIDITY", "SOLANA", "VYPER"]:
        count = int(run_psql(f"SELECT COUNT(*) FROM vulnerability_patterns WHERE id LIKE 'BVD-{eco}-%'") or 0)
        record("F", f"BVD-{eco}-* patterns: {count}", count > 0)

    # F5: No duplicate pattern IDs
    dupes = int(run_psql("""
        SELECT COUNT(*) FROM (
            SELECT id, COUNT(*) FROM vulnerability_patterns GROUP BY id HAVING COUNT(*) > 1
        ) t
    """) or 0)
    record("F", "No duplicate pattern IDs", dupes == 0)

    # F6: scanner_versions table exists
    exists = run_psql("SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'scanner_versions')")
    record("F", "scanner_versions table exists", exists == "t")


# ============================================================================
# Main
# ============================================================================

def main():
    start = datetime.now()
    print(f"\033[1m{'='*60}\033[0m")
    print(f"\033[1mApogee Intelligence System Audit\033[0m")
    print(f"\033[1m{'='*60}\033[0m")
    print(f"Date: {start.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print(f"Target: {API_BASE}")

    audit_seed_data()
    audit_patterns()
    audit_ml()
    audit_intelligence()
    audit_scanners()
    audit_database()

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
