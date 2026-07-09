# OECT fnOS iStoreOS Docker Builder

This fork is the production scaffold for building a private OECT/fnOS Docker iStoreOS side-router image line.

Upstream attribution is preserved in `LICENSE` and git history. This fork does not claim to be the upstream project.

## Current Production Scope

The default production workflow is:

- `.github/workflows/oect-dry-run-release.yml`

It publishes:

- `manifest.json`
- `SHA256SUMS`
- `SAFETY.md`
- `oect-istoreos-seed-files.tar.gz`
- `oect-fnos-arm64-target.tar.gz`

This is a scaffold release. It proves the seed files, target files, checksums, and security gates are publishable. It does not claim a live fnOS/OECT deployment has passed.

## Manual Rootfs Build

The manual workflow is:

- `.github/workflows/oect-build-rootfs.yml`

It requires an official iStoreOS ImageBuilder URL and its exact sha256. Do not run it with a drifting or unverified URL.

Official ImageBuilder entry:

- `https://fw.koolcenter.com/iStoreOS/ib/`

Target note:

- This repository currently follows upstream's Docker rootfs line: `armsr/armv8`, using the official `armsr/` ImageBuilder.
- OECT hardware is RK3566/Rockchip. For a bare-metal or RK-specific iStoreOS firmware build, use the official `rk3xxx/` ImageBuilder (`rockchip-armv8`) instead.
- Do not treat the Docker rootfs target as proof that a bare-metal RK firmware package has been built. Always verify the selected archive against the official `sha256sums` file before triggering the workflow.

## Network Baseline

- iStoreOS container IP: `192.168.31.3`
- LAN gateway: `192.168.31.1`
- LAN subnet: `192.168.31.0/24`
- DHCP server: disabled
- LAN masquerade: `192.168.31.0/24 -> !192.168.31.0/24`

For a generic macvlan compose pattern with a pinned container MAC, see:

- `examples/compose.macvlan.yml`

Compose variable quick reference:

| Variable | Meaning |
| --- | --- |
| `ISTORE_IMAGE` | iStoreOS/OpenWrt image tag to run |
| `ISTORE_CONTAINER` | Container name, usually the live router name |
| `ISTORE_IP` | Container LAN IP reserved for iStoreOS |
| `ISTORE_MAC` | Container macvlan endpoint MAC discovered and pinned after drift is proven |
| `LAN_PARENT` | Host LAN interface used as the macvlan parent |
| `LAN_SUBNET` | LAN subnet for the macvlan network |
| `LAN_GATEWAY` | LAN gateway for the container |

## Security Boundary

Public releases must not contain:

- Tailscale identity, auth key, or `tailscaled.state`
- ShellCrash subscription, profile, or CrashCore runtime
- Lucky certificate, token, domain, or private reverse-proxy rules
- root password hash
- SSH private keys

Private runtime state belongs in a local private reapply pack, not in a public image or GitHub Release.

## Promotion Rule

Build artifacts must be tested on an A/B IP such as `192.168.31.4` before replacing the production `.3` router. Passing GitHub Actions is not the same as passing live fnOS macvlan, LAN client, OECT reboot, and optional host BBR gates.

Before promoting a live router, also pass the macvlan ARP/MAC gates in:

- `runbooks/docker-macvlan-arp.md`

At minimum, verify that:

- the container keeps the same IP and pinned MAC across `docker restart` and `docker compose up -d --force-recreate`;
- any host-side macvlan shim uses an unused helper IP, not another LAN device's service IP;
- host IP, shim IP, container IP, and peer LAN device IP each map to the intended MAC after ARP relearn;
- any shim source policy rule uses the target host's actual LAN route table and a free priority;
- the final IP-to-MAC map survives interface rebuild and host reboot.
