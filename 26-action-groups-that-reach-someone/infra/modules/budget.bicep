// =============================================================================
// Consumption budget (subscription scope) - alert family #2
// =============================================================================
// A monthly cost budget whose notification thresholds route to the SAME shared
// action group. This is the second alert family reusing one central group:
// resource health is an activity-log signal, this is a cost signal, and both
// land in the same place.
//
// NOTES worth reading out on camera:
//   * Budget notifications require the action group RESOURCE ID via
//     `contactGroups`. There is no "role receiver" concept in a budget - the
//     roles come from the action group, which is exactly why routing budgets
//     through a shared action group is the clean way to reach on-call.
//   * Budgets are evaluated ASYNCHRONOUSLY (hours, not seconds). A threshold
//     crossing does not page instantly; this is a slow-burn signal, unlike the
//     test notification in fire-test-alert.sh.
// =============================================================================

targetScope = 'subscription'

@description('Budget name (unique within the subscription).')
param budgetName string

@description('Monthly budget amount in the billing currency.')
param monthlyBudgetAmount int = 100

@description('First day of the month the budget becomes effective, e.g. 2026-09-01. Must be the 1st.')
param budgetStartDate string

@description('Resource ID of the shared action group that receives budget notifications.')
param actionGroupResourceId string

@description('Resource group names this budget is scoped to, so it only measures demo spend.')
param scopedResourceGroupNames array

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: budgetName
  properties: {
    amount: monthlyBudgetAmount
    category: 'Cost'
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    // Only count spend in the demo resource groups - a budget on the whole
    // subscription would page on everything.
    filter: {
      dimensions: {
        name: 'ResourceGroupName'
        operator: 'In'
        values: scopedResourceGroupNames
      }
    }
    notifications: {
      // 50% of budget, actual spend.
      actualFiftyPercent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        locale: 'en-us'
        contactEmails: []
        contactRoles: []
        // The action group carries the Owner/Contributor role receivers.
        contactGroups: [
          actionGroupResourceId
        ]
      }
      // 80% of budget, actual spend.
      actualEightyPercent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        locale: 'en-us'
        contactEmails: []
        contactRoles: []
        contactGroups: [
          actionGroupResourceId
        ]
      }
      // 100% forecast - warns before the month actually blows the budget.
      forecastedOneHundredPercent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        locale: 'en-us'
        contactEmails: []
        contactRoles: []
        contactGroups: [
          actionGroupResourceId
        ]
      }
    }
  }
}

output budgetId string = budget.id
