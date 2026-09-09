# Battery widget verification (issue #4)

## `device-before.png` — what the device showed before this change

The reason #4's premise needed correcting. The theme's status bar was
"clock-only", but the Brick was **already** drawing a battery: ES's own
`BatteryIndicatorComponent` (`Window.cpp:157`), an unstyled wifi + glyph +
`100%` row sitting directly above the clock, in ES's font. That is the
widget v0.10 was fighting when it concluded `<visible>false</visible>`
"doesn't hide the icon on-device" — it was hiding its own `batteryIcon`
while this kept painting.

## `device-after.png` — the same device, this branch

TrimUI Brick (192.168.0.52), Knulli, April Green, 1024x768, captured with
`knulli-screenshot` under the normal `S31emulationstation` service.

Measured ink bands, left to right:

| Element | x span | ink height | ink centre |
|:---|:---|---:|---:|
| Clock `12:35 PM` | 0.7051 – 0.8164 | 23 px | 0.0612 |
| `networkIcon` | 0.8340 – 0.8594 | 21 px | 0.0612 |
| `batteryText` `100%` | 0.8779 – 0.9199 | 17 px | 0.0612 |
| `batteryIcon` | 0.9346 – 0.9785 | 23 px | 0.0599 |

**The harness predicted these to sub-pixel** — its own bands at the same
level are 0.8340–0.8594, 0.8779–0.9209 and 0.9346–0.9795. For this cluster
the harness can be trusted.

Two things only hardware showed:

- **The glyph is the charging bolt, not the full 3-bar art.** The device
  reports `status = Full` while plugged in, and ES computes
  `isCharging = (status != "Not charging" && status != "Discharging")`
  (`Platform.cpp`), so `Full` counts as charging and
  `BatteryIconComponent.cpp:56` takes the `incharge` branch before it ever
  looks at the level. A plugged-in device at 100% never shows `full`.
- **The clock is nearly full at its 12-hour width.** `12:35 PM` ends at
  0.8164 against a box edge of 0.82 — 0.0036 of slack. This is not new
  (the box is still 0.14 wide, it only moved), but anything wider than
  `12:35 PM` would be abbreviated with `...` rather than overflow.

## `harness-battery-states.png`

The four charge states plus no-battery, via `render.sh --battery`:
47% (2 segments), 4% (empty — ES switches at `level > 5`), 80% charging
(bolt), 100% (full, and the widest text the percentage can be), and a
device with no battery at all, where both battery elements auto-hide and
the clock and network glyph do not move.

## `harness-aspect-ratios.png`

All five design surfaces at `100%`, the widest string the percentage can be.
This is what the first pass got wrong: x positions are fractions of screen
*width* but a `<fontSize>` is a fraction of screen *height*, so `"100%"` is
0.058 of the width at 1:1 against 0.045 at 4:3, and the 4:3 literals ran it
into the battery glyph at 8:7 (6 px clearance) and 1:1 (3 px — actually
touching). Fixed with per-ratio `${statusClockX}` / `${statusNetX}` /
`${statusPctX}` variables.

The measured percent-to-glyph clearance, after:

| Ratio | Surface | clearance |
|:---|:---|---:|
| 4:3 | 1024x768 | 0.0137 (14 px) |
| 8:7 | 1024x896 | 0.0166 (17 px) |
| 3:2 | 720x480 | 0.0139 (10 px) |
| 16:9 | 1280x720 | 0.0180 (23 px) |
| 1:1 | 720x720 | 0.0208 (15 px) |

The rendered `"100%"` ink widths behind `PCT_INK_W` in
`scripts/tests/test-battery.sh` were measured from these same renders. They
are measured rather than computed because PIL's metrics for this font
disagree with ES's rasteriser by -12% to +23% across these sizes — the first
attempt at 3:2 was tuned from a computed width and left only 4 px.

## `harness-showbattery-values.png`

Visibility is ES's setting, not a theme subset: *UI Settings > Show
Battery Status*. ICON AND TEXT (the ES default), ICON, and NO.

## Not refreshed here

The shipped reference screenshots (`docs/screenshots/system-*.png`,
`gamelist-*.png`) still show the clock at its old `0.84` position, since
the status bar overlays every view. Regenerating that set belongs to #45
(README showcase), which owns those images and wants them taken with real
scraped assets.
