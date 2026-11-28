# Draws media/WeaveArrow.tga: a bold chevron pointing up, white with soft edges (the game tints it).
# Usage: python make-weave-art.py <YaHT folder>
import math, os, struct, sys
W, H = 64, 32
PTS = [(7.0, 25.0), (32.0, 7.0), (57.0, 25.0)]   # left foot, tip, right foot (y grows downward)
HALF = 5.2                                        # half the stroke's thickness
def dist(px, py, a, b):
    ax, ay = a; bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))
rows = []
for y in range(H):
    row = bytearray()
    for x in range(W):
        cov = 0.0
        for sy in range(4):                       # 4x4 samples per pixel: smooth edges
            for sx in range(4):
                px, py = x + (sx + 0.5) / 4, y + (sy + 0.5) / 4
                d = min(dist(px, py, PTS[0], PTS[1]), dist(px, py, PTS[1], PTS[2]))
                if d <= HALF: cov += 1
        a = int(round(255 * cov / 16))
        row += bytes((255, 255, 255, a))          # B, G, R, A
    rows.append(bytes(row))
out = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 8) + b''.join(reversed(rows))  # rows bottom-up
open(os.path.join(sys.argv[1], 'media', 'WeaveArrow.tga'), 'wb').write(out)
print('WeaveArrow.tga', len(out))
