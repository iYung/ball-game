# Remove Step Command

## Goal

Remove the Step button (and its spacebar binding) from the matrix scene. Step was intended as a single-tick debugger but is broken — pressing it from an idle state triggers `start_run()` which sets `running = true` + `anim_ready = true`, causing `update()` to begin full auto-run on the next frame. The button is disabled immediately after and can never actually single-step. No UI spec covers it.

## Affected files

- `game/scenes/matrix_scene.lua` — CMD_BUTTONS table, `_cmd_enabled`, `_cmd_activate`, `key_pressed`
- `tests/test_matrix_registry.lua` — asserts `cmd:step` is present
- `tests/test_palette_layout.lua` — asserts `cmd:step` appears in the button bar

## What changes

- Remove `{ id="step", label="Step" }` from `CMD_BUTTONS`
- Remove the `elseif id == "step"` branches from `_cmd_enabled` and `_cmd_activate`
- Remove `space = "step"` from the `KEY_CMD` table in `key_pressed`
- Remove `cmd:step` assertions from `test_matrix_registry.lua` and `test_palette_layout.lua`

## What stays the same

- `do_step()` itself is not removed — it is the internal per-tick advance called by `update()` during a Run, and by `start_run()` indirectly. It is not player-facing.
- Run, Reset, and Menu buttons are untouched.
- All simulation logic (Sim.advance, footprint processing, win/fail detection) is untouched.

## Open questions

None — user confirmed removal.
