# Build-spec prompt (paste into a coding LLM)

You are an expert Linux audio engineer + build engineer. Generate a **GitHub repository** that builds a bootable **Raspberry Pi OS Lite 64-bit image** for **Raspberry Pi 5** with a Roon-like headless endpoint feature set. The repo must build successfully in GitHub Actions and output an `.img.xz`.

## Hard requirements
- Target: **Raspberry Pi 5**, **64-bit**, Raspberry Pi OS Lite (no GUI), minimal packages.
- **Bit-perfect pipeline** by default for USB audio output (Eversolo DMP-A6 in USB DAC mode).
- Handle formats: FLAC, DSD/DSF (via DoP when enabled), AIFF, OGG, MP3, etc.
- Provide **resampling to PCM** using **soxr** with HQ options; resampling must respect original sample rates (no forced fixed rate unless user selects).
- Support:
  - **Logitech Media Server** endpoint via **squeezelite**
  - **Spotify Connect** via **librespot**
  - **AirPlay receiver** via **shairport-sync** in a “bit-perfect only” configuration (avoid DSP; fail closed if it would process)
- Web control plane: **Flask** UI (no GUI) with:
  - device/card selection, format display
  - HQ/LL profile switch
  - DoP on/off toggle (where applicable)
  - live logs (journalctl streaming)
  - latency test utility (round-trip estimate using ALSA loopback where available or simple buffer/underrun test)
- System tuning:
  - systemd services with **CPUAffinity** and **nice/rtprio** where safe
  - **cpuset** dedicated to audio processes (squeezelite/librespot/shairport)
  - isolate 1 CPU core with `isolcpus=` in cmdline + cpuset for audio
  - **IRQ pinning** for USB + audio related IRQs
  - systemd-udev rules to prioritize USB audio (sched/rtprio, power control, autosuspend off)
  - script to **auto-detect DAC** at boot and write the selected ALSA device into `/etc/audioos/audioos.yaml`
- Optional kernel: support an **installable PREEMPT_RT kernel**, with:
  - build-time install attempt (package-based)
  - runtime enable/disable toggle with clean fallback if RT packages are not available on the selected Raspberry Pi OS branch
- Provide “pCP-like strict” presets: buffers, soxr quality, DoP toggleable on the fly.
- Everything must be installable and configured via **pi-gen** custom stage; repo includes:
  - `.github/workflows/build-image.yml` that checks out pi-gen, copies custom stage, builds image, uploads artifact.
  - custom stage scripts (idempotent) to install packages, drop configs, enable services.
  - A `tools/build-local.sh` for local builds.

## Repo deliverables (must exist)
- `/pi-gen-custom/` with a stage `stage-audioos/` containing:
  - `00-packages` list
  - `01-run.sh` (install/configure)
- `/systemd/` unit files (audio tuning, squeezelite, librespot, shairport, ui)
- `/udev/99-usb-audio-priority.rules`
- `/ui/` Flask app with templates/static
- `/scripts/`:
  - `detect_dac.sh`
  - `apply_profile.sh` (HQ/LL)
  - `install_rt_kernel.sh` (safe fallback)
  - `irq_pin.sh`
- `/config/` default YAML/TOML/conf templates
- `README.md` with exact URLs/ports, first-boot behavior, and how to change output device.

## Acceptance criteria
- `Build Raspberry Pi Image` workflow completes and produces `audioos-raspios64.img.xz`
- On first boot, web UI comes up at port `8787`
- Squeezelite connects to LMS when configured
- Librespot advertises a Spotify Connect device
- Shairport-sync advertises an AirPlay target
- Profiles can be switched from UI and restart services reliably
- If RT kernel install fails, the system still boots normally and logs the skip

Use safe defaults, prioritize simplicity, and keep image minimal.
