# Operational skills

[中文说明](README_CN.md)

This directory stores reusable agent skills that support live iStoreOS/OpenWrt operations around this repository. Skills are documentation plus helper scripts; they are not build artifacts and are not installed into the Docker image by default.

## Gateway DNS Proxy Troubleshoot

- Skill: `skills/gateway-dns-proxy-troubleshoot/SKILL.md`
- Main macvlan reference: `skills/gateway-dns-proxy-troubleshoot/references/docker-macvlan-arp.md`
- Repository runbook: `runbooks/docker-macvlan-arp.md`

Use this skill when an OpenWrt/iStoreOS gateway has DNS, domain routing, app download, AdGuard Home, dnsmasq, ShellCrash, OpenClash, Mihomo, Tailscale MagicDNS, or Docker/macvlan LAN failures. Typical symptoms include domains resolving but traffic stalling, Google Play or other app downloads hanging, local hostnames failing after DNS takeover, AdGuard query logs looking stale, proxy DNS loops, DNS hijack bypassing the intended front resolver, or Docker/macvlan hosts showing correct ARP while ICMP/TCP still fail.

Required usage pattern:

1. Start in read-only mode.
2. Open `skills/gateway-dns-proxy-troubleshoot/SKILL.md` and the smallest relevant reference file before acting.
3. Discover the current target's IPs, MACs, ports, listeners, firewall redirect target, upstream DNS, interfaces, route tables, rule priorities, client path, and container state.
4. Fill unknown or inapplicable variables explicitly. Use `N/A` for components that do not exist, such as a missing host-side shim.
5. Do not copy values from previous incidents. Use role placeholders such as `<gateway_ip>`, `<front_resolver>`, `<proxy_dns_port>`, `<upstream_dns>`, `<local_hostname>`, and `<lan_domain>` until live evidence proves the actual values.
6. Prove the failing layer before proposing a repair. Listener state alone is not enough; pair it with DNS answers, current query logs, firewall redirect target, route/rule/outlet evidence, or LAN reachability probes as appropriate.
7. Propose one minimal repair only after the failing layer is proven.
8. Back up, apply one variable, reload narrowly, and verify with the same reproduction path after approval.
9. For persistent DNS/proxy changes, re-check runtime and persistent config after service restart or host reboot when that gate is approved.

Reference selection:

| Symptom | Start with |
| --- | --- |
| OpenWrt/iStoreOS listeners, DNS topology, ShellCrash/OpenClash, Tailscale, or local hostnames | `references/openwrt-istoreos.md` |
| Google Play, Apple, Xiaomi, app downloads, API/CDN split, or HTTPS smoke tests | `references/failure-patterns.md` |
| Docker/macvlan ARP, MAC drift, host-side shim, or promotion gates | `references/docker-macvlan-arp.md` and `../runbooks/docker-macvlan-arp.md` |
| Any live change proposal | `references/safe-remediation.md` |

Useful read-only collectors:

```sh
sh skills/gateway-dns-proxy-troubleshoot/scripts/collect_gateway_dns_evidence.sh
python3 skills/gateway-dns-proxy-troubleshoot/scripts/dns_compare.py --help
python3 skills/gateway-dns-proxy-troubleshoot/scripts/watch_mihomo_connections.py --help
```

For Docker macvlan ARP/MAC promotion gates, use the repository runbook before promoting a live router:

```text
runbooks/docker-macvlan-arp.md
```

Do not publish local private runtime state, personal MAC addresses, proxy subscriptions, Tailscale identity, certificates, tokens, passwords, or SSH keys.

Important interpretation notes:

- HTTPS smoke tests against API/CDN roots may return `404`; that can still prove DNS, TCP, and TLS reachability.
- Google Play CDN domains such as `gvt1.com`, `gvt2.com`, `gvt3.com`, `redirector.gvt1.com`, and `dl.google.com` are common delivery surfaces, but current logs must prove a block or sink rewrite before adding rules.
- DNS hijack must be checked by target role and port. A redirect can silently bypass AdGuard even when every listener is running.
- ShellCrash/OpenClash generated runtime config can differ from persistent config after restart. Do not call a DNS fix durable until the owner layer survives restart.
