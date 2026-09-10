# Troubleshooting

## The theme breaks EmulationStation on startup

SSH still works. To force the device back to the built-in `carbon` theme:

**Knulli:**
```
ssh root@<your-device-ip> "knulli-settings-set theme.set carbon && sed -i 's|<string name=\"ThemeSet\" value=\"[^\"]*\"|<string name=\"ThemeSet\" value=\"carbon\"|' /userdata/system/configs/emulationstation/es_settings.cfg && knulli-es-swissknife --restart"
```

**Batocera:**
```
ssh root@<your-device-ip> 'batocera-settings-set theme.set carbon && batocera-es-swissknife --restart'
```

Knulli stores the theme name in two places — `theme.set` in `knulli.conf` and
`ThemeSet` in `es_settings.cfg`. If they diverge, ES enters a restart loop. The
Knulli command above updates both atomically.

The Knulli default SSH credentials are `root` / `linux`.

## No navigation sounds at all

EmulationStation ships with navigation sounds turned **off**, and that is ES's own
switch rather than a theme option. Turn on **Main Menu ▸ Sound Settings ▸ Enable
Navigation Sounds**.

## Still nothing after turning them on

Restart EmulationStation. ES skips loading a sound file entirely while that
setting is off, and switching it on does not reload the ones it already skipped —
they are only re-read when the audio system restarts, which happens at ES startup
and on returning from a game. Launching and quitting any game works too.

## Box Art Grid renders as an unstyled gamelist

**UI Settings ▸ Gamelist View Style** must be `Automatic` (ES's own default, in a
different menu from the theme's settings). Pinned to `Detailed` or `Gamecarousel`,
ES ignores the theme's requested view. The theme cannot detect or override that
preference; switching back to Automatic restores the grid.

## Gamelist rows show silhouettes instead of box art

With **Icon Size** on `Boxart`, each row shows the game's scraped `thumbnail`. A
game with no thumbnail falls back to its system's media-type silhouette —
cartridge, CD, floppy and so on, from `art/system-media/`. Scrape your library
with box/thumbnail media, or switch Icon Size to `Compact`.
