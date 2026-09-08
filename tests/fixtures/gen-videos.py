"""Generate placeholder gameplay videos for the fixture library.

Each clip is a short, obviously-synthetic animation: the game's box-art
colour, a moving sweep bar and a frame counter. Not real gameplay footage —
just something a screenshot can tell apart from the still box art, so a
harness render proves the <video> element is actually PLAYING rather than
showing its snapshot (see docker/README.md, "Video").

The two clips deliberately differ in aspect ratio (PSX 4:3, SNES 8:7) —
<maxSize> preserves each FILE's aspect, so a video and its snapshot fit to
different rectangles. That mismatch is the subject of issue #41.

Needs ffmpeg. Uses it from PATH if present, otherwise runs the static
image in Docker. Run from repo root:

    python3 tests/fixtures/gen-videos.py
"""
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent / "library"
FFMPEG_IMAGE = "mwader/static-ffmpeg:latest"

FPS = 15
SECONDS = 6

# rel path -> (label, background rgb, (width, height))
# Colours match the game's box art in gen-thumbs.py; sizes are the systems'
# native gameplay resolutions, so the clips have honest aspect ratios.
VIDEOS = {
    "psx/media/videos/ff7.mp4": ("Final Fantasy 7", (70, 70, 200), (320, 240)),
    "snes/media/videos/super-metroid.mp4": ("Super Metroid", (220, 60, 60), (256, 224)),
}


def font(size):
    try:
        return ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size
        )
    except OSError:
        return ImageFont.load_default()


def frame(label, rgb, size, index, total):
    """One frame: label, frame counter, and a bar sweeping left to right."""
    w, h = size
    img = Image.new("RGB", size, rgb)
    draw = ImageDraw.Draw(img)

    # Sweep bar — guarantees consecutive frames differ visibly.
    bar_w = w // 8
    x = int((w + bar_w) * (index / total)) - bar_w
    draw.rectangle([x, 0, x + bar_w, h], fill="white")

    # Border, so the video's own edges are visible against the theme.
    draw.rectangle([0, 0, w - 1, h - 1], outline="white", width=2)

    big, small = font(max(14, h // 12)), font(max(10, h // 18))
    for text, y, fnt in (
        ("VIDEO", h * 0.28, big),
        (label, h * 0.48, small),
        (f"frame {index + 1:02d}/{total}", h * 0.66, small),
    ):
        bbox = draw.textbbox((0, 0), text, font=fnt)
        draw.text(((w - (bbox[2] - bbox[0])) / 2, y), text, fill="white", font=fnt)
    return img


def encode(frames, out_path, size):
    """Pipe PNG frames into ffmpeg, writing an H.264 mp4 to out_path."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if shutil.which("ffmpeg"):
        cmd = ["ffmpeg"]
        target = str(out_path)
    else:
        cmd = ["docker", "run", "--rm", "-i",
               "-v", f"{out_path.parent.resolve()}:/out", FFMPEG_IMAGE]
        target = f"/out/{out_path.name}"
    cmd += [
        "-y", "-hide_banner", "-loglevel", "error",
        # bitexact: no encoder-version metadata, so re-running is reproducible.
        "-fflags", "+bitexact", "-flags", "+bitexact",
        "-f", "image2pipe", "-framerate", str(FPS), "-i", "-",
        "-c:v", "libx264", "-preset", "veryslow", "-crf", "28",
        # yuv420p + even dimensions: the profile every hardware decoder takes.
        "-pix_fmt", "yuv420p", "-s", f"{size[0]}x{size[1]}",
        "-movflags", "+faststart", target,
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    try:
        for img in frames:
            img.save(proc.stdin, format="PNG")
    except BrokenPipeError:
        # ffmpeg exited early (missing encoder, unwritable target, bad docker
        # mount). Its own stderr is already on the terminal; swallow the pipe
        # error so the exit status below reports it, rather than burying the
        # cause under a traceback from the middle of the frame loop.
        pass
    finally:
        try:
            proc.stdin.close()
        except BrokenPipeError:
            pass
    if proc.wait() != 0:
        raise SystemExit(f"ffmpeg failed for {out_path}")


def main():
    total = FPS * SECONDS
    for rel, (label, rgb, size) in VIDEOS.items():
        path = ROOT / rel
        encode((frame(label, rgb, size, i, total) for i in range(total)), path, size)
        print(f"wrote {rel} ({path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
