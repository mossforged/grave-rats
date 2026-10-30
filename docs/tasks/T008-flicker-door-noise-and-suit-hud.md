# T008 - Flashlight flicker, door noise rule, and the suit-OS HUD with the noise ring (code)

**Modules:** `src/sight/` (flashlight), `src/enemies/` and `src/doors/` (door rule), new `src/hud/` (suit OS HUD). **Read:** `CLAUDE.md`, `docs/playtests/log.md` (the 2026-10-30 entries), `docs/decisions.md` (2026-10-30 lines), `docs/handoffs/auto-T006.md` (flicker section), `docs/handoffs/auto-T007.md`, the contracts of the modules above and of `src/health/` and `src/cover/`, `docs/screens/A005/sheet.png` (A005-05 and A005-06b, the HUD). **Needs:** T007 merged.
**Autonomy:** human-gated (John checks the flicker is gone, the HUD reads, and the ring helps).

T007 started before its addendum landed, so items 1 and 2 are that addendum, unchanged. Item 3 is new.

## Do
1. **The flashlight flicker, located by John:** "there is the steady cone of white for the light, and then there's a more abstract lower shape that's sort of flickering. It's visible kind of lower on the screen from it a little bit, like almost overlaid, but not quite."
   - **The lead's suspect:** the beam mesh `flashlight.draw_beam()` (`src/sight/flashlight.gd`). It's rebuilt every frame as a fan from the sight polygon, sloping from `beam.start_height_m` to `end_height_m`, so it sits lower than and offset from the real SpotLight cone, and its edge follows every polygon change.
   - **Confirm first:** with the beam mesh hidden, does the second shape go away? Capture both.
   - **Fix so there is one light shape:** no frame-to-frame jitter (stabilise the ring, or build it from a fixed cone clipped only at walls), lined up with the spotlight's footprint.
   - Test the beam's vertex change per frame while standing still and while turning slowly. Before and after captures.
   - Check the sight mask's stair-stepped edge for the same crawl.
   - The pirates' flashlights use the same code, so check them too.
2. **Gunshots don't start door-breaking** (John: "I don't want one fight to cause everything to trigger necessarily"):
   - A stalker breaks a shut door only if it was **hunting you** (it saw you, or was stalking you) when you went behind that door.
   - A gunshot it hears through a shut door makes it **investigate up to the door and linger**, then give up.
   - Hearing through shut doors uses a reduced radius (data, start at 50%).
   - Update T006's door tests; add one: a fight in one room doesn't send a stalker two rooms away into bashing.
3. **The suit-OS HUD with the noise ring** (`src/hud/`). John picked A003-02 / A005-05: the company-issue suit interface, with the ring around the operator showing **noise** (decided 2026-10-30).
   - **Ring:** a segmented ring on the floor around the operator. It swells when you sprint and blooms outward when you fire, to the real hearing radius the stalkers and pirates use, then shrinks back. Quiet walking leaves it faint or empty, and crouch-walking keeps it smaller. It's drawn from the same numbers the AI hears with (no separate copy), and it's readable from the game camera without hiding the floor.
   - **Docks** in the A005-05 layout: suit integrity, ammo (magazine / reserve), oxygen "billed per minute" (a placeholder ticker is fine), the salvage credits tally (placeholder), the `IN COVER` / `LOCKED` / `CROUCHED` / `LIGHT OFF` states, and the cover shields. Remnant Asset Recovery mark top left, and a "RENTAL UNIT 04" watermark.
   - Muted, so it doesn't fight the lighting. It replaces the grey-box HUD pieces in every deck; the help line stays toggleable (H).
   - Use an open-licence condensed font (note the licence) or Godot's default if none fits.
   - All sizes, colours and timings in `data/hud.json`, with an F1 section.

## Acceptance
- **Headless:**
  - all old tests pass;
  - the beam's per-frame vertex change stays under a threshold when still and when turning slowly;
  - a gunshot through a shut door → investigate and give up, no bash;
  - a hunting stalker still breaks the door;
  - the through-door hearing radius comes from data;
  - the ring's radius equals the AI hearing radius for walk, sprint, crouch and gunfire;
  - every HUD number comes from data.
- **Windowed** (`docs/screens/T008/`):
  - the flicker before and after (beam on, beam off, fixed);
  - the HUD at rest, then sprinting, then firing (ring states);
  - the HUD in the tense state (low suit, acid, low ammo, in cover), like A005-06b;
  - frame time.
- **Human (John):** is the flicker gone, does the HUD read, and does the ring help?

Out of scope: real fonts licensing beyond noting one, the minimap, crew rows for co-op (show one row), loot.
