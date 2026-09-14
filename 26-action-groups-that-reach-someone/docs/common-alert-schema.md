# Common Alert Schema: the payload shape, and why it matters here

Every receiver in this demo's action group sets `useCommonAlertSchema: true`.
This is not a cosmetic flag. It is what makes **one shared action group serving
many alert families** actually workable downstream.

## The problem it solves

Without the common schema, each Azure alert source hands your webhook a
**different JSON shape**:

- a metric alert payload looks nothing like an activity-log alert payload,
- which looks nothing like a Log Analytics query alert payload,
- which looks nothing like a budget notification.

If a single webhook (a ticketing bridge, a chat notifier) is wired to a shared
action group, it would otherwise need a parser branch per source, and every new
alert family would mean new code. That is exactly the friction that pushes teams
back towards one-action-group-per-alert, which is how you end up with alerts
that email one person.

## What the common schema guarantees

With `useCommonAlertSchema: true`, every alert - resource health, metric,
budget, log - arrives in the **same envelope**:

```json
{
  "schemaId": "azureMonitorCommonAlertSchema",
  "data": {
    "essentials": {
      "alertId": "/subscriptions/.../providers/Microsoft.AlertsManagement/alerts/...",
      "alertRule": "contoso-demo-26-workload-resource-health",
      "severity": "Sev3",
      "signalType": "Activity Log",
      "monitorCondition": "Fired",
      "monitoringService": "Resource Health",
      "alertTargetIDs": [
        "/subscriptions/.../resourceGroups/rg-contoso-demo-26-workload"
      ],
      "firedDateTime": "2026-09-14T09:42:56.0000000Z",
      "description": "..."
    },
    "alertContext": {
      "// source-specific fields live here, but essentials is always the same": ""
    }
  }
}
```

A downstream handler can read `data.essentials` - `alertRule`, `severity`,
`monitorCondition` (`Fired` vs `Resolved`), `alertTargetIDs` - for **every**
alert type, and only reach into `alertContext` when it needs source-specific
detail. One parser, every alert family.

## Why it matters for reaching a role instead of a person

The whole point of this demo is a central action group whose receivers are ARM
**roles** (Owner, Contributor) rather than a named mailbox. That central group
is only sustainable if adding a new alert family is cheap - and the common alert
schema is what keeps it cheap: the ticketing webhook, the on-call bridge, the
chat notifier all keep working unchanged when you bolt on the next alert.

## The one asymmetry to know about

Budget notifications (`Microsoft.Consumption/budgets`) are a slightly different
animal: they route through the action group's `contactGroups`, are evaluated
**asynchronously** (hours, not seconds), and their common-schema payload is
emitted when the notification is sent. The resource health and metric alerts in
this demo fire in near real time. Same envelope, very different cadence - worth
saying out loud on camera so nobody expects the budget alert to page instantly.

## References

- [Common alert schema](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-common-schema)
- [Common alert schema definitions](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-common-schema-definitions)
- [Create and manage action groups](https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups)
