# Changelog

Notable changes per release. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

**On tags:** releases through v0.9.2 are tagged. v0.10, v0.11 and v0.12 shipped
as code but were never tagged — the entries below reconstruct them from the
merge commits, and the commit each one ended at is given so the boundary is
recoverable. Tagging them retroactively, and tagging v1.0 when the milestone
closes, is tracked in issue #47.

## [Unreleased] — v0.13, working toward v1.0

Everything merged since v0.12 (`60ec465`, 2026-09-08). The v1.0 milestone is
the public-release gate; closing it is the go/no-go.

### Added
- Themed boot splash, tracking the user's colorset (#10).
- Status bar: clock, network glyph, battery glyph and percentage as one
  right-anchored cluster that re-packs around whatever is showing. Battery is
  driven by ES's own *Show Battery Status* setting, not a theme knob (#4).
- Three selectable face-button glyph sets — Nintendo (default), PSP, Xbox (#8).
- Navigation sounds that ES actually asks for, on both the carousel and the
  gamelist axes (#21).
- **Scroll Speed** knob for the auto-scrolling description (#38).
- Video support in the render harness, plus audio capture and analysis
  (#40, #21).
- README showcase: real screenshots, style comparisons and a navigation GIF
  (#45).

### Changed
- Box Art Grid: selection zoom no longer clips against the grid's own render
  clip or overlaps its neighbours, and the info bar wraps its text (#43).
- Body text legibility pass (#42).
- Media slots collapsed onto ES's own `md_video`, so the still and the video
  share one rectangle instead of leaking edges past each other (#41).
- Grouped systems get the right caption and icon; `atari8bit` gains both (#39).

### Removed
- The selected-icon halo, along with its asset, variables and generator.
  Measured rather than re-tuned: the glow lit the icon from inside, through
  the gaps in its silhouette, and the selected icon is already pure white.
  Geometric, not a brightness setting (#34).
- The horizontal "swoosh" — built, deployed to hardware, and rejected by ear
  as out of place. Both axes share one tick (#21).

### Fixed
- The wave's crest no longer stair-steps. The layer art drew its white rim with
  a binary test, so the grey/white transition held exactly two values and the
  rim snapped to whole pixel rows — pronounced on an edge this close to
  horizontal. The rim edge is now anti-aliased.
- The wave no longer duplicates its layers in the card and list styles; the
  grid's copy is load-bearing and stays. Its restart on view change is an
  accepted limitation (#44).

### Maintenance (v1.0 audit)
- `scripts/gen-wave-layers.py` reconstructs the wave layers. The original
  generator was never committed despite the README claiming otherwise, so the
  wave's maths was unrecoverable from the tree; the parameters were recovered by
  FFT from the committed art and match it to 0.53px. Excluded from the release
  archive by the existing `scripts/` rule, and guarded by `test-wave-layers.sh`
  so the art and its generator cannot drift apart the way they did before.
- Theme payload 9.0 MB → 2.9 MB: `art/wave/wave.gif` and `wave.mp4` were the
  *rejected* wave approaches and were referenced by nothing.
- `.gitattributes` bounds `git archive` — and so GitHub's release tarballs —
  to the theme, not the development tree.
- Media-fallback: 75 per-system include lines and files → 6, one per glyph.
- One shared, hardened `check()` across the test suites; a `run-all.sh` runner
  with whole-tree gates for XML well-formedness, dead and undeclared theme
  variables, and doc `file:line` citations.
- Device SSH transport built once, fixing `deploy.sh`'s ssh and scp silently
  omitting `StrictHostKeyChecking=accept-new`.
- Five theme variables deleted that nothing had consumed since v0.6/511f750.

### Licensing and go-public readiness (#47)
- `CREDITS.md` re-audited against the tree and rebuilt. Every directory under
  `art/` is now accounted for — the table previously listed only inherited
  assets, omitting the five directories of this port's own work, and still
  filed `art/system-media/` under "Not yet used" after #41 wired all seven
  glyphs into the gamelist.
- Corrected the RetroArch attribution: 150 icons, not 134. The manifest has
  mapped 150 since 6614f3b, so the figure was wrong in all seven places four
  documents repeated it — and CC-BY 4.0 makes an inaccurate count a false
  attribution rather than a typo.
- Documented the licence chain, including *why* CC-BY-NC-SA 2.0 is not a
  choice: ShareAlike inherits it from the parent theme, and the NonCommercial
  term is what blocks inclusion in commercial distro images.
- Scrubbed a real LAN address that had reached three files with the
  battery-widget screenshots.
- New `no-secrets` whole-tree gate (credential shapes, non-example private
  IPs, absolute home paths) and `test-credits-accounting.sh`, which re-derives
  the icon counts from the tree and rejects any figure in the public docs that
  is not one of them.
- `CONTRIBUTING.md` and GitHub issue templates.

## [v0.12] — 2026-09-08 (`60ec465`, untagged)

### Added
- **Three selectable gamelist styles** behind a `gamelistStyle` subset: PSP
  Card (default), List + Details, and Box Art Grid.
- Friendly captions for ES's auto-collections, which had been rendering as
  `AUTO-ALLGAMES` / `AUTO-FAVORITES` / `AUTO-LASTPLAYED` (#37).

### Changed
- PSP Card recomposed: screenshot above the title, bounded description, three
  fixed metadata columns. Fixed columns are what stops a long genre wrapping
  and pushing the star rating onto a second line.

### Notes
- Box Art Grid requires *UI Settings → Gamelist View Style = Automatic*. The
  theme registers `detailed,gamecarousel` unconditionally, so a pinned view
  style wins over the theme's `defaultView`.

## [v0.11] — 2026-07-30 (`6672299`, untagged)

### Added
- Monochrome system icons adopted from the RetroArch `monochrome` XMB set:
  150 shortnames plus 8 hand-authored port icons, with pre-burned drop
  shadows (#27).
- Per-system media fallback glyphs for unscraped games.
- `iconSize`, `titleVisibility` and `videoDelay` subsets.

### Changed
- Gamelist redesigned as a single PSP-card row list; the right info panel and
  the `<gamecarousel>` component were removed (#32).

### Fixed
- Aspect includes now load *after* the mode subsets, so per-ratio corrections
  beat per-mode defaults. Before this, `icon-size-*.xml` silently clobbered
  every per-ratio card override — theme variables resolve at element-parse
  time, so the last write wins.

## [v0.10] — 2026-05-26 (`6c78661`, untagged)

### Changed
- `horizontalAlignment` → `alignment`, clearing ~80 parse warnings.

### Removed
- The battery widget and the system halo, both pulled back out of the release
  to be revisited individually (they became #4 and #34).

## [v0.9.2] — 2026-05-24
Halo and screenshot refresh.

## [v0.9.1] — 2026-05-24
Halo and status-bar polish.

## [v0.9] — 2026-05-24
XMB authenticity pass.

## [v0.8.2] — 2026-05-23
Constant carousel gap-to-icon ratio across aspect ratios.

## [v0.8.1] — 2026-05-23
Carousel tuning and refreshed screenshots.

## [v0.8] — 2026-05-23
Multi-aspect-ratio support: 4:3, 16:9, 3:2, 1:1 and 8:7.

## [v0.7] — 2026-05-22
Gamelist and menu refinement.

## [v0.6] — 2026-05-21
Gamecarousel view.

## [v0.5] — 2026-05-20
XMB cross layout.

## [v0.4] — 2026-05-20
Carousel game count and icons; README banner and customization docs.

## [v0.3] — 2026-05-20
Always-on PSP XMB wave animation; the motion subset was dropped.

## [v0.2] — 2026-05-20
First shaped release: gamelist `md_logo` renamed to `logo`.
