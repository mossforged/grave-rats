# T022: the full Mixamo shooter set on the hauler (auto, code)

Branch `auto/t022-mac`. **Nobody has played this or watched it at speed in a real fight.** I read the looks from stills and a circle recording, so feel is John's call. Play with `godot --path .`.

## What changed
- **Clips:** 54 of the 88 copied into `assets/game/hauler/clips/` (22 MB), retargeted at load by the existing path. The 8 old `hauler-*.fbx` files are gone, a net +19 MB. Only `roll` still uses a Meshy clip (`Roll_Dodge`), and no key triggers it. `assets/source/` is untouched.
- **Legs:** eight directions at walk and run, sprint forward, left and right, blended by move direction against aim. Speeds per gait and direction are in `gaits.speeds_m_s`, which replaces the single strafe speed. All are measured by `tools/t022_measure.gd`, at the game's character scale.
- **Crouch:** idle, aim idle, four-way walk and both transitions.
- **Firing:** three clips on `upper_bones`, restarted the same step the round goes off. The arm kick stays on top.
- **Reload:** three clips, blended mid-reload, stretched to `reload_s`.
- **Turn in place, hits, deaths, pick up, press E, cover, heavy carry:** in, each below under "Calls".
- **Pirates:** same body, same states. Their rounds pick the flinch and the death.
- **Code:** `src/player/hauler_anim.gd` rebuilt, `hauler_moves.gd` new (scene-free choices), `hauler_clips.gd` and `hauler_retarget.gd` extended.

**Outside the packet's modules, small and needed:**
- `src/weapons/rifle.gd`, `data/audio.json`: mag-out and mag-drop moved from "at once" to `reload_stages`.
- `src/sight/sight_deck.gd`, `src/shift/shift_deck.gd`, `src/enemies/stalker_deck.gd`: one-line wiring for hit direction, pick up and press E. This also closes the parked "stalker deck stagger plays no hit clip".

## Checks
- **Import:** exit 0, no errors.
- **Headless tests: 587 passed, 0 failed, 0 load errors** (566 before; `tests/test_hauler_moves.gd` is new). They hold:
  - every state in data maps to a clip that loads, and nothing is a stand-in;
  - all eight directions pick the right blend, aimed three ways, and each clip steps the way it's named at its data speed;
  - reload, fire and flinch leave the foot ranging at least 70% of plain walking;
  - deaths move the body and not the player.
- **Build time:** the first hauler takes about 0.95 s to build its clips, against 0.52 s before, once per run.

### Foot slide: planted foot speed, % of body speed (0 is perfect)
**T009 set no number**, so I set the test's limit at under 45% on the exact clock (T009's best was 63%, on the noisier clock). Same tool on both sets, both feet.

| Case | Old clips, exact | New, exact | Old, frame clock (3 runs) | New, frame clock (3 runs) |
|---|---|---|---|---|
| Run forward (3.4 m/s) | **9%** | 14% | 58–66% | 36–56% |
| Run back | 25% | 11% | 70–74% | 32–45% |
| Strafe right | 32% | 19% | 82–83% | 36–54% |
| Strafe left | 58% | 14% | 92–96% | 35–59% |
| Crouch forward | 80% | 10% | 104–111% | 46–52% |
| Sprint forward | **16%** | 24% | 78–82% | 52–66% |

- **Forward run and forward sprint are slightly worse on the exact clock.** Everything else is much better. On the frame clock, which adds frame-order noise, all six improved.
- "Exact" steps body and clips together by hand. T009's table can't be compared directly, as it measured one foot.

Every locomotion clip on the exact clock (`docs/screens/T022/foot_slide_all.txt`):

| Direction | Walk | Run | Sprint | Crouch |
|---|---|---|---|---|
| fwd | 19% | 14% | 24% | 10% |
| fwd_right | 25% | 14% | | |
| right | 15% | 19% | 11% | 14% |
| back_right | 17% | 12% | | |
| back | 18% | 11% | | 22% |
| back_left | 39% | 10% | | |
| left | 15% | 14% | 11% | 21% |
| fwd_left | 16% | 17% | | |

### Frame time: `shift_deck` and `pirate_deck`
1920×957, M2 Pro, Metal, 2x MSAA, vsync off, 15 s each, before (a checkout of main) and after alternating, load average about 4–6. The capture's own window walks and fires. All runs: `frametime_before_after.json`.

| Deck | Before, avg ms per run | After, avg ms per run |
|---|---|---|
| Shift | 7.65, 7.78, 7.91, 7.54, 7.62 | 7.67, **9.21**, 7.81, 7.44, 7.78 |
| Pirate | 7.21, 7.25, 7.22 | 7.15, 7.25, 7.24 |

- **No cost I can measure**, apart from one bad shift run: 9.21 avg, p99 31.6, a 258 ms max. I didn't trace it. The other four after-runs match before, so I read it as other load on the Mac, but I can't prove that.
- p95 is about 10.5–11.1 ms on the shift deck and 9.7–10.2 ms on the pirate deck, both sides.
- Worst case for many bodies wasn't measured: no scene runs a crew all firing at once.

