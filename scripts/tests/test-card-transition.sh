#!/usr/bin/env bash
# Structural test for the PSP Card scroll transition.
#
# Everything here fails SILENTLY on device if it regresses. ES logs nothing
# when a storyboard names an event no call site raises, nothing when a
# ${variable} fails to resolve (it becomes the empty string, and toFloat("")
# is 0 — so a typo'd shift is a transition that travels nowhere), and nothing
# when a theme property lands on no element. Hence structural guards; the
# pixel behaviour is verified separately by a render.
#
# NOTE: deliberately NOT `set -e` — every failure must be reported, not just
# the first.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

CARD="${REPO_ROOT}/_inc/gamelist-card.xml"
COMMON="${REPO_ROOT}/_inc/common.xml"
BOXART="${REPO_ROOT}/_inc/icon-size-boxart.xml"
COMPACT="${REPO_ROOT}/_inc/icon-size-compact.xml"
ANIMATED=(cardBoxart cardFallback)

# Print one named <image> element's block. The close has to be a line that is
# ONLY a closing tag, so a nested property tag cannot end the block early.
image_block() { # image_block <file> <element-name>
  awk -v want="name=\"$2\"" '
    !inblk && index($0, want) && /<image/ {
      inblk = 1; print
      if ($0 ~ /<\/image>/) inblk = 0
      next
    }
    inblk { print; if ($0 ~ /^[[:space:]]*<\/image>[[:space:]]*$/) inblk = 0 }
  ' "$1"
}

# Strip comments before matching, so a guard can never be satisfied by prose.
# This is the failure that let a live <image> through the first no-halo guard.
uncommented() { # uncommented <file>
  python3 - "$1" <<'PY'
import re, sys
print(re.sub(r'<!--.*?-->', '', open(sys.argv[1], encoding='utf-8').read(), flags=re.S))
PY
}

# Print one <storyboard event="..."> block's animation lines, from an
# already-extracted, already-uncommented element body on stdin. Scoped to a
# SINGLE element and a SINGLE event, so a property moved between events or
# between elements (while an element-wide or file-wide total stays the same)
# cannot hide from the count below. Empty output is a legitimate result: it
# means this element has no such event block, and callers must treat that as
# a failure, never as "nothing to check".
event_block() { # event_block <event-name>   (body on stdin)
  awk -v want="event=\"$1\"" '
    !inblk && index($0, want) && /<storyboard/ { inblk = 1; next }
    inblk && /<\/storyboard>/ { inblk = 0; next }
    inblk { print }
  '
}

echo "both media elements carry all four direction-aware events:"

for el in "${ANIMATED[@]}"; do
  # Via a temp file, NOT by interpolating the block into a Python string:
  # the XML contains quotes of every kind and would break the literal.
  tmp="$(mktemp)"
  image_block "${CARD}" "${el}" > "${tmp}"
  body="$(uncommented "${tmp}")"
  rm -f "${tmp}"
  for ev in deactivateNext deactivatePrev activateNext activatePrev; do
    grep -q "<storyboard event=\"${ev}\">" <<<"${body}"
    rc=$?
    check "${el} declares event=\"${ev}\"" "${rc}"
  done

  # The direction-blind fallback. handleStoryBoard reaches plain
  # activate/deactivate only when no direction variant exists; declaring one
  # here would silently take over and travel the wrong way half the time.
  ! grep -qE '<storyboard event="(activate|deactivate)">' <<<"${body}"
  rc=$?
  check "${el} declares no direction-blind activate/deactivate" "${rc}"

  # scaleOrigin defaults to the element centre, which is what the design
  # needs. An override is always a mistake here.
  ! grep -q '<scaleOrigin>' <<<"${body}"
  rc=$?
  check "${el} does not override scaleOrigin" "${rc}"

  # Guard the PROPERTIES, not the word "storyboard" -- and guard them PER
  # EVENT, not as an element-wide total. A total of 4 across the element's
  # four storyboards is satisfied just as well by 1+1+1+1 as by 2+0+1+1, so a
  # property moved out of one event and duplicated into another leaves the
  # total unchanged while one event silently animates nothing.
  for ev in deactivateNext deactivatePrev activateNext activatePrev; do
    ev_block="$(event_block "${ev}" <<<"${body}")"
    for prop in offsetY scale opacity; do
      grep -q "property=\"${prop}\"" <<<"${ev_block}"
      rc=$?
      check "${el} ${ev} animates ${prop}" "${rc}"
    done
  done
