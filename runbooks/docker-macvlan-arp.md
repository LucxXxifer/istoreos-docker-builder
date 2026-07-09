# Docker macvlan ARP and MAC runbook

This runbook applies when iStoreOS or OpenWrt runs in Docker on a NAS/fnOS host through a macvlan LAN network. It is meant for live promotion and troubleshooting, not for GitHub Actions artifact proof.

## Scope

A single physical LAN port can expose multiple MAC addresses:

| Role | Example value | Notes |
| --- | --- | --- |
| Host IP | `HOST_IP` on `LAN_PARENT` | fnOS/NAS UI, SSH, SMB |
| Host shim IP | `SHIM_IP/32` on a macvlan shim | Host-to-container helper path |
| Container IP | `ISTORE_IP` on the Docker macvlan network | iStoreOS side-router |
| Peer device IP | `PEER_IP` on another LAN device | Must never map to the host shim MAC |

Do not assume one physical box has only one MAC when Docker macvlan, bridge, bond, or shim interfaces exist.

## Read-only evidence first

Run on the host:

```sh
date
hostname
ip -br addr show
ip -d link show
ip rule show
ip route show table all
ip neigh show
cat /sys/class/net/*/address
cat /proc/sys/net/ipv4/conf/*/arp_ignore
cat /proc/sys/net/ipv4/conf/*/arp_filter
cat /proc/sys/net/ipv4/conf/*/arp_announce
cat /proc/sys/net/ipv4/conf/*/proxy_arp
docker ps --format '{{.Names}} {{.Status}} {{.Networks}}'
docker network ls --filter driver=macvlan
docker network inspect MACVLAN_NETWORK
docker inspect ISTORE_CONTAINER --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} ip={{$conf.IPAddress}} mac={{$conf.MacAddress}} gw={{$conf.Gateway}}{{"\n"}}{{end}}'
```

Run from at least one LAN client; two clients are better:

```sh
for ip in HOST_IP SHIM_IP ISTORE_IP PEER_IP; do
  ping -c 2 "$ip"
  nc -vz -w 2 "$ip" 22
  nc -vz -w 2 "$ip" 80
done
arp -an 2>/dev/null || ip neigh show
```

## Failure signatures

| Symptom | Likely failing layer | Proof to collect |
| --- | --- | --- |
| `ISTORE_IP` keeps the same IP but changes MAC after restart/recreate | Docker macvlan endpoint MAC is not pinned | `docker inspect` before and after lifecycle actions |
| `PEER_IP` maps to the host shim MAC | Shim IP conflict or weak-host ARP/proxy behavior | LAN client ARP plus host `ip addr show` |
| `HOST_IP` maps to the shim MAC | ARP flux between parent and shim | Parent/shim `arp_ignore` plus LAN ARP relearn |
| `SHIM_IP` has correct ARP but ICMP/TCP time out | Policy routing table or return path mismatch | `ip route get CLIENT_IP from SHIM_IP` |
| `ISTORE_IP` works but host/shim IPs time out after a cable or port move | Switch CAM/link learning or host interface state | Two-client ARP plus ICMP/TCP comparison |

ARP success is not IP success. Pair every ARP result with ping or TCP checks.

## Repair order

Use one variable per phase and verify before continuing.

1. Move a conflicting shim IP away from any real LAN device IP. Synchronize `SHIM_IP`, address checks, reverse pings, source-rule checks, and script comments that are parsed by automation.
2. If `SHIM_IP` ARPs but cannot reply, inspect `ip route get CLIENT_IP from SHIM_IP`. Add one source policy rule only if the route uses the wrong table. Use the target host's actual LAN table and a free priority; do not copy a priority from another machine.
3. If parent and shim answer for each other's IPs, set `arp_ignore=1` on both the parent interface and the shim interface. Avoid `all/default`, `arp_filter`, and `arp_announce` as first-line changes unless evidence proves they are needed.
4. If current evidence shows the iStoreOS container MAC drifts after restart/recreate, pin the container MAC at the Docker network endpoint next to `ipv4_address`. Pin the current live MAC only when clients and Docker already agree on it; do not revert to an older historical MAC without planning for a MAC move.
5. Run the lifecycle gates below before promoting.

## Compose pattern

See [examples/compose.macvlan.yml](../examples/compose.macvlan.yml) for a generic template. The important part is endpoint-level `mac_address` next to `ipv4_address`:

```yaml
services:
  istoreos-router:
    networks:
      oect_istore_lan:
        ipv4_address: ${ISTORE_IP}
        mac_address: ${ISTORE_MAC}
```

## Lifecycle promotion gates

The same IP-to-MAC map must survive each gate.

| Gate | Minimum verification | Stronger verification |
| --- | --- | --- |
| Shim IP move | `ip addr show SHIM_IF`, scripts have no old conflicting IP | LAN client confirms `PEER_IP` maps to the peer device MAC |
| Shim source rule | `ip route get CLIENT_IP from SHIM_IP` uses the LAN table | Client ping/TCP to `SHIM_IP` succeeds |
| `arp_ignore` change | Parent and shim both report `arp_ignore=1` | `HOST_IP` and `SHIM_IP` map to different intended MACs after ARP relearn |
| Compose MAC pin | `docker compose config` and `docker inspect` show the pinned MAC | `docker restart` and `docker compose up -d --force-recreate` keep the same MAC |
| Interface rebuild | Deleting/recreating the shim returns the same IP, MAC, and sysctls | Host, shim, container, and peer device all remain reachable |
| Host reboot | Post-boot service state and `docker inspect` pass | Two LAN clients confirm the final IP-to-MAC map after services settle |

## Completion criteria

Promotion is blocked until all of these are true after the planned lifecycle gates:

- Host IP maps to the host interface MAC and responds.
- Shim IP maps to the shim MAC and responds as intended.
- iStoreOS container IP maps to the pinned container MAC and responds.
- Peer LAN device IPs map to their own device MACs.
- SSH or UI login failures are classified separately after TCP/banner or HTTP status proves transport works.

Do not put local private runtime state, personal MAC addresses, proxy subscriptions, Tailscale identity, certificates, tokens, or SSH keys into public release artifacts.
