# v0.11 redesign-v2 implementation notes (approved mockup: v6)

**Approved mockup:** `proposed-v6-bigger-uniform-spacing.png`. Implement the gamelist to match it.

## Target layout (4:3 1024×768 reference)

| Element | Position (screen) | Size | Notes |
|---|---|---|---|
| System icon | center (0.24, 0.14) | carousel-selected size = `sysCarouselLogoW × logoScale` = 0.10 × 1.5 = **0.15** (width-capped; square icon ≈ 154 px) | Moved up from 0.18 |
| Caption "NES" | center (0.24, 0.25) | font ~0.029 | Tight below icon |
| Row centers | Y = 0.37, 0.59, 0.81 | — | Spacing 0.22; system-to-first gap (~0.23) matches inter-row spacing |
| Selected boxart | center (0.24, 0.59) | **240 px** (~0.234 × 0.31) | Overflows its slot — see spike |
| Selected title | right of boxart, above line | font ~0.075 (58 px) | |
| Selected line | (text_x, 0.59) → (0.97, 0.59) | 2 px | Bisects boxart vertically |
| Selected metadata | below line, left | `{game:genre} · {game:stars}` | |
| Selected description | below line, right of metadata | `{game:desc}`, `<autoScrollSpeed>200</autoScrollSpeed>` | Marquee |
| Peek boxart (prev/next) | center (0.24, 0.37 / 0.81) | **65 px** (~0.063 × 0.085) | |
| Peek title (Friendly only) | right of peek boxart | small dim font | Strict: hidden |

Selected-to-peek boxart ratio ≈ 3.7×.

## Spike FIRST — does an itemTemplate child render outside its slot bounds?

The selected boxart (240 px) is larger than the slot height (textlist 0.59 tall ÷ 3 lines ≈ 0.197 = 151 px). It must overflow the slot by ~45 px each way.

**Spike:** in the itemTemplate, set a test `<image>` `<size>` taller than the slot (e.g. `<size>0.234 1.6</size>` — 1.6 × slot height). Render. Read the PNG.
- If the image renders at full size, overflowing into neighbouring slots → **Path A (overflow)** works.
- If the image is clipped to the slot's top/bottom edges → use **Path B (pinned cursor + extras)**.

### Path A — overflow (preferred if it works)

Paired-element opacity swap inside the itemTemplate:
- `tplIconSmall`: 65 px, `<opacity>1</opacity>` default, activate→0.
- `tplIconBig`: 240 px (overflowing), `<opacity>0</opacity>` default, activate→1.
- `tplTitle`, `tplLine`, `tplMetadata`, `tplDesc`: `<opacity>0</opacity>` default, activate→1 (selected only).
- `tplPeekTitle` (Friendly only): `<opacity>${titleUnselectedOpacity}</opacity>`, deactivate keeps it; on activate fades to 0 (the big title replaces it).

### Path B — pinned cursor + extras (fallback)

- Set the textlist to pin the selected row at slot 1 (middle). Find the ES property (`<selectorOffsetY>` or equivalent) that fixes the cursor's screen position. Spike this too.
- itemTemplate renders ONLY the small peek icon + (Friendly) small title for every row.
- The big selected content (boxart, title, line, metadata, desc) are `extra="true"` elements at the fixed slot-1 screen position (0.24, 0.59), binding `{game:thumbnail}` / `{game:name}` / etc. — they rebind on cursor change (proven with the round-4 video element).
- On the selected (middle) row, the small peek icon is covered by the big extra boxart — acceptable (big is opaque and larger).

## Carry-over from prior rounds (keep working)

- System halo: stays DISABLED (commented out). Don't re-enable.
- Video: single `<video>` element tracking selection (keep round-4's approach; if Path B, the video becomes an extra at the selected slot too). Audio-leak-on-hidden remains a known on-device issue — don't regress it, but don't need to solve it here.
- Subsets: Icon Size {Boxart, Compact} and Title Visibility {PSP-Faithful, With Titles} must still work. Scale all the above sizes per subset:
  - Boxart subset: selected boxart 0.234 (240 px), peek 0.063 (65 px).
  - Compact subset: selected boxart ~0.16 (165 px), peek ~0.045 (46 px). Tune to taste but keep the dominance ratio.
  - Title Visibility controls only the PEEK title (selected always shows its title).
- Metadata text: `{game:genre} · {game:stars}` (no lastplayed — epoch leak).
- All text `${textPrimary}` / `${textSecondary}` (no black).

## Verification

Render `--view gamelist` at 4:3 January Blue and **Read the PNG**, compare against `proposed-v6-bigger-uniform-spacing.png`. The layout should match: big selected boxart, two small peeks, uniform spacing, system icon up top. Then render the subset matrix (Boxart/Compact × Strict/Friendly) and Read each. On-device verification for video + marquee.
