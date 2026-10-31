# Scripted hard-surface props (lead, Blender by script)

Built by `tools/blender/props.py` (run `python3 tools/blender/props.py assets/source/props`; needs `pip install bpy`). Previews in `docs/screens/props/`.

| File | Deck prop | Size w × h × d (m) | Tris |
| --- | --- | --- | --- |
| `console_1400.glb` | `console` 1.4 × 1.1 × 0.6 (medbay) | 1.40 × 1.10 × 0.59 | 752 |
| `console_1200.glb` | `console` 0.6 × 1.1 × 1.2 (side-facing, so 1.2 wide) | 1.20 × 1.10 × 0.59 | 752 |
| `console_1000.glb` | `console` 0.6 × 1.1 × 1.0 (side-facing) | 1.00 × 1.10 × 0.59 | 752 |
| `cabinet.glb` | `cabinet` 0.6 × 1.9 × 0.5 | 0.60 × 1.90 × 0.49 | 564 |
| `locker_bank.glb` | `locker_bank` 0.6 × 2.0 × 2.4 (2.4 long) | 2.40 × 2.00 × 0.60 | 1904 |

- Origin at the centre of the base; front faces +Z (glTF); width along X. A deck prop whose size is narrower in X than in Z is the same model turned 90°, front toward the room.
- **Material slots are `data/kit.json` material keys:** `clinical`, `steel`, `hull`, `hazard`, `rubber`, `glass`, `emit_blue`, `emit_red`. The colours in the file are previews only; the game should bind its kit materials by slot name, so props get the same textures, wear and grime as the walls.
- Nothing pokes out of the deck footprint; collision, occluders and cover still come from the deck data, never the mesh.
