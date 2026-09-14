// =============================================================================
// The shared, central action group - the whole point of this demo
// =============================================================================
// This is ONE action group, deployed once into a management resource group, and
// reused by every alert family across every workload resource group.
//
// The receivers are deliberately mixed to show three kinds side by side:
//
//   armRoleReceivers  -> notify whoever currently holds a ROLE (Owner /
//                        Contributor) on the scope the alert fires against.
//                        Nobody's personal mailbox. When someone leaves, they
//                        lose the role and stop being paged automatically.
//   emailReceivers    -> one concrete mailbox, so the demo actually delivers
//                        mail on camera. In production this would be a shared
//                        distribution list, never an individual.
//   webhookReceivers  -> a placeholder integration endpoint (ticketing / chat).
//
// Every receiver sets useCommonAlertSchema: true so downstream handlers see one
// stable payload shape regardless of which alert family fired. See
// docs/common-alert-schema.md.
// =============================================================================

@description('Action group resource name (unique within the resource group).')
@maxLength(260)
param name string

// groupShortName is a CLASSIC deployment failure: max 12 characters. It becomes
// the prefix on SMS and email notifications, so Azure enforces the limit hard.
// A name like "contoso-demo-26-oncall" is 22 chars and the deployment is
// rejected with "groupShortName ... exceeds the maximum length of 12". Keep it
// short and let @maxLength catch it at build time instead of at deploy time.
@description('Short name used as the SMS/email prefix. Hard limit: 12 characters.')
@maxLength(12)
param groupShortName string

@description('One real mailbox that receives notifications so the demo delivers mail on camera. Use a shared distribution list in production, never a person.')
param alertEmailAddress string

@description('Placeholder webhook endpoint (ticketing/chat integration). Kept on example.com for the demo.')
param webhookUrl string = 'https://example.com/contoso-demo-26/alert-webhook'

@description('Azure built-in role definition GUID for Owner. Public Azure constant.')
param ownerRoleId string = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'

@description('Azure built-in role definition GUID for Contributor. Public Azure constant.')
param contributorRoleId string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

@description('Resource tags.')
param tags object = {}

// Action groups are GLOBAL resources - location is always 'Global'.
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: name
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: groupShortName
    enabled: true

    // [1] The point of the demo: reach a ROLE, not a person.
    // Whoever currently holds Owner or Contributor on the alert's scope gets
    // notified. No named mailbox to go stale the day that person changes teams.
    armRoleReceivers: [
      {
        name: 'subscription-owners'
        roleId: ownerRoleId
        useCommonAlertSchema: true
      }
      {
        name: 'subscription-contributors'
        roleId: contributorRoleId
        useCommonAlertSchema: true
      }
    ]

    // [2] One concrete mailbox, so mail actually lands during the recording.
    emailReceivers: [
      {
        name: 'oncall-distribution'
        emailAddress: alertEmailAddress
        useCommonAlertSchema: true
      }
    ]

    // [3] A placeholder webhook - where a ticket or chat integration would hook
    // in. Common Alert Schema is what makes a single handler here viable.
    webhookReceivers: [
      {
        name: 'ticketing-webhook'
        serviceUri: webhookUrl
        useCommonAlertSchema: true
      }
    ]
  }
}

output actionGroupResourceId string = actionGroup.id
output actionGroupName string = actionGroup.name
