# T021: loose ends from T016 to T018 (auto, code)

Branch `auto/t021-mac`. All four items are in. Look at `docs/screens/T021/sheet.png` first. **Nobody has played or heard this.**

**Dependency, for the lead:** the packet says "Needs: T020 merged", and T020 isn't on `main`. I left it out, as T017 and T018 did with theirs, so T021 can't carry T020 past John's feel gate. T021 builds on `main`, and item 3 uses T017's cue, which the packet allows. See "Merging".

## What changed
1. **Bed:** I chose the hazard stripe. A kit `hazard` stripe runs along both long rims of the bed's file (`KitPieces.bed_edge_stripe`, `TipBed.edge_stripe`, numbers in `data/kit.json` `bed_edge_stripe`). Whichever way the bed falls, one rim is the top edge the steep camera sees. No light was added, and collision and cover are untouched.
2. **Wall-top band: it was ours, and it's fixed.** The cause is a z-fight, in the kit since T010 (commit `84496ff`). In `_wall_body`, the steel core's top sat at exactly `height`, the same plane as the painted cap insert and the hazard slash. Which one won depended on the camera, and the camera lands about a millimetre differently per stand (the X values varied by about 1 mm). So the whole band flipped. The core's top is now buried inside the cap.
3. **Pirate gunfire:** `src/pirates` plays `rifle_shot` through `Audio`, at the muzzle, on the SFX bus, fading with distance. Its private player, `src/enemies/placeholder_sound.gd` and the `sound` key in `data/pirates.json` are gone. **Occlusion is not in on this branch:** `main` has no occlusion for anyone's shots; it comes with T020 (see "Merging").
4. **Lock through commands:** Space sends `LOCK` through `Session.send`. While locked, `LockDriver` turns keys, RMB and LMB (or `scripted`) into a new `LOCK_CONTROLS` command each step, the way `Operator._send_local_input` does. `pirate_deck` consumes both. A `remote` operator is driven by commands alone.

