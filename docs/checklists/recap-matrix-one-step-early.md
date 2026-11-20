## Recap Matrix One Step Early — Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — In `do_step()`, change line 654 from `matrix = self.current_matrix:copy()` to `matrix = mat:copy()` so each frame stores the pre-op matrix values.
- [x] Task B — `tests/test_solution_recap.lua` — Add an assertion: set up a run where the matrix crosses a `negate` op tile, capture the frame recorded for that step, and assert that `frame.matrix.values[1][1]` equals the un-negated value (i.e. the pre-op value), not the post-negate value.
