#!/usr/bin/env bash
# Fires a REAL test notification through the shared action group, so the video
# has something to show. This uses Azure Monitor's test-notifications API, which
# sends an actual email / webhook / role notification without waiting for a real
# alert to fire.
#
#   ./fire-test-alert.sh --resource-group rg-contoso-demo-26-management \
#       --action-group contoso-demo-26-oncall --email you@example.com
#
# The email lands in the mailbox you deployed with. The ARM role receivers reach
# whoever currently holds Owner / Contributor on the subscription.
set -euo pipefail

RESOURCE_GROUP="rg-contoso-demo-26-management"
ACTION_GROUP="contoso-demo-26-oncall"
EMAIL="widget-oncall@example.com"
ALERT_TYPE="resourcehealth"
OWNER_ROLE_ID="8e3af657-a8ff-443c-a75c-2fe8c4bcb635"        # Azure built-in: Owner
CONTRIBUTOR_ROLE_ID="b24988ac-6180-42a0-ab88-20f7382dd24c"  # Azure built-in: Contributor

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --action-group)   ACTION_GROUP="$2"; shift 2 ;;
    --email)          EMAIL="$2"; shift 2 ;;
    --alert-type)     ALERT_TYPE="$2"; shift 2 ;;
    -h|--help)        sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "Firing a test '$ALERT_TYPE' notification through:"
echo "  Action group : $ACTION_GROUP  (resource group $RESOURCE_GROUP)"
echo "  Email lands  : $EMAIL"
echo "  ARM roles    : Owner + Contributor on the subscription"
echo

# Preferred path: the first-class CLI command. The receivers passed here are the
# ones that get tested - we mirror what the deployed action group contains.
if az monitor action-group test-notifications create --help >/dev/null 2>&1; then
  echo "Using: az monitor action-group test-notifications create"
  az monitor action-group test-notifications create \
    --resource-group "$RESOURCE_GROUP" \
    --action-group "$ACTION_GROUP" \
    --alert-type "$ALERT_TYPE" \
    --add-action email oncall-distribution "$EMAIL" usecommonalertschema \
    --add-action armrole subscription-owners "$OWNER_ROLE_ID" usecommonalertschema \
    --add-action armrole subscription-contributors "$CONTRIBUTOR_ROLE_ID" usecommonalertschema
  echo
  echo "Notification dispatched. Give email a minute or two to arrive."
  exit 0
fi

# Fallback: call the ARM createNotifications endpoint directly.
echo "CLI command unavailable - falling back to the ARM REST endpoint."
SUB_ID=$(az account show --query id -o tsv)
API_VERSION="2023-01-01"
URL="https://management.azure.com/subscriptions/${SUB_ID}/providers/Microsoft.Insights/createNotifications?api-version=${API_VERSION}"

BODY=$(cat <<JSON
{
  "alertType": "${ALERT_TYPE}",
  "emailReceivers": [
    { "name": "oncall-distribution", "emailAddress": "${EMAIL}", "useCommonAlertSchema": true }
  ],
  "armRoleReceivers": [
    { "name": "subscription-owners", "roleId": "${OWNER_ROLE_ID}", "useCommonAlertSchema": true },
    { "name": "subscription-contributors", "roleId": "${CONTRIBUTOR_ROLE_ID}", "useCommonAlertSchema": true }
  ]
}
JSON
)

az rest --method post --url "$URL" --body "$BODY" --headers "Content-Type=application/json"
echo
echo "Notification dispatched via REST. Give email a minute or two to arrive."
