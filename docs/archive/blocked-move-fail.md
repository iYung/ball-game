# Blocked Move → Puzzle Fail Checklist

- [x] Task A — `game/pusher_sim.lua` — Add a `blocked` return value to `Sim.advance`.
  Track `local blocked = false` before the pusher loop. For each pusher: if the command is
  non-idle (`d ~= nil`) and the final `ok` is `false` after all movement/shove logic,
  set `blocked = true`. Change the last `return moved` to `return moved, blocked`.

- [x] Task B — `game/scenes/matrix_scene.lua` — Consume the new `blocked` return value in `do_step`.
  At line 386, change `local moved = Sim.advance(st)` to `local moved, blocked = Sim.advance(st)`.
  Immediately after (before footprint processing), add:
  ```lua
  if blocked then
      self.running = false
      self.status  = "fail"
      return
  end
  ```
  Also add `"fail"` to the allowed statuses in `key_pressed` for the Space key (line 1447) so a
  failed-by-collision run can be stepped through without pressing R first — actually `"fail"` is
  already there for the R key; confirm Space also allows restart when status is `"fail"`. (Space is
  for single-stepping, not restarting — just verify the R-key guard at line 1437 already includes
  `"fail"`, which it does. No change needed there.)

- [x] Task C — `tests/test_pushers.lua` — Update unit tests to assert the new `blocked` return value.
  For every `Sim.advance` call that expects a blocked move, capture both return values and assert
  `blocked == true`. For every move that should succeed (valid command executes), assert
  `blocked == false`. Specifically:
  - "pusher moves" block: add `, false` checks to successful advances
  - "blocking" block: check `blocked == true` for each blocked advance
  - "pusher collision" block: check `blocked == true` for the blocked pusher cases
  - "gap blocking" block: check `blocked == true` for blocked-by-gap advances

- [x] Task D — `tests/test_pusher_scene.lua` — Add a scene-level test that a blocked move fails the run.
  Write a new `do` block after the existing tests: place a pusher at `(1, 6)` with a single "left"
  command (hits the left wall, always blocked). Call `run_to_end(scene)` and assert
  `scene.status == "fail"`. Add a second case: pusher at `(8, 5)` with "right" command into a matrix
  anchored at `(9, 5)` that is against the right wall (cols=2, so anchor+1=10 is the edge, pushing
  right would put anchor at 10 which is in-bounds but anchor+1=11 is off — confirm exact setup matches
  the puzzle grid size) so the matrix cannot be shoved → also `"fail"`.
