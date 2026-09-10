#!/usr/bin/env bash
# Structural guard for CREDITS.md — the licensing claims must match the tree.
#
# Going public turns CREDITS.md from an internal note into the repository's
# licence compliance record: CC-BY 4.0 obliges us to attribute the RetroArch
# icons we shipped, and "we shipped 134 of them" is a false statement of fact
# once the number is 150. That drift is what this guards.
#
# It had already happened four separate ways by the v1.0 audit (#47): CREDITS
# said 134 RA icons when the manifest mapped 150; README said "~56 icons from
# the previous XMB Menu ES-DE set" when 13 were distinct upstream icons and 30
# were copies of _default.png; the authenticity audit said 198 icons when 201
# shipped; and the "Not yet used" section still listed art/system-media/ after
# #41 wired all seven glyphs into the gamelist. None of it is visible in a
# render, none of it breaks a test, and every one of those numbers is prose
# somebody has to remember to update.
#
# The related failure this is descended from is worse than a wrong count: PR #22
# was rolled back because the shipped TSV header still named RetroArch's
# `automatic` set while the icons came from `monochrome` — an attribution
# pointing at the wrong upstream work. So the set name is asserted too.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

echo "CREDITS.md accounts for everything the repository ships:"

python3 - "${REPO_ROOT}" <<'PY'
import os, re, sys, hashlib, glob
root = sys.argv[1]
problems = []

def read(p):
    return open(os.path.join(root, p), encoding='utf-8').read()

credits = read('CREDITS.md')
icon_dir = os.path.join(root, 'art/system-icons')

# --- re-derive the icon accounting from the tree, not from the prose ---
icons = sorted(f[:-4] for f in os.listdir(icon_dir) if f.endswith('.png'))
total = len(icons)

mapped = set()
for line in read('scripts/ra-mapping.tsv').splitlines():
    if not line.strip() or line.lstrip().startswith('#'):
        continue
    mapped.add(line.split('\t')[0].strip())

# Tier 1 is hardware systems, tier 2 utility/auto-collection/media graphics.
# The tier a row falls in is positional, so count by walking the file in order.
tier, tiers = None, {1: 0, 2: 0}
for line in read('scripts/ra-mapping.tsv').splitlines():
    m = re.match(r'#\s*---\s*Tier\s*(\d+)', line)
    if m:
        tier = int(m.group(1))
        continue
    if line.strip() and not line.lstrip().startswith('#') and tier:
        tiers[tier] = tiers.get(tier, 0) + 1

port = set(re.findall(r'^\s*"([a-z0-9.+-]+)":', read('scripts/gen-port-icons.py'), re.M))

def digest(name):
    with open(os.path.join(icon_dir, f'{name}.png'), 'rb') as fh:
        return hashlib.sha256(fh.read()).hexdigest()

default_digest = digest('_default')
rest = [i for i in icons if i not in mapped and i not in port]
placeholder = [i for i in rest if digest(i) == default_digest]
inherited = [i for i in rest if digest(i) != default_digest]

derived = {
    'total': total,
    'ra': len(mapped),
    'ra_tier1': tiers.get(1, 0),
    'ra_tier2': tiers.get(2, 0),
    'inherited': len(inherited),
    'placeholder': len(placeholder),
    'port': len(port & set(icons)),
}

# Every icon must land in exactly one bucket, or the accounting is not an
# accounting — it is four numbers that happen to sum correctly.
buckets = derived['ra'] + derived['inherited'] + derived['placeholder'] + derived['port']
if buckets != total:
    problems.append(
        f"{total} icons ship but the buckets accounted for {buckets} "
        f"(RA {derived['ra']}, inherited {derived['inherited']}, "
        f"placeholder {derived['placeholder']}, port {derived['port']})")
if derived['ra_tier1'] + derived['ra_tier2'] != derived['ra']:
    problems.append(
        f"ra-mapping.tsv has {derived['ra']} rows but its tiers hold "
        f"{derived['ra_tier1']} + {derived['ra_tier2']}")

# --- the numbers CREDITS.md states must be those numbers ---
table = re.search(r'## Icon accounting\n(.*?)\n## ', credits, re.S)
if not table:
    problems.append("CREDITS.md has no '## Icon accounting' section")