## Checks
- **Headless:** 518 passed, 0 failed, 0 load errors (511 before, 7 new, 1 edited: `test_session`'s one-of-each list gained `lock_controls`).
- **Import:** exits 0, no errors.
- **Wall band test:** `test_no_two_surfaces_of_a_wall_share_a_flat_plane`. With the old line put back, it fails at y 2.600, on the plane the bug was on.
- **Pirate shots:** `test_a_pirate_shot_plays_a_bank_cue_at_its_muzzle_on_the_sfx_bus`, all three firing in one step. It names no cue, so it also passes after T020.
- **Lock with no keyboard:** `test_lock_works_from_commands_alone` runs lock, raise, fire, lower, tap and let go on a remote operator. Two more tests cover the ID, a dead suit, no authority, and Space becoming `LOCK`.
- **Bed:** in all four fall directions, the stripe is on the top rim, inside the footprint, with no light. It's proud of the file's rim by 4 mm, so it can't z-fight that rim either.

### Wall-top numbers
Band = the medbay's north wall top, in grey levels out of 255, six repeats of T016's stand (15 pairs).

| Run | Worst pair, band mean difference |
|---|---|
| T015's commit (`097973b`), 1 run | 14.20 |
| This branch before the fix, 2 runs | 13.82, 15.31 |
| After the fix, 2 runs | 1.22, 0.62 |

So it **predates T016**. T016's 13.9 is the same thing. The two "after" runs and the fog runs below had the core's top at the cap's underside; I then raised it to halfway up the cap, because the new test found that plane shared with the face plates' hidden tops. Both are buried, and the pinned pair below is the final code. What's left in those runs is the same millimetre moving the edges. With the camera held still on one seed (`wall_repeat.json`, the final capture):

| Pair | Band mean | Band max |
|---|---|---|
| Same camera, same seed | 0.037 | 1 |
| Camera moved 1 mm | 1.20 | 89 (edges; the sheet shows no flip) |

**The last 1–2 levels are the engine.** Across three check runs, with the same camera and seed, the band's max was 2 with everything on, 2 with `KIT_SSAO=off`, and **exactly 0 with `KIT_FOG=off`**. That points at volumetric fog's temporal reprojection, on one run each. I left it alone, as it's invisible. Outside the band, the same pinned pairs still differ around the player (up to 154 levels, x 670–1006, y 481–770). I didn't trace that; my guess is the operator's idle animation.

### Frame time
`shift_deck`, 1920x953, M2 Pro, real GPU, 10 s window, alternating, load average about 6, so not a quiet Mac.

| Run | `main` avg / p95 | T021 avg / p95 |
|---|---|---|
| 1 | 7.59 / 10.73 | 7.43 / 10.54 |
| 2 | 7.48 / 10.53 | 7.42 / 10.58 |

No cost shows. `pirate_deck`, one run on T021: 6.68 / 9.19, with nothing from `main` to compare.

## Not checked
- **Nothing by hand.** The real keys through `LockDriver` were never pressed, so whether solo lock feels unchanged is by reading: the same reads in the same step, with the same rules. Only Space was tested, as an injected event.
- **Pirate gunfire by ear.** Nobody has heard it, and it hasn't been recorded. Tests only prove cue, place and bus. On `main` it's now as loud as your own rifle at the same range (`rifle_shot`, -2 dB), where it used to be on the master bus.
- The tip's motion with the stripe on it, at speed.
- The T007 bots weren't rerun: they don't use the lock or read sound, and the stripe and wall fix change no collision.
- Only the pirate deck has a lock. Its one `LockDriver` is the local player's, so a second player's `LOCK` does nothing there. The shift deck ignores `LOCK`.

## Calls I made
- **`LOCK_CONTROLS` is a command the packet didn't name.** It says `LockDriver` reads Space and RMB directly. Space alone would have left RMB, LMB and WASD on the keyboard while locked. Each is a command now.
- **The stripe is on both rims and always shows,** so upright beds carry a yellow band on their long sides as well. That avoids it popping in mid-tip. It makes them read as tippable, but it is a look change.
- **Width:** `y_from_m` 0.36 to `y_to_m` 0.6, about 24 cm, so it reads from the steep camera. Thinner hugging the plate's 5 cm rim wouldn't.

## Made
`docs/screens/T021/`: `sheet.png`, `t021_bed_before` / `_after`, `t021_bed_dark_before` / `_after` (light off), `t021_bed_room_before` / `_after` (no mask), `t021_wall_repeat_a` / `_b`, `t021_wall_nudged`, `wall_repeat.json`, `frametime.json`. Before and after are the same stand with the stripe hidden, not the old commit. Remake: `tools/capture.sh scenes/dev/t021_stand.tscn docs/screens/T021 2`, then `python3 tools/t021_sheet.py`.

## For John's eye
- **The wall tops now show their paint all the time.** The hazard slashes and pale inserts used to come and go; now every other bay has its slash. That's the design from T010, but it is more yellow along the wall tops than he may be used to. Lever: `dims.hazard_cap_m`.
- **The bed (sheet):** clear with a light on it. With your light off in that corner it's still dim, though you can pick out the stripes. Is that enough? Levers: `bed_edge_stripe` `y_from_m` / `y_to_m`, or the deck's lighting.
- Are the striped upright beds OK?

## Outside the named modules
- `src/enemies/placeholder_sound.gd` deleted, with `src/enemies/CONTRACT.md` and `src/audio/CONTRACT.md` updated. T020 deletes the same file.
- `src/debug/t021_stand.gd`, `scenes/dev/t021_stand.tscn`, `tools/t021_sheet.py`, `src/debug/CONTRACT.md`, one stale comment in `t016_stand.gd`.
- `data/kit.json`, `data/pirates.json`.

## Merging
A trial merge of `auto/t020-mac` onto this branch, in a scratch worktree since removed, gave **566 passed, 0 failed, 0 load errors, import with no errors.** Git stops on `docs/STATUS.md`, `src/audio/CONTRACT.md`, `src/pirates/CONTRACT.md`, `src/pirates/pirate_squad.gd` and `src/study/CONTRACT.md`. To resolve:
- `pirate_squad.gd`: **take T020's side.** Drop my `Audio.play("rifle_shot", ...)` (T020 removes that cue) and keep its `_space_of`. T020's layered shot then gives pirates distance and occlusion, which is what item 3 asks for.
- `src/pirates/CONTRACT.md`: keep T020's "Their guns" line, drop mine, keep "The lock is a command".
- `src/audio/CONTRACT.md`: drop my `src/pirates` line under "Who calls what" if T020 has its own.

For the trial I resolved only `pirate_squad.gd`, and left the conflict markers in the docs, since they don't affect the tests.
