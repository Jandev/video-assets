@description('Application Insights component name.')
param name string

@description('Azure region.')
param location string

@description('Resource ID of the backing Log Analytics workspace.')
param workspaceResourceId string

@description('Resource tags.')
param tags object = {}

// Workspace-based Application Insights. The telemetry the API emits (requests,
// dependencies, traces) is stored in the linked workspace, which is what the
// scheduled query rules read - AppRequests and AppDependencies both live there.
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    DisableLocalAuth: false
  }
}

output name string = appInsights.name
output resourceId string = appInsights.id
output connectionString string = appInsights.properties.ConnectionString
output instrumentationKey string = appInsights.properties.InstrumentationKey
