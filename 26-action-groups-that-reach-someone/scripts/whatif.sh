#!/usr/bin/env bash
# Subscription-scope what-if. Shows what would change without deploying.
#   ./whatif.sh --email you@example.com
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

LOCATION="westeurope"
NAME_SUFFIX=""
EMAIL="widget-oncall@example.com"
BUDGET_START="$(date -u +%Y-%m-01)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --location)     LOCATION="$2"; shift 2 ;;
    --name-suffix)  NAME_SUFFIX="$2"; shift 2 ;;
    --email)        EMAIL="$2"; shift 2 ;;
    --budget-start) BUDGET_START="$2"; shift 2 ;;
    -h|--help)      sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

az deployment sub what-if \
  --location "$LOCATION" \
  --template-file "$INFRA_DIR/main.bicep" \
  --parameters location="$LOCATION" \
               nameSuffix="$NAME_SUFFIX" \
               alertEmailAddress="$EMAIL" \
               budgetStartDate="$BUDGET_START"
