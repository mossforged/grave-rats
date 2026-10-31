# T009 handoff: John's hauler replaces the grey operator

Branch `auto/t009-mac`. Play it: F5 in the editor or `godot --path .` (`pirate_deck`, the main scene).

**Nobody has seen this move.** Numbers come from tests and a foot-slide bot, and pictures are stills. Whether the hauler moves right is John's call at the gate. I didn't run the T007 pirate bots. No fight rule changed, but the pirates' bodies did.

## What changed
1. **Hauler in:** copied to `assets/game/hauler/`, scaled 1.70 m to 1.80 m from data (×1.0588), then the game's ×1.15 on top. `assets/source/` is untouched.
2. **Clips mapped in data:** `data/hauler_anim.json`. The Mixamo files are retargeted, because their T-pose rest and body differ from the hauler's. Copying bone rotations by name wouldn't have worked.
3. **Root motion gone:** hips x and z are pinned in every state's clip.
4. **Rifle on the hand:** the legacy rifle's mesh sits on `mixamorig_RightHand`, placed from where the legacy aim pose grips it. A spine correction keeps the barrel level and on the torso's aim, whichever clips are mixed underneath.
5. **Pirates:** the same model, repainted by a shader over the same textures: orange plates to navy, fabric to off-white, grime kept (`body.hauler_paint`).
6. **Switch:** `"body"` in `data/player.json` and `"body.model"` in `data/pirates.json`, each `"hauler"` or `"legacy"`.

## States and sources
| State | Source | Type | Note |
| --- | --- | --- | --- |
| idle | `hauler-rifle-idle.fbx` | Mixamo | Legs only; the upper body plays aim |
| walk forward | `Walking` | Meshy | Only seen at low speed: accelerating, pirates looting |
| walk back | `Walk_Backward` | Meshy | A slow clip sped up, see foot slide |
| strafe left | `hauler-strafe-b.fbx` | Mixamo | Direction measured from the feet; a test guards it |
| strafe right | `hauler-strafe-a.fbx` | Mixamo | Same |
| run | `Running` | Meshy | This is the normal 3.4 m/s move |
| sprint | `Rifle_Charge` | Meshy | Natively 5.4 m/s, the game's sprint speed |
| turn in place | `Idle_Turn_Left`, `_Right` | Meshy | Hip turn removed, looped; **may pop at the loop, unseen** |
| crouch idle | `hauler-crouch-idle.fbx` | Mixamo | |
| crouch walk | `hauler-crouch-walk.fbx` | Mixamo | Forward clip for every direction, as on the legacy body |
| aim | `hauler-rifle-idle.fbx`; crouched `hauler-crouch-aim.fbx` | Mixamo | |
| low (sprint and looting arms) | `Rifle_Charge` | Meshy | **Pirates loot at a walk with these charging arms** |
| fire (recoil) | none | **Stand-in** | Upper spine kicks back, `aim.recoil_kick_deg` |
| reload | `hauler-reload.fbx` | Mixamo | A 3.67 s clip fitted to the game's reload time |
| roll | `Roll_Dodge` | Meshy | Plays on request; **no key uses it**, only the capture |
| hit | `hauler-hit.fbx` | Mixamo | A 2.3 s clip squeezed into the stagger time |
| death | `Dead` | Meshy | Holds the last frame until respawn |

- **No state uses a retargeted legacy clip.** The path works (`legacy:<clip>`) and has a test, but every state had a better source.
- **Packet correction:** the unnamed 2.97 s clip isn't a copy of `Dead`. Its hips barely move, so it's an idle. It's unused.
- **Unused:** `Lean_Forward_Sprint`, the other rolls, the rifle turns, `Walk_Forward_While_Shooting`, walk turns, `Run_to_Walk_Transition`, `Standard_Forward_Charge_inplace`.

### What to fetch next, most useful first
1. **Strafe run, left and right, and run backward.** The game moves at 3.4 m/s, but these clips are walks.
2. **Firing rifle** (upper body), to replace the recoil stand-in.
3. **Crouch walk backward and crouch strafes.**
4. **A low-ready rifle walk,** for the pirates looting.

Copy a new file into `assets/game/hauler/` as `hauler-<state>.fbx` or `.glb`, re-import, and it takes over that state with no data edit. Moving clips also need their clip speed set.

## Checks
| Check | Result |
| --- | --- |
| Headless tests | **247 passed, 0 failed, 0 load errors** (231 before, 16 new in `tests/test_hauler.gd`) |
| Import | Exit 0, no errors. The 13 old `invalid UID` warnings for `operator.glb` remain |
| Fresh clone | Imports, 247/247 |
| Height | 1.80 m rest, soles at 0 |
| Each state resolves | Clip, or declared stand-in (fire) |
| Horizontal root motion | Under 0.5 mm in every state |
| Rifle on hand | Under 3 cm through walk, roll and death |
| Barrel aim | Within about 14° of the aim standing, strafing and crouched (test threshold) |
| Pirate recolour | Shader over the same textures, colours from data, player keeps orange |

