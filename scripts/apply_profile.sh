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

device = (cfg.get('device') or {}).get('alsa','default')
dop = bool((cfg.get('device') or {}).get('dop', False))
name = (((cfg.get('services') or {}).get('squeezelite') or {}).get('name') or 'AudioOS')
lms = (((cfg.get('services') or {}).get('squeezelite') or {}).get('lms_host') or '') or ''
profile = "$PROFILE"

res = cfg.get('resample') or {}
res_enable = bool(res.get('enable', True))

# ---- Build squeezelite options ----
opts = [f"-n {name}", f"-o {device}"]
if lms:
    opts += [f"-s {lms}"]

# Buffer presets
if profile == "ll":
    opts += ["-a 40:4:16:0", "-b 1024:1536", "-p 70"]
else:
    opts += ["-a 80:4:32:0", "-b 2048:3445", "-p 85"]

# Advertise supported rates (do not force)
opts += ["-r 44100,48000,88200,96000,176400,192000"]

# DoP / native DSD
if dop:
    opts += ["-D"]

# ---- Resampling / upsampling with soxr (squeezelite -u/-R) ----
# Reference: squeezelite man page resampling argument format:
# <recipe>:<flags>:<attenuation>:<precision>:<passband_end>:<stopband_start>:<phase_response>
# recipe flags: [v|h|m|l|q][L|I|M][s][E|X]
# - E avoids resampling if output supports the rate (good for "bit-perfect when possible")
# - X forces async upsample to max device rate
if res_enable:
    adv = res.get('soxr') or {}
    quality = str(adv.get('quality', 'h')).lower()  # v/h/m/l/q
    if quality in ('very_high','vhq','v'): q='v'
    elif quality in ('high','h'): q='h'
    elif quality in ('medium','m'): q='m'
    elif quality in ('low','l'): q='l'
    elif quality in ('quick','q'): q='q'
    else: q='h'

    phase = str(adv.get('phase', 'L')).lower()
    if phase in ('linear','l'): ph='L'
    elif phase in ('intermediate','i'): ph='I'
    elif phase in ('minimum','min','m'): ph='M'
    else: ph='L'

    steep = bool(adv.get('steep', False))
    exception = bool(adv.get('exception', True))   # default ON (fail-open to bit-perfect)
    async_max = bool(adv.get('async_max', False))

    recipe = q + ph + ('s' if steep else '') + ('E' if exception else '') + ('X' if async_max else '')

    flags = adv.get('flags_hex', '')  # e.g. "2" for SOXR_ROLLOFF_NONE
    att = adv.get('attenuation_db', '')  # e.g. "0" to disable default -1dB
    prec = adv.get('precision_bits', '') # e.g. "28"
    pb = adv.get('passband_end', '')     # e.g. "98"
    sb = adv.get('stopband_start', '')   # e.g. "100"
    pr = adv.get('phase_response', '')   # 0-100

    # Build -u arg with minimal separators so squeezelite parses correctly
    parts = [recipe, flags, att, prec, pb, sb, pr]
    # trim trailing empty fields
    while parts and parts[-1] in ("", None):
        parts.pop()
    uarg = ":".join([p if p is not None else "" for p in parts]) if parts else recipe
    opts += [f"-u {uarg}"]

sl_opts = " ".join(opts)

with open("/etc/default/squeezelite","w") as f:
    f.write(f'SL_OPTS="{sl_opts}"\n')

# ---- librespot ----
lp = (((cfg.get('services') or {}).get('librespot') or {}).get('name') or 'AudioOS Spotify')
with open("/etc/librespot.toml","w") as f:
    f.write(f'name = "{lp}"\n')
    f.write('backend = "alsa"\n')
    f.write(f'device = "{device}"\n')
    f.write('bitrate = 320\n')
    f.write('volume_ctrl = "softvol"\n')
    f.write('enable_volume_normalisation = false\n')

# ---- shairport-sync (AirPlay) ----
ap = (((cfg.get('services') or {}).get('shairport') or {}).get('name') or 'AudioOS AirPlay')
air = cfg.get('airplay') or {}
strict = bool(air.get('strict', False))

# Strict guidance: "bit perfect" commonly requires hw device + ignore volume + disable sync
# (see shairport-sync discussions/issues).
# We do best-effort config; user should set device to hw:CARD,DEV for strictest behavior.
alsa_mixer_type = "none" if strict else "software"
ignore_vol = "yes" if strict else "no"
disable_sync = "yes"  # generally recommended for stable USB DAC behavior

conf = f'''general =
{{
  name = "{ap}";
}};

alsa =
{{
  output_device = "{device}";
  mixer_type = "{alsa_mixer_type}";
  ignore_volume_control = "{ignore_vol}";
  disable_synchronization = "{disable_sync}";
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
print("AirPlay strict:", strict)
PY

# restart services
systemctl restart squeezelite.service || true
systemctl restart librespot.service || true
systemctl restart shairport-sync.service || true

exit 0
