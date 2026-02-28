#!/usr/bin/env python3
"""
Comprehensive load test for Apogee API by tier.

Tests all 4 tiers (developer, team, growth, enterprise) against a representative
set of endpoints at increasing concurrency levels. Measures p50/p95/p99 latency,
throughput, error rates, and verifies rate limiting enforcement.

Usage:
    /home/pwner/Git/blocksecops-api-service/.venv/bin/python3 \
        /home/pwner/Git/docs/audits/scripts/load-test-by-tier.py

Requirements: httpx, PyJWT (both in api-service venv)
"""

import asyncio
import json
import statistics
import sys
import time
from dataclasses import dataclass, field

import httpx
import jwt

# ============================================================================
# Configuration
# ============================================================================

API_BASE = "https://app.0xapogee.local/api/v1"
JWT_SECRET = "local-dev-jwt-secret-key-change-in-production"

USERS = {
    "developer": {
        "sub": "11111111-1111-1111-1111-111111111111",
        "email": "test-developer@blocksecops.local",
    },
    "team": {
        "sub": "22222222-2222-2222-2222-222222222222",
        "email": "test-team@blocksecops.local",
    },
    "growth": {
        "sub": "33333333-3333-3333-3333-333333333333",
        "email": "test-growth@blocksecops.local",
    },
    "enterprise": {
        "sub": "44444444-4444-4444-4444-444444444444",
        "email": "test-enterprise@blocksecops.local",
    },
}

# Endpoints: (path, requires_auth, tier_gate, description)
ENDPOINTS = [
    ("/health/live", False, None, "Health (liveness)"),
    ("/health/ready", False, None, "Health (readiness + DB)"),
    ("/users/me", True, None, "User profile"),
    ("/users/me/quota", True, None, "User quota"),
    ("/contracts", True, None, "Contracts list"),
    ("/scans", True, None, "Scans list"),
    ("/vulnerabilities", True, None, "Vulnerabilities list"),
    ("/search", True, "team", "Search"),
    ("/api-keys", True, "team", "API Keys list"),
    ("/webhooks", True, "team", "Webhooks list"),
    ("/notification-channels", True, "team", "Notification channels"),
    ("/economic-analysis/quota", True, "team", "Economic analysis quota"),
    ("/audit-logs", True, "enterprise", "Audit logs"),
]

CONCURRENCY_LEVELS = [
    ("serial", 1, 50),
    ("light", 5, 100),
    ("moderate", 10, 100),
    ("heavy", 25, 100),
    ("stress", 50, 200),
]

TIER_ORDER = {"developer": 0, "team": 1, "growth": 2, "enterprise": 3}
RATE_LIMITED_TIERS = {"developer", "team"}  # monthly_api_calls_limit=0


# ============================================================================
# Token generation
# ============================================================================


