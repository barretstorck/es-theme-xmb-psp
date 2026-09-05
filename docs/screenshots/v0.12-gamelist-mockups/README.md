# v0.12 gamelist mockups — five candidates

**Status:** awaiting sign-off. No XML changes yet.

The v0.11 card gamelist shipped and was verified on-device, but two problems
remain in use:

1. **Text overflow / clipping** — `cardDesc` renders as a full vertical
   paragraph that runs under the help strip on-device, and a long genre
   ("Shooter / 1st person") wraps `cardMetadata` and pushes the stars onto a
   second line.
2. **Wasted space** — the upper-right quadrant and the left column below the
   card are empty. The layout does not feel composed the way the system view
   does.

Navigation was *not* raised as a problem: three visible rows is working in
practice, and the card-vs-cursor decoupling at the list edges has not bitten.

## The five candidates

All five are rendered in the theme's own visual language — real
`art/wave/*` background, `colors/psp-jan-blue.xml` palette, Roboto Condensed —
against the real KNULLI render library, so the comparison is about **layout
only**, not palette or art direction.

| | Mockup | Style | Keeps XMB? |
|---|---|---|:---:|
| **A** | [`a-xmb-card-recomposed.png`](./a-xmb-card-recomposed.png) | The shipped PSP card, retuned | yes |
| **B** | [`b-playstation-x.png`](./b-playstation-x.png) | `es-theme-PlayStation-X` (RANKING Tier 1 #2) | no |
| **C** | [`c-minimal-panels.png`](./c-minimal-panels.png) | `es-theme-minimal` (Tier 1 #10) | no |
| **D** | [`d-boxart-grid.png`](./d-boxart-grid.png) | `Meringue_Knulli` cover wall | no |
| **E** | [`e-fakexmb-style.png`](./e-fakexmb-style.png) | `FakeXMB` — the other XMB theme's own gamelist | no |

### A — recomposed card

Same three-row format, same `crossX` column, same selected-dominates idea.
Retuned geometry:

- card raised `cardY` 0.59 → 0.545 so the text block has room above the help strip;
- description promoted from a narrow marquee strip to a **bounded 7-line block**
  spanning the full text column (0.385 → 0.97), so it cannot reach `y=0.94`;
- metadata split onto two lines (`genre · stars · players`, then
  `year · developer`) so a long genre can no longer displace the stars;
- peek titles centred *beneath* their icons rather than beside them, which
  fills the left column and works in both Strict and Friendly;
- position counter (`2 / 10`) under the clock.

### B, C, E — list + metadata

All three abandon the card and put a full ~10-row title list on the left. This
is what `FakeXMB`, the only other XMB theme in the 211-theme corpus, does for
its own gamelist. It overturns two §10 settled decisions — "single PSP-card
gamelist, no right panel" and "three visible game rows".

### D — cover wall

No text list at all. Depends entirely on scrape coverage; degrades badly where
box art is missing.

## What these mockups hide

- **Motion.** No wave animation, no marquee scroll, no video preview.
- **Feasibility.** These are PIL compositions, not ES renders. Each candidate
  still needs its layout mechanism confirmed against this Knulli ES build
  before it can be costed — see the v0.11 spike notes for how badly that can
  bite (`TextListComponent` ignores `<centerSelection>`, which is why v0.11
  ended up on Path B).
- **Stars.** Drawn as polygons here; ES renders `{game:stars}` from its bundled
  fontawesome.

## Generator

`.dev/mockups/{common,gen}.py` (untracked — `.dev/` is gitignored). Rebuild with
`python3 .dev/mockups/gen.py`. Requires the render library at `/tmp/library`.
