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

echo "image selection:"

grep -q 'IMAGE="${IMAGE}-video"' "${REPO_ROOT}/scripts/render.sh"
check "--video selects the -video image tag" $?

grep -q 'WITH_VIDEO=1' "${REPO_ROOT}/scripts/render.sh"
check "--video builds with WITH_VIDEO=1" $?

# One Dockerfile, two images. A second Dockerfile would drift silently.
[[ ! -e "${REPO_ROOT}/docker/Dockerfile.video" ]]
check "there is no forked video Dockerfile" $?

grep -q 'ARG WITH_VIDEO=0' "${REPO_ROOT}/docker/Dockerfile"
check "Dockerfile defaults WITH_VIDEO to 0" $?

# vlc-plugin-base is the whole reason <video> was dead in the harness:
# libvlc-dev ships the library, not a single demuxer or decoder.
grep -q 'vlc-plugin-base' "${REPO_ROOT}/docker/Dockerfile"
check "Dockerfile installs vlc-plugin-base for the video image" $?

# Both images must build the SAME ES commit — a different pin would silently
# stop the video renders from matching the device.
n_pins="$(grep -c 'ARG ES_PIN=9bbb16a' "${REPO_ROOT}/docker/Dockerfile")"
[[ "${n_pins}" == "1" ]]
check "both images build ES pin 9bbb16a (found ${n_pins} pin declarations)" $?

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

# Applied under WITH_VIDEO only: the default image stays an unmodified build
# of the pinned source.
grep -A2 'WITH_VIDEO}" = "1"' "${REPO_ROOT}/docker/Dockerfile" | grep -q 'vlc-parse-no-block.patch'
check "the patch is applied only when WITH_VIDEO=1" $?

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

grep -q 'knulli-9bbb16a-video' "${REPO_ROOT}/docker/README.md"
check "docker/README.md names the video image" $?

! grep -q 'compiled out' "${REPO_ROOT}/docker/README.md"
check "docker/README.md drops the 'video compiled out' claim" $?

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