done

echo
echo "the travel is one slot, in the right direction:"

# Next = cursor moved down the list, so the outgoing card leaves UPWARD.
# Getting a sign wrong is invisible to every other guard and produces a
# transition that travels into the slot it came from.
card_body="$(uncommented "${CARD}")"

grep -q 'event="deactivateNext">' <<<"${card_body}"
rc=$?
check "deactivateNext exists to check signs against" "${rc}"

# Per element AND per event -- never "does some block, somewhere, agree".
# Filtering a list of blocks down to "the ones that have offsetY" and then
# checking `all()` over what's left makes a MISSING offsetY block vanish
# from the sample instead of failing it: with cardBoxart's offsetY silently
# dropped, cardFallback's intact block alone satisfied `all(...)`. Here each
# element/event pair is graded on its own: the offsetY animation must be
# PRESENT in that exact block, and it must carry the right from/to. A block
# with no offsetY at all is a hard failure, never a skip.
declare -A WANT_OFFSETY=(
  [deactivateNext]='to="-${cardPeekShift}"'
  [deactivatePrev]='to="${cardPeekShift}"'
  [activateNext]='from="${cardPeekShift}"'
  [activatePrev]='from="-${cardPeekShift}"'
)

# scale and opacity get the same per-element/per-event treatment as offsetY,
# for the same reason: a total across the element hides a value moved between
# events. Demonstrated escapes that the presence-only check above (property=
# "scale"/"opacity" appears SOMEWHERE in the block) let through clean:
#   - a scale animation's `to` flattened to "0"
#   - the incoming (activateNext/activatePrev) opacity ramp inverted to
#     from="1" to="0", fading the selected box art to invisible on every
#     cursor move
# Both left the suite at a clean pass count. An event block missing the
# animation entirely must FAIL here too, never silently skip -- same
# `[[ -n ... ]] &&` guard as offsetY.
declare -A WANT_SCALE=(
  [deactivateNext]='from="1" to="${cardPeekScale}"'
  [deactivatePrev]='from="1" to="${cardPeekScale}"'
  [activateNext]='from="${cardPeekScale}" to="1"'
  [activatePrev]='from="${cardPeekScale}" to="1"'
)
declare -A WANT_OPACITY=(
  [deactivateNext]='from="1" to="0"'
  [deactivatePrev]='from="1" to="0"'
  [activateNext]='from="0" to="1"'
  [activatePrev]='from="0" to="1"'
)

for el in "${ANIMATED[@]}"; do
  tmp="$(mktemp)"
  image_block "${CARD}" "${el}" > "${tmp}"
  body="$(uncommented "${tmp}")"
  rm -f "${tmp}"

  for ev in deactivateNext deactivatePrev activateNext activatePrev; do
    ev_block="$(event_block "${ev}" <<<"${body}")"

    want="${WANT_OFFSETY[${ev}]}"
    offsety_line="$(grep 'property="offsetY"' <<<"${ev_block}")"
    [[ -n "${offsety_line}" ]] && [[ "${offsety_line}" == *"${want}"* ]]
    rc=$?
    check "${el} ${ev} offsetY carries ${want}" "${rc}"

    scale_want="${WANT_SCALE[${ev}]}"
    scale_line="$(grep 'property="scale"' <<<"${ev_block}")"
    [[ -n "${scale_line}" ]] && [[ "${scale_line}" == *"${scale_want}"* ]]
    rc=$?
    check "${el} ${ev} scale carries ${scale_want}" "${rc}"

    opacity_want="${WANT_OPACITY[${ev}]}"
    opacity_line="$(grep 'property="opacity"' <<<"${ev_block}")"
    [[ -n "${opacity_line}" ]] && [[ "${opacity_line}" == *"${opacity_want}"* ]]
    rc=$?
    check "${el} ${ev} opacity carries ${opacity_want}" "${rc}"
  done
