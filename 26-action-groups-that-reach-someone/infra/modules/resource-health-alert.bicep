// =============================================================================
// Resource health alert (management resource group) - alert family #1
// =============================================================================
// An activity log alert that fires when Azure reports a resource in this
// resource group as unhealthy (Resource Health, status Active). It notifies the
// SHARED action group that lives in the same management resource group.
//
// This is the "in the same RG" consumption of the group. workload-alerts.bicep
// shows the harder, cross-resource-group consumption of the exact same group.
// =============================================================================

@description('Alert rule name.')
param name string

@description('Resource ID of the shared action group to notify.')
param actionGroupResourceId string

// activityLogAlerts are global resources - the scope is set inside properties.
resource resourceHealthAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: name
  location: 'global'
  properties: {
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ResourceHealth'
        }
        {
          field: 'status'
          equals: 'Active'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroupResourceId
        }
      ]
    }
  }
}

output resourceHealthAlertId string = resourceHealthAlert.id
