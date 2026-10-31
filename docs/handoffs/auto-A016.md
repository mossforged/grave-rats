# A016 — arsenal concepts

Status: concept-selection packet; **John's selection is required before modelling or implementation.** No game imports or code changes. No git commands run.

## Review

- Source cards, exact submitted prompts, one-line design briefs and machine-readable inventory: `assets/source/A016-arsenal/`.
- Matrix: `assets/source/A016-arsenal/A016-00.png` and searchable `A016-00.md`.
- Contact sheet: `docs/screens/A016/sheet.png`.
- Built-in image_gen used, one independent request per weapon. Refused images were skipped without retries. Full refusal results are recorded in `assets/source/A016-arsenal/generation-results.json`; the final inventory below distinguishes generated and refused IDs.
- 18 concepts: six salvage tools, five company weapons, three Prior Claim loadouts, four thrown/deployed items. Each prompt includes side profile, metric length bar, 1.8 m operator reference and steep camera hauler demonstration. The accepted cards' human silhouettes are separate references rather than shared-scale comparisons; use numeric dimensions for modelling. Generated dimensions are illustrative, not engineering drawings.
- Camera thumbnails are downsampled concept crops using the A005 96 px review convention, with exact nearest-neighbour 2x previews. They are not engine captures or proof of retargeting. Refused slots have no substitute artwork.
- A015 has not landed: no A015 bestiary art or handoff found at session start. Threat matches for its swarm, parasite, brute, spiders, drone, horror and pirate variants refer only to the proposed task roster. They do not establish counter mechanics. Existing stalker and Prior Claim matches are distinguished in the matrix.

## Recommended first six (design shortlist, including skipped art)

1. **A016-07 Issue rifle:** general-purpose baseline with the existing shot/reload pipeline and readable recoil. Keeps the first comparison anchored to the current weapon.
2. **A016-08 Budget shotgun:** trades reach and follow-up speed for a strong doorway burst. Detachable magazine and self-loading action avoid requiring pump or individual shell-loading animation.
3. **A016-04 Flare gun:** spends ammo to place light and reveal routes. Makes light useful beyond the flashlight without presuming that proposed horrors take damage from it.
4. **A016-01 Plasma cutter:** short reach and heat management in exchange for cutting doors and close denial; a utility decision rather than a stronger rifle.
5. **A016-15 Frag charge:** flushes a held position at the cost of a committed throw, finite supply and blast risk; uses the existing grenade motion.
6. **A016-18 Decoy beacon:** buys escape time through sound, giving crews a non-damage answer. Requires explicit AI investigation behavior before it can work.

These are proposed side-grades. Range, fire rate, mass and ammo economy are concept targets only. Prior Claim gear exchanges speed, turn response, noise, ammo cost or dependency for specialist roles; it is not a permanent damage-upgrade tier. Satirical copy is proposed and awaits selection/copy review.

## Animation compatibility and missing clips

The manifest contains `rifle_aim_idle_loop`, `rifle_fire`, `rifle_reload`, crouch/walk/run variants, `rifle_melee`, `rifle_throw_grenade`, and pistol locomotion/hold/fire clips. It does **not** contain a pistol reload, pump cycle, shield brace or heavy-autocannon reload.

- **A016-01/02/03/07/08/12:** two-handed rifle grips; ordinary cassette/cell/box-mag swaps can adapt `rifle_reload`, with grip and attachment checks. Beam and pneumatic actuation are equipment effects, not a new body pose.
- **A016-04/09/11:** right-hand pistol class fits pistol holds/fire; **pistol magazine reload animation is missing**. The flare concept deliberately uses a magazine rather than a break-open action; a classic break-open flare pistol would also need a loading clip.
- **A016-05:** horizontal ram uses `rifle_melee` as a committed bash. No overhead hammer swing or hydraulic spreading interaction is proposed. Dedicated spreading would need a new interaction animation.
- **A016-06:** rifle launch/hold fits; **reeling/recovering the harpoon needs a dedicated clip or a deliberately stationary equipment-only approximation**. Existing clips do not prove reel operation.
- **A016-10:** rifle hold/fire and box-mag reload fit; **pump-cycle animation missing**. Do not pretend the rifle reload supplies it.
- **A016-13:** SMG uses right-hand pistol base; **left shield brace, shield-compatible locomotion and reload are missing**. Concept is a specialist sidearm loadout, not ready to implement with untouched pistol clips.
- **A016-14:** long-gun class only; **heavy brace/slow locomotion treatment and oversized-magazine reload need work**. No hip-fire/minigun pose assumed. A new equipped heavy class is proposed, distinct from the existing two-handed salvage carry that prevents firing.
- **A016-15/16/17/18:** `rifle_throw_grenade` for all. Mine and beacon deploy by throwing, avoiding an unsupported crouched placement gesture. Clip timing, object release, hand contacts and suit retargeting still require code-lane verification.

## Systems required if selected

