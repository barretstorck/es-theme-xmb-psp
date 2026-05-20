# es-theme-xmb-psp

A PSP XMB-style theme for [batocera-emulationstation](https://github.com/batocera-linux/batocera-emulationstation), built and tuned for **Knulli Scarab on the TrimUI Brick** (4:3, 1024×768).

> Status: PSP-style variant only. 4:3 only. Twelve user-selectable PSP-month colorsets.

## Install

1. SSH into your device. The Knulli default credentials are `root` / `linux`:
   ```
   ssh root@<your-device-ip>
   ```
2. Clone (or copy) this repo into `/userdata/themes/`:
   ```
   cd /userdata/themes && git clone <repo-url> es-theme-xmb-psp
   ```
3. In EmulationStation: **Main Menu → UI Settings → Theme Set → `es-theme-xmb-psp`**.
4. Pick a colorset: **UI Settings → Theme Configuration → PSP Color → choose one**.
5. Restart EmulationStation: **Main Menu → Quit → Restart Emulation Station**.

## Compatibility

- **Tested:** Knulli Scarab on TrimUI Brick (4:3, 1024×768).
- **Likely works:** any Batocera/Knulli device at 4:3 running batocera-emulationstation with `formatVersion 7` support. Other aspect ratios will letterbox or stretch.

## Customization

The only configurable knob is colorset (PSP-authentic month-tinted palettes). Change it under **UI Settings → Theme Configuration → PSP Color**. No per-system or per-device overrides — the theme intentionally ships minimal.

## Troubleshooting

If the theme breaks EmulationStation on startup, SSH still works. To force Batocera back to the built-in `carbon` theme:

```
ssh root@<your-device-ip> 'batocera-settings-set theme.set carbon && batocera-es-swissknife --restart'
```

## Credits and license

This is a derivative work. See [CREDITS.md](CREDITS.md) for the full attribution chain.

Licensed under **Creative Commons CC-BY-NC-SA 2.0** — see [LICENSE](LICENSE). You may share and adapt this theme for non-commercial purposes, must credit the upstream authors, and must license derivatives under the same terms.
