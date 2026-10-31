# T022 - The full Mixamo shooter set on the hauler (code)

**Modules:**
- `src/player/` (`hauler_clips.gd`, `hauler_anim.gd`, `hauler_retarget.gd`, `operator_anim.gd`);
- `data/hauler_anim.json`;
- `src/pirates/` only to use the same states (pirates wear the hauler body).

**Read:**
- `CLAUDE.md`;
- `assets/source/mixamo-shooter/manifest.json` (every clip: frames, loop, in place or not);
- the `src/player` contract;
- `docs/handoffs/auto-T009.md` (how clips retarget today);
- STATUS "Parked" (the hauler lines).

**Needs:** nothing (T021 merged).
**Autonomy:** auto-ok for the wiring; human-gated on feel (John plays).

John downloaded 88 Mixamo clips (Y Bot, `mixamorig:` bones, animation only) into `assets/source/mixamo-shooter/`. Today the hauler has about 10 clips, so strafes, backpedal and firing are faked. This set covers nearly every move the game has. Use them.

## Do
1. **Import** into `assets/game/hauler/clips/` through the existing retarget path (copies; never edit `assets/source/`). Keep the old clips until every state has a new one, then drop the unused.
2. **Locomotion: eight directions at walk, run and sprint**, blended by move direction against aim direction:
   - `rifle_walk_*`, `rifle_run_*`, `rifle_sprint_*` (sprint has forward, left and right);
   - clip speeds per direction in data. This replaces the single strafe speed: STATUS parked "separate left and right strafe clip speeds";
   - feet must not slide. Measure with the foot-slide tool, as T009 did.
3. **Crouch:** idle, aim idle and four-direction walk (`rifle_crouch_*`), with the stand-to-crouch and crouch-to-stand transitions. These move the hips, so play them in place or let the crouch blend absorb it; say which.
4. **Firing:** `rifle_fire`, `rifle_fire_walking`, `rifle_fire_crouch` on the upper body (`upper_bones`), synced to T020's shot timeline. The arm kick stays additive on top.
5. **Reload:** standing, walking and crouched variants (`rifle_reload*`), stretched to `reload_s` from data, with T020's mag-out and mag-drop sounds timed to the clip's real moments (mark the frames in data).
6. **Turning in place:** `rifle_turn_left` and `rifle_turn_right` when aim turns past a threshold while standing still.
7. **Hits and deaths:**
   - hit reacts by direction relative to facing (front, back, left, right, head for a hit above the neck, `hit_react_rifle` when aiming), short and additive so control isn't lost;
   - deaths by cause: `death_headshot` for a head hit, forward or backward by hit direction, `death_rifle` otherwise;
   - deaths and knockdowns move the hips: let them move the body visually, but the collision and the dropped-loot point stay where the player fell.
8. **Actions:** `pick_up` when taking salvage (upper body, quick, cut short if you move); `interact_button` for E on doors and panels; `cover_idle_loop` and `cover_to_stand` for the pirate deck's lock.
9. **Heavy carry:** `unarmed_walk_loop`, `unarmed_idle_loop` and `unarmed_crouch_*` while carrying a heavy item, with the rifle slung (STATUS parked "a carry pose"). Note this if heavy carry already blocks firing in the rules; don't change the rule.
10. **Pirates** use the same states, since they wear the same body.
11. **Not now (park):** jumps, falls, ladder, vault, slide, melee, grenade, pistol, unarmed punch. No systems use them. List them in STATUS "Parked" as available clips.

## Acceptance
- **Headless:**
  - all tests pass;
  - every state in data maps to a clip that loads;
  - move direction against aim picks the right blend in all eight directions;
  - reload, fire and hit react never leave the lower body stuck;
  - foot slide per locomotion clip under the T009 threshold (report the table).
- **Windowed** (`docs/screens/T022/`):
  - a sheet of the eight directions at walk and run, from the game camera;
  - crouch walk;
  - fire standing, walking and crouched;
  - reload;
  - one hit react;
  - one death;
  - carrying heavy;
  - a short recording of walking a circle while aiming at a fixed point, if the capture tool can.
- **Frame time:** the shift deck before and after (more clips and blends).
- **Human (John):** does the hauler finally move like a soldier?
