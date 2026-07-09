# OpenWrt And iStoreOS Inspection

iStoreOS is usually OpenWrt with additional UI and packages. Prefer OpenWrt CLI evidence first, then use LuCI/iStore UI only for state that is not available from shell.

## Read-Only Commands

These commands inspect state only:

```sh
date
hostname
uname -a
ubus call system board
ip addr show
ip route show
ip rule show
ip -d link show
ip neigh show
ss -lntup
uci show dhcp
uci show network
uci show firewall
cat /etc/resolv.conf
cat /tmp/resolv.conf.d/resolv.conf.auto
logread -e dnsmasq
logread -e AdGuard
logread -e clash
logread -e mihomo
pgrep -af 'AdGuard|dnsmasq|mihomo|clash|openclash|shellcrash|tailscaled'
```

If available, also inspect:

```sh
nft list ruleset
iptables-save
ip -6 route show
tailscale status
tailscale dns status
```

`nft list ruleset` and `iptables-save` can be noisy; capture targeted excerpts when context is tight.

## DNS Topologies To Identify

| Pattern | Evidence | Risk |
| --- | --- | --- |
| dnsmasq -> AdGuard -> upstream | dnsmasq advertises router; AdGuard listens on another port | Loop if upstream points back |
| AdGuard -> dnsmasq for private suffixes | AdGuard rewrites or upstream rules for LAN suffixes | Private names fail if suffix missing |
| Proxy core DNS enabled | Clash/Mihomo listens on 7874/1053/53 or similar | Public domains may bypass AdGuard logs |
| DNS hijack | firewall redirects port 53 | Client-set DNS may be silently captured |
| Docker/macvlan DNS | container has own `/etc/resolv.conf` and gateway | Gateway fix does not affect container |

## Docker/macvlan LAN Reachability

When a Docker iStoreOS side-router runs on a NAS host, one physical switch port can legitimately expose several MAC addresses: the host IP, a host macvlan shim, and the iStoreOS container. If one IP works while another times out, diagnose link/MAC learning before DNS or proxy rules.

Use this read-only pattern from at least two LAN clients when possible:

```sh
for ip in HOST_IP SHIM_IP CONTAINER_IP; do
  ping -c 2 "$ip"
  nc -vz -w 2 "$ip" 22
  nc -vz -w 2 "$ip" 80
done
ip neigh show
arp -an 2>/dev/null
```

Interpretation:

| Evidence | Likely layer |
| --- | --- |
| ARP maps to the expected MAC, but ICMP/TCP time out | L2 forwarding, link flap, host stack, firewall, or return path; not DNS |
| Container IP works, host/shim IPs fail | macvlan host path, switch MAC learning, or host interface state |
| Moving cables or switch ports restores access without config changes | transient CAM/MAC learning or link negotiation state |
| Only DNS names fail while direct IP and ports work | DNS/proxy layer remains plausible |

Before repairing, capture the stable MAC map for each role and avoid assuming one device has only one MAC when macvlan is in use.

## ShellCrash/OpenClash Notes

- ShellCrash template option updates can overwrite generated config and custom groups.
- OpenClash may run multiple config layers: subscription template, custom rules, generated runtime config, and core API state.
- Prefer existing stable selectors such as `手动选择` when the user needs to switch Google Play region by account.
- Do not change provider subscriptions, templates, or default selectors during diagnosis.

## Tailscale And MagicDNS

Check whether:
- `tailscaled` is running.
- MagicDNS is enabled for the client path.
- Tailnet suffixes are sent to Tailscale DNS or locally resolved.
- `100.64.0.0/10` and tailnet hostnames are bypassed from proxy capture.
- Subnet routes are advertised or accepted unexpectedly.

Tailscale failures can look like public DNS failures if AdGuard or Clash intercepts MagicDNS before `tailscaled` can answer.

## Evidence Quality

- Current reproduction beats old logs.
- Current query log entries must advance while the user reproduces.
- A single DNS answer is not enough; pair DNS result with route/rule/outlet evidence.
- A correct ARP entry is not proof that IP traffic will pass; pair ARP with ICMP/TCP probes.
- If SSH shell and UI disagree, record both and prefer runtime process/listener evidence for the current moment.
