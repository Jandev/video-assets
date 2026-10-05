#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="rg-demo28-foundry-diagnostics"
YES="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --yes) YES="true"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "$YES" != "true" ]]; then
  read -r -p "Delete resource group '$RESOURCE_GROUP' and all of its contents? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 0
fi
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion started for $RESOURCE_GROUP."
