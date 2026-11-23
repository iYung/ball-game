## Restore Tabs + Cutscene Fix Checklist

- [x] Task A — `lua/game/scenes/level_select_scene.lua` — Replace entire file contents with blob `83f976e` (the correct tab-bar + settings-overlay version). This restores `_switch_world`, `world_index_of`, tab rects, settings menu wiring, and Sound music start. Do NOT edit — write the full file.

- [x] Task B — `tests/test_level_select.lua` — Replace file with blob `9f63832` (tab-based registry/locked-tab tests) then append a "right-click does not switch scene" unit test that simulates `mouse_pressed(x, y, 2)` on the world:1 tab rect and asserts the scene hasn't changed.

- [x] Task C — `tests/ui/01_solve_puzzle_1.lua` — Change `{ assert_text = "WORLD 1: BASICS" }` to `{ assert_button = { id = "world:1", selected = true } }` (tab is active, not a text label).

- [x] Task D — `tests/ui/03_world_locking.lua` — Replace text-based world-name assertions with tab button assertions:
  - `assert_text = "WORLD 1: BASICS"` → `assert_button = { id = "world:1", selected = true }`
  - `assert_no_text = "WORLD 2"` → `assert_button = { id = "world:2", selected = false }`
  - `assert_text = "WORLD 2: COMBOS"` → `assert_button = { id = "world:2", selected = true }`

- [x] Task E — `tests/ui/04_sweep_all_puzzles.lua` — Two changes:
  1. `assert_text string.format(...)` → `assert_button { id = string.format("world:%d", w), selected = true }`
  2. After `add({ press = "escape" })`, restore `add({ click_button = { id = "settings:exit" } })` (ESC opens settings overlay; settings:exit navigates back to level select)

- [x] Task F — `tests/ui/05_start_screen.lua` — Replace both `assert_text = "WORLD 2: COMBOS"` occurrences with `assert_button = { id = "world:2", selected = true }`.

- [x] Task G — `tests/ui/02_level_select_keyboard.lua` — Remove the "escape on level select returns to start screen" spec entirely (ESC now opens the settings overlay, not the start screen). Keep "right-click on level select row does nothing".

- [x] Task H — `tests/ui/06_cutscene.lua` — Append a third spec: start on title, press return → level select, click `world:2` tab (first visit, cutscenes_unseen={2}) → cutscene triggers, escape to skip, land on level select world 2 with "Ordered Ops" puzzle visible.
