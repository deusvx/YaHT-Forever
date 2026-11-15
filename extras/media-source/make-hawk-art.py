"""YaHT's hawk circle artwork: a bevelled ring, its fine dark edge lines, a soft gloss for the icon and a
soft round halo (used as the glow and, in black, as the shadow). White / grey shapes: the game tints them.
Also draws a mock-up of the finished circle (before and after) to judge the look outside the game.

Usage: python make_hawk_art.py <media folder> <stand-in icon image> <mock-up png>"""
import sys
import numpy as np
from PIL import Image

media, stand_in, mock_out = sys.argv[1:4]
N = 128
OUTER, INNER = 0.97, 0.80       # the ring, as shares of the half-size
ICON_R = 0.97 * 0.78            # the icon's disc inside it (it is drawn at 78% of the circle's size)


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    x = (x + 0.5 - n / 2) / (n / 2)
    y = (y + 0.5 - n / 2) / (n / 2)
    return x, y, np.hypot(x, y)


def edge(r, at, px, n):
    """Coverage of 'inside radius at', one pixel soft."""
    return np.clip((at - r) / (px * 2.0 / n) + 0.5, 0, 1)


def ring(n=N):
    x, y, r = grid(n)
    a = edge(r, OUTER, 1, n) * (1 - edge(r, INNER, 1, n))
    nx, ny = x / np.maximum(r, 1e-6), y / np.maximum(r, 1e-6)
    lit = 0.64 + 0.36 * (-0.45 * nx - 0.89 * ny)                     # light from the upper left
    t = np.clip((r - INNER) / (OUTER - INNER), 0, 1)
    lum = np.clip(lit * (0.72 + 0.28 * np.sin(np.pi * t)) * 1.12, 0.34, 1)
    return lum, a


def lines(n=N):
    _, _, r = grid(n)
    w = 0.016
    a = np.maximum(np.exp(-((r - OUTER) / w) ** 2), np.exp(-((r - INNER) / w) ** 2)) * 0.85
    return np.zeros_like(a), a


def gloss(n=N):
    x, y, r = grid(n)
    inside = edge(r, 0.97, 1, n)
    a = 0.30 * np.clip((0.15 - y) / 1.0, 0, 1) ** 1.4 * inside       # a soft light on the upper half
    a += 0.10 * np.exp(-(((x + 0.30) / 0.42) ** 2 + ((y + 0.52) / 0.24) ** 2)) * inside
    return np.ones_like(a), np.clip(a, 0, 1)


def halo(n=N):
    _, _, r = grid(n)
    a = np.where(r < 0.58, 1.0, np.exp(-((r - 0.58) / 0.17) ** 2))
    a *= np.clip((1.0 - r) / 0.08, 0, 1)                              # nothing reaches the quad's edge
    return np.ones_like(a), a


def disc(n=N):
    _, _, r = grid(n)
    return np.ones_like(r), edge(r, 0.97, 1, n)


def save(name, lum, a):
    rgba = np.dstack([lum, lum, lum, a])
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    path = media + "/" + name + ".tga"
    img.save(path)
    data = open(path, "rb").read()[:18 + N * N * 4]                   # (without the footer, like YaHT's other shapes)
    open(path, "wb").write(data)
    return lum, a


shapes = {
    "Ring": save("Ring", *ring()),
    "RingLine": save("RingLine", *lines()),
    "Gloss": save("Gloss", *gloss()),
    "Halo": save("Halo", *halo()),
}

# ---------------------------------------------------------------- the mock-up
S = 26          # the circle's size on screen
Z = 8           # drawn this many times larger


def layer(fn, size, tint, alpha=1.0):
    n = int(round(size * Z))
    lum, a = fn(n)
    return np.dstack([lum * tint[0], lum * tint[1], lum * tint[2]]), a * alpha, n


def put(canvas, cx, cy, rgb, a, n, add=False):
    x0, y0 = int(round(cx - n / 2)), int(round(cy - n / 2))
    region = canvas[y0:y0 + n, x0:x0 + n]
    if add:
        region += rgb * a[..., None]
    else:
        region *= (1 - a[..., None])
        region += rgb * a[..., None]


