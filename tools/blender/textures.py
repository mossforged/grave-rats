"""Dead Circuit texture authoring.

Every set is generated from ONE authored height/mask stack, so albedo, normal,
roughness, metalness and AO agree with each other (unlike the old prototype,
which reused colour maps as bump maps). All maps tile seamlessly.

Output: dist/assets/tex/<set>_{albedo,normal,orm}.jpg  (ORM = R:AO G:roughness B:metalness, glTF layout)
Run:   python3 assets-src/textures.py
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'source', 'legacy-pass05', 'tex')
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(1049)


# ---------------------------------------------------------------- primitives
def fbm(n, beta=2.2, lo=2, seed=None):
    """Tileable fractal noise in 0..1 using spectral synthesis (periodic by construction)."""
    r = np.random.default_rng(seed) if seed is not None else RNG
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(n)[:, None] * n
    kx = np.fft.fftfreq(n)[None, :] * n
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1
    amp = 1 / k ** (beta / 2)
    amp[k < lo] = 0
    out = np.real(np.fft.ifft2(f * amp))
    out -= out.min(); out /= out.max()
    return out


def blur(a, r):
    if r <= 0: return a
    from scipy.ndimage import gaussian_filter
    return gaussian_filter(np.asarray(a, np.float32), r, mode='wrap')


def canvas(n, val=0.0):
    return Image.new('F', (n, n), val)


def wrapdraw(img, fn):
    """Draw fn(draw, ox, oy) at the 9 wrapped offsets so shapes crossing edges tile."""
    d = ImageDraw.Draw(img)
    n = img.size[0]
    for ox in (-n, 0, n):
        for oy in (-n, 0, n):
            fn(d, ox, oy)


def arr(img):
    return np.asarray(img, dtype=np.float32)


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + 1)
    # OpenGL/glTF convention: +Y up in tangent space (green = up). Image row 0 is top (v=1).
    n = np.stack([-dx / l, dy / l, nz / l], -1)
    return n * 0.5 + 0.5


def cavity_ao(h, r=6, k=3.0):
    ao = 1 - np.clip((blur(h, r) - h) * k, 0, 1)
    ao *= 1 - np.clip((blur(h, r * 3) - h) * k * .5, 0, .35)
    return np.clip(ao, 0, 1)


def scratches(n, count, length, width=1, seed=None, angle=None):
    r = np.random.default_rng(seed)
    img = canvas(n)
    def fn(d, ox, oy):
        rr = np.random.default_rng(seed)
        for _ in range(count):
            x, y = rr.random() * n, rr.random() * n
            a = rr.random() * math.tau if angle is None else angle + rr.normal() * .25
            L = length * (.3 + rr.random())
            pts = [(x + ox, y + oy)]
            for s in range(4):
                a += rr.normal() * .08
                x += math.cos(a) * L / 4; y += math.sin(a) * L / 4
                pts.append((x + ox, y + oy))
            d.line(pts, fill=float(.4 + rr.random() * .6), width=width)
    wrapdraw(img, fn)
    return arr(img)


def save(name, albedo, normal, ao, rough, metal):
    def u8(a):
        return (np.clip(a, 0, 1) * 255 + .5).astype(np.uint8)
    Image.fromarray(u8(albedo), 'RGB').save(os.path.join(OUT, f'{name}_albedo.jpg'), quality=90)
    Image.fromarray(u8(normal), 'RGB').save(os.path.join(OUT, f'{name}_normal.jpg'), quality=94)
    orm = np.stack([ao, rough, metal], -1)
    Image.fromarray(u8(orm), 'RGB').save(os.path.join(OUT, f'{name}_orm.jpg'), quality=92)
    print('wrote', name)


def tint(mask_rgb_pairs, n):
    out = np.zeros((n, n, 3), np.float32)
    for m, c in mask_rgb_pairs:
        out = out * (1 - m[..., None]) + np.array(c, np.float32)[None, None] * m[..., None]
    return out


def srgb(hexs):
    hexs = hexs.lstrip('#')
    return [int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def bolt(d, x, y, r, val=1.0):
    d.ellipse((x - r, y - r, x + r, y + r), fill=val)


# ---------------------------------------------------------------- sets
def floor_plate(n=1024):
    """One deck tile (2.2 m): four plates, recessed seams, bolts, one tread plate."""
    h = canvas(n, .55)
    plate_id = np.zeros((n, n), np.float32)
    seam = 6
    W = int(n * .64)  # one large deck plate + two service plates: breaks the 1.1 m grid
    rects = [(0, 0, W, n), (W, 0, n, n // 2 - 40), (W, n // 2 - 40, n, n)]
    def fn(d, ox, oy):
        for (x0, y0, x1, y1) in rects:
            x0, y0, x1, y1 = x0 + ox, y0 + oy, x1 + ox, y1 + oy
            d.rectangle((x0, y0, x1, y1), outline=0.0, width=seam)
            d.rectangle((x0 + seam + 8, y0 + seam + 8, x1 - seam - 8, y1 - seam - 8), outline=.5, width=2)
            for bx in (x0 + 22, x1 - 22):
                for by in (y0 + 22, y1 - 22):
                    bolt(d, bx, by, 9, .36); bolt(d, bx, by, 6, .76)
        # flush access panel with lift slots on the main plate
        d.rectangle((ox + 120, oy + 300, ox + 300, oy + 460), outline=.32, width=3)
        for k in range(2):
            d.rectangle((ox + 170 + k * 60, oy + 370, ox + 200 + k * 60, oy + 384), fill=.2)
    wrapdraw(h, fn)
    h = arr(h).copy()
    # diamond tread on plate (1,0)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    tread_mask = ((xx > W + 20) & (xx < n - 20) & (yy > n // 2 - 20) & (yy < n - 20)).astype(np.float32)
    u = (xx + yy) / 22.0; v = (xx - yy) / 22.0
    diam = np.clip(1 - (np.abs(np.sin(u * math.pi)) * 3 + np.abs(np.sin(v * math.pi * 2.0)) * .6), 0, 1)
    h += tread_mask * diam * .12
    # per-plate value variation
    var = np.zeros((n, n), np.float32)
    for (x0, y0, x1, y1) in rects:
        var[y0:y1, x0:x1] = RNG.uniform(-.05, .05)
    dents = fbm(n, 2.6, 6, seed=3)
    h += (dents - .5) * .025
    sc = scratches(n, 260, 70, 1, seed=11)
    h -= sc * .02
    seams = (h < .2).astype(np.float32)
    seams = np.clip(blur(seams, 2.5), 0, 1)
    # traffic wear: lighter, polished paths where paint is worn
    wear = np.clip((fbm(n, 2.0, 2, seed=5) - .55) * 3 + sc * .8, 0, 1)
    grime = np.clip(fbm(n, 2.6, 3, seed=7) * 1.3 - .25, 0, 1)
    stains = np.clip((fbm(n, 2.8, 3, seed=9) - .62) * 5, 0, 1)
    ao = cavity_ao(h, 5, 4)
    base = np.array(srgb('#6f7472'))
    alb = np.ones((n, n, 3)) * base * (1 + var[..., None])
    alb = alb * (1 - .13 * grime[..., None])
    alb = alb * (1 - wear[..., None] * .25) + np.array(srgb('#a9aca5')) * wear[..., None] * .25
    alb = alb * (1 - stains[..., None] * .28) + np.array(srgb('#1d1a16'))[None, None] * stains[..., None] * .12
    alb *= (1 - seams[..., None] * .6)
    alb *= ao[..., None] ** .6
    rough = np.clip(.72 - wear * .3 - stains * .35 + grime * .1 + seams * .2, .12, 1)
    metal = np.clip(.25 + wear * .55 - seams * .2, 0, 1)
    save('floor_plate', alb, normal_from_height(h, 9), ao, rough, metal)


def floor_grate(n=512):
    """Corridor drainage grating: bars over a dark sump."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    bars = (np.abs(((xx / n) * 16) % 1 - .5) < .3).astype(np.float32)
    cross = (np.abs(((yy / n) * 4) % 1 - .5) > .44).astype(np.float32)
    solid = np.clip(bars + cross, 0, 1)
    solid = blur(solid, 1.2)
    h = solid * .7 + .05
    rust = np.clip((fbm(n, 2.4, 3, seed=21) - .5) * 3, 0, 1)
    ao = cavity_ao(h, 4, 5)
    alb = np.ones((n, n, 3)) * np.array(srgb('#4f5554')) * solid[..., None] + np.array(srgb('#0b0d0e')) * (1 - solid[..., None])
    alb = alb * (1 - rust[..., None] * .4) + np.array(srgb('#5a3a22')) * rust[..., None] * .4 * solid[..., None]
    alb *= ao[..., None]
    rough = np.clip(.55 + rust * .3 + (1 - solid) * .4, 0, 1)
    metal = solid * (.8 - rust * .5)
    save('floor_grate', alb, normal_from_height(h, 7), ao, rough, metal)


