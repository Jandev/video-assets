// =============================================================================
// Log alerts on Kusto queries - the privacy-safe part
// =============================================================================
// Four scheduled query rules over the app's own telemetry. The distinctive
// point of this module is NOT the KQL logic - it is that every query returns a
// single aggregate count and NOTHING else.
//
// A scheduled query rule copies whatever its query returns into the alert
// payload: the notification email, the webhook body, the ticket. A query with a
// `| take 10` in it quietly exfiltrates ten customer request rows into your
// inbox on every evaluation. So each query here ends in one
// `summarize <Name> = count()/countif(...)` producing ONE numeric column, wired
// to the rule through `metricMeasureColumn`.
//
// Settings people get wrong, all deliberate here:
//   - evaluationFrequency (how often the rule runs) vs windowSize (how much
//     history each run looks at). Both PT5M, and the KQL uses ago(5m) to match.
//   - metricMeasureColumn is MANDATORY once you compare a numeric column to a
//     threshold. Omit it and the deployment fails.
//   - failingPeriods lets a single bad window fire immediately (1 of 1) instead
//     of waiting for several consecutive breaches.
//   - skipQueryValidation lets the rule deploy against tables that do not exist
//     yet (an empty workspace has no AppRequests rows until the app runs).
// =============================================================================

@description('Prefix for alert rule names.')
param namePrefix string

@description('Azure region.')
param location string

@description('Resource ID of the Log Analytics workspace to query.')
param workspaceResourceId string

@description('Resource ID of the action group to notify.')
param actionGroupResourceId string

@description('Resource tags.')
param tags object = {}

// -----------------------------------------------------------------------------
// Queries. Each triple-quoted string is byte-identical to the matching file in
// queries/. scripts/validate-queries.sh fails the build if they ever drift, so
// the queries/ folder is the real, runnable source of truth - not decoration.
//
// GOTCHA: Bicep triple-quoted strings are VERBATIM - no ${...} interpolation.
// The AppRoleName is hard-coded on purpose; it is the app's OpenTelemetry
// service.name and must match exactly.
// -----------------------------------------------------------------------------
var serverErrorsQuery = '''
// Privacy-safe alert query: returns ONE aggregate count column and nothing else.
// It deliberately does NOT return request paths, query strings, client IPs,
// user or principal ids, or headers - no per-request row leaves the workspace.
// Everything a query returns lands in the alert payload, the notification email
// and any downstream webhook or ticket, so the query returns only a count.
AppRequests
| where TimeGenerated > ago(5m)
| where AppRoleName =~ 'contoso-widget-api'
| summarize ServerErrorCount = countif(toint(ResultCode) >= 500)
'''

var authorizationAnomalyQuery = '''
// Privacy-safe alert query: returns ONE aggregate count column and nothing else.
// It deliberately does NOT return client IPs, user or principal ids, tokens,
// authorization headers, or the requested path. A 401/403 spike is triaged from
// the count plus server-side identity signals - never from request content,
// which would copy authentication data into every notification channel.
AppRequests
| where TimeGenerated > ago(5m)
| where AppRoleName =~ 'contoso-widget-api'
| summarize AuthFailureCount = countif(toint(ResultCode) in (401, 403))
'''

var dependencyFailuresQuery = '''
// Privacy-safe alert query: returns ONE aggregate count column and nothing else.
// It deliberately does NOT return dependency targets, connection strings, SQL
// text, command parameters, or any data returned by the dependency call. A
// failed dependency is investigated from the count and a trace id, not from the
// payload of the failing call.
AppDependencies
| where TimeGenerated > ago(5m)
| where AppRoleName =~ 'contoso-widget-api'
| where Success == false
| summarize DependencyFailureCount = count()
'''

var availabilityQuery = '''
// Privacy-safe alert query: returns ONE aggregate count column and nothing else.
// It deliberately does NOT return per-request rows - it exists to detect the
// ABSENCE of telemetry, the alert people forget to write. When the count drops
// to zero the app has stopped reporting (crash, bad deploy, broken egress),
// which is invisible to every rule that only looks for errors.
AppRequests
| where TimeGenerated > ago(5m)
| where AppRoleName =~ 'contoso-widget-api'
| summarize RequestCount = count()
'''

