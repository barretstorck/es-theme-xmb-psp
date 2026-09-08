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

grep -q '<video>./media/videos/ff7.mp4</video>' "${LIB}/psx/gamelist.xml"
check "psx/gamelist.xml wires ff7's video" $?

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

# The old claim was that video support is compiled out of the binary. The
# README may now say the opposite; what it must not do is repeat the claim.
! grep -qE 'support is compiled out|no libvlc linkage|zero .?VideoVlcComponent' \
    "${REPO_ROOT}/docker/README.md"
check "docker/README.md does not repeat the 'compiled out' claim" $?

grep -q 'Preview video plays here' "${REPO_ROOT}/docker/README.md"
check "docker/README.md states that video plays" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
