# Grave Rats

Co-op top-down sci-fi salvage shooter: crews of scoundrels board derelict ships taken over by something weird, grab what they can and try to get out. Godot 4.7.

- Brief and pillars: `docs/handoffs/game-brief.md`
- Where things stand: `docs/STATUS.md`
- Decisions: `docs/decisions.md`
- Builder guides: `CLAUDE.md` (code and QA), `AGENTS.md` (art), `QA.md`

## Mac setup (one time)
Run in Terminal on the Mac mini:

```
mkdir -p ~/Projects && cd ~/Projects
git clone https://github.com/mossforged/grave-rats.git grave-rats-code
bash grave-rats-code/tools/code-runner/install.sh
bash grave-rats-code/tools/art-runner/install.sh
bash grave-rats-code/tools/qa-runner/install.sh
```

The art and QA installers make their own clones (`grave-rats-art`, `grave-rats-qa`), so no agent shares a working folder. Each runner checks its queue (`docs/queue/<lane>.txt`) every 10 minutes and runs new packets unattended on their own `auto/` branch. Logs: `~/Library/Logs/grave-rats-<lane>-runner.log`.

## Origins
Grew out of the Dead Circuit prototype (Three.js). Its pitch, code and comparison captures are in `docs/reference/`; its glTF characters, kit and textures are in `assets/source/legacy-pass05/` (rebuild scripts in `tools/blender/`).
