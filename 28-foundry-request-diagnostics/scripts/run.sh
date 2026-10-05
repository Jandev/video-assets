#!/usr/bin/env bash
# Creates the local environment and runs either the direct OpenAI or MAF demo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="${1:-}"
if [[ "$APP" != "openai" && "$APP" != "maf" ]]; then
  echo "Usage: $0 <openai|maf> [application arguments]" >&2
  exit 1
fi
shift

if [[ ! -f "$ROOT/.azure-outputs.env" ]]; then
  echo "Missing $ROOT/.azure-outputs.env. Run ./scripts/deploy.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/.azure-outputs.env"

if [[ "${APPLICATIONINSIGHTS_CONNECTION_STRING:-}" != InstrumentationKey=* ]]; then
  if [[ -z "${AZURE_RESOURCE_GROUP:-}" || -z "${APPLICATIONINSIGHTS_NAME:-}" ]]; then
    echo "Application Insights configuration is missing from $ROOT/.azure-outputs.env." >&2
    exit 1
  fi

  SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  export APPLICATIONINSIGHTS_CONNECTION_STRING="$(az rest --method get --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Insights/components/$APPLICATIONINSIGHTS_NAME?api-version=2020-02-02" --query properties.ConnectionString -o tsv)"
fi

if ! "$ROOT/.venv/bin/python" -m pip --version >/dev/null 2>&1; then
  rm -rf "$ROOT/.venv"
  python3 -m venv "$ROOT/.venv"
fi
"$ROOT/.venv/bin/python" -m pip install -q -r "$ROOT/requirements.txt"
"$ROOT/.venv/bin/python" "$ROOT/src/${APP}_headers.py" "$@"
