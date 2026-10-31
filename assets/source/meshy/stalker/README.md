# Stalker (spitter), Meshy API test run, 2026-10-31

Made by the lead through the Meshy API (`tools/meshy/`), with John's OK for 30 credits. Task `01a193db-b19b-716b-a45a-0eba2dc6ddd8`: multi-image-to-3d, latest model, from the four A007 views in `assets/source/meshy/input/stalker-*.png` (front first), 2K PBR, remeshed to about 20k.

- `stalker.glb`: 20,780 triangles, one mesh and one PBR material (textures embedded). Base at 0, head toward +Z. Meshy auto-size makes it 1.36 × 1.20 × 2.90 m (w × h × length); set the game size in data.
- **No rig.** Meshy's auto-rig is for humanoids only. A quadruped needs a script rig or procedural legs.
- From the game camera the throat sacs (the spit tell) sit under the body, so the in-game tell must stay an effect.
- Preview: `docs/screens/props/stalker_meshy_preview.jpg`.
