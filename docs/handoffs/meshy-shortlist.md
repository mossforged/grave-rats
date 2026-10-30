# Meshy shortlist for John (stage 3)

Scripts build anything boxy that has to snap to the 0.5 m grid: walls, floors, door frames and leaves with their damage states, crates. Meshy is for the few irregular, organic shapes scripts can't do well. Each comes from an approved image.

| # | Model | Source image | Notes |
| --- | --- | --- | --- |
| 1 | **Orange hauler** (player) | `assets/source/A005-dev/A005-01b.png` (front), 02 for detail | The biggest win. A/T-pose, rifle as a separate model. Rig: Meshy's humanoid auto-rig, or Mixamo, so the existing 13 clips can be retargeted. |
| 2 | **Acid stalker** | `assets/source/A001-crew-threat/A001-11.png` | Static mesh is fine; code animates it from parts if no rig fits a creature. Split body, head and legs if Meshy allows. |
| 3 | **Medical bed** | `assets/source/A006-slice/A006-07b.png` (bed), `A002-slice-env/A002-05.png` | One rigid model, used upright and tipped. Solid underside; that's the shield. |
| 4 | **Med console** | A006-07b (console), A002-05 | 1.4 × 1.1 × 0.6 m. |
| 5 | **Rifle** | A005-02 (helmet and body only; the grip inset is wrong), A001-01 | A chunky industrial carbine for both crews. |
| 6 | **Optional dressing:** surgical lamp, IV stand, med cabinet, parked loader exosuit | A002-05, A002-06 | Only if 1–5 go smoothly. |

## Input images
Meshy needs one clean object per image. Use `assets/source/meshy/input/`:
- **hauler:** `hauler-front.png`, `hauler-side.png`, `hauler-back.png` (ready; use Meshy's multi-view upload);
- **stalker, bed, console, rifle:** made by A007 (queued).

Text prompts are optional. A short texture hint is enough, e.g. hauler: "worn industrial space salvage suit, beige patched fabric, orange painted armour plates, black rubber, grime". Don't use the A001/A005 scene or sheet images directly.

## Specs
- Export **.glb**, in **metres**, Y-up, feet or base at the origin.
- Scale to the A006 numbers: the hauler 1.8 m tall before the game's ×1.15; the bed 0.9 × 0.75 × 2.0 m.
- Triangles: the hauler ≤ 30k; the stalker ≤ 20k; props ≤ 10k each. The camera is far, so lighter is fine.
- PBR textures at 2K (base colour, normal, roughness/metal). Meshy's defaults are fine.
- Drop the files in `assets/source/meshy/` (name them `hauler.glb`, `stalker.glb`, `bed.glb`, `console.glb`, `rifle.glb`), commit and push, or just tell the lead where they are.
