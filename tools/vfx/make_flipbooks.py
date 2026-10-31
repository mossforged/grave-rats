"""VFX textures for Grave Rats (lead, 2026-10-31). Procedural, re-runnable, no downloads.

Run: python3 tools/vfx/make_flipbooks.py [out_dir]     (numpy, scipy, Pillow)
Writes RGBA PNGs to assets/source/vfx/ (default) plus previews to docs/screens/vfx/.

Flipbooks are square grids read left-to-right, top-to-bottom. "add" sheets are meant for additive
blending (black = nothing); "blend" sheets are straight-alpha RGBA, mostly white/grey so the engine
tints them (dust brown on clinical panels, steam white, smoke dark, acid green).
See assets/source/vfx/README.md for the full list and intended use.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, map_coordinates

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/source/vfx"
PREVIEW = "docs/screens/vfx"
MANIFEST = {}


# ---------------------------------------------------------------- helpers

def fbm(h, w, seed, octaves=5, base=4, tile=True):
    """Fractal value noise in 0..1. tile=True makes it seamless."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = base * 2 ** o
        g = rng.random((n, n)).astype(np.float32)
        if tile:
            big = np.tile(g, (3, 3))
            img = Image.fromarray(big, "F").resize((w * 3, h * 3), Image.BICUBIC)
            a = np.asarray(img)[h:2 * h, w:2 * w]
        else:
            a = np.asarray(Image.fromarray(g, "F").resize((w, h), Image.BICUBIC))
        acc += amp * a
        total += amp
        amp *= 0.5
    acc /= total
    acc -= acc.min()
    return acc / max(acc.max(), 1e-6)


def grid(n):
    """Pixel-centre coordinates in -1..1 for an n x n frame (y down)."""
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, c)
    return x.astype(np.float32), y.astype(np.float32)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def ramp(t, stops):
    """Colour ramp: stops = [(pos, (r,g,b)), ...], t array 0..1 -> HxWx3."""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,), np.float32)
    for (p0, c0), (p1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= p0) & (t <= p1)
        k = ((t - p0) / max(p1 - p0, 1e-6))[..., None]
        out[m] = (np.array(c0) * (1 - k) + np.array(c1) * k)[m]
    return out


FIRE = [(0.0, (0, 0, 0)), (0.25, (0.45, 0.04, 0.0)), (0.5, (0.95, 0.32, 0.03)),
        (0.75, (1.0, 0.72, 0.25)), (1.0, (1.0, 0.97, 0.85))]


FLASH = [(0, (0, 0, 0)), (0.3, (0.9, 0.35, 0.05)), (0.65, (1, 0.8, 0.4)), (1, (1, 1, 0.92))]


def rgba(rgb, a):
    return np.dstack([np.clip(rgb, 0, 1), np.clip(a, 0, 1)])


def sheet(frames, cols):
    n = frames[0].shape[0]
    rows = math.ceil(len(frames) / cols)
    out = np.zeros((rows * n, cols * n, 4), np.float32)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        out[r * n:(r + 1) * n, c * n:(c + 1) * n] = f
    return out


def save(name, arr, blend, desc, frames=1, cols=1, fps=None):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, f"{name}.png"), optimize=True)
    MANIFEST[name] = {"file": f"{name}.png", "blend": blend, "frames": frames, "cols": cols,
                      "size_px": list(img.size), "fps": fps, "use": desc}
    return img


def warp(a, seed, amount):
    """Displace an image by a noise field (amount in pixels)."""
    h, w = a.shape
    dx = (fbm(h, w, seed, 4, 3) - 0.5) * 2 * amount
    dy = (fbm(h, w, seed + 1, 4, 3) - 0.5) * 2 * amount
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return map_coordinates(a, [yy + dy, xx + dx], order=1, mode="nearest")


# ---------------------------------------------------------------- blend flipbooks

