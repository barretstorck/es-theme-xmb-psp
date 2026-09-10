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

TrimUI Brick (192.168.1.4), Knulli, April Green, 1024x768, captured with
`knulli-screenshot` under the normal `S31emulationstation` service.

Measured ink bands, left to right:

| Element | x span | ink height | ink centre |
|:---|:---|---:|---:|
| Clock `01:57 PM` | 0.6914 – 0.8037 | 23 px | 0.0599 |
| `networkIcon` | 0.8242 – 0.8496 | 23 px | 0.0599 |
| `batteryText` `93%` | 0.8711 – 0.9180 | 21 px | 0.0612 |
| `batteryIcon` | 0.9346 – 0.9785 | 23 px | 0.0599 |

Cluster span 0.6914 – 0.9785, against the harness's 0.3047 prediction for
this surface at the wider `"100%"`.

**The harness matches the device** — same right margin, same ink centres,
same spacing. For this cluster the harness can be trusted, provided
`CLOCK_12H=true` is used: the Bricks run a 12-hour clock and it is ~1.7x
wider than the 24-hour one the harness renders by default.

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
the cluster shortens to clock + network glyph.

## `harness-aspect-ratios.png`

All five design surfaces at `100%`, the widest string the percentage can be.
Rendered with `CLOCK_12H=true` and `--battery 100`: the 12-hour clock the
Bricks are set to is ~1.7x wider than ES's 24-hour default, and `"100%"` is
the widest the percentage gets, so this is the case the cluster has to fit.

The first pass hand-placed each element, which cannot hold across ratios: x
positions are fractions of screen *width* but a `<fontSize>` is a fraction of
screen *height*, so text takes a different share of the width on every
surface. The 4:3 literals ran the percentage into the battery glyph at 8:7
(6 px clearance) and 1:1 (3 px — touching).

The second pass fixed that with per-ratio variables. Those are now **gone**:
the cluster is a `<stackpanel>` that packs itself from the right margin, so
one set of literals serves every surface and there is nothing to re-tune.
Measured after, at the 12-hour/`100%` worst case: right edge 0.979 at every
ratio, and cluster widths of 0.305 (4:3), 0.351 (8:7), 0.321 (3:2), 0.230
(16:9) and 0.408 (1:1) against a panel of 0.50. Those five numbers are the
table `test-battery.sh` guards the panel width against.

## `harness-showbattery-collapse.png`

The defect this widget was re-worked for, found in manual review on the
hammer. ES owns the visibility of three of the four elements, so a fixed
layout leaves a hole wherever the missing one was:

| Setting | Before | After |
|:---|:---|:---|
| ICON AND TEXT | correct | correct |
| ICON | 77 px hole between wifi and the glyph | cluster shortens, stays flush right |
| NO | ~120 px of dead space to the right margin | cluster shortens, stays flush right |
| no battery in the device | same as NO | same as NO |

## Not refreshed here

The shipped reference screenshots (`docs/screenshots/system-*.png`,
`gamelist-*.png`) still show the clock at its old `0.84` position, since
the status bar overlays every view. Regenerating that set belongs to #45
(README showcase), which owns those images and wants them taken with real
scraped assets.
