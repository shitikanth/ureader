#!/usr/bin/env python3
"""Generate a macOS-compliant app icon from a source PNG of a glyph.

Produces a 1024x1024 PNG with the source glyph centered on a white squircle
tile sized to 824x824 (Apple's macOS icon template inner box, 100px padding).
The squircle uses a superellipse (n=5) which closely approximates Apple's
continuous-curvature app icon shape.
"""
import sys
from pathlib import Path
from PIL import Image

SRC = Path(sys.argv[1])
DST = Path(sys.argv[2])

CANVAS = 1024
TILE = 824                       # macOS icon template inner box
PAD = (CANVAS - TILE) // 2
GLYPH_SCALE = 0.90               # glyph occupies 90% of tile
TILE_BG = (255, 255, 255, 255)   # white squircle
SUPER_N = 5.0
SUPER_SS = 4                     # supersampling for mask edge


def squircle_mask(size: int, n: float = SUPER_N, ss: int = SUPER_SS) -> Image.Image:
    big = size * ss
    mask = Image.new("L", (big, big), 0)
    px = mask.load()
    half = big / 2.0
    for y in range(big):
        ny = (y + 0.5 - half) / half
        ay = abs(ny) ** n
        if ay >= 1.0:
            continue
        xspan = half * ((1.0 - ay) ** (1.0 / n))
        x0 = max(0, int(half - xspan))
        x1 = min(big, int(half + xspan))
        for x in range(x0, x1):
            px[x, y] = 255
    return mask.resize((size, size), Image.LANCZOS)


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    # Tight bbox around the glyph (anything with non-zero alpha).
    bbox = src.split()[-1].getbbox()
    if bbox is None:
        raise SystemExit("source image is fully transparent")
    glyph = src.crop(bbox)

    # White squircle tile.
    tile = Image.new("RGBA", (TILE, TILE), TILE_BG)
    mask = squircle_mask(TILE)
    # Apply mask to alpha channel of tile.
    r, g, b, a = tile.split()
    tile.putalpha(mask)

    # Scale glyph to occupy GLYPH_SCALE of TILE on the larger dimension.
    gw, gh = glyph.size
    target = int(TILE * GLYPH_SCALE)
    scale = target / max(gw, gh)
    new_w, new_h = max(1, int(round(gw * scale))), max(1, int(round(gh * scale)))
    glyph_r = glyph.resize((new_w, new_h), Image.LANCZOS)

    # Composite glyph centered on tile.
    gx = (TILE - new_w) // 2
    gy = (TILE - new_h) // 2
    tile.alpha_composite(glyph_r, (gx, gy))

    # Place tile centered on transparent 1024 canvas.
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(tile, (PAD, PAD))

    DST.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(DST, format="PNG", optimize=True)
    print(f"wrote {DST} ({CANVAS}x{CANVAS}); glyph bbox in source: {bbox}")


if __name__ == "__main__":
    main()
