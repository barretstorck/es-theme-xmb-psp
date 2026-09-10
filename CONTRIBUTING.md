# Contributing

Thanks for looking. This is a small, opinionated theme with one goal —
reproduce the PSP's XMB on EmulationStation — and most of what follows exists
because a specific mistake was made once already.

## The short version

```bash
git clone https://github.com/barretstorck/es-theme-xmb-psp
cd es-theme-xmb-psp
scripts/render.sh                 # screenshot the theme, headless, no device
scripts/tests/run-all.sh          # everything; takes seconds, needs no Docker
```

**You do not need a TrimUI Brick, or any handheld, to work on this.**
`scripts/render.sh` runs batocera-emulationstation headless in Docker and
screenshots the theme at any resolution. See [`docker/README.md`](docker/README.md).
The on-device scripts (`scripts/deploy.sh`, `scripts/ui.sh`) are a dormant
fallback, not the routine workflow.

Run `scripts/tests/run-all.sh` before you commit. It is fast, it has no
dependencies beyond `python3` and `bash`, and every gate in it is there because
something shipped broken.

## Design intent comes first

Read [`docs/psp-xmb-style-guidelines.md`](docs/psp-xmb-style-guidelines.md)
before changing anything visual. Where the theme knowingly departs from the real
XMB, and why, is in
[`docs/psp-authenticity-audit.md`](docs/psp-authenticity-audit.md).

"The PSP did it this way" wins arguments here. It is not the only valid
argument, but it is the strongest one available.

## Four things that will bite you

These are not style preferences. Each one has cost a debug cycle.

1. **An unresolved `${variable}` blanks the whole element.** EmulationStation
   does not fall back — if a `${var}` referenced by an element resolves to
   nothing, *every* icon and path property on that element is dropped. A
   variable that only exists under some subset selections is therefore a silent
   blanking bug. The `no-undeclared-variables` gate catches the common case.

2. **Include order in `theme.xml` is load-bearing, and it is not obvious.**
   ES processes children in document order and resolves `${variable}` at
   element-*parse* time, so properties merge last-write-wins. The order is
   `common.xml` -> colorset -> variable-only subsets (iconSize,
   titleVisibility, ...) -> `aspect-*.xml` -> the view files. Per-ratio
   corrections sit after the mode subsets so they beat them, and *before* the
   views so the views read resolved values. Moving an include is a behaviour
   change; the header comment in `theme.xml` explains each position and which
   bug it came from.

3. **Five aspect ratios, tuned by hand.** 4:3, 16:9, 3:2, 1:1, 8:7. Anything
   positional needs rendering at all five — `scripts/render-fixtures.sh` does
   the sweep. A value that looks right at 4:3 routinely overlaps at 1:1.

4. **Subsets multiply.** Gamelist Style x Icon Size x Title Visibility x
   Button Icons x Scroll Speed. `scripts/render.sh` takes environment pins
   (`ICON_SIZE=Compact`, `TITLE_VISIBILITY=...`) so you can capture a specific
   combination rather than only the defaults.

## Assets and licensing

The theme is **CC-BY-NC-SA 2.0**, inherited from its parent theme's ShareAlike
clause rather than chosen — see [`CREDITS.md`](CREDITS.md). By contributing you
agree your work ships under it.

If you add an asset, **add its provenance to `CREDITS.md` in the same commit.**
`scripts/tests/test-credits-accounting.sh` enforces the parts of this that can
be checked mechanically: every directory under `art/` must be accounted for, and
every icon count stated in the docs must match what the tree actually holds.
Counts drift silently — this is the one thing here that is genuinely automated
paranoia rather than advice.

Assets whose licence you cannot name will not be merged. That includes anything
extracted from Sony firmware: no ripped icon, font or sound may enter this
repository.

## Secrets

`.env.local` is gitignored and is where device addresses and passwords belong.
The `no-secrets` gate in `run-all.sh` scans every tracked file for credential
shapes, private IPs and absolute home paths. `192.168.1.4` is the one allowed
example address; if you need another, the gate is telling you to use
`.env.local`.

## Pull requests

Small and self-describing. Say what changed and why it was wrong before —
the commit log here is written to be read later, and it is frequently the only
record of why a value is what it is.

Include a render for anything visual. A claim that something looks right is not
verification; the screenshot is.
