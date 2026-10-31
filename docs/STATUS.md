# Grave Rats — status

**Stage:** 3 and 4 in progress. Stage 2 passed (tag `stage-2`). T011 to T022 built; T022 on `auto/t022-mac`, the rest merged, waiting on John's gates (T017/T020 sound and gun feel: his ear and hands; T022: does the hauler move like a soldier?). A013 approved; A014 pitch B (biological survey vessel) approved. **Next:** John plays a shift (expected tomorrow night). Code lane: T023 (build the survey vessel). QA: Q003 now T022 is built.

## Stage plan (each stage ends in a gate John answers by playing)
0. **Skeleton.** Godot project, headless tests, capture tool, runners. Gate: none (lead checks). **Done 2026-10-30.**
1. **Camera and scale (grey box).** Perspective camera rig and a grey-box deck at the chosen proportions. Gate: *"Does this framing feel like the concept?"*
2. **Core loop (grey box).** Move, aim, shoot, crouch, flashlight sight, doors, one enemy type, one small deck. Gate: *"Is moving through these rooms with a flashlight tense and fun?"*
3. **Vertical slice art.** Medbay, corridor and cargo at concept quality: kit, materials, lighting, crew model and animation. Gate: *"Does it match or beat the concept?"*
4. **Systems.** Cover with height, loot and carry decisions, extraction, threat variety, sound. Gate per system.
5. **Co-op.** 2–4 players over the network. Gate: a real session with the Monday crew.
Later (parked): Open Tender (competitive mode, decided 2026-10-31; see decisions), ship generation, contracts and meta, the threat roster.

## What builders need now
- Queue order (lead): T015 awaiting review; T011, T012 and T014 awaiting John's gates.
- Code: T015 on `auto/t015-mac`: 383/383, see `docs/handoffs/auto-T015.md`. The main scene is `scenes/shift/shift_deck.tscn`, and it opens on the briefing.
- Art: A006 merged and approved. A007 merged: Meshy inputs for stalker, bed and console in `assets/source/meshy/input/`; the rifle was refused by the image tool. The hauler is in the game (`assets/game/hauler/`).

