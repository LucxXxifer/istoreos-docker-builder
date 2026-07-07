#!/bin/sh
set -eu

release_tag="${1:-manual}"
artifact_class="${2:-scaffold}"
upstream_commit="$(git ls-remote https://github.com/wukongdaily/istoreos-docker-builder.git refs/heads/master | awk '{print $1}')"
[ -n "$upstream_commit" ] || upstream_commit="unknown"
source_commit="$(git rev-parse --verify HEAD^{commit})"
tag_commit="$(git rev-parse --verify "refs/tags/$release_tag^{commit}" 2>/dev/null || true)"
[ -n "$tag_commit" ] || tag_commit="unresolved"
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
contains_rootfs=false
contains_docker_image=false

case "$artifact_class" in
  rootfs)
    contains_rootfs=true
    ;;
  docker-image)
    contains_rootfs=true
    contains_docker_image=true
    ;;
esac

cat <<JSON
{
  "name": "oect-fnos-istoreos-docker",
  "release_tag": "$release_tag",
  "generated_at": "$generated_at",
  "artifact_class": "$artifact_class",
  "source_repo": "LucxXxifer/istoreos-docker-builder",
  "source_commit": "$source_commit",
  "tag_commit": "$tag_commit",
  "upstream_repo": "wukongdaily/istoreos-docker-builder",
  "upstream_master_commit": "$upstream_commit",
  "release_policy": {
    "immutable_tag_required": true,
    "tag_commit_must_match_source_commit": true,
    "move_existing_public_tag": false
  },
  "target": {
    "host": "fnOS/OECT",
    "container_ip": "192.168.31.3",
    "lan_subnet": "192.168.31.0/24",
    "gateway": "192.168.31.1",
    "arch": "armsr/armv8",
    "openwrt_release": "24.10.x"
  },
  "network_policy": {
    "dhcp_server": "disabled",
    "masquerade": true,
    "masq_src": "192.168.31.0/24",
    "masq_dest": "!192.168.31.0/24"
  },
  "build_inputs": {
    "imagebuilder_url": "${OECT_IMAGEBUILDER_URL:-}",
    "imagebuilder_sha256": "${OECT_IMAGEBUILDER_SHA256:-}",
    "rootfs_sha256": "${OECT_ROOTFS_SHA256:-}",
    "docker_image": "${OECT_DOCKER_IMAGE:-}",
    "docker_digest": "${OECT_DOCKER_DIGEST:-}"
  },
  "contains_rootfs": $contains_rootfs,
  "contains_docker_image": $contains_docker_image,
  "contains_private_identity": false,
  "explicitly_excluded": [
    "tailscaled.state",
    "tailscale auth key",
    "ShellCrash subscription",
    "CrashCore runtime",
    "Lucky certificate/token/domain",
    "root password hash",
    "SSH private key"
  ],
  "required_live_gates": [
    "fnOS macvlan LAN client can reach http://192.168.31.3/",
    "docker compose recreate keeps network and firewall config",
    "OECT reboot brings Docker and container back",
    "fnOS host BBR verified only if enabled"
  ]
}
JSON
