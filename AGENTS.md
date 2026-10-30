# Grave Rats — art builder guide (Codex)

## Start every session
0. `pwd` must be `~/Projects/grave-rats-art`. If it isn't, stop.
1. Unattended runs: the runner has already pulled main and made your branch. Do not run git at all; your sandbox can't write `.git`, and the runner commits what you leave in your folders.
2. Read `docs/handoffs/game-brief.md`, `docs/style-contract.md` (once it exists), `docs/handoffs/asset-contract.md`, then your packet in `docs/tasks/`.

## You own
- `assets/source/` (new folders only; never touch `legacy-pass05/`)
- `docs/screens/<packet-id>/` for review sheets
- `docs/handoffs/auto-<ID>.md` for your report

Never touch `src/`, `scenes/`, `data/`, `tests/` or `tools/`. The code lane imports art; you never copy into the game.

## Rules
- Every asset has an ID from the packet (A001-03…). Never reuse an ID; a revision gets a letter (A001-03b).
- Save the prompt you used next to each image (`<id>.prompt.md`), so a pick can be regenerated or extended.
- Make a contact sheet for review (`docs/screens/<ID>/sheet.png`) with labels, at the sizes the packet asks for.
- If an image is refused, note it in the handoff, skip it and continue.
- If something needs John's decision, write it in the handoff and stop.
- No real brands, logos, celebrities, or other games' characters or ships.
