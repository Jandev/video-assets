#!/usr/bin/env bash
# Drives the failure-injection endpoints so a threshold is crossed inside one
# five-minute evaluation window. Works against a locally running API or a
# deployed URL - it only needs to reach the HTTP endpoint.
#
#   ./generate-failures.sh --url http://localhost:5027 --scenario server-errors
#   ./generate-failures.sh --url https://my-api.example.com --scenario all --count 40
#
# Scenarios:
#   server-errors   GET /widgets/boom            (rule fires at >= 5)
#   authorization   GET /orders/secret           (rule fires at >= 20)
#   dependency      GET /widgets/{id}/supplier   (rule fires at >= 3)
#   all             all three, back to back
#
# Availability is NOT here on purpose: that rule fires on the ABSENCE of
# traffic, so you trigger it by stopping the app, not by calling it.
set -euo pipefail

URL="http://localhost:5027"
SCENARIO="server-errors"
COUNT="30"
RATE_PER_SEC="5"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)          URL="$2"; shift 2 ;;
    --scenario)     SCENARIO="$2"; shift 2 ;;
    --count)        COUNT="$2"; shift 2 ;;
    --rate-per-sec) RATE_PER_SEC="$2"; shift 2 ;;
    -h|--help)      sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

URL="${URL%/}"
DELAY=$(awk "BEGIN { print ($RATE_PER_SEC > 0) ? 1.0 / $RATE_PER_SEC : 0 }")

hit() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" "$URL$path" 2>/dev/null || echo "000")
  printf "  %-32s -> %s\n" "$path" "$code"
  sleep "$DELAY"
}

run_scenario() {
  local scenario="$1"
  case "$scenario" in
    server-errors)
      echo "Scenario: server-errors ($COUNT x GET /widgets/boom) - rule fires at >= 5"
      for _ in $(seq 1 "$COUNT"); do hit "/widgets/boom"; done ;;
    authorization)
      echo "Scenario: authorization ($COUNT x GET /orders/secret) - rule fires at >= 20"
      for i in $(seq 1 "$COUNT"); do
        if (( i % 2 == 0 )); then hit "/orders/secret?forbidden=true"; else hit "/orders/secret"; fi
      done ;;
    dependency)
      echo "Scenario: dependency ($COUNT x GET /widgets/WIDGET-001/supplier) - rule fires at >= 3"
      for _ in $(seq 1 "$COUNT"); do hit "/widgets/WIDGET-001/supplier"; done ;;
    *)
      echo "Unknown scenario: $scenario" >&2
      echo "Use: server-errors | authorization | dependency | all" >&2
      exit 1 ;;
  esac
}

echo "Target : $URL"
echo "Rate   : $RATE_PER_SEC req/s"
echo

if [[ "$SCENARIO" == "all" ]]; then
  run_scenario server-errors
  echo
  run_scenario authorization
  echo
  run_scenario dependency
else
  run_scenario "$SCENARIO"
fi

echo
echo "Done. Telemetry reaches Log Analytics within a few minutes; the rule then"
echo "evaluates on its PT5M cycle. Expect the notification several minutes later,"
echo "not instantly - see docs/script.md for how to film this honestly."
