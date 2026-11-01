# A018 → Meshy plan (lead, 2026-11-01). Waits on John's OK.

All: latest model, 2K PBR, remeshed, static (no rig), 30 credits each. Sizes from auto-A018.md, set in game data.

| Object | Mode | Inputs | Remesh target |
| --- | --- | --- | --- |
| crew_dead_sitting | multi-view | front, side, 34, back (approximate match is fine) | 15k |
| crew_cryo_occupant | multi-view | front, side, 34, back | 15k |
| crew_dead_prone | single image | 34 | 15k |
| crew_dead_bunk | single image | 34 (bunk + body as one) | 15k |
| growth_wall_patch | multi-view | front, side, back | 10k |
| growth_egg_cluster | single image | 34 | 10k |
| specimen_floating | single image | 34 | 6k |
| specimen_dissected | single image | 34 (the only consistent view) | 10k |
| drone_wreck | multi-view | 34, front, side (back invents details: leave it out) | 12k |
| security_bot_gutted | single image | 34 | 15k |
| loader_wreck | **not Meshy**: the lead cuts and re-poses the existing loader model in Blender (free, keeps its exact identity) | | |

Total: 10 × 30 = **300 credits** (about $6 on Pro). If any comes out badly, a re-roll is another 30 and needs John's OK.
