# Remove Step Command Checklist

- [x] Task A — `game/scenes/matrix_scene.lua` — remove `{ id="step", label="Step" }` from CMD_BUTTONS; remove both `elseif id == "step"` branches from `_cmd_enabled` and `_cmd_activate`; remove `space = "step"` from the KEY_CMD table in `key_pressed`
- [x] Task B — `tests/test_matrix_registry.lua` and `tests/test_palette_layout.lua` — remove all assertions that reference `cmd:step`
