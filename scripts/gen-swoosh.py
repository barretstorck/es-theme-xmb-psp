#!/usr/bin/env python3
"""gen-swoosh.py — generate the system-carousel navigation sound.

Mirrors the procedural-asset pattern of scripts/gen-chevrons.py and
scripts/gen-battery-icons.py. Produces:
  sounds/system-scroll.wav — the horizontal "swoosh" heard when the system
                             carousel moves between systems

Why generated rather than sourced: the PSP distinguishes horizontal cross moves
from vertical sub-item moves, the horizontal being a softer, lower swoosh
against the vertical's bright tick (docs/psp-authenticity-audit.md, A2). No
CC-licensed asset matches the existing set's timbre, and an original synthesis
adds no third-party licence to CREDITS.md — which matters for the go-public
audit in issue #47.

Shape, following A2's sketch: a band of noise whose centre glides DOWNWARD from
1100 Hz to 600 Hz over 200 ms, plus a quiet sine at the same centre for the
low-frequency body A2 asks for. The downward bend is what makes it read as a
movement that settles rather than an alert; sounds/navigate.wav, the vertical
tick, is a flat bright transient dominant at 6.4 kHz, so the two do not collide
anywhere in the spectrum.

Levels are matched to the existing set by RMS, not by peak: noise and a
transient with the same peak are perceived at very different loudnesses, and it
is the RMS that decides whether the swoosh sits alongside the tick or shouts
over it. sounds/navigate.wav measures 0.0218 RMS.

Re-run after editing this script:
  python3 scripts/gen-swoosh.py
"""

import wave
from pathlib import Path

import numpy as np

OUT_PATH = Path(__file__).resolve().parent.parent / "sounds" / "system-scroll.wav"

RATE = 44100
CHANNELS = 2  # matches sounds/navigate.wav and sounds/select.wav
DURATION_S = 0.200  # A2: "about 200 ms duration"

# A2: "center frequency ~800 Hz, with a slight pitch bend". 1100 -> 600 Hz keeps
# 800 Hz as the geometric middle while giving the bend somewhere to travel.
SWEEP_START_HZ = 1100.0
SWEEP_END_HZ = 600.0

# Filter sharpness. Low enough to stay a "swoosh" — push it much past 3 and the
# noise band collapses into an audible pitched tone, which is the tick's job.
RESONANCE_Q = 2.2

# Band-pass stages in series. A state-variable filter's band output rolls off at
# only 6 dB/octave a side, which leaves enough broadband noise above the band to
# read as hiss rather than as a swoosh — one stage measured a 4.6 kHz spectral
# centroid against an 875 Hz peak. Each extra stage doubles the slope.
FILTER_STAGES = 3

# How much of the quiet sine to mix under the noise. Enough to give the low body
# A2 asks for; more than this and the swoosh turns into a descending bleep.
SINE_MIX = 0.30

ATTACK_S = 0.015  # fast enough to read as a movement cue, not a pad
TARGET_RMS = 0.0218  # sounds/navigate.wav, so the pair sits at one level


def sweep_hz(n: int) -> np.ndarray:
    """Centre frequency per sample, gliding geometrically start -> end.

    Geometric rather than linear because pitch is perceived logarithmically: a
    linear ramp spends most of its time in the top half of the interval and the
    bend stops sounding like an even glide.
    """
    return np.geomspace(SWEEP_START_HZ, SWEEP_END_HZ, n)


def bandpass_sweep(signal: np.ndarray, centre: np.ndarray) -> np.ndarray:
    """Chamberlin state-variable band-pass with a per-sample centre frequency.

    Written out rather than pulled from scipy: scipy is not a dependency of this
    repo, and its filter functions take a FIXED cutoff, so a glide would need the
    signal chopped into blocks and re-filtered — which leaves a click at every
    block boundary. A state-variable filter takes a new coefficient every sample
    by construction, which is exactly what a swept filter needs.
    """
    f = 2.0 * np.sin(np.pi * centre / RATE)
    q = 1.0 / RESONANCE_Q
    out = signal
    for _ in range(FILTER_STAGES):
        source, out = out, np.empty_like(signal)
        low = band = 0.0
        for i in range(signal.size):
            high = source[i] - low - q * band
            band += f[i] * high
            low += f[i] * band
            out[i] = band
    return out


def envelope(n: int) -> np.ndarray:
    """Fast attack, exponential decay, forced to zero at both ends.

    The final sample is pinned to zero because SDL_mixer plays the chunk as-is:
    a non-zero last sample is a step discontinuity, which is an audible click on
    every single carousel move.
    """
    env = np.exp(-np.linspace(0.0, 4.5, n))
    attack = int(ATTACK_S * RATE)
    env[:attack] *= np.linspace(0.0, 1.0, attack)
    env[-1] = 0.0
    return env


def make_swoosh() -> np.ndarray:
    n = int(DURATION_S * RATE)
    # Seeded so the asset is reproducible: an unseeded run would produce a
    # different-sounding file on every invocation and a spurious git diff.
    rng = np.random.default_rng(20260909)
    centre = sweep_hz(n)

    noise = bandpass_sweep(rng.uniform(-1.0, 1.0, n), centre)
    # Integrating the swept frequency gives the phase; using centre directly as
    # a phase multiplier would sweep the WRONG way and add a discontinuity.
    sine = np.sin(2.0 * np.pi * np.cumsum(centre) / RATE)

    noise /= np.max(np.abs(noise))
    mono = (1.0 - SINE_MIX) * noise + SINE_MIX * sine
    mono *= envelope(n)
    mono *= TARGET_RMS / np.sqrt(np.mean(np.square(mono)))

    peak = np.max(np.abs(mono))
    if peak >= 1.0:
        raise SystemExit(f"ERROR: signal clips at {peak:.3f} full scale")
    # Centred, not panned. A pan would encode a direction, and the carousel moves
    # both ways — half of every user's moves would sweep the wrong way.
    return np.repeat(mono[:, None], CHANNELS, axis=1)


def main() -> None:
    stereo = make_swoosh()
    pcm = np.round(stereo * 32767.0).astype("<i2")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT_PATH), "wb") as w:
        w.setnchannels(CHANNELS)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())

    mono = stereo[:, 0]
    print(f"wrote {OUT_PATH.relative_to(OUT_PATH.parents[1])}: "
          f"{stereo.shape[0] / RATE * 1000:.0f}ms, {RATE}Hz, {CHANNELS}ch, "
          f"peak {np.max(np.abs(mono)):.3f}, rms {np.sqrt(np.mean(mono ** 2)):.4f}")


if __name__ == "__main__":
    main()
