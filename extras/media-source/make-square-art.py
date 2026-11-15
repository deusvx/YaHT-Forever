"""YaHT's polished look for its square icons (the proc icons, the aspect badge and the hawks in their
square shape): a bevelled frame that takes the place of the flat rim, the frame's fine dark edge lines, a
soft light for the icon and a soft shadow. White / grey shapes: the game tints them.
Also draws a mock-up (standard look next to polished look) to judge it outside the game.

Usage: python make_square_art.py <media folder> <stand-in icon image> <mock-up png>"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

media, stand_in, mock_out = sys.argv[1:4]
N = 128
OUTER, THICK = 0.985, 0.15       # the frame: its half-size and its thickness, as shares of the half-size
RAD = 0.12                       # how round the corners are (small: the square icon under it must not peek out)


def grid(n):
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    return (x + 0.5 - n / 2) / (n / 2), (y + 0.5 - n / 2) / (n / 2)


def sd(x, y, half, rad):
    """Distance to a rounded square's edge: negative inside."""
    qx, qy = np.abs(x) - (half - rad), np.abs(y) - (half - rad)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rad


def cover(d, n):
    return np.clip(-d / (2.0 / n) + 0.5, 0, 1)


def frame(n=N):
    x, y = grid(n)
    d = sd(x, y, OUTER, RAD)
    a = cover(d, n) * (1 - cover(d + THICK, n))
    gy, gx = np.gradient(d)
    g = np.maximum(np.hypot(gx, gy), 1e-9)
    nx, ny = gx / g, gy / g
    lit = 0.66 + 0.34 * (-0.45 * nx - 0.89 * ny)                      # light from the upper left
    t = np.clip(-d / THICK, 0, 1)
    lum = np.clip(lit * (0.74 + 0.26 * np.sin(np.pi * t)) * 1.14, 0.36, 1)
    return lum, a


def lines(n=N):
    x, y = grid(n)
    d = sd(x, y, OUTER, RAD)
    w = 0.02
    a = np.maximum(np.exp(-(d / w) ** 2), np.exp(-((d + THICK) / w) ** 2)) * 0.9
    return np.zeros((n, n)), a


def gloss(n=N):
    x, y = grid(n)
    a = 0.26 * np.clip((0.10 - y) / 1.1, 0, 1) ** 1.3                  # a soft light on the upper half
    a += 0.09 * np.exp(-(((x + 0.30) / 0.46) ** 2 + ((y + 0.55) / 0.26) ** 2))
    return np.ones((n, n)), np.clip(a, 0, 1)


def halo(n=N):
    x, y = grid(n)
    d = sd(x, y, 0.60, 0.10)
    a = np.where(d < 0, 1.0, np.exp(-(d / 0.16) ** 2))
    edge = np.minimum(1 - np.abs(x), 1 - np.abs(y))
    return np.ones((n, n)), a * np.clip(edge / 0.08, 0, 1)             # nothing reaches the quad's edge


def save(name, lum, a):
    rgba = np.dstack([lum, lum, lum, a])
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    path = media + "/" + name + ".tga"
    img.save(path)
    data = open(path, "rb").read()[:18 + N * N * 4]                    # (without the footer, like YaHT's other shapes)
    open(path, "wb").write(data)


save("SquareRing", *frame())
save("SquareLine", *lines())
save("SquareGloss", *gloss())
save("SquareHalo", *halo())

# ---------------------------------------------------------------- the mock-up
S, Z = 30, 8                      # an icon's size on screen, and how many times larger it is drawn here
GOLD, RED = (0.85, 0.70, 0.42), (1.0, 0.33, 0.28)


def layer(fn, size, tint, alpha=1.0):
    n = int(round(size * Z))
    lum, a = fn(n)
    return np.dstack([lum * tint[0], lum * tint[1], lum * tint[2]]), a * alpha, n


