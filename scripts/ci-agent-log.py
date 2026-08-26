#!/usr/bin/env python3
"""Read Cursor agent stream-json (NDJSON) on stdin. Print short flushed CI lines."""
from __future__ import annotations

import json
import os
import sys


def emit(line: str, *, summary: bool = False) -> None:
    print(line, flush=True)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary and path:
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")


def tool_label(event: dict) -> str:
    payload = event.get("tool_call")
    if not isinstance(payload, dict):
        return event.get("subtype") or "tool"
    for key, body in payload.items():
        name = str(key).replace("ToolCall", "")
        args = {}
        if isinstance(body, dict):
            maybe = body.get("args")
            if isinstance(maybe, dict):
                args = maybe
        detail = (
            args.get("path")
            or args.get("target_notebook")
            or args.get("command")
            or args.get("query")
            or args.get("pattern")
            or args.get("glob_pattern")
            or ""
        )
        detail_s = str(detail).replace("\n", " ").strip()
        if len(detail_s) > 160:
            detail_s = detail_s[:157] + "..."
        return f"{name} {detail_s}".strip()
    return "tool"


def assistant_text(event: dict) -> str:
    msg = event.get("message")
    if not isinstance(msg, dict):
        return ""
    parts = msg.get("content") or []
    texts = []
    if isinstance(parts, list):
        for part in parts:
            if isinstance(part, dict) and part.get("type") == "text":
                texts.append(str(part.get("text") or ""))
    elif isinstance(parts, str):
        texts.append(parts)
    blob = " ".join(texts).replace("\n", " ").strip()
    if len(blob) > 200:
        blob = blob[:197] + "..."
    return blob


def main() -> int:
    emit("## Agent progress", summary=True)
    for raw in sys.stdin:
        line = raw.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            print(line, flush=True)
            continue
        if not isinstance(event, dict):
            continue
        kind = event.get("type")
        if kind == "system":
            model = event.get("model") or ""
            emit(f"ci-agent: start model={model}", summary=True)
        elif kind == "tool_call":
            sub = event.get("subtype") or ""
            label = tool_label(event)
            emit(f"ci-agent: tool {sub} {label}", summary=True)
        elif kind == "assistant":
            text = assistant_text(event)
            if text:
                emit(f"ci-agent: {text}")
        elif kind == "result":
            sub = event.get("subtype") or ""
            ms = event.get("duration_ms")
            emit(f"ci-agent: result {sub} duration_ms={ms}", summary=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
