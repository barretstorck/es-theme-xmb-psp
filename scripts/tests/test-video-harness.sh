#!/usr/bin/env bash
# Structural smoke test for the video-capable harness (issue #40).
# Asserts the wiring a render cannot catch cheaply: image selection, the ES
# source patch, subset/settle/frame plumbing, and fixture video assets.
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fail=0
check() { # check <description> <condition-exit-code>
  if [[ "$2" -eq 0 ]]; then echo "  ok   - $1"; else echo "  FAIL - $1"; fail=1; fi
}

echo "the image:"

# One image does everything. A second one would mean every screenshot carries a
# "which image made this?" question.
[[ ! -e "${REPO_ROOT}/docker/Dockerfile.video" ]]
check "there is no second Dockerfile" $?

! grep -q 'WITH_VIDEO' "${REPO_ROOT}/docker/Dockerfile" "${REPO_ROOT}/scripts/render.sh"
check "no leftover WITH_VIDEO build-arg plumbing" $?

# vlc-plugin-base is the whole reason <video> was dead in the harness:
# libvlc-dev ships the library, not a single demuxer or decoder.
grep -q 'vlc-plugin-base' "${REPO_ROOT}/docker/Dockerfile"
check "Dockerfile installs vlc-plugin-base" $?

# The pin is what makes harness renders mean anything about the device.
grep -q 'ARG ES_PIN=9bbb16a' "${REPO_ROOT}/docker/Dockerfile"
check "Dockerfile builds ES pin 9bbb16a" $?

grep -q 'ES_PIN="9bbb16a"' "${REPO_ROOT}/scripts/render.sh"
check "render.sh agrees on the pin" $?

# render.sh builds only when the image is MISSING, so changing docker/ without
# bumping the tag leaves everyone on their first build forever.
grep -q 'HARNESS_REV="r2"' "${REPO_ROOT}/scripts/render.sh"
check "the image tag carries a harness revision" $?

grep -q 'IMAGE="es-xmb-harness:knulli-${ES_PIN}-${HARNESS_REV}"' "${REPO_ROOT}/scripts/render.sh"
check "the tag is built from pin + revision" $?

echo
echo "ES source patch:"

PATCH="${REPO_ROOT}/docker/patches/vlc-parse-no-block.patch"
[[ -f "${PATCH}" ]]
check "docker/patches/vlc-parse-no-block.patch exists" $?

grep -q 'VideoVlcComponent.cpp' "${PATCH}"
check "the patch targets VideoVlcComponent.cpp" $?

# The pinned build spins forever on libvlc_media_parsed_status_done; the patch
# has to leave on any terminal status, not just done.
grep -q 'libvlc_media_get_parsed_status(mMedia) == 0' "${PATCH}"
check "the patch waits only while the parse is still running" $?

# Unconditional: an unapplied patch means a harness that freezes on the first
# gamelist render, which reads as a dropped keystroke rather than a bug.
grep -qE '^RUN git -C /opt/es apply .*vlc-parse-no-block.patch' "${REPO_ROOT}/docker/Dockerfile"
check "the Dockerfile applies the patch" $?

echo
echo "harness plumbing:"

for var in VIDEO_DELAY VIDEO_AUDIO SETTLE FRAMES FRAME_INTERVAL CAROUSEL_RIGHT; do
  grep -q -- "-e ${var}=" "${REPO_ROOT}/scripts/render.sh"
  check "render.sh passes ${var} through" $?
done

grep -q 'subset.videoDelay' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh writes subset.videoDelay" $?

grep -q 'subset.videoAudio' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh writes subset.videoAudio" $?

# Video plays now, and the capture lands ~6s after entering a gamelist — past
# the theme's own 5s default. Without a longer pin, every render of a game with
# a scraped video would catch a different frame.
grep -q 'VIDEO_DELAY="10 seconds"' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh pins a 10s video delay by default" $?

grep -q '\[\[ -n "${VIDEO_DELAY:-}" \]\] || VIDEO_DELAY=' "${REPO_ROOT}/docker/run-in-container.sh"
check "an explicit VIDEO_DELAY still wins" $?

# A capture taken before the theme's <delay> elapses can only ever show the
# snapshot, so the settle wait has to happen before the screenshot.
python3 - "${REPO_ROOT}/docker/run-in-container.sh" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
settle = s.index('sleep "${SETTLE}"')
shot = s.index('import -window root')
sys.exit(0 if settle < shot else 1)
PY
check "the settle wait happens before the screenshot" $?

