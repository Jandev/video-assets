#!/usr/bin/env python3
"""Microsoft Agent Framework version of the Foundry diagnostics demo."""

from __future__ import annotations

import argparse
import asyncio
import os
import time
from typing import Any

from agent_framework import Agent
from agent_framework.openai import OpenAIChatClient
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
    if not endpoint or not model:
        raise SystemExit(
            "Set AZURE_AI_FOUNDRY_ENDPOINT and AZURE_AI_MODEL_DEPLOYMENT "
            "(or source .azure-outputs.env)."
        )
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
        openai_client = AsyncOpenAI(
            base_url=f"{endpoint}/openai/v1",
            api_key=token_provider,
            http_client=http_client,
            max_retries=0,
            timeout=300.0,
        )
        chat_client = OpenAIChatClient(model=model, async_client=openai_client)
        agent = Agent(
            client=chat_client,
            name="foundry-diagnostics-agent",
            instructions="Be concise and follow the requested output format exactly.",
        )

        label = f"Microsoft Agent Framework | headers={'on' if include_headers else 'off'} | stream={stream}"
        with tracer.start_as_current_span("demo28.maf.invoke") as span:
            print_trace_id(span)
            span.set_attribute("demo.request_headers_enabled", include_headers)
            span.set_attribute("gen_ai.request.model", model)
            if headers:
                span.set_attribute("foundry.request.x-ms-client-request-id", headers["x-ms-client-request-id"])
            started = time.monotonic()
            if stream:
                parts: list[str] = []
                response_stream = agent.run(
                    PROMPT,
                    stream=True,
                    client_kwargs={"extra_headers": headers},
                )
                async for update in response_stream:
                    if update.text:
                        parts.append(update.text)
                answer = "".join(parts)
            else:
                response = await agent.run(
                    PROMPT,
                    client_kwargs={"extra_headers": headers},
                )
                answer = response.text
            elapsed_ms = (time.monotonic() - started) * 1000
            span.set_attribute("http.response.status_code", recorder.last_status_code or 0)
            for header_name, header_value in recorder.last_response_headers.items():
                if header_name in {"apim-request-id", "x-request-id", "openai-processing-ms"}:
                    span.set_attribute(f"foundry.response.{header_name}", header_value)

        print_diagnostic_summary(
            label=label,
            request_headers=recorder.last_request_headers,
            response_headers=recorder.last_response_headers,
            status_code=recorder.last_status_code,
            elapsed_ms=elapsed_ms,
        )
        print(f"Answer: {answer.strip()}")
        await openai_client.close()

    provider = trace.get_tracer_provider()
    force_flush = getattr(provider, "force_flush", None)
    if callable(force_flush):
        force_flush(timeout_millis=10_000)


async def main() -> None:
    args = parse_args()
    endpoint, model = required_environment()
    tracer = configure_tracing("demo28-maf")
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


if __name__ == "__main__":
    asyncio.run(main())
