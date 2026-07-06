#!/bin/sh
set -eu

target_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

cat "$target_dir/config.seed" >> .config
make defconfig
grep -q '^CONFIG_TARGET_ROOTFS_TARGZ=y' .config

make image \
  PACKAGES="$(grep -vE '^\s*(#|$)' "$target_dir/packages.list" | tr '\n' ' ')" \
  FILES="$target_dir/files"
