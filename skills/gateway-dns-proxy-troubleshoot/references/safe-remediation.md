# Safe Remediation

Use this reference only after read-only diagnosis identifies a likely failing layer. Live changes require user confirmation.

## Proposal Template

Before changing anything, present:

```text
Evidence:
- Current symptom:
- Confirmed failing layer:
- Commands/logs that prove it:

Root-cause confidence:
- High/medium/low, with reason:

Proposed change:
- Exact file/UI field/selector:
- Exact value before:
- Exact value after:

Impact:
- Expected fix:
- Possible side effects:
- Services affected:

Backup:
- Command:
- Backup path:

Rollback:
- Command:
- Service reload/restart:

Verification:
- Command or user reproduction:
- Expected successful evidence:
```

If any field is unknown, keep diagnosing instead of repairing.

## Backup Examples

Use a timestamp variable and create the backup before editing:

```sh
ts="$(date +%Y%m%d-%H%M%S)"
cp -a /etc/config/dhcp "/etc/config/dhcp.bak.$ts"
cp -a /etc/config/network "/etc/config/network.bak.$ts"
cp -a /etc/config/firewall "/etc/config/firewall.bak.$ts"
```

For AdGuard Home, find the real YAML path first:

```sh
pgrep -af AdGuard
find /etc /opt /usr /mnt -maxdepth 4 -name 'AdGuardHome.yaml' 2>/dev/null
cp -a /path/to/AdGuardHome.yaml "/path/to/AdGuardHome.yaml.bak.$ts"
```

For ShellCrash/OpenClash/Mihomo generated configs, back up both user custom rules and the generated runtime file after locating them:

```sh
find /etc /usr/share /root /opt -maxdepth 5 \( -iname '*clash*.yaml' -o -iname '*mihomo*.yaml' -o -iname '*rules*.list' \) 2>/dev/null
cp -a /path/to/file "/path/to/file.bak.$ts"
```

Do not assume paths; inspect first.

## One-Variable A/B Rule

Change only one variable per attempt:

| Symptom | One-variable candidate |
| --- | --- |
| One domain blocked | One allowlist/blocklist entry |
| Domain resolves to wrong outlet | One domain rule |
| API works, CDN stalls | One CDN domain bucket routed to same existing selector |
| Private hostnames fail | One private suffix upstream/rewrite |
| MagicDNS fails | One tailnet suffix or `100.64.0.0/10` bypass rule |
| DNS loop | One upstream target or listener port |
| Docker macvlan IP conflict | One shim IP move, with all script references synchronized |
| macvlan MAC drift | One `mac_address` pin for the container endpoint |
| ARP flux between host and shim | One interface-specific `arp_ignore` change |
| Shim return path timeout | One source policy rule for the shim IP |

After each change, reload narrowly and reproduce. Do not batch unrelated fixes.

## Narrow Reloads

Prefer the smallest reload that applies the confirmed change:

```sh
/etc/init.d/dnsmasq reload
/etc/init.d/AdGuardHome restart
/etc/init.d/openclash reload
/etc/init.d/shellcrash restart
```

Only run a command if that service exists on the target. Check with:

```sh
ls /etc/init.d
pgrep -af 'dnsmasq|AdGuard|openclash|shellcrash|mihomo|clash'
```

For Clash/Mihomo API selector changes, do not change protected groups or AI platform selectors unless explicitly approved.

## Rollback Requirements

Rollback must be executable before repair:

```sh
cp -a "/etc/config/dhcp.bak.$ts" /etc/config/dhcp
/etc/init.d/dnsmasq reload
```

If rollback depends on UI-only actions, document the exact UI path and capture current values first.

## Forbidden As Defaults

- No default route changes.
- No WAN/LAN interface role changes.
- No DHCP server role changes.
- No broad DNS hijack enable/disable.
- No subscription/template update as a diagnostic shortcut.
- No AI platform selector changes.
- No destructive delete of generated configs; move or copy only after confirmation.
