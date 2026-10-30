# Grave Rats — game brief (paste-ready for any agent)

## Pillars (approved by John 2026-10-29)
1. **The ship is the arena.** Tight, interconnected rooms, loops and side doors; every doorway is a decision and every route is readable from the camera.
2. **Know the room, fear the corner.** Light and sight are the core mechanic: walls and doors block vision, the flashlight shows what's real, explored space is remembered but enemies outside sight vanish.
3. **Weight, not speed.** Combat is visceral and deliberate. Turning, aiming, firing, reloading and getting up all take time, so position and cover matter: you crouch behind an overturned medical table while something acid-spitting stalks into the room. When something bursts through the bulkhead behind you it's scary *because* you can't spin and kill it instantly. No bouncing off the walls.
4. **Desperate scoundrels in a satirical future.** Two hundred years on, an even worse capitalism drives broke crews into derelict ships overrun by rogue AI, robots, aliens and horrors, and into fights with other pirate crews, all to score some credits. The humour comes from that desperation (contracts, fees, waivers, debt). The violence still lands; it isn't slapstick.
5. **Match or beat the concept, and keep the art doable.** The steep oblique camera, chunky industrial interiors and a readable astronaut are the bar. Art is built from kits, scripts and image generation, plus John's own models case by case; no hand-animated epics.

## The game
Co-op (1–4) top-down sci-fi shooter, possibly with competitive modes later. Crews of scrappers board derelict ships that were lost, or taken over by something weird. They scavenge gear and salvage, fight what's aboard and get out. The setting is a ship graveyard where wrecks drift.

Threats aboard: rogue AI, robots, aliens, horrors, and rival pirate crews (so PvPvE is on the table). Mission structure, modes, meta-progression and the exact roster are **open**. The Dead Circuit prototype's "board, find the recorder, extract" was a placeholder.

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
