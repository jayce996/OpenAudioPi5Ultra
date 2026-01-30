# AudioOS (Roon-like headless audio endpoint) for Raspberry Pi 5 (64-bit)

This repo builds a **Raspberry Pi OS Lite 64-bit** `.img` using **pi-gen** + a custom stage that installs and configures:
- **Squeezelite** (Logitech Media Server endpoint)
- **Librespot** (Spotify Connect)
- **Shairport-sync** (AirPlay receiver — configured for "bit-perfect only" behavior)
- A lightweight **Flask Web UI** (no desktop GUI) to:
  - select output card/device & format
  - switch **HQ / LL** profiles (quality vs low latency)
  - toggle DoP on/off
  - view live logs & run latency test
- Audio tuning: **systemd CPUAffinity/cpuset**, **IRQ affinity**, **udev rules** to prioritize USB audio, **DAC auto-detect** at boot
- Optional **PREEMPT_RT** kernel installation with a safe fallback if unavailable

> Note: Spotify support uses **librespot** (community implementation of Spotify Connect). It is not official Spotify software.

## Quick start (GitHub Actions)
1. Push this repo to GitHub
2. Run the workflow **Build Raspberry Pi Image**
3. Download the generated artifact: `audioos-raspios64.img.xz`

## Local build (Linux)
```bash
git clone https://github.com/<you>/<repo>.git
cd <repo>
./tools/build-local.sh
```

## First boot
- Default hostname: `audioos`
- Default user: `pi`
- Default password: `raspberry` (change immediately)
- Web UI: `http://audioos.local:8787`

## Configuration files
- `/etc/audioos/audioos.yaml` (main settings)
- `/etc/default/squeezelite` (generated)
- `/etc/librespot.toml`
- `/etc/shairport-sync.conf`
- `/etc/udev/rules.d/99-usb-audio-priority.rules`

## Profiles
- **HQ**: larger buffers, soxr very-high quality, min-ringing/hybrid options available
- **LL**: reduced buffering, aggressive scheduling, lower latency

Switch profiles in the Web UI (or run):
```bash
sudo audioos-apply-profile hq
sudo audioos-apply-profile ll
```

## PREEMPT_RT runtime option
AudioOS can attempt to install an RT kernel package at build time and expose a **boot-time toggle** via `/boot/firmware/cmdline.txt` entries and `audioos-rt-toggle`.

If an RT kernel package isn't available on the selected Raspberry Pi OS branch, the installer **skips** and preserves the non-RT kernel.

## Notes on "bit-perfect"
- For LMS: use Squeezelite with `-o hw:<card>,<device>` and disable DSP.
- For Spotify: Spotify Connect may resample internally depending on the stream.
- For AirPlay: AirPlay streams are typically 44.1kHz/16-bit ALAC; we avoid extra DSP.

## License
MIT
