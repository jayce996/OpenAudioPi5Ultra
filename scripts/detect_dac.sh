#!/bin/bash
set -euo pipefail

CFG="/etc/audioos/audioos.yaml"

# Find first USB audio card, else fallback to first non-HDMI card, else default.
USB_CARD=$(aplay -l 2>/dev/null | awk '/card [0-9]+:/{c=$2} /USB Audio|USB|XMOS|Eversolo|DMP/ {gsub(":","",c); print c; exit}')
if [ -n "${USB_CARD:-}" ]; then
  CARD="hw:${USB_CARD},0"
else
  # pick first card that isn't HDMI if possible
  CARDLINE=$(aplay -l 2>/dev/null | awk '/card [0-9]+:/{print; exit}')
  if [ -n "${CARDLINE:-}" ]; then
    NUM=$(echo "$CARDLINE" | sed -n 's/^card \([0-9]\+\):.*/\1/p')
    CARD="hw:${NUM},0"
  else
    CARD="default"
  fi
fi

# Update YAML (simple safe replace)
if [ -f "$CFG" ]; then
  python3 - <<PY
import yaml
p="$CFG"
with open(p,'r') as f:
    data=yaml.safe_load(f) or {}
data.setdefault('device',{})
data['device']['alsa']="$CARD"
with open(p,'w') as f:
    yaml.safe_dump(data,f,sort_keys=False)
print("Set ALSA device to", "$CARD")
PY
fi

# Render service configs from templates
cp /etc/audioos/templates/librespot.toml /etc/librespot.toml || true
cp /etc/audioos/templates/shairport-sync.conf /etc/shairport-sync.conf || true

exit 0
