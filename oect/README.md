# OECT fnOS iStoreOS Docker Production Scaffold

This directory contains the production scaffold for the OECT/fnOS Docker iStoreOS side-router image line.

The first release is intentionally a scaffold release. It publishes seed files, a manifest, checksums, and safety notes. It does not claim that a full rootfs, Docker image, or live fnOS deployment has already passed.

Official iStoreOS ImageBuilder entry:

- `https://fw.koolcenter.com/iStoreOS/ib/`

Target note:

- This production scaffold currently follows upstream's Docker rootfs line: `armsr/armv8`, using the official `armsr/` ImageBuilder.
- OECT hardware is RK3566/Rockchip. For a bare-metal or RK-specific iStoreOS firmware build, use the official `rk3xxx/` ImageBuilder (`rockchip-armv8`) instead.
- Do not treat the Docker rootfs target as proof that a bare-metal RK firmware package has been built. Verify the selected ImageBuilder archive with the official `sha256sums` file before building a rootfs release.

## Baseline

- Container IP: `192.168.31.3`
- LAN subnet: `192.168.31.0/24`
- Gateway: `192.168.31.1`
- DHCP server: disabled
- LAN masquerade: enabled for `192.168.31.0/24 -> !192.168.31.0/24`
- Runtime expectation: Docker container with `/sbin/init`, `privileged: true`, `/dev/net/tun`, and `restart: unless-stopped`

## Safety Boundary

Do not publish any artifact containing:

- Tailscale identity, auth key, or `tailscaled.state`
- ShellCrash subscription, profile, or CrashCore runtime
- Lucky certificate, token, private domain, or private reverse-proxy config
- root password hash
- SSH private key

Personal state belongs in a private local reapply pack, not in a public GitHub Release.

## Promotion Rule

New images and plugin artifacts must be tested on an A/B IP such as `192.168.31.4` before replacing the production `.3` router. Passing this scaffold workflow is not enough to promote a live router.

Live promotion must also pass the repository macvlan ARP/MAC runbook:

- `../runbooks/docker-macvlan-arp.md`
- `../skills/gateway-dns-proxy-troubleshoot/SKILL.md` for evidence-first gateway DNS/proxy/macvlan troubleshooting

Do not promote if the iStoreOS container MAC drifts after restart/recreate, if a host-side shim uses another device's service IP, or if host/shim/container/peer IPs do not map to their intended MACs after ARP relearn and host reboot.
