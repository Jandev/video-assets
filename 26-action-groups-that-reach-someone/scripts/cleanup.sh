#!/usr/bin/env bash
# Deletes both demo resource groups and the subscription-scoped budget.
#   ./cleanup.sh --yes
#   ./cleanup.sh --name-suffix ab12 --yes
set -euo pipefail

NAME_SUFFIX=""
ASSUME_YES="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name-suffix) NAME_SUFFIX="$2"; shift 2 ;;
    --yes|-y)      ASSUME_YES="true"; shift ;;
    -h|--help)     sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

SUFFIX=""
[[ -n "$NAME_SUFFIX" ]] && SUFFIX="-${NAME_SUFFIX}"

MGMT_RG="rg-contoso-demo-26-management${SUFFIX}"
WORKLOAD_RG="rg-contoso-demo-26-workload${SUFFIX}"
BUDGET_NAME="contoso-demo-26-monthly-budget${SUFFIX}"

if [[ "$ASSUME_YES" != "true" ]]; then
  read -r -p "Delete $MGMT_RG, $WORKLOAD_RG and budget $BUDGET_NAME? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Aborted."; exit 0; }
fi

# Budgets are subscription-scoped and are not removed by deleting a resource
# group, so delete it explicitly. Ignore "not found".
az consumption budget delete --budget-name "$BUDGET_NAME" 2>/dev/null || true
echo "Budget $BUDGET_NAME removed (if it existed)."

for rg in "$MGMT_RG" "$WORKLOAD_RG"; do
  if az group exists --name "$rg" | grep -q true; then
    az group delete --name "$rg" --yes --no-wait
    echo "Deletion started for $rg (--no-wait)."
  else
    echo "$rg does not exist. Skipping."
  fi
done