grep -q 'OUTNAME%.png}-${i}.png' "${REPO_ROOT}/docker/run-in-container.sh"
check "--frames writes numbered captures" $?

# A --frames run can span minutes. Checking ES is alive only once, up front,
# turns a mid-sequence crash into blank PNGs and exit 0.
python3 - "${REPO_ROOT}/docker/run-in-container.sh" <<'FRAMEGUARD'
import sys
s = open(sys.argv[1]).read()
loop = s.index('for i in $(seq 1 "${FRAMES}")')
shot = s.index('import -window root "/harness-out/${OUTNAME%.png}', loop)
sys.exit(0 if 'require_es_alive' in s[loop:shot] else 1)
FRAMEGUARD
check "every --frames capture re-checks that ES is alive" $?

# `(( 08 ))` is an octal parse error, so a zero-padded --frames/--settle would
# silently do the wrong thing rather than fail.
grep -q '10#' "${REPO_ROOT}/scripts/render.sh"
check "render.sh forces base-10 on its numeric arguments" $?

grep -q '10#' "${REPO_ROOT}/docker/run-in-container.sh"
check "run-in-container.sh forces base-10 on its numeric envs" $?

# ES silently ignores an unknown subset value and falls back to the theme
# default, so a typo'd VIDEO_DELAY would quietly reintroduce the very
# nondeterminism the pin was added to remove.
grep -q 'check_pin VIDEO_DELAY' "${REPO_ROOT}/scripts/render.sh"
check "render.sh validates the VIDEO_DELAY pin against theme.xml" $?

echo
echo "fixture video assets:"

LIB="${REPO_ROOT}/tests/fixtures/library"
for rel in psx/media/videos/ff7.mp4 snes/media/videos/super-metroid.mp4; do
  [[ -s "${LIB}/${rel}" ]]
  check "${rel} is a non-empty file" $?

  # 'ftyp' in the first 16 bytes = a real MP4 container, not a placeholder.
  head -c 16 "${LIB}/${rel}" 2>/dev/null | grep -q 'ftyp'
  check "${rel} is an MP4 container" $?
done

# Both clips, not just psx: an unwired video is an unreachable fixture, and the
# snes one is the 8:7 clip that makes the aspect mismatch of #41 visible.
for rel in psx/media/videos/ff7.mp4 snes/media/videos/super-metroid.mp4; do
  sys="${rel%%/*}"
  grep -q "<video>./media/videos/${rel##*/}</video>" "${LIB}/${sys}/gamelist.xml"
  check "${sys}/gamelist.xml wires ${rel##*/}" $?
done

# The showSnapshotNoVideo path needs a game with an image and no video.
python3 - "${LIB}/psx/gamelist.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
games = ET.parse(sys.argv[1]).getroot().findall('game')
sys.exit(0 if any(g.find('image') is not None and g.find('video') is None
                  for g in games) else 1)
PY
check "psx fixtures include a game with an image but no video" $?

[[ -f "${REPO_ROOT}/tests/fixtures/gen-videos.py" ]]
check "the fixture videos have a generator" $?

echo
echo "docs:"

grep -q 'knulli-9bbb16a-r2' "${REPO_ROOT}/docker/README.md"
check "docker/README.md names the current image tag" $?

# Two claims are now dead: that video support is compiled out of the binary,
# and that the harness image lacks VLC's plugins. A file may say the opposite;
# what it must not do is repeat either. This covers the live theme XML as well
# as the READMEs — the comment beside the screenshot/video pair is exactly
# where the next person reads WHY the pair exists (#41), so a stale claim there
# does more damage than one in a doc. docs/superpowers/ is deliberately out of
# scope: those are dated design records of what was believed at the time.
STALE_RE='support is compiled out|cannot play video|plugins are not installed'
STALE_RE+='|no libvlc linkage|zero .?VideoVlcComponent'
STALE_HITS="$(grep -rlE "${STALE_RE}" \
    "${REPO_ROOT}/README.md" "${REPO_ROOT}/docker/README.md" \
    "${REPO_ROOT}/theme.xml" "${REPO_ROOT}"/_inc/*.xml 2>/dev/null || true)"
[[ -z "${STALE_HITS}" ]]
check "no README or live theme file repeats the 'harness cannot play video' claim" $?
if [[ -n "${STALE_HITS}" ]]; then
  echo "         stale in:" >&2
  sed "s|^${REPO_ROOT}/|           |" <<<"${STALE_HITS}" >&2
fi

grep -q 'Preview video plays here' "${REPO_ROOT}/docker/README.md"
check "docker/README.md states that video plays" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
