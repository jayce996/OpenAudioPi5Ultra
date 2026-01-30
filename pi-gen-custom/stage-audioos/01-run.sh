#!/bin/bash
set -euo pipefail

on_chroot <<'EOF'
set -euo pipefail

echo "[AudioOS] Creating directories..."
install -d -m 0755 /opt/audioos/ui /opt/audioos/scripts /etc/audioos /etc/audioos/templates

echo "[AudioOS] Installing repo payload..."
# Copy files staged by pi-gen into target (they are already in /tmp during build)
rsync -a /tmp/repo_payload/ui/ /opt/audioos/ui/
rsync -a /tmp/repo_payload/scripts/ /opt/audioos/scripts/
rsync -a /tmp/repo_payload/systemd/ /etc/systemd/system/
rsync -a /tmp/repo_payload/udev/ /etc/udev/rules.d/
rsync -a /tmp/repo_payload/config/ /etc/audioos/templates/

chmod +x /opt/audioos/scripts/*.sh || true
ln -sf /opt/audioos/scripts/apply_profile.sh /usr/local/bin/audioos-apply-profile
ln -sf /opt/audioos/scripts/detect_dac.sh /usr/local/bin/audioos-detect-dac
ln -sf /opt/audioos/scripts/install_rt_kernel.sh /usr/local/bin/audioos-install-rt
ln -sf /opt/audioos/scripts/rt_toggle.sh /usr/local/bin/audioos-rt-toggle
ln -sf /opt/audioos/scripts/irq_pin.sh /usr/local/bin/audioos-irq-pin

echo "[AudioOS] Default config..."
if [ ! -f /etc/audioos/audioos.yaml ]; then
  cp /etc/audioos/templates/audioos.yaml /etc/audioos/audioos.yaml
fi

echo "[AudioOS] Create python venv for UI..."
python3 -m venv /opt/audioos/venv
/opt/audioos/venv/bin/pip install --no-cache-dir --upgrade pip wheel
/opt/audioos/venv/bin/pip install --no-cache-dir flask pyyaml

echo "[AudioOS] systemd reload & enable services..."
systemctl daemon-reload
systemctl enable audioos-tune.service
systemctl enable audioos-detect-dac.service
systemctl enable squeezelite.service
systemctl enable librespot.service
systemctl enable shairport-sync.service
systemctl enable audioos-ui.service

echo "[AudioOS] Apply initial HQ profile..."
/usr/local/bin/audioos-apply-profile hq || true

echo "[AudioOS] Attempt RT kernel install (safe, optional)..."
/usr/local/bin/audioos-install-rt || true

echo "[AudioOS] Disable autosuspend for USB by default..."
mkdir -p /etc/modprobe.d
cat >/etc/modprobe.d/usb-autosuspend.conf <<'EOC'
options usbcore autosuspend=-1
EOC

echo "[AudioOS] Caddy reverse proxy to UI..."
install -d -m 0755 /etc/caddy
cat >/etc/caddy/Caddyfile <<'EOC'
:80 {
  reverse_proxy 127.0.0.1:8787
}
EOC
systemctl enable caddy

echo "[AudioOS] CPU isolation (best-effort): append isolcpus to cmdline if not present."
CMDLINE=/boot/firmware/cmdline.txt
if [ -f "$CMDLINE" ]; then
  if ! grep -q "isolcpus=" "$CMDLINE"; then
    sed -i '1 s/$/ isolcpus=3 nohz_full=3 rcu_nocbs=3/' "$CMDLINE"
  fi
fi

echo "[AudioOS] Done."
EOF
