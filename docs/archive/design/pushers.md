# Pushers

## Goal
Replace the arrow-guided cursor with player-programmed pushers. The matrix starts idle on the source cell and only moves when a pusher shoves it. Each pusher is a 1x1 tile; the player programs all pushers on one shared tick timeline.

---

## Affected files

| File | Why touched |
|------|-------------|
| `game/pusher_sim.lua` (new) | Pure-Lua tick simulation: reads timeline, resolves pushes, blocking, stuck detection. No Love2D, headless-testable |
| `game/cursor.lua` | Remove path-following (`new`, `reset`, `move`, visited set). Keep `Cursor.apply_op` (could move to `pusher_sim` or stay) |
| `game/scenes/matrix_scene.lua` | Remove arrow tiles/palette buttons; add pusher tile + palette button; timeline panel (draw + click); per-tick run loop using the sim; footprint op/sink logic reused |
| `game/hud.lua` | New end statuses (`stuck`, `timeout`); the empty "CURRENT STATE" block is where the timeline panel lives |
| `data/puzzles/01_identity.lua`, `07_double_flip.lua` | Remove locked arrows; drop `source.dir` from all puzzles |
| `tests/test_pushers.lua` (new) | Headless tests for the sim |

`game/matrix_math.lua` and `game/grid.lua` are not touched.

---

## What changes

### 1. Pusher tile
- New tile kind `pusher`, 1x1, placed from the palette (arrow buttons removed).
- Each pusher gets a stable letter id (A, B, C...) shown on the tile, assigned in placement order; capped at 8 pushers.
- Pushers are **not solid** (revised during implementation): the matrix slides over them. With solid pushers the matrix could never travel horizontally, because a pusher at `x=p` only acts once the matrix covers `p+1`, and every path to that position overlaps `p`. Only a push off the grid edge is blocked (no move that tick; not a failure).
- Erasing a pusher removes its timeline row.

### 2. Shared tick timeline
- One global timeline of N slots (default 8, player-adjustable 1..16, loops).
- Every pusher has a row; each slot is one of `idle, up, down, left, right`.
- Left-click a slot cycles forward, right-click cycles back. The current tick column is highlighted while running.

### 3. How a push resolves each tick
For tick `t`, slot index `((t-1) mod N) + 1`:
1. A pusher with command direction `d` is **active** if the matrix footprint contains the cell directly adjacent to the pusher in direction `d` (it "shoves" the matrix away from itself).
2. All active pushers' direction vectors are summed; each axis is clamped to -1..1. Opposing pushes cancel.
3. If the net vector is non-zero and the destination footprint is in bounds, the matrix anchor moves by that vector. Otherwise nothing moves.
4. After moving, existing footprint rules run unchanged: entering an op tile fires it once (anchor dedupe, re-arm on fully leaving), and any footprint cell on the sink ends the run.

### 4. Run lifecycle
- Matrix starts anchored on the source cell, stationary.
- One tick per `run_speed`; the matrix slides to its new cell with the existing smooth-step animation.
- End states: `win` / `fail` (sink reached, matrix compared to target), `stuck` (no movement for a full timeline length N ticks), `timeout` (500 ticks safety cap).
- `loop` and `out_of_bounds` statuses are removed (blocked pushes replace out-of-bounds).
- Space still single-steps one tick; Run, Reset, puzzle navigation keys unchanged.

### 5. UI placement
The grid fills y=20..650 and the palette is at y=660, so there is no room below the grid. The timeline panel goes in the right column in the currently unused "CURRENT STATE" area of the HUD (about 270px tall, 460px wide: roughly 8 rows of 16px slots).

### 6. Puzzles
Existing 10 puzzles keep their op tiles, source, sink and matrices. Locked arrows in puzzles 01 and 07 are removed. All puzzles are designed so a solution needs pushers placed by the player.

---

## What stays the same
- Matrix math, ops, multi-cell op tiles and their inline +/- editing.
- Footprint-based op triggering and sink detection.
- Matrix drawn as one board cell per element; smooth slide animation.
- Palette, eraser, puzzle navigation, HUD input/target display.

---

## Open questions
1. **Timeline panel location**: right column (above) instead of "below grid" as you chose, because the grid already fills the screen. Alternative is shrinking the cell size. OK to use the right column?
2. **Multiple pushers, same tick**: summed with per-axis clamp (above). Alternative: only the first active pusher (by letter) acts.
3. **Puzzle solvability**: I will assume the 10 puzzles stay as-is minus the locked arrows. If any layout turns out to need a different op placement, that is a follow-up.
