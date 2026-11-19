# Validate Matrix Footprint After a Transform

## Goal

When an op tile fires and changes the matrix's dimensions (currently only `transpose` does this), the resulting footprint must be validated before the run continues. Right now no check is made, so a transpose can silently produce a matrix that extends off the board, overlaps a gap cell, or overlaps a pusher — all of which should be illegal states that end the run.

## Affected files

- `game/pusher_sim.lua` — add `Sim.footprint_clear(x, y, rows, cols, w, h, gaps, pushers)` helper
- `game/scenes/matrix_scene.lua` — call that helper inside `_process_footprint` after each op fires; if the check fails, set `self.running = false; self.status = "fail"` and stop processing further ops
- `tests/test_pushers.lua` — add unit tests for `Sim.footprint_clear`
- `tests/test_pusher_scene.lua` (or a new headless test file) — add integration tests for the three failure modes via the scene if feasible; otherwise cover them in the Sim-level unit tests

## What changes

### `game/pusher_sim.lua`

Add a new exported function:

```lua
-- Returns true if the matrix footprint anchored at (x,y) with given rows/cols
-- is fully in-bounds, clear of gaps, and does not overlap any pusher.
function Sim.footprint_clear(x, y, rows, cols, w, h, gaps, pushers)
    if Sim.blocked(x, y, rows, cols, w, h, gaps) then return false end
    if pushers then
        for _, q in ipairs(pushers) do
            if q.x >= x and q.x <= x + cols - 1
               and q.y >= y and q.y <= y + rows - 1 then
                return false
            end
        end
    end
    return true
end
```

### `game/scenes/matrix_scene.lua`

Inside `_process_footprint`, in the loop that fires entered_anchors, after updating `mat` via `Sim.apply_op` add a validity check:

```lua
mat = Sim.apply_op(tile, mat)
self.occupied_ops[info.akey] = {ax=info.x, ay=info.y}
if not Sim.footprint_clear(self.sim.x, self.sim.y,
                            mat.rows, mat.cols,
                            self.grid.w, self.grid.h,
                            self.sim.gaps, self.sim.pushers) then
    self.running = false
    self.status  = "fail"
    self.current_matrix = mat
    return new_fp
end
```

The early return exits `_process_footprint`; `do_step` sees `self.running = false` and skips any further simulation.

## What stays the same

- `transpose` is still the only op that can change rows/cols; the check is cheap and harmless for non-dimension-changing ops.
- The `Sim.blocked` function is unchanged.
- All existing tests must continue to pass.
- Pusher movement checks, gap checks, and edge checks during pushes are untouched.

## Open questions

None. The three failure modes (off-board, gap overlap, pusher overlap after transform) are deterministic and reproducible with simple unit tests.
