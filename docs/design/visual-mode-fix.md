# Visual mode fix

## Goal

`love . --visual tests/test_foo.lua` should run the named unit test in a real
LÖVE window so you can watch each frame render as the test progresses. Right
now the variables `_visual_mode` and `_visual_test` are set in `main.lua` but
never consumed, so the game just starts normally and sits at the start menu
waiting for a player.

## Affected files

- `main.lua` — the only file that needs to change

## What changes

When `_visual_mode = true` and `_visual_test` is non-nil, `love.load()` must:

1. Require `lua/headless/runner` and set `runner._visual = true`.
2. Wrap `dofile(_visual_test)` in a coroutine.
3. Store that coroutine so `love.update` can resume it each frame.

`love.update(dt)` gains a branch: if the visual coroutine exists and is still
suspended, resume it (no arguments needed). When it finishes (or errors), print
PASS/FAIL and call `love.event.quit`.

`love.draw()` gains a branch: if `runner._active_sm` is set (populated by
`runner.setup` when `runner._visual` is true), draw from that scene manager
instead of the normal `manager`. We still wrap it in the letterboxed canvas so
the window scale logic works unchanged.

The `run_frame` → `runner.tick` → `coroutine.yield` chain already yields one
frame at a time back to the main loop, so we get one rendered frame per tick.

Scope: **unit tests only**. UI spec files (`tests/ui/*.lua`) are run by
`UIRunner.run_file`, which does not call `runner.tick` and therefore has no
yield points. That is by design; the docs already note it. If `--visual` is
given with a UI spec path we print an error and quit immediately.

## What stays the same

- Headless mode is untouched.
- Normal (no-flag) gameplay is untouched.
- `runner.lua`, `ui_runner.lua`, `stubs.lua` are untouched.
- `love.keypressed`, `love.mousepressed`, etc. are untouched (irrelevant in
  visual-test mode since input is scripted).

## Open questions

None. Scope is fully determined by the existing `runner._visual` mechanism.
