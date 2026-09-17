using './main.bicep'

// Replace values before deploying. Nothing here is customer-specific.
param location = 'westeurope'
param nameSuffix = ''
param alertEmailAddress = 'ops-team@example.com'
param retentionInDays = 30
param tags = {
  demo: 'contoso-log-alerts'
  managedBy: 'bicep'
  owner: 'ops-team@example.com'
}
