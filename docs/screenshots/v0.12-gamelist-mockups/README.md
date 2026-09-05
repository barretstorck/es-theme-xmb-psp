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

---

# Round 2 — A revised, three styles selected

Chosen: **A**, **B** and **D**, exposed as a user-selectable subset.
**C** and **E** are dropped.

## A2 — revisions to the card layout

Feedback on round 1: the `GB` caption collided with the system icon, and a
screenshot should sit above the title and be replaced by a video after a delay.

| Mockup | What it shows |
|---|---|
| [`a2-media-centred-i-screenshot.png`](./a2-media-centred-i-screenshot.png) | Media centred in the card's text column, above the title. Screenshot state. |
| [`a2-media-centred-ii-video-16x9.png`](./a2-media-centred-ii-video-16x9.png) | Same layout, video state, 16:9 source — shows how a wide clip fills the envelope that a 10:9 screenshot only partly fills. |
| [`a2-media-split.png`](./a2-media-split.png) | Alternative: media left on the card spine, `released / developer / publisher / players` stack filling the right. |

Both A2 variants fix the caption gap (system icon centre 0.110, caption centre
0.222) and shorten the description to a bounded 5 lines.

`a2-media-split` fills the upper right more completely but reintroduces a
metadata stack, which is closer to B than to a PSP card.

## Feasibility — resolved against the pinned Knulli ES source

Read from `/opt/es` in the render container (Knulli `9bbb16a`), not assumed:

- **A subset variant can select the view type.** `ThemeData::appendFile()` calls
  `parseTheme()` on every included file, and `parseTheme()` reads the root
  `defaultView` attribute (`ThemeData.cpp:1329`). `ViewController::getGameListView()`
  substitutes `getDefaultView()` whenever ES's own `GamelistViewStyle` is
  `automatic` (`ViewController.cpp:715-720`). So a variant file whose root is
  `<theme defaultView="grid">` switches the theme to the grid view.
  **Caveat:** if the user has explicitly set Gamelist View Style to a style the
  theme defines, the user's setting wins (`ViewController.cpp:697-698`).
- **`gridtile` is themeable** — `selectionMode`, `imageSizeMode`, `padding`,
  `backgroundImage`, `backgroundColor`, `reflexion` (`ThemeData.cpp:196-207`),
  and `imagegrid` accepts an `itemTemplate` (`ThemeData.cpp:30`). D is buildable.
- **Video aspect ratio is preserved by `<maxSize>`** — `VideoComponent.h:95`
  documents `setMaxSize()` as *"Never breaks the aspect ratio."* The v0.11
  `<size>` → `<maxSize>` change on `cardVideo` was correct; it has still never
  been verified on-device.
  **Limit:** this preserves the *video file's* aspect ratio, not the system's
  canonical one. A 4:3-padded ScreenScraper clip for a 10:9 Game Boy game will
  render with its padding intact; the theme cannot crop it.
