# A014 — second derelict concept handoff

2026-10-31. Art packet complete; **awaiting John's concept approval before a code build**. Recommended: the biological survey vessel, thumbnail B. No image refusals. No game files or imports were changed. No git commands were run.

## Review files

- `docs/screens/A014/sheet.png`: 3000 × 3900 labeled review sheet, all three pitch thumbnails, scaled plan and three mood frames. The packet prescribed no pixel dimensions.
- `assets/source/A014-derelict-2/A014-01.png`: three purpose/mood thumbnails, left to right transport / survey / mining tug. Full pitches and recommendation in `A014-01.pitches.md`.
- `A014-02.png`: 2400 × 2020 plan, with finished dimensions, 0.5 m grid, ten sliding doors, cover, S/M/H salvage, BB, vents/closets, practical lights, cutter and drone patrol.
- `A014-02.layout.json`: matching geometry and point placements in final world metres, x east / y south; concept specification, not a game data import.
- `A014-03.png`: emergency-red bridge; `A014-04.png`: cyan-green specimen lab; `A014-05.png`: dressed corridor.
- Exact generation prompts sit beside every numbered image. Built-in imagegen generated 01/03/04/05; Pillow drew the dimensioned plan and assembled the contact sheet. `docs/screens/A014/build-review.py` rebuilds plan and sheet from the saved artwork; `sheet.prompt.md` records assembly instructions.

## Choice and story

Pick the biological survey vessel because all five new room types have a clear purpose aboard it, and it differs from the first hospital/cargo vessel. Existing kit silhouettes carry the scene: tanks, bench, centrifuge and fridge; bridge consoles and chart table; bunks and lockers; galley and benches; engineering machinery; corridor ribs, pipe clips, service panels and cable runs.

The black box on the distant bridge holds quarantine orders and mirrored specimen telemetry. The room story runs from interrupted meals to the lab seal to a sample case at command: containment outlived its operators. This remains a proposed environmental story, not approved lore or new gameplay. Transport and mining-tug alternatives each have their own black-box rationale and room story in `A014-01.pitches.md`.

## Layout and dimension checks against data/deck.json

Eight spaces including the hold: bridge, bio lab, mess, quarters, engineering, west spine, east spine, airlock. Five required room types are present. Ten doors connect all eight spaces; the adjacency graph has three independent cycles. Engineering has exactly one door, D10, and offers heavy engine salvage plus a medium component as the rewarded dead end. It is optional on the prize route.

| Space | Final clear interior, m | Input size if multiplied by 0.85, m | Practical colour |
| --- | --- | --- | --- |
| Bridge | 11.5 × 6 | 13.529412 × 7.058824 | emergency red + dim screens |
| Bio lab | 11.5 × 9.5 | 13.529412 × 11.176471 | cyan-green tanks + weak white |
| Mess | 11.5 × 5.5 | 13.529412 × 6.470588 | amber |
| Quarters | 11.5 × 5.5 | 13.529412 × 6.470588 | cool white |
| Engineering | 10 × 10 | 11.764706 × 11.764706 | cyan |
| West spine | 3.5 × 28 | 4.117647 × 32.941176 | cool white |
| East spine | 3.5 × 28 | 4.117647 × 32.941176 | amber + fault red |
| Airlock / hold | 6 × 6 | 7.058824 × 7.058824 | white |

The reference deck's original room sizes (junction 6 × 26, medbay 14 × 10, cargo 14 × 12, side corridor 14 × 3.5) establish scale, not a requirement to duplicate their layout. The new room sizes are comparable. Hull bounding envelope is 37.5 × 29 m including exterior wall thickness; the footprint is stepped rather than that whole rectangle.

