# Credits

## Design lineage

- **PSP XMB (Cross Media Bar)** — Sony Computer Entertainment, 2004.
  Visual design inspiration only; no assets used.

## Theme lineage

- **XMB-Easy-Theme** — InitialDin. Original EmulationStation XML; the lineage starts here.
- **XMB Menu ES-DE** — Ant (anthonycaccese). ES-DE refactor with refreshed assets, color schemes, aspect-ratio support. CC-BY-NC-SA 2.0. https://github.com/anthonycaccese/xmb-menu-es-de
- **es-theme-xmb-psp** — Barret Storck. Port to batocera-emulationstation for Knulli Scarab / TrimUI Brick. CC-BY-NC-SA 2.0.

## Assets used in this port

| Asset | Source | Origin author / license |
|---|---|---|
| Wave background | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| System icons | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| UI chrome (selector, separators) | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| Sound effects | XMB Menu ES-DE | Ant — CC-BY-NC-SA 2.0 |
| Font: Saira Semi Condensed (Light/Regular/Bold) | [Google Fonts](https://fonts.google.com/specimen/Saira+Semi+Condensed) | Omnibus Type — SIL OFL 1.1 (see `fonts/OFL.txt`) |

**Font substitution:** the source theme uses *FOT-NewRodin Pro* (Fontworks), which is proprietary and not redistributable. This port substitutes [Saira Semi Condensed](https://fonts.google.com/specimen/Saira+Semi+Condensed) by Omnibus Type, a free, OFL-licensed condensed sans-serif with a similar visual feel.

## Not yet used (would re-add credit if included later)

- **Physical media icons** — RetroArch XMB monochrome theme contributors. (Not currently in any view.)
- **Controller icons** — RobZombie9043. (Not currently in any view.)

## Icon attribution (v0.4)

Most system icons in `art/system-icons/` are inherited from the parent
theme chain documented above (same CC-BY-NC-SA 2.0 license).

The following icons were additionally harvested in v0.4 from
[xmb-menu-es-de](https://github.com/anthonycaccese/xmb-menu-es-de) by
**anthonycaccese**, CC-BY-NC-SA 2.0, for systems that were previously
falling back to a generic placeholder:

amiga, astrocade, atarijaguar, atarijaguarcd, atarilynx, bbcmicro,
msx, odyssey2, pc, sg-1000, wonderswan, wonderswancolor

Systems without a hand-tuned or harvested icon use a generic `_default.png`
placeholder (which itself comes from the upstream parent-theme chain).
To override: drop a hand-tuned `<system-shortname>.png` into
`art/system-icons/`.
