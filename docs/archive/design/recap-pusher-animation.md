## Goal

Fix the solution recap replay loop so that pushers animate to their correct positions each tick, mirroring what the player saw during the winning run.

## Affected files

- `game/scenes/matrix_scene.lua` — where run frames are recorded
- `game/scenes/solution_recap_scene.lua` — where frames are replayed
- `tests/test_solution_recap.lua` — tests for recap behaviour

## What changes

### Frame recording (`matrix_scene.lua` — `do_step`)

Each recorded frame currently stores only the matrix ball's pixel start/end positions and a matrix snapshot. Pusher positions are **not** captured.

Before calling `Sim.advance()`, snapshot each pusher's current pixel position (`cell_top_left(p.x, p.y)`) as `{id, px, py}` into `pushers_from`. After the advance mutates the pushers in-place, snapshot again into `pushers_to`. Both arrays are added to the frame table alongside the existing fields.

### Static grid drawing (`solution_recap_scene.lua` — `_draw_grid`)

The inner tile-drawing loop currently draws all tile kinds including `"pusher"`. Pusher tiles must be skipped here — they will be drawn by the new animated pass instead. Without this skip, a ghost at the placed position would show permanently underneath the moving pusher.

### Animated pusher drawing (`solution_recap_scene.lua` — `_draw_pushers`)

New method. Reads `frame.pushers_from` and `frame.pushers_to` from the current frame and interpolates each pusher's screen position with the same smooth-step easing already used for the matrix ball. Draws each pusher using the same visual style as `_draw_tile` for `kind="pusher"`. Called from `draw()` between `_draw_grid()` and `_draw_matrix()`.

Graceful fallback: if the current frame has no `pushers_from` (e.g. fake frames in existing tests), the method returns early and nothing is drawn.

### Tests (`tests/test_solution_recap.lua`)

Add two assertions to the existing "run_frames recorded correctly" test:

1. `frame.pushers_from` is a table (even if empty when the board has no pushers).
2. When a pusher is placed and a winning run is performed, `pushers_from` contains at least one entry with `id`, `px`, `py` fields.

## What stays the same

- Existing frame fields (`from_x`, `from_y`, `to_x`, `to_y`, `matrix`) — unchanged, additive change only.
- Matrix ball animation logic — unchanged.
- All existing tests pass without modification to their frame construction.
- Pusher drawing style — same colours and font as the existing `_draw_tile` pusher branch.

## Open questions

None — the fix is straightforward. The pusher pixel coords are already computed inside `do_step` (the `cell_top_left` helper exists) and the smooth-step interpolation pattern is already in `_draw_matrix`.
