#!/bin/bash
set -euo pipefail

# Attempt to install an RT kernel package if available on this Raspberry Pi OS branch.
# This script is intentionally conservative: it will not fail the build.

echo "[AudioOS] Checking for RT kernel packages..."
if ! command -v apt-cache >/dev/null 2>&1; then
  echo "[AudioOS] apt-cache not found; skipping RT kernel install."
  exit 0
fi

CANDIDATES=(
  "linux-image-rt-arm64"
  "linux-image-rpi-rt"
  "linux-image-raspi-rt"
)

FOUND=""
for p in "${CANDIDATES[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then
    FOUND="$p"
    break
  fi
done

if [ -z "$FOUND" ]; then
  echo "[AudioOS] No RT kernel package found; skipping."
  exit 0
fi

echo "[AudioOS] Installing RT kernel package: $FOUND"
apt-get update || true
if apt-get install -y "$FOUND"; then
  echo "[AudioOS] RT kernel installed."
else
  echo "[AudioOS] RT kernel install failed; skipping."
fi

exit 0
