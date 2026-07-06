#!/bin/sh
set -eu

scan_dir="${1:-oect/files}"
denylist="${2:-oect/security-denylist.txt}"

if [ ! -d "$scan_dir" ]; then
  echo "ERROR: scan directory not found: $scan_dir" >&2
  exit 2
fi

if [ ! -s "$denylist" ]; then
  echo "ERROR: denylist not found or empty: $denylist" >&2
  exit 3
fi

fail=0
while IFS= read -r pattern; do
  case "$pattern" in
    ""|\#*) continue ;;
  esac
  if grep -R -I -n -F "$pattern" "$scan_dir" >/tmp/oect-security-hit.txt 2>/dev/null; then
    echo "FAIL: denied pattern found: $pattern" >&2
    cat /tmp/oect-security-hit.txt >&2
    fail=1
  fi
done < "$denylist"

if [ "$fail" -ne 0 ]; then
  exit 10
fi

echo "PASS: security scan clean for $scan_dir"
