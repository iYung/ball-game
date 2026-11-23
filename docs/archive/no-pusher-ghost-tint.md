## No-pusher ghost tint Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — in `draw_travelling_matrix()`, add `and #self:_pusher_list() > 0` to the idle-preview condition so the 0.45-alpha input matrix only draws once a pusher is placed.
- [x] Task B — `tests/test_matrix_coverage.lua` (existing test, section 5a) — place a pusher before calling `draw_travelling_matrix()` so the float-preview branch (line coverage) is still exercised; the old precondition (no pusher) no longer reaches that branch by design.
- [x] Task C — `tests/test_idle_preview_pusher_gate.lua` (new) — with a 1x1 `{{0.5}}` input matrix, clear drawn text, assert `"0.5"` is NOT drawn by `draw_travelling_matrix()` with no pusher, then place a pusher and assert it IS drawn.
- [x] Task D — `tests/ui/06_preview_after_pusher.lua` (new UI spec) — drive puzzle 1 through real clicks (select "P", click a cell), assert the pusher placed and input matrix intact, then Reset and confirm state returns to idle.
