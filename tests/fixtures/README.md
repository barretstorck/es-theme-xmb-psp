# Test Fixtures

A tiny Knulli-shaped library used by `scripts/render-fixtures.sh` to
render `gamelist` and `gamecarousel` views without depending on a real
device library.

## Matrix

| system | game | thumbnail | video | description | genre |
|---|---|:-:|:-:|:-:|:-:|
| snes | super-metroid | ✓ | ✓ | ✓ | ✓ |
| snes | zelda3 | ✓ | | ✓ | ✓ |
| snes | unscraped-game | | | | |
| snes | no-desc | ✓ | | | ✓ |
| psx | ff7 | ✓ | ✓ | ✓ | ✓ |
| psx | mgs | ✓ | | ✓ | ✓ |
| psx | no-video | ✓ | | ✓ | ✓ |
| psx | no-thumb | | | ✓ | ✓ |
| nes | smb3 | ✓ | | ✓ | ✓ |
| nes | contra | ✓ | | ✓ | ✓ |
| nes | no-genre | ✓ | | ✓ | |
| nes | zero-metadata | | | | |

The two videos are short synthetic clips (a frame counter and a sweep bar) at
their systems' native gameplay resolutions — psx 320x240 (4:3), snes 256x224
(8:7). They are deliberately unmistakable for the still box art, so a render
proves a `<video>` is *playing* rather than showing its snapshot, and their
differing aspect ratios exercise `<maxSize>`, which fits each file to its own
rectangle.

Video only plays under `render.sh --video`; the default harness image has no
VLC plugins. See `docker/README.md`.

## Regenerating thumbnails

    python3 tests/fixtures/gen-thumbs.py

## Regenerating videos

    python3 tests/fixtures/gen-videos.py

Needs ffmpeg — from `PATH`, or Docker (`mwader/static-ffmpeg`) if it is not
installed.
