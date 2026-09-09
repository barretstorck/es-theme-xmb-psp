#!/usr/bin/env bash
# Shared reader for theme.xml's <subset> blocks.
#
# Extracted from render.sh so the render harness, the README asset generator
# and the README guard all read the SAME source of truth. A hard-coded copy of
# the colorset list in any of them would let a thirteenth palette ship with a
# twelve-row gallery and nothing to catch it.
#
# Requires REPO_ROOT to be set by the caller.

subset_values() { # subset_values <subset-name>
  awk -v want="$1" '
    $0 ~ "<subset name=\"" want "\"" { inblk = 1; next }
    inblk && /<\/subset>/ { exit }
    inblk && match($0, /<include name="[^"]*"/) {
      print substr($0, RSTART + 15, RLENGTH - 16)
    }
  ' "${REPO_ROOT}/theme.xml"
}
