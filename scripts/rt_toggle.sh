#!/bin/bash
set -euo pipefail

# Runtime toggle: enable/disable RT kernel via cmdline tag + selecting installed kernel (best-effort).
# This is a lightweight mechanism: it only toggles a marker and relies on installed kernels/bootloader behavior.
# On failure, it prints a message and exits 0.

MODE="${1:-status}"
CMDLINE="/boot/firmware/cmdline.txt"
MARKER="audioos_rt=1"

if [ ! -f "$CMDLINE" ]; then
  echo "cmdline not found: $CMDLINE"
  exit 0
fi

case "$MODE" in
  enable)
    if grep -q "$MARKER" "$CMDLINE"; then
      echo "RT marker already enabled."
    else
      sed -i "1 s/$/ $MARKER/" "$CMDLINE"
      echo "Enabled RT marker. Reboot to apply."
    fi
    ;;
  disable)
    sed -i "s/ $MARKER//" "$CMDLINE" || true
    echo "Disabled RT marker. Reboot to apply."
    ;;
  status|*)
    if grep -q "$MARKER" "$CMDLINE"; then
      echo "RT marker: enabled"
    else
      echo "RT marker: disabled"
    fi
    uname -a || true
    ;;
esac
