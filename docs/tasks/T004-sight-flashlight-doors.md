# T004 - Sight, flashlight and doors (code)

**Modules:** new: `src/sight/`, `src/doors/`. **Read:** `CLAUDE.md`, the `src/player/` and `src/camera/` contracts, `docs/concepts/C001-dead-circuit-key-art/concept-sheet.jpg` (the bottom-right "Know the room. Fear the corner." panel). **Needs:** T003 merged.
**Autonomy:** human-gated (John judges the dread: does fear of the corner work?).

Pillar 2, "Know the room, fear the corner", works like the concept's visibility panel:
- What's in your sight is real.
- Rooms you've seen are remembered, dimmed, but anything moving in them is hidden.
- Rooms you haven't seen are dark.
- Walls and closed doors block sight.
- The flashlight is how you push sight further, in one direction at a time.

## Do
1. **Line of sight** (`src/sight/`, pure logic plus a Godot adapter):
   - Visibility from the player's eye over the deck's occluders (walls, closed doors, tall props; low props don't block).
   - A 360° "awareness" radius close to the body.
   - A longer cone along the flashlight beam.
   - A shorter cone with the light off.
   - Ranges and angles in `data/sight.json`.
2. **Three states per area.** Use cells or rooms (your choice; explain it): visible, remembered, unknown.
   - Remembered areas render dimmed and desaturated. Unknown areas render near-black with only the faintest structure.
   - Implement with a screen-space or projected mask, so lit geometry stays real-lit. Aim for the concept's look: a hard-edged sight polygon softened slightly at the edge.
   - Entities (enemies, other players later, pickups) carry a `SightTarget` and are hidden unless currently visible.
3. **Flashlight:**
   - A `SpotLight3D` from the weapon, with shadows.
   - Toggled with F.
   - Its beam is the sight cone, so light and knowledge match.
   - A subtle volumetric beam (fog volume or a beam mesh) with dust motes.
   - It must cost under 2 ms of frame time at 1080p on this Mac. Measure it.
4. **Doors** (`src/doors/`):
   - A sliding bulkhead door with open, closed and locked states, opened with E within reach, taking a short time to open.
   - Blocks movement and sight when closed.
   - Doors are data-placed in the grey-box deck (at least four, including one between medbay and junction, and one locked).
5. **Debug:** F2 shows the sight polygon and areas outlined by state.

## Acceptance
- **Headless:**
  - a wall blocks sight;
  - a closed door blocks sight and an open one doesn't;
  - low props don't block;
  - remembered state persists after leaving;
  - a `SightTarget` behind a wall is hidden;
  - the flashlight-off cone is shorter than the on cone;
  - data-driven numbers.
- **Windowed:** `docs/screens/T004/`:
  - entering the medbay from the junction (three states visible);
  - flashlight on vs off in the same spot;
  - a closed vs open door;
  - frame time with the flashlight on vs off (`tools/capture.sh`).
- **Human (John):** *"Do I feel the corners?"* Does walking into an unknown room feel uncertain?

Out of scope: enemies' own sight and AI (next packet), sound, cover.
