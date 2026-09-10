#!/usr/bin/env bash
# Run every structural test suite, plus the whole-tree gates.
#
# The suites were only ever invoked one at a time, by hand, from whichever
# ticket was in flight — so a change touching shared XML could break a suite
# nobody happened to run. The whole thing takes a few seconds and needs no
# Docker: there is no reason not to run all of it before every commit.
#
# Usage:
#   scripts/tests/run-all.sh              # everything
#   scripts/tests/run-all.sh grid sound   # only suites matching these substrings
#   VERBOSE=1 scripts/tests/run-all.sh    # stream each suite's own output
#
# Exit status is 0 only if every selected suite and every gate passes.
#
# NOTE: deliberately NOT `set -e` — a failing suite must be recorded and
# reported alongside the others, not abort the run at the first one.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}" || exit 1

VERBOSE="${VERBOSE:-0}"
declare -a PASSED=() FAILED=() SKIPPED=()

run_one() { # run_one <name> <command...>
  local name="$1"; shift
  local out rc
  if [[ "${VERBOSE}" == "1" ]]; then
    echo "── ${name}"
    "$@"; rc=$?
  else
    out="$("$@" 2>&1)"; rc=$?
  fi
  if [[ ${rc} -eq 0 ]]; then
    printf '  \033[32mPASS\033[0m  %s\n' "${name}"
    PASSED+=("${name}")
  else
    printf '  \033[31mFAIL\033[0m  %s (exit %d)\n' "${name}" "${rc}"
    FAILED+=("${name}")
    [[ "${VERBOSE}" == "1" ]] || { sed 's/^/        /' <<<"${out}" | tail -25; }
  fi
}

# ── Whole-tree gates ────────────────────────────────────────────────────────
# These catch what a per-feature suite cannot, because they are about files no
# single ticket owns.

echo "gates:"

# ES parses theme XML with pugixml, which ACCEPTS constructs that are illegal
# XML — notably "--" inside a comment. Such a file renders fine on device and
# breaks only the python3/xmllint tooling, so nothing surfaces it until a
# script mysteriously fails. Parse every file strictly instead.
run_one "xml-well-formed" python3 - <<'PY'
import glob, sys, xml.etree.ElementTree as ET
bad = []
for f in sorted(glob.glob('**/*.xml', recursive=True)):
    try:
        ET.parse(f)
    except Exception as e:
        bad.append(f"{f}: {e}")
if bad:
    print("\n".join(bad)); sys.exit(1)
PY

# A ${variable} that resolves to nothing does not merely blank one property:
# ES drops EVERY icon/path property on the element (the buttonGlyphs failure
# caught on hardware). A variable referenced but never declared is that bug
# waiting for the right subset selection.
run_one "no-undeclared-variables" python3 - <<'PY'
import glob, re, sys
decl, used = set(), set()
for f in glob.glob('**/*.xml', recursive=True):
    t = re.sub(r'<!--.*?-->', '', open(f, encoding='utf-8').read(), flags=re.S)
    for blk in re.findall(r'<variables>(.*?)</variables>', t, re.S):
        decl |= set(re.findall(r'<(\w+)>', blk))
    used |= set(re.findall(r'\$\{(\w+)\}', t))
# system.*, screen.* and game.* are supplied by ES, not by the theme.
missing = sorted(v for v in used - decl if '.' not in v)
if missing:
    print("referenced but never declared: " + ", ".join(missing)); sys.exit(1)
PY

