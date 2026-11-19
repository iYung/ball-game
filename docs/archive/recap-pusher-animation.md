## Recap Pusher Animation Checklist

- [x] Task A — `game/scenes/matrix_scene.lua` — in `do_step()`, snapshot pusher pixel coords into `pushers_from` before `Sim.advance()` and `pushers_to` after; add both arrays to each recorded frame
- [x] Task B — `game/scenes/solution_recap_scene.lua` — in `_draw_grid()`, skip tiles where `tile.kind == "pusher"` so the static placed-position ghost is not drawn
- [x] Task C — `game/scenes/solution_recap_scene.lua` — add `_draw_pushers()` method: iterate `frame.pushers_from`/`pushers_to`, interpolate with smooth-step, draw each pusher with the same style as `_draw_tile` pusher branch; call it from `draw()` between `_draw_grid()` and `_draw_matrix()`
- [x] Task D — `tests/test_solution_recap.lua` — add assertions: winning frame has `pushers_from` table; with a pusher on board, `pushers_from[1]` has `id`, `px`, `py` fields
