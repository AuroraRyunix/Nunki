"""Draws rel/windows/Nunki.ico and rel/macos/Nunki-icon.png from the mark
in priv/logo/mark.svg.

The mark is nine squares on a 24-unit grid: five filled with the ink, one
with the accent, three only outlined. They are read out of the SVG and
redrawn here rather than rendered from it, because rendering SVG needs a
renderer nobody has installed and nine rectangles do not. The parser knows
exactly one shape - a `<rect>` with x, y, width and height, filled
(`fill="currentColor"`, or the accent in `style="fill:var(--accent,...)"`)
or outlined (`fill="none" stroke="currentColor" stroke-width="..."`) - and
stops on anything else, so a mark that grows a circle says so instead of
quietly losing it.

    python rel/windows/build_icon.py

Needs Pillow. Both files are committed: the launcher's resource script and
`vpk pack --icon` want the .ico, rel/macos/build_app.sh wants the PNG, and CI
should not need Python to make a release.
"""

import re
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
MARK = HERE.parent.parent / "priv" / "logo" / "mark.svg"

INK = (27, 27, 26, 255)
# Nunki's accent, #94600a.
ACCENT = (148, 96, 10, 255)
PAPER = (255, 255, 255, 255)


def attrs(tag):
    return dict(re.findall(r'([\w:-]+)="([^"]*)"', tag))


def read_mark():
    """[(x, y, w, h, kind, stroke_width)] with kind "ink", "accent" or "outline"."""
    svg = MARK.read_text(encoding="utf-8")
    body = re.sub(r"^.*?<svg[^>]*>|</svg>\s*$", "", svg.strip(), flags=re.S)
    tags = re.findall(r"<[^>]+>", body)
    shapes = []

    for tag in tags:
        if not tag.startswith("<rect"):
            raise SystemExit(f"{MARK}: this script draws rectangles only, and found {tag}")

        a = attrs(tag)
        x, y, w, h = (float(a[k]) for k in ("x", "y", "width", "height"))
        style = a.get("style", "")

        if "var(--accent" in style:
            shapes.append((x, y, w, h, "accent", 0))
        elif a.get("fill") == "none" and a.get("stroke") == "currentColor":
            shapes.append((x, y, w, h, "outline", float(a.get("stroke-width", "1"))))
        elif a.get("fill") == "currentColor":
            shapes.append((x, y, w, h, "ink", 0))
        else:
            raise SystemExit(f"{MARK}: a rectangle this script does not know how to colour: {tag}")

    if not shapes:
        raise SystemExit(f"{MARK}: no rectangles in it")

    return shapes


def draw(shapes, size, scale=16):
    # Drawn large and scaled down: the small sizes get their edges from the
    # resampling, not from rounding a 0.67-pixel gap to nothing. The mark
    # sits on a 28-unit tile, two units of paper round its 24.
    side = 28 * scale
    image = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    pen = ImageDraw.Draw(image)
    pen.rounded_rectangle((0, 0, side - 1, side - 1), radius=4 * scale, fill=PAPER)

    def box(x, y, w, h):
        return ((x + 2) * scale, (y + 2) * scale, (x + 2 + w) * scale - 1, (y + 2 + h) * scale - 1)

    for x, y, w, h, kind, stroke in shapes:
        if kind == "outline":
            # SVG strokes straddle the edge: half outside, half inside.
            half = stroke / 2
            width = max(1, round(stroke * scale))
            pen.rectangle(box(x - half, y - half, w + stroke, h + stroke), outline=INK, width=width)
        else:
            pen.rectangle(box(x, y, w, h), fill=ACCENT if kind == "accent" else INK)

    return image.resize((size, size), Image.LANCZOS)


def write_mac_png(shapes, path):
    # macOS draws its icons inside a margin (824 of 1024); a tile that fills
    # the canvas looks a size too big beside everybody else's in the Dock.
    # Drawn at 32 units a pixel (896 square) so 824 is a step down, not up.
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    canvas.paste(draw(shapes, 824, scale=32), (100, 100))
    canvas.save(path)


def main():
    shapes = read_mark()
    sizes = [256, 128, 64, 48, 32, 24, 16]
    draw(shapes, 256).save(HERE / "Nunki.ico", format="ICO", sizes=[(s, s) for s in sizes])
    print(f"wrote {HERE / 'Nunki.ico'}")
    png = HERE.parent / "macos" / "Nunki-icon.png"
    write_mac_png(shapes, png)
    print(f"wrote {png}")


if __name__ == "__main__":
    main()
