"""Rebuild A005 review layouts from preserved ImageGen masters. Layout/resampling only."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "assets/source/A005-dev"
OUT = Path(__file__).resolve().parent
BG = "#10171d"
FG = "#e8e5d9"
MUTED = "#a6b4bd"
AMBER = "#edb84e"
FONT = "/System/Library/Fonts/Supplemental/Arial.ttf"
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

def label(draw, xy, text, size=24, fill=FG, bold=False):
    draw.text(xy, text, font=ImageFont.truetype(BOLD if bold else FONT, size), fill=fill)

def place_fit(canvas, image, box):
    x, y, w, h = box
    image = ImageOps.contain(image, (w, h), Image.Resampling.LANCZOS)
    canvas.paste(image, (x + (w-image.width)//2, y + (h-image.height)//2))

def camera_sheet(asset, crop):
    master = Image.open(SRC / f"{asset}-render.png").convert("RGB").crop(crop)
    small = master.resize((round(master.width * 96/master.height), 96), Image.Resampling.LANCZOS)
    zoom = small.resize((small.width * 4, 384), Image.Resampling.NEAREST)
    canvas = Image.new("RGB", (1200, 720), BG)
    d = ImageDraw.Draw(canvas)
    label(d, (40, 24), f"{asset} / HAULER CAMERA READ", 32, bold=True)
    label(d, (40, 72), "Steep overhead three-quarter / orange crown, shoulders, pack and rifle", 23, MUTED)
    for cx, im, title in [(280, small, "GAME-SIZE PROXY / 96 px"), (840, zoom, "4x / 384 px")]:
        d.rectangle((cx-240, 146, cx+240, 580), fill="#252b30", outline="#47535b")
        canvas.paste(im, (cx-im.width//2, 365-im.height//2))
        label(d, (cx-220, 112), title, 22, AMBER, True)
    label(d, (40, 614), "The 4x panel enlarges the same downsampled pixels; no extra detail is invented.", 23)
    label(d, (40, 652), "96 px is a review proxy. Actual game-camera scale still needs playtest approval.", 22, MUTED)
    canvas.save(SRC / f"{asset}.png")
    return {"asset": asset, "crop": crop, "proxy_size": small.size, "zoom_size": zoom.size}

def logo_sheet(asset):
    master = Image.open(SRC / f"{asset}-render.png").convert("RGB")
    regions = [
        ("HULL STENCIL / PRIMARY", (225, 73, 1211, 278)),
        ("CRACKED VISOR / VARIANT", (337, 284, 1082, 677)),
        ("RAT CREW PATCH / EMBLEM", (499, 685, 901, 1063)),
    ]
    canvas = Image.new("RGB", (1600, 1400), BG)
    d = ImageDraw.Draw(canvas)
    label(d, (40, 25), f"{asset} / GRAVE RATS LOGO FAMILY", 36, bold=True)
    label(d, (40, 78), "Large artwork + exact 64 px-tall review samples / cream, amber, charcoal", 25, MUTED)
    for i, (title, crop) in enumerate(regions):
        y = 142 + i*405
        d.line((40, y, 1560, y), fill="#44535d", width=2)
        label(d, (40, y+14), title, 25, AMBER, True)
        mark = master.crop(crop)
        place_fit(canvas, mark, (40, y+62, 1020, 285))
        tiny = mark.resize((round(mark.width*64/mark.height), 64), Image.Resampling.LANCZOS)
        canvas.paste(tiny, (1110, y+160))
        label(d, (1110, y+120), "64 px tall / 1:1", 22, MUTED)
        label(d, (1110, y+244), f"{tiny.width} x 64 px", 19, MUTED)
    label(d, (40, 1370), "Review raster masters; small samples are not independently generated.", 19, MUTED)
    canvas.save(SRC / f"{asset}.png")

def contact_sheet():
    entries = [
        ("A005-01b", "Front / back / side + 1.80 m", "Revised profile; preferred over 01"),
        ("A005-02", "Three-quarter + component details", "RIFLE GRIP is a cutter; 02b correction refused"),
        ("A005-03b", "Overhead / 96 px + exact 4x", "Steeper camera; preferred over 03"),
        ("A005-04", "Four builds / company-issue suit family", "Height guides are approximate; see handoff"),
        ("A005-05", "Suit OS / normal state + ammo ring", "Rental watermark + oxygen billed per minute"),
        ("A005-06b", "Suit OS / acid, low ammo, in cover", "Explicit LOW AMMO; preferred over 06"),
        ("A005-07", "Airlock cutter + approaching crew mate", "Two crew / dark upper-left logo space"),
        ("A005-08b", "Hull stencil / visor / rat patch", "Large + exact 64 px samples; cleaner revision"),
    ]
    canvas = Image.new("RGB", (2400, 3280), BG)
    d = ImageDraw.Draw(canvas)
    label(d, (40, 25), "GRAVE RATS / A005 DEVELOPMENT REVIEW", 46, bold=True)
    label(d, (40, 90), "Human approval pending / modelling, crew, suit OS, title and logo", 29, MUTED)
    for i, (asset, title, note) in enumerate(entries):
        x = 40 + (i % 2)*1180
        y = 160 + (i // 2)*770
        label(d, (x, y), f"{asset} / {title}", 29, AMBER, True)
        im = Image.open(SRC / f"{asset}.png").convert("RGB")
        place_fit(canvas, im, (x, y+52, 1140, 645))
        label(d, (x, y+711), note, 25, MUTED)
    label(d, (40, 3250), "Source prompts + revision history: assets/source/A005-dev / report: docs/handoffs/auto-A005.md", 22, MUTED)
    canvas.save(OUT / "sheet.png")

if __name__ == "__main__":
    print(camera_sheet("A005-03", (306, 40, 1128, 1184)))
    print(camera_sheet("A005-03b", (127, 104, 1180, 1176)))
    logo_sheet("A005-08")
    logo_sheet("A005-08b")
    contact_sheet()
