# A011 — CUSTODIAN / rogue ship AI

2026-10-30 unattended art run. Art packet complete; **human gate pending: John picks the AI identity and which units to build first.** Stopped at that gate. No game imports or implementation performed.

My pick: **CUSTODIAN**, Vesper Reach Freight's maintenance/property-protection AI; build **cutter + patrol drone first**, then the cargo loader after its committed charge and slow turning have been playtested. These give tall cover and line of sight an immediate second purpose with a small modelling/animation footprint. Door locking/venting is the optional fourth unit and is deferred, not proposed for the first build.

## Identity and voice

CUSTODIAN continues its final authorised order to protect company property. Its single concentric mint lens inside four corner brackets appears on camera housings, terminals and local wall repeaters. No face or evil avatar. Physical shells inherit the owner's worn ivory/faded teal rather than the orange hauler or Prior Claim navy. Mint identifies the AI; red paired rectangles identify the loader's impending movement, not its faction. The cutter concept has an amber heated tool aperture; its identity and targeting tell remain mint. Use mint identity colour around #A6E7C4 as a starting reference, keeping it greener than cyan engineering lights.

Approved-for-review copy transcript (the image is a concept, this text is authoritative):

- “Unauthorised salvage detected. Your account has been charged.”
- “Please remain clear of company property.”
- “Crew authority expired. Asset protection continues.”
- Screen state: “PROPERTY PROTECTION ACTIVE”.

Voice direction: calm, short, administrative, no anger or combat quips. Play announcement lines at detection/state transitions, with cooldowns; do not repeat over every attack. These are proposed copy, not recorded audio.

## Each unit: one rule and one tell

- **Cutter turret:** tall cover breaks its line of sight and prevents a cut; a sweeping mint targeting line and filling segmented ring reveal the source and warm-up before discharge.
- **Patrol drone:** break its spotlight line of sight before the call completes to prevent reinforcement; the spotlight, three sequential roof bars and a rising chirp announce acquisition/call progress.
- **Cargo loader:** sidestep its committed straight approach because the heavy tracked body cannot turn quickly; twin rectangular roof warning lights flash with a reversing beep before movement.

Every audio cue has a visible twin. Sources must reveal before damage; tells stop at occluders. Timing, range, light intensity, damage, collision and reinforcement rules are design proposals for the code lane to tune, not validated mechanics. No hidden attacker is authorised by these concepts. The loader's striped lane in A011-03 illustrates its commitment direction; it is an art annotation/proposal, not an existing gameplay decal or required HUD.

## Image inventory

All numbered images and exact generation prompts are in `assets/source/A011-rogue-ai/`. All generated images are 1536 × 1024 PNG, opaque light-grey backgrounds for Meshy inputs. Built-in image_gen used throughout. Generated pixels were copied without cropping, retouching or compositing; only the review sheet resizes them.

| ID | Image | Review |
| --- | --- | --- |
| A011-01 | `A011-01.png` | Identity, wall lens, terminal, distributed wall presence and three deadpan announcement samples. Clear mint/bracket family. |
| A011-02 | `A011-02.png` | Three bodies in front-facing and three-quarter presentations on A007 light-grey studio background, rule/tell captions. Cutter's upper view retains a slight oblique angle. Industrial cutter and clamps point down/away, not at the viewer. |
| A011-03 | `A011-03.png` | Steep oblique ship-lighting comparison beside orange hauler and stalker; cutter line ends on tall crate, drone spotlight/roof bars and loader twin lamps read from above. Concept, not an engine capture. |
| A011-04 | `A011-04.png` | Drone three-quarter master: four wheels, wedge ivory/teal shell, mint front lens, offset spotlight and three roof bars. Preferred single-image Meshy input. |
| A011-05 | `A011-05.png` | Drone front; main panels and equipment match master, some downward view remains. |
| A011-06 | `A011-06.png` | Initial drone side attempt; too oblique for a profile. Retained for provenance; superseded for Meshy by A011-06b. |
| A011-06b | `A011-06b.png` | Improved drone side profile (slight elevated view remains), two near wheels visible; front camera occludes naturally, shell/roof-bar arrangement retained. Preferred side alias. |
| A011-07 | `A011-07.png` | Drone back; inferred rear service grille, front lens correctly absent. Spotlight is turned toward camera relative to master, so use master for its final orientation. |
| A011-08 | `A011-08.png` | Loader three-quarter master: two track pods, central mint lens, two hydraulic clamp arms and twin roof lamps. Preferred single-image Meshy input. |
| A011-09 | `A011-09.png` | Loader front; major construction matches, small clamp/fastener details vary. |
| A011-10 | `A011-10.png` | Initial loader side attempt; too oblique. Retained for provenance; superseded for Meshy by A011-10b. |
| A011-10b | `A011-10b.png` | Improved loader side view (some oblique perspective remains); near track and forward clamp silhouette clarify length and rear counterweight. Preferred side alias. |
| A011-11 | `A011-11.png` | Loader rear interpretation; service grille and no front lens, but arms incorrectly read as extending toward rear camera. Do not use it to determine arm direction; master/side govern. |

## Meshy delivery

The packet explicitly authorises these new aliases in the existing `assets/source/meshy/input/` folder; no pre-existing inputs were overwritten. Every alias has its own `.prompt.md` with ID, source/master and exact prompt.

| Alias | Numbered source |
| --- | --- |
| `drone-34.png` | A011-04 |
| `drone-front.png` | A011-05 |
| `drone-side.png` | A011-06b |
| `drone-back.png` | A011-07 |
| `loader-34.png` | A011-08 |
| `loader-front.png` | A011-09 |
| `loader-side.png` | A011-10b |
| `loader-back.png` | A011-11 |

Use the three-quarter masters for initial single-image Meshy generation. Additional views are generated interpretations, not renders of shared geometry or guaranteed coherent multi-view inputs. In particular the loader rear arm direction is unreliable, and both rear service layouts are inferred. All inputs contain one whole centred machine without text, labels, dimensions, people, loose props, fog or beam effects. Light lenses are bright material swatches with mild local shading, not VFX assets. Apply metric scale to the mesh: drone target length 0.65 m; loader target top height 2.2 m. A011-03 exaggerates drone size for readable comparison and does not calibrate these dimensions. Hauler reference is 1.8 m; loader track/clamp clearance needs an engine check.

## Review and validation

`docs/screens/A011/sheet.png` is the labelled 2400 × 3410 contact sheet including all 13 generated images; corrected side profiles occupy the primary input rows, and initial attempts appear in a provenance strip. `sheet.prompt.md` records its assembly, and `build-sheet.py` reproduces the layout. `camera-960.png` is a 960 × 640 downsample for checking the tells at reduced size, with an adjacent provenance prompt. No exact image size was mandated by A011.

All source PNGs and aliases decode; source/alias bytes and prompt companions verified. Visually inspected all generated images and the assembled sheet. The camera study shows distinguishable ring/line, spotlight/bars and paired-lamp tells at reduced review size, but gameplay visibility, colourblind readability and timings still need engine playtesting. No tests or game files were changed.

**Refusals:** none. Two side-angle quality revisions made, with unique lettered IDs. No git commands run. Writes restricted to new A011 source/review folders, new packet-requested Meshy aliases, and this handoff. No changes to `src/`, `scenes/`, `data/`, `tests/`, `tools/`, `assets/game/` or `legacy-pass05/`.

**John's decision:** accept or change CUSTODIAN's identity/voice/palette, and choose the first bodies to build (recommend cutter + patrol). Await that choice before any game import or build commitment.
