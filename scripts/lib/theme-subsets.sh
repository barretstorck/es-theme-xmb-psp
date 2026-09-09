#!/usr/bin/env bash
# Shared theme-subset reader and the validators built on it.
#
# Extracted from render.sh so every consumer reads the SAME source of truth:
# render.sh, record.sh, render-readme-assets.sh and the README guard. A
# hard-coded copy of the colorset list in any of them would let a thirteenth
# palette ship with a twelve-row gallery and nothing to catch it.
#
#   subset_values  list a <subset>'s values, straight from theme.xml
#   check_pin      reject an env pin that is not one of those values
#   check_bool     reject a non-true/false env setting (no subset involved)
#
# check_pin lives here rather than in render.sh because record.sh needs it for
# the same reason render.sh does: ES silently ignores an unknown subset value
# and falls back to the theme default, so an unvalidated typo yields a flawless
# render of the wrong thing.
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

check_pin() { # check_pin <env-var-name> <subset-name>
  local var="$1" subset="$2" val="${!1:-}" valid
  [[ -n "${val}" ]] || return 0            # empty = theme default, always fine
  valid="$(subset_values "${subset}")"
  if [[ -z "${valid}" ]]; then
    echo "bad ${var}: theme.xml declares no '${subset}' subset" >&2; exit 2
  fi
  if ! grep -Fxq -- "${val}" <<<"${valid}"; then
    echo "bad ${var}: '${val}' is not a value of the '${subset}' subset." >&2
    echo "  valid values:" >&2
    sed 's/^/    /' <<<"${valid}" >&2
    exit 2
  fi
}

check_bool() { # check_bool <env-var-name>
  local var="$1" val="${!1:-}"
  [[ -z "${val}" ]] && return 0
  if [[ "${val}" != "true" && "${val}" != "false" ]]; then
    echo "bad ${var}: '${val}' — expected true or false" >&2; exit 2
  fi
}
