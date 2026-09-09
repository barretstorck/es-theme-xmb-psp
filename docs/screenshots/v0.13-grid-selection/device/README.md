# Box Art Grid #43 — verified on the TrimUI Brick

Captured on the real device (Knulli / Batocera 42, `trimui-brick`, 1024x768,
April Green colorset) rather than the Docker harness. `main` was deployed
first, captured, then this branch, so the comparison isolates #43 from the
other PRs the device had not yet seen.

## Screenshots on this device ARE possible

Earlier notes on this project concluded that device pixel capture was
impossible because `fbgrab /dev/fb0` returned a stale buffer showing an
unrelated theme. **That was wrong**, and the correction matters for every
future device check:

* Knulli ships `/usr/bin/knulli-screenshot`, which is `fbgrab` driven by the
  geometry `fbset` reports — crucially including `-l <width>` for the stride.
  Called that way it captures ES's live output faithfully; the clock in the
  frame matches `date` on the device.
* The "unrelated pale theme" in the earlier attempt was not a stale buffer. It
  was this theme, in the **April Green** colorset, which no harness render had
  used. `ThemeColorSet` in `es_settings.cfg` is the giveaway.

## Two traps worth keeping

**`es_settings.cfg` is written by ES on exit.** Editing it while ES runs is
pointless — a clean `S31emulationstation stop` sends SIGTERM and ES overwrites
the file from memory. The order has to be stop, then edit, then start. The
device had had `ThemeSet` edited under a running ES 21 hours earlier and the
edit had simply never taken effect.

**This Brick has `InvertButtons=true`.** `scripts/ui.sh a` is ES's SELECT and
`b` is BACK, so `a` **launches the highlighted game** from inside a gamelist —
which is exactly what happened while capturing these (Balatro; recovered with
a plain `kill -TERM` on the `love.aarch64` pid). The on-screen help strip is
authoritative and should be read before injecting anything: the carousel
offers `Ⓐ SELECT` / `Ⓑ NAVIGATION BAR`, a gamelist offers `Ⓑ BACK`. Inside a
gamelist, restrict injection to the d-pad.

## Measurements

| | before (main) | after (branch) | theme declares |
|---|---|---|---|
| info-bar band | `0.8229 – 0.8776` (h `0.0547`) | `0.7956 – 0.9049` (h `0.1094`) | `0.795 – 0.905` (h `0.110`) |
| selected-tile growth, square art | `1.050` | `1.190` | `1.20` |
| selected art top vs grid clip edge | `+0.0002` — flush, i.e. clipped | `+0.0012`, and symmetric about the cell centre (`0.3001` vs `0.3020`) | — |

The before figures are **identical to the harness**, which is the useful
result: the harness reproduced the hardware bug exactly, so its measurements
can be trusted for this style.

`1.050` against a declared `1.14` is the clipping — roughly 15px shaved off the
top of the selected tile. After the fix the enlarged tile is exactly tangent to
the grown grid rect by construction (padding equals the overhang), and measures
symmetric about its cell centre, so nothing is lost.

16:9 art never reproduces the clipping: `maxSize` fits it by width, so it never
fills the cell vertically. Only square or portrait covers show it. That is the
same box-versus-art distinction that hid the v0.12 neighbour overlap.
