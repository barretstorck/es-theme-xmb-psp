<!--
Small and self-describing. See CONTRIBUTING.md — the commit log here is written
to be read later, and is frequently the only record of why a value is what it is.
-->

## What changed, and what was wrong before

<!-- The "before" half matters more than the "after" half. -->

## Renders

<!--
Required for anything visual. A claim that something looks right is not
verification; the screenshot is.

Anything positional needs all five ratios — 4:3, 16:9, 3:2, 1:1, 8:7.
`scripts/render-fixtures.sh` does the sweep.
-->

## Checklist

- [ ] `scripts/tests/run-all.sh` passes locally
- [ ] Renders attached above, if this changes anything visual
- [ ] Checked at all five aspect ratios, if this moves or resizes anything
- [ ] New assets have their provenance recorded in `CREDITS.md`, in this PR
- [ ] Nothing here is extracted from Sony firmware
