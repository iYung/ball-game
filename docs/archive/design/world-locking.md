# World Locking

## Goal

Gate worlds behind progression: a world is locked until every puzzle in all previous worlds has been solved. World 1 is always unlocked. A debug "Unlock All" button on the start screen bypasses this for testing.

## Affected files

- `game/progress.lua` — new module; owns the solved-set and persistence
- `game/scenes/solution_recap_scene.lua` — marks the puzzle solved on entry
- `game/scenes/level_select_scene.lua` — greys out locked worlds; blocks navigation into them
- `game/scenes/start_scene.lua` — adds a second "UNLOCK ALL" debug button
- `lua/headless/stubs.lua` — extend `love.filesystem` stub with `read` and `write` so tests work

## What changes

### `game/progress.lua` (new)

A singleton module that tracks which puzzle indices have been solved.

```
Progress.mark_solved(n)       -- record puzzle n as solved; persist
Progress.is_solved(n)         -- boolean
Progress.is_world_unlocked(w) -- true if w == 1 OR all puzzles in worlds 1..w-1 are solved
Progress.unlock_all()         -- mark every puzzle solved; persist
Progress.reset()              -- clear all progress; persist (useful for tests)
```

Persistence: a small file in LÖVE's save directory (`progress.lua`) containing a serialised Lua table of solved indices: `return {1,3,5}`. On load, the file is `pcall`-ed so a missing or corrupt file silently starts fresh. On write, the table is serialised manually (no dependency on external libs).

In headless/test environments `love.filesystem.read` and `love.filesystem.write` will be stubbed to no-ops, so `Progress` degrades gracefully (in-memory only).

### `solution_recap_scene.lua`

In `on_enter`, after loading fonts, call:

```lua
local Progress = require("game/progress")
Progress.mark_solved(self._stats.puzzle_index)
```

No other changes.

### `level_select_scene.lua`

- In `draw`, locked world tabs render dimly (colour `0.30, 0.32, 0.42`) with a `[lock]` text label instead of the world name. Unlocked worlds render as today.
- In `_cycle_world`, skip worlds that are locked (advance further in the same direction until an unlocked world is found, wrapping if needed — if somehow all were locked, stay put, though World 1 is always unlocked so this never happens).
- In `draw` for the level rows, no per-level locking — all levels inside an unlocked world are playable.

### `start_scene.lua`

Add a second, smaller button below the existing prompt:

```
[Enter] or click to play

           (D) Unlock All
```

Pressing `d` or clicking the "Unlock All" label calls `Progress.unlock_all()` and then advances to `LevelSelectScene` normally. No confirmation dialog. The button is visually subdued (small font, muted colour) so it reads as a dev tool.

### `lua/headless/stubs.lua`

Extend the existing `love.filesystem` stub:

```lua
love.filesystem.read  = function() return nil end
love.filesystem.write = function() end
```

## What stays the same

- `puzzle_loader.lua` — untouched
- `MatrixScene` — untouched
- The world groupings (Basics / Combos / Advanced) — untouched
- All existing puzzle files — untouched
- `SolutionRecapScene` visual layout — untouched beyond the one `mark_solved` call

## Open questions

- None blocking. `unlock_all` is intentionally a dev shortcut and not hidden; it can be removed or gated behind a build flag later.
