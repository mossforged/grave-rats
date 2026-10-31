# A015 — Threat bestiary

2026-10-31. Concept packet complete; **John selects what gets built.** No roster, mechanics, names or implementation approved by this packet. Stopping at that requested human gate.

## Deliverables

- `docs/screens/A015/sheet.png`: labeled 2220 × 3510 contact sheet, all 18 plates, five recommendations in gold.
- `assets/source/A015-bestiary/A015-01.png` through `A015-18.png`: eighteen 1536 × 1024 concept plates. Each shows the same threat in a hero view, a ship-interior steep oblique view, and an idle / warning / committed strip. A015-08 uses overhead views throughout, as requested for the existing loader.
- `assets/source/A015-bestiary/A015-00.png`: 2200 × 4490 matrix, every threat's camera thumbnail and six explicit lines: role, light, tell, counterplay, build route and ship. `A015-00.md` is the searchable text matrix and also names new work per threat.
- A `.prompt.md` beside every image; `manifest.json` holds the design records and generation prompts, and `generation-log.json` records built-in image_gen output provenance. The loader used `assets/source/A011-rogue-ai/A011-08.png` as its image reference. Other plates are new generations informed by the required project references.
- `docs/screens/A015/build-review.py` rebuilds the deterministic sheet and matrix. `validation.json` records image counts, sizes, prompt presence and the shortlist.

Scope: five biological specimens, four machines, three horrors, four people (all three requested Prior Claim roles plus repo), two bosses. Eighteen threats, below the twenty-threat ceiling. The extra person preserves all requested role coverage. Bosses cover survey and mining tug; the existing freighter AI remains CUSTODIAN.

## Top five to build next

| Priority | ID | Recommendation and why | Additional work even with reuse |
| --- | --- | --- | --- |
| 1 | A015-08 | **CUSTODIAN Loader.** Existing art identity; a slow turning straight charger makes side doors and loops matter. Twin red roof lamps read above its off-white/teal chassis. | Turn, wind-up, fixed charge lane, collision and recovery behavior. The loader is designed, not claimed implemented. |
| 2 | A015-02 | **Suit Hitch.** Gives the approved survey vessel an immediate specimen encounter with a humanoid build route; violet nape identifies it from above. | Sustained-light wake trigger, rear weak point, short committed grab; parasite tendrils can be rigid attachments initially. |
| 3 | A015-04 | **Pool Bell.** Turns existing acid into a positional encounter, without a full character rig. The lime ring announces the shot; dry routes and tall cover remain useful. | Pool-bound occupancy, animated bell/ring, directional fan and beam reaction. |
| 4 | A015-15 | **Prior Claim Surveyor.** Reuses the rival crew look and squad foundation. The visible laser gives long lanes a deliberate crossing rhythm. | Laser blocked by tall cover, staged aim tell, single shot and reset window. |
| 5 | A015-07 | **Seam Spiders.** Small rigid machines make the return route change while the crew is greedy; magenta chevrons distinguish them from the AI's other units. | Interruptible door-weld state, light-driven retreat, reopening rules and a guarantee that the extraction route cannot be irreversibly sealed. More system work than the first four. |

These are recommendations for John to compare against the full matrix, not instructions to import them.

## Reuse of existing technology

- **Stalker brain:** target pursuit, sight/noise foundations and attack wind-up/recovery are starting points for Suit Hitch (02), Door Ram (03), Borrowed Voice (05) and Vacant Shift (10). Door Ram additionally needs door damage; Vacant Shift needs light-gated motion. Pool Bell (04) can reuse acid damage and projectile foundations while remaining stationary. None is a complete behavior-only reskin.
- **CUSTODIAN tells:** staged bars/rings, line-of-sight cancellation, spotlight acquisition and deliberate timing are starting points for Term Enforcer (06), Loader (08), Bore Warden (09), Surveyor (15) and both bosses (17–18). These share warning infrastructure, not identical attack rules. Loader preserves the A011 cab, tracks, long clamp arms, mint sensor and twin red lamps; no replacement loader design is proposed.
- **Pirate squad:** movement, aiming, cover and crew identity support Bulwark (13), Underwriter (14), Surveyor (15) and Marshal (16). Meshy on a hauler-style humanoid rig is the proposed art route for these people and the upright biological/horror characters. Retargeting and equipment attachment still need verification. The medic's enemy revival and marshal's salvage claim are new mechanics.
- **Simple art routes:** Vent Rosettes (01) use instanced flat sprites/particles for the swarm; Pool Bell (04) and Missing Volume (11) use standees/materials/particles. Machines (06–09) use rigid parts; False Rescue (12) uses a rigid buoy plus cable effects. Mother Culture (17) is a rooted core with lobe transforms and particles, and Debt Furnace (18) uses rotating rigid shields and heat effects. No bespoke multi-limb animation pipeline is assumed.

