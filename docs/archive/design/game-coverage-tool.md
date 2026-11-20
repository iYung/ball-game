# Game Coverage Tool

## Goal

Add a `--coverage` flag to the headless test runner that measures line-level coverage across `lua/game/` and prints a per-file report. The goal is to identify which game-logic paths are not exercised by the test suite so gaps can be targeted with new tests.

`lua/core/` is deliberately excluded: its files are mostly rendering infrastructure (`shader.lua`, `sprite.lua`, `spriteset.lua`, `fonts.lua`) that cannot be meaningfully exercised in headless mode where `love.graphics` is stubbed out. Tracking those files would inflate the "uncovered" total without pointing at anything testable.

## Affected files

- `lua/headless/coverage.lua` — new file (already written); needs scope narrowed from `{lua/core, lua/game}` to `{lua/game}` only
- `main.lua` — modified to accept `--coverage` flag; starts the hook before the runner and patches `love.event.quit` to print the report before quitting

## What changes

**`lua/headless/coverage.lua`**

- The `hook` function's path filter changes from `path:match("^lua/core/") or path:match("^lua/game/")` to `path:match("^lua/game/")` only.
- The `M.report` directory scan changes from iterating `{ "lua/core", "lua/game" }` to `{ "lua/game" }` only.
- The module-level comment is updated to reflect the narrowed scope.

**`main.lua`** (already complete — no further changes needed)

- Parses `--coverage` from the argument list.
- When present: `require`s `coverage`, calls `cov.start()`, then monkey-patches `love.event.quit` so `cov.report()` runs before the process exits.
- The existing `--headless` path is otherwise unchanged.

## What stays the same

- All existing tests (`tests/test_*.lua` and `tests/ui/*.lua`) are unchanged.
- The headless runner (`lua/headless/runner.lua`) is unchanged.
- Running `love . --headless` without `--coverage` behaves identically to before.
- Coverage measurement uses only the standard Lua `debug` library — no third-party tools required.
- Executable-line counting uses a simple heuristic (skip blank lines, comment lines, and bare structural keywords); this may undercount in some files, so hit counts that exceed the estimate are capped at 100 % in the display.

## Open questions

None.
