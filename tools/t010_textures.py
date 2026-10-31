#!/usr/bin/env python3
"""T010: procedural textures and signage decals for the slice kit. Values: data/kit.json.

Every set grows from one height/mask stack, so albedo, normal and ORM agree. All tile except the
door leaf. ORM: R AO, G roughness, B metalness. Normals: OpenGL. Grime stays out of the textures:
the kit paints it low and in corners with vertex colours.

Writes assets/game/kit/tex/<set>_{albedo,normal,orm}.png, assets/game/kit/decals/<name>.png and the
matching .import settings (mipmaps, VRAM compression, normal maps). Reads the art lane's sheet, never
writes to it. Then: godot --headless --path . --import

Run: python3 tools/t010_textures.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion, gaussian_filter, label

ROOT = Path(__file__).resolve().parents[1]
CFG = json.loads((ROOT / "data/kit.json").read_text())
TEX = ROOT / "assets/game/kit/tex"
DEC = ROOT / "assets/game/kit/decals"


def rgb(hexstr):
    return np.array([int(hexstr[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def fbm(n, beta=2.2, lo=2, seed=0, shape=None):
    """Tileable fractal noise in 0..1 (spectral synthesis, periodic by construction)."""
    h, w = shape if shape else (n, n)
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.standard_normal((h, w)))
    ky = np.fft.fftfreq(h)[:, None] * h
    kx = np.fft.fftfreq(w)[None, :] * w
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1
    amp = 1 / k ** (beta / 2)
    amp[k < lo] = 0
    out = np.real(np.fft.ifft2(f * amp))
    out -= out.min()
    return (out / out.max()).astype(np.float32)


def blur(a, r):
    return gaussian_filter(np.asarray(a, np.float32), r, mode="wrap") if r > 0 else a


def smooth(lo, hi, a):
    t = np.clip((a - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def threshold_for(a, cover):
    """The value above which `cover` of the image lies."""
    return float(np.quantile(a, 1.0 - cover))


def scratches(n, count, seed, length=(0.04, 0.3), shape=None):
    """Hairlines, wrapped so they tile. 1 on a scratch."""
    h, w = shape if shape else (n, n)
    r = np.random.default_rng(seed)
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    for _ in range(count):
        x, y = r.random() * w, r.random() * h
        a, ln = r.random() * np.pi * 2, r.uniform(*length) * n
        dx, dy = np.cos(a) * ln, np.sin(a) * ln
        v = int(r.uniform(90, 255))
        for ox in (-w, 0, w):
            for oy in (-h, 0, h):
                d.line((x + ox, y + oy, x + dx + ox, y + dy + oy), fill=v, width=1)
    return np.asarray(im, np.float32) / 255.0


def normal_from(height, strength):
    gy, gx = np.gradient(height)
    nx, ny = -gx * strength, gy * strength  # OpenGL: green points up the image
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.dstack([nx / length, ny / length, nz / length]) * 0.5 + 0.5


def save(name, albedo, normal, ao, rough, metal):
    TEX.mkdir(parents=True, exist_ok=True)
    def png(arr, suffix):
        Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).save(TEX / f"{name}_{suffix}.png", optimize=True)
    png(albedo, "albedo")
    png(normal, "normal")
    png(np.dstack([ao, rough, metal]), "orm")
    write_import(TEX / f"{name}_albedo.png", normal_map=False)
    write_import(TEX / f"{name}_normal.png", normal_map=True)
    write_import(TEX / f"{name}_orm.png", normal_map=False)


def write_import(path, normal_map, vram=True):
    """Settings Godot keeps on import: without these a headless import makes no mipmaps."""
    rel = path.relative_to(ROOT).as_posix()
    imp = path.with_name(path.name + ".import")
    old_uid = ""
    if imp.exists():
        for line in imp.read_text().splitlines():
            if line.startswith("uid="):
                old_uid = line + "\n"
    imp.write_text(
        '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n' + old_uid
        + f'\n[deps]\n\nsource_file="res://{rel}"\n\n[params]\n\n'
        + f"compress/mode={2 if vram else 0}\ncompress/high_quality=false\ncompress/lossy_quality=0.8\n"
        + f"compress/normal_map={1 if normal_map else 2}\ncompress/channel_pack=0\n"
        + f"mipmaps/generate={'true' if vram else 'false'}\nmipmaps/limit=-1\ndetect_3d/compress_to=0\n")


def paint_set(name):
    """Chipped paint over steel: hull, graphite trim, clinical enamel."""
    c = CFG["textures"][name]
    n, seed = c["px"], c["seed"]
    field = fbm(n, 2.7, 4, seed) * 0.8 + fbm(n, 1.9, 40, seed + 1) * 0.2
    # `cover` of the surface keeps its paint; chips grow where the field is low.
    t = threshold_for(field, c["cover"])
    paint = smooth(t - 0.004, t + 0.004, field)
    rim = np.clip(blur(1 - paint, 2.0) * paint * 2.2, 0, 1)
    tone = fbm(n, 2.6, 2, seed + 2)
    hair = scratches(n, n // 6, seed + 3)
    albedo = rgb(c["paint"])[None, None] * (0.88 + 0.12 * tone)[..., None]
    albedo = albedo * (1 - 0.3 * hair)[..., None]
    steel = rgb(c["steel"])[None, None] * (0.75 + 0.5 * fbm(n, 1.6, 30, seed + 4))[..., None]
    albedo = albedo * paint[..., None] + steel * (1 - paint)[..., None]
    albedo = albedo * (1 - rim * 0.65)[..., None] + rgb(c["rust"])[None, None] * (rim * 0.65)[..., None]
    rp, rs = c["rough_paint"], c["rough_steel"]
    rough = (rp[0] + (rp[1] - rp[0]) * tone) * paint + (rs[0] + (rs[1] - rs[0]) * tone) * (1 - paint)
    metal = 1 - paint
    height = blur(paint, 1.0) * 1.3 + fbm(n, 2.0, 12, seed + 5) * 0.7 - hair * 0.25
    ao = 1 - 0.3 * blur(1 - paint, 2.5)
    save(name, albedo, normal_from(height, 3.0), ao, rough, metal)


def deck():
    c = CFG["textures"]["deck"]
    n, seed = c["px"], c["seed"]
    # The hammered, crinkled steel of the paint-overs: ridged noise at two scales.
    a = fbm(n, 2.1, 10, seed)
    b = fbm(n, 2.0, 26, seed + 1)
    ridged = (1 - np.abs(a * 2 - 1)) * 0.65 + (1 - np.abs(b * 2 - 1)) * 0.35
    ridged = (ridged - ridged.min()) / (ridged.max() - ridged.min())
    tone = fbm(n, 2.6, 2, seed + 2)
    stain = fbm(n, 2.6, 4, seed + 3)
    t = threshold_for(stain, c["stain_cover"])
    stains = smooth(t, t + 0.16, stain) * c["stain_strength"]
    specks = fbm(n, 1.3, 60, seed + 6)
    t = threshold_for(specks, 0.03)
    specks = smooth(t, t + 0.02, specks)
    albedo = rgb(c["base"])[None, None] * (0.82 + 0.3 * tone)[..., None]
    albedo = albedo * (0.86 + 0.2 * ridged)[..., None]
    albedo = albedo * (1 - stains)[..., None] + rgb(c["dark"])[None, None] * stains[..., None]
    albedo = albedo * (1 - specks * 0.6)[..., None]
    polish = fbm(n, 2.8, 3, seed + 4)
    t = threshold_for(polish, c["polish_cover"])
    damp = blur(smooth(t, t + 0.2, polish), 6.0)
    r0, r1 = c["rough"], c["polish_rough"]
    rough = r0[0] + (r0[1] - r0[0]) * (ridged * 0.5 + stains * 0.5)
    rough = rough * (1 - damp) + (r1[0] + (r1[1] - r1[0]) * tone) * damp
    height = ridged * 1.0 + fbm(n, 1.7, 40, seed + 5) * 0.3
    metal = np.full((n, n), c["metal"], np.float32)
    ao = 1 - 0.15 * stains
    save("deck", albedo, normal_from(height, 2.6), ao, rough, metal)


def grate():
    c = CFG["textures"]["grate"]
    n, seed = c["px"], c["seed"]
    yy, xx = np.mgrid[0:n, 0:n] / n
    # Rounded slots on a grid.
    fx = (xx * c["cols"]) % 1.0 - 0.5
    fy = (yy * c["rows"]) % 1.0 - 0.5
    qx = np.maximum(np.abs(fx) - 0.38, 0)
    qy = np.maximum(np.abs(fy) - 0.24, 0)
    hole = smooth(0.05, 0.015, np.hypot(qx / c["rows"] * c["cols"], qy))
    tone = fbm(n, 2.2, 3, seed)
    albedo = rgb(c["bar"])[None, None] * (0.6 + 0.7 * tone)[..., None] * (1 - hole)[..., None]
    albedo = albedo + rgb(c["hole"])[None, None] * hole[..., None]
    r = c["rough"]
    rough = r[0] + (r[1] - r[0]) * tone
    height = (1 - blur(hole, 1.6)) * 4 + fbm(n, 1.8, 20, seed + 1) * 0.3
    metal = c["metal"] * (1 - hole)
    save("grate", albedo, normal_from(height, 2.2), 1 - 0.85 * hole, rough, metal)


def hazard(name="hazard"):
    c = CFG["textures"][name]
    n, seed = c["px"], c["seed"]
    yy, xx = np.mgrid[0:n, 0:n] / n
    worn = fbm(n, 2.4, 4, seed) * 0.7 + fbm(n, 1.7, 26, seed + 1) * 0.3
    if name == "hazard":
        s = (xx + yy) * c["stripes"]
        band = smooth(0.49, 0.51, np.abs((s % 1.0) - 0.5) * 2)
        t = threshold_for(worn, 0.86)
        yellow = band * smooth(t - 0.01, t + 0.01, worn)
    else:
        t = threshold_for(worn, 0.8)
        yellow = smooth(t - 0.02, t + 0.02, worn)
    tone = fbm(n, 2.6, 2, seed + 2)
    albedo = rgb(c["yellow"])[None, None] * (0.75 + 0.3 * tone)[..., None] * yellow[..., None]
    albedo = albedo + rgb(c["dark"])[None, None] * (0.8 + 0.4 * tone)[..., None] * (1 - yellow)[..., None]
    r = c["rough"]
    height = blur(yellow, 0.8) * 1.2 + fbm(n, 1.8, 20, seed + 3) * 0.4
    save(name, albedo, normal_from(height, 2.2), np.ones((n, n), np.float32), r[0] + (r[1] - r[0]) * tone, np.zeros((n, n), np.float32))


def rubber():
    c = CFG["textures"]["rubber"]
    n, seed = c["px"], c["seed"]
    yy, xx = np.mgrid[0:n, 0:n] / n
    k = c["dimples"]
    fx = (xx * k) % 1.0 - 0.5
    fy = (yy * k + np.floor(xx * k) * 0.5) % 1.0 - 0.5
    dimple = smooth(0.42, 0.2, np.hypot(fx, fy))
    tone = fbm(n, 2.4, 3, seed)
    albedo = rgb(c["base"])[None, None] * (0.8 + 0.6 * tone)[..., None]
    r = c["rough"]
    save("rubber", albedo, normal_from(dimple, 1.6), 1 - 0.25 * dimple, r[0] + (r[1] - r[0]) * tone, np.zeros((n, n), np.float32))


def leaf():
    """One door leaf, not tiling: the hull paint, its hazard band by the lock edge, handles, a rim."""
    c = CFG["textures"]["leaf"]
    w, h = c["size"]
    seed = c["seed"]
    hull = CFG["textures"]["hull"]
    field = fbm(0, 2.5, 3, seed, (h, w)) * 0.72 + fbm(0, 1.7, 24, seed + 1, (h, w)) * 0.28
    t = threshold_for(field, hull["cover"])
    paint = smooth(t - 0.004, t + 0.004, field)
    tone = fbm(0, 2.6, 2, seed + 2, (h, w))
    hair = scratches(w, w // 5, seed + 3, shape=(h, w))
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, yy / h
    ivory = rgb(hull["paint"])[None, None] * (0.82 + 0.18 * tone)[..., None] * (1 - 0.3 * hair)[..., None]
    haz = CFG["textures"]["hazard"]
    b0, b1 = c["band"]
    in_band = smooth(b0 - 0.002, b0 + 0.002, u) * smooth(b1 + 0.002, b1 - 0.002, u)
    stripe = smooth(0.48, 0.52, np.abs((((u * w + v * h) / w * 6) % 1.0) - 0.5) * 2)
    band = rgb(haz["yellow"])[None, None] * stripe[..., None] + rgb(haz["dark"])[None, None] * (1 - stripe)[..., None]
    surface = ivory * (1 - in_band)[..., None] + band * in_band[..., None]
    steel = rgb(hull["steel"])[None, None] * (0.75 + 0.5 * tone)[..., None]
    albedo = surface * paint[..., None] + steel * (1 - paint)[..., None]
    # A dark rim, a recessed panel line, and the pull handle.
    edge = np.minimum(np.minimum(u, 1 - u) * w, np.minimum(v, 1 - v) * h)
    rim = smooth(26, 18, edge)
    line = smooth(4, 1.5, np.abs(edge - 46))
    handle = ((np.abs(u - 0.7) < 0.022) & (np.abs(v - 0.5) < 0.07)).astype(np.float32)
    dark = np.clip(rim + line + handle, 0, 1)
    albedo = albedo * (1 - dark * 0.9)[..., None]
    rp, rs = hull["rough_paint"], hull["rough_steel"]
    rough = (rp[0] + (rp[1] - rp[0]) * tone) * paint + (rs[0] + (rs[1] - rs[0]) * tone) * (1 - paint)
    height = blur(paint, 1.0) * 1.2 + rim * -4 + line * -2 + handle * 5 - hair * 0.2
    save("leaf", albedo, normal_from(height, 3.0), 1 - 0.4 * line, rough, 1 - paint)


def decals():
    """Cuts signage out of the art lane's sheet: the sheet's grey goes transparent, ink stays."""
    d = CFG["decals"]
    DEC.mkdir(parents=True, exist_ok=True)
    src = np.asarray(Image.open(ROOT / d["source"]).convert("RGB"), np.float32) / 255.0
    for i, (name, it) in enumerate(d["items"].items()):
        x0, y0, x1, y1 = it["box"]
        crop = src[y0:y1, x0:x1]
        lo = crop.min(axis=2)
        hi = crop.max(axis=2)
        # The sheet's grey: light and colourless.
        grey = (lo > 0.72) & (hi - lo < 0.045)
        if it["mode"] == "outline":
            # A framed sign keeps everything inside its frame: only grey touching the crop goes.
            lab, _ = label(grey)
            edge = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
            edge.discard(0)
            gone = np.isin(lab, list(edge))
        else:
            gone = grey
        keep = binary_erosion(~gone, iterations=1)
        alpha = keep.astype(np.float32)
        # Painted-on wear, so stencils look stencilled.
        worn = fbm(0, 2.0, 16, 400 + i, alpha.shape)
        alpha = alpha * (worn > threshold_for(worn, 1.0 - d["wear"]))
        if "ink" in it:
            # Floor stencils: black ink vanishes on a dark deck, so it's repainted.
            dark = (hi < 0.35)[..., None]
            crop = crop * (~dark) + rgb(it["ink"])[None, None] * dark
        Image.fromarray((np.dstack([crop, alpha]) * 255 + 0.5).astype(np.uint8), "RGBA").save(DEC / f"{name}.png", optimize=True)
        write_import(DEC / f"{name}.png", normal_map=False)


if __name__ == "__main__":
    for s in ("hull", "steel", "clinical"):
        paint_set(s)
    deck()
    grate()
    hazard("hazard")
    hazard("hazard_line")
    rubber()
    leaf()
    decals()
    print("textures:", sorted(p.name for p in TEX.glob("*_albedo.png")))
    print("decals:", sorted(p.name for p in DEC.glob("*.png")))
