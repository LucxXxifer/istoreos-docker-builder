#!/usr/bin/env python3
"""Read Clash/Mihomo connection routing without changing runtime state."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import urllib.error
import urllib.request
from typing import Any


def fetch_json(api_url: str, secret: str | None, timeout: int) -> dict[str, Any]:
    request = urllib.request.Request(api_url)
    if secret:
        request.add_header("Authorization", f"Bearer {secret}")
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = response.read()
    parsed = json.loads(data.decode("utf-8"))
    if not isinstance(parsed, dict):
        raise ValueError("API response is not a JSON object")
    return parsed


def parse_time(value: Any) -> str:
    if not isinstance(value, str) or not value:
        return "-"
    try:
        normalized = value.replace("Z", "+00:00")
        started = dt.datetime.fromisoformat(normalized)
        if started.tzinfo is None:
            started = started.replace(tzinfo=dt.timezone.utc)
        age = dt.datetime.now(dt.timezone.utc) - started.astimezone(dt.timezone.utc)
        seconds = max(0, int(age.total_seconds()))
        return f"{seconds}s"
    except ValueError:
        return value


def pick_host(connection: dict[str, Any]) -> str:
    metadata = connection.get("metadata")
    if not isinstance(metadata, dict):
        return "-"
    for key in ("host", "destinationIP", "dnsMode"):
        value = metadata.get(key)
        if value:
            return str(value)
    return "-"


def format_chain(value: Any) -> str:
    if isinstance(value, list):
        return " > ".join(str(item) for item in value)
    if value:
        return str(value)
    return "-"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Read-only Clash/Mihomo connection watcher.")
    parser.add_argument("--api-url", default="http://127.0.0.1:9090/connections", help="Connections API URL.")
    parser.add_argument("--secret", default=None, help="Optional API secret; used only for this request.")
    parser.add_argument("--filter", default="", help="Case-insensitive host/rule/chain substring filter.")
    parser.add_argument("--timeout", type=int, default=5, help="HTTP timeout seconds. Default: 5.")
    args = parser.parse_args(argv)

    try:
        payload = fetch_json(args.api_url, args.secret, args.timeout)
    except (urllib.error.URLError, TimeoutError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    connections = payload.get("connections", [])
    if not isinstance(connections, list):
        print("ERROR: response does not contain a connections list", file=sys.stderr)
        return 1

    needle = args.filter.lower()
    print("host\trule\trule_payload\tchain\tdownload\tupload\tage")
    for item in connections:
        if not isinstance(item, dict):
            continue
        host = pick_host(item)
        rule = str(item.get("rule") or "-")
        rule_payload = str(item.get("rulePayload") or "-")
        chain = format_chain(item.get("chains"))
        row_text = " ".join([host, rule, rule_payload, chain]).lower()
        if needle and needle not in row_text:
            continue
        download = item.get("download") if item.get("download") is not None else "-"
        upload = item.get("upload") if item.get("upload") is not None else "-"
        age = parse_time(item.get("start"))
        print(f"{host}\t{rule}\t{rule_payload}\t{chain}\t{download}\t{upload}\t{age}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
