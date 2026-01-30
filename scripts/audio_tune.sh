#!/bin/bash
set -euo pipefail

# Governor to performance (best-effort)
if command -v cpufreq-set >/dev/null 2>&1; then
  cpufreq-set -g performance || true
else
  for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$g" ] && echo performance > "$g" || true
  done
fi

# Create cpuset groups (requires cpuset package)
# We dedicate CPU3 to audio (also matches isolcpus=3)
if command -v cset >/dev/null 2>&1; then
  cset set -c 3 -s audio || true
  cset proc -m -f root -t / || true
fi

# Pin likely USB IRQs to CPU3 (best-effort heuristic)
if [ -x /opt/audioos/scripts/irq_pin.sh ]; then
  /opt/audioos/scripts/irq_pin.sh || true
fi

exit 0
