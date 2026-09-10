#!/usr/bin/env bash
# The harness image identity, in ONE place.
#
# ES_PIN/HARNESS_REV/IMAGE used to be copied into every script that runs the
# container. render.sh's own comment explains why that is dangerous: the build
# only fires when the image is MISSING, so a stale copy of the tag means that
# script silently keeps using whatever image was built first. With four copies
# and a guard covering two of them, the next HARNESS_REV bump would leave
# record.sh and render-readme-assets.sh pointing at the old image with no error.
#
# HARNESS_REV is bumped whenever docker/ changes the IMAGE'S CONTENTS.
# docker/run-in-container.sh is bind-mounted at run time and never COPYd, so
# editing it is NOT a reason to bump.
# All three are consumed by the scripts that source this file.
ES_PIN="9bbb16a"
HARNESS_REV="r2"
IMAGE="es-xmb-harness:knulli-${ES_PIN}-${HARNESS_REV}"

# The build-on-first-use guard belongs here for exactly the reason the tag
# does. It was copied byte-for-byte into render.sh, record.sh and
# capture-audio.sh, and it is the half of the mechanism that makes a stale tag
# silent: the build fires only when the image is MISSING, so a script holding
# the wrong IMAGE finds nothing to build, builds it, and then happily renders
# against something no other script uses. One tag plus one guard, together, is
# what makes a HARNESS_REV bump reach every consumer.
#
# Requires REPO_ROOT to be set by the caller.
ensure_harness_image() {
  if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "Building ${IMAGE} (one-time, ~5-10 min)..."
    docker build -t "${IMAGE}" --build-arg ES_PIN="${ES_PIN}" "${REPO_ROOT}/docker"
  fi
}