# Two codes are excluded, both because they are false positives against
# idioms this repo uses deliberately and everywhere:
#   SC2319  "$? refers to a condition, not a command" — the house assertion
#           idiom is `[[ cond ]]` on its own line followed by `check "..." $?`,
#           which consumes the status immediately and is correct.
#   SC2034  "appears unused" — the suites assert through eval'd condition
#           strings and the lib/ files export variables to their sourcers,
#           neither of which static analysis can see.
# Everything else is a gate: SC1078/SC2154/SC2164 have all caught real bugs.
# The mirror of the gate above, and the reason five variables sat dead in
# common.xml and the aspect files until the v1.0 audit: a variable whose last
# consumer was deleted leaves nothing behind that looks wrong. The
# <gamecarousel> component went in ae82df9 and gameColX/W/TextY/H outlived it
# by four releases, still being dutifully overridden per aspect ratio.
run_one "no-dead-variables" python3 - <<'PY'
import glob, re, sys
decl, used = {}, set()
for f in glob.glob('**/*.xml', recursive=True):
    t = re.sub(r'<!--.*?-->', '', open(f, encoding='utf-8').read(), flags=re.S)
    for blk in re.findall(r'<variables>(.*?)</variables>', t, re.S):
        for name in re.findall(r'<(\w+)>', blk):
            decl.setdefault(name, set()).add(f)
    used |= set(re.findall(r'\$\{(\w+)\}', t))
dead = sorted(set(decl) - used)
if dead:
    for d in dead:
        print(f"declared but never consumed: {d}  ({', '.join(sorted(decl[d]))})")
    sys.exit(1)
PY

# Doc citations of the form `_inc/foo.xml:123`. These break SILENTLY and
# repeatedly: a seven-line insert in a style file shifted five citations in
# the style guide, one of them into an unrelated element, and a 26-line
# deletion for #34 broke five more. Nothing surfaces it, because the docs are
# never executed. Only path:line forms are checked — a bare filename in prose
# ("art/halo.png was deleted in v1.0") is deliberate and must stay legal.
#
# Scoped to the LIVE reference docs. Dated files under docs/superpowers/ are
# point-in-time plans and specs, correct for the release they describe, and
# are not maintained against the current tree.
run_one "doc-citations-resolve" python3 - <<'PY'
import os, re, sys
LIVE = ['README.md', 'CREDITS.md', 'docker/README.md',
        'docs/psp-authenticity-audit.md', 'docs/psp-xmb-style-guidelines.md']
PAT = re.compile(r'((?:_inc|scripts|colors|docker|art|sounds|fonts)/'
                 r'[\w./-]+\.(?:xml|sh|py)):(\d+)')
bad = []
for doc in LIVE:
    if not os.path.exists(doc):
        continue
    for i, line in enumerate(open(doc, encoding='utf-8'), 1):
        for path, num in PAT.findall(line):
            num = int(num)
            if not os.path.exists(path):
                bad.append(f"{doc}:{i} cites {path}:{num} — no such file")
            else:
                n = sum(1 for _ in open(path, encoding='utf-8', errors='ignore'))
                if num > n:
                    bad.append(f"{doc}:{i} cites {path}:{num} — file has {n} lines")
if bad:
    print("\n".join(bad)); sys.exit(1)
PY

# The repository is public (#47), so anything committed here is published the
# moment it lands — cloneable and indexable before it can be taken back. The
# v1.0 audit found the tree had already drifted past its own recorded state:
# the note saying "the real device address does not appear" was written while a
# real LAN address sat in three files, having arrived with the battery-widget
# screenshots long after the check was last run. A scan that only runs when
# someone remembers to run it is how that happens.
#
# Scoped to what a scan can actually decide. Credential SHAPES (key headers,
# vendor token prefixes) are unambiguous. A password VALUE is not, so the one
# rule here is structural: no assignment may carry a literal secret, and the
# documented Knulli default `linux` is allowlisted by exact value because it is
# published in Knulli's own docs and is the whole point of .env.local.example.
run_one "no-secrets" python3 - <<'PY_SECRETS'
import re, subprocess, sys

files = subprocess.run(['git', 'ls-files'], capture_output=True, text=True,
                       check=True).stdout.split()
bad = []

