#!/usr/bin/env python3
"""Compare DNS answers across resolvers without changing system DNS."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from dataclasses import dataclass


DEFAULT_DOMAINS = [
    "play.googleapis.com",
    "android.clients.google.com",
    "clientservices.googleapis.com",
    "services.googleapis.cn",
    "rr1---sn-i3belney.xn--ngstr-lra8j.com",
    "cache.pack.google.com",
    "dl.google.com",
    "app-measurement.com",
    "apps.apple.com",
    "iosapps.itunes.apple.com",
    "mzstatic.com",
    "swcdn.apple.com",
    "icloud.com",
    "account.xiaomi.com",
    "api.io.mi.com",
    "update.miui.com",
    "resolver.msg.xiaomi.net",
    "login.tailscale.com",
]


@dataclass(frozen=True)
class Resolver:
    label: str
    host: str | None
    port: str | None


def parse_resolver(raw: str) -> Resolver:
    if raw in {"system", "default", "-"}:
        return Resolver("system", None, None)
    if ":" in raw and raw.count(":") == 1:
        host, port = raw.rsplit(":", 1)
        if port.isdigit():
            return Resolver(raw, host, port)
    return Resolver(raw, raw, None)


def run_command(cmd: list[str], timeout: int) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            cmd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout.strip()
    except subprocess.TimeoutExpired:
        return 124, "TIMEOUT"
    except OSError as exc:
        return 127, str(exc)


def query_with_dig(resolver: Resolver, domain: str, record_type: str, timeout: int) -> tuple[str, list[str]]:
    cmd = ["dig", "+time=3", "+tries=1", "+short"]
    if resolver.host:
        cmd.append(f"@{resolver.host}")
    if resolver.port:
        cmd.extend(["-p", resolver.port])
    cmd.extend([domain, record_type])
    code, output = run_command(cmd, timeout)
    answers = [line for line in output.splitlines() if line and not line.startswith(";")]
    status = "OK" if code == 0 and answers else ("EMPTY" if code == 0 else f"ERR{code}")
    return status, answers


def query_with_nslookup(resolver: Resolver, domain: str, timeout: int) -> tuple[str, list[str]]:
    if resolver.port:
        return "SKIP", ["nslookup fallback does not support resolver ports reliably"]
    cmd = ["nslookup", domain]
    if resolver.host:
        cmd.append(resolver.host)
    code, output = run_command(cmd, timeout)
    answers: list[str] = []
    for line in output.splitlines():
        stripped = line.strip()
        if stripped.startswith("Address:") or stripped.startswith("Addresses:"):
            value = stripped.split(":", 1)[-1].strip()
            if value and not value.startswith("#"):
                answers.append(value)
    status = "OK" if code == 0 and answers else ("EMPTY" if code == 0 else f"ERR{code}")
    return status, answers


def query(resolver: Resolver, domain: str, record_type: str, timeout: int) -> tuple[str, list[str]]:
    if shutil.which("dig"):
        return query_with_dig(resolver, domain, record_type, timeout)
    if shutil.which("nslookup"):
        return query_with_nslookup(resolver, domain, timeout)
    return "ERR127", ["missing dig and nslookup"]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Read-only DNS comparison across resolvers.")
    parser.add_argument("--resolver", action="append", default=[], help="Resolver IP, IP:port, or system. Repeatable.")
    parser.add_argument("--domain", action="append", default=[], help="Domain to query. Repeatable.")
    parser.add_argument("--type", default="A", help="DNS record type for dig mode. Default: A.")
    parser.add_argument("--timeout", type=int, default=5, help="Per-query timeout seconds. Default: 5.")
    args = parser.parse_args(argv)

    resolvers = [parse_resolver(item) for item in (args.resolver or ["system"])]
    domains = args.domain or DEFAULT_DOMAINS

    print("resolver\tdomain\ttype\tstatus\tanswers")
    for resolver in resolvers:
        for domain in domains:
            status, answers = query(resolver, domain, args.type, args.timeout)
            compact = ",".join(answers[:8]) if answers else "-"
            print(f"{resolver.label}\t{domain}\t{args.type}\t{status}\t{compact}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