- `grid_m=0.5`: every finished room edge and cover footprint is on this grid. The grid is drawn in the plan. `floor_tile_m=1.0` fits two grid divisions.
- `wall_height_m=2.6`, `wall_thickness_m=0.5`: retained. The plan draws 0.5 m shared wall bands. Use the 2 m wall modules plus end/filler pieces where needed; this is a layout drawing, not a module cutting list.
- `door_width_m=2.0`, `door_frame_m=0.2`: retained. Even budgeting both frames inside the aperture gives 1.6 m clear, above the requested 1.5 m. Do not apply room_scale to doors or frames a second time.
- Spines are 3.5 m clear interior. Ribs/pipes/cables/panels occupy at most 0.5 m at each wall, leaving at least 2.5 m; reserved travel bands are 2 m. Cover footprints do not intersect those bands. Cables hang above travel height or remain against a wall; floor debris stays in recesses.
- `room_scale=0.85`: plan dimensions are **final**, already selected at game scale. If the builder retains a multiplier on room input, divide the target size and relative placement distances by 0.85 first. The inverse-scaled input need not be on a 0.5 m grid; the final geometry must be. Alternatively author final coordinates without a second room multiplier. This is an explicit policy for John/lead to approve, not a silent change to deck.json.
- `character_scale=1.15`: no change proposed. The small suited figure is a mood/readability reference, not a measured model export.

## Routes, threats and salvage

The direct marked orthogonal route is hold centre (3,25) → west spine (8.5,25) → bridge crossing (8.5,4) → recorder (17,2.5), about 36.5 m. The return may use the other spine and lab, mess or quarters. West → bridge → east → mess → west is one clear loop; lab and quarters give additional cross-links, allowing stalkers to intercept without a mandatory locked-door puzzle.

BB is heavy (two hands, −35% speed, no firing) in accordance with the run-loop spec. Small chips/fuses are placed in bridge, lab, mess and quarters; medium assemblies/canisters in lab, mess, quarters and engineering; the engineering dead end has a heavy engine component. All markers are proposed spawn spots, not guaranteed values or spawn counts. Alarm-on-prize uses the existing run-loop rule.

The cutter mounts near (25,13), looking south down the east spine toward the engineering approach. The west spine remains an alternate route. Its line and filling ring must retain the established tells. The drone patrols the east spine and crosses through mess and lab, creating an interception loop; tall cover and doors should break its spotlight sightline. Patrol points are conceptual, not validated flying navigation.

Vent and closet markers identify wall-side spawn candidates, never permission to spawn in current sight. Keep the existing out-of-sight/tier rules. Reserve 0.5 m wall-side service zones for vents/closets so their dressing does not narrow the travel band.

The 8-minute oxygen window is ample for traversal; salvage, combat and commitment supply the time cost. At the reference 4.2 m/s, a 36.5 m direct route is about 8.7 s unobstructed, or 13.4 s carrying heavy at 65% speed. These are reference arithmetic only, not a balance result: character scaling, doors, fights, turns and real navigation were not simulated.

## Visual checks and limitations

Inspected all five images and final sheet. Checked PNG readability, all prompts present, final room grid alignment, graph connectivity/cycles/dead-end degree, and cover against reserved travel bands; results in `docs/screens/A014/validation.json`. No image was refused or skipped.

The mood frames are new-room concept paint-overs guided by A006 and the supplied kit renders, not registered overlays of gameplay screenshots; no second-deck blockout exists yet. The plan and JSON control construction. In particular the lab painting has two tanks and a foreground entry composition, whereas the plan proposes three wall-side tanks and two side doors. The bridge and corridor render can also drift in prop counts/spacing; do not extract dimensions or add entries from them. Shared target: steep cutaway camera, worn ivory/graphite PBR, low corner grime, heavy ribs, hazard door trim, dark ambient pools, dusty flashlight, restrained emissive bloom. Reference-led finishing is proposed; no new meshes or textures are supplied.

No Godot navigation, camera occlusion, spawn visibility, combat timing, lighting performance or 8-minute balance validation was performed. Those belong to the code blockout after approval. In particular test the cutter's view around D10 and the drone's room-to-room route before committing its positions.

## John's decision — stop here

The packet states: “Autonomy: human-gated (John approves before the code lane builds it).” All reviewable art is now supplied. John needs to approve or redirect:

1. Biological survey pitch B and its proposed environmental story/black-box rationale, versus transport A or tug C.
2. The eight-space plan, engineering reward dead end, distant bridge prize, and proposed cutter/drone locations.
3. Red bridge / cyan-green lab / worn dressed corridor mood and existing-kit interpretation.
4. Final-world-metre grid policy with explicit compensation for `room_scale=0.85`.

Stopped at that approval gate. No code-lane build or import is authorised by this art handoff.
