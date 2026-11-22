# World Select Tab Bar Checklist

- [x] Task A — `lua/game/scenes/level_select_scene.lua` — Replace the world bar constants (`BAR_Y`, `BAR_H`, `ARROW_W`), arrow hit-rects (`_arrow_left`, `_arrow_right`), and dot-drawing code with a tab bar. Add `TAB_H = 48` at the top of the screen (y=0). Each tab is `W / world_count` wide. Active tab gets highlighted background + coloured bottom-edge underline. Locked tabs show a padlock symbol (`[?]`) and are dimmed. Remove world dots below the old bar. Adjust `LIST_TOP` upward to fill freed space.

- [x] Task B — `lua/game/scenes/level_select_scene.lua` — Update `ui_elements()` to replace `world:prev` / `world:next` buttons with one `world:N` button per world (N = 1-based index). Locked worlds have `enabled = false`. Add a `_switch_world(target)` helper that calls the cutscene/unlock logic for a direct index jump (wraps `_cycle_world` or replicates its behaviour for a direct target). Wire mouse clicks on tab elements to `_switch_world`. Keep left/right arrow keys calling `_cycle_world(±1)` as before.

- [x] Task C — `tests/ui/03_world_locking.lua` — Update the UI spec to use tab element IDs instead of `assert_text` world-name checks. Replace `{ press = "right" }` / `{ assert_text = "WORLD 1: BASICS" }` etc. with `{ click_button = { id = "world:2" } }` where appropriate. Keep the locked-world-is-skipped test valid (clicking a locked tab should do nothing).

- [x] Task D — `tests/ui/02_level_select_keyboard.lua` — The `"left-arrow and u-key"` test currently uses `press = "right"` / `press = "left"` to cycle worlds; that still works (keyboard cycling unchanged). Verify no other steps in this file assert text or buttons specific to the old arrow design, and update any that do.
