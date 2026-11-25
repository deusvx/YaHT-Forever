"""Hunter sounds for YaHT, made from scratch (noise, damped rings, plucked strings): no recordings.
Plain Python, no libraries; ffmpeg turns the result into .ogg."""
import sys, os, wave, struct, math, random, subprocess

SR = 44100
random.seed(7)
TAU = 2 * math.pi

def N(sec): return int(SR * sec)
def zeros(n): return [0.0] * n
def noise(n): return [random.gauss(0, 1) for _ in range(n)]

def biquad(x, kind, f, q=0.707):
    w = TAU * f / SR; c, s = math.cos(w), math.sin(w); a = s / (2 * q)
    if kind == "lp": b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
    else:            b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
    a0, a1, a2 = 1 + a, -2 * c, 1 - a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = [0.0] * len(x); x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y
def band(x, lo, hi):
    for _ in range(2): x = biquad(x, "hp", lo)
    for _ in range(2): x = biquad(x, "lp", min(hi, SR * 0.45))
    return x
def norm(x, peak=1.0):
    m = max(abs(v) for v in x) or 1.0
    return [v / m * peak for v in x]
def mul(x, f): return [v * f(i / SR) for i, v in enumerate(x)]
def env(attack, decay): return lambda s: min(1.0, s / max(attack, 1e-4)) * math.exp(-s / decay)
def add(*xs):
    n = max(len(x) for x in xs); out = [0.0] * n
    for x in xs:
        for i, v in enumerate(x): out[i] += v
    return out
def gain(x, g): return [v * g for v in x]
def ring(n, freqs, decays, amps):
    out = [0.0] * n
    for f, d, a in zip(freqs, decays, amps):
        ph = random.uniform(0, TAU); w = TAU * f / SR
        for i in range(n): out[i] += a * math.sin(w * i + ph) * math.exp(-(i / SR) / d)
    return out
def place(buf, at, x, g=1.0):
    i0 = N(at)
    for i, v in enumerate(x):
        if i0 + i >= len(buf): break
        buf[i0 + i] += g * v
def soft(x, drive=1.6):
    k = math.tanh(drive)
    return [math.tanh(v * drive) / k for v in x]
def finish(x, peak=0.89, fade=0.012):
    m = sum(x) / len(x); x = [v - m for v in x]
    n = N(fade)
    for i in range(n): x[len(x) - n + i] *= 1 - i / n
    for i in range(N(0.002)): x[i] *= i / N(0.002)
    return norm(x, peak)

def clack(dur, lo, hi, rings, decay, thump=0.0):
    """one mechanical knock: a burst of noise, the metal ringing after it, a low thump under it"""
    n = N(dur)
    out = norm(mul(band(noise(n), lo, hi), env(0.0008, decay)))
    out = add(out, gain(ring(n, rings, [decay * 2.2] * len(rings), [1 / (k + 1) ** 0.7 for k in range(len(rings))]), 0.55))
    if thump:
        out = add(out, [thump * math.sin(TAU * (150 * math.exp(-(i / SR) * 18) + 70) * (i / SR)) * math.exp(-(i / SR) / 0.045) for i in range(n)])
    return out
def scrape(dur, lo, hi, rate):
    """the slide moving: noise that swells, with a ratchety edge"""
    n = N(dur)
    x = band(noise(n), lo, hi)
    return norm([v * (0.25 + 0.75 * (i / n)) ** 2 * (1 + 0.5 * (1 if math.sin(TAU * rate * i / SR) >= 0 else -1)) for i, v in enumerate(x)])

def pump():
    """shotgun pump: the slide racked back (ch), then slammed forward (chk)"""
    buf = zeros(N(0.52))
    place(buf, 0.010, scrape(0.085, 1200, 5200, 140), 0.42)
    place(buf, 0.088, clack(0.11, 900, 6500, [1450, 2380, 3620, 5100], 0.020, thump=0.55), 0.85)
    place(buf, 0.225, scrape(0.060, 1500, 6000, 170), 0.40)
    place(buf, 0.282, clack(0.20, 800, 8000, [1280, 2150, 3340, 4780, 6400], 0.026, thump=0.9), 1.0)
    return finish(soft(buf, 1.9))

def bolt():
    """rifle bolt: up and back, forward and down: tight clicks"""
    buf = zeros(N(0.40))
    place(buf, 0.008, clack(0.07, 1800, 9000, [2600, 4100, 6300], 0.010, thump=0.2), 0.7)
    n = N(0.07)
    place(buf, 0.060, norm([v * math.sin(math.pi * i / n) ** 2 for i, v in enumerate(band(noise(n), 2000, 7000))]), 0.22)
    place(buf, 0.150, clack(0.07, 1800, 9000, [2300, 3900, 5800], 0.011, thump=0.25), 0.8)
    place(buf, 0.215, clack(0.15, 1200, 8000, [1900, 3100, 4700, 6900], 0.020, thump=0.6), 1.0)
    return finish(soft(buf, 1.7))

def bow():
    """bow: the string let go (a low twang falling a little in pitch), the arrow leaving (a short hiss)"""
    n = N(0.55)
    s = zeros(n); ph = 0.0
    phases = [0.0] * n
    for i in range(n):
        ph += TAU * 118 * (1 + 0.10 * math.exp(-(i / SR) / 0.035)) / SR
        phases[i] = ph
    for k in range(1, 13):
        d = 0.22 / (1 + 0.28 * k); st = 1 + 0.0009 * k * k; a = 1 / k ** 1.15
        for i in range(n): s[i] += math.sin(k * phases[i] * st) * a * math.exp(-(i / SR) / d)
    s = norm(mul(s, lambda t: min(1.0, t / 0.0015)))
    slap = norm(mul(band(noise(n), 700, 4500), env(0.0006, 0.012)))
    hiss = norm(mul(band(noise(n), 2500, 9000), lambda t: math.exp(-((t - 0.05) / 0.045) ** 2)))
    return finish(soft(add(s, gain(slap, 0.45), gain(hiss, 0.30)), 1.4))

