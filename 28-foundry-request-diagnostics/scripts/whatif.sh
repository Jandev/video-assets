#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCE_GROUP="rg-demo28-foundry-diagnostics"
LOCATION="swedencentral"
NAME_SUFFIX="preview28"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    --name-suffix) NAME_SUFFIX="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

PRINCIPAL_ID="$(az ad signed-in-user show --query id -o tsv)"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
az deployment group what-if \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$ROOT/infra/main.bicep" \
  --parameters location="$LOCATION" nameSuffix="$NAME_SUFFIX" principalId="$PRINCIPAL_ID"
