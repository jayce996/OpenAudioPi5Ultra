#!/bin/bash
set -euo pipefail

PROFILE="${1:-hq}"
CFG="/etc/audioos/audioos.yaml"

# Load YAML (python) and render /etc/default/squeezelite + librespot/shairport output device
python3 - <<PY
import yaml, os, sys
cfg_path = "$CFG"
with open(cfg_path,'r') as f:
    cfg = yaml.safe_load(f) or {}
device = cfg.get('device',{}).get('alsa','default')
dop = bool(cfg.get('device',{}).get('dop', False))
name = cfg.get('services',{}).get('squeezelite',{}).get('name','AudioOS')
lms = cfg.get('services',{}).get('squeezelite',{}).get('lms_host','') or ''
profile = "$PROFILE"

# Base options
opts = []
opts += [f"-n {name}"]
opts += [f"-o {device}"]
if lms:
    opts += [f"-s {lms}"]

# Buffer & latency presets
if profile == "ll":
    # lower latency
    opts += ["-a 40:4:16:0"]
    # keep supported rates; do not force resample
    opts += ["-r 44100,48000,88200,96000,176400,192000"]
else:
    # HQ
    opts += ["-a 80:4:32:0"]
    opts += ["-r 44100,48000,88200,96000,176400,192000"]

# DoP is mostly relevant for LMS DSD->DoP path; expose via -D
if dop:
    opts += ["-D"]

sl_opts = " ".join(opts)

with open("/etc/default/squeezelite","w") as f:
    f.write(f'SL_OPTS="{sl_opts}"\\n')

# librespot config
lp = cfg.get('services',{}).get('librespot',{}).get('name','AudioOS Spotify')
with open("/etc/librespot.toml","w") as f:
    f.write(f'name = "{lp}"\\n')
    f.write('backend = "alsa"\\n')
    f.write(f'device = "{device}"\\n')
    f.write('bitrate = 320\\n')
    f.write('volume_ctrl = "softvol"\\n')
    f.write('enable_volume_normalisation = false\\n')

# shairport-sync config
ap = cfg.get('services',{}).get('shairport',{}).get('name','AudioOS AirPlay')
conf = f'''general =
{{
  name = "{ap}";
}};

alsa =
{{
  output_device = "{device}";
  mixer_type = "software";
  disable_synchronization = "yes";
}};

diagnostics =
{{
  log_verbosity = 1;
}};
'''
with open("/etc/shairport-sync.conf","w") as f:
    f.write(conf)

# update current profile
cfg.setdefault('profiles',{})['current']=profile
with open(cfg_path,'w') as f:
    yaml.safe_dump(cfg,f,sort_keys=False)

print("Applied profile:", profile)
print("Device:", device)
print("Squeezelite opts:", sl_opts)
PY

# restart services
systemctl restart squeezelite.service || true
systemctl restart librespot.service || true
systemctl restart shairport-sync.service || true

exit 0
