# T002 - Camera and scale study in grey box (code)

**Modules:** new: `src/camera/`, `scenes/study/`. **Read:** `CLAUDE.md`, `docs/handoffs/game-brief.md`, `docs/concepts/C001-dead-circuit-key-art/gameplay-panel.jpg`, `docs/reference/dead-circuit-pass05-compare-junction.jpg`. **Needs:** T001 merged.
**Autonomy:** human-gated. This is the stage 1 gate: John judges which framing and scale feel like the concept.

The prototype's biggest failure was scale and framing. The rooms were two to three times too big, and an orthographic camera can never show walls the way the concept does. This task builds a grey-box deck at concept-like proportions with a tunable perspective camera and a few presets, so John can pick by playing rather than by reading numbers.

## What the lead measured in the concept (starting points, not truth)
- **Perspective, not orthographic.** The medbay's left wall shows its inner face and the cargo walls on the right show theirs. Pitch looks steep, about 55–65°; FOV moderate.
- **The operator is about 8% of view height.** The visible play area is roughly 8–9 character-heights tall and 15–18 wide.
- **Medbay interior ≈ 8 × 5–6 character-heights** (about 14 × 10 m at 1.8 m). **Main junction corridor ≈ 3–3.5 heights wide** (about 6 m); **side corridors ≈ 2 heights** (about 3.5 m). **Walls ≈ 1.3–1.5 heights tall** where shown full height. Doorways ≈ 1.1 heights wide.
- **The art's proportions disagree with themselves** (the operator is about a third of a bed's length). Don't trace it. Pick a consistent scale and match the screen composition.
- For comparison, the old prototype's medbay was 24 × 20 m and its corridor 8.8 m wide.

## Do
1. **Camera rig** in `src/camera/`:
   - Follows a target with smoothing and a small look-ahead toward the aim direction.
   - Perspective, with pitch, yaw offset, FOV and distance all in `data/camera.json`.
   - An orthographic option for comparison.
   - **Wall cut-away:** walls between the camera and the player fade or drop to low height. Try both, pick one, and say why.
   - **Presets** switchable with keys 1–5 and shown on screen: at least the concept match (your best estimate), steeper/closer, flatter/wider, the prototype's orthographic view, and one wildcard of your choosing.
2. **Grey-box deck** in `scenes/study/scale_deck.tscn`:
   - A medbay, the junction corridor, a side corridor and a cargo hold, laid out like the concept's top half.
   - Use simple boxes with readable grey materials (a slightly lighter floor, darker walls, a hazard-coloured door frame), not the legacy kit, so scale is judged without art bias.
   - Add **props at real size**: bed 2.0 × 0.9 m, crates 1.2 and 0.8 m tall, consoles, a doorway.
   - **Grid size, wall height, wall thickness, door width and corridor widths live in `data/deck.json`.** The deck is generated from data so John's scale changes are a number edit.
3. **A walkable stand-in:** the legacy operator, moved with WASD and aimed with the mouse.
   - Collision with walls and props, placeholder speed from data.
   - No shooting.
   - The run animation may still slide; that's fine here.
4. **Scale variants:** `data/deck.json` holds a scale multiplier for rooms and corridors (default 1.0 = the concept estimate) and a character scale multiplier (default 1.0). Add keys for room scale 0.85 / 1.0 / 1.15 and character scale 1.0 / 1.15, so John can try them live.
5. **Comparison captures**, saved in `docs/screens/T002/`:
   - every camera preset at default scale;
   - the concept-match preset at each room scale;
   - a side-by-side sheet against `gameplay-panel.jpg`.

## Acceptance
- **Headless:** the deck generator test checks room and corridor sizes come from `data/deck.json`, there's a walkable path from the medbay to cargo, and the doorways are wider than the character's collision diameter plus margin. Camera math test: the target stays in view at every preset.
- **Windowed:** the captures above, plus the frame time at the concept preset (`tools/capture.sh`).
- **Human (John):** *"Which preset and scale feel like the concept? Does moving through the medbay and junction feel tight enough?"* He answers by playing; the lead records his words.

Out of scope: shooting, enemies, lighting polish, art. Lighting should be plain and even so geometry reads.
