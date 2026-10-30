# Grave Rats — Claude Code guide (code builder and QA)

Co-op top-down sci-fi salvage shooter. Godot 4.7, GDScript, Forward+. Brief: `docs/handoffs/game-brief.md`.

## Start every session
0. Check you are in the right clone: the code lane works in `~/Projects/grave-rats-code`, QA in `~/Projects/grave-rats-qa`. If `pwd` is anything else, stop.
1. `git checkout main && git pull`, then branch for the task: `git checkout -b t002-camera-study`. Never commit to `main`. (Unattended runs: the runner has already made `auto/<id>-mac`; stay on it.)
2. Read `docs/STATUS.md`, then the task packet in `docs/tasks/`.
3. Read only the `CONTRACT.md` of the modules the packet names. Search big scripts for the functions you need before reading them whole.

Don't read `docs/reference/` unless the packet says so. It holds the old prototype and the long pitch.

## Layout
- `src/<module>/`: one folder per module, each with a `CONTRACT.md` (owns, does not own, public API, signals, data keys). Modules talk through contracts and signals, never each other's internals.
- `scenes/`: Godot scenes.
- `data/*.json`: **every number a designer might tune** (camera, speeds, damage, light ranges). Never hard-code them in scripts.
- `tests/`: headless tests. The runner must FAIL if any test file fails to load.
- `tools/`: capture scripts, Blender scripts (`tools/blender/`), runners.
- `assets/source/`: art sources, owned by the art lane and John. Never edit them. Import copies into `assets/game/`.

## Rules
- One task per session. Stay inside the modules the packet names.
- Pure logic (damage, sight, inventory rules) stays scene-free so it runs headless.
- Don't add systems the packet doesn't ask for. Ideas go in STATUS "Parked", one line each.
- Performance is a feature: report frame time on this Mac for anything visual (the packet says where to measure).

## Commands
- Tests: `godot --headless --path . -s tests/run_tests.gd`. If `godot` isn't on PATH, use `/Applications/Godot.app/Contents/MacOS/Godot`.
- Re-import after adding assets: `godot --headless --path . --import`.
- Captures: `tools/capture.sh <scene> <out-dir>`, a windowed run that saves PNGs, made in T001.

## End of every task
- Run the packet's acceptance checks and report the results honestly, including what you couldn't check.
- Commit on your branch (author `mossforged <mossforged@users.noreply.github.com>`). Unattended runs don't push (the runner does); interactive runs `git push -u origin <branch>`. Never merge to main.
- Write `docs/handoffs/auto-<ID>.md`: what changed, checks run with numbers, screenshots made, what needs John's eye.
- Update `docs/STATUS.md` in place: the Stage/Next lines and a 2–3 line "Last session" (replace the old one). Keep STATUS to about a page.
- Update the `CONTRACT.md` of any module you changed, in place.
- John's play feedback, if you hear any, goes into `docs/playtests/log.md` in his words, dated.

## Stage gates
When John passes a gate, the lead tags the commit (`stage-N`).
