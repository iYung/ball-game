# Matrix Animation Timing Fix

## Goal

Make the puzzle scene display the same matrix values during travel as the solution recap — i.e., the **pre-transform** matrix animates to the op tile, and the transform becomes visible only once the matrix arrives.

## Affected files

- `lua/game/scenes/matrix_scene.lua` — `do_step()` and `draw_travelling_matrix()`

## What changes

**Root cause.**  
In `do_step()`, the local variable `mat` captures `self.current_matrix` (a table reference).  
`_process_footprint()` calls `Sim.apply_op()`, which returns a *new* table, then assigns `self.current_matrix = new_table`.  
Back in `do_step`, the local `mat` still points to the original (pre-transform) table — which is why `_run_frames` already records the right pre-transform snapshot.  
But `draw_travelling_matrix()` reads `self.current_matrix` (post-transform), so the puzzle displays transformed values *while the matrix is still moving*.

**Fix.**  
1. In `do_step()`, after capturing `mat` but before calling `_process_footprint()`, save the reference: `self._anim_display_matrix = mat`.  
2. In `draw_travelling_matrix()`, while `anim_t < 1`, read `self._anim_display_matrix`; at `anim_t >= 1` (animation complete), read `self.current_matrix`.  
3. Clear `self._anim_display_matrix = nil` in `do_reset()` and `start_run()` so stale display matrices are never shown.

No changes to `_process_footprint`, `start_run`, `_run_frames` recording, or the solution recap scene — those are already correct.

## What stays the same

- Game logic, op timing, win detection — untouched.
- Solution recap scene — already shows the correct pre-transform behaviour.
- All existing tests — no game-state semantics change, only the display during animation.

## Open questions

None — the fix is fully determined by matching the solution recap behaviour. `ui_matrix()` (used by `assert_matrix`) also reports the displayed matrix so the behaviour is UI-testable.