else:
    body = table.group(1)

    # Each count must be bound to the row that DESCRIBES it, not merely present
    # in the table. Comparing the two as sets passes just as happily when the
    # counts are attached to the wrong origins -- which would have CREDITS.md
    # crediting RetroArch with 13 of the 201 icons and the CC-BY-NC-SA chain
    # with 150. That is the false-attribution failure PR #22 was rolled back
    # for, restated as a licence claim rather than a set name.
    # Ordered most specific first, and matched first-wins: the placeholder row
    # legitimately names its upstream too ("_default.png, inherited from XMB
    # Menu ES-DE"), so `_default.png` has to be decided before the generic
    # inherited pattern. Binding is preserved by the two checks below -- no
    # two rows may claim the same origin, and every origin needs a row.
    ROWS = [
        ('placeholder', r'_default\.png',                'the _default.png placeholders'),
        ('port',        r'[Hh]and-authored port icons',  'the hand-authored port icons'),
        ('ra',          r'RetroArch',                    'the RetroArch import'),
        ('inherited',   r'inherited from XMB Menu ES-DE','icons inherited from XMB Menu ES-DE'),
    ]
    rows = re.findall(r'^\|\s*\*?\*?([\d,]+)\*?\*?\s*\|(.*)$', body, re.M)
    seen_keys = set()
    for count, rest in rows:
        count = int(count.replace(',', ''))
        key = next((k for k, pat, _ in ROWS if re.search(pat, rest)), None)
        if key is None:
            # The totals row describes no origin; it must state the total.
            if count != derived['total']:
                problems.append(
                    f"CREDITS.md accounting row '{count}' names no origin and is "
                    f"not the total ({derived['total']})")
            continue
        if key in seen_keys:
            problems.append(
                f"CREDITS.md accounting has two rows for {key} -- each origin "
                f"is counted once or the total is meaningless")
            continue
        seen_keys.add(key)
        if count != derived[key]:
            label = next(l for k, _, l in ROWS if k == key)
            problems.append(
                f"CREDITS.md credits {count} icons to {label}; the tree has "
                f"{derived[key]}")

    for key, _, label in ROWS:
        if key not in seen_keys:
            problems.append(f"CREDITS.md accounting has no row for {label}")

    if not any(int(c.replace(',', '')) == derived['total'] for c, _ in rows):
        problems.append(f"CREDITS.md accounting does not state the total, {total}")

    # The RA row must also carry the tier split, and carry it on that row --
    # it is the CC-BY 4.0 attribution, the one an outside party may check.
    ra_row = next((rest for c, rest in rows
                   if int(c.replace(',', '')) == derived['ra'] and 'RetroArch' in rest), '')
    for n in (derived['ra_tier1'], derived['ra_tier2']):
        if not re.search(rf'\b{n}\b', ra_row):
            problems.append(
                f"CREDITS.md's RetroArch row does not state the tier split value {n}")

# --- every icon count stated in the public docs must be one of ours ---
#
# An allowlist, not a denylist of known-bad numbers: a count nobody recognises
# is exactly the thing that ships wrong. Matching is narrow on purpose --
# "shortnames" and "carries N icons" are this accounting's own vocabulary, so
# unrelated counts ("7 media icons", "16 button glyphs") never reach here.
allowed = set(derived.values())
COUNT_PHRASES = (
    r'(~?\d+)\s+(?:mapped\s+)?(?:system\s+)?shortnames',
    r'carries\s+(~?\d+)\s+icons',
    r'(~?\d+)\s+RetroArch',
)
for doc in ('README.md', 'CREDITS.md', 'CHANGELOG.md',
            'docs/psp-authenticity-audit.md', 'docs/psp-xmb-style-guidelines.md'):
    text = read(doc)
    for pattern in COUNT_PHRASES:
        for hit in re.findall(pattern, text):
            if hit.startswith('~'):
                problems.append(
                    f"{doc}: icon count {hit!r} is approximate -- these are countable")
            elif int(hit) not in allowed:
                problems.append(
                    f"{doc}: states {hit} where the tree gives {sorted(allowed)}")

# --- every art/ directory is named somewhere in CREDITS.md ---
#
# The FULL path, not the basename. Short directory names ("ui", "help", "wave")
# occur all over ordinary prose, so a basename test passes on a CREDITS.md that
# has lost the row entirely -- deleting every art/ui/ line left this silent.
for entry in sorted(os.listdir(os.path.join(root, 'art'))):
    path = f'art/{entry}'
    if os.path.isdir(os.path.join(root, path)):
        path += '/'
    if path not in credits:
        problems.append(f"{path} ships but CREDITS.md never mentions it")

# --- the attribution names the set the icons actually came from ---
if 'monochrome' not in credits:
    problems.append("CREDITS.md never names the RetroArch `monochrome` set")
if re.search(r'RetroArch[^.\n]*\bautomatic\b', credits):
    problems.append("CREDITS.md attributes RetroArch's `automatic` set — the icons are `monochrome` (see PR #22)")
if 'CC-BY 4.0' not in credits:
    problems.append("CREDITS.md does not state the RetroArch icons' CC-BY 4.0 licence")

if problems:
    print("\n".join("      " + p for p in problems))
    sys.exit(1)
print(f"      {total} icons: {derived['ra']} RA "
      f"({derived['ra_tier1']}+{derived['ra_tier2']}), "
      f"{derived['inherited']} inherited, {derived['placeholder']} placeholder, "
      f"{derived['port']} port")
PY
rc=$?
check "the icon accounting in CREDITS.md matches the shipped tree" "${rc}"

# The licence the repo ships under must be the one CREDITS.md claims, because
# ShareAlike inherits it from the parent theme — it is not a free choice, and a
# LICENSE swapped for a permissive one would be a licence violation, not a typo.
grep -q "Attribution-NonCommercial-ShareAlike 2.0" "${REPO_ROOT}/LICENSE"
rc=$?
check "LICENSE is CC-BY-NC-SA 2.0, as the licence chain requires" "${rc}"

grep -q "CC-BY-NC-SA 2.0" "${REPO_ROOT}/CREDITS.md"
rc=$?
check "CREDITS.md states the same licence the repository ships" "${rc}"

# fonts/ is redistributed under its own licence; the OFL requires the text to
# travel with the fonts.
[[ -f "${REPO_ROOT}/fonts/OFL.txt" ]]
rc=$?
check "fonts/OFL.txt ships alongside the fonts it licenses" "${rc}"

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
