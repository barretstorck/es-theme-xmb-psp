#!/usr/bin/env python3
"""Measure what EmulationStation actually played during a VIEW=audio capture.

capture-audio.sh drives ES through a key script while SDL's "disk" audio driver
writes the mixer's output to a raw file, and records the byte offset at which
each key was pressed. This script turns those offsets into an answer to the only
question that matters for a sound binding: did anything come out?

Silence is the interesting result. A theme <sound> element ES never asks for and
a correctly wired one look identical in the XML; they differ here.

The stream is signed 16-bit little-endian stereo at 44100 Hz, fixed by
AudioManager's Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2) (AudioManager.cpp:71).
"""

import argparse
import sys
from pathlib import Path

import numpy as np

RATE = 44100
CHANNELS = 2
BYTES_PER_FRAME = CHANNELS * 2  # s16 stereo

# Full scale for signed 16-bit. Amplitudes are reported as a fraction of this so
# the numbers stay comparable across captures and mixer volume settings.
FULL_SCALE = 32768.0

# Digital silence out of the SDL mixer is exact zeros, so any threshold above
# zero works; this one is ~ -60 dBFS, low enough to catch a quiet sound and high
# enough that a single stray sample cannot report one.
DEFAULT_THRESHOLD = 0.001


def load_pcm(path: Path) -> np.ndarray:
    """Return the capture as a mono float array in [-1, 1], one value per frame."""
    raw = np.fromfile(path, dtype="<i2")
    if raw.size == 0:
        raise SystemExit(f"ERROR: {path} is empty — ES produced no audio at all.")
    if raw.size % CHANNELS:
        # A truncated final frame means the stream was cut mid-sample. Drop it
        # rather than letting the reshape below fail on an otherwise fine capture.
        raw = raw[: raw.size - (raw.size % CHANNELS)]
    stereo = raw.reshape(-1, CHANNELS).astype(np.float32) / FULL_SCALE
    return stereo.mean(axis=1)


def load_events(path: Path, total_frames: int) -> list[tuple[int, str]]:
    """Read the offset/key manifest, converting byte offsets to frame indices."""
    events = []
    for lineno, line in enumerate(path.read_text().splitlines(), start=1):
        if not line.strip() or line.startswith("offset_bytes"):
            continue
        parts = line.split("\t")
        if len(parts) != 2:
            raise SystemExit(f"ERROR: {path}:{lineno}: expected 'offset<TAB>key'")
        offset, key = parts
        frame = int(offset) // BYTES_PER_FRAME
        if frame >= total_frames:
            # The capture ended before this keystroke's audio could be written.
            # Reporting it as silence would be a false negative, so refuse.
            raise SystemExit(
                f"ERROR: {path}:{lineno}: event '{key}' is at frame {frame}, "
                f"past the end of the {total_frames}-frame capture."
            )
        events.append((frame, key))
    if not events:
        raise SystemExit(f"ERROR: {path} lists no events.")
    return events


def dominant_hz(segment: np.ndarray) -> float:
    """Peak of the magnitude spectrum, ignoring DC."""
    if segment.size < 64:
        return 0.0
    windowed = segment * np.hanning(segment.size)
    spectrum = np.abs(np.fft.rfft(windowed))
    spectrum[0] = 0.0
    return float(np.fft.rfftfreq(segment.size, 1 / RATE)[int(np.argmax(spectrum))])


def measure(mono: np.ndarray, start: int, end: int, threshold: float) -> dict:
    """Describe one event window: was there sound, when, how loud, what pitch."""
    segment = mono[start:end]
    peak = float(np.max(np.abs(segment))) if segment.size else 0.0
    if peak < threshold:
        return {"sound": False, "peak": peak, "onset_ms": None,
                "duration_ms": 0.0, "hz": 0.0, "rms": 0.0}

    loud = np.flatnonzero(np.abs(segment) >= threshold)
    first, last = int(loud[0]), int(loud[-1])
    body = segment[first : last + 1]
    return {
        "sound": True,
        "peak": peak,
        "onset_ms": first / RATE * 1000.0,
        "duration_ms": body.size / RATE * 1000.0,
        "hz": dominant_hz(body),
        "rms": float(np.sqrt(np.mean(np.square(body)))),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("capture", type=Path, help="raw s16le/44100/stereo capture")
    ap.add_argument("--events", type=Path,
                    help="event manifest (default: <capture>.events.tsv)")
    ap.add_argument("--window", type=float, default=1.5,
                    help="seconds after each keypress to examine (default: 1.5)")
    ap.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD,
                    help=f"amplitude counted as sound (default: {DEFAULT_THRESHOLD})")
    ap.add_argument("--expect", default="",
                    help="comma-separated 'sound' / 'silence' / 'any', one per "
                         "event in order. Exits non-zero on any mismatch.")
    args = ap.parse_args()

    events_path = args.events or args.capture.with_suffix(".events.tsv")
    if not args.capture.is_file():
        raise SystemExit(f"ERROR: no capture at {args.capture}")
    if not events_path.is_file():
        raise SystemExit(f"ERROR: no event manifest at {events_path}")
    if args.window <= 0:
        raise SystemExit("ERROR: --window must be positive")

    mono = load_pcm(args.capture)
    events = load_events(events_path, mono.size)

    expected = [e.strip() for e in args.expect.split(",") if e.strip()]
    if expected:
        if len(expected) != len(events):
            raise SystemExit(
                f"ERROR: --expect lists {len(expected)} outcomes but the capture "
                f"has {len(events)} events."
            )
        for e in expected:
            if e not in ("sound", "silence", "any"):
                raise SystemExit(f"ERROR: bad --expect value '{e}'")

    span = int(args.window * RATE)
    print(f"{args.capture}: {mono.size / RATE:.1f}s, {len(events)} events, "
          f"window {args.window}s, threshold {args.threshold}")
    print(f"{'#':>2}  {'key':<8} {'at':>7}  {'result':<7} {'peak':>6} "
          f"{'onset':>7} {'dur':>7} {'freq':>7}")

    failures = []
    for i, (frame, key) in enumerate(events):
        # The window stops at the next keypress when the script moves faster
        # than --window, so one long sound cannot be credited to two events.
        end = min(frame + span, events[i + 1][0] if i + 1 < len(events) else mono.size)
        m = measure(mono, frame, end, args.threshold)
        result = "SOUND" if m["sound"] else "silence"
        onset = f"{m['onset_ms']:.0f}ms" if m["sound"] else "-"
        dur = f"{m['duration_ms']:.0f}ms" if m["sound"] else "-"
        hz = f"{m['hz']:.0f}Hz" if m["sound"] else "-"
        line = (f"{i:>2}  {key:<8} {frame / RATE:>6.2f}s  {result:<7} "
                f"{m['peak']:>6.3f} {onset:>7} {dur:>7} {hz:>7}")

        if expected:
            want = expected[i]
            ok = want == "any" or (want == "sound") == m["sound"]
            line += "   " + ("ok" if ok else f"MISMATCH (expected {want})")
            if not ok:
                failures.append(f"event {i} ({key}): expected {want}, got {result}")
        print(line)

    if failures:
        print(f"\nFAIL: {len(failures)} mismatch(es)", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        return 1
    if expected:
        print(f"\nPASS: all {len(events)} events matched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
