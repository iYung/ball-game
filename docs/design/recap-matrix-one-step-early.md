## Goal

Fix the solution-recap animation so the matrix values displayed on each frame match the state the matrix *carries into* that move, not the state it *arrives at after* ops fire.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — where run frames are built in `do_step()`
- `tests/test_solution_recap.lua` — where frame-capture behaviour is tested

## What changes

In `MatrixScene:do_step()` the frame is currently recorded as:

```lua
matrix = self.current_matrix:copy(),   -- line 654: POST-op state
```

`_process_footprint` is called just before this (line 643).  Because every matrix operation returns a fresh object (all matrix methods call `self:copy()` internally), `self.current_matrix` has been reassigned to the post-op matrix while the local `mat` (captured on line 602) still points to the pre-op matrix.

The fix is to record `mat:copy()` instead, so each frame carries the values the matrix had *before* entering the new cell, matching what the player sees in the live game before ops fire.

A new assertion in `test_solution_recap.lua` will cover a run that crosses a `negate` op and check that the frame recorded for the step into the negate cell still carries the un-negated values.

## What stays the same

- The ops still fire correctly (they update `self.current_matrix`).
- The position interpolation (`from_x/to_x`) is unaffected.
- Pusher position recording is unaffected.
- All existing tests continue to pass.

## Open questions

None.
