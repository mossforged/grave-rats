# T017: a placeholder sound pass (auto, code)

Branch `auto/t017-mac`. **Nobody has heard any of this, me included.** I can measure levels and read a spectrogram, but whether it sounds like a place is John's call.

**Dependency:** the packet says "Needs: T016 merged", and T016 isn't merged, so this branch starts from `main` without it. T017 doesn't use anything from T016. In a trial merge with `auto/t016-mac`, the only conflict is `docs/STATUS.md`, where both branches rewrote the same lines; code and data merge clean. I haven't run the tests on the merged result, so run them at merge.

## What changed
- **`src/audio/` (new), autoload `Audio`:** the bank, the buses (SFX, Ambience, UI, VoicePlaceholder), a hard limiter on the master bus (ceiling -1 dB), a fixed pool of 24 positional and 12 flat voices, and the listener. The listener stands at the player and turns with the camera, so left on screen is left in your ear.
- **`data/audio.json`:** 44 cues, each with file, volume, pitch variance, max distance, cooldown and bus, plus the rule numbers. Bus and master volumes are F1 sliders ("Audio buses"), added through `data/debug.json`, so `tuning_panel.gd` is untouched.
- **`tools/audio/gen_placeholder_audio.py`:** synthesises all 44 to `assets/game/audio/<group>/ph_<cue>.wav` (3.8 MB). I ran it twice and got identical files.
- **Call sites:** weapons, enemies, custodian, doors, shift and player (footsteps, crouch rustle). `weight_deck` also has a few audio lines beyond footsteps: it points the listener at the operator and stops the sound when the deck leaves.
- **Noise-ring logic unchanged.** No line of `StalkerPack.noise`, the brain's hearing or the ring's rules changed. A test plays loud cues beside a stalker and checks that neither it nor the ring reacts.
- **Removed:** `src/shift/placeholder_siren.gd` and the old generated-sound numbers in `data/enemies.json`, `shift.json` and `custodian.json`.

## Checks
- **Import:** `godot --headless --path . --import` exits 0 with no errors.
- **Headless tests:** 423 passed, 0 failed, 0 load errors (383 before; `tests/test_audio.gd` is new, 40 tests). They cover:
  - every cue exists and loads, and carries its placeholder label;
  - every event in the packet's list plays its cue, on the real deck;
  - every one-shot's cooldown holds;
  - the twins: the hum is on exactly while the rings and line show, the burn comes with the beam, each chirp comes with that many bars lit, the hiss with the glow, the spit with a glob.
- **Recording:** `tools/t017_sound_capture.sh docs/screens/T017` runs one scripted sequence through Godot's Movie Maker, which uses the real GPU but sends nothing to the speakers. I run it three ways: normal, with no limiter, and with every bus 12 dB too hot.

| Segment (seconds) | Peak dBFS | Peak, no limiter | Peak, limiter, 12 dB hot | RMS dBFS |
|---|---|---|---|---|
| room tone, cargo (0–2) | -23.3 | -23.3 | -11.3 | -35.9 |
| spit wind-up, spit, a lunge (2–4.5) | -10.9 | -11.1 | -1.0 | -31.8 |
| cutter warm-up and burn (4.5–8) | -9.0 | -8.9 | -1.0 | -21.6 |
| alarm, panel burst (8–12) | -4.9 | -4.6 | -1.0 | -11.9 |
| three stalkers, CUSTODIAN, alarm, rifle on full auto (12–20) | -1.6 | -1.7 | -1.0 | -12.6 |

No sample reaches full scale in any run. The mix stays under the ceiling by itself even in the pile-up, so the limiter is a backstop: it only acts in the hot run, where it holds exactly -1.0. Differences of a few tenths between columns are random pitch variance between runs, not the limiter. In the recording the alarm ends at 18 s, as its data says, so the last 2 s of the pile-up have no siren. The cue-by-cue timeline is in `docs/screens/T017/cues.json`.

- **Frame time, `shift_deck`, 1920x953, real GPU, one run:** 6.65 ms avg, 9.65 ms p95. T015 was 6.88 / 10.15 and 6.82 / 9.81 at 1920x1080, so no sign of a cost, though the window size differs and that capture is muted (it still mixes). The capture's busy moments aren't a pile-up like the recording's, and I didn't measure frame time during one.

## Not checked
- Anything by ear: whether the sounds are good, whether the panning feels right, whether the levels work on John's speakers. The real sound driver only ran muted, through the capture. It ran without errors there.
- Co-op. Each client would follow its own player, but only the solo path exists.
- Pirate gunfire: `src/pirates` wasn't in the packet, so it keeps its own placeholder on the master bus, outside the SFX slider (it does go through the limiter).

## Calls I made (each is a data change if wrong)
- **The tier chirp is now the oxygen warning tone.** Tiers are the O2 60% and 30% announcements, so one sound does both. It also repeats every 2.5 s once the air's gone, with the O2 alert on screen.
- **The chime plays with the line, not ahead of it.** The line shows at the moment the chime starts. There's no voice audio, only the chime, on the voice-placeholder bus.
- **Surfaces:** medbay and cargo are deck plate, the junction is grate, the side corridor is wet (`footsteps.surfaces`). Nothing in the deck data said which is which, so this is a guess.
- **Stalkers can be heard through walls** (clicks, chirps, hiss), up to 16–20 m, with no occlusion. It tells you something's near that you can't see, which is the point, but it is information the sight rules otherwise hide. First lever: `max_distance_m` on those cues.
- **The locked buzz also plays when someone's standing in a closing door.** It's the same "no" from the door.
- **Ambience keeps playing behind the forms; breathing stops.**
- **Added beyond the packet's list:** `bulkhead_burst` (the ambush bang already existed and needed a sound), and muting any `--capture-out` run, so unattended captures don't sound a siren in the room.

## Made
`docs/screens/T017/`: `sequence.mp4` (20 s, picture and sound), `sequence.wav` (the mix), `levels.json`, `cues.json`.

## For John's ear
`godot --path .`, or watch `sequence.mp4` first. Does it sound like a place, and do the warnings warn?
- Walk medbay, junction, cargo: do the room tones change enough? They're low on purpose (cargo about -36 dBFS RMS) and may be too low. F1 → Audio buses → Ambience, then Save.
- Does the cutter's rising hum and the spit's hiss make you move before you've read the ring or the glow?
- Is the alarm too much? It's the loudest thing that lasts, about -12 dBFS RMS for its whole length, and it can bury the cutter's hum and the chirps you most need then. Level: `alarm_siren.volume_db`.
- Is breathing noticeable without being annoying, and does it read as fear when the suit or air is low?
