# VFX textures (lead, generated)

Made by `tools/vfx/make_flipbooks.py` (procedural noise, re-runnable: `python3 tools/vfx/make_flipbooks.py`). Placeholders good enough to ship the look; an artist can replace any file with the same name and layout. Previews: `docs/screens/vfx/vfx_sheet.jpg` and `flipbooks.gif` (animated).

- **add**: additive blending; black means nothing. **blend**: straight-alpha RGBA, mostly white or grey so the engine tints it per use. **data**: shader input, not shown directly.
- Flipbooks are grids read left to right, top to bottom; `manifest.json` gives frames, columns and fps.
- Gun meshes: `assets/source/props/shell_casing.glb`, `spent_magazine.glb` (`tools/blender/props_fx.py`).

| File | Blend | Frames | Use |
| --- | --- | --- | --- |
| `smoke_puff.png` | blend | 64 (8 cols) | one puff growing and thinning; particle base for plumes, muzzle smoke, steam (tint) |
| `impact_dust.png` | blend | 16 (4 cols) | short dust/paint puff at a bullet hit on clinical panels (tint by surface) |
| `fire_loop.png` | add | 64 (8 cols) | looping flame for burning consoles, fuel fires (scale and layer 2-3) |
| `explosion.png` | blend | 64 (8 cols) | fireball cooling to smoke; unshaded (fire is bright in RGB); pair with a light flash |
| `acid_bubble.png` | blend | 16 (4 cols) | one bubble rising, swelling and popping on an acid/slime pool (tint) |
| `muzzle_flash.png` | add | 8 (4 cols) | frames 0-3 front-on star, 4-7 side cone (muzzle on the left); one random frame per shot, 1-2 frames on screen, random roll |
| `electric_arc.png` | add | 4 (1 cols) | 4 arcs, one per 64-px row; swap rows every 2-3 frames; shorting panels, cutter, damaged reactor |
| `spark_streak.png` | add | 1 (1 cols) | velocity-aligned spark (head on the right); bursts of 8-20 for metal hits and shorting consoles |
| `glow_dot.png` | add | 1 (1 cols) | soft glow for embers, spark heads, dust motes in a torch beam, warning-lamp halos (tint) |
| `decal_bullet_holes.png` | blend | 8 (4 cols) | row 0: holes in bare metal (scuffed ring, soot); row 1: holes in clinical panels (chipped paint, cracks) |
| `decal_splats.png` | blend | 8 (4 cols) | 0-3 stalker ichor splats (sickly yellow-green; re-tint if the stalker's blood changes); 4-5 scorch marks (explosions, cutter burns); 6-7 puddle shapes for acid/slime pools (white, tint; pair with liquid_noise) |
| `liquid_noise.png` | data | 1 (1 cols) | seamless; R/G noise at two scales to scroll against each other for the pool surface (emission + slow distortion), B for bubble spots |