// -----------------------------------------------------------------------------
// [1] Server errors - 5xx responses from the API
// -----------------------------------------------------------------------------
resource serverErrorsAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-server-errors'
  location: location
  kind: 'LogAlert'
  tags: tags
  properties: {
    displayName: '${namePrefix}: server errors (HTTP 5xx)'
    description: 'Platform Operations owns response to five or more HTTP 5xx responses from contoso-widget-api within five minutes. The query returns only an aggregate count and does not expose request paths, client, or header data.'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    checkWorkspaceAlertsStorageConfigured: false
    skipQueryValidation: true
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: serverErrorsQuery
          timeAggregation: 'Total'
          metricMeasureColumn: 'ServerErrorCount'
          operator: 'GreaterThanOrEqual'
          threshold: 5
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    muteActionsDuration: 'PT30M'
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

// -----------------------------------------------------------------------------
// [2] Authorization anomaly - a burst of 401/403 (owned by Security Operations)
// -----------------------------------------------------------------------------
// Higher threshold than the 5xx rule: a few 401s are normal (expired tokens,
// the odd misconfigured client). A burst is what matters, and it is a security
// signal - which is exactly why the query must not carry any identity data.
resource authorizationAnomalyAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-authorization-anomaly'
  location: location
  kind: 'LogAlert'
  tags: tags
  properties: {
    displayName: '${namePrefix}: authorization anomaly (HTTP 401/403)'
    description: 'Security Operations owns investigation of twenty or more HTTP 401/403 responses from contoso-widget-api within five minutes. The query returns only an aggregate count and does not retain client, path, token, or header values.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    checkWorkspaceAlertsStorageConfigured: false
    skipQueryValidation: true
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: authorizationAnomalyQuery
          timeAggregation: 'Total'
          metricMeasureColumn: 'AuthFailureCount'
          operator: 'GreaterThanOrEqual'
          threshold: 20
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    muteActionsDuration: 'PT30M'
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

// -----------------------------------------------------------------------------
// [3] Dependency failures - failed outbound calls (AppDependencies)
// -----------------------------------------------------------------------------
resource dependencyFailuresAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-dependency-failures'
  location: location
  kind: 'LogAlert'
  tags: tags
  properties: {
    displayName: '${namePrefix}: outbound dependency failures'
    description: 'Platform Operations owns response to three or more failed outbound dependency calls from contoso-widget-api within five minutes. The query returns only an aggregate count and does not expose dependency targets, connection strings, or payloads.'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    checkWorkspaceAlertsStorageConfigured: false
    skipQueryValidation: true
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: dependencyFailuresQuery
          timeAggregation: 'Total'
          metricMeasureColumn: 'DependencyFailureCount'
          operator: 'GreaterThanOrEqual'
          threshold: 3
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    muteActionsDuration: 'PT30M'
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

// -----------------------------------------------------------------------------
// [4] Availability - fires when request volume drops to ZERO
// -----------------------------------------------------------------------------
// The alert people forget to write. Every other rule fires when something bad
// happens; this one fires when NOTHING happens. A crash, a bad deploy or broken
// egress produces no errors at all - it produces silence, and silence is
// invisible to error-based rules. operator LessThan 1 means "fewer than one
// request in the window", i.e. the app has gone quiet.
resource availabilityAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${namePrefix}-availability'
  location: location
  kind: 'LogAlert'
  tags: tags
  properties: {
    displayName: '${namePrefix}: no requests (availability)'
    description: 'Platform Operations owns response when contoso-widget-api reports zero requests in a five-minute window, which indicates the service has stopped serving traffic. The query returns only an aggregate count.'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    checkWorkspaceAlertsStorageConfigured: false
    skipQueryValidation: true
    scopes: [
      workspaceResourceId
    ]
    criteria: {
      allOf: [
        {
          query: availabilityQuery
          timeAggregation: 'Total'
          metricMeasureColumn: 'RequestCount'
          operator: 'LessThan'
          threshold: 1
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    muteActionsDuration: 'PT30M'
    actions: {
      actionGroups: [
        actionGroupResourceId
      ]
    }
  }
}

output serverErrorsAlertName string = serverErrorsAlert.name
output authorizationAnomalyAlertName string = authorizationAnomalyAlert.name
output dependencyFailuresAlertName string = dependencyFailuresAlert.name
output availabilityAlertName string = availabilityAlert.name
