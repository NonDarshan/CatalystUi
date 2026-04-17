# CatalystUi Build System

This repository contains an automated GitHub Actions pipeline to build a **TWRP-flashable CatalystUi zip** from Samsung SM-A146B stock firmware.

## What this pipeline does

1. Downloads stock firmware archive from Samloader (recommended) or a direct URL.
2. Extracts AP partition images.
3. Converts `.img.lz4` to `.img`.
4. Extracts `system`, `product`, and `system_ext` contents.
5. Applies CatalystUi property/CSC patches, blur & animation toggles, debloat profile, thermal profile, charging service, and custom wallpaper replacement.
6. Stages a TWRP-flashable package with installer scripts and payload.
7. Outputs `out/CatalystUi_<version>_SM-A146B.zip`.

## New customization options

- **Firmware source**:
  - `samloader`: auto-fetch firmware by model/CSC/version.
  - `url`: use manual archive URL.
- **Fast charging enforcement**: injects an init service that tries to push known charging current nodes to maximum supported values at boot.
- **Debloat profiles**:
  - `safe`: conservative removal.
  - `heavy`: stronger removal while keeping core telephony/system stability.
- **Live blur / high-end animation toggles**: properties are set in CatalystUi feature config for easy hook-in with UI mods.
- **Custom wallpaper folder**: place your image in `custom_wallpapers/`; first file is packed as default wallpaper.

## Important notes

- This is a build framework and patch set, not a guarantee every requested flagship feature is natively supported on all A14 hardware.
- Thermal safeguards are **relaxed**, not fully removed, to reduce hardware risk.
- Forcing charging limits can increase heat and battery wear over time.
- DeX over HDMI still requires hardware DisplayPort capability.
- If recovery lacks `avbctl`, vbmeta patching must be completed manually.

## GitHub Actions usage

Run workflow: **Build CatalystUi ROM** with:
- `firmware_source`: `samloader` or `url`.
- `firmware_url`: required only if source is `url`.
- `samloader_model`: e.g. `SM-A146B`.
- `samloader_region`: e.g. `INS`.
- `samloader_version`: firmware string or `latest`.
- `rom_version`: your version label.
- `apply_debloat`: true/false.
- `debloat_profile`: safe/heavy.
- `force_fast_charge`: true/false.
- `patch_vbmeta`: true/false.

The workflow uploads:
- Flashable zip artifact.
- Build logs artifact.
