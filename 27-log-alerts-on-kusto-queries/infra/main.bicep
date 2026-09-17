// =============================================================================
// Contoso Widget Platform - log alerts on Kusto queries (demo 27)
// =============================================================================
// Deploys a self-contained stack that demonstrates PRIVACY-SAFE log alerting:
//
//   1. Log Analytics workspace          (stores the telemetry)
//   2. Application Insights (workspace)  (where contoso-widget-api reports)
//   3. Action group                      (this demo's own email target)
//   4. Four scheduled query rules        (server errors, authorization anomaly,
//                                         dependency failures, availability)
//
// The point of the demo is in the queries: each alert query returns a single
// aggregate count and nothing else, because everything a query returns ends up
// in the alert payload, the email and any webhook behind it.
// =============================================================================

targetScope = 'resourceGroup'

@description('Azure region.')
param location string = resourceGroup().location

@description('Suffix appended to resource names to avoid global-name collisions.')
@minLength(0)
@maxLength(12)
param nameSuffix string = ''

@description('Email address that receives the alerts. Use a real mailbox you control.')
param alertEmailAddress string = 'ops-team@example.com'

@description('Retention in days for the workspace.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Resource tags.')
param tags object = {
  demo: 'contoso-log-alerts'
  managedBy: 'bicep'
}

var namePrefix = empty(nameSuffix) ? 'contoso-demo-27' : 'contoso-demo-27-${nameSuffix}'
var workspaceName = 'law-${namePrefix}'
var appInsightsName = 'appi-${namePrefix}'
var actionGroupName = 'ag-${namePrefix}'

module workspace 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    name: workspaceName
    location: location
    retentionInDays: retentionInDays
    tags: tags
  }
}

module appInsights 'modules/application-insights.bicep' = {
  name: 'deploy-app-insights'
  params: {
    name: appInsightsName
    location: location
    workspaceResourceId: workspace.outputs.workspaceResourceId
    tags: tags
  }
}

module actionGroup 'modules/action-group.bicep' = {
  name: 'deploy-action-group'
  params: {
    name: actionGroupName
    emailAddress: alertEmailAddress
    tags: tags
  }
}

module alerts 'modules/log-alerts.bicep' = {
  name: 'deploy-log-alerts'
  params: {
    namePrefix: namePrefix
    location: location
    workspaceResourceId: workspace.outputs.workspaceResourceId
    actionGroupResourceId: actionGroup.outputs.actionGroupResourceId
    tags: tags
  }
}

output workspaceName string = workspace.outputs.workspaceName
output workspaceResourceId string = workspace.outputs.workspaceResourceId
output workspaceCustomerId string = workspace.outputs.customerId
output appInsightsName string = appInsights.outputs.name
output appInsightsConnectionString string = appInsights.outputs.connectionString
output actionGroupName string = actionGroup.outputs.actionGroupName
output serverErrorsAlertName string = alerts.outputs.serverErrorsAlertName
output authorizationAnomalyAlertName string = alerts.outputs.authorizationAnomalyAlertName
output dependencyFailuresAlertName string = alerts.outputs.dependencyFailuresAlertName
output availabilityAlertName string = alerts.outputs.availabilityAlertName
