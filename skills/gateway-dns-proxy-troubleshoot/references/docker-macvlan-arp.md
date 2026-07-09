# Docker Macvlan ARP And MAC Stability

Use this reference when a NAS/fnOS host runs OpenWrt or iStoreOS in Docker with a macvlan LAN address, especially when host IPs, shim IPs, and container IPs share one physical switch port.

## Mental Model

A single physical LAN port may legitimately present several MACs:

| Role | Example | Purpose |
| --- | --- | --- |
| Host interface | `HOST_IP` on `LAN_PARENT` | NAS/fnOS UI, SSH, SMB |
| Host macvlan shim | `SHIM_IP_CIDR` on `SHIM_IF` | Host-to-container reachability |
| iStoreOS container | `ISTORE_IP` on `MACVLAN_NETWORK` | Side-router gateway/DNS/proxy |
| Other LAN host | `PEER_IP` | Must not be stolen by the shim |

Do not assume one physical device has one MAC once Docker macvlan, bridge, bond, or shim interfaces exist.

## Placeholder Map

Treat every placeholder below as a value to discover on the current target. Never replace it with a value remembered from an earlier case.

| Placeholder | Meaning |
| --- | --- |
| `LAN_PARENT` | Physical or bonded LAN interface used as the macvlan parent |
| `HOST_IP` / `HOST_MAC` | NAS/fnOS host address and MAC on `LAN_PARENT` |
| `SHIM_IF` / `SHIM_IP_CIDR` / `SHIM_MAC` | Optional host-side macvlan shim interface, helper IP, and MAC |
| `ISTORE_CONTAINER` / `ISTORE_IP` / `ISTORE_MAC` | Docker iStoreOS container name, LAN IP, and macvlan endpoint MAC |
| `PEER_IP` / `PEER_MAC` | Another LAN device that must not be stolen by host/shim ARP |
| `LAN_ROUTE_TABLE` / `RULE_PRIORITY` | Target-specific LAN routing table and unused source-rule priority |
| `CLIENT_IP` | LAN client reproducing the timeout or ARP symptom |

## Failure Signatures

| Symptom | Likely issue | First proof |
| --- | --- | --- |
| Container IP changes MAC after restart/recreate | macvlan endpoint MAC is unpinned | `docker inspect`, LAN ARP before/after restart |
| A real LAN device IP maps to the shim MAC | shim IP conflict or ARP proxy/weak-host behavior | client ARP plus host `ip addr show` |
| Host IP maps to shim MAC | ARP flux between parent and shim | `arp_ignore=0` on parent/shim |
| Shim IP ARPs but ping/TCP time out | policy routing table mismatch or return path wrong | `ip route get CLIENT from SHIM_IP` |
| Container IP works but host/shim IPs time out after cable move | switch CAM/link learning or host stack state | two-client ARP + ICMP/TCP comparison |

ARP success is not IP success. Pair every ARP finding with ICMP/TCP evidence.

## Variable Discovery Gate

Before proposing any repair, fill these variables from the current host and LAN clients:

| Variable | Must be discovered from |
| --- | --- |
| `LAN_PARENT` | `ip -d link show`, Docker macvlan `Options.parent` |
| `HOST_IP` / `HOST_MAC` | `ip addr show`, `/sys/class/net/$LAN_PARENT/address`, LAN client ARP |
| `SHIM_IF` / `SHIM_IP_CIDR` / `SHIM_MAC` | `ip -d link show`, `ip addr show`, `/sys/class/net/$SHIM_IF/address` |
| `ISTORE_CONTAINER` / `ISTORE_IP` / `ISTORE_MAC` | `docker inspect`, LAN client ARP |
| `PEER_IP` / `PEER_MAC` | the actual peer device and LAN client ARP |
| `LAN_ROUTE_TABLE` / `RULE_PRIORITY` | `ip rule show`, `ip route show table all`; choose a free priority only after inspection |
| `CLIENT_IP` / client interface | the reproducing LAN client route and ARP table |

If any required value is unknown, keep diagnosing. Do not substitute values from a previous case. If the environment does not use Docker macvlan or has no host-side shim, mark the related variables as `N/A` and skip the matching repair branches instead of inventing values.

