#!/usr/bin/env bash
# Deploys the Log Analytics workspace, Application Insights, action group and
# the four log-alert rules.
#
#   ./deploy.sh --email you@example.com
#   ./deploy.sh --email you@example.com --name-suffix ab12
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

RESOURCE_GROUP="rg-contoso-demo-27"
LOCATION="westeurope"
NAME_SUFFIX=""
EMAIL="ops-team@example.com"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --location)       LOCATION="$2"; shift 2 ;;
    --name-suffix)    NAME_SUFFIX="$2"; shift 2 ;;
    --email)          EMAIL="$2"; shift 2 ;;
    -h|--help)        sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "Resource group : $RESOURCE_GROUP"
echo "Location       : $LOCATION"
echo "Name suffix    : ${NAME_SUFFIX:-<none>}"
echo "Alert email    : $EMAIL"
echo

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

DEPLOYMENT_NAME="log-alerts-demo-$(date +%Y%m%d%H%M%S)"

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$INFRA_DIR/main.bicep" \
  --parameters location="$LOCATION" \
               nameSuffix="$NAME_SUFFIX" \
               alertEmailAddress="$EMAIL" \
  --output none

CONN=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.appInsightsConnectionString.value" -o tsv)
WS=$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.workspaceName.value" -o tsv)

echo "Deployment complete."
echo "  Workspace: $WS"
echo
echo "Export the connection string, run the API, then drive failures:"
echo "  export APPLICATIONINSIGHTS_CONNECTION_STRING='$CONN'"
echo "  dotnet run --project src/dotnet/Contoso.Demo.LogAlerts.Api &"
echo "  ./scripts/generate-failures.sh --url http://localhost:5027 --scenario server-errors"
echo "  ./scripts/show-alerts.sh --resource-group $RESOURCE_GROUP"
