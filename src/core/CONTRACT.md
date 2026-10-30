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

Failures are loud: `push_error("Data: ...")`, `null`/fallback return, `last_error` set. Tests in `tests/test_data.gd` cover good, missing and bad files and parse every file in `data/`.

## Signals
None.

## Data keys
None of its own.