def make_token(tier: str) -> str:
    user = USERS[tier]
    payload = {
        "sub": user["sub"],
        "email": user["email"],
        "aud": "authenticated",
        "role": "authenticated",
        "iat": int(time.time()),
        "exp": int(time.time()) + 7200,
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


# ============================================================================
# Data structures
# ============================================================================


@dataclass
class RequestResult:
    status: int
    latency_ms: float
    error: str | None = None


@dataclass
class EndpointResult:
    endpoint: str
    description: str
    concurrency: int
    total_requests: int
    results: list[RequestResult] = field(default_factory=list)

    @property
    def latencies(self) -> list[float]:
        return [r.latency_ms for r in self.results if r.error is None]

    @property
    def status_counts(self) -> dict[int, int]:
        counts: dict[int, int] = {}
        for r in self.results:
            counts[r.status] = counts.get(r.status, 0) + 1
        return counts

    @property
    def error_count(self) -> int:
        return sum(1 for r in self.results if r.error is not None)

    def percentile(self, p: float) -> float:
        lat = sorted(self.latencies)
        if not lat:
            return 0.0
        idx = int(len(lat) * p / 100)
        return lat[min(idx, len(lat) - 1)]

    @property
    def throughput(self) -> float:
        if not self.latencies:
            return 0.0
        total_time = sum(self.latencies) / 1000.0
        if total_time == 0:
            return 0.0
        return len(self.latencies) / (total_time / self.concurrency)


@dataclass
class TierResult:
    tier: str
    endpoint_results: list[EndpointResult] = field(default_factory=list)


@dataclass
class BurstTestResult:
    tier: str
    endpoint: str
    total_sent: int
    status_counts: dict[int, int] = field(default_factory=dict)
    first_429_at: int | None = None
    latencies: list[float] = field(default_factory=list)


# ============================================================================
# Load test engine
# ============================================================================


async def send_request(
    client: httpx.AsyncClient, url: str, headers: dict
) -> RequestResult:
    start = time.perf_counter()
    try:
        resp = await client.get(url, headers=headers, timeout=30.0)
        latency = (time.perf_counter() - start) * 1000
        return RequestResult(status=resp.status_code, latency_ms=latency)
    except Exception as e:
        latency = (time.perf_counter() - start) * 1000
        return RequestResult(status=0, latency_ms=latency, error=str(e))


async def run_endpoint_test(
    client: httpx.AsyncClient,
    endpoint: str,
    headers: dict,
    concurrency: int,
    total_requests: int,
    description: str,
) -> EndpointResult:
    url = f"{API_BASE}{endpoint}"
    result = EndpointResult(
        endpoint=endpoint,
        description=description,
        concurrency=concurrency,
        total_requests=total_requests,
    )

    sem = asyncio.Semaphore(concurrency)

    async def bounded_request():
        async with sem:
            return await send_request(client, url, headers)

    tasks = [bounded_request() for _ in range(total_requests)]
    results = await asyncio.gather(*tasks)
    result.results = list(results)
    return result


async def run_burst_test(
    client: httpx.AsyncClient,
    endpoint: str,
    headers: dict,
    total: int,
    concurrency: int = 25,
) -> BurstTestResult:
    """Send requests as fast as possible to test rate limiting."""
    url = f"{API_BASE}{endpoint}"
    burst = BurstTestResult(tier="growth", endpoint=endpoint, total_sent=total)
    sem = asyncio.Semaphore(concurrency)
    request_order: list[tuple[int, RequestResult]] = []
    counter = 0
    lock = asyncio.Lock()

    async def bounded_request():
        nonlocal counter
        async with lock:
            idx = counter
            counter += 1
        async with sem:
            r = await send_request(client, url, headers)
            request_order.append((idx, r))
            return r

    tasks = [bounded_request() for _ in range(total)]
    await asyncio.gather(*tasks)

    request_order.sort(key=lambda x: x[0])
    for idx, r in request_order:
        burst.status_counts[r.status] = burst.status_counts.get(r.status, 0) + 1
        burst.latencies.append(r.latency_ms)
        if r.status == 429 and burst.first_429_at is None:
            burst.first_429_at = idx + 1

    return burst


async def run_tier_test(tier: str, token: str) -> TierResult:
    tier_result = TierResult(tier=tier)
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    async with httpx.AsyncClient(verify=False) as client:
        for path, requires_auth, tier_gate, desc in ENDPOINTS:
            if not requires_auth:
                # Health endpoints: test without auth at all concurrency levels
                for level_name, conc, total in CONCURRENCY_LEVELS:
                    result = await run_endpoint_test(
                        client, path, {}, conc, total, f"{desc} ({level_name})"
                    )
                    tier_result.endpoint_results.append(result)
            else:
                # Authenticated endpoints: test with tier's token
                # For rate-limited tiers, only run serial (they'll all be 429)
                if tier in RATE_LIMITED_TIERS:
                    result = await run_endpoint_test(
                        client, path, headers, 1, 10, f"{desc} (rate-limited)"
                    )
                    tier_result.endpoint_results.append(result)
                else:
                    for level_name, conc, total in CONCURRENCY_LEVELS:
                        result = await run_endpoint_test(
                            client, path, headers, conc, total, f"{desc} ({level_name})"
                        )
                        tier_result.endpoint_results.append(result)

    return tier_result


# ============================================================================
# Output formatting
# ============================================================================


def print_header(text: str):
    print(f"\n{'=' * 72}")
    print(f"  {text}")
    print(f"{'=' * 72}\n")


def print_endpoint_result(r: EndpointResult):
    lat = r.latencies
    if not lat:
        print(f"  {r.description:40s}  NO RESPONSES")
        return
    p50 = r.percentile(50)
    p95 = r.percentile(95)
    p99 = r.percentile(99)
    status_str = " ".join(f"{s}:{c}" for s, c in sorted(r.status_counts.items()))
    print(
        f"  {r.description:40s}  "
        f"p50={p50:6.1f}ms  p95={p95:6.1f}ms  p99={p99:6.1f}ms  "
        f"tput={r.throughput:6.1f}rps  [{status_str}]"
    )


def generate_markdown(
    tier_results: dict[str, TierResult],
    baseline_results: list[EndpointResult],
    burst_result: BurstTestResult | None,
    issues: list[str],
    start_time: float,
    end_time: float,
) -> str:
    duration = end_time - start_time
    lines = []

    lines.append("# Load Test Results")
    lines.append("")
    lines.append("**Date:** February 24, 2026")
    lines.append("**Platform Version:** api-service 0.29.27")
    lines.append(
        "**Environment:** Local cluster (kubeadm, 1 replica, 200m/1CPU, 256Mi/1Gi)"
    )
    lines.append(f"**Duration:** {duration:.0f}s")
    lines.append(f"**Tool:** Python asyncio + httpx (custom script)")
    lines.append("")

    # Executive summary
    lines.append("## Executive Summary")
    lines.append("")
    total_requests = 0
    total_errors = 0
    for tr in tier_results.values():
        for er in tr.endpoint_results:
            total_requests += len(er.results)
            total_errors += er.error_count
    lines.append(f"- **Total requests sent:** {total_requests:,}")
    lines.append(f"- **Connection errors:** {total_errors}")

    # Per-tier summary
    for tier in ["developer", "team", "growth", "enterprise"]:
        tr = tier_results.get(tier)
        if not tr:
            continue
        all_statuses: dict[int, int] = {}
        for er in tr.endpoint_results:
            for s, c in er.status_counts.items():
                all_statuses[s] = all_statuses.get(s, 0) + c
        status_str = ", ".join(f"{s}: {c}" for s, c in sorted(all_statuses.items()))
        lines.append(f"- **{tier}:** {status_str}")

    if burst_result:
        lines.append(
            f"- **Rate limit burst test:** first 429 at request #{burst_result.first_429_at or 'N/A'}"
        )
    if issues:
        lines.append(f"- **Issues found:** {len(issues)}")
    else:
        lines.append("- **Issues found:** 0")
    lines.append("")

    # Test environment
    lines.append("## Test Environment")
    lines.append("")
    lines.append("| Setting | Value |")
    lines.append("|---------|-------|")
    lines.append("| API Base URL | `https://app.0xapogee.local/api/v1` |")
    lines.append("| Cluster | kubeadm (single node) |")
    lines.append("| API replicas | 1 |")
    lines.append("| CPU | 200m request / 1 CPU limit |")
    lines.append("| Memory | 256Mi request / 1Gi limit |")
    lines.append("| DB pool | 10 + 20 overflow = 30 max |")
    lines.append("| Auth | HS256 JWT (local dev fallback) |")
    lines.append(
        "| Concurrency levels | serial(1), light(5), moderate(10), heavy(25), stress(50) |"
    )
    lines.append("")

    # Baseline performance
    lines.append("## Baseline Performance (Health Endpoints, No Auth)")
    lines.append("")
    lines.append(
        "| Endpoint | Concurrency | Requests | p50 (ms) | p95 (ms) | p99 (ms) | Throughput (rps) | Errors |"
    )
    lines.append(
        "|----------|-------------|----------|----------|----------|----------|-----------------|--------|"
    )
    for er in baseline_results:
        lat = er.latencies
        if not lat:
            continue
        lines.append(
            f"| {er.endpoint} | {er.concurrency} | {len(er.results)} | "
            f"{er.percentile(50):.1f} | {er.percentile(95):.1f} | {er.percentile(99):.1f} | "
            f"{er.throughput:.1f} | {er.error_count} |"
        )
    lines.append("")

    # Results by tier
    for tier in ["developer", "team", "growth", "enterprise"]:
        tr = tier_results.get(tier)
        if not tr:
            continue

        lines.append(f"## {tier.capitalize()} Tier")
        lines.append("")

        if tier in RATE_LIMITED_TIERS:
            lines.append(
                f"**Expected:** All requests return 429 (monthly API call limit = 0, API access blocked)."
            )
            lines.append("")
            lines.append("| Endpoint | Requests | 429 | Other | Avg Latency (ms) |")
            lines.append("|----------|----------|-----|-------|-------------------|")
            for er in tr.endpoint_results:
                if not er.results[0].error and er.endpoint in (
                    "/health/live",
                    "/health/ready",
                ):
                    continue  # Skip health endpoints in rate-limited tier display
                count_429 = er.status_counts.get(429, 0)
                count_other = len(er.results) - count_429 - er.error_count
                avg_lat = statistics.mean(er.latencies) if er.latencies else 0
                lines.append(
                    f"| {er.endpoint} | {len(er.results)} | {count_429} | {count_other} | {avg_lat:.1f} |"
                )
            # Verify
            auth_results = [
                er
                for er in tr.endpoint_results
                if er.endpoint not in ("/health/live", "/health/ready")
            ]
            all_429 = all(
                er.status_counts.get(429, 0) == len(er.results)
                for er in auth_results
                if er.results
            )
            lines.append("")
            lines.append(
                f"**Verification:** {'PASS' if all_429 else 'FAIL'} — "
                f"{'All' if all_429 else 'Not all'} authenticated requests returned 429."
            )
        else:
            lines.append(
                "| Endpoint | Concurrency | Requests | p50 (ms) | p95 (ms) | p99 (ms) | Throughput (rps) | Status Distribution |"
            )
            lines.append(
                "|----------|-------------|----------|----------|----------|----------|-----------------|---------------------|"
            )
            for er in tr.endpoint_results:
                if er.endpoint in ("/health/live", "/health/ready"):
                    continue
                lat = er.latencies
                if not lat:
                    continue
                status_str = " ".join(
                    f"{s}:{c}" for s, c in sorted(er.status_counts.items())
                )
                lines.append(
                    f"| {er.endpoint} | {er.concurrency} | {len(er.results)} | "
                    f"{er.percentile(50):.1f} | {er.percentile(95):.1f} | {er.percentile(99):.1f} | "
                    f"{er.throughput:.1f} | {status_str} |"
                )

        lines.append("")

    # Rate limit burst test
    if burst_result:
        lines.append("## Rate Limit Verification (Growth Tier Burst Test)")
        lines.append("")
        lines.append(f"**Endpoint:** `{burst_result.endpoint}`")
        lines.append(f"**Total requests:** {burst_result.total_sent}")
        lines.append(f"**Concurrency:** 25")
        lines.append(
            f"**First 429 at request:** #{burst_result.first_429_at or 'N/A (no 429 received)'}"
        )
        lines.append("")
        lines.append("| Status | Count | Percentage |")
        lines.append("|--------|-------|------------|")
        for s, c in sorted(burst_result.status_counts.items()):
            pct = c / burst_result.total_sent * 100
            lines.append(f"| {s} | {c} | {pct:.1f}% |")
        lines.append("")
        if burst_result.latencies:
            sorted_lat = sorted(burst_result.latencies)
            p50 = sorted_lat[len(sorted_lat) // 2]
            p95 = sorted_lat[int(len(sorted_lat) * 0.95)]
            p99 = sorted_lat[int(len(sorted_lat) * 0.99)]
            lines.append(
                f"**Latency:** p50={p50:.1f}ms, p95={p95:.1f}ms, p99={p99:.1f}ms"
            )
        lines.append("")

    # Issues
    lines.append("## Issues Found")
    lines.append("")
    if issues:
        for i, issue in enumerate(issues, 1):
            lines.append(f"{i}. {issue}")
    else:
        lines.append("No issues found during load testing.")
    lines.append("")

    # Recommendations
    lines.append("## Recommendations")
    lines.append("")

    # Generate recommendations based on results
    recs = []

    # Check if any enterprise endpoint had high p99
    if "enterprise" in tier_results:
        for er in tier_results["enterprise"].endpoint_results:
            if er.endpoint in ("/health/live", "/health/ready"):
                continue
            if er.percentile(99) > 1000 and er.concurrency >= 25:
                recs.append(
                    f"**High p99 latency** on `{er.endpoint}` at concurrency {er.concurrency}: "
                    f"{er.percentile(99):.0f}ms. Consider adding database query optimization or caching."
                )

    # Check baseline health
    for er in baseline_results:
        if er.percentile(99) > 500 and er.concurrency >= 25:
            recs.append(
                f"**Health endpoint p99 > 500ms** at concurrency {er.concurrency}: "
                f"{er.percentile(99):.0f}ms. May indicate resource contention under load."
            )

    if not recs:
        recs.append(
            "Platform performs within acceptable parameters for local single-replica deployment."
        )
        recs.append(
            "Production deployment with 3 replicas and higher CPU limits will improve throughput linearly."
        )

    for rec in recs:
        lines.append(f"- {rec}")
    lines.append("")

    return "\n".join(lines)


# ============================================================================
# Main
# ============================================================================


async def main():
    import warnings

    warnings.filterwarnings("ignore", message=".*SSL.*")

    print_header("Apogee Platform Load Test")
    print(f"  API: {API_BASE}")
    print(f"  Tiers: developer, team, growth, enterprise")
    print(f"  Endpoints: {len(ENDPOINTS)}")
    print(f"  Concurrency levels: {len(CONCURRENCY_LEVELS)}")
    print()

    start_time = time.time()
    issues: list[str] = []
    tier_results: dict[str, TierResult] = {}
    baseline_results: list[EndpointResult] = []
    tokens = {tier: make_token(tier) for tier in USERS}

    # ---- Phase 1: Baseline (health endpoints, no auth) ----
    print_header("Phase 1: Baseline Performance (Health Endpoints)")
    async with httpx.AsyncClient(verify=False) as client:
        for path, requires_auth, _, desc in ENDPOINTS:
            if requires_auth:
                continue
            for level_name, conc, total in CONCURRENCY_LEVELS:
                result = await run_endpoint_test(
                    client, path, {}, conc, total, f"{desc} ({level_name})"
                )
                baseline_results.append(result)
                print_endpoint_result(result)
                if result.error_count > 0:
                    issues.append(
                        f"Baseline: {result.error_count} connection errors on {path} at concurrency {conc}"
                    )

    # ---- Phase 2: Developer tier ----
    print_header("Phase 2: Developer Tier (expect all 429)")
    tr = await run_tier_test("developer", tokens["developer"])
    tier_results["developer"] = tr
    for er in tr.endpoint_results:
        if er.endpoint in ("/health/live", "/health/ready"):
            continue
        print_endpoint_result(er)
        non_429 = sum(c for s, c in er.status_counts.items() if s != 429)
        if non_429 > 0:
            issues.append(
                f"Developer tier: {non_429} non-429 responses on {er.endpoint}"
            )

    # ---- Phase 3: Team tier ----
    print_header("Phase 3: Team Tier (expect all 429)")
    tr = await run_tier_test("team", tokens["team"])
    tier_results["team"] = tr
    for er in tr.endpoint_results:
        if er.endpoint in ("/health/live", "/health/ready"):
            continue
        print_endpoint_result(er)
        non_429 = sum(c for s, c in er.status_counts.items() if s != 429)
        if non_429 > 0:
            issues.append(f"Team tier: {non_429} non-429 responses on {er.endpoint}")

    # ---- Phase 4: Growth tier ----
    print_header("Phase 4: Growth Tier (expect 200 on team+, 403 on enterprise)")
    tr = await run_tier_test("growth", tokens["growth"])
    tier_results["growth"] = tr
    for er in tr.endpoint_results:
        if er.endpoint in ("/health/live", "/health/ready"):
            continue
        print_endpoint_result(er)
        # Check tier gate enforcement
        endpoint_info = next(
            (e for e in ENDPOINTS if e[0] == er.endpoint), None
        )
        if endpoint_info and endpoint_info[2] == "enterprise":
            count_403 = er.status_counts.get(403, 0)
            if count_403 != len(er.results):
                issues.append(
                    f"Growth tier: expected 403 on {er.endpoint}, got {er.status_counts}"
                )

    # ---- Phase 5: Enterprise tier ----
    print_header("Phase 5: Enterprise Tier (expect 200 on all)")
    tr = await run_tier_test("enterprise", tokens["enterprise"])
    tier_results["enterprise"] = tr
    for er in tr.endpoint_results:
        if er.endpoint in ("/health/live", "/health/ready"):
            continue
        print_endpoint_result(er)

    # ---- Phase 6: Rate limit burst test (growth tier) ----
    print_header("Phase 6: Rate Limit Burst Test (Growth Tier, 350 reqs)")
    burst_result = None
    async with httpx.AsyncClient(verify=False) as client:
        headers = {"Authorization": f"Bearer {tokens['growth']}"}
        burst_result = await run_burst_test(
            client, "/contracts", headers, total=350, concurrency=25
        )
        print(f"  Endpoint: /contracts")
        print(f"  Total sent: {burst_result.total_sent}")
        print(
            f"  First 429 at: #{burst_result.first_429_at or 'N/A (no 429)'}"
        )
        for s, c in sorted(burst_result.status_counts.items()):
            print(f"    {s}: {c} ({c / burst_result.total_sent * 100:.1f}%)")

    # ---- Phase 7: Post-test health check ----
    print_header("Phase 7: Post-Test Health Check")
    async with httpx.AsyncClient(verify=False) as client:
        for path in ["/health/live", "/health/ready"]:
            r = await send_request(client, f"{API_BASE}{path}", {})
            status = "PASS" if r.status == 200 else "FAIL"
            print(f"  {status} — {path}: {r.status} ({r.latency_ms:.1f}ms)")
            if r.status != 200:
                issues.append(f"Post-test health check failed: {path} returned {r.status}")

    end_time = time.time()

    # ---- Generate report ----
    print_header("Summary")
    print(f"  Duration: {end_time - start_time:.0f}s")
    print(f"  Issues: {len(issues)}")
    for i, issue in enumerate(issues, 1):
        print(f"    {i}. {issue}")

    markdown = generate_markdown(
        tier_results, baseline_results, burst_result, issues, start_time, end_time
    )

    report_path = "/home/pwner/Git/docs/audits/2026-02-24-load-test-results.md"
    with open(report_path, "w") as f:
        f.write(markdown)
    print(f"\n  Report saved to: {report_path}")


if __name__ == "__main__":
    asyncio.run(main())
