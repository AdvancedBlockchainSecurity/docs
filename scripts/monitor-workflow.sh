#!/bin/bash
# Monitor contract upload and scan workflow
# Usage: ./monitor-workflow.sh [watch]

WATCH_MODE=false
if [ "$1" = "watch" ]; then
  WATCH_MODE=true
fi

show_status() {
  clear
  echo "=========================================="
  echo "  Apogee Workflow Monitor"
  echo "  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "=========================================="
  echo ""
  
  echo "=== Current Contracts ==="
  kubectl exec -n postgresql-local postgresql-0 -- \
    psql -U postgres -d solidity_security \
    -c "SELECT id, name, status, created_at FROM contracts ORDER BY created_at DESC LIMIT 5;" 2>/dev/null | tail -n +3

  echo ""
  echo "=== Recent Scans ==="
  kubectl exec -n postgresql-local postgresql-0 -- \
    psql -U postgres -d solidity_security \
    -c "SELECT id, contract_id, status, scan_type, created_at FROM scans ORDER BY created_at DESC LIMIT 5;" 2>/dev/null | tail -n +3

  echo ""
  echo "=== Latest Vulnerabilities ==="
  kubectl exec -n postgresql-local postgresql-0 -- \
    psql -U postgres -d solidity_security \
    -c "SELECT id, scan_id, severity, title, detected_at FROM vulnerabilities ORDER BY detected_at DESC LIMIT 5;" 2>/dev/null | tail -n +3

  echo ""
  echo "=== Service Status ==="
  echo "API Service: $(curl -s http://127.0.0.1:8000/api/v1/health/ready 2>/dev/null | jq -r '.ready // "unavailable"')"
  echo "Dashboard: $(curl -s http://127.0.0.1:3001 -o /dev/null -w '%{http_code}' 2>/dev/null | grep -q 200 && echo 'running' || echo 'unavailable')"
  
  echo ""
  echo "=== Recent API Activity (Last 10 lines) ==="
  kubectl logs -n api-service-local deployment/api-service --tail=10 2>/dev/null | \
    grep -v "GET /api/v1/health" | \
    grep -E "(POST|GET|PUT|DELETE|ERROR|INFO)" | tail -5
}

if [ "$WATCH_MODE" = true ]; then
  echo "Starting watch mode (press Ctrl+C to exit)..."
  while true; do
    show_status
    sleep 5
  done
else
  show_status
fi