## Read-Only Map

Collect this before repair:

```sh
date
hostname
ip -br addr show
ip -d link show
ip rule show
ip route show table all
ip neigh show
ss -lntup
cat /sys/class/net/*/address
cat /proc/sys/net/ipv4/conf/*/arp_ignore
cat /proc/sys/net/ipv4/conf/*/arp_filter
cat /proc/sys/net/ipv4/conf/*/arp_announce
cat /proc/sys/net/ipv4/conf/*/proxy_arp
docker ps --format '{{.Names}} {{.Status}}'
docker network ls
docker network inspect MACVLAN_NETWORK
docker inspect CONTAINER --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} ip={{$conf.IPAddress}} mac={{$conf.MacAddress}} gw={{$conf.Gateway}}{{"\n"}}{{end}}'
```

From at least one LAN client, preferably two:

```sh
for ip in HOST_IP SHIM_IP CONTAINER_IP OTHER_DEVICE_IP; do
  ping -c 2 "$ip"
  nc -vz -w 2 "$ip" 22
  nc -vz -w 2 "$ip" 80
done
arp -an 2>/dev/null || ip neigh show
```

Expected evidence table:

| IP | Expected MAC | Owner | Required proof |
| --- | --- | --- | --- |
| Host IP | parent interface MAC | NAS/fnOS | ping/TCP open, ARP stable |
| Shim IP | shim MAC | host macvlan shim | ping/TCP as needed, ARP stable |
| Container IP | pinned container MAC | Docker iStoreOS | LuCI/SSH/DNS reachable, MAC survives restart |
| Other LAN device IP | that device MAC | separate device | never maps to host/shim MAC |

## Repair Order

Use one variable per phase and verify before continuing.

1. **Move conflicting shim IP first.** If current evidence proves the shim uses an IP that belongs to another LAN device, move it to a currently unused helper IP. Synchronize every script reference: `SHIM_IP_CIDR`, address grep, reverse ping, source rule checks, and comments that are used by scripts.
2. **Fix shim return path.** If `SHIM_IP` resolves by ARP but cannot reply, check whether `ip route get CLIENT_IP from SHIM_IP` uses the wrong table, such as a VPN/tailnet policy table. If so, add one source policy rule for `SHIM_IP` to the discovered `LAN_ROUTE_TABLE`. This is a policy-routing fix, not a DNS or ARP-flux fix.
3. **Stop ARP flux.** If the current parent and shim answer for each other's IPs, set interface-specific `arp_ignore=1` on both involved interfaces: `LAN_PARENT` and `SHIM_IF`. Setting only one side can leave the other interface answering for the wrong IP. Avoid `all/default`, `arp_filter`, and `arp_announce` as first moves unless evidence proves they are needed.
4. **Pin container MAC.** If Docker macvlan creates a new MAC for the same `ISTORE_IP` after restart/recreate, pin the current live, already-learned `ISTORE_MAC` at the network endpoint level next to `ipv4_address`. Verify with Docker inspect before and after recreate/restart.
5. **Run lifecycle gates.** Validate service restart, shim interface rebuild, Docker recreate/restart, and host reboot/post-boot. Do not call the chain fixed until the MAC map survives all required gates.

## Compose MAC Pin Pattern

Prefer endpoint-level `mac_address` next to `ipv4_address`:

```yaml
services:
  ${ISTORE_CONTAINER}:
    networks:
      ${MACVLAN_NETWORK}:
        ipv4_address: ${ISTORE_IP}
        mac_address: ${ISTORE_MAC}
```

Pin the current live MAC when clients and Docker already agree on it. Do not revert to an older historical MAC unless the network is deliberately being moved back and the outage window is accepted.

Verify drift with Docker runtime data, not only client ARP:

```sh
docker inspect "$ISTORE_CONTAINER" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} ip={{$conf.IPAddress}} mac={{$conf.MacAddress}} gw={{$conf.Gateway}}{{"\n"}}{{end}}'
```

