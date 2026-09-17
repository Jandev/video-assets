#!/usr/bin/env bash
# Runs a resource-group what-if - shows what deploy.sh would change, no writes.
#   ./whatif.sh --resource-group rg-contoso-demo-27 --email you@example.com
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
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

az deployment group what-if \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$INFRA_DIR/main.bicep" \
  --parameters location="$LOCATION" nameSuffix="$NAME_SUFFIX" alertEmailAddress="$EMAIL"
