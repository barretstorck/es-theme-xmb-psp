#!/usr/bin/env bash
# Guards the wave layer art against its generator (scripts/gen-wave-layers.py).
#
# WHY THIS EXISTS
#
# The FIRST wave generator was never committed. README.md claimed for months
# that the layers were "generated procedurally by a small Python script", but no
# such file exists anywhere in the object database, reachable or dangling — so
# when the art needed changing, the wave's maths had to be recovered by running
# an FFT over the committed PNGs. That is the exact failure this guards against:
# art and generator drifting apart until only the art is left.
#
# NOTE: deliberately NOT `set -e` — see the note in test-gamelist-styles.sh.
set -uo pipefail

# shellcheck source=scripts/lib/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/test-lib.sh"

GENERATOR="${REPO_ROOT}/scripts/gen-wave-layers.py"
WAVE_DIR="${REPO_ROOT}/art/wave"

echo "== the generator exists and the art is reproducible =="

test -f "${GENERATOR}"
check "scripts/gen-wave-layers.py exists (art is generated, not hand-drawn)" $?

grep -q 'export-ignore' "${REPO_ROOT}/.gitattributes" && \
  grep -qE '^scripts/ +export-ignore' "${REPO_ROOT}/.gitattributes"
check "scripts/ is export-ignore, so the generator stays out of the release archive" $?

if ! python3 -c 'import numpy, PIL' 2>/dev/null; then
  echo "  skip - generator reproducibility (python3 + numpy + Pillow unavailable)"
else
  # Compare PIXELS, not file bytes: PNG encoders shift between zlib/Pillow
  # releases, so a byte-for-byte gate here would become a tripwire for
  # dependency upgrades rather than a guard against real drift.
  OUT="$(mktemp -d)"
  python3 "${GENERATOR}" --outdir "${OUT}" >/dev/null 2>&1
  check "generator runs clean" $?

  python3 - "${WAVE_DIR}" "${OUT}" <<'PY' 2>/dev/null
import sys
import numpy as np
from PIL import Image
committed, fresh = sys.argv[1], sys.argv[2]
for n in (1, 2, 3):
    a = np.asarray(Image.open(f"{committed}/wave-layer-{n}.png").convert("RGBA"))
    b = np.asarray(Image.open(f"{fresh}/wave-layer-{n}.png").convert("RGBA"))
    if not np.array_equal(a, b):
        sys.exit(1)
sys.exit(0)
PY
  check "generator reproduces all three committed layers pixel-for-pixel" $?
  rm -rf "${OUT}"

  # The rim edge is the whole point of the anti-aliasing fix: a binary test
  # leaves exactly two values (body grey and white) across the grey/white
  # transition, and the crest stair-steps because it runs near-horizontal.
  python3 - "${WAVE_DIR}" <<'PY' 2>/dev/null
import sys
import numpy as np
from PIL import Image
for n in (1, 2, 3):
    a = np.asarray(Image.open(f"{sys.argv[1]}/wave-layer-{n}.png").convert("RGBA"))
    opaque = a[..., 3] > 250
    if len(np.unique(a[..., 0][opaque])) < 16:
        sys.exit(1)
sys.exit(0)
PY
  check "rim edge is anti-aliased, not a two-value binary step" $?
fi

echo
if [[ "${fail}" -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit "${fail}"
