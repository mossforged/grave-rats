# Free sound shortlist (lead, checked 2026-10-31)

Licences were read on each pack's own page on 2026-10-31. Nothing was bought, downloaded or signed up for. **The repo is public**, so:
- **commit** means CC0 (or CC-BY with a line in `assets/source/audio/CREDITS.md`);
- **local** means the files stay on John's Mac in a gitignored folder (`assets/local_audio/`), because the licence forbids or doesn't address redistributing the raw files.

Fine for a private game either way.

Most of the itch gun packs that search turns up are paid (Real Guns, gravity-sound, soundform, mgw, cyrex): left out.

## Guns
| Pack | Licence | Repo | What's in it |
| --- | --- | --- | --- |
| [Snake's Authentic Gun Sounds](https://f8studios.itch.io/snakes-authentic-gun-sounds) | Free; "can be used commercially, credit not needed" (no formal licence) | local | **Real 5.56 and 7.62x39 shots, each dry and with natural reverb** (the reverb set gives the room tails); AR bolt release, AK rack, reloads. MP3 + WAV. **The core of the rifle.** |
| [Snake's SECOND pack](https://f8studios.itch.io/snakes-second-authentic-gun-sounds-pack) | Name your price ($0 works); author: "public domain, use it any way" in comments | local | 9mm, .308, 20 ga, magazine packing, slide and reload handling, dry and reverb. |
| [Bouncing Shell Casings](https://freesound.org/s/318964) (GryffDavid, freesound) | CC0 | commit | Real casings on a hard floor: the tinks. |
| [Metal impact sounds](https://opengameart.org/content/metal-impact-sounds) (BMacZero, OGA) | CC0 | commit | 7 clinks, thuds, bings: the base for bullet-on-metal. |
| freesound CC0 search | per file | commit if CC0 | Fill the gaps: dry fire, ricochets, distant shots. Use the "Creative Commons 0" filter; check each file. |

## Creatures
| Pack | Licence | Repo | What's in it |
| --- | --- | --- | --- |
| [80 CC0 creature SFX](https://opengameart.org/content/80-cc0-creature-sfx) (rubberduck) | CC0 | commit | Alien, bug, monster, hurt, scream, roar, **spit**: the stalker's base. |
| [80 CC0 creature SFX #2](https://opengameart.org/content/80-cc0-creture-sfx-2) | "CC0" in the title only: check the page | local until checked | **9 bug, 8 slime**, alien, die: clicks and skitter. |
| [Free monster voice pack](https://lazyspar7an.itch.io/free-monster-voice-pack-growls-grunts-death-sounds-wav) | Free; "commercial and non-commercial, no credit" | local | Growls, pain, death screams. |
| [Monster sound effects 2](https://opengameart.org/content/monster-sound-effects-2) (Ogrebane) / [Monster or beast sounds](https://opengameart.org/content/monster-or-beast-sounds) (pauliuw) | CC0 | commit | Die, hit, attack, idle; growls. |
| freesound CC0: [Monster Screech](https://freesound.org/s/518297), [Calls Beyond Earth](https://freesound.org/s/466871) | CC0 | commit | Lunge screech; alien calls. |

## Ship, sparks, explosions
| Pack | Licence | Repo | What's in it |
| --- | --- | --- | --- |
| [Kenney Sci-fi Sounds](https://opengameart.org/content/sci-fi-sounds) | CC0 | commit | 70 OGG: engines, explosions, lasers. Machinery hums. |
| [50 CC0 sci-fi SFX](https://opengameart.org/content/50-cc0-sci-fi-sfx) | CC0 | commit | Explosions, loops, terminal beeps (the CUSTODIAN UI). |
| freesound CC0: [Red Alert Klaxon](https://freesound.org/s/350508), [spacecraft hum](https://freesound.org/s/221570), [cargo bay alarm/servos](https://freesound.org/s/206070) | CC0 | commit | Siren, room hum, cargo machinery. |
| freesound sparks: [Electric Sparks](https://freesound.org/s/412313) (InspectorJ), [lowvolt sparks](https://freesound.org/s/32682) | CC BY 4.0 | commit with credit | Shorting consoles. |
| Sonniss GDC bundle (2024 has guns and alien sounds) | royalty-free, no attribution; redistribution terms conflict between sources | local | Huge; dig for ricochets, distant gunfire and fire crackle. Signup unconfirmed. |

**Thin spots:** stalker clicks, chirps and skittering; fire crackle; steam hiss; acid bubbling. The candidate pages for these had unclear licences. Search freesound CC0, or synthesise them (T017's generator) for now.

## How they get into the game
John downloads the packs (each is a click on itch, OGA or freesound) into one folder on the Mac. Then a code packet (T021, written when the files exist):
- sorts them into the T017 bank;
- trims and loudness-matches them;
- builds the round-robin sets from gun-feel.md;
- commits only the CC0/CC-BY files and keeps the rest in the gitignored folder.
