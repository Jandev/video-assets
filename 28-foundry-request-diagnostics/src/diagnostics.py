"""Shared, intentionally small diagnostics helpers for both demo applications."""

from __future__ import annotations

import json
import os
from collections.abc import Mapping
from typing import Any
from uuid import uuid4

from azure.monitor.opentelemetry import configure_azure_monitor
from openai import DefaultAsyncHttpxClient
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource

REQUEST_HEADER = "x-ms-client-request-id"

RESPONSE_HEADERS = {
    "apim-request-id",
    "azureai-fe-is-streaming",
    "azureai-fe-requested-service-tier",
    "azureml-served-by-cluster",
    "openai-processing-ms",
    "x-ms-client-request-id",
    "x-ms-region",
    "x-ms-served-model",
    "x-ratelimit-limit-requests",
    "x-ratelimit-limit-tokens",
    "x-ratelimit-remaining-requests",
    "x-ratelimit-remaining-tokens",
    "x-request-id",
}

SECRET_HEADERS = {"api-key", "authorization", "cookie", "set-cookie"}


def correlation_headers(enabled: bool) -> dict[str, str]:
    """Return a fresh caller-owned identifier, or no extra headers."""
    return {REQUEST_HEADER: str(uuid4())} if enabled else {}


def selected_response_headers(headers: Mapping[str, str]) -> dict[str, str]:
    return {
        key.lower(): value
        for key, value in headers.items()
        if key.lower() in RESPONSE_HEADERS
    }


def redact_headers(headers: Mapping[str, str]) -> dict[str, str]:
    return {
        key: "<redacted>" if key.lower() in SECRET_HEADERS else value
        for key, value in headers.items()
    }


def _pretty_body(content: bytes) -> str:
    if not content:
        return "<empty>"
    try:
        parsed = json.loads(content)
        return json.dumps(parsed, indent=2, ensure_ascii=False)
    except (UnicodeDecodeError, json.JSONDecodeError):
        return content.decode("utf-8", errors="replace")


class HttpExchangeRecorder:
    """Records the request plus response metadata without leaking credentials."""

    def __init__(self, *, print_wire: bool) -> None:
        self.print_wire = print_wire
        self.last_request_headers: dict[str, str] = {}
        self.last_response_headers: dict[str, str] = {}
        self.last_status_code: int | None = None

    async def on_request(self, request: Any) -> None:
        body = await request.aread()
        self.last_request_headers = {
            key.lower(): value for key, value in redact_headers(dict(request.headers)).items()
        }
        if self.print_wire:
            print("\n--- outbound HTTP request (credentials redacted) ---")
            print(f"{request.method} {request.url}")
            print(json.dumps(self.last_request_headers, indent=2, sort_keys=True))
            print(_pretty_body(body))

    async def on_response(self, response: Any) -> None:
        self.last_status_code = response.status_code
        self.last_response_headers = {
            key.lower(): value for key, value in dict(response.headers).items()
        }
        if self.print_wire:
            print("\n--- inbound HTTP response metadata ---")
            print(f"HTTP {response.status_code}")
            print(json.dumps(selected_response_headers(self.last_response_headers), indent=2, sort_keys=True))

    def create_http_client(self) -> DefaultAsyncHttpxClient:
        return DefaultAsyncHttpxClient(
            event_hooks={
                "request": [self.on_request],
                "response": [self.on_response],
            }
        )


def configure_tracing(service_name: str) -> Any:
    """Configure Azure Monitor when deployed, while remaining runnable offline."""
    connection_string = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if connection_string:
        configure_azure_monitor(
            connection_string=connection_string,
            resource=Resource.create({"service.name": service_name}),
            enable_live_metrics=False,
        )
        destination = "Application Insights"
    else:
        destination = "local only (APPLICATIONINSIGHTS_CONNECTION_STRING is unset)"

    tracer = trace.get_tracer(service_name)
    print(f"Trace destination: {destination}")
    return tracer


def print_trace_id(span: Any) -> None:
    trace_id = span.get_span_context().trace_id
    print(f"Trace ID: {trace_id:032x}")


def print_diagnostic_summary(
    *,
    label: str,
    request_headers: Mapping[str, str],
    response_headers: Mapping[str, str],
    status_code: int | None,
    elapsed_ms: float,
) -> None:
    selected = selected_response_headers(response_headers)
    print(f"\n=== {label} ===")
    print(f"HTTP status: {status_code if status_code is not None else '<not captured>'}")
    print(f"Client wall clock: {elapsed_ms:,.0f} ms")
    print("Request correlation:")
    print(f"  {REQUEST_HEADER}: {request_headers.get(REQUEST_HEADER, '<not sent>')}")
    print("Foundry response headers:")
    if selected:
        for key, value in sorted(selected.items()):
            print(f"  {key}: {value}")
    else:
        print("  <none of the selected headers were returned>")
