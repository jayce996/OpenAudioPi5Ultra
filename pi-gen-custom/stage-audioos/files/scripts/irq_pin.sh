#!/bin/bash
set -euo pipefail

# Pin xhci (USB3) and snd IRQs to CPU3 (mask 0x8 on 4-core)
MASK="8"

while read -r irq rest; do
  irqnum="${irq%:}"
  if echo "$rest" | grep -Eiq "(xhci|usb|snd|dwc|xhci_hcd)"; then
    if [ -w "/proc/irq/${irqnum}/smp_affinity" ]; then
      echo "$MASK" > "/proc/irq/${irqnum}/smp_affinity" || true
    fi
  fi
done < /proc/interrupts

exit 0
