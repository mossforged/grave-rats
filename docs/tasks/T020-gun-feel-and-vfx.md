# T020 - Gun feel and environment effects (code)

**Modules:**
- new `src/vfx/` (an effect library: recipes in `data/vfx.json`, pooled emitters, decals, a debug gallery);
- `src/weapons/` (the shot timeline);
- `src/enemies/` and `src/pirates/` (hit reactions call the library);
- `src/audio/` (call the T017 bank's cues; add the layers below as cues).

**Read:**
- `CLAUDE.md`;
- **`docs/design/gun-feel.md` (the spec; this packet implements it)**;
- `assets/source/vfx/README.md` and `manifest.json`;
- `docs/screens/vfx/` (`vfx_sheet.jpg`, `flipbooks.gif`);
- `assets/source/props/catalogue.json` (`shell_casing`, `spent_magazine`);
- the contracts of the modules above;
- `docs/handoffs/auto-T017.md`.

**Needs:** T017 merged (the audio bank).
**Autonomy:** auto-ok for the wiring; human-gated on feel (John fires the rifle).

The lead generated a VFX texture set (flipbooks, decals, a shader noise) and two gun meshes, and wrote the gun-feel spec. Wire all of it.

## Do
1. **`src/vfx`:**
   - every effect is a recipe in `data/vfx.json`: textures, counts, lifetimes, velocities, gravity, colours and tints, light flashes, sound cues;
   - emitters are pooled; no allocation per shot;
   - flipbooks play from the manifest;
   - additive and blend materials as the manifest says;
   - decals project onto floor, walls and props, with a cap and oldest-first fade.
2. **The shot**, every row of gun-feel.md sections 1–3:
   - the flash from the sheet;
   - muzzle smoke and haze;
   - barrel wisps after long bursts;
   - casings with bounces and a cap;
   - magazine drops on reload;
   - surface-specific impacts. Surface comes from the hit collider's kit material (steel/hull = metal; clinical = panel; glass; enemy = by type);
   - ichor and blood splats on the surface behind the hit;
   - the arm kick.
3. **The shot's sound** (gun-feel.md section 4) as bank cues:
   - mechanical, body (round-robin), tail by room (`room_tail` per space), local thump, last-five-rounds layer, dry fire;
   - casing tinks by surface; magazine clatter;
   - impacts by surface with the ricochet chance;
   - distance low-pass and occlusion muffling;
   - the ambience duck.

   Placeholder sounds are fine (T017's generator, extended). The real packs come in a later packet.
4. **Environment effects** (gun-feel.md section 5) as recipes plus a deck placement list (`effects` in deck data):
   - put one sparking console, one smoke plume, one steam jet and the dust motes in each deck where the story fits;
   - also build fire, the acid/slime pool and the explosion, and leave them unplaced: they show in the gallery only.
5. **A debug gallery (F1 → Effects):** spawn any recipe at the cursor; play the shot sequence on a wall of each surface. John uses this to judge by eye.
6. **Budgets in data:** max particles, max decals, max casings. Report frame time with a 30-round mag dump into a metal wall at close range, on both decks.

## Acceptance
- **Headless:**
  - all tests pass;
  - every recipe loads and every texture exists;
  - pools never allocate after warm-up (count check);
  - caps hold after 500 shots;
  - surface-to-impact mapping is right for each kit material;
  - round-robin never repeats a body variant twice in a row;
  - the last-five-rounds layer plays only on rounds 26–30 of a 30-round mag.
- **Windowed** (`docs/screens/T020/`), from the game camera:
  - a burst into a metal wall;
  - a burst into a clinical panel;
  - shooting a stalker;
  - casings and a dropped magazine on the floor;
  - each environment effect in the gallery.

  Also a short screen recording of a full-mag dump, if the capture tool can.
- **Frame time:** idle, during the mag dump and with every environment effect running.
- **Human (John):** does the rifle feel heavy and real in a dark room?