def put(canvas, cx, cy, rgb, a, n, add=False):
    x0, y0 = int(round(cx - n / 2)), int(round(cy - n / 2))
    region = canvas[y0:y0 + n, x0:x0 + n]
    if not add:
        region *= (1 - a[..., None])
    region += rgb * a[..., None]


def rect(canvas, cx, cy, w, h, color, alpha=1.0):
    x0, y0 = int(round(cx - w * Z / 2)), int(round(cy - h * Z / 2))
    region = canvas[y0:y0 + int(round(h * Z)), x0:x0 + int(round(w * Z))]
    region *= (1 - alpha)
    region += np.array(color) * alpha


def icon_layer(size):
    n = int(round(size * Z))
    im = Image.open(stand_in).convert("RGB")
    w, h = im.size
    side = int(min(w, h) * 0.42)
    im = im.crop((w // 2 - side // 2, int(h * 0.30) - side // 2, w // 2 + side // 2, int(h * 0.30) + side // 2)).resize((n, n), Image.LANCZOS)
    return np.asarray(im, dtype=np.float64) / 255, np.ones((n, n)), n


def one(canvas, cx, cy, color, part, polished):
    """One proc-style icon: the square with its rim or frame, and the timer line under it."""
    if polished:
        put(canvas, cx, cy + 0.06 * S * Z, *layer(halo, (S + 2) * 1.5, (0, 0, 0), 0.7))
        put(canvas, cx, cy, *icon_layer(S))
        put(canvas, cx, cy, *layer(gloss, S, (1, 1, 1)), add=True)
        put(canvas, cx, cy, *layer(frame, S + 2, color))
        put(canvas, cx, cy, *layer(lines, S + 2, (0, 0, 0)))
    else:
        rect(canvas, cx, cy, S + 2, S + 2, color)
        put(canvas, cx, cy, *icon_layer(S))
    ty = cy + (S + 2) * Z / 2 + 3 * Z                                   # the timer line: a dark track, the part left in colour
    rect(canvas, cx, ty, S, 2, (0, 0, 0), 0.45)
    rect(canvas, cx - S * Z * (1 - part) / 2, ty, S * part, 2, color)


W, H = 196 * Z, 74 * Z
canvas = np.zeros((H, W, 3))
canvas[:] = (0.13, 0.15, 0.11)
canvas *= (1.15 - 0.4 * (np.mgrid[0:H, 0:W][0] / H))[..., None]
y = 28 * Z
xs = (30 * Z, 70 * Z, 126 * Z, 166 * Z)
one(canvas, xs[0], y, GOLD, 0.78, False)
one(canvas, xs[1], y, RED, 0.28, False)
one(canvas, xs[2], y, GOLD, 0.78, True)
one(canvas, xs[3], y, RED, 0.28, True)
out = Image.fromarray((np.clip(canvas, 0, 1) * 255 + 0.5).astype(np.uint8))
d = ImageDraw.Draw(out)
f = ImageFont.truetype(r"C:\Windows\Fonts\segoeuib.ttf", 30)
small = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 24)
for cx, text, col in ((xs[0], "14", (243, 227, 181)), (xs[1], "5", (255, 140, 128)), (xs[2], "14", (243, 227, 181)), (xs[3], "5", (255, 140, 128))):
    tw = d.textlength(text, font=f)
    ty = y + (S + 2) * Z / 2 + 6 * Z
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        d.text((cx - tw / 2 + dx, ty + dy), text, font=f, fill=(0, 0, 0))
    d.text((cx - tw / 2, ty), text, font=f, fill=col)
for cx, text in (((xs[0] + xs[1]) / 2, "Square, standard look"), ((xs[2] + xs[3]) / 2, "Square, polished look")):
    tw = d.textlength(text, font=small)
    d.text((cx - tw / 2, 64 * Z), text, font=small, fill=(200, 200, 200))
out.save(mock_out)
print("done", out.size)
