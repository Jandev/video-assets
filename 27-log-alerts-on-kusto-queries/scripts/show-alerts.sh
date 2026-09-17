#!/usr/bin/env bash
# Shows the deployed log-alert rules, their state, and any recent fired alerts.
#   ./show-alerts.sh --resource-group rg-contoso-demo-27
set -euo pipefail

RESOURCE_GROUP="rg-contoso-demo-27"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    -h|--help)        sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo
echo "=== Scheduled query alert rules ================================================"
# `az monitor scheduled-query` is the log-alert (scheduledQueryRules) surface.
# NOTE: `az monitor activity-log alert` is a DIFFERENT thing (activity-log
# alerts), not what this demo deploys.
az monitor scheduled-query list --resource-group "$RESOURCE_GROUP" \
  --query "[].{Name:name, Severity:severity, Enabled:enabled, Every:evaluationFrequency, Window:windowSize}" \
  -o table 2>/dev/null || echo "  (no rules found - deploy first)"

echo
echo "=== Fired alerts (last 24h) ===================================================="
# Fired alert INSTANCES live in the Alerts Management API, not in scheduled-query.
SUB=$(az account show --query id -o tsv)
az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.AlertsManagement/alerts?api-version=2019-05-05-preview&timeRange=1d" \
  --query "value[?contains(properties.essentials.targetResourceGroup, '$RESOURCE_GROUP')].{Name:name, Severity:properties.essentials.severity, State:properties.essentials.monitorCondition, FiredAt:properties.essentials.startDateTime}" \
  -o table 2>/dev/null || echo "  (no alerts, or the Alerts Management API is unavailable)"
echo
