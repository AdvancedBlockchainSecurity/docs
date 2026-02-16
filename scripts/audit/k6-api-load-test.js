/**
 * BlockSecOps Go-Live Audit: API Load Test (Section 13)
 *
 * Usage:
 *   k6 run --env BASE_URL=https://app.blocksecops.com \
 *          --env TOKEN=<jwt_token> \
 *          scripts/audit/k6-api-load-test.js
 *
 * Thresholds:
 *   - p95 response time < 500ms for key endpoints
 *   - Error rate < 1%
 *   - All health endpoints < 200ms
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'https://app.blocksecops.com';
const TOKEN = __ENV.TOKEN || '';

// Custom metrics
const errorRate = new Rate('errors');
const healthLatency = new Trend('health_latency');
const scansLatency = new Trend('scans_latency');
const contractsLatency = new Trend('contracts_latency');

export const options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp up to 10 users
    { duration: '1m', target: 20 },    // Hold at 20 users
    { duration: '30s', target: 50 },   // Spike to 50 users
    { duration: '1m', target: 50 },    // Hold spike
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    'http_req_duration{endpoint:health}': ['p(95)<200'],
    'http_req_duration{endpoint:scans}': ['p(95)<500'],
    'http_req_duration{endpoint:contracts}': ['p(95)<500'],
    'http_req_duration{endpoint:vulnerabilities}': ['p(95)<500'],
    'errors': ['rate<0.01'],
  },
};

const headers = TOKEN
  ? { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' }
  : { 'Content-Type': 'application/json' };

export default function () {
  // 13.2 Health endpoint (should be fastest)
  const healthRes = http.get(`${BASE_URL}/api/v1/health/live`, {
    tags: { endpoint: 'health' },
  });
  check(healthRes, { 'health status 200': (r) => r.status === 200 });
  healthLatency.add(healthRes.timings.duration);
  errorRate.add(healthRes.status !== 200);

  sleep(0.5);

  if (TOKEN) {
    // 13.2 Scans endpoint
    const scansRes = http.get(`${BASE_URL}/api/v1/scans?limit=5`, {
      headers,
      tags: { endpoint: 'scans' },
    });
    check(scansRes, {
      'scans status 200': (r) => r.status === 200,
      'scans has items': (r) => {
        try { return JSON.parse(r.body).items !== undefined; } catch { return false; }
      },
    });
    scansLatency.add(scansRes.timings.duration);
    errorRate.add(scansRes.status !== 200);

    sleep(0.5);

    // 13.2 Contracts endpoint
    const contractsRes = http.get(`${BASE_URL}/api/v1/contracts?limit=5`, {
      headers,
      tags: { endpoint: 'contracts' },
    });
    check(contractsRes, { 'contracts status 200': (r) => r.status === 200 });
    contractsLatency.add(contractsRes.timings.duration);
    errorRate.add(contractsRes.status !== 200);

    sleep(0.5);

    // 13.2 Vulnerabilities endpoint
    const vulnsRes = http.get(`${BASE_URL}/api/v1/vulnerabilities?limit=5`, {
      headers,
      tags: { endpoint: 'vulnerabilities' },
    });
    check(vulnsRes, { 'vulns status 200': (r) => r.status === 200 });
    errorRate.add(vulnsRes.status !== 200);

    sleep(0.5);

    // 13.2 Dedup groups endpoint
    const dedupRes = http.get(`${BASE_URL}/api/v1/deduplication/groups?limit=5`, {
      headers,
      tags: { endpoint: 'dedup' },
    });
    check(dedupRes, { 'dedup status 200': (r) => r.status === 200 });
    errorRate.add(dedupRes.status !== 200);
  }

  sleep(1);
}

export function handleSummary(data) {
  const summary = {
    timestamp: new Date().toISOString(),
    thresholds: {},
    metrics: {},
  };

  for (const [name, metric] of Object.entries(data.metrics)) {
    if (metric.values) {
      summary.metrics[name] = metric.values;
    }
  }

  for (const [name, threshold] of Object.entries(data.root_group?.thresholds || {})) {
    summary.thresholds[name] = threshold;
  }

  return {
    stdout: textSummary(data, { indent: '  ', enableColors: true }),
    'reports/k6-summary.json': JSON.stringify(summary, null, 2),
  };
}

function textSummary(data) {
  let out = '\n=== BlockSecOps Load Test Results ===\n\n';

  const metrics = data.metrics;
  const endpoints = ['health', 'scans', 'contracts', 'vulnerabilities', 'dedup'];

  for (const ep of endpoints) {
    const key = `http_req_duration{endpoint:${ep}}`;
    if (metrics[key] && metrics[key].values) {
      const v = metrics[key].values;
      out += `  ${ep}: p50=${v.med?.toFixed(0)}ms p95=${v['p(95)']?.toFixed(0)}ms p99=${v['p(99)']?.toFixed(0)}ms\n`;
    }
  }

  if (metrics.errors && metrics.errors.values) {
    out += `\n  Error rate: ${(metrics.errors.values.rate * 100).toFixed(2)}%\n`;
  }

  if (metrics.http_reqs && metrics.http_reqs.values) {
    out += `  Total requests: ${metrics.http_reqs.values.count}\n`;
    out += `  RPS: ${metrics.http_reqs.values.rate?.toFixed(1)}\n`;
  }

  return out;
}
