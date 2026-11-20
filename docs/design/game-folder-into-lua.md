# Move `game/` into `lua/`

## Goal

Consolidate all Lua source under a single `lua/` root so the top-level directory contains only non-Lua concerns (assets, data, docs, tests, conf, main). After this change the layout will be:

```
lua/
  core/       (unchanged — engine utilities)
  headless/   (unchanged — test infrastructure)
  game/       (moved from top-level game/)
    grid.lua
    hud.lua
    matrix_math.lua
    palette.lua
    param_popup.lua
    player.lua
    progress.lua
    pusher_sim.lua
    puzzle_loader.lua
    scenes/
      cutscene_scene.lua
      game_scene.lua
      level_select_scene.lua
      matrix_scene.lua
      solution_recap_scene.lua
      start_scene.lua
```

## Affected files

**Directory move:**
- `game/` → `lua/game/`

**Require-path updates (71 call sites across 29 files):**
- `main.lua`
- `game/*.lua` (3 files with cross-game requires)
- `game/scenes/*.lua` (5 files)
- `lua/headless/ui_runner.lua`
- `tests/test_*.lua` (23 files)
- `tests/ui/04_sweep_all_puzzles.lua`

**Markdown doc updates:**
- `README.md` — Structure section lists `game/` and has a stale `core/lua/` label (actual path is `lua/core/`); both entries need correcting. Code examples reference an absent `core/lua/README.md`.
- `docs/testing.md` — Three inline Lua code snippets use `require("game/progress")` and `require("game/scenes/matrix_scene")`.
- `docs/checklists/multi-cell-op-tiles.md` — File paths in task descriptions (`game/grid.lua`, `game/scenes/matrix_scene.lua`) need updating.
- `docs/checklists/palette-button-overlap.md` — File paths in task descriptions.
- `docs/design/all-ops-first-level.md` — One file path reference.
- `docs/design/multi-cell-op-tiles.md` — File path references in the affected-files table.
- `docs/design/palette-button-overlap.md` — File path reference.

## What changes

1. Physical directory: `git mv game lua/game`
2. Every `require("game/...")` becomes `require("lua/game/...")` — a pure string substitution with no logic changes.
3. `main.lua` line `require("game/scenes/start_scene")` → `require("lua/game/scenes/start_scene")`.
4. Markdown files updated so path references stay accurate.

## What stays the same

- All game logic, scene code, and test logic — no behaviour changes.
- `lua/core/` and `lua/headless/` paths are untouched.
- `data/`, `assets/`, `tests/` directory locations are untouched.
- CI workflows, `conf.lua`, `package.json` — no changes needed.

## Open questions

None — the change is a mechanical path rename with no ambiguity.
