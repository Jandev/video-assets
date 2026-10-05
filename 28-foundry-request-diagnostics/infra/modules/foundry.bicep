targetScope = 'resourceGroup'

param location string
param baseName string
param principalId string
param principalType string
param modelName string
param modelVersion string
param modelDeploymentName string
param modelCapacity int
param applicationInsightsName string
param applicationInsightsResourceId string
@secure()
param applicationInsightsConnectionString string
param tags object

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: 'foundry-${baseName}'
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    allowProjectManagement: true
    customSubDomainName: 'foundry-${baseName}'
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }

  resource modelDeployment 'deployments' = {
    name: modelDeploymentName
    sku: {
      name: 'GlobalStandard'
      capacity: modelCapacity
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: modelName
        version: modelVersion
      }
      versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    }
  }

  resource project 'projects' = {
    name: 'project-${baseName}'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    tags: tags
    properties: {
      displayName: 'Foundry request diagnostics'
      description: 'Demo project for correlating model requests, response headers and OpenTelemetry traces.'
    }
    dependsOn: [
      modelDeployment
    ]
  }
}

resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: account::project
  name: 'application-insights'
  properties: {
    category: 'AppInsights'
    target: applicationInsightsResourceId
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: applicationInsightsConnectionString
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: applicationInsightsResourceId
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

// Azure AI User, scoped to this project: enough to invoke the deployed model.
resource azureAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account::project
  name: guid(account::project.id, principalId, '53ca6127-db72-4b80-b1b0-d745d6d5456d')
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '53ca6127-db72-4b80-b1b0-d745d6d5456d')
  }
}

// The project identity can read its connected trace store.
resource projectLogAnalyticsReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: applicationInsights
  name: guid(applicationInsightsResourceId, account::project.id, '73c42c96-874c-492b-b04d-ab87d138a893')
  properties: {
    principalId: account::project.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '73c42c96-874c-492b-b04d-ab87d138a893')
  }
}

output accountName string = account.name
output projectName string = account::project.name
output projectEndpoint string = account::project.properties.endpoints['AI Foundry API']
