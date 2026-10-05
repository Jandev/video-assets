#!/usr/bin/env bash
# Deploys Foundry, one model deployment, and a connected Application Insights resource.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCE_GROUP="rg-demo28-foundry-diagnostics"
LOCATION="swedencentral"
NAME_SUFFIX="$(openssl rand -hex 3)"
MODEL_NAME="gpt-4.1-mini"
MODEL_VERSION="2025-04-14"
MODEL_DEPLOYMENT="gpt-4.1-mini"
MODEL_CAPACITY="10"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    --name-suffix) NAME_SUFFIX="$2"; shift 2 ;;
    --model-name) MODEL_NAME="$2"; shift 2 ;;
    --model-version) MODEL_VERSION="$2"; shift 2 ;;
    --model-deployment) MODEL_DEPLOYMENT="$2"; shift 2 ;;
    --model-capacity) MODEL_CAPACITY="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

PRINCIPAL_ID="$(az ad signed-in-user show --query id -o tsv)"
DEPLOYMENT_NAME="foundry-diagnostics-$(date +%Y%m%d%H%M%S)"

echo "Resource group : $RESOURCE_GROUP"
echo "Location       : $LOCATION"
echo "Name suffix    : $NAME_SUFFIX"
echo "Model          : $MODEL_NAME ($MODEL_VERSION)"
echo "Deployment     : $MODEL_DEPLOYMENT"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$ROOT/infra/main.bicep" \
  --parameters location="$LOCATION" \
               nameSuffix="$NAME_SUFFIX" \
               principalId="$PRINCIPAL_ID" \
               modelName="$MODEL_NAME" \
               modelVersion="$MODEL_VERSION" \
               modelDeploymentName="$MODEL_DEPLOYMENT" \
               modelCapacity="$MODEL_CAPACITY" \
  --output none

PROJECT_ENDPOINT="$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query 'properties.outputs.foundryProjectEndpoint.value' -o tsv)"
APP_INSIGHTS_NAME="$(az deployment group show --resource-group "$RESOURCE_GROUP" --name "$DEPLOYMENT_NAME" --query 'properties.outputs.applicationInsightsName.value' -o tsv)"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
APP_INSIGHTS_CONNECTION="$(az rest --method get --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Insights/components/$APP_INSIGHTS_NAME?api-version=2020-02-02" --query properties.ConnectionString -o tsv)"

OUTPUT_FILE="$ROOT/.azure-outputs.env"
umask 077
{
  printf 'export AZURE_AI_FOUNDRY_ENDPOINT=%q\n' "$PROJECT_ENDPOINT"
  printf 'export FOUNDRY_PROJECT_ENDPOINT=%q\n' "$PROJECT_ENDPOINT"
  printf 'export AZURE_AI_MODEL_DEPLOYMENT=%q\n' "$MODEL_DEPLOYMENT"
  printf 'export APPLICATIONINSIGHTS_CONNECTION_STRING=%q\n' "$APP_INSIGHTS_CONNECTION"
  printf 'export AZURE_RESOURCE_GROUP=%q\n' "$RESOURCE_GROUP"
  printf 'export APPLICATIONINSIGHTS_NAME=%q\n' "$APP_INSIGHTS_NAME"
} > "$OUTPUT_FILE"

echo
echo "Deployment complete. Configuration written to $OUTPUT_FILE"
echo "Next: ./scripts/run.sh openai"
echo "      ./scripts/run.sh maf"
