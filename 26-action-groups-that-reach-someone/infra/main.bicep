// =============================================================================
// Contoso Widget Platform - one shared action group that reaches a ROLE
// =============================================================================
// An alert that emails one person's mailbox is a liability the day that person
// changes teams or leaves: the alert keeps firing into a mailbox nobody reads,
// and the people who should act never hear about it.
//
// The fix is ONE central action group, deployed into a management resource
// group, with ARM ROLE receivers (Owner + Contributor). It notifies whoever
// currently holds that role - no named mailbox to go stale. Every workload
// resource group and every alert family reuses that single group.
//
// This template is `targetScope = 'subscription'` on purpose: it creates two
// resource groups so the cross-resource-group `existing` + `scope` reuse of the
// action group is real and demonstrable, not hand-waved.
//
//   rg-contoso-demo-26-management  the shared action group
//                                  + a resource health alert (family #1)
//   rg-contoso-demo-26-workload    a workload resource health alert (family #1)
//                                  + a placeholder metric alert (family #3)
//   subscription scope             a cost budget (family #2)
//
// All three alert families route to the same shared action group.
// =============================================================================

targetScope = 'subscription'

@description('Azure region for the resource groups and region-scoped alerts.')
param location string = 'westeurope'

@description('Suffix appended to names to avoid collisions when several people run the demo in one subscription. Leave empty for the plain names.')
@maxLength(8)
param nameSuffix string = ''

@description('One real mailbox that receives notifications so the demo delivers mail on camera. Use a shared distribution list in production, never a person.')
param alertEmailAddress string = 'widget-oncall@example.com'

@description('Placeholder webhook endpoint for the action group. Kept on example.com for the demo.')
param webhookUrl string = 'https://example.com/contoso-demo-26/alert-webhook'

@description('Monthly cost budget amount in the billing currency.')
param monthlyBudgetAmount int = 100

@description('First day of the month the budget becomes effective, e.g. 2026-09-01. Must be the 1st of a month.')
param budgetStartDate string = '2026-09-01'

@description('Tags applied to every resource group.')
param tags object = {
  demo: 'contoso-demo-26-action-groups'
  managedBy: 'bicep'
}

var demoId = 'contoso-demo-26'
var suffix = empty(nameSuffix) ? '' : '-${nameSuffix}'

var managementResourceGroupName = 'rg-${demoId}-management${suffix}'
var workloadResourceGroupName = 'rg-${demoId}-workload${suffix}'

// One name, computed once, passed to both the module that CREATES the action
// group and the module that CONSUMES it cross-RG - so the `existing` lookup can
// never drift from the deployed name.
var actionGroupName = '${demoId}-oncall${suffix}'

// groupShortName is capped at 12 characters. "contoso-demo-26-oncall" is far too
// long, so the demo uses a deliberately short, stable short name.
var groupShortName = 'cd26-oncall'

resource managementRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: managementResourceGroupName
  location: location
  tags: tags
}

resource workloadRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: workloadResourceGroupName
  location: location
  tags: tags
}

// -----------------------------------------------------------------------------
// The shared action group, in the management resource group.
// -----------------------------------------------------------------------------
module actionGroup 'modules/action-group.bicep' = {
  name: 'deploy-action-group'
  scope: managementRg
  params: {
    name: actionGroupName
    groupShortName: groupShortName
    alertEmailAddress: alertEmailAddress
    webhookUrl: webhookUrl
    tags: tags
  }
}

// Alert family #1, in the management RG (same-RG consumption of the group).
module managementResourceHealth 'modules/resource-health-alert.bicep' = {
  name: 'deploy-management-resource-health'
  scope: managementRg
  params: {
    name: '${demoId}-management-resource-health${suffix}'
    actionGroupResourceId: actionGroup.outputs.actionGroupResourceId
  }
}

// Alert family #2, at subscription scope: a cost budget wired to the same group.
module budget 'modules/budget.bicep' = {
  name: 'deploy-budget'
  params: {
    budgetName: '${demoId}-monthly-budget${suffix}'
    monthlyBudgetAmount: monthlyBudgetAmount
    budgetStartDate: budgetStartDate
    actionGroupResourceId: actionGroup.outputs.actionGroupResourceId
    scopedResourceGroupNames: [
      managementResourceGroupName
      workloadResourceGroupName
    ]
  }
}

// Alert families #1 and #3, in the workload RG: the cross-RG reuse of the group.
module workloadAlerts 'modules/workload-alerts.bicep' = {
  name: 'deploy-workload-alerts'
  scope: workloadRg
  params: {
    namePrefix: '${demoId}${suffix}'
    location: location
    managementResourceGroupName: managementResourceGroupName
    actionGroupName: actionGroupName
    tags: tags
  }
}

output managementResourceGroup string = managementResourceGroupName
output workloadResourceGroup string = workloadResourceGroupName
output actionGroupName string = actionGroupName
output actionGroupResourceId string = actionGroup.outputs.actionGroupResourceId
output groupShortName string = groupShortName
