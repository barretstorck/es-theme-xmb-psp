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
ES_PIN="9bbb16a"
HARNESS_REV="r2"
IMAGE="es-xmb-harness:knulli-${ES_PIN}-${HARNESS_REV}"
