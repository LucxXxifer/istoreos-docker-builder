---
name: gateway-dns-proxy-troubleshoot
description: Use when OpenWrt or iStoreOS gateways have DNS, domain, app download, internal host, Tailscale MagicDNS, AdGuard Home, dnsmasq, ShellCrash, OpenClash, Clash, Mihomo, or Docker/macvlan failures, especially when domains resolve but traffic stalls, ARP is correct but ICMP/TCP time out, routes DIRECT unexpectedly, query logs are stale, or proxy selectors/templates may overwrite rules.
---

# Gateway DNS Proxy Troubleshoot

## Core Rule

Treat gateway DNS/proxy incidents as evidence-first operations. Start read-only, identify the failing layer, then present a small reversible change for user confirmation before touching live config.

## Required Gates

1. **Read-only diagnosis.** Do not edit files, reload services, change selectors, update subscriptions, clear logs, restart routers, or "try a fix" during this gate.
2. **Proposal for confirmation.** Show evidence, likely root cause, exact change, impact, backup path, rollback command, and verification command. Wait for explicit user approval.
3. **Minimum repair.** Verify permission, back up live config, change one variable, reload only the affected service, verify runtime evidence, and keep rollback ready.

## Red Lines

- Do not invent credentials or assume any default username/password pair.
- Do not change AI platform selectors unless the user explicitly asks for that exact selector. If the user has protected a selector such as `AI platform -> US node -> US03`, preserve it.
- Do not create a custom proxy group as the default ShellCrash/OpenClash fix. Template options such as ShellCrash `6-3` may overwrite custom groups; prefer existing stable selectors such as `手动选择` when the user needs regional switching.
- Do not rewrite broad DNS, DHCP, firewall, WAN/LAN, default route, subscription, or provider settings to solve one domain symptom.
- Do not treat stale AdGuard query logs as current proof. Verify whether logs are still updating.
- Do not repair multiple variables at once. One domain rule, one upstream, one redirect, or one selector per A/B step.
- Do not copy prior-case IPs, MACs, interface names, route tables, or rule priorities. Discover the current target's values first.

## Evidence Matrix

Collect enough evidence to locate the break:

| Layer | Evidence to collect | Typical failure |
| --- | --- | --- |
| Client | Client IP, DNS server, gateway, private DNS/DoH/VPN state | Client bypasses gateway or uses stale DNS |
| Gateway listeners | `ss -lntup`, dnsmasq/AdGuard ports, proxy DNS ports | Port conflict or DNS loop |
| DHCP/dnsmasq | `uci show dhcp`, advertised DNS, local domain | Clients receive wrong resolver |
| AdGuard Home | Upstream, bootstrap, rewrites, block result, current query log | Blocked domain, stale log, loop to dnsmasq |
| Proxy core DNS | Clash/Mihomo/OpenClash/ShellCrash DNS mode and fake-ip/redir-host | Domain resolves DIRECT or fake-ip breaks LAN |
| Rule/outlet | Matched rule, chain, selector, CDN/control-plane outlet | API and CDN use different exits |
| Firewall redirect | DNS hijack, TProxy/REDIR, nft/iptables rules | Traffic captured unexpectedly |
| Tailscale | MagicDNS, `100.64.0.0/10`, subnet routes | Tailnet names or CGNAT range proxied |
| Docker/macvlan | Container DNS, macvlan gateway, MAC map, neighbor table, link path | Container or side-router has separate path; single host port exposes multiple MACs |

## Workflow

1. Scope the device and symptom: OpenWrt/iStoreOS IP, client IP, failing app/domain, whether failure is DNS NXDOMAIN, blocked, DIRECT routing, timeout, or download stall.
2. Run read-only discovery. Use `scripts/collect_gateway_dns_evidence.sh` on the gateway when shell access exists. Use `scripts/dns_compare.py` from a safe client to compare resolvers.
3. If Clash/Mihomo API is available, use `scripts/watch_mihomo_connections.py` while the user reproduces the failure to see rule, chain, and outlet evidence.
4. Load the relevant reference:
   - `references/failure-patterns.md` for Google Play, Apple, Xiaomi, app-store CDN/control-plane patterns.
   - `references/openwrt-istoreos.md` for safe inspection commands, Docker/macvlan, and platform notes.
   - `references/docker-macvlan-arp.md` when fnOS/NAS hosts, Docker iStoreOS, macvlan shims, or multi-MAC ARP instability are involved.
   - `references/safe-remediation.md` before proposing any live change.
5. Present a diagnosis and one proposed next action. If confidence is low, propose the next read-only probe rather than a repair.
6. After approval, back up, apply only the confirmed change, reload narrowly, and verify with the same reproduction path.

## Script Use

- `scripts/collect_gateway_dns_evidence.sh`: run on OpenWrt/iStoreOS shell for read-only state collection.
- `scripts/dns_compare.py`: compare domain answers across client DNS, gateway DNS, AdGuard, proxy DNS, and public resolvers.
- `scripts/watch_mihomo_connections.py`: inspect live Clash/Mihomo connection routing without changing selectors.

## Diagnosis Hints

- App stores often need API/control-plane domains and CDN/download domains on a consistent outlet. For Google Play, a visible percent that never moves often means CDN routing, not login.
- A blocked telemetry domain can be noisy evidence, not root cause. Unblock only when current logs and reproduction show it gates the failing flow.
- When an internal host times out but ARP maps to the expected MAC, do not treat it as DNS first. Compare ICMP/TCP and ARP for the host IP, shim IP, and macvlan container IP from at least two LAN clients before changing DNS or proxy rules.
- For Docker macvlan routers, consider pinning the container MAC only after current evidence proves MAC drift across restart/recreate. A stable IP with an unpinned macvlan MAC can poison client ARP and switch CAM state, but the current MAC must be discovered before proposing a pin.
- For ShellCrash/OpenClash template-managed setups, durable fixes usually belong in rules or an existing template-stable selector, not ad hoc groups that disappear after update.
- For Tailscale/MagicDNS, confirm whether tailnet names and `100.64.0.0/10` are excluded from proxy capture before changing DNS.
