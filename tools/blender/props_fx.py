"""Tiny gun-feel meshes (lead, 2026-10-31): an ejected rifle casing and a dropped magazine.

Run: python3 tools/blender/props_fx.py [out_dir]   (pip install bpy). Same conventions as props.py.
Real scale: the casing is tiny (45 mm). The game may scale casings x1.5-2 so they read from the
steep camera; that is a data number (see docs/design/gun-feel.md).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import props as P  # noqa: E402

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/source/props"


def shell_casing():
    """A 5.56-style casing lying on its side, along X. 45 mm long."""
    b = P.Builder("shell_casing")
    b.cyl(-0.006, 0, 0.0048, 0.0048, 0.034, "x", "brass", 10)
    b.cyl(0.0145, 0, 0.0048, 0.0036, 0.007, "x", "brass", 10)
    b.cyl(0.0205, 0, 0.0048, 0.003, 0.005, "x", "brass", 10)
    b.cyl(-0.0225, 0, 0.0048, 0.0047, 0.002, "x", "steel", 10)  # extractor groove (dark)
    return b.build()


def spent_magazine():
    """A curved rifle magazine lying flat on the floor, as dropped on a reload."""
    b = P.Builder("spent_magazine")
    b.box(-0.04, 0, 0.0125, 0.11, 0.065, 0.025, "steel", 0.003, rot=(0, 0, 0))
    b.box(0.06, 0.012, 0.0125, 0.11, 0.065, 0.025, "steel", 0.003, rot=(0, 0, 14))
    b.box(-0.1, 0, 0.0125, 0.02, 0.075, 0.028, "rubber", 0.003)  # base plate
    b.box(0.0, -0.033, 0.0125, 0.06, 0.004, 0.012, "hazard", 0.0)  # witness stripe
    return b.build()


def main():
    os.makedirs(OUT, exist_ok=True)
    P.reset()
    for f in (shell_casing, spent_magazine):
        P.export(f(), OUT)


if __name__ == "__main__":
    main()
