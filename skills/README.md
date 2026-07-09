# Operational skills

This directory stores reusable agent skills that support live iStoreOS/OpenWrt operations around this repository. Skills are documentation plus helper scripts; they are not build artifacts and are not installed into the Docker image by default.

## Gateway DNS Proxy Troubleshoot

- Skill: `skills/gateway-dns-proxy-troubleshoot/SKILL.md`
- Main macvlan reference: `skills/gateway-dns-proxy-troubleshoot/references/docker-macvlan-arp.md`
- Repository runbook: `runbooks/docker-macvlan-arp.md`

Use this skill when an OpenWrt/iStoreOS gateway has DNS, domain routing, app download, AdGuard Home, dnsmasq, ShellCrash, OpenClash, Mihomo, Tailscale MagicDNS, or Docker/macvlan LAN failures.

Required usage pattern:

1. Start in read-only mode.
2. Discover the current target's IPs, MACs, interfaces, route tables, rule priorities, client path, and container state.
3. Fill unknown or inapplicable variables explicitly. Use `N/A` for components that do not exist, such as a missing host-side shim.
4. Do not copy values from previous incidents.
5. Propose one minimal repair only after the failing layer is proven.
6. Back up, apply one variable, and verify with the same reproduction path after approval.

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
