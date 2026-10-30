#!/usr/bin/env python3
"""T003 black-box check. Compares a capture with the muzzle flash, tracer and impact on against the
same pose without them, both under the asset viewer's post-processing (glow, SSAO, fog). Those
effects only add light, so a black box shows up as a block of pixels that got much darker.

usage: python3 tools/t003_blackbox.py <no_flash.png> <flash.png>   (needs Pillow; exits 1 on a box)
"""
import sys

from PIL import Image, ImageChops, ImageFilter

DARKER = 40           # a pixel counts when it lost this much on its brightest channel
MAX_BOX_SIDE = 24     # a black box is a solid block; thin slivers from the small recoil shift are not


def main(before_path, after_path):
    before = Image.open(before_path).convert("RGB")
    after = Image.open(after_path).convert("RGB")
    lost = ImageChops.subtract(before, after).convert("RGB")
    mask = lost.point(lambda v: 255 if v >= DARKER else 0).convert("L")
    gained = ImageChops.subtract(after, before).convert("L").point(lambda v: 255 if v >= DARKER else 0)
    count = mask.histogram()[255]
    added = gained.histogram()[255]
    # A filled square of MAX_BOX_SIDE survives a shrink by MAX_BOX_SIDE / 2 pixels each way.
    solid = mask.filter(ImageFilter.MinFilter(MAX_BOX_SIDE | 1))
    box = solid.getbbox()
    print(f"pixels much darker: {count}; pixels much brighter: {added}; solid dark block: {box}")
    if added == 0:
        print("FAIL: the effects drew nothing")
        return 1
    if box is not None:
        print("FAIL: a block of pixels went dark")
        return 1
    print("OK: no black box")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
