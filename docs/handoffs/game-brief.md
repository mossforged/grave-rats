# Grave Rats — game brief (paste-ready for any agent)

## Pillars (lead draft, 2026-10-29, pending John's sign-off)
1. **The ship is the arena.** Tight, interconnected rooms, loops and side doors; every doorway is a decision and every route is readable from the camera.
2. **Know the room, fear the corner.** Light and sight are the core mechanic: walls and doors block vision, the flashlight shows what's real, explored space is remembered but enemies outside sight vanish.
3. **Scoundrels, not heroes.** The crew are cheap, scrappy salvagers working dead ships for money. Greed versus survival drives every run. The tone is gritty and darkly funny, never heroic and never gory for its own sake.
4. **Match or beat the concept, and keep the art doable.** The steep oblique camera, chunky industrial interiors and a readable astronaut are the bar. Art is built from kits, scripts and image generation, plus John's own models case by case; no hand-animated epics.

## The game
Co-op (1–4) top-down sci-fi shooter, possibly with competitive modes later. Crews of scrappers board derelict ships that were lost, or taken over by something weird. They scavenge gear and salvage, fight what's aboard and get out. The setting is a ship graveyard where wrecks drift.

Mission structure, modes, meta-progression, enemy roster and the exact threat are **all open**. The Dead Circuit prototype's "board, find the recorder, extract" was a placeholder.

## Look
- **Target:** `docs/concepts/C001-dead-circuit-key-art/`. A steep oblique view (about 55–65° pitch), perspective, with walls cut away so interiors read.
  - Heavy industrial interiors: thick bulkheads, layered panels, pipes, grates and hazard trim.
  - Dark ambient lighting with practical pools: clinical cool white in medbays, sodium amber in cargo holds, cyan in engineering.
  - Flashlight cones with dust in the air.
  - Worn, grimy PBR materials.
- **Characters:** bulky pressure suits with a strong silhouette from above: helmet, life-support pack, a readable weapon. Crew members should be distinguishable at a glance.
- **Readability beats realism:** the player, enemies, pickups and doorways must read at gameplay zoom.

## Tech
Godot 4.7, GDScript, Forward+ renderer, desktop first (Mac, then Windows). Assets are glTF; Blender scripts live in `tools/blender/`. Builders run on John's Mac mini.