Run this before and after `docker restart`, `docker compose up -d --force-recreate`, or any container lifecycle action that could rebuild the macvlan endpoint.

## Shim Script Pattern

Keep the parent and shim ARP behavior explicit:

```sh
SHIM_IF="${DISCOVERED_SHIM_IF}"
LAN_PARENT="${DISCOVERED_LAN_PARENT}"
ISTORE_IP="${DISCOVERED_ISTORE_IP}"
SHIM_IP_CIDR="${DISCOVERED_SHIM_IP_CIDR}"
SHIM_MAC="${DISCOVERED_OR_CHOSEN_SHIM_MAC}"
LAN_ROUTE_TABLE="${DISCOVERED_LAN_ROUTE_TABLE}"
RULE_PRIORITY="${DISCOVERED_FREE_RULE_PRIORITY}"
SHIM_SRC="${SHIM_IP_CIDR%/*}"

sysctl -w "net.ipv4.conf.${LAN_PARENT}.arp_ignore=1" >/dev/null
ip link show "$SHIM_IF" >/dev/null 2>&1 || ip link add "$SHIM_IF" link "$LAN_PARENT" address "$SHIM_MAC" type macvlan mode bridge
sysctl -w "net.ipv4.conf.${SHIM_IF}.arp_ignore=1" >/dev/null
ip addr show "$SHIM_IF" | grep -q "${SHIM_SRC}" || ip addr add "$SHIM_IP_CIDR" dev "$SHIM_IF"
ip link set "$SHIM_IF" up
ip route replace "$ISTORE_IP/32" dev "$SHIM_IF"
if ! ip rule show | grep -q "from ${SHIM_SRC} lookup ${LAN_ROUTE_TABLE}"; then
  ip rule add priority "$RULE_PRIORITY" from "$SHIM_SRC/32" lookup "$LAN_ROUTE_TABLE" protocol static 2>/dev/null || ip rule add priority "$RULE_PRIORITY" from "$SHIM_SRC/32" lookup "$LAN_ROUTE_TABLE"
fi
```

This is a shape example only. Use the actual local table name, free priority, interface names, and current IP/MAC values from the target. Do not copy values from a previous case.

## Lifecycle Gates

Use the same MAC map after each gate. Re-learn ARP from a LAN client when possible; stale client cache can hide failure.

| Trigger | Minimum verification | Stronger verification |
| --- | --- | --- |
| Shim IP move | `ip addr show SHIM`, script grep has no old IP | Client ARP shows other LAN device IP no longer maps to shim MAC |
| Shim source rule | `ip route get CLIENT from SHIM_IP` uses LAN table | Client ping/TCP to shim succeeds and route remains stable |
| `arp_ignore` change | Parent and shim both report `arp_ignore=1` | Host IP and shim IP map to different intended MACs after ARP relearn |
| Compose `mac_address` pin | `docker compose config`, `docker inspect` MAC matches pin | `docker restart` and `--force-recreate` keep the same MAC |
| Interface rebuild | shim delete/recreate returns same IP/MAC/sysctls | Host, shim, container, and peer device all remain reachable |
| Host reboot | post-boot service state and Docker inspect pass | Two LAN clients confirm final IP->MAC map after services settle |

## Stop Conditions

Stop and reassess if any of these occur:

- The shim script still contains the old conflicting IP after the move.
- `ip route get CLIENT from SHIM_IP` uses a VPN/tailnet table when the client is on local LAN.
- A LAN client maps a real device IP to the shim MAC.
- Host IP or shim IP remains reachable only through the wrong MAC after ARP relearn.
- Container `docker inspect` MAC differs from the pinned compose MAC.
- One lifecycle gate passes only because of stale ARP cache; re-learn from a client before accepting.

## Completion Gate

The chain is complete only when these are all true after the planned lifecycle events:

- Host IP maps to the host interface MAC and responds.
- Shim IP maps to the shim MAC and responds as intended.
- Container IP maps to the pinned container MAC and responds.
- Other LAN device IPs map to their own device MACs.
- At least one independent LAN client confirms the same map; two clients are better.
- SSH or UI login failures are classified separately after TCP/banner or HTTP status proves transport works.
