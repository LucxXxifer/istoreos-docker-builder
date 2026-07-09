#!/bin/sh
set -u

case " $* " in
  *" --write "*|*" --fix "*|*" --apply "*|*" --reload "*|*" --restart "*)
    echo "Refusing: this collector is read-only and will not write, reload, or restart." >&2
    exit 2
    ;;
esac

section() {
  printf '\n## %s\n' "$1"
}

run() {
  label="$1"
  cmd="$2"
  section "$label"
  printf '$ %s\n' "$cmd"
  sh -c "$cmd" 2>&1 | sed -n '1,220p'
}

exists() {
  command -v "$1" >/dev/null 2>&1
}

section "gateway-dns-proxy read-only evidence"
echo "This script only runs inspection commands. It does not edit files, reload services, or change selectors."

run "time" "date"
run "identity" "hostname 2>/dev/null; uname -a 2>/dev/null"

if exists ubus; then
  run "system board" "ubus call system board"
fi

if exists ip; then
  run "addresses" "ip addr show"
  run "link details" "ip -d link show"
  run "routes" "ip route show table all"
  run "rules" "ip rule show"
  run "neighbors" "ip neigh show"
  run "default-link counters" "dev=\$(ip route show default 2>/dev/null | awk 'NR==1{for(i=1;i<=NF;i++)if(\$i==\"dev\"){print \$(i+1); exit}}'); [ -n \"\$dev\" ] && ip -s link show dev \"\$dev\" || true"
fi

if exists bridge; then
  run "bridge fdb excerpt" "bridge fdb show 2>/dev/null | sed -n '1,220p'"
fi

if exists ethtool; then
  run "default-link ethtool" "dev=\$(ip route show default 2>/dev/null | awk 'NR==1{for(i=1;i<=NF;i++)if(\$i==\"dev\"){print \$(i+1); exit}}'); [ -n \"\$dev\" ] && ethtool \"\$dev\" || true"
fi

if exists ss; then
  run "listeners" "ss -lntup"
elif exists netstat; then
  run "listeners" "netstat -lntup"
fi

if exists uci; then
  run "uci dhcp" "uci show dhcp"
  run "uci network" "uci show network"
  run "uci firewall" "uci show firewall"
fi

run "resolver files" "for f in /etc/resolv.conf /tmp/resolv.conf.d/resolv.conf.auto /tmp/resolv.conf.d/resolv.conf.dnsmasq; do [ -f \"\$f\" ] && { echo \"--- \$f\"; sed -n '1,120p' \"\$f\"; }; done"

run "processes" "ps w 2>/dev/null | grep -Ei 'AdGuard|dnsmasq|mihomo|clash|openclash|shellcrash|tailscaled' | grep -v grep || true"

if exists pgrep; then
  run "matching pgrep" "pgrep -af 'AdGuard|dnsmasq|mihomo|clash|openclash|shellcrash|tailscaled' || true"
fi

if exists docker; then
  run "docker containers" "docker ps --format '{{.Names}} {{.Status}} {{.Networks}}' 2>/dev/null"
  run "docker macvlan networks" "docker network ls --filter driver=macvlan --format '{{.Name}} {{.Driver}} {{.Scope}}' 2>/dev/null"
  run "docker macvlan inspect summary" "for n in \$(docker network ls --filter driver=macvlan --format '{{.Name}}' 2>/dev/null); do echo \"--- \$n\"; docker network inspect \"\$n\" --format 'driver={{.Driver}} options={{json .Options}} ipam={{json .IPAM.Config}} containers={{json .Containers}}' 2>/dev/null; done"
fi

if exists logread; then
  run "dnsmasq log excerpt" "logread -e dnsmasq | tail -n 80"
  run "AdGuard log excerpt" "logread -e AdGuard | tail -n 80"
  run "clash/mihomo log excerpt" "logread -e clash -e mihomo -e openclash -e shellcrash | tail -n 120"
fi

if exists nft; then
  run "nft dns/tproxy excerpt" "nft list ruleset 2>/dev/null | grep -Ei 'dport 53|tproxy|redirect|dns|mihomo|clash' | sed -n '1,220p'"
fi

if exists iptables-save; then
  run "iptables dns/tproxy excerpt" "iptables-save 2>/dev/null | grep -Ei 'dpt:53|--dport 53|TPROXY|REDIRECT|mihomo|clash' | sed -n '1,220p'"
fi

if exists tailscale; then
  run "tailscale status" "tailscale status"
  run "tailscale dns status" "tailscale dns status 2>/dev/null || true"
fi

section "done"
echo "Collector finished without applying changes."