def icon_layer(size):
    n = int(round(size * Z))
    im = Image.open(stand_in).convert("RGB")
    w, h = im.size
    side = int(min(w, h) * 0.42)
    im = im.crop((w // 2 - side // 2, int(h * 0.30) - side // 2, w // 2 + side // 2, int(h * 0.30) + side // 2)).resize((n, n), Image.LANCZOS)
    _, a = disc(n)
    return np.asarray(im, dtype=np.float64) / 255, a, n


def old_ring(n):
    _, _, r = grid(n)
    a = edge(r, 0.97, 1, n) * (1 - edge(r, 1 - 6.5 / 32, 1, n))
    return np.ones_like(a), a


def circle(canvas, cx, cy, color, polished, part=1.0):
    """One hawk circle. part: how much of the ring is left (it drains clockwise from the top)."""
    def arc(a, n):
        x, y, _ = grid(n)
        ang = (np.degrees(np.arctan2(x, -y)) + 360) % 360
        return a * (ang >= 360 * (1 - part))
    if polished:
        put(canvas, cx, cy + 0.06 * S * Z, *layer(halo, S * 1.62, (0, 0, 0), 0.75))
        put(canvas, cx, cy, *layer(halo, S * 1.62, color, 0.34), add=True)
    put(canvas, cx, cy, *layer(disc, S, (0.05, 0.045, 0.04)))
    put(canvas, cx, cy, *icon_layer(S * (0.78 if polished else 0.80)))
    if polished:
        put(canvas, cx, cy, *layer(gloss, S * 0.78, (1, 1, 1)), add=True)
        rgb, a, n = layer(ring, S, (0.34, 0.27, 0.13))
        put(canvas, cx, cy, rgb, a, n)
        rgb, a, n = layer(ring, S, color)
        put(canvas, cx, cy, rgb, arc(a, n), n)
        put(canvas, cx, cy, *layer(lines, S, (0, 0, 0)))
    else:
        rgb, a, n = layer(old_ring, S, (0.32, 0.26, 0.12))
        put(canvas, cx, cy, rgb, a, n)
        rgb, a, n = layer(old_ring, S, color)
        put(canvas, cx, cy, rgb, arc(a, n), n)


W, H = 134 * Z, 52 * Z
canvas = np.zeros((H, W, 3))
canvas[:] = (0.13, 0.15, 0.11)                                        # something like grass at night
yy = np.mgrid[0:H, 0:W][0] / H
canvas *= (1.15 - 0.4 * yy)[..., None]
OLD_GOLD, OLD_RED = (0.91, 0.70, 0.24), (0.93, 0.30, 0.27)
GOLD, RED = (1.0, 0.80, 0.30), (1.0, 0.33, 0.28)
y = 22 * Z
circle(canvas, 16 * Z, y, OLD_GOLD, False, 0.78)
circle(canvas, 46 * Z, y, OLD_RED, False, 0.28)
circle(canvas, 76 * Z, y, GOLD, True, 0.78)
circle(canvas, 106 * Z, y, RED, True, 0.28)
out = Image.fromarray((np.clip(canvas, 0, 1) * 255 + 0.5).astype(np.uint8))
from PIL import ImageDraw, ImageFont
d = ImageDraw.Draw(out)
f = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 26)
small = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 22)
for cx, text, col in ((16 * Z, "14", (243, 227, 181)), (46 * Z, "5", (255, 140, 128)),
                      (76 * Z, "14", (243, 227, 181)), (106 * Z, "5", (255, 140, 128))):
    tw = d.textlength(text, font=f)
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        d.text((cx - tw / 2 + dx, y + S * Z / 2 + 6 + dy), text, font=f, fill=(0, 0, 0))
    d.text((cx - tw / 2, y + S * Z / 2 + 6), text, font=f, fill=col)
d.text((24 * Z, 44 * Z), "Now", font=small, fill=(200, 200, 200))
d.text((80 * Z, 44 * Z), "More polished", font=small, fill=(200, 200, 200))
out.save(mock_out)
# the same at the size it has on screen (x2 so it can be seen), under it
print("done", out.size)
