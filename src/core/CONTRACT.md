# core

## Owns
- `data.gd`: loading designer-tunable numbers from `data/<name>.json`. Autoload `Data`.

## Does not own
- What the numbers mean (each module reads its own file).
- Scenes, rendering, input.

## Public API (`Data` autoload)
- `load_data(name: String) -> Variant`: parsed `data/<name>.json` (cached), or `null` on a missing file or bad JSON.
- `value(name: String, key: String, fallback = null) -> Variant`: one top-level key; returns `fallback` if the file or key is missing.
- `last_error: String`: why the last failing call failed ("" after a good load).
- `base_dir: String`: defaults to `res://data`; tests point it at fixtures.
- `clear_cache()`.
- **Ships (T023):** `ship` (the deck file in use, default `"deck"`), `use_ship(deck_file)`, `pin_ship(deck_file)`, `reset_ship()`, `ship_pinned`, `ship_file("survey") -> "deck_survey"`, static `ship_arg(args)`, static `merged_over(base, over)`. While another ship is in use, `load_data("deck")` reads its file and its `data_overrides` {file: keys} lie over the other files (dictionaries merge, anything else replaces). A dictionary already handed out is refilled in place, so holders of a whole file see it; holders of something nested in one don't. `--ship survey` on the command line pins it at start. On the first ship nothing is merged and no file differs.

Failures are loud: `push_error("Data: ...")`, `null`/fallback return, `last_error` set. Tests in `tests/test_data.gd` cover good, missing and bad files and parse every file in `data/`.

## Signals
None.

## Data keys
None of its own.