# One example address, documented as such. Any other RFC1918 address is either
# somebody's real device or a stale copy of one.
EXAMPLE_IP = '192.168.1.4'
PRIVATE_IP = re.compile(r'\b(?:192\.168|10\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01]))'
                        r'\.\d{1,3}\.\d{1,3}\b')
SECRET_SHAPE = re.compile(
    r'BEGIN (?:RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY'
    r'|AKIA[0-9A-Z]{16}'
    r'|gh[pousr]_[A-Za-z0-9]{20,}'
    r'|xox[baprs]-[A-Za-z0-9-]{10,}'
    r'|sk-[A-Za-z0-9]{20,}')
# A credential-shaped name assigned a literal. Interpolations (${VAR}, $VAR),
# empty values and the documented default are not literals we are leaking.
#
# Two assignment spellings, and neither may be preceded by `${`: bash parameter
# expansion puts a colon straight after a credential-shaped name without
# assigning anything, so `${NAS_PASS:+SET}` — an idiom whose entire purpose is
# to avoid printing the value — read as an assignment of the literal "+SET".
# A gate that cries wolf on the safe idiom trains people to ignore it.
CRED_NAME = r'(?<!\$\{)\b(SSHPASS|PASSWORD|PASSWD|API[_-]?KEY|SECRET|TOKEN|NAS_PASS)\b'
ASSIGNED = re.compile(
    r'(?i)' + CRED_NAME + r'(?:=|:[ \t])[ \t]*["\']?([^\s"\'#$}]{3,})')
HOME_PATH = re.compile(r'/(?:Users|home)/(?!runner\b)[A-Za-z0-9._-]+')

for f in files:
    try:
        with open(f, encoding='utf-8') as fh:
            lines = fh.readlines()
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        continue  # binary asset, or a submodule/symlink entry
    for i, line in enumerate(lines, 1):
        for ip in PRIVATE_IP.findall(line):
            if ip != EXAMPLE_IP:
                bad.append(f"{f}:{i} private IP {ip} (only {EXAMPLE_IP} is the documented example)")
        if SECRET_SHAPE.search(line):
            bad.append(f"{f}:{i} credential-shaped literal")
        m = ASSIGNED.search(line)
        if m and m.group(2) != 'linux':
            bad.append(f"{f}:{i} {m.group(1)} assigned a literal value")
        for h in HOME_PATH.findall(line):
            bad.append(f"{f}:{i} absolute home path {h}")

if bad:
    print("\n".join(bad)); sys.exit(1)
print(f"scanned {len(files)} tracked files")
PY_SECRETS

if command -v shellcheck >/dev/null 2>&1; then
  run_one "shellcheck" shellcheck -x -S warning -e SC2319,SC2034 \
    scripts/*.sh scripts/lib/*.sh scripts/tests/*.sh
else
  printf '  \033[33mSKIP\033[0m  shellcheck (not installed)\n'
  SKIPPED+=("shellcheck")
fi

# ── Test suites ─────────────────────────────────────────────────────────────

echo
echo "suites:"
for t in "${SCRIPT_DIR}"/test-*.sh; do
  name="$(basename "${t}" .sh)"
  if [[ $# -gt 0 ]]; then
    match=0
    for pat in "$@"; do [[ "${name}" == *"${pat}"* ]] && match=1; done
    [[ ${match} -eq 1 ]] || continue
  fi
  run_one "${name}" bash "${t}"
done

# ── Summary ─────────────────────────────────────────────────────────────────

echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
  printf '\033[32m%d passed\033[0m' "${#PASSED[@]}"
  [[ ${#SKIPPED[@]} -eq 0 ]] || printf ', %d skipped' "${#SKIPPED[@]}"
  echo
  exit 0
fi

printf '\033[31m%d failed\033[0m, %d passed\n' "${#FAILED[@]}" "${#PASSED[@]}"
for f in "${FAILED[@]}"; do echo "    ${f}"; done
exit 1
