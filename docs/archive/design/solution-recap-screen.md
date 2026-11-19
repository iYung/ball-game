# Solution Recap Screen

## Goal

After a puzzle is solved, instead of jumping straight to the level-select screen, show an intermediate recap screen displaying:
- The number of ticks the solution took
- The number of player-placed pieces on the board
- A looping playback animation of the winning solution

## Affected files

- `game/scenes/matrix_scene.lua` — record frames during run; count pieces; on win switch to recap instead of level-select
- `game/scenes/solution_recap_scene.lua` — new scene (to create)

## What changes

### `matrix_scene.lua`

**Frame recording** — during a run, append each step's matrix anchor position and matrix values to a `self._run_frames` list. Each frame: `{ x, y, matrix }`. Record before and after each `do_step`, capturing the animated from/to positions so the replay can re-use the same smooth-step interpolation.

Concretely: in `start_run`, clear `self._run_frames = {}`. In `do_step`, after computing `from_x/from_y` and `to_x/to_y`, append `{ from_x=from_x, from_y=from_y, to_x=to_x, to_y=to_y, matrix=self.current_matrix:copy() }`.

**Piece counting** — a helper `_count_pieces()` iterates `self.grid` anchor cells and counts tiles where `tile.locked == false` (pushers + ops placed by the player). Only anchor cells are counted (refs are skipped) to avoid double-counting multi-cell tiles.

**Win transition** — in `update`, when `self._win_timer >= 0.8`, instead of switching to `LevelSelectScene`, switch to `SolutionRecapScene.new(...)` passing:
  - `stats = { ticks = self.sim.tick, pieces = self:_count_pieces(), puzzle_name = self.puzzle.name, puzzle_index = self.puzzle_index }`
  - `board = { grid = self.grid, timeline = self.timeline, timeline_n = self.timeline_n, puzzle = self.puzzle }`
  - `frames = self._run_frames`
  - `run_speed = self.run_speed`
  - `scene_manager = self._scene_manager`

### `solution_recap_scene.lua` (new)

A new scene with:

**State**
- `self._stats` — ticks, pieces, puzzle_name, puzzle_index
- `self._frames` — the recorded frame list
- `self._frame_idx` — current frame (1-based)
- `self._anim_t` — interpolation [0,1] within the current frame
- `self._run_speed` — seconds per frame step (same as puzzle's run_speed)
- `self._loop_timer` — time since start of current replay loop
- `self._pause_at_end` — brief hold (0.5s) at the last frame before looping back

**Layout (1280×720)**
- Left panel (0–819 px): mini grid replay — draws the board (grid tiles and live pushers) and the travelling matrix, scaled to fit at the same pixel coords as the puzzle scene (identical draw helpers reused or simplified)
- Right panel (820–1280 px): stat display
  - Puzzle name + index at the top
  - "SOLVED!" in gold
  - Ticks: large number + label
  - Pieces: large number + label
- Bottom bar: `[Enter] Next puzzle   [R] Replay   [Esc] Menu`

**Animation loop**
- `update(dt)`: advance `self._anim_t` at the same `run_speed` rate. When `anim_t >= 1`, advance `frame_idx`. When `frame_idx > #frames`, hold for `_pause_at_end` seconds then reset to frame 1 and loop.
- `draw()`: interpolates the matrix position using the current frame's `from_x/from_y/to_x/to_y` and `anim_t`, using the same smooth-step formula. Draws the static grid (source, sink, pushers, op tiles) underneath, and the animated matrix on top.

**Input**
- `Enter` / `Return` → switch to next puzzle (wrap around) via `MatrixScene.new(puzzle_index + 1)`
- `R` → reset `frame_idx = 1`, `anim_t = 0` (restart replay)
- `Escape` → switch to `LevelSelectScene`

## What stays the same

- The grid draw helpers (source, sink, op, pusher rendering) can be shared by calling the same sub-routines. The recap scene duplicates the minimal drawing needed (or requires `MatrixScene` to expose static draw helpers).
- `pusher_sim.lua`, `grid.lua`, `matrix_math.lua` — untouched.
- `level_select_scene.lua`, `start_scene.lua` — untouched.

## Open questions

None — proceeding to checklist.