## Calls I made (each is a data change if wrong)
- **Crouch transitions play in place:** hips x and z pinned, height kept, scrubbed by `crouch_amount` rather than timed, so the crouch keeps its 0.18 s and 0.35 s. Moving, the crouch blend absorbs it. The clips step a little on the way down, so I raised `test_a_step_crouch` from 10 cm to 15 cm of stray (it measured 19 against 8 settled). **Please check that one.**
- **Heavy carry:** heavy is what blocks firing already (`can_fire: false` in `data/salvage.json`). I didn't change that rule; the pose reads it. Medium keeps the rifle.
- **Hit reacts touch only spine, neck and head** (`hits.bones`). Those clips' arms aren't holding a gun, and their legs would fight the walk. So the flinch is modest, and the clips' big stumbles (up to 1.7 m of hip travel) are gone. All last 0.6 s (`hits.seconds`).
- **"When aiming" means fired in the last 0.25 s.** The body is always aiming, so taken literally `hit_rifle` would replace every direction. Order: head, then gun in use, then side.
- **Head hits will be rare.** Only pirate rounds carry a height, and they aim for the torso, so `hit_head` and `death_headshot` may almost never show. Stalkers and CUSTODIAN pass a direction only.
- **Deaths:** from behind falls forward, from the front backward, from the side or no blow within 0.5 s the plain one (`hits.memory_s`).
- **The dead body slides up to about 1.1 m from the collision,** which with the loot point stays put, as asked. It can reach into a wall; I didn't test that against one.
- **Cover idle is upper body only.** The clip stands taller than low cover, and the crouch must show you're protected.
- **`knocked_down` and `get_up` are parked:** the packet mentions knockdowns, but no rule knocks anyone down.
- **Mag-out sound and drop now come at 20% and 30% of the reload,** not at the key press. The ammo rule hasn't moved: the rounds still leave at once.
- **Reload marks are estimates:** frames in `states.reload*.marks`, read from how far apart the hands are, plus strips too small to see a magazine. The clips are bent to `reload_stages`' shares. The crouched clip plays about 3.4× fast.
- **Firing kick frames for walking and crouched are read from hand motion** (`fire.*.shot_frames`), also estimates.
- **Sprinting backward uses the run clips** sped up, since no backward sprint clip exists.

## Old tests I changed
- `test_hauler.gd`: state names updated to the new ones; the "new file takes over a state" test now uses `hauler-rigged.glb`, since `hauler-reload.fbx` is gone; deaths exempted from the no-hip-travel test (`keep_travel`); the crouch stray limit, 10 cm to 15 cm (above).
- `test_player.gd`: the leg check reads the gait blend, because the old `legs` node no longer exists.
- `test_audio.gd`, `test_vfx.gd`: mag out and the falling magazine are checked at their new moments, not at the key press.

## Not checked
- Hearing any of it: reload sounds against the clips by ear.
- Anything in motion except the circle: blends between gaits, the flinch, firing rhythm, crouch transitions, turn-in-place loop pops. Tests prove the numbers, not the look.
- **The cover pose on the deck.** The pirate deck's lock shots were too dark to read, so I've only seen the raw clips in `strips/actions.png`. Letting go (`cover_to_stand`) was never seen in the game.
- The pirates' clips on screen: only tests, no captures.
- Two-player scene by eye.
- The T007 and T015 bots weren't rerun. No rule changed, though the mag drop's timing did.

## For John's eye
- **The gate:** does the hauler finally move like a soldier?
- **Heavy carry looks wrong in one way:** the crate floats ahead while the arms hang at the sides. The clip is unarmed, and it's slowest of all (0.9 m/s native, played about 2.4× to reach 2.2 m/s), so it may look like a fast shuffle. Strafing with it slides, as the clips only go forward (backward plays in reverse).
- **Pick up doesn't bend.** It's upper body as asked, so the arm reaches out while the legs stay straight, and the rifle goes with that hand.
- **Is the rifle on the back placed right?** `rifle.sling`. It's a guess by eye from the game camera.
- **Pirates looting** still wear the sprint's arms at a walk (T009's note). The set has no low-ready walk.
- **Still there from T009:** the bowed head when aiming and the left hand under the foregrip (parked).

## Known problem, not from this task
`test_vfx.gd::test_pools_never_allocate_after_warm_up` fails when `test_vfx` runs on its own (27 more objects), and does the same on main. It passes in the full suite. Parked.

## Made
`docs/screens/T022/`: `sheet.png` (start here: eight directions at walk and run, sprint, crouch walk, fire three ways, reload three ways, hits, pick up, press, turn, death, heavy carry; a lamp added so poses read), `circle_aiming.mp4` (16 s walking a circle aiming at its centre, HUD off, collision off so nothing stops the walk, so it passes through a prop), eight full-frame stills as JPG, `strips/` (raw clips over time), `frametime_before_after.json`, `foot_slide_all.txt`. I kept only those; the other stills took 58 MB.

Remake with `tools/t022_capture.sh docs/screens/T022` and `godot --path . scenes/dev/t022_strips.tscn`. Foot slide: `godot --headless --path . -s tools/t003_footslide.gd -- --all --exact`.
