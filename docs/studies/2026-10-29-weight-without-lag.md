# Study: weight without lag (2026-10-29)

## Where the project stood
Stage 0. T001 (Godot skeleton) and A001 (crew and threat exploration) queued on the Mac; T002 (camera and scale) written. Pillar 3, "Weight, not speed", was just approved. John's words: crouching behind an overturned medical table while something acid-spitting stalks in; something bursting through a bulkhead behind you is scary "because it takes time to turn, time to fire, time to take it down."

## The trap
"Weighty" is easy to get wrong as "laggy". Players forgive a character that is slow to *finish* an action. They hate a character that is slow to *start* one. The rule for every mechanic below:

**The intent responds instantly; the completion takes time.** Press a key and something visibly begins the same frame (the torso starts turning, the hand goes to the magazine, the knees bend). What takes time is finishing it.

## Levers, with starting numbers for stage 2 (all in `data/`, tuned by John playing)
| Lever | What it does | Start at | Why |
| --- | --- | --- | --- |
| Turn-rate cap | The body rotates toward the cursor at a max speed instead of snapping | 240°/s standing, 150°/s while firing, 120°/s crouched | A 180° turn takes ~0.75 s: that *is* the bulkhead-ambush moment. The cursor stays free; the gun catches up. |
| Aim-settle cone | Spread starts wide after moving or turning and closes over time | wide 9° to tight 1.5° over 0.45 s; moving keeps it ≥ 5° | Rewards stopping and planting your feet; no random-feeling misses if the cone is drawn |
| Upper/lower split | Legs move one way while the torso aims another, within a limit | torso may lead hips by 70°; beyond that the legs turn too | Strafe-shooting is possible but clumsy at the edges |
| Acceleration | Ramp to and from full speed | 0.18 s up, 0.12 s down | Removes the ice-skating start; short enough not to feel sluggish |
| Commitments | Actions that lock you in for a moment | reload 1.6–2.4 s (cancel by sprinting, not by firing); stand up from cover 0.35 s; melee 0.6 s | The "bad moment to reload" story, without unfairness |
| Recoil and kick | Each shot pushes the aim off and the camera slightly | rifle 0.9°/shot recovering at 12°/s; shotgun 4° | Makes bursts a choice; full-auto is a sprayed hose |
| Hit reaction | Enemies flinch, stagger and lose footing on heavy hits; so do you | stagger on ≥ 25% of health in one hit | Big hits feel big; being hit costs time, not just health |
| Footwork sound | Heavy boots, suit creak, breath | audible radius tied to speed | Speed has a cost the enemies can hear |
| Camera | Slight lag behind the aim, small kick on firing | follow 6/s, kick 0.06 m | The camera shouldn't jitter with every mouse twitch |

## Making it fair
- Draw the aim cone and the turn arc so the player always knows why a shot missed or why they can't face the door yet.
- Enemies obey the same rules: slow turns, wind-ups that telegraph, recoveries after a lunge. The scary ones break one rule on purpose; a stalker that turns fast is terrifying because nothing else does.
- Sound and light give warning before ambushes, so a bulkhead burst behind you is "I heard it and still wasn't fast enough", not "cheap".

## References worth a look (feel, not looks)
- **Alien Swarm** (co-op, top-down, corridors): squad callouts, ammo and reload pressure.
- **Darkwood** (top-down horror): the vision cone, and how dread comes from what you can't see.
- **Teleglitch** (top-down sci-fi): scarcity, and line of sight as the whole UI.
- **Synthetik** (top-down shooter): reloads with real failure states; a strong model for weighty guns.
- **Lethal Company / Deep Rock Galactic** (co-op): blue-collar jobs for an uncaring company. The tone is close to ours.
- **Hotline Miami / Ruiner** (the opposite): what we are *not* making.

## Recommendation
Stage 2 (core loop) implements the turn-rate cap, aim settle, the upper/lower split, acceleration, reload commitment and recoil from day one, each with a debug slider. John tunes them by playing before any enemy design is locked.
