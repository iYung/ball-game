## Game Folder Into Lua Checklist

- [x] Task A — `game/` → `lua/game/` — `git mv game lua/game` to physically relocate the directory

- [x] Task B — `main.lua`, `lua/game/**/*.lua`, `lua/headless/ui_runner.lua`, `tests/**/*.lua` — Replace every `require("game/` with `require("lua/game/` (71 call sites across 29 source files)

- [x] Task C — `README.md` — Update Structure section: change `game/` entry to `lua/game/`, fix `core/lua/` label to `lua/core/`, remove dead link to `core/lua/README.md`

- [x] Task D — `docs/testing.md` — Update the three inline Lua code examples that use `require("game/progress")` and `require("game/scenes/matrix_scene")` to use `lua/game/` paths

- [x] Task E — `docs/checklists/multi-cell-op-tiles.md`, `docs/checklists/palette-button-overlap.md`, `docs/design/all-ops-first-level.md`, `docs/design/multi-cell-op-tiles.md`, `docs/design/palette-button-overlap.md` — Update all file-path references from `game/` to `lua/game/` in task descriptions and affected-files tables
