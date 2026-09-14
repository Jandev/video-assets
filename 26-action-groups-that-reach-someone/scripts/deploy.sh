#!/usr/bin/env bash
# Deploys the shared action group, the resource health alerts, the cost budget
# and the workload alerts, at subscription scope (it creates two resource
# groups). Idempotent - safe to re-run.
#
#   ./deploy.sh --email you@example.com
#   ./deploy.sh --email you@example.com --name-suffix ab12 --location westeurope
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
    -h|--help)      sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "Location      : $LOCATION"
echo "Name suffix   : ${NAME_SUFFIX:-<none>}"
echo "Alert email   : $EMAIL"
echo "Budget starts : $BUDGET_START"
echo

DEPLOYMENT_NAME="contoso-demo-26-$(date -u +%Y%m%d%H%M%S)"

az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file "$INFRA_DIR/main.bicep" \
  --parameters location="$LOCATION" \
               nameSuffix="$NAME_SUFFIX" \
               alertEmailAddress="$EMAIL" \
               budgetStartDate="$BUDGET_START" \
  --output none

AG_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.actionGroupName.value" -o tsv)
MGMT_RG=$(az deployment sub show --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.managementResourceGroup.value" -o tsv)

echo "Deployment complete."
echo "  Action group    : $AG_NAME"
echo "  Management group : $MGMT_RG"
echo
echo "Fire a real test notification so the video has something to show:"
echo "  ./scripts/fire-test-alert.sh --resource-group $MGMT_RG --action-group $AG_NAME --email $EMAIL"