## New systems, named plainly

1. **Swarms / 01:** group movement, vent emergence, grouped damage and door containment; do not simulate every pictured crab as an independent full stalker.
2. **Light exposure / 02–04, 07, 09–11, 17:** authoritative beam and practical-light tests with occlusion, exposure duration and clear thresholds. Existing sight support is a foundation, not proof these reactions already exist.
3. **Door breaking / 03** and **door sealing / 07:** damage or welding progress, interruption, reopening, route safety and multiplayer authority.
4. **Pool inhabitant / 04:** acid-pool boundaries and directional fan attack.
5. **Radio mimic / 05:** authored deceptive radio calls and lure behavior, plus telegraphed cone stun. No player microphone capture, voice cloning or live voice imitation is proposed.
6. **New machine attacks / 06, 08–09:** suppression burst, loader charge, drill charge and rear-sensor stall respectively.
7. **False crew / 10:** light freezes movement, independent head tell and reliable team identification. It never copies an actual player's identity.
8. **Dark-only thing / 11:** darkness occupancy, subtraction from the flashlight image and safe lit areas; requires gameplay and rendering work together.
9. **Rescue lure / 12:** deceptive beacon cue and closing cable hazard zone.
10. **Shield / 13:** directional blocking and committed shove. **Enemy medic / 14:** downed squadmates and interruptible revival. **Sniper / 15:** staged laser aim and reset. **Repo agent / 16:** late boarding, cargo tagging, ownership and lock/interruption rules.
11. **Survey boss / 17:** lobe feeding/shuttering, add spawning, radial wave with safe gap and phases. **Mining boss / 18:** sector cycle, shield rotation, heat lanes and coolant interactions. Both need boss encounter design, not just large models.

## Verification and limits

- Read AGENTS, STATUS, brief, style and asset contracts, packet, tone bible and run loop; visually inspected A001 threats, A009, A011 and the approved A014 survey-vessel sheet.
- Used built-in image_gen for all eighteen plates. **Refusals: none.** No missing or skipped concepts. All eighteen PNGs decode at 1536 × 1024 and have adjacent prompts; matrix and contact sheet also have assembly specifications. Rebuild completed successfully; visually inspected both assembled sheets and the generated plates.
- The game-camera panels are **illustrations**, not engine captures, calibrated 60-degree projections, physical-size specifications or gameplay readability proof. Names, attack timing and effects are proposals. No game import or runtime check is claimed.
- Specific visual simplifications for a build: Suit Hitch's long tendrils should not drive its hitbox; Door Ram needs doorway-clearance testing and shorter/retargeted arms; Borrowed Voice's blue throat reads more from the front than rear; Pool Bell's committed splash looks broader than the intended directional fan; Missing Volume depicts the beam-cutting boundary but does not demonstrate disappearance in a fully lit state; medic and beacon pulse timing cannot be established by a still strip. Matrix behavior lines are the design intent where a still image is ambiguous. Test these only if selected.
- Boss rooms are illustrative encounter spaces, not edits to the approved A014 plan; fitting Mother Culture requires a later encounter/layout decision. Bosses are not in the recommended first five.
- No real brands, celebrity likenesses or borrowed game characters/ships were requested. Prior Claim and CUSTODIAN retain this project's invented identities. No files in src, scenes, data, tests, tools or legacy-pass05 were changed. No git commands were run.

## John's decision

Choose threats and build order from `sheet.png` and `A015-00.png`, including whether to accept or replace the gold shortlist. The art packet is ready for that review. No implementation proceeds from this unattended run.
