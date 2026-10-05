#!/usr/bin/env python3
"""Direct OpenAI SDK baseline for Foundry request diagnostics."""

from __future__ import annotations

import argparse
import asyncio
import os
import time
from typing import Any

from azure.identity.aio import DefaultAzureCredential, get_bearer_token_provider
from openai import AsyncOpenAI
from opentelemetry import trace

from diagnostics import (
    HttpExchangeRecorder,
    configure_tracing,
    correlation_headers,
    print_diagnostic_summary,
    print_trace_id,
)

PROMPT = "List exactly three primary colours. Answer in under 15 words."
TOKEN_SCOPE = "https://ai.azure.com/.default"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--headers", choices=("with", "without", "both"), default="both")
    parser.add_argument("--stream", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--wire", action=argparse.BooleanOptionalAction, default=True)
    return parser.parse_args()


def required_environment() -> tuple[str, str]:
    endpoint = os.getenv("AZURE_AI_FOUNDRY_ENDPOINT") or os.getenv("FOUNDRY_PROJECT_ENDPOINT")
    model = os.getenv("AZURE_AI_MODEL_DEPLOYMENT")
    missing = [
        name
        for name, value in (
            ("AZURE_AI_FOUNDRY_ENDPOINT", endpoint),
            ("AZURE_AI_MODEL_DEPLOYMENT", model),
        )
        if not value
    ]
    if missing:
        raise SystemExit(f"Missing environment variable(s): {', '.join(missing)}")
    return endpoint.rstrip("/"), model


async def invoke(
    *,
    endpoint: str,
    model: str,
    credential: DefaultAzureCredential,
    include_headers: bool,
    stream: bool,
    wire: bool,
    tracer: Any,
) -> None:
    recorder = HttpExchangeRecorder(print_wire=wire)
    headers = correlation_headers(include_headers)
    token_provider = get_bearer_token_provider(credential, TOKEN_SCOPE)

    async with recorder.create_http_client() as http_client:
        client = AsyncOpenAI(
            base_url=f"{endpoint}/openai/v1",
            api_key=token_provider,
            default_headers=headers,
            http_client=http_client,
            max_retries=0,
            timeout=300.0,
        )
        label = f"OpenAI SDK | headers={'on' if include_headers else 'off'} | stream={stream}"
        with tracer.start_as_current_span("foundry.responses.request") as span:
            print_trace_id(span)
            span.set_attribute("demo.request_headers_enabled", include_headers)
            span.set_attribute("gen_ai.request.model", model)
            if headers:
                span.set_attribute("foundry.request.x-ms-client-request-id", headers["x-ms-client-request-id"])
            started = time.monotonic()
            raw = await client.responses.with_raw_response.create(
                model=model,
                input=PROMPT,
                stream=stream,
                store=False,
            )
            response_headers = dict(raw.headers)
            parsed = raw.parse()
            if stream:
                text_parts: list[str] = []
                async for event in parsed:
                    delta = getattr(event, "delta", None)
                    if isinstance(delta, str):
                        text_parts.append(delta)
                answer = "".join(text_parts)
            else:
                answer = parsed.output_text
            elapsed_ms = (time.monotonic() - started) * 1000
            span.set_attribute("http.response.status_code", recorder.last_status_code or 0)
            for header_name, header_value in response_headers.items():
                if header_name.lower() in {"apim-request-id", "x-request-id", "openai-processing-ms"}:
                    span.set_attribute(f"foundry.response.{header_name.lower()}", header_value)

        print_diagnostic_summary(
            label=label,
            request_headers=recorder.last_request_headers,
            response_headers=response_headers,
            status_code=recorder.last_status_code,
            elapsed_ms=elapsed_ms,
        )
        print(f"Answer: {answer.strip()}")
        await client.close()


async def main() -> None:
    args = parse_args()
    endpoint, model = required_environment()
    tracer = configure_tracing("demo28-openai")
    states = [False, True] if args.headers == "both" else [args.headers == "with"]
    async with DefaultAzureCredential() as credential:
        for include_headers in states:
            await invoke(
                endpoint=endpoint,
                model=model,
                credential=credential,
                include_headers=include_headers,
                stream=args.stream,
                wire=args.wire,
                tracer=tracer,
            )
    provider = trace.get_tracer_provider()
    force_flush = getattr(provider, "force_flush", None)
    if callable(force_flush):
        force_flush(timeout_millis=10_000)


if __name__ == "__main__":
    asyncio.run(main())
