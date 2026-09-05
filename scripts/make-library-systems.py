#!/usr/bin/env python3
"""Generate a Knulli-accurate es_systems.cfg for a harness test library.

The harness falls back to synthesising one system entry per directory, using the
directory name as the fullname. That is enough to get a render out, but it is not
what the device looks like: Knulli's real es_systems.cfg carries proper fullnames
("Super Nintendo Entertainment System", not "snes"), a per-system extension list,
and the theme folder name. A theme that keys off any of those renders differently
here than on hardware -- in both directions.

This writes es_systems.cfg into the library root. run-in-container.sh picks it up
and uses it verbatim instead of synthesising one.

Definitions come from batocera's canonical es_systems.yml, which is what Knulli
inherits. Cache it alongside the script to work offline.

Usage:
    ./scripts/make-library-systems.py .dev/library
    ./scripts/make-library-systems.py .dev/library --yml /path/to/es_systems.yml
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape

ES_SYSTEMS_YML = (
    "https://raw.githubusercontent.com/batocera-linux/batocera.linux/master"
    "/package/batocera/emulationstation/batocera-es-system/es_systems.yml"
)


def load_yml(cache: Path, override: Path | None) -> str:
    if override:
        return override.read_text(encoding="utf-8", errors="replace")
    if cache.is_file():
        return cache.read_text(encoding="utf-8", errors="replace")
    with urllib.request.urlopen(ES_SYSTEMS_YML, timeout=60) as resp:
        text = resp.read().decode("utf-8", errors="replace")
    cache.write_text(text, encoding="utf-8")
    return text


def parse_systems(text: str) -> dict[str, dict[str, object]]:
    """Pull name/extensions/group out of es_systems.yml.

    Deliberately not using PyYAML -- the file is large and regular, and the
    harness should not need a dependency the rest of the repo does not have.
    """
    systems: dict[str, dict[str, object]] = {}
    for block in re.split(r"\n(?=\S[^\s:]*:\s*\n)", text):
        key = re.match(r"([A-Za-z0-9_\-]+):\s*\n", block)
        if not key:
            continue
        name = re.search(r"^\s+name:\s*(.+)$", block, re.M)
        if not name:
            continue
        exts = re.search(r"^\s+extensions:\s*\[(.*?)\]", block, re.M | re.S)
        group = re.search(r"^\s+group:\s*(\S+)", block, re.M)
        systems[key.group(1)] = {
            "name": name.group(1).strip(),
            "ext": [e.strip() for e in exts.group(1).split(",")] if exts else ["zip"],
            "theme": group.group(1).strip() if group else key.group(1),
        }
    return systems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("library", type=Path, help="harness library directory")
    ap.add_argument("--yml", type=Path, help="local es_systems.yml instead of fetching")
    args = ap.parse_args()

    if not args.library.is_dir():
        print(f"not a directory: {args.library}", file=sys.stderr)
        return 2

    cache = Path(__file__).with_name("es_systems.yml.cache")
    systems = parse_systems(load_yml(cache, args.yml))

    lines = ['<?xml version="1.0"?>', "<systemList>"]
    known = unknown = 0
    for sysdir in sorted(p for p in args.library.iterdir() if p.is_dir()):
        s = sysdir.name
        info = systems.get(s)
        if info is None:
            # Not in batocera's list (a port collection, or a Knulli-only entry).
            # Fall back rather than drop it -- the theme still needs to see it.
            info = {"name": s, "ext": ["zip"], "theme": s}
            unknown += 1
        else:
            known += 1
        exts = " ".join("." + e.lstrip(".") for e in info["ext"])
        lines += [
            "  <system>",
            f"    <name>{escape(s)}</name>",
            f"    <fullname>{escape(str(info['name']))}</fullname>",
            f"    <path>/userdata/roms/{escape(s)}</path>",
            f"    <extension>{escape(exts)}</extension>",
            "    <command>echo %ROM%</command>",
            f"    <platform>{escape(s)}</platform>",
            f"    <theme>{escape(str(info['theme']))}</theme>",
            "  </system>",
        ]
    lines += ["</systemList>", ""]

    out = args.library / "es_systems.cfg"
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {out} ({known} systems matched, {unknown} fell back to the directory name)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
