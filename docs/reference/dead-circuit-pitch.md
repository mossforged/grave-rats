# DEAD CIRCUIT
## Board. Scavenge. Survive.
**Working title • Game concept pitch • October 2026**

A derelict ship is a battlefield you can learn—and a place you can never fully see.

DEAD CIRCUIT is a top-down sci-fi shooter about boarding abandoned spacecraft, scavenging weapons and equipment, and fighting your way through interconnected rooms and corridors. A steep overhead camera gives you the tactical overview of a floor plan with the physical depth of a 3D environment. Limited sight turns every doorway into a decision.

**Proposed starting format:** solo and 1–4 player online co-op; PC first; missions of roughly 15–25 minutes. Competitive boarding is a possible later mode. These are design proposals, not settled requirements.

(Concept sheet: docs/concepts/C001-dead-circuit-key-art/concept-sheet.jpg)

## The player fantasy
You are a salvage operator entering ships that should be empty. Bring a modest kit, find something better, and improvise when the lights go out. Your squad covers a junction while you cross a cargo hold. A maintenance door offers a flank. Your last magazine might get you to the reactor—or you could take your salvage and leave now.

The promise is immediate shooter action, the spatial decisions of a good FPS map, and the dread of knowing something can move beyond your view.

## Three pillars
**The ship is the arena.** Rooms connect through loops, side doors, junctions, and alternate approaches. Cover breaks up long sightlines. A medical bay can be a shortcut, a defensible position, or the route an enemy uses to get behind you. Backtracking changes meaning when doors, power, and enemy positions change.

**Know the room. Fear the corner.** Previously explored architecture remains faintly visible, but enemies outside current sight disappear. Walls and closed doors block vision. Aiming a flashlight into one corridor means leaving another unwatched. Sound gives useful warning without revealing exact positions.

**Make every pickup a decision.** Weapons change how you fight; ammo, medical supplies, and utility tools change which risks you can afford. Carry space is limited. Take the unfamiliar rifle with a full magazine, or keep the weapon you trust and search for ammunition?

## What you actually do
1. **Prepare:** choose a starting firearm and a small utility loadout; select a salvage contract.
2. **Board:** enter at an airlock with a partial ship plan and an immediate objective.
3. **Explore and fight:** search rooms, pick up ammo, swap weapons, and navigate alternate routes while confronting security machines or an invasive organism.
4. **Commit or leave:** optional caches and deeper objectives offer better salvage at a growing cost in supplies and exposure.
5. **Extract:** return to the boarding point or activate a second exit; recovered equipment and salvage support the next mission.

Mission objectives create reasons to cross the map: recover a flight recorder, restart a cargo lift, retrieve medical samples, or divert power to an extraction airlock. Extraction gives missions a clear ending; this does not require an extensive persistent economy.

## A minute inside the ship
The squad reaches a sealed bulkhead. The direct route needs power, but a maintenance passage loops around through the medbay. One player watches the corridor while another checks a locker and finds shotgun shells. A third enters the medbay and hears metallic footsteps beyond its far door.

You cut through cargo to flank the sound. A security unit catches your flashlight, and the first burst wakes a second unit in the adjacent room. Your teammate seals a door to stop the flank. Now you can spend a tool to reopen the short route—or retreat through the medbay with the recovered recorder and the ammunition you have left.

The tension comes from movement, gunfire, sound, and decisions made under pressure.

## Camera, controls, and combat
Use a fixed, steep overhead camera: closer to classic GTA than Diablo, tilted only enough to show wall height and physical objects. Roofs disappear and obstructing walls fade or cut away. Characters and floor hazards must remain readable even in darkness.

Movement and aiming are independent: WASD plus mouse on PC, with twin-stick controller support as a design target. The player directly moves, aims, shoots, reloads, and interacts. Short encounters emphasize positioning, weapon handling, and disciplined bursts. Modest enemy counts preserve room for flanking and resource decisions.

Start with distinct weapon roles: a dependable rifle, a close-range shotgun, and a heavy weapon that trades mobility and scarce ammunition for stopping power. Tools such as a door wedge, portable light, and motion sensor help shape encounters. Avoid a large inventory of nearly identical stat upgrades.

