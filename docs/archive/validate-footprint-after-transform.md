## Validate Matrix Footprint After Transform Checklist

- [x] Task A — `game/pusher_sim.lua` — Add `Sim.footprint_clear(x, y, rows, cols, w, h, gaps, pushers)` after the existing `Sim.blocked` function. It returns false if `Sim.blocked` returns true OR if any pusher in the list covers the footprint; otherwise returns true.

- [x] Task B — `game/scenes/matrix_scene.lua` — In `_process_footprint`, after `mat = Sim.apply_op(tile, mat)` and `self.occupied_ops[info.akey] = ...`, call `Sim.footprint_clear` with `self.sim.x/y`, `mat.rows/cols`, `self.grid.w/h`, `self.sim.gaps`, and `self.sim.pushers`. If it returns false, set `self.running = false; self.status = "fail"; self.current_matrix = mat` and `return new_fp` immediately.

- [x] Task C — `tests/test_pushers.lua` — Add a `"footprint_clear"` test block covering: (1) valid footprint returns true, (2) off-board footprint returns false, (3) footprint overlapping a gap returns false, (4) footprint overlapping a pusher returns false.
