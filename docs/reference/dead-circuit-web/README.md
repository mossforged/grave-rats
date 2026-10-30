# Dead Circuit — First Contact

A solo browser prototype of an overhead sci-fi boarding shooter. Built with Three.js; no application build step or runtime CDN dependency. Fonts and engine are vendored.

## Play
Serve `dist/` through any static HTTP server, for example:

```sh
python -m http.server 8081 --directory dist
```

Open http://localhost:8081 in a desktop browser with WebGL enabled.

- WASD / arrows: move; Shift: move faster
- Mouse: aim; left button: fire
- 1 / 2: rifle / shotgun
- R: reload; Q: use medkit; F: flashlight
- E: take nearby supplies, operate bulkheads, extract
- M: deck schematic; Escape: pause; wheel: zoom

Recover the orange flight recorder in Engineering, then return to the marked boarding airlock and press E. Medkits and ammunition require E to collect. Weapon slots are available from the start so both handling models can be evaluated immediately.

## Scope and implementation

This is a short handcrafted solo mission, not a multiplayer vertical slice. It has independent movement/aim, two weapons, collision, security AI with pathfinding, sight-blocking doors, per-player enemy visibility, pickups, healing, mission completion, death, restart, and synthesized sound effects.

The view uses actual 3D geometry and a steep orthographic camera. Art is procedural: worn metal textures, cutaway bulkheads, machinery, beds, cargo, suit and robot geometry, floor markings, grime, practical lights, and shadows. It follows the pitch art's direction but does not reproduce its finished asset quality.

Enemy visibility is line-of-sight plus directional awareness. Explored floor tiles remain dimmed. Environmental props remain visible as silhouettes beyond current sight; room-darkening is a prototype treatment, not final fog-of-war. No saved progression, networking, procedural map generation, gamepad support, touch controls, or inventory swapping yet. Ammunition and health reset on restart.

## Files

- `dist/game.js`: game world, renderer, simulation, input, visibility, UI binding
- `dist/style.css`, `dist/index.html`: game shell and HUD
- `dist/vendor/`: Three.js and Barlow font families
- `check-engine.cjs`: deterministic integration checks through a browser-only test injection; no debug mutation API is shipped
- `qa.cjs`: browser UI smoke checks and screenshots

The checks require the Playwright package and Chromium in the developer environment. Run a static server first, then `node check-engine.cjs` / `node qa.cjs`. The shipped game exposes only read-only diagnostics at `window.__deadCircuit`.

## Third-party assets

Three.js, Copyright Three.js authors, MIT License: https://github.com/mrdoob/three.js/blob/dev/LICENSE
Barlow and Barlow Condensed by Jeremy Tribby, SIL Open Font License 1.1: https://github.com/jpt/barlow

## Visual pass 02
Lower oblique overhead camera with screen-aligned movement, metal reflection environment, bumped floor panels, layered wall assemblies, pipe unions, vents, equipment details, suit armour seams, and local amber/cyan glow.

## Operator and defense pass 03
Rebuilt original procedural operator with articulated hips/knees/arms, layered pressure suit, visor, pack, and weapon; gait, breathing, crouch, recoil, reload and forward tumble animations. Space rolls in the movement direction (or aim direction at rest), with a 1.7-second cooldown and a short dodge window. Hold C to crouch; firing is disabled while crouched or rolling. Nearby solid cargo provides directional cover, not protection from flanks. Environment and suit surfaces use cached 1024px procedural worn-metal maps. No external character model or motion-capture clips are used.

## Weapon feedback and roll correction
The roll animation now measures the transformed model's lower bounds and keeps the full silhouette above the deck. The rifle and shotgun have distinct recoil impulses and muzzle bursts, layered moving tracer meshes, brass ejection, smoke, spark impacts, robot flinch and crosshair hit confirmation. Camera kick respects the system reduced-motion preference. The integration check samples an entire roll for floor penetration alongside the existing mission checks.

## Visual pass 05 — authored asset pipeline
The procedural boxes and code-built operator are replaced by Blender-built glTF assets with authored PBR texture sets. Gameplay rules are unchanged except where listed under "Gameplay-visible changes".

- `dist/assets/operator.glb` — skinned salvage operator (orange pressure suit, white helmet, life-support pack, AR-4 rifle, SG-8 shotgun) with 13 clips: aim, low-ready, reload (magazine swap), idle, 4-way run, patrol walk, crouch idle/walk, roll, death.
- `dist/assets/robot.glb` — security unit on the same skeleton; it uses the operator's clips.
- `dist/assets/kit.glb` — 32 bevelled modular pieces: full-height and cutaway bulkheads, pilasters, floor plates and grates, bulkhead door frame and leaves, medbay beds/consoles/cabinets/IV stands, cargo crates/shelves/pallets/canisters, pickups.
- `dist/assets/tex/` — 15 tileable texture sets (albedo, tangent-space normal derived from an authored height stack, ORM = AO/roughness/metalness).
- `dist/src/materials.js` binds texture sets to glTF material slots by name; `dist/src/characters.js` is the layered animation controller (legs blend by move direction relative to aim, upper body aims/reloads, full-body roll/death, procedural recoil/flinch on top).
- Rendering: practical point lights per room, shadow-casting weapon light, sun shadows that follow the camera, room-environment reflections, GTAO ambient occlusion, HDR bloom on emitters only. `?q=low` disables post-processing.

### Rebuilding assets
Requires Python 3.13 with `pip install bpy numpy scipy pillow` (bpy is Blender 5.2 as a module, ~400 MB). Then `npm run assets`. The character build fails if any roll frame pushes the body or a weapon through the deck.

### Gameplay-visible changes in pass 05
- Closed bulkheads now seal their corridor: door frames are solid across the whole 3-tile opening (pass 04 left ~1.1 m walkable gaps beside each closed leaf).
- New wall-hugging props (medbay cabinets/canisters/gurney, cargo shelves/crates, corridor canisters) carry collision footprints; none blocks an existing route, but they add cover points.
- Default zoom is tighter (view span 17, wheel range 12–36; was 29, 24–48) so the operator reads at roughly the concept's scale.
- Robot shots now originate at the robot's muzzle (visual only).

### Tools
- `node shots.cjs [outDir] [label] [views]` renders fixed views (junction, wide, medbay, cargo, operator, combat) with the loop frozen, for comparison against `design/concept-art.png`.
- `dist/dev/viewer.html?cells=operator:U_Aim|L_Run_F@0.25,robot:F_Death@1&yaw=2.6` poses characters on any clip/time; `tools/viewshot.cjs` screenshots it.
