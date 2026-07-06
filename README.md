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

## Network Baseline

- iStoreOS container IP: `192.168.31.3`
- LAN gateway: `192.168.31.1`
- LAN subnet: `192.168.31.0/24`
- DHCP server: disabled
- LAN masquerade: `192.168.31.0/24 -> !192.168.31.0/24`

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
