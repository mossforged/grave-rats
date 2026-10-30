# Asset contract

- **Formats:** 3D in glTF 2.0 binary (`.glb`), Y-up, metres, character facing -Z (Godot forward). Textures: PNG or JPG; normal maps OpenGL convention (green up); ORM packing (R = AO, G = roughness, B = metalness).
- **Folders:** sources in `assets/source/<ID>-<slug>/` (art lane and John only); game-ready imports in `assets/game/` (code lane only).
- **Characters:** share one skeleton so animations are reusable. The legacy skeleton and clip names are in `assets/source/legacy-pass05/operator.glb` (22 bones; clips `L_*` lower body, `U_*` upper body, `F_*` full body) until a stage replaces them.
- **Kit pieces:** pivot at floor level, sized to the grid set in T002.
- **IDs:** A-packets name their assets (`A001-03`). Revisions get a letter (`A001-03b`). Every image has its prompt beside it.
- **John's models:** drop into `assets/source/john/<slug>/` with a one-line note on what each is; the lead writes the import packet.
