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

## Regenerating thumbnails

    python3 tests/fixtures/gen-thumbs.py