## Open questions (for John)
- T022 play (`godot --path .`; sheet `docs/screens/T022/sheet.png`, `circle_aiming.mp4`): does the hauler finally move like a soldier? Strafe, back up, fire walking, reload, take a hit, die, carry heavy. Calls and levers in `auto-T022`.
- T021 look (`docs/screens/T021/sheet.png`): the wall tops now always show their paint (a z-fight used to hide it), so there's more yellow up there; beds carry a hazard stripe on their long rims. Enough to read the overturned bed with your light off? Calls in `auto-T021`.
- T019 look (`docs/screens/T019/sheet.png`, then walk the junction and the side corridor): is it realistic enough? North-facing walls gain the most; the long junction's side walls mostly show their tops from the steep camera. Lever if the junction stays flat: floor-level pieces and more light there, not more wall pieces. Calls in `auto-T019`.
- T015 play: does the ship itself feel like a threat? Can you read the cutter (line + filling ring, tall cover blocks it) and the drone (spotlight, three bars; break line of sight to cancel) in time? Bots: the prize route is now near-fatal (greedy survives 1/12; cautious 12/12 because it leaves before CUSTODIAN wakes). First lever if too much: move the cargo cutter off the prize route.
- T015 play (sheet `docs/screens/T015/sheet.png`): does the ship feel like a threat? Can you read the turret and drone in time? Approve the new copy in auto-T015.
- T015 balance: the prize route may now be too lethal. Greedy bot survives 1 of 12 (was 6 of 12), even reading the cutter's ring; cautious stays 12 of 12 because it leaves before CUSTODIAN wakes. First lever: move the cargo cutter off the prize's route.
- T014 play (the game now opens on the briefing): does the quota make you take risks? Do the payslip and death bill land? Balance flags from the bots: greedy met 42 of 44 quotas while dying in 45% of shifts (the black box is about 69% of the first quota, the design says a third); fees are small next to a good shift; dying costs nothing on the quota while leaving empty-handed costs about 120. Approve the new copy (termination notice, decline confirms, vessel names) in auto-T014.
- T014 play (`godot --path .`, sheet `docs/screens/T014/sheet.png`): does the quota make you take risks? Do the payslip and death bill land? New copy for your approval is in the handoff (termination notice, decline lines, vessels).
- T014 balance: the cautious bot meets quota 1 (10 of 12), then mostly misses (2 of 10), as asked. Greedy meets 42 of 44 while dying in 45% of shifts, so dying barely threatens it. Levers: `quota.growth`, the prize's value, charging deaths to the quota. Dying also costs less than leaving empty-handed; keep it?
- T012 play (`scenes/shift/shift_deck.tscn`, now the main scene): does "one more room?" happen? Is grabbing the black box scary? Tier stalkers can reach a still player in about 2 s (`spawning.min_player_m`). Are failed lights dark enough? Bots: greedy banks about 1.8× cautious but survives 50% against 100%; cautious may be too safe until the quota (T014).
- T012 play (`godot --path .`, sheet `docs/screens/T012/sheet.png`): does "one more room?" happen? Is grabbing the black box scary? Bots: greedy banks 2,380 on average and survives 6 of 12; cautious banks 1,309 and survives 12 of 12.
- T012 calls: rings hidden in unseen rooms until seen, a tier stalker can spawn out of sight 7 m or more away and hit within about 2 s, the airlock is a marked zone and not a room, lights failing is looks only. Handoff has each lever.
- T011: MSAA dropped from 4x to 2x to meet the frame budget (reverses the 2026-10-30 decision); turning shimmer rose (0.09 → 0.12% twinkle), possibly from that. Accept 2x, or go back to 4x and find the time elsewhere?
- T011 play (stage 3): sheet `docs/screens/T011/sheet.png`, then medbay to junction to cargo. Does it match or beat the concept?
- T011 calls: MSAA 4x to 2x (biggest frame win; rougher edges?), dimmer rooms with no shadowed practicals, the ambush panel's new tell, door strips in a fight, shimmer when turning (twinkle up 30% on T010).
- T011 frame time: pirate deck met the target in one window (7.07 / 9.1) and missed in a busier one (7.7 / 10.4; T010 8.2 / 10.5). Re-measure T010 against T011 on a quiet Mac.
- A009: approve the rival crew **Prior Claim** (white/navy, sponsor Lien Capital)? Its Meshy A-pose inputs are in `assets/source/meshy/input/rival-apose-*.png`.
- T009 play: does the hauler look and move right from the game camera? Known: the head bows forward when aiming, the left hand sits below the foregrip, feet slide on strafes, and firing has no clip yet. Next clips worth fetching from Mixamo: strafe run left/right, run backward, rifle firing, crouch backward/strafes, low-ready walk.
- T009 play: does the hauler look and move right from the game camera? Nobody has seen it move. Watch strafing and walking backward (feet slide most, slow clips sped up), the bowed head when aiming, and turning on the spot. Clips to fetch: handoff.
- T008 play: is the flicker gone? Does the suit-OS HUD read? Does the noise ring help? (Placeholder O2 and salvage counters.)
- T007 play (`scenes/pirates/pirate_deck.tscn`, now the main scene): does cover matter? Is lock-to-cover (Space, RMB) better than plain crouch (F1 toggle)? Too lethal (3.4 s in the open)? Do the crew read as rivals? Do the barks give too much away? Bots: cover doubles survival; lock is no better than crouch when fighting from one spot.
- Meshy models from John (`docs/handoffs/meshy-shortlist.md`): stalker, bed, rifle still open; the console slot is now filled by the lead's scripted one.
- T006 open: is 8 s of door banging right?
- T006 decisions: 1.2 m crates are now tall cover (you can't fire over them); locked doors hold stalkers; your light makes a prowler hunt you.
- Stage 1: John picked rooms ×0.85, character ×1.15, fade cut-away (T006 addendum makes them default). Confirm the framing after T006.
- `tools/capture.sh` only reaches 1920×954 on this display; accept, or make the capture window borderless?

## Parked
- Lock-to-cover, Gears style (John): brace against cover and shoot over it. Waits for a shooting enemy.
- Visible aim cone may go in the final game (John); keep for testing.
- Competitive modes; procedural ship generation; contracts and meta-progression.
- T002 capture: auto-walk during the frame-time window so camera motion and cut-away are measured.
- Physics interpolation: the operator steps at 60 Hz, so a faster display may show slight camera jitter.
- Legacy clips: a real walk (the run clips stand in), a crouch walk with real steps, turn-in-place feet. Foot slide numbers in auto-T003.
- `tests/test_deck.gd` `test_props_at_real_size` logs a string-format error (`%` with an array) while passing.
- Sight leaks: tracers and prompts draw over the mask, hidden targets pop in with no fade.
- T005 limits: the cover shield can show a stalker you can't see; 1.2 m crate physics boxes may stop 1.2 m rounds; a tipped bed can land on a stalker; 13 `invalid UID` import warnings for `operator.glb`.
- Quiet-machine frame-time baseline for the asset viewer (T001 runs had other load on the Mac).
- `src/study` deck dressing and the deck copy in `stalker_deck` want a real level module.
- Stalker: a hit interrupting a wind-up.
- A roll move: the hauler has the clip (`anim.play_state("roll")`), but no key or rule uses it yet.
- Door state lights tell states apart by colour alone; a pattern per state would help colourblind players.
- T012: drawn vents and closets at spawn points; the airlock as a real room; stale `p_size` engine errors from headless HUD text.
- T014: the HUD help has both "Backspace abandon shift" and the shared "Backspace respawn"; the death screen says "Backspace: next shift" where it now opens the bill. Text in `data/hud.json`, `data/health.json`.
- T014: the forms render over a running 3D view; hiding the camera behind an opaque form would save the GPU.
- T015: a collider for the drone; cutters and drones reacting to stalkers; the T014 session bots rerun with CUSTODIAN.
- T018: E through commands on the older dev decks; `src/pirates` randomness on the session's seed.
- T021: a `LockDriver` per player (the pirate deck has the local player's only); volumetric fog leaves 1–2 grey levels of frame-to-frame difference on a still camera.
- T018: per-stalker targets (the pack hunts one player at a time, and the cover-shield lines follow it); a death bill for a player left behind; spectating when you're down with the crew alive; a second input device in the two-player scene.
- T019: `hanging_cables` spark flicker. T008's "flicker" was a bug fix, not an effect, and T012's flickers whole sections from `src/shift`; the tip glows steadily for now.
- T019: door surrounds on doors' room faces; a generated `floor_grate` rule that exempts flush grates from route keep-outs.
- Hauler: left-hand IK onto the foregrip; the Meshy roll's feet aren't auto-grounded.
- Available Mixamo clips, in `assets/source/mixamo-shooter/`, no system uses them (T022): jumps (`rifle_jump*`, `unarmed_jump*`, `pistol_jump`), falls (`fall_loop`, `fall_to_land`), `ladder_climb_loop`, `vault`, `run_slide`, `rifle_melee`, `rifle_throw_grenade`, the `pistol_*` set, `unarmed_punch`, `unarmed_run_loop`, `rifle_equip`, `rifle_idle_loop`, `knocked_down`, `get_up`.
- T022: heavy-carry hands on the load; strafing with a heavy load (forward-only clips slide sideways); a low-ready walk for pirates looting; a death body reaching through a wall (it can slide about 1.1 m from the collision).
- `test_vfx.gd::test_pools_never_allocate_after_warm_up` fails when `test_vfx` runs alone (27 more objects, on main too); it passes in the full suite.

## Last session
2026-10-31 (code, unattended): T022: 54 of John's Mixamo clips on the hauler and pirates: eight-way walk and run, sprint, four-way crouch, fire, reload, hits by direction, deaths by cause, pick up, press, cover, heavy carry with the rifle slung. 587/587. No measurable frame cost. Nobody has played it. See `auto-T022`.
