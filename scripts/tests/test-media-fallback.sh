#!/usr/bin/env bash
# Structural guard for the media-fallback glyph mapping.
#
# The mapping went from 75 per-system files to six per-glyph ones, and the
# system lists that used to be implied by 75 filenames are now written down in
# two places: the `include if` conditions in theme.xml, and the header comment
# of each _inc/media-fallback/*.xml. Two copies of a list is exactly the shape
# that rots — so this asserts they agree, character for character.
#
# The failure this really guards is SILENT. ES evaluates `include if` through
# MathExpr and simply skips an include whose condition is false; a typo'd
# system name does not warn, it just leaves that system on the _default glyph.
# Nothing in a render says "this should have been the disc". Likewise a system
# listed under TWO glyphs quietly takes whichever include comes later.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

echo "the media-fallback mapping is internally consistent:"

python3 - "${REPO_ROOT}" <<'PY'
import os, re, sys, glob, collections
root = sys.argv[1]
theme = open(os.path.join(root, 'theme.xml'), encoding='utf-8').read()
problems = []

# theme.xml: every media-fallback include, with the systems its condition names.
includes = re.findall(
    r'<include(?:\s+if="([^"]*)")?\s*>(\./_inc/media-fallback/[\w-]+\.xml)</include>',
    theme, re.S)
if not includes:
    problems.append("theme.xml declares no media-fallback includes at all")

seen = {}
declared = {}
for cond, path in includes:
    fname = os.path.basename(path)
    full = os.path.join(root, path.lstrip('./'))
    if not os.path.exists(full):
        problems.append(f"theme.xml includes {path}, which does not exist")
        continue

    if fname == '_default.xml':
        if cond:
            problems.append("_default.xml must be included unconditionally")
        continue

    # Newlines inside an XML attribute normalise to spaces before MathExpr
    # sees them, so collapse whitespace the same way before parsing.
    flat = ' '.join(cond.split())
    terms = [t.strip() for t in flat.split('||')]
    systems = []
    for t in terms:
        m = re.fullmatch(r"\$\{system\.theme\} == '([\w.+-]+)'", t)
        if not m:
            problems.append(f"{fname}: unparseable condition term {t!r}")
        else:
            systems.append(m.group(1))
    declared[fname] = systems

    for s in systems:
        if s in seen:
            problems.append(
                f"system {s!r} is claimed by both {seen[s]} and {fname} — "
                "the later include silently wins")
        seen[s] = fname

# Each glyph file: the art it points at must exist, and its documented system
# list must match the condition theme.xml selects it with.
for f in sorted(glob.glob(os.path.join(root, '_inc/media-fallback/*.xml'))):
    fname = os.path.basename(f)
    text = open(f, encoding='utf-8').read()

    m = re.search(r'<mediaFallbackPath>\./(art/system-media/[\w-]+\.png)</mediaFallbackPath>', text)
    if not m:
        problems.append(f"{fname}: no <mediaFallbackPath> setting a system-media png")
        continue
    if not os.path.exists(os.path.join(root, m.group(1))):
        problems.append(f"{fname}: points at {m.group(1)}, which does not exist")

    if fname == '_default.xml':
        continue
    if fname not in declared:
        problems.append(f"{fname} exists but theme.xml never includes it")
        continue

    # The glyph filename and the art it sets should agree, or the file is
    # named after something it does not actually provide.
    stem = fname[:-4]
    if os.path.basename(m.group(1)) != f"{stem}.png":
        problems.append(f"{fname}: named for {stem} but sets {m.group(1)}")

    doc = re.search(r'Systems using this glyph \((\d+)\):\n(.*?)\n\n', text, re.S)
    if not doc:
        problems.append(f"{fname}: header has no 'Systems using this glyph (N):' list")
        continue
    listed = [s.strip() for s in doc.group(2).replace('\n', ' ').split(',') if s.strip()]
    if int(doc.group(1)) != len(listed):
        problems.append(f"{fname}: header says {doc.group(1)} systems, lists {len(listed)}")
    if sorted(listed) != sorted(declared[fname]):
        only_doc = sorted(set(listed) - set(declared[fname]))
        only_thm = sorted(set(declared[fname]) - set(listed))
        problems.append(
            f"{fname}: header list and theme.xml condition disagree — "
            f"only in header: {only_doc or 'none'}; only in theme.xml: {only_thm or 'none'}")

if problems:
    print("\n".join("      " + p for p in problems))
    sys.exit(1)
print(f"      {len(seen)} systems across {len(declared)} glyphs, plus _default")
PY
rc=$?
check "theme.xml conditions, glyph files and their documented lists all agree" "${rc}"

# The consolidation's whole premise is that these files hold one variable each.
# If one grows an element, it is no longer a shared mapping entry and the
# "editing this changes it for every system listed" contract quietly breaks.
extra="$(grep -lE '<(view|image|text|imagegrid|textlist|carousel)\b' \
         "${REPO_ROOT}"/_inc/media-fallback/*.xml 2>/dev/null || true)"
[[ -z "${extra}" ]]
rc=$?
check "no media-fallback file declares elements — they set one variable only" "${rc}"
[[ -n "${extra}" ]] && sed "s|^${REPO_ROOT}/|      offender: |" <<<"${extra}" >&2

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