def thud():
    """an arrow striking wood: a hard knock, a low thump, the shaft humming for a moment"""
    n = N(0.42)
    knock = norm(mul(band(noise(n), 300, 5000), env(0.0005, 0.009)))
    low = [1.1 * math.sin(TAU * (95 * math.exp(-(i / SR) * 9) + 62) * (i / SR)) * math.exp(-(i / SR) / 0.07) for i in range(n)]
    wood = gain(ring(n, [410, 655, 980, 1420], [0.045, 0.035, 0.025, 0.018], [1, 0.7, 0.45, 0.3]), 0.6)
    hum = [0.22 * math.sin(TAU * 232 * (i / SR)) * math.exp(-(i / SR) / 0.11) * (1 + 0.5 * math.sin(TAU * 27 * (i / SR))) for i in range(n)]
    return finish(soft(add(knock, low, wood, hum), 1.8))

def horn():
    """a hunting horn: two rising notes"""
    def note(f, dur):
        n = N(dur); s = zeros(n); ph = 0.0; phases = [0.0] * n
        for i in range(n):
            t = i / SR
            ph += TAU * f * (1 + 0.004 * math.sin(TAU * 5.2 * t) * min(1.0, t / 0.2)) / SR
            phases[i] = ph
        for k in range(1, 15):
            for i in range(n):
                bright = min(1.0, (i / SR) / 0.09)      # a horn brightens as the note opens
                s[i] += math.sin(k * phases[i]) / k ** (2.1 - 0.9 * bright)
        return [v * min(1.0, (i / SR) / 0.045) * min(1.0, (dur - i / SR) / 0.09) for i, v in enumerate(s)]
    buf = zeros(N(0.95))
    place(buf, 0.00, note(196.0, 0.30), 0.8)    # G3
    place(buf, 0.27, note(293.7, 0.66), 1.0)    # D4
    buf = add(band(buf, 120, 5200), gain(band(noise(len(buf)), 900, 4000), 0.02))
    return finish(soft(norm(buf), 1.3), fade=0.03)

def drum():
    """a hide drum: one deep hit"""
    n = N(0.55); ph = 0.0; body = zeros(n)
    for i in range(n):
        t = i / SR
        ph += TAU * (58 + 75 * math.exp(-t / 0.03)) / SR
        body[i] = 1.2 * math.sin(ph) * math.exp(-t / 0.16)
    skin = ring(n, [142, 215, 301], [0.09, 0.06, 0.04], [0.5, 0.3, 0.2])
    slap = gain(norm(mul(band(noise(n), 500, 4000), env(0.0006, 0.010))), 0.5)
    return finish(soft(add(body, skin, slap), 2.0))

def blade():
    """a knife drawn: a rising scrape, then the steel ringing"""
    n = N(0.60); m = N(0.16)
    raw = noise(m); sweep = zeros(n)
    for j in range(8):                          # a band that climbs: the edge leaving the sheath
        c = 2200 + (7000 - 2200) * j / 7
        seg = band(raw, c * 0.8, c * 1.25)
        for i in range(m):
            sweep[i] += seg[i] * math.exp(-((i / m - (j + 0.5) / 8) / 0.16) ** 2) * (0.3 + 0.7 * i / m)
    steel = ring(n, [2950, 4380, 5160, 6730, 8120], [0.20, 0.16, 0.13, 0.10, 0.07], [1, 0.8, 0.6, 0.5, 0.35])
    lag = N(0.13)
    steel = [0.0] * lag + steel[: n - lag]
    return finish(soft(add(gain(norm(sweep), 0.9), gain(norm(steel), 0.75)), 1.3), fade=0.04)

SOUNDS = [("Pump", pump), ("Bolt", bolt), ("Bow", bow), ("Thud", thud), ("Horn", horn), ("Drum", drum), ("Blade", blade)]

def describe(x):
    """what it is, in numbers (nobody here can listen): loud moments, and roughly where its energy sits"""
    win = N(0.005)
    sm = [sum(abs(v) for v in x[i:i + win]) / win for i in range(0, len(x) - win, win)]
    top = max(sm)
    hits = [round(i * win / SR, 2) for i in range(1, len(sm) - 1) if sm[i] > 0.3 * top and sm[i] >= sm[i - 1] and sm[i] > sm[i + 1]]
    # zero crossings per second / 2: a rough "pitch" of the whole thing
    zc = sum(1 for i in range(1, len(x)) if (x[i - 1] < 0) != (x[i] < 0)) / (len(x) / SR) / 2
    rms = math.sqrt(sum(v * v for v in x) / len(x))
    return hits[:8], zc, rms

def main(out_dir, ffmpeg):
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in SOUNDS:
        x = fn()
        wav = os.path.join(out_dir, "Sound-%s.wav" % name)
        with wave.open(wav, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
        ogg = os.path.join(out_dir, "Sound-%s.ogg" % name)
        r = subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", "-ac", "1", ogg], capture_output=True, text=True)
        assert r.returncode == 0, r.stderr
        hits, zc, rms = describe(x)
        print("%-6s %.2fs  rms %.3f  ~%5.0f Hz  loud moments at %s  ogg %d bytes" % (name, len(x) / SR, rms, zc, hits, os.path.getsize(ogg)))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