done

echo
echo "duration and easing survive a slow-motion capture-and-restore round trip:"

# The style guide's device-verification workflow tells an engineer to
# multiply every duration by 10x for slow-motion capture, then restore the
# originals by hand afterward. Nothing above catches a failure to restore:
# duration="1500" mode="linear" on any animation passed every guard above
# clean, because none of them look past from/to. Ship that and the
# transition is a 1.5-second crawl instead of 150ms.
declare -A WANT_OPACITY_TIMING=(
  [deactivateNext]='begin="30" duration="120"'
  [deactivatePrev]='begin="30" duration="120"'
  [activateNext]='begin="0" duration="110"'
  [activatePrev]='begin="0" duration="110"'
)

for el in "${ANIMATED[@]}"; do
  tmp="$(mktemp)"
  image_block "${CARD}" "${el}" > "${tmp}"
  body="$(uncommented "${tmp}")"
  rm -f "${tmp}"

  for ev in deactivateNext deactivatePrev activateNext activatePrev; do
    ev_block="$(event_block "${ev}" <<<"${body}")"

    offsety_line="$(grep 'property="offsetY"' <<<"${ev_block}")"
    [[ -n "${offsety_line}" ]] && [[ "${offsety_line}" == *'duration="150"'* ]] \
      && [[ "${offsety_line}" == *'mode="easeOut"'* ]]
    rc=$?
    check "${el} ${ev} offsetY carries duration=150 mode=easeOut" "${rc}"

    scale_line="$(grep 'property="scale"' <<<"${ev_block}")"
    [[ -n "${scale_line}" ]] && [[ "${scale_line}" == *'duration="150"'* ]] \
      && [[ "${scale_line}" == *'mode="easeOut"'* ]]
    rc=$?
    check "${el} ${ev} scale carries duration=150 mode=easeOut" "${rc}"

    opacity_want="${WANT_OPACITY_TIMING[${ev}]}"
    opacity_line="$(grep 'property="opacity"' <<<"${ev_block}")"
    [[ -n "${opacity_line}" ]] && [[ "${opacity_line}" == *"${opacity_want}"* ]]
    rc=$?
    check "${el} ${ev} opacity carries ${opacity_want}" "${rc}"
  done
done

echo
echo "the variables exist, in the right files, with the right values:"

# cardPeekShift is glListH / 3. Recomputed rather than compared to a literal,
# so the two cannot drift apart -- the #43 lesson.
python3 - "${COMMON}" <<'PY'
import re, sys
t = open(sys.argv[1], encoding='utf-8').read()
t = re.sub(r'<!--.*?-->', '', t, flags=re.S)
def val(name):
    m = re.search(r'<%s>([\d.]+)</%s>' % (name, name), t)
    return float(m.group(1)) if m else None
h, shift = val('glListH'), val('cardPeekShift')
if h is None or shift is None:
    print("glListH or cardPeekShift missing from common.xml"); sys.exit(1)
if abs(shift - h / 3) > 1e-9:
    print("cardPeekShift %s != glListH/3 %s" % (shift, h / 3)); sys.exit(1)
PY
rc=$?
check "cardPeekShift equals glListH / 3" "${rc}"

# A subset variable that fails to resolve does not just blank one property:
# ES drops sibling properties on the element (the buttonGlyphs failure found
# on hardware). Both subsets must carry it or one Icon Size setting breaks.
for f in "${BOXART}" "${COMPACT}"; do
  grep -q '<cardPeekScale>' "${f}"
  rc=$?
  check "$(basename "${f}") declares cardPeekScale" "${rc}"
