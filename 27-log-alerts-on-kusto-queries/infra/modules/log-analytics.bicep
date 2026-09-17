@description('Workspace name.')
param name string

@description('Azure region.')
param location string

@description('Retention in days.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Resource tags.')
param tags object = {}

// A plain workspace-based Log Analytics workspace. This demo is about the alert
// rules that read from it, so there is nothing exotic here - PerGB2018 with a
// short retention keeps the running cost of the demo down.
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output workspaceName string = workspace.name
output workspaceResourceId string = workspace.id
output customerId string = workspace.properties.customerId
