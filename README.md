# Video assets and demos

This repository holds the supporting assets, examples, and runnable demos for
YouTube videos I share. Each demo lives in its own directory and includes the
instructions and context needed to explore it independently.

## Demos

| Demo | What it covers |
| --- | --- |
| [26 — Action groups that reach someone](26-action-groups-that-reach-someone/) | A runnable Azure Bicep demo showing one shared action group, role-based receivers, cross-resource-group reuse, resource health alerts, a cost budget, and a metric alert. |
| [27 — Privacy-safe log alerts](27-log-alerts-on-kusto-queries/) | Four runnable KQL log alerts that aggregate telemetry without copying customer request data into notifications. |
| [28 — Foundry request diagnostics](28-foundry-request-diagnostics/) | Deploy Foundry plus a model and trace store, then compare OpenAI SDK and Microsoft Agent Framework calls with correlation headers, response diagnostics and end-to-end traces. |

Start with the README inside a demo directory for prerequisites, architecture,
deployment instructions, verification, and cleanup steps.

## Using these materials

You are welcome to use, share, and adapt the material in this repository,
including for commercial purposes. Please credit **Jan de Vries**, link back to
this repository when practical, and indicate if you made changes.

The repository is licensed under the
[Creative Commons Attribution 4.0 International License](LICENSE). Individual
third-party components remain subject to their own licenses.

These demos can create or modify cloud resources. Review the templates and
scripts before running them, use a non-production environment, and run the
provided cleanup steps when you are finished.