done

# common.xml MUST carry it too, and must agree with Boxart. On the device no
# icon-size include applies until the user opens the setting, and then
# common.xml wins (test-body-legibility.sh:150). Without a value here
# ${cardPeekScale} resolves empty, toFloat("") is 0, and the card animates to
# nothing -- a device-only regression the harness cannot see.
grep -q '<cardPeekScale>' "${COMMON}"
rc=$?
check "common.xml declares the fresh-device cardPeekScale default" "${rc}"

python3 - "${COMMON}" "${BOXART}" <<'PY'
import re, sys
def val(p):
    t = re.sub(r'<!--.*?-->', '', open(p, encoding='utf-8').read(), flags=re.S)
    m = re.search(r'<cardPeekScale>([\d.]+)</cardPeekScale>', t)
    return float(m.group(1)) if m else None
c, b = val(sys.argv[1]), val(sys.argv[2])
if c is None or b is None:
    print("cardPeekScale missing from common.xml or icon-size-boxart.xml"); sys.exit(1)
if abs(c - b) > 1e-9:
    print("common.xml %s != icon-size-boxart.xml %s" % (c, b)); sys.exit(1)
PY
rc=$?
check "common.xml cardPeekScale equals icon-size-boxart.xml's" "${rc}"

# Each subset's value must sit inside ITS OWN bounds, recomputed from its own
# variables. A literal comparison would pass a value copied from the other file.
for f in "${BOXART}" "${COMPACT}"; do
  python3 - "${f}" "${COMMON}" <<'PY'
import re, sys
def load(p):
    t = re.sub(r'<!--.*?-->', '', open(p, encoding='utf-8').read(), flags=re.S)
    return {k: float(v) for k, v in re.findall(r'<(\w+)>([\d.]+)</\1>', t)}
sub, common = load(sys.argv[1]), load(sys.argv[2])
g = {**common, **sub}
need = ('peekIconW', 'cardBoxartW', 'peekIconH', 'cardBoxartH', 'glListH', 'cardPeekScale')
missing = [n for n in need if n not in g]
if missing:
    print("missing: " + ", ".join(missing)); sys.exit(1)
lo = g['peekIconW'] / g['cardBoxartW']                      # both width-limited
hi = (g['peekIconH'] * g['glListH'] / 3) / g['cardBoxartH']  # both height-limited
if not (min(lo, hi) - 1e-9 <= g['cardPeekScale'] <= max(lo, hi) + 1e-9):
    print("cardPeekScale %.4f outside [%.4f, %.4f] for %s"
          % (g['cardPeekScale'], min(lo, hi), max(lo, hi), sys.argv[1]))
    sys.exit(1)
PY
  rc=$?
  check "$(basename "${f}") cardPeekScale lies within its own peek/card bounds" "${rc}"
done

echo
echo "the transition is scoped to Style A:"

for other in gamelist-list gamelist-grid; do
  ! grep -qE 'event="(activate|deactivate)(Next|Prev)"' "${REPO_ROOT}/_inc/${other}.xml"
  rc=$?
  check "${other}.xml declares no direction-aware events" "${rc}"
done

! grep -l 'cardPeekScale\|cardPeekShift' "${REPO_ROOT}"/_inc/aspect-*.xml >/dev/null 2>&1
rc=$?
check "no aspect-*.xml overrides the transition variables" "${rc}"

echo
echo "docs describe the shipped behaviour:"

GUIDE="${REPO_ROOT}/docs/psp-xmb-style-guidelines.md"
grep -q 'deactivateNext' "${GUIDE}"
rc=$?
check "style guide names the direction-aware events" "${rc}"

grep -qi 'cardPeekScale' "${GUIDE}"
rc=$?
check "style guide documents cardPeekScale" "${rc}"

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
