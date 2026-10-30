# T006 - Make the stalker dangerous, plus John's playtest fixes (code)

**Modules:** `src/enemies/`, `src/doors/`, `src/cover/`, `src/camera/`, `src/sight/`, `src/player/` (crouch bug only), `src/debug/` (main scene). **Read:** `CLAUDE.md`, `docs/playtests/log.md` (the 2026-10-30 entry, John's words), `docs/handoffs/auto-T005.md`, the contracts of the modules above, `data/enemies.json`, `data/camera.json`, `data/sight.json`. **Needs:** T005 merged.
**Autonomy:** human-gated (stage 2 gate again: *"Is moving through these rooms with a flashlight tense and fun?"*).

John played `stalker_deck`. The structure works: sight, weight and sounds are good. But he wasn't scared: "It attacks pretty slowly. It doesn't really move." "It's not really dodging. It's not fast. Its shot is kind of slow." The ambush "feels very easy"; in several tries he was hit once. This task makes the stalker a real threat while keeping pillar 3: the danger comes from **its** speed against **your** weight, so don't speed the player up.

## Do
1. **A faster, smarter stalker** (`src/enemies/`, all numbers in `data/enemies.json`, all on F1 sliders):
   - **Burst movement.** It closes distance in fast skittering dashes (about 6–7 m/s for 0.4–0.7 s), between pauses or hidden points, not at a steady walk. The player walks at 3.4 m/s and can't outrun a dash.
   - **Dodge.** When it's shot at or a light first lands on it, it dashes sideways or to the nearest hidden point, with a cooldown so it doesn't dodge everything. Hits still land if you track it.
   - **A faster spit:** wind-up 0.6 → about 0.4 s, glob speed 9 → about 16 m/s, damage up (start at 22). The glow stays readable.
   - **Lunge from further, and more often:** a longer reach (about 5 m), damage enough to stagger.
   - **Don't stand still.** In stalk it keeps shifting position between attacks: circle, back off into the dark, come again.
   - **Health:** keep 6–8 rifle hits, but make them harder to land, because it dodges and keeps moving.
2. **The ambush bites.** The burst stalker comes out within about 0.25 s and goes straight into a dash and lunge. Target: a player who keeps walking and reacts only when they hear it **gets hit at least once** (prove it with a headless bot), and a player who turns at once can get a shot off.
3. **Doors get broken, slowly** (John's call): stalkers never open doors. A stalker that knows you're behind a shut door bangs on it for about 6–10 s, with a loud, repeated bang and the door denting or shaking, then it breaks the door open and the door stays broken. Numbers in `data/doors.json` or `data/enemies.json`.
4. **Bugs and small changes from John's play:**
   - **Crouch corkscrew:** standing still and pressing C twists the operator's torso around in a corkscrew. Find and fix it, and add a test if the cause is in logic.
   - **Flashlight flicker:** with the light on, the view "flickers a bunch in a weird way". Find the cause (the sight polygon or mask jittering? the beam? the light itself?) and fix it. F is light on/off; show a small `LIGHT OFF` on the HUD when it's off, so off doesn't look like a second mode.
   - **Cover readout:** John never saw the shield. Whenever you're crouched behind low cover, show a clear `IN COVER` state next to `CROUCHED`, with or without a hunting stalker. Make the per-stalker shields larger, and place them where the eye already looks (near the crouch readout).
   - **Camera:** a new default preset **between preset 1 and 2, closer to 1** (start at pitch 60°, distance 20.5 m, fov 35°). It becomes the default in every deck; the old presets stay on their keys.
   - **Awareness circle** "might be a little bit big": 2.6 → 2.2 m.
   - **Tall cargo crates block sight**, the 1.2 m crate stacks included. If that changes their cover class, say how in the handoff.
   - **Main scene** becomes `scenes/enemies/stalker_deck.tscn`, so F5 runs the latest build.

## Acceptance
- **Headless:** all old tests still pass (update the ones whose numbers John changed). New tests:
  - a dash moves faster than the player's walk;
  - a shot triggers a dodge, and the cooldown holds;
  - the faster spit's wind-up and speed come from data;
  - the ambush bot that reacts only to the sound takes damage, and one that turns at once fires before being hit;
  - a stalker breaks a shut door after the bang time, never earlier, and never opens it;
  - the crouch doesn't spin the torso (if it's a logic bug);
  - the `IN COVER` state appears behind low cover with no stalker hunting;
  - the new camera preset is the default.
- **Bot report** in the handoff: how long a bot standing still lives, and how long one in cover lives, before and after.
- **Windowed** (`docs/screens/T006/`): a dash mid-motion; a dodge; the fast spit wind-up; a door mid-bash and broken; the `IN COVER` readout; the ambush in 3 frames; the new default camera beside preset 1; frame time with two stalkers.
- **Human (John):** the stage 2 gate question again, with F1 open.

Out of scope: new enemy types (a shooting enemy is next), lock-to-cover, art, new sounds beyond placeholder bangs.

## Addendum (lead, 2026-10-30, John's stage 1 answers)
John played `scale_deck`: "I like tight and bigger for the scale", and the operator "is generally, I think, too small ... We want to be able to see details in the model." For the cut-away he "definitely" prefers fade over drop, and it "could even be a little bit more obscure".
- **Room scale 0.85 and character scale 1.15 become the defaults** in every deck (data only). Check that props and doors still fit and that the T005 cover heights still hold at the new scale; report the operator's share of view height at the new default camera.
- **Cut-away default becomes `fade`**, with the faded walls a little more solid than now (`fade_transparency` 0.82 → about 0.65; a slider in F1). Drop stays on the C key.
- Add to the windowed captures: the new defaults (camera, scale, fade) in the medbay and the junction.
