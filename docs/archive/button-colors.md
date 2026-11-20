# Button Colors Checklist

- [x] Task A — `lua/game/scenes/matrix_scene.lua` — Add `color_fill` and `color_border` fields to each entry in `CMD_BUTTONS`, then update `_draw_cmd_buttons()` to use them (fall back to neutral when absent); disabled state keeps current dim-out
- [x] Task B — `lua/game/scenes/solution_recap_scene.lua` — Add `color_fill` and `color_border` fields to each entry in `RECAP_BUTTONS`, then update `_draw_buttons()` to use them (fall back to neutral when absent); disabled state keeps current dim-out