**Old tests I changed, please check these:**
- Five tests that read legacy bones or clips now force the legacy body: four in `test_player.gd`, and the rival paint test in `test_pirates.gd`. They still guard the legacy body. The new hauler tests only partly mirror them.
- The hauler's crouch test allows more than the legacy one: **10 cm of stray, not 3 cm**. It measured 14 cm stray against 8 cm settled, 6 cm over, so the feet do wander a little during the blend.

### Foot slide (`tools/t003_footslide.gd`, 3 runs each, average; 0 is perfect)
| Case | Hauler m/s (% of body speed) | Legacy m/s (% of body speed) |
| --- | --- | --- |
| Walk forward | 2.12 (63%) | 2.34 (69%) |
| Walk back | 2.38 (70%) | 3.32 (98%) |
| Strafe right | 3.12 (92%) | 4.86 (143%) |
| Strafe left | 3.48 (102%) | 5.26 (154%) |
| Crouch forward | 1.41 (94%) | 2.14 (143%) |
| Sprint | 3.71 (69%) | 4.10 (76%) |

- **Better than legacy on average, but not good.** Feet still slide a lot, and strafes slide at about body speed.
- **The tool is noisy:** the same build's walk forward ranged 56-68% on the hauler and 63-79% on legacy, so forward and sprint are too close to call.
- **Lightly tuned:** the clip speeds are the best of four sets, with one run for each of the three I swept. They sit well above the speeds measured from the feet, and lower play rates also won, so the feet may be under-animated. A better fit may exist.

### Frame time, `pirate_deck` (15 s, 1920×1080, M2 Pro, Metal, MSAA 4x, vsync off)
| Body | Average ms | p95 ms | p99 ms | Max ms |
| --- | --- | --- | --- | --- |
| Hauler, run A | 4.23 | 5.66 | 6.11 | 13.8 |
| Hauler, run B | 4.39 | 5.82 | 7.71 | 68.3 |
| Legacy, same session | 4.13 | 5.52 | 5.94 | 11.9 |

- **Cost:** about 0.1-0.25 ms on average, on single runs with load average about 3.4.
- **One 68 ms spike** in run B is unexplained. It wasn't in run A.
- **T008 isn't comparable:** it measured about 8 ms on a busier machine. Only this table's same-session runs are.
- `stalker_deck` wasn't measured.

## Screenshots: `docs/screens/T009/`
- **Default camera:** `hauler_idle`, `_walk`, `_run`, `_sprint`, `_strafe`, `_crouch`, `_crouch_walk`, `_aiming`, `_reload`, `_rolling`, `_dead`.
- **Comparison:** `hauler_beside_pirate`, `hauler_pirate_legacy` (all three in one frame).
- **Camera moved in:** `hauler_close_up`, `hauler_close_side`.
- **Every state's raw clip:** `clips_front`, `clips_back`, `clips_top`.
- **From the frame-time run:** `frametime.json` (hauler run A), `pirate_deck.png`, `pirate_deck_overlay.png`.
- Remake them with `CAPTURE_HAULER=1 tools/capture.sh scenes/pirates/pirate_deck.tscn docs/screens/T009 15` and `godot --path . scenes/dev/t009_sheet.tscn -- --out=docs/screens/T009`.

## Needs John's eye
- **The gate:** does the hauler look and move right from the game camera?
- **Bowed head when aiming:** the helmet tips well forward. From above it shows the orange crown, which may help, but up close the visor faces the floor.
- **Left hand:** near the foregrip but below it, with a visible gap in `hauler_close_side`. No IK.
- **Hands through the body:** I only checked this by eye in stills, not in motion or per clip.
- **Feet:** Mixamo clips are stood on the floor by a measured hip lift (8-10 cm). Meshy clips are as they came: in `Walking` and `Running` the ankle rides about 2.5 cm high and the toes dip about 4.5 cm below rest.
- **Pirate paint:** it reads apart clearly, but the fabric is quite white and the plates a brighter blue than navy under strong light. `body.hauler_paint` tunes it.
- **Close-up:** a cut-away wall fades across the hauler's left side in `hauler_close_up`. That's the framing, not the model.

## Known gaps
- `stalker_deck` staggers don't play the hit clip, because `src/enemies` was outside this packet. Death does play there.
- Stalker decks and every other operator scene also wear the hauler now, since the switch is global. The asset viewer and study stand-in stay legacy.
- The hauler adds 42 MB to `assets/game/`: the GLB, three textures and eight FBX files.
