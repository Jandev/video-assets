targetScope = 'resourceGroup'

@description('Azure region. The model must be available here for Global Standard deployment.')
param location string = resourceGroup().location

@description('Short suffix used to make globally unique resource names.')
@minLength(2)
@maxLength(12)
param nameSuffix string

@description('Object ID of the signed-in user who will run the demo.')
param principalId string

@description('Principal type for the role assignments.')
@allowed([
  'User'
  'ServicePrincipal'
])
param principalType string = 'User'

@description('Foundry model catalog name.')
param modelName string = 'gpt-4.1-mini'

@description('Foundry model version.')
param modelVersion string = '2025-04-14'

@description('Name used by the application when it invokes the model.')
param modelDeploymentName string = 'gpt-4.1-mini'

@description('Global Standard capacity, in thousands of tokens per minute.')
@minValue(1)
param modelCapacity int = 10

@description('Tags applied to every resource.')
param tags object = {
  demo: 'foundry-request-diagnostics'
  managedBy: 'bicep'
}

var baseName = 'demo28-${toLower(nameSuffix)}'

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    baseName: baseName
    principalId: principalId
    principalType: principalType
    tags: tags
  }
}

module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    location: location
    baseName: baseName
    principalId: principalId
    principalType: principalType
    modelName: modelName
    modelVersion: modelVersion
    modelDeploymentName: modelDeploymentName
    modelCapacity: modelCapacity
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    applicationInsightsResourceId: monitoring.outputs.applicationInsightsResourceId
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    tags: tags
  }
}

output foundryAccountName string = foundry.outputs.accountName
output foundryProjectName string = foundry.outputs.projectName
output foundryProjectEndpoint string = foundry.outputs.projectEndpoint
output modelDeploymentName string = modelDeploymentName
output applicationInsightsName string = monitoring.outputs.applicationInsightsName
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
