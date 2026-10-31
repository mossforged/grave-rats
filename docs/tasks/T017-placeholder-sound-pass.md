# T017 - A proper placeholder sound pass (code)

**Modules:** new `src/audio/` (a small sound bank and player), call sites in `src/weapons/`, `src/enemies/`, `src/custodian/`, `src/doors/`, `src/shift/`, `src/player/` (footsteps only). **Read:** `CLAUDE.md`, `docs/studies/2026-10-30-comparable-games.md` (presentation: every audio cue has a visual twin; sound carries information), the contracts of the modules above. **Needs:** T016 merged.
**Autonomy:** human-gated (John listens).

Every sound so far is generated noise that nobody has heard. Sound is half of the dread, and it also carries information the player needs. Make a coherent placeholder set, synthesised in code or by a script in `tools/` (no downloads, no purchases), each named and labelled as placeholder so real audio can replace it file by file.

## Do
1. **A bank** (`data/audio.json`): every cue with file, volume, pitch variance, max distance, cooldown and bus (SFX, ambience, UI, voice-placeholder). Positional 3D audio for world sounds; buses with their own volumes in F1.
2. **Generate the set** (a script in `tools/` writing `.wav`/`.ogg` to `assets/game/audio/`, re-runnable):
   - **player:** footsteps by surface (deck plate, grate, wet), a crouch rustle, the suit breathing (subtle, faster at low suit and low oxygen), pick-up and drop by class (heavy is a loud thud);
   - **weapons:** the rifle shot (punchy, with a tail), dry fire, reload stages (mag out, mag in, charge), the casing tinkle;
   - **stalker:** an idle click and chirp, the spit wind-up hiss, the spit, the lunge screech, hit and death, vent scuttle (spawns), door banging;
   - **CUSTODIAN:** the cutter's warm-up hum (rising with the ring), the burn, the drone chirp (rising per bar), an announcement chime before each voice line;
   - **ship:** an ambient hum per room (medbay a clean high hum, cargo low machinery, junction air flow), doors (open, close, locked buzz, breaking), lights failing (a clunk and buzz), the alarm siren, the oxygen warning tone;
   - **UI:** form stamps for the paperwork (accept, acknowledge), the payslip ledger tick.
3. **Wire the call sites**, with the noise-ring logic unchanged (sound you hear is not the AI's hearing; keep those separate).
4. **Mix:** the rifle and the alarm loud; ambience low; nothing clipping when three stalkers and CUSTODIAN are all going. A limiter on the master bus.

## Acceptance
- **Headless:**
  - all tests pass;
  - every cue in the bank exists and loads;
  - every gameplay event in the packet's list triggers its cue (signal-level tests);
  - cooldowns hold;
  - no cue plays without its visual twin where one exists (the drone, the cutter and the spit have both).
- **Captures:** a short screen recording or audio dump of one scripted sequence (spit wind-up, cutter warm-up, alarm), plus peak levels in the handoff.
- **Human (John):** does it sound like a place, and do the warnings warn?
