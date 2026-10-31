# A016 - Weapons: concept art for the arsenal (art)

**Read:**
- `AGENTS.md`;
- `docs/handoffs/game-brief.md`;
- `docs/design/tone-bible.md`;
- `docs/design/gun-feel.md` (what a shot is made of);
- `docs/design/run-loop.md` (light progression: cosmetics and side-grades, not power creep);
- `docs/screens/A005/sheet.png` (the hauler and the current rifle);
- `docs/screens/A009/` (Prior Claim's better-funded gear);
- `assets/source/mixamo-shooter/manifest.json` (the animations we have).

**Needs:** nothing. **Autonomy:** human-gated (John picks what gets built).

There is one rifle today. John wants concept art for a bunch of possible weapons. The crews are broke salvagers: most of their arsenal is industrial tools pressed into service, cheap company-issue guns with fees attached, and whatever they pry off dead pirates. Prior Claim carries the expensive version of everything.

**Design to the animations we have.** John's Mixamo set has rifle holds (walk, run, crouch, fire, reload), pistol holds, a grenade throw and a rifle melee. Every weapon must fit one of these:
- **long gun:** two hands, rifle clips;
- **sidearm:** one hand, pistol clips;
- **thrown:** the grenade clip;
- **melee:** rifle melee, or a tool swing on the same clip.

Say which for each.

## Do
Save each to `assets/source/A016-arsenal/A016-NN.png` with a `.prompt.md`. For each weapon:
- a clean side profile on a plain background, with a scale bar against a 1.8 m operator;
- the hauler holding it (or throwing it) from the game camera;
- a one-line note: role, how it fires, ammo, its gun-feel signature (flash, sound, impact), and its satirical hook (a fee, a waiver, a sponsor).

Roughly 16–20 weapons:
1. **Salvage tools as weapons** (5–6):
   - plasma cutter (short beam, cuts through doors too);
   - rivet driver (slow, heavy, pins things to walls);
   - nail gun;
   - flare gun (light as a weapon, given pillar 2);
   - hydraulic spreader or breaching ram (melee);
   - a tether or harpoon line.
2. **Company issue** (4–5): the current rifle (redrawn consistently with the rest), a cheap shotgun, a subscription smart-pistol that locks without paid ammo, a pump-action "repossession" launcher, a sidearm with a debt-counter display.
3. **Pirate kit, Prior Claim's** (3–4): what you take off their bodies — a scoped rifle with a laser, a riot shield and SMG pair, a heavy autocannon you can barely carry (a heavy carry class?).
4. **Throwables and deployables** (3–4): a frag charge, a flashbang (light again), a motion-sensor mine, a decoy beacon that makes noise.
5. **A matrix sheet (A016-00):**
   - every weapon's silhouette at game scale;
   - its hold class;
   - one line each for role, range, rate and weight feel;
   - which threats from A015 (if it has landed) it answers;
   - your top six for a first arsenal that covers different jobs, not just more damage.
6. **Contact sheet** at `docs/screens/A016/sheet.png`.

## Acceptance
- The images and prompts, the matrix, and the sheet.
- `docs/handoffs/auto-A016.md`:
  - your top six and why;
  - any weapon that needs an animation we don't have, named plainly;
  - which ones need a new system (a beam weapon, a tether, mines).
