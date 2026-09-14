using './main.bicep'

// Replace values before deploying. Nothing here is customer-specific.
param location = 'westeurope'

// Optional suffix so several people can run the demo in one subscription.
param nameSuffix = ''

// A real mailbox you control, so the test notification actually arrives.
param alertEmailAddress = 'widget-oncall@example.com'

// Placeholder integration endpoint - stays on example.com for the demo.
param webhookUrl = 'https://example.com/contoso-demo-26/alert-webhook'

// Cost budget. Budgets are free; the notifications route to the shared group.
param monthlyBudgetAmount = 100

// Must be the first day of a month, and not in the past when you deploy.
param budgetStartDate = '2026-09-01'

param tags = {
  demo: 'contoso-demo-26-action-groups'
  managedBy: 'bicep'
  owner: 'widget-oncall@example.com'
}
