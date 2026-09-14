// =============================================================================
// Workload alerts (workload resource group) - the cross-RG consumption pattern
// =============================================================================
// This module lives in a DIFFERENT resource group from the action group, and
// this is the interesting part: it does not create an action group of its own.
// It references the shared one that already exists in the management resource
// group, using `existing` + `scope`. That is what turns "one central action
// group" from a slogan into something a second resource group actually reuses.
//
// It then wires up two more alert families onto that same group:
//   * a workload-scoped resource health activity-log alert (alert family #1,
//     but firing on THIS resource group)
//   * a placeholder metric alert (alert family #3), disabled, showing how a
//     metric alert attaches to the same shared group
// =============================================================================

@description('Prefix for alert rule names.')
param namePrefix string

@description('Azure region (used for the placeholder metric alert target region).')
param location string

@description('Name of the management resource group that holds the shared action group.')
param managementResourceGroupName string

@description('Name of the shared action group in the management resource group.')
param actionGroupName string

@description('Resource tags.')
param tags object = {}

// The shared action group already exists in ANOTHER resource group. `scope`
// points at that resource group; `existing` means "look it up, do not create
// it". No name drift: main.bicep passes the exact same name it deployed with.
resource sharedActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' existing = {
  name: actionGroupName
  scope: resourceGroup(managementResourceGroupName)
}

// Workload-scoped resource health alert, reusing the cross-RG action group.
resource workloadResourceHealthAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: '${namePrefix}-workload-resource-health'
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
          actionGroupId: sharedActionGroup.id
        }
      ]
    }
  }
}

// Placeholder metric alert (alert family #3). Deployed DISABLED: the workload RG
// has no real target resource in this demo, so this exists only to show how a
// metric alert attaches to the same shared action group. Virtual machines are
// used because Azure Monitor supports multi-resource VM metric alerts scoped to
// a resource group; storage accounts do not support that scope.
resource placeholderMetricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${namePrefix}-workload-high-cpu-placeholder'
  location: 'global'
  tags: tags
  properties: {
    description: 'Placeholder: VM CPU above 80%. Disabled until a real target resource exists. Routes to the shared action group.'
    severity: 3
    enabled: false
    scopes: [
      resourceGroup().id
    ]
    // Multiple-resource criteria let the alert target every resource of a type
    // in the scope, rather than one named resource - handy for a placeholder.
    targetResourceType: 'Microsoft.Compute/virtualMachines'
    targetResourceRegion: location
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'CpuAboveThreshold'
          criterionType: 'StaticThresholdCriterion'
          metricNamespace: 'Microsoft.Compute/virtualMachines'
          metricName: 'Percentage CPU'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: sharedActionGroup.id
      }
    ]
  }
}

output workloadResourceHealthAlertId string = workloadResourceHealthAlert.id
output placeholderMetricAlertId string = placeholderMetricAlert.id
