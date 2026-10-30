# Decisions (dated, append-only; a change is a new line that supersedes)

- 2026-10-29: Project continues the Dead Circuit prototype (Three.js, built in ChatGPT, then pass 05 by Claude) as a new project. John: the current map and mission are "200% disposable"; the goal is to match or exceed the concept art.
- 2026-10-29: Name: **Grave Rats** ("for now", John). Checked: no game found using it; a metal band "Grave Rat" exists. Not a trademark search.
- 2026-10-29: Engine: **Godot 4** (John agreed). Lead's reasons: plain-text scenes agents can edit, Forward+ lighting with volumetric fog and global illumination for the concept's look, glTF-native, free, light on the M2, built-in multiplayer for co-op later. Trade-off accepted: desktop game, no easy browser play.
- 2026-10-29: Workflow: multi-agent. Lead = this Claude chat; code and QA = Claude Code on John's Mac mini (queue runners); art = Codex on the Mac, unattended (ImageGen); 3D models from John case by case. John = designer and gatekeeper.
- 2026-10-29: Repo `mossforged/grave-rats`, **public** (John created it public). No GitHub Actions, no LFS.
- 2026-10-29: Renderer Forward+ (lead's choice for lighting quality; Dead Links used Mobile). Revisit if the M2 can't hold frame rate.
- 2026-10-29: Camera direction (lead's finding, to be judged in T002): the concept uses a **perspective** camera (both side walls show their inner faces); the prototype's orthographic camera could not match it. The concept's proportions are internally inconsistent (the operator is about a third of a medbay bed's length), so scale is chosen in-game, not traced from the art.
- 2026-10-29: Carried over from the prototype as legacy assets only: the operator and robot glTF (one shared skeleton, 13 clips), the 32-piece environment kit, 15 PBR texture sets, the Blender/texture build scripts. Reference only; free to replace.
- 2026-10-29: Pillars approved, with two from John: **weight, not speed** (deliberate, visceral combat; turning, aiming, firing and reloading take time; cover matters; ambushes scare because you can't spin instantly) and **satirical tone** (200 years on, worse capitalism drives desperate crews into derelicts for credits; humour from desperation, violence still lands).
- 2026-10-29: Threats (John): rogue AI, robots, aliens, horrors, and rival pirate crews. Roster and mix still open; A001 explores.
