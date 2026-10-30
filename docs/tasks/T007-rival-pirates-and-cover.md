# T007 - Rival pirates: an enemy that shoots back, and lock-to-cover (code)

**Modules:** new `src/pirates/`; `src/cover/` (lock-to-cover); `src/enemies/` only where a shared sense or nav piece needs reuse. **Read:** `CLAUDE.md`, `docs/playtests/log.md` (2026-10-30), `docs/handoffs/auto-T006.md`, the `src/cover/`, `src/enemies/`, `src/player/`, `src/weapons/`, `src/sight/` and `src/health/` contracts, `docs/screens/A001/sheet.png` (A001-13, the rival pirate crew). **Needs:** T006 merged.
**Autonomy:** human-gated (John: *"Does cover matter now? Is lock-to-cover better than plain crouching?"*).

John: cover needs "a monster that shoots something", and "maybe having a sort of Gears style, like, lock into cover thing would be a good idea, where you, like, brace against it and then can shoot over it." He picked **rival pirates** for the shooting enemy, and suggested **a recolour of the player body** to save time.

## Do
0. **First, John's stage 1 picks (the T006 addendum, which T006 missed because it branched before it):**
   - room scale 0.85 and character scale 1.15 become the defaults in `data/deck.json`;
   - the cut-away default becomes `fade`, with `fade_transparency` 0.82 → 0.65, plus a slider for it in F1.
   The lead tried exactly this data change on top of T006: 180/181 passed. `test_enemies.gd::test_tipping_a_bed_in_the_scene_holds_you_and_gives_low_cover` fails with "can't walk off while tipping": probably a test position that assumes room ×1.0. Fix the cause, not just the number. Check that every prop, door, bed and the ambush panel still fit at ×0.85. Report the operator's share of view height at the new default camera, and capture the medbay and junction with the new defaults.
1. **The pirate body:** the legacy operator model and clips, recoloured as a rival crew. Per the A001-13 brief they're "better funded, worse people": clean corporate white and navy or a loud sponsor colour, with no orange (that's ours). Do it with a material tint or swap in data, not by editing the source glTF. Same rifle model.
2. **Pirates obey weight, exactly like you** (`src/pirates/`, numbers in `data/pirates.json`, on F1 sliders): the same turn-rate cap, aim settle, recoil and reload commitment as the player. They're dangerous because they're coordinated and use cover, not because they cheat.
3. **Pirate behaviour (a squad of 3):**
   - **Senses** as the stalker's: sight cone, hearing, doors and walls. They carry flashlights, and their beams are a tell you can see coming.
   - **Take cover:** pick low or tall cover facing you, crouch behind it, and pop up to a braced height to fire bursts. They use the same 3D shot trace, so low cover protects them when crouched and exposes them when braced, just like you.
   - **Coordinate:** one suppresses (bursts at your cover, keeping you down), one flanks to a spot with an open line, and they call it out. Placeholder voice barks as text over their heads are fine ("Flanking!", "Reloading, cover me", "It's nothing personal, it's in the contract").
   - **Reload and fall back** when hurt; each dies in about 4–5 rifle hits.
   - **Their shots** use the real 3D trace against cover height, with visible tracers, and staggers on big hits as for you.
4. **Lock-to-cover, as a prototype you can switch off** (`src/cover/`; F1 toggle, default **on**): next to low cover, a key (Space) snaps you into cover facing it. Locked, you're crouched and protected, and move along the cover's edge. Aiming over it raises you to braced (exposed), lowering returns you to protected, with short, data-driven transition times. Moving away or pressing the key again releases you. With the toggle off, plain crouch behaves exactly as in T006.
5. **A firefight deck:** `scenes/pirates/pirate_deck.tscn`. The cargo hold and junction, with the squad looting cargo. You come in through the junction door, and there's enough low and tall cover on both sides for a real exchange. A respawn key resets.
6. **Run log:** add pirates to the killed-by sources, time spent locked in cover, and shots blocked by cover (both ways).

## Acceptance
- **Headless:**
  - all old tests pass;
  - the pirate's turn, settle and reload numbers come from data and match the player's rules;
  - a crouched pirate behind low cover is protected, and a braced one is exposed;
  - the suppressor fires at your cover while the flanker reaches a spot with an open line;
  - lock-to-cover snaps only next to low cover, is protected when locked, exposed when aiming over, and releases on moving away;
  - with the toggle off, crouch is unchanged;
  - the run log has the new fields.
- **Windowed** (`docs/screens/T007/`): the recoloured pirate beside the operator; a pirate braced and firing over cover; the flank in 3 frames; you locked in cover, then aiming over it; frame time with the squad of 3 fighting.
- **Bot report:** time to die for a bot that stands in the open, one that crouches, and one that uses lock-to-cover.
- **Human (John):** does cover matter now, and is lock-to-cover better than plain crouching?

Out of scope: new art beyond the recolour, pirates fighting stalkers (parked), loot, co-op.

## Addendum (lead, 2026-10-30, after John's second play)
Do these two first, after step 0.
1. **The flashlight flicker, located by John:** "there is the steady cone of white for the light, and then there's a more abstract lower shape that's sort of flickering. It's visible kind of lower on the screen from it a little bit, like almost overlaid, but not quite."
   - **The lead's suspect:** the beam mesh `flashlight.draw_beam()` (`src/sight/flashlight.gd`). It's rebuilt every frame as a fan from the sight polygon, sloping from `beam.start_height_m` to `end_height_m`, so it sits lower than and offset from the real SpotLight cone, and its edge follows every polygon change.
   - **Confirm before fixing:** with the beam mesh hidden, does the second shape go away?
   - **Then fix it so there is one light shape:** the beam shouldn't jitter frame to frame (smooth or stabilise the ring, or build it from a fixed cone clipped only at walls), and it should line up with the spotlight's footprint.
   - Add a test on frame-to-frame beam vertex change while standing still and slowly turning. Capture a before and after pair.
   - Also check the sight mask's stair-stepped edge, which T006 flagged, for the same crawl.
2. **Gunshots don't start door-breaking** (John: "I don't want one fight to cause everything to trigger necessarily"):
   - A stalker breaks a shut door only if it was **hunting you** (it saw you, or was stalking you) when you went behind that door.
   - A gunshot it hears through a shut door makes it **investigate up to the door and linger**, then give up; no bashing on noise alone.
   - Hearing through shut doors uses a reduced radius (a data value, start at 50%).
   - Update the T006 door tests to match, and add one: a fight in one room doesn't send a stalker two rooms away into bashing.