def smoke_puff(name="smoke_puff", n=128, count=64, cols=8, seed=10, rise=0.25, life_pow=1.3,
               desc="one puff growing and thinning; particle base for plumes, muzzle smoke, steam (tint)"):
    x, y = grid(n)
    N1 = gaussian_filter(fbm(n * 2, n, seed, 4, 2, tile=False), n / 64)
    N1 = (N1 - N1.min()) / (N1.max() - N1.min())
    N2 = fbm(n * 2, n, seed + 7, 4, 3, tile=False)
    frames = []
    for f in range(count):
        t = f / (count - 1)
        r = 0.45 + 0.5 * t ** 0.6
        off = int(t * n * rise)
        a1 = N1[n - off:2 * n - off]
        a2 = N2[n - off // 2:2 * n - off // 2]
        d = np.sqrt(x ** 2 + (y + t * rise) ** 2) / r + (a1 - 0.5) * (0.5 + 0.5 * t)
        dens = np.clip(1 - d, 0, 1) ** 1.2 * (1 - t) ** life_pow * (0.6 + 0.4 * a2)
        dens = np.clip(dens * 1.8, 0, 1)
        shade = 0.62 + 0.3 * np.clip(-y * 0.8 + 0.2, -1, 1) * 0.5 + 0.12 * (a2 - 0.5)
        frames.append(rgba(np.dstack([shade] * 3), dens))
    return save(name, sheet(frames, cols), "blend", desc, count, cols, 30), frames


def impact_dust():
    return smoke_puff("impact_dust", n=64, count=16, cols=4, seed=40, rise=0.1, life_pow=1.8,
                      desc="short dust/paint puff at a bullet hit on clinical panels (tint by surface)")


def acid_bubble(n=64, count=16, cols=4):
    """A bubble swells, wobbles and pops into a ring and droplets (white; tint green/yellow)."""
    x, y = grid(n)
    frames = []
    rng = np.random.default_rng(5)
    drops = rng.uniform(0, 2 * math.pi, 6)
    for f in range(count):
        t = f / (count - 1)
        if t < 0.6:
            k = t / 0.6
            r = 0.15 + 0.5 * k ** 0.8
            d = np.sqrt(x ** 2 + (y / (1.0 - 0.1 * k)) ** 2)
            body = smoothstep(r, r - 0.08, d) * 0.35
            rim = np.exp(-((d - r) / 0.05) ** 2) * 0.9
            hl = np.exp(-(((x + r * 0.35) ** 2 + (y + r * 0.4) ** 2) / (0.02 + 0.03 * k)))
            a = np.clip(body + rim + hl, 0, 1)
        else:
            k = (t - 0.6) / 0.4
            r = 0.65 + 0.3 * k
            d = np.sqrt(x ** 2 + y ** 2)
            a = np.exp(-((d - r) / (0.04 + 0.03 * k)) ** 2) * (1 - k) * 0.8
            for ang in drops:
                px, py = math.cos(ang) * (0.3 + 0.6 * k), math.sin(ang) * (0.3 + 0.6 * k) - 0.3 * k + 0.6 * k * k
                a += np.exp(-((x - px) ** 2 + (y - py) ** 2) / 0.004) * (1 - k)
            a = np.clip(a, 0, 1)
        frames.append(rgba(np.dstack([np.full_like(x, 0.95)] * 3), a))
    return save("acid_bubble", sheet(frames, cols), "blend",
                "one bubble rising, swelling and popping on an acid/slime pool (tint)", count, cols, 24), frames


# ---------------------------------------------------------------- additive flipbooks

def fire_loop(n=128, count=64, cols=8):
    """A seamless looping flame (64 frames). Additive."""
    x, y = grid(n)
    hgt = (1 - y) / 2  # 0 at bottom, 1 at top
    N1 = fbm(n, n, 21, 5, 4)
    N2 = fbm(n, n, 22, 4, 3)
    frames = []
    for f in range(count):
        a1 = np.roll(N1, -f * (n // count) * 2, axis=0)  # scroll up, loops
        a2 = np.roll(N2, -f * (n // count), axis=0)
        xw = x + (a2 - 0.5) * 0.35 * hgt  # sway, more at the top
        width = 0.5 * (1 - hgt) ** 0.9 + 0.03
        shape = np.exp(-(xw / width) ** 2) * smoothstep(0.0, 0.1, hgt)
        heat = shape * (1.2 - hgt * 0.95) - (a1 * 0.8 + a2 * 0.4) * (0.25 + hgt * 1.0)
        heat = np.clip(heat * 1.25, 0, 1)
        col = ramp(heat, FIRE)
        frames.append(rgba(col, heat ** 0.7))
    return save("fire_loop", sheet(frames, cols), "add",
                "looping flame for burning consoles, fuel fires (scale and layer 2-3)", count, cols, 30), frames


def explosion(n=128, count=64, cols=8):
    """Fireball that cools into a rolling smoke ball. Fire in RGB, smoke alpha-blended."""
    x, y = grid(n)
    N1 = fbm(n * 2, n, 31, 5, 3, tile=False)
    N2 = fbm(n, n, 32, 5, 5, tile=False)
    frames = []
    for f in range(count):
        t = f / (count - 1)
        r = 0.2 + 0.75 * (1 - (1 - t) ** 3)
        off = int(t * n * 0.3)
        a1 = N1[n - off:2 * n - off]
        d = np.sqrt(x ** 2 + (y + t * 0.3) ** 2) / r + (a1 - 0.5) * 0.8
        dens = np.clip(1 - d, 0, 1) ** 0.9
        temp = np.clip((1 - t / 0.45) * 1.3 * (1 - d * 0.6) + (N2 - 0.5) * 0.4, 0, 1)
        fire = ramp(temp, FIRE)
        smoke = np.dstack([0.16 + 0.12 * a1] * 3)
        k = smoothstep(0.02, 0.35, temp)[..., None]
        col = smoke * (1 - k) + fire * k
        alpha = np.clip(dens * 1.6, 0, 1) * (1 - smoothstep(0.55, 1.0, t))
        frames.append(rgba(col, alpha))
    return save("explosion", sheet(frames, cols), "blend",
                "fireball cooling to smoke; unshaded (fire is bright in RGB); pair with a light flash",
                count, cols, 30), frames


def muzzle_flash(n=256):
    """4 front views (star) + 4 side views (cone), 4x2 sheet. Additive. Pick at random per shot."""
    x, y = grid(n)
    rng = np.random.default_rng(7)
    frames = []
    for i in range(4):
        d = np.sqrt(x ** 2 + y ** 2)
        ang = np.arctan2(y, x)
        a = np.exp(-(d / 0.16) ** 2) * 1.3
        k = rng.integers(4, 7)
        base = rng.uniform(0, 2 * math.pi)
        for s in range(k):
            th = base + s * 2 * math.pi / k + rng.uniform(-0.25, 0.25)
            ln = rng.uniform(0.55, 0.95)
            along = x * math.cos(th) + y * math.sin(th)
            perp = -x * math.sin(th) + y * math.cos(th)
            a += np.where(along > 0, np.exp(-(perp / (0.06 * (1 - along / ln).clip(0.05))) ** 2)
                          * np.clip(1 - along / ln, 0, 1) ** 1.5, 0)
        a = warp(np.clip(a, 0, 1.4), 100 + i, 3)
        frames.append(rgba(ramp(a / 1.4, FLASH), np.clip(a, 0, 1)))
    for i in range(4):
        u = (x + 1) / 2  # 0 at muzzle (left) -> 1
        ln = rng.uniform(0.7, 0.95)
        width = 0.05 + 0.32 * np.clip(u / ln, 0, 1) ** 0.8 * (1 - np.clip(u / ln, 0, 1)) ** 0.6
        a = np.exp(-(y / np.maximum(width, 0.02)) ** 2) * np.clip(1 - u / ln, 0, 1) ** 0.9
        a += np.exp(-((x + 0.92) ** 2 + y ** 2) / 0.006) * 1.2
        # side prongs (muzzle brake)
        for sgn in (-1, 1):
            a += np.exp(-((y - sgn * (x + 0.85) * 0.9) ** 2) / 0.003) * np.clip(1 - (x + 0.85) / 0.35, 0, 1) * (x > -0.85)
        a = warp(np.clip(a, 0, 1.4), 200 + i, 4)
        frames.append(rgba(ramp(a / 1.4, FLASH), np.clip(a, 0, 1)))
    return save("muzzle_flash", sheet(frames, 4), "add",
                "frames 0-3 front-on star, 4-7 side cone (muzzle on the left); one random frame per shot, "
                "1-2 frames on screen, random roll", 8, 4), frames


def spark_textures():
    """spark_streak (128x32): a hot streak for velocity-stretched particles. glow_dot (64x64)."""
    w, h = 128, 32
    xs = (np.arange(w) + 0.5) / w
    ys = (np.arange(h) + 0.5) / h * 2 - 1
    X, Y = np.meshgrid(xs, ys)
    taper = np.clip(X / 0.15, 0, 1) * np.clip((1 - X) / 0.6, 0, 1) ** 0.6
    core = np.exp(-(Y / (0.12 * taper + 0.02)) ** 2) * taper
    col = ramp(core, [(0, (0, 0, 0)), (0.4, (1.0, 0.45, 0.08)), (0.8, (1, 0.85, 0.5)), (1, (1, 1, 1))])
    save("spark_streak", rgba(col, core), "add",
         "velocity-aligned spark (head on the right); bursts of 8-20 for metal hits and shorting consoles", 1, 1)
    x, y = grid(64)
    d = np.sqrt(x ** 2 + y ** 2)
    a = np.exp(-(d / 0.18) ** 2) + 0.35 * np.exp(-(d / 0.55) ** 2)
    save("glow_dot", rgba(np.dstack([np.ones_like(d)] * 3), np.clip(a, 0, 1)), "add",
         "soft glow for embers, spark heads, dust motes in a torch beam, warning-lamp halos (tint)", 1, 1)


def electric_arcs(w=256, h=64, count=4):
    """4 jagged arcs left->right with branches, cyan-white glow. Additive. Flip between them fast."""
    rng = np.random.default_rng(3)
    frames, squares = [], []
    for i in range(count):
        img = Image.new("F", (w, h), 0.0)
        dr = ImageDraw.Draw(img)

        def bolt(p0, p1, disp, depth, width):
            if depth == 0:
                dr.line([p0, p1], fill=1.0, width=width)
                return
            mx = (p0[0] + p1[0]) / 2
            my = (p0[1] + p1[1]) / 2 + rng.uniform(-disp, disp)
            bolt(p0, (mx, my), disp / 2, depth - 1, width)
            bolt((mx, my), p1, disp / 2, depth - 1, width)
            if depth >= 3 and rng.random() < 0.35:
                end = (mx + rng.uniform(15, 50), my + rng.uniform(-25, 25))
                bolt((mx, my), end, disp / 3, depth - 2, 1)

        bolt((4, h / 2), (w - 4, h / 2 + rng.uniform(-8, 8)), 22, 6, 2)
        core = np.asarray(img)
        glow = gaussian_filter(core, 3.0) * 3 + gaussian_filter(core, 8) * 4
        a = np.clip(core + glow, 0, 1)
        col = ramp(a, [(0, (0, 0, 0)), (0.3, (0.1, 0.4, 1.0)), (0.7, (0.55, 0.85, 1.0)), (1, (1, 1, 1))])
        f = rgba(col, a)
        pad = np.zeros((w, w, 4), np.float32)
        pad[(w - h) // 2:(w - h) // 2 + h] = f
        frames.append(f)
        squares.append(pad)
    out = np.concatenate(frames, axis=0)  # 256 x 256, one arc per 64-px row
    save("electric_arc", out, "add",
         "4 arcs, one per 64-px row; swap rows every 2-3 frames; shorting panels, cutter, damaged reactor", 4, 1)
    return squares


# ---------------------------------------------------------------- decals

def _hole(n, rng, panel):
    x, y = grid(n)
    d = np.sqrt(x ** 2 + y ** 2)
    ang = np.arctan2(y, x)
    rough = (fbm(n, n, int(rng.integers(1e6)), 4, 6) - 0.5)
    rgb = np.zeros((n, n, 3), np.float32)
    a = np.zeros((n, n), np.float32)
    hole_r = 0.11 + 0.04 * rng.random()
    if panel:
        chip = smoothstep(0.45 + rough * 0.3, 0.3 + rough * 0.3, d)  # chipped paint, lighter primer
        rgb += np.array([0.55, 0.52, 0.46]) * chip[..., None]
        a = np.maximum(a, chip * 0.85)
        for _ in range(int(rng.integers(4, 8))):  # cracks
            th = rng.uniform(0, 2 * math.pi)
            ln = rng.uniform(0.4, 0.9)
            along = x * math.cos(th) + y * math.sin(th)
            perp = -x * math.sin(th) + y * math.cos(th) + 0.04 * np.sin(along * 20 + th)
            c = np.exp(-(perp / 0.012) ** 2) * (along > 0) * np.clip(1 - along / ln, 0, 1)
            rgb = rgb * (1 - c[..., None]) + np.array([0.08, 0.08, 0.08]) * c[..., None]
            a = np.maximum(a, c)
    else:
        ring = smoothstep(0.32 + rough * 0.15, 0.18, d)  # bare bright metal scuff
        rgb += np.array([0.78, 0.76, 0.72]) * ring[..., None]
        a = np.maximum(a, ring * 0.9)
        soot = smoothstep(0.6 + rough * 0.2, 0.25, d) * (1 - ring)
        rgb = rgb * (1 - soot[..., None] * 0.6)
        a = np.maximum(a, soot * 0.55)
    hole = smoothstep(hole_r + 0.02, hole_r - 0.01, d + rough * 0.05)
    rgb = rgb * (1 - hole[..., None]) + np.array([0.02, 0.02, 0.02]) * hole[..., None]
    a = np.maximum(a, hole)
    return rgba(rgb, a)


def _splat(n, rng, color, soft=False):
    x, y = grid(n)
    a = np.zeros((n, n), np.float32)
    for _ in range(int(rng.integers(5, 9))):
        cx, cy = rng.normal(0, 0.18, 2)
        r = rng.uniform(0.12, 0.3)
        a = np.maximum(a, smoothstep(r, r * 0.7, np.sqrt((x - cx) ** 2 + (y - cy) ** 2)))
    for _ in range(int(rng.integers(8, 16))):  # droplets
        th = rng.uniform(0, 2 * math.pi)
        dd = rng.uniform(0.45, 0.9)
        r = rng.uniform(0.02, 0.06)
        a = np.maximum(a, smoothstep(r, r * 0.6, np.sqrt((x - math.cos(th) * dd) ** 2 + (y - math.sin(th) * dd) ** 2)))
    a = warp(a, int(rng.integers(1e6)), 4)
    if soft:
        a = gaussian_filter(a, 2)
    shade = 0.75 + 0.25 * fbm(n, n, int(rng.integers(1e6)), 3, 4)
    rgb = np.array(color)[None, None, :] * shade[..., None]
    rgb = rgb * (0.7 + 0.3 * smoothstep(0.3, 1.0, a))[..., None]
    return rgba(rgb, a)


def _scorch(n, rng):
    x, y = grid(n)
    d = np.sqrt(x ** 2 + y ** 2) + (fbm(n, n, int(rng.integers(1e6)), 5, 4) - 0.5) * 0.5
    a = smoothstep(0.95, 0.2, d) ** 1.2
    rgb = np.dstack([0.03 + 0.05 * smoothstep(0.2, 0.9, d)] * 3)
    return rgba(rgb, a * 0.95)


def _puddle(n, rng):
    x, y = grid(n)
    d = np.sqrt((x * 0.8) ** 2 + y ** 2) + (fbm(n, n, int(rng.integers(1e6)), 4, 3) - 0.5) * 0.6
    a = smoothstep(0.8, 0.7, d)
    edge = np.exp(-((d - 0.74) / 0.04) ** 2)
    rgb = np.dstack([0.85 + 0.15 * edge] * 3)
    return rgba(rgb, a)


def decals(n=128):
    rng = np.random.default_rng(11)
    holes = [_hole(n, rng, False) for _ in range(4)] + [_hole(n, rng, True) for _ in range(4)]
    save("decal_bullet_holes", sheet(holes, 4), "blend",
         "row 0: holes in bare metal (scuffed ring, soot); row 1: holes in clinical panels (chipped paint, cracks)",
         8, 4)
    ichor = (0.62, 0.68, 0.18)
    sp = [_splat(n, rng, ichor) for _ in range(4)] + [_scorch(n, rng), _scorch(n, rng)] + \
         [_puddle(n, rng), _puddle(n, rng)]
    save("decal_splats", sheet(sp, 4), "blend",
         "0-3 stalker ichor splats (sickly yellow-green; re-tint if the stalker's blood changes); "
         "4-5 scorch marks (explosions, cutter burns); 6-7 puddle shapes for acid/slime pools (white, tint; "
         "pair with liquid_noise)", 8, 4)
    return holes + sp


def liquid_noise(n=256):
    """Seamless noise: R and G two scales for a scrolling acid/slime surface shader, B cells for
    bubble placement."""
    r = fbm(n, n, 51, 5, 4)
    g = fbm(n, n, 52, 4, 8)
    b = fbm(n, n, 53, 3, 6) ** 3
    img = np.dstack([r, g, b, np.ones_like(r)])
    save("liquid_noise", img, "data",
         "seamless; R/G noise at two scales to scroll against each other for the pool surface "
         "(emission + slow distortion), B for bubble spots", 1, 1)


# ---------------------------------------------------------------- previews

def preview(anims):
    """An animated GIF of the flipbooks side by side, plus a contact sheet of every texture."""
    os.makedirs(PREVIEW, exist_ok=True)
    tile = 160
    names = list(anims)
    bg = (22, 24, 27)
    gif = []
    for f in range(64):
        canvas = Image.new("RGB", (tile * len(names), tile + 22), bg)
        dr = ImageDraw.Draw(canvas)
        for i, nm in enumerate(names):
            frames, mode = anims[nm]
            fr = frames[f % len(frames)]
            im = Image.fromarray((np.clip(fr, 0, 1) * 255).astype(np.uint8), "RGBA").resize((tile - 10, tile - 10))
            if mode == "add":
                arr = np.asarray(im).astype(np.float32) / 255
                rgb = np.asarray(Image.new("RGB", im.size, bg)).astype(np.float32) / 255 + arr[..., :3] * arr[..., 3:4]
                canvas.paste(Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)), (i * tile + 5, 5))
            else:
                tint = {"smoke_puff": (0.75, 0.75, 0.78), "impact_dust": (0.8, 0.72, 0.6),
                        "acid_bubble": (0.55, 1.0, 0.25)}.get(nm, (1, 1, 1))
                arr = np.asarray(im).astype(np.float32) / 255
                base = np.asarray(Image.new("RGB", im.size, bg)).astype(np.float32) / 255
                rgb = base * (1 - arr[..., 3:4]) + arr[..., :3] * np.array(tint) * arr[..., 3:4]
                canvas.paste(Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)), (i * tile + 5, 5))
            dr.text((i * tile + 8, tile + 4), nm, fill=(200, 200, 200))
        gif.append(canvas)
    gif[0].save(os.path.join(PREVIEW, "flipbooks.gif"), save_all=True, append_images=gif[1:], duration=40, loop=0)

    tiles = []
    for nm, meta in MANIFEST.items():
        im = Image.open(os.path.join(OUT, meta["file"])).convert("RGBA")
        im.thumbnail((360, 360))
        cell = Image.new("RGB", (380, 400), bg)
        if meta["blend"] == "add":
            arr = np.asarray(im).astype(np.float32) / 255
            rgb = 22 / 255 + arr[..., :3] * arr[..., 3:4]
            im2 = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
        else:
            back = Image.new("RGBA", im.size, (60, 64, 70, 255))
            im2 = Image.alpha_composite(back, im).convert("RGB")
        cell.paste(im2, (10, 10))
        ImageDraw.Draw(cell).text((10, 378), f"{nm} ({meta['blend']})", fill=(210, 210, 210))
        tiles.append(cell)
    cols = 4
    rows = math.ceil(len(tiles) / cols)
    cs = Image.new("RGB", (380 * cols, 400 * rows), bg)
    for i, t in enumerate(tiles):
        cs.paste(t, ((i % cols) * 380, (i // cols) * 400))
    cs.save(os.path.join(PREVIEW, "vfx_sheet.jpg"), quality=88)


def main():
    os.makedirs(OUT, exist_ok=True)
    anims = {}
    _, fr = smoke_puff()
    anims["smoke_puff"] = (fr, "blend")
    _, fr = impact_dust()
    anims["impact_dust"] = (fr, "blend")
    _, fr = fire_loop()
    anims["fire_loop"] = (fr, "add")
    _, fr = explosion()
    anims["explosion"] = (fr, "blend")
    _, fr = acid_bubble()
    anims["acid_bubble"] = (fr, "blend")
    _, fr = muzzle_flash()
    anims["muzzle_flash"] = ([fr[i // 8 % 8] for i in range(64)], "add")
    fr = electric_arcs()
    anims["electric_arc"] = ([fr[i // 3 % 4] for i in range(64)], "add")
    spark_textures()
    decals()
    liquid_noise()
    json.dump(MANIFEST, open(os.path.join(OUT, "manifest.json"), "w"), indent=1)
    preview(anims)
    print("wrote", len(MANIFEST), "textures to", OUT)


if __name__ == "__main__":
    main()
