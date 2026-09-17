#!/usr/bin/env bash
# Two jobs:
#   1. Prove queries/*.kql are byte-identical to the KQL embedded in
#      infra/modules/log-alerts.bicep. If they drift, the query you reviewed in
#      the queries/ folder is not the query that got deployed.
#   2. (optional) Run each query against a live Log Analytics workspace to prove
#      the KQL is valid. A broken query in an alert rule does not fail at deploy
#      time - it just never fires, which looks exactly like "everything is fine".
#
#   ./validate-queries.sh --sync-only
#   ./validate-queries.sh --resource-group rg-contoso-demo-27
#   ./validate-queries.sh --workspace-id <customerId>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RESOURCE_GROUP="rg-contoso-demo-27"
WORKSPACE_ID=""
SYNC_ONLY="false"
FAILURES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --workspace-id)   WORKSPACE_ID="$2"; shift 2 ;;
    --sync-only)      SYNC_ONLY="true"; shift ;;
    -h|--help)        sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- 1. Drift check -----------------------------------------------------------
if python3 - "$ROOT" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
src = (root / "infra/modules/log-alerts.bicep").read_text()
mapping = {
    "serverErrorsQuery": "server-errors.kql",
    "authorizationAnomalyQuery": "authorization-anomaly.kql",
    "dependencyFailuresQuery": "dependency-failures.kql",
    "availabilityQuery": "availability.kql",
}
ok = True
for var, fname in mapping.items():
    match = re.search(r"var\s+%s\s*=\s*'''\n(.*?)'''" % var, src, re.S)
    if not match:
        print(f"        variable {var} not found in log-alerts.bicep")
        ok = False
        continue
    path = root / "queries" / fname
    if not path.exists():
        print(f"        queries/{fname} is missing")
        ok = False
        continue
    if match.group(1) != path.read_text():
        print(f"        queries/{fname} has drifted from {var} in Bicep")
        ok = False
sys.exit(0 if ok else 1)
PY
then
  printf "  \033[32mPASS\033[0m  queries/*.kql match the KQL embedded in log-alerts.bicep\n"
else
  printf "  \033[31mFAIL\033[0m  KQL drift between queries/*.kql and log-alerts.bicep\n"
  FAILURES=$((FAILURES + 1))
fi

if [[ "$SYNC_ONLY" == "true" ]]; then
  [[ $FAILURES -eq 0 ]] && exit 0 || exit 1
fi

# --- 2. Live validation -------------------------------------------------------
if [[ -z "$WORKSPACE_ID" ]]; then
  WORKSPACE_ID=$(az monitor log-analytics workspace list --resource-group "$RESOURCE_GROUP" \
    --query "[0].customerId" -o tsv 2>/dev/null || true)
fi

if [[ -z "$WORKSPACE_ID" ]]; then
  echo "  SKIP  no reachable workspace - pass --workspace-id <customerId> to validate live KQL"
  [[ $FAILURES -eq 0 ]] && exit 0 || exit 1
fi

echo
echo "Validating alert queries against workspace $WORKSPACE_ID"
echo
for file in "$ROOT"/queries/*.kql; do
  name=$(basename "$file")
  query=$(cat "$file")
  if output=$(az monitor log-analytics query -w "$WORKSPACE_ID" \
        --analytics-query "$query" -o json 2>&1); then
    rows=$(echo "$output" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
    printf "  \033[32mPASS\033[0m  %-28s valid KQL, %s row(s) returned\n" "$name" "$rows"
  else
    printf "  \033[31mFAIL\033[0m  %-28s\n" "$name"
    echo "$output" | sed 's/^/        /' | head -6
    FAILURES=$((FAILURES + 1))
  fi
done

echo
if [[ $FAILURES -eq 0 ]]; then
  echo "All queries are in sync and valid."
  exit 0
fi
echo "$FAILURES check(s) failed."
exit 1