## Visibility that feels fair
Keep three states legible: currently seen space in full detail; explored space as muted architecture; unexplored space in darkness. Treat sight and illumination as related systems: walls always block sight, darkness reduces identification, and a flashlight improves information without becoming a visible cone-shaped wall.

Give the player modest awareness immediately around their body, with stronger directional awareness toward their aim. Nearby shots and footsteps remain audible outside sight. Do not show live enemies in remembered rooms, even when those rooms remain on the map.

For co-op, a proposed starting rule is individual enemy visibility with teammates and manual pings visible through walls. Test shared squad vision as an alternative: it improves coordination but may reduce dread. Competitive play would require a separate fairness and information review.

## Enemies and atmosphere
Security machines offer readable behaviors: patrol, investigate, hold a doorway, or advance behind armor. A biological threat can later add speed, erratic routes, and pressure to keep moving. Prove one faction first; mixed encounters can follow once the combat is clear.

The ship feels abandoned through its systems: failing lights, intermittent machinery, distant impacts, damaged doors, and empty crew spaces. Quiet stretches make the next exchange matter. Horror should amplify the shooting and exploration.

## Multiplayer direction
**Core proposal: cooperative boarding.** One to four operators share a mission and a physical space, covering approaches, trading ammunition, and deciding when to extract. Solo uses the same core verbs with encounter tuning; AI companions are not required for the first prototype.

**Expansion candidate: competitive boarding.** Two small crews enter through different airlocks and pursue overlapping salvage objectives. Doors, sounds, and limited sight create ambushes and flanks. Begin with a self-contained match and standardized starting kits before considering persistent PvP gear loss.

Co-op and PvP imply different balance, networking, map, and community requirements. Competitive boarding is a promising direction to validate, rather than a second launch commitment.

## What we take from the references
- **Alien Swarm: Reactive Drop:** readable overhead sci-fi combat and squad coordination.
- **Alien Breed: Impact:** industrial ship interiors and corridor atmosphere.
- **SYNTHETIK 2:** distinctive weapon handling and meaningful equipment choices.
- **ZERO Sievert:** the appeal of scavenging, committing to risk, and returning with useful gear.
- **Darkwood:** restricted awareness and the anxiety of unseen space.
- **Door Kickers:** room connectivity, doors, and consequential sightlines; our player directly controls one operator.
- **Space Beast Terror Fright:** claustrophobic boarding tension, translated into an overhead view.

The proposed identity comes from combining a nearly overhead camera, limited personal visibility, FPS-style route design, and equipment found inside derelict ships. These references establish ingredients; they do not establish market demand or prove novelty.

## Visual direction
Worn industrial spacecraft, readable silhouettes, and restrained lighting. Cool steel and cyan practical lights sit against amber emergency lamps. Salvage operators wear utilitarian pressure suits with small identifying accents. Weapons, doors, and interactable supplies stand out against detailed but quiet floors.

The accompanying art demonstrates the intended camera, atmosphere, branching spaces, and visibility language. It is illustrative concept art, not a playable screenshot or a final UI specification. The small route diagrams communicate intent rather than validated level geometry.

## A practical first build
A fixed overhead camera, modular interiors, and a single ship are a plausible foundation for a small team. The largest uncertainties are combat feel, visibility readability, and networked co-op. Procedural ship generation, a persistent economy, and PvP substantially expand scope.

**Prototype:** one handcrafted deck with two traversal loops, a cargo hold, medbay, reactor room, and two airlocks. Build movement and aiming, one rifle and one alternate weapon, ammo pickups, occluded visibility, and one enemy type. Run an objective-and-return mission first in solo, then in two-player co-op.

**Vertical slice:** expand to four players only after the basic combat works. Add a small set of tools, a second enemy behavior, one optional salvage objective, and a polished lighting-and-sound pass. Recombine authored sections later if repeat play needs more variety.

**Questions to answer:** Does the camera make aiming and cover intuitive? Can players understand threats without seeing through walls? Do alternate routes actually change fights? Do pickups force interesting choices? Does extraction create tension without excessive downtime?

Proceed when unfamiliar players can navigate without camera confusion, use the flank routes voluntarily, understand why they were hit, and want another boarding run. Staffing and schedule estimates should follow a scoped prototype rather than precede it.

## The pitch in one sentence
**Board a dead ship, fight through a map full of alternate routes, and scavenge your way out—while your flashlight reveals only part of the fight.**
