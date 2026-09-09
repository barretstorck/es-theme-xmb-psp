# Test Fixtures

A tiny Knulli-shaped library used by `scripts/render-fixtures.sh` to
render `gamelist` and `gamecarousel` views without depending on a real
device library.

## Matrix

`thumbnail` is `<thumbnail>`, the box-art slot. `screenshot` is `<image>`, the
gameplay still that feeds the media slot — a separate file, as in a real scrape.

| system | game | thumbnail | screenshot | video | description | genre |
|---|---|:-:|:-:|:-:|:-:|:-:|
| snes | super-metroid | ✓ | ✓ 4:3 | ✓ 8:7 | ✓ | ✓ |
| snes | zelda3 | ✓ | box | | ✓ | ✓ |
| snes | video-no-image | | | ✓ 8:7 | ✓ | ✓ |
| snes | unscraped-game | | | | | |
| snes | no-desc | ✓ | box | | | ✓ |
| psx | ff7 | ✓ | ✓ 16:9 | ✓ 4:3 | ✓ | ✓ |
| psx | mgs | ✓ | box | | ✓ | ✓ |
| psx | no-video | ✓ | box | | ✓ | ✓ |
| psx | box-only | ✓ 3:4 | | | ✓ | ✓ |
| psx | no-thumb | | | | ✓ | ✓ |
| nes | smb3 | ✓ | box | | ✓ | ✓ |
| nes | contra | ✓ | box | | ✓ | ✓ |
| nes | no-genre | ✓ | box | | ✓ | |
| nes | long-title | ✓ | box | | ✓ | ✓ |
| nes | zero-metadata | | | | | |

"box" means `<image>` points at the box art, i.e. the still and the box art are
the same file. Only the two games with videos have a distinct screenshot.

The two videos are short synthetic clips (a frame counter and a sweep bar) at
their systems' native gameplay resolutions — psx 320x240 (4:3), snes 256x224
(8:7). They are deliberately unmistakable for the still box art, so a render
proves a `<video>` is *playing* rather than showing its snapshot.

**The screenshots are deliberately WIDER than their clips**, and carry a magenta
border — a colour that appears nowhere else in the theme. `<maxSize>` preserves
each *file's* aspect, so a still and a clip in one slot fit to different
rectangles; if the media slot is ever split back into an image plus a video, the
still's magenta edges show around the video. That was issue #41, and a square
placeholder cannot reproduce it — a 1:1 still fits *inside* a 4:3 clip and hides
the fault completely.

`snes/video-no-image` has a video but no `<image>` at all, which is the path
where the media slot has nothing to show until the clip starts and the fallback
icon underneath is what renders.

`nes/long-title` is the only fixture whose *name* is the point: 89 characters,
with descenders (g/j/p/y). No real title in the scraped library slice is long
enough to overflow a title box — the longest there is 44 characters — so
without this fixture the Box Art Grid's `gridTitle` clipRect, and its height,
render identically whether they are present or not. It is why issue #43's title
overflow was invisible in every v0.12 render.

`psx/box-only` has a thumbnail and no `<image>` — a box-art-only scrape, the
common real-world case. ES falls back to the *thumbnail* for the media slot's
still, so this fixture is what proves the media fallback's guard has to ask
about both. Its box art is **portrait** (192x256) on purpose: a square fallback
behind a 3:4 still leaks on both sides, and a square placeholder would have
hidden that too.

Renders pin the Video Delay to 10s, so an ordinary capture shows the still
screenshot; pass `VIDEO_DELAY=Instant --settle 4` to catch the video playing.
See `docker/README.md`.

## Regenerating thumbnails

    python3 tests/fixtures/gen-thumbs.py

## Regenerating videos

    python3 tests/fixtures/gen-videos.py

Needs ffmpeg — from `PATH`, or Docker (`mwader/static-ffmpeg`) if it is not
installed.
