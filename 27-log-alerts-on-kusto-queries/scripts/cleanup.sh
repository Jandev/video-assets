#!/usr/bin/env bash
# Deletes the demo resource group.
#   ./cleanup.sh --resource-group rg-contoso-demo-27 --yes
set -euo pipefail

RESOURCE_GROUP="rg-contoso-demo-27"
ASSUME_YES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --yes|-y)         ASSUME_YES="true"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! az group exists --name "$RESOURCE_GROUP" | grep -q true; then
  echo "$RESOURCE_GROUP does not exist. Nothing to do."
  exit 0
fi

if [[ "$ASSUME_YES" != "true" ]]; then
  read -r -p "Delete $RESOURCE_GROUP and everything in it? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 0; }
fi

az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion started (--no-wait)."