- **Cutter:** short continuous beam, heat/cell consumption, door-cut progress and permissions, continuous audio and bounded light.
- **Rivet driver:** projectile travel, stagger and eligible wall-pin constraints; exclude unsupported pin targets.
- **Nail gun / shotgun / scoped rifle:** burst or pellet patterns, spread/impact budgets, deliberate aim and occluded laser tell. Reuse existing ballistics where possible; no assumed new first-person scope.
- **Flare:** arcing projectile, burning lifetime, persistent light budget and optional light reactions only after threat design approves them.
- **Ram:** melee contact window, push/stagger, door breach rules.
- **Harpoon:** cable simulation/constraint, anchors, target mass eligibility, range, reel/release and co-op ownership.
- **Smart pistol:** signed-ammo authorization, lockout feedback and modest aim assistance. The fiction must never imply a real player payment service.
- **Repossession launcher:** nonexplosive impulse projectile, cover/target mass rules and pump timing.
- **Debt pistol:** display/counter and economy hook; ballistics otherwise reusable. Fees are proposals, not changes to the approved quota system.
- **Shield + SMG:** directional coverage, movement and turn limits, muzzle clearance and one-hand automatic recoil.
- **Autocannon:** equipped heavy class, movement/recoil limits and large ammo budget; no power-creep unlock assumption.
- **Frag:** throw arc, fuse, blast LOS/occlusion, damage/friendly-fire policy, debris and audio.
- **Flashbang:** LOS-gated interrupt/exposure, readable bounded flash, AI light reaction if approved.
- **Motion mine:** thrown placement, delayed arming, motion filtering, team attribution, trigger LOS and blast.
- **Decoy:** deployed spatial noise source and AI investigation/priority rules, duration and retrieval.

Gun-feel briefs specify flash, mechanical/body/tail sound and surface impact identity. Actual sounds, VFX and game stats are not delivered by this concept packet.

## Visual QA

Both accepted cards were opened and inspected: side profile, length bar, 1.80 m reference, orange/cream hauler and steep downward view are present. The decoy is shown in a held pre-release demonstration, not proof of a grenade animation. Its scale bar spans the main body while the handle projects past it; treat 0.22 m as the proposed body length and confirm total length including handle when modelling. The rivet profile and held view broadly agree, but exact hand placement and barrel length require 3D verification.

## Human gate

John: select which concepts get built, especially whether to fund beam/door cutting, persistent flare light, decoy investigation, tether physics, shield support or the heavy equipped class. Work stops at the requested concept-selection gate; no modelling or import is authorized by these recommendations.

## Final generation inventory

**2 generated / 16 refused and skipped.** The requested breadth of image art could not be produced because of tool refusals; all 18 prompts and written designs remain reviewable. No refusal was retried or disguised with substitute artwork.

| ID | Concept | Image result |
|---|---|---|

| A016-01 | Plasma cutter | Safety refusal (`violence`); skipped. Request c8428345-cdda-48c7-bb1f-c49f81f9ee95. |
| A016-02 | Rivet driver | Generated; visually inspected. |
| A016-03 | Nail gun | Safety refusal (`violence`); skipped. Request 373a3bbb-c5ab-4274-96fa-91769f4bd962. |
| A016-04 | Flare gun | Safety refusal (`violence`); skipped. Request 994dfc1a-41f5-4ac5-b20a-7479930b2e44. |
| A016-05 | Breach ram | Safety refusal (`violence`); skipped. Request 20c0085a-cce0-4cf4-8879-8c86e857cace. |
| A016-06 | Tether harpoon | Safety refusal (`violence`); skipped. Request 8011f718-7eb5-4956-9e20-0877dbde0a41. |
| A016-07 | Issue rifle | Safety refusal (`violence`); skipped. Request b8fd520c-7a94-4a7c-ba6d-6c5277cc4320. |
| A016-08 | Budget shotgun | Safety refusal (`violence`); skipped. Request c4d51d6a-55fd-4227-8159-97b6332ebea5. |
| A016-09 | Subscription smart-pistol | Safety refusal (`violence`); skipped. Request c01bc98c-852f-4d92-bcb0-4d96f23cdeb4. |
| A016-10 | Repossession launcher | Safety refusal (`violence`); skipped. Request 3370f67c-861f-4e38-a6b3-b63b096a7515. |
| A016-11 | Debt-counter sidearm | Safety refusal (`violence`); skipped. Request 8586e8e9-67de-4278-b547-b3995a569c2c. |
| A016-12 | Prior Claim scoped rifle | Safety refusal (`violence`); skipped. Request 7a2518e9-7efd-4705-a666-67dbd3b10919. |
| A016-13 | Prior Claim shield + SMG | Safety refusal (`violence`); skipped. Request bf363eb9-79db-418a-a677-b3611d96e4db. |
| A016-14 | Prior Claim autocannon | Safety refusal (`violence`); skipped. Request 12d97c1f-2d02-455e-9f66-c62403350209. |
| A016-15 | Frag charge | Safety refusal (`violence`); skipped. Request bf6d37bd-7bd6-4843-82a9-b346c3fdbd4b. |
| A016-16 | Flashbang | Safety refusal (`violence`); skipped. Request c80d732d-fb38-47cf-a79c-3811d3502b8c. |
| A016-17 | Motion mine | Safety refusal (`violence`); skipped. Request 10254e6d-ed8a-4e55-b64c-c046ace6296e. |
| A016-18 | Decoy beacon | Generated; visually inspected. |

Validation: opened both generated cards and the assembled review artifacts; checked all 18 unique IDs, prompt sidecars and result records, PNG readability, matrix text fit, and that every absent weapon image has an explicit refusal. Outputs stay in the three permitted art-lane locations.