def wall_panel(n=1024, name='wall_panel', paint='#7e8888', grime_amt=1.0):
    """Interior bulkhead panel. U = along wall (one 2.2 m bay), V = height (0 at floor, top at 2.6 m)."""
    h = canvas(n, .5)
    def fn(d, ox, oy):
        # two tall panels per bay, kick-plate band, upper vent strip
        for i in range(2):
            x0 = i * n // 2 + ox
            d.rectangle((x0, oy, x0 + n // 2, oy + n), outline=.1, width=6)
            d.rectangle((x0 + 30, oy + 120, x0 + n // 2 - 30, oy + n - 230), fill=.42, outline=.62, width=5)
            for by in (oy + 40, oy + n - 170, oy + n // 2):
                for bx in (x0 + 18, x0 + n // 2 - 18):
                    bolt(d, bx, by, 7, .3); bolt(d, bx, by, 5, .75)
        d.rectangle((ox, oy + n - 150, ox + n, oy + n - 140), fill=.15)  # kick plate seam (bottom, row ~ v=.14)
        for k in range(10):  # vent slits near top
            y = oy + 50 + k * 7
            d.rectangle((ox + n // 2 - 120, y, ox + n // 2 + 120, y + 3), fill=.08)
    wrapdraw(h, fn)
    h = arr(h).copy()
    h += (fbm(n, 2.6, 5, seed=31) - .5) * .02
    sc = scratches(n, 140, 50, 1, seed=33)
    h -= sc * .015
    yy = np.mgrid[0:n, 0:n][0].astype(np.float32) / n  # 0 top .. 1 bottom
    drip = blur(np.clip((fbm(n, 2.0, 1, seed=35) - .45) * 3, 0, 1), 1)
    streak = np.clip(np.asarray(Image.fromarray(fbm(n, 1.5, 2, seed=37).astype(np.float32), 'F').resize((n, 8)).resize((n, n), Image.BICUBIC)) - .4, 0, 1)
    grime = np.clip((yy ** 2.5) * 1.2 + streak * .5 * yy + drip * .2, 0, 1) * grime_amt
    kick = (yy > 1 - 145 / n).astype(np.float32)
    wear = np.clip(sc * 1.2 + np.clip((fbm(n, 2.4, 4, seed=39) - .7) * 4, 0, 1), 0, 1)
    ao = cavity_ao(h, 6, 4)
    paintc = np.array(srgb(paint))
    alb = np.ones((n, n, 3)) * paintc * (1 - kick[..., None]) + np.array(srgb('#3a4144')) * kick[..., None]
    alb = alb * (1 - grime[..., None] * .55) + np.array(srgb('#2b2620')) * grime[..., None] * .15
    alb = alb * (1 - wear[..., None]) + np.array(srgb('#8d8f8b')) * wear[..., None]
    alb *= ao[..., None] ** .7
    rough = np.clip(.6 + grime * .25 - wear * .25, 0, 1)
    metal = np.clip(.1 + wear * .7 + kick * .3, 0, 1)
    save(name, alb, normal_from_height(h, 8), ao, rough, metal)


def dark_metal(n=512):
    h = .5 + (fbm(n, 2.4, 4, seed=41) - .5) * .03
    sc = scratches(n, 400, 40, 1, seed=43)
    h = h - sc * .02
    edge = np.clip((fbm(n, 2.2, 3, seed=45) - .6) * 3, 0, 1)
    ao = cavity_ao(h, 4, 3)
    alb = np.ones((n, n, 3)) * np.array(srgb('#2b3134'))
    alb = alb * (1 - sc[..., None] * .5) + np.array(srgb('#6c706e')) * sc[..., None] * .5
    alb = alb * (1 - edge[..., None] * .3) + np.array(srgb('#1a1612')) * edge[..., None] * .3
    rough = np.clip(.5 + edge * .3 - sc * .2, 0, 1)
    metal = np.clip(.75 - edge * .3, 0, 1)
    save('dark_metal', alb, normal_from_height(h, 6), ao, rough, metal)


def painted(n, name, color, wear_amt=1.0, base_metal='#8e908c', stripes=False):
    """Painted steel (crates, suit plates, helmet). Optional hazard stripes."""
    h = .5 + (fbm(n, 2.6, 6, seed=51) - .5) * .015
    sc = scratches(n, 220, 30, 1, seed=53)
    chips = np.clip((fbm(n, 2.6, 8, seed=55) - .74) * 6, 0, 1) * wear_amt
    h = h - sc * .015 - chips * .02
    wear = np.clip(sc * .9 * wear_amt + chips, 0, 1)
    grime = np.clip((fbm(n, 2.0, 2, seed=57) - .35) * 1.4, 0, 1)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    col = np.ones((n, n, 3)) * np.array(srgb(color))
    if stripes:
        s = (((xx + yy) / (n / 6)) % 1 < .5).astype(np.float32)
        s = blur(s, 1)
        col = col * (1 - s[..., None]) + np.array(srgb('#151515')) * s[..., None]
    ao = cavity_ao(h, 4, 3)
    alb = col * (1 - grime[..., None] * .14)
    alb = alb * (1 - wear[..., None]) + np.array(srgb(base_metal)) * wear[..., None]
    alb *= ao[..., None] ** .5
    rough = np.clip(.5 + grime * .2 - wear * .15, 0, 1)
    metal = np.clip(wear * .85, 0, 1)
    save(name, alb, normal_from_height(h, 5), ao, rough, metal)


def suit_fabric(n=512, name='suit_fabric', color='#b8551f'):
    """Woven pressure-suit outer layer (rip-stop grid + quilting)."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    weave = (np.sin(xx / n * math.tau * 96) * np.sin(yy / n * math.tau * 96)) * .5 + .5
    rip = ((np.abs(((xx / n) * 16) % 1 - .5) > .47) | (np.abs(((yy / n) * 16) % 1 - .5) > .47)).astype(np.float32)
    quilt = np.abs(np.sin(xx / n * math.pi * 4)) * .3 + np.abs(np.sin(yy / n * math.pi * 4)) * .3
    h = weave * .03 + rip * .03 + quilt * .25 + (fbm(n, 2.2, 3, seed=61) - .5) * .05
    dirt = np.clip((fbm(n, 2.0, 2, seed=63) - .4) * 1.5, 0, 1)
    ao = cavity_ao(h, 5, 3)
    alb = np.ones((n, n, 3)) * np.array(srgb(color)) * (.92 + weave[..., None] * .08)
    alb = alb * (1 - dirt[..., None] * .35) + np.array(srgb('#3b2c22')) * dirt[..., None] * .1
    alb *= ao[..., None] ** .6
    rough = np.clip(.85 + dirt * .1, 0, 1)
    metal = np.zeros((n, n))
    save(name, alb, normal_from_height(h, 4), ao, rough, metal)


def rubber(n=256):
    h = .5 + (fbm(n, 2.8, 8, seed=71) - .5) * .05
    ao = cavity_ao(h, 3, 2)
    alb = np.ones((n, n, 3)) * np.array(srgb('#1b1e1f')) * (0.9 + fbm(n, 2, 2, seed=73)[..., None] * .2)
    save('rubber', alb, normal_from_height(h, 4), ao, np.full((n, n), .82), np.zeros((n, n)))


def medical_fabric(n=512):
    """Mattress / padding vinyl with stitched quilting and a dried blood stain."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    q = np.minimum(np.abs(((xx / n) * 3) % 1 - .5), np.abs(((yy / n) * 6) % 1 - .5))
    h = np.clip(q * 4, 0, 1) * .4 + (fbm(n, 2.3, 3, seed=81) - .5) * .06
    blood = np.clip((fbm(n, 2.6, 3, seed=83) - .62) * 6, 0, 1) * (((xx - n * .5) ** 2 + (yy - n * .45) ** 2) < (n * .3) ** 2)
    blood = blur(blood.astype(np.float32), 1.5)
    ao = cavity_ao(h, 5, 2)
    alb = np.ones((n, n, 3)) * np.array(srgb('#a9aca4'))
    alb = alb * (1 - blood[..., None] * .9) + np.array(srgb('#5a1410')) * blood[..., None] * .9
    alb *= ao[..., None] ** .7
    rough = np.clip(.6 - blood * .35, 0, 1)
    save('medical_fabric', alb, normal_from_height(h, 3), ao, rough, np.zeros((n, n)))


def hull_top(n=512):
    """Top face of thick structural bulkheads — the dark cut section seen from above."""
    h = canvas(n, .5)
    def fn(d, ox, oy):
        r = np.random.default_rng(91)
        for _ in range(26):
            x, y = r.random() * n + ox, r.random() * n + oy
            w, hh = 30 + r.random() * 160, 20 + r.random() * 90
            d.rectangle((x, y, x + w, y + hh), fill=float(.35 + r.random() * .4), outline=.2, width=3)
        for k in range(3):
            y = oy + 60 + k * 170
            d.rectangle((ox, y, ox + n, y + 14), fill=.75)
    wrapdraw(h, fn)
    h = arr(h).copy() + (fbm(n, 2.4, 4, seed=93) - .5) * .03
    ao = cavity_ao(h, 6, 4)
    alb = np.ones((n, n, 3)) * np.array(srgb('#262b2d')) * (0.75 + h[..., None] * .4)
    alb *= ao[..., None]
    save('hull_top', alb, normal_from_height(h, 6), ao, np.full((n, n), .6), np.full((n, n), .6))


if __name__ == '__main__':
    floor_plate(); floor_grate(); wall_panel(); wall_panel(name='wall_med', paint='#b9c0bc', grime_amt=.8)
    dark_metal(); painted(512, 'paint_yellow', '#c9a227', stripes=False); painted(512, 'paint_hazard', '#c9a227', stripes=True)
    painted(512, 'paint_orange', '#b8541b', wear_amt=.7); painted(512, 'paint_white', '#b4b8b2', wear_amt=.5)
    painted(512, 'paint_robot', '#323a3f', wear_amt=.6, base_metal='#5f6365')
    suit_fabric(); rubber(); medical_fabric(); hull_top()
