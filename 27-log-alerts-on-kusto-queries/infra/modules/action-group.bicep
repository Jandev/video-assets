@description('Action group name.')
@maxLength(260)
param name string

@description('Email address that receives the alerts.')
param emailAddress string

@description('Resource tags.')
param tags object = {}

// Action groups are global resources. `groupShortName` is limited to 12
// characters and shows up as the email/SMS prefix. This demo ships its own
// notification target so it is fully standalone.
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: name
  location: 'global'
  tags: tags
  properties: {
    groupShortName: take(replace(name, 'contoso-demo-', ''), 12)
    enabled: true
    emailReceivers: [
      {
        name: 'ops-team'
        emailAddress: emailAddress
        // Common Alert Schema keeps the payload identical across every rule,
        // which is what makes a single downstream webhook handler viable - and
        // is also why the query must not put customer data in that payload.
        useCommonAlertSchema: true
      }
    ]
  }
}

output actionGroupResourceId string = actionGroup.id
output actionGroupName string = actionGroup.name
