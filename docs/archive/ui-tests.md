## UI Tests Checklist

Design: `docs/design/ui-tests.md`. Read it first. This checklist owns the *how*; the design owns the *what/why*.

Every task agent sees only its own task text plus the design doc, so each task below is written to stand alone. The **Contracts** section is binding for every task. If a task needs to deviate from a contract, it must stop and report back instead.

---

### Contracts

**C1. UI element entry shape.** Each entry returned by `scene:ui_elements()` is a plain table:

```lua
{ id = "cmd:run", label = "Run", kind = "button", rect = { x = 622, y = 666, w = 42, h = 48 }, enabled = true, selected = false }
```

- `kind` is one of `"button"`, `"cell"`, `"slot"`.
- `enabled` is a boolean and is always present. `selected` is a boolean when the element has a highlight state; otherwise omit it (the runner treats nil as false).
- All coordinates are in logical 1280x720 space. `rect` is half-open: a point is inside if `x <= px < x+w` and `y <= py < y+h`.
- `ui_elements()` returns a fresh, **deterministically ordered** array (build it with `ipairs` over arrays, never with `pairs`). Calling it has no side effects.
- A scene with no `ui_elements` method is treated as returning `{}`.

**C2. Element ids and labels (all scenes).**

| Scene | id | label | kind | notes |
|---|---|---|---|---|
| Start | `start:play` | `Play` | button | rect around the "[Enter] or click to play" prompt: `{x=520, y=572, w=240, h=32}` |
| Start | `start:unlock_all` | `Unlock All` | button | the existing `_unlock_rect` `{x=560, y=625, w=160, h=22}` |
| Level select | `puzzle:<index>` | puzzle name | button | one per row; `selected = (row == self.selected)` |
| Level select | `world:prev` / `world:next` | `<` / `>` | button | existing `_arrow_left` / `_arrow_right` rects; always enabled |
| Matrix | `palette:pusher` | `P` | button | `selected` = the palette selection is this tool |
| Matrix | `palette:<op>` | op label from `PALETTE_BUTTONS` (e.g. `xR`) | button | `<op>` is the **op name**, e.g. `palette:scale_row` |
| Matrix | `palette:fixed:<op>` | op label + `!` (e.g. `<>R!`) | button | e.g. `palette:fixed:swap_rows` |
| Matrix | `palette:drag` / `palette:erase` | `Mv` / `[X]` | button | erase is `selected` when the palette selection is nil |
| Matrix | `palette:page_prev` / `palette:page_next` | `<<` / `>>` | button | only present when paging is active (Task 7) |
| Matrix | `cmd:run` `cmd:step` `cmd:reset` `cmd:menu` | `Run` `Step` `Reset` `Menu` | button | `enabled` from `MatrixScene:_cmd_enabled(id)` |
| Matrix | `cell:<x>,<y>` | same as id | cell | every grid cell, `x = 1..grid.w`, `y = 1..grid.h`, rect from `cell_top_left` and size `CELL_SIZE` |
| Matrix | `tl:dec` `tl:inc` | `-` `+` | button | present only when `_timeline_layout()` is non-nil; `enabled = not self.running` |
| Matrix | `tl:scroll_left` `tl:scroll_right` | `<` `>` | button | `enabled` = can scroll in that direction and not running |
| Matrix | `slot:<L>:<s>` | same as id | slot | `<L>` is the pusher letter `string.char(64 + id)`, `<s>` is the actual slot index; visible window only; `enabled = not self.running` |
| Recap | `recap:next` `recap:replay` `recap:menu` | `Next puzzle` `Replay` `Menu` | button | always enabled |

Matrix element order: palette (left to right as laid out), then commands (Run, Step, Reset, Menu), then cells (y-major: `for y` then `for x`), then `tl:scroll_left`, `tl:scroll_right`, `tl:dec`, `tl:inc`, then slots (pusher order, then slot order).

**Not in the registry (deliberate exception):** the resize affordances in `MatrixScene._expand_rects` (`grow_col`/`shrink_col`/`grow_row`/`shrink_row` strips drawn on top of grid cells). They sit inside cells by design, so the no-overlap invariant would always fail. They keep their existing hit-testing, which runs inside the cell-click path before the tile logic. `docs/testing.md` (Task 9) records this as a known gap.

**C3. Shared helper module `lua/core/ui.lua`** (created by Task 1, consumed by Tasks 3-7):

```lua
local UI = require("lua/core/ui")
UI.hit(rect, x, y)              --> bool, half-open test as in C1
UI.element_at(elements, x, y)   --> first element (list order) whose rect contains (x, y), or nil
UI.find(elements, id)           --> element with that id, or nil
UI.centre(rect)                 --> x, y rounded to whole pixels: math.floor(rect.x + rect.w/2 + 0.5), same for y
UI.overlaps(a, b)               --> true iff the rects intersect with positive area (shared edges do not count)
```

The module must not require any game module.

**C4. Headless stubs API (`lua/headless/stubs.lua`, Task 1).** Requiring the module installs the stubs (same as now) and **returns** a table:

```lua
local Stubs = require("lua/headless/stubs")
Stubs.drawn_text()   --> array of strings recorded by love.graphics.print/printf since the last clear
Stubs.clear_text()
Stubs.set_mouse(x, y)  -- sets the virtual cursor read by love.mouse.getX/getY/getPosition
```

`love.graphics.getWidth()` returns 1280 and `getHeight()` returns 720. `love.mouse.getX/getY/getPosition` return the virtual cursor (default 0,0). `love.mouse.isDown` returns false. `love.mouse.setVisible`/`setCursor` are no-ops. Text recording: string arguments are stored as they are, numbers via `tostring`, LÖVE coloured-text tables (`{color, "str", color, "str"}`) by concatenating their string parts. The log is capped at 5000 entries: when full, clear it before appending.

Code must not use font metrics such as `font:getWidth(text)` for layout. Headless fonts are stub images that report width 120 for any text. Use constants.

**C5. SceneManager addition (Task 1).** `SceneManager:is_idle()` returns `self._fade_state == "idle"`. Nothing else in `scene_manager.lua` changes.

**C6. MatrixScene query methods for the runner (Task 6 adds them, Task 1's runner calls them):**

```lua
scene:ui_matrix()      --> 2D array of numbers (rows of values): current_matrix if non-nil, else input_matrix
scene:ui_tile(x, y)    --> nil if the cell is empty, else { kind = tile.kind, op = tile.op, dir = tile.dir }
                       --   (for a ref cell of a multi-cell tile, the anchor tile's fields)
```

If the current scene lacks these methods, the runner fails the step with `"scene has no matrix"` or `"scene has no tiles"`.

**C7. Spec file format and step vocabulary.** These are exactly as in design section 1. In addition:
- A spec file returns either one spec (a table with `steps`) or a **list of specs** (an array whose items each have `steps`). Each spec in a list gets its own `Progress` reset, `given` and fresh `SceneManager`.
- Allowed step keys: `press`, `click`, `right_click`, `click_button`, `right_click_button`, `click_cell`, `right_click_cell`, `click_slot`, `right_click_slot`, `move_mouse`, `hover_button`, `wait`, `wait_until`, `assert_text`, `assert_no_text`, `assert_button`, `assert_matrix`, `assert_tile`. A step must contain exactly one of these keys. Anything else fails with `"unknown step key '<k>'"`.
- `click_button` / `hover_button` / `assert_button` match against any element kind. The argument is a string label or a table with `id` (for `assert_button`, the table may carry `label` or `id`). A label that matches more than one element fails with `"ambiguous label '<l>' (<n> matches)"`.
- `click_slot.pusher` is a number n (letter `string.char(64+n)`) or a letter string. A slot that is not in the visible window fails the step. The runner never auto-scrolls.
- `click_cell.part`: `"left"` clicks at `x + w/6`, `"right"` at `x + 5*w/6`, and `"centre"` (the default) at the centre, all rounded as in `UI.centre`.
- `wait_until.max_frames` defaults to 600. `wait_until` may carry `text`, `matrix` or both, and all given conditions must hold.
- `assert_matrix` and `wait_until.matrix` compare numbers exactly.

**C8. Runner frame / input semantics (Task 1).**
- One frame is `sm:update(1/60)`, then `Stubs.clear_text()`, then `sm:draw()`, then an invariant check on `sm.current:ui_elements()`.
- Start of each spec: `Progress.reset()`. Then apply `given.solved`: a list means `Progress.mark_solved` each entry, `"all"` means `Progress.unlock_all()`. Then `sm = SceneManager.new(1280, 720)`, `sm:switch(StartScene.new(sm))`, `Stubs.set_mouse(0, 0)`, and run 1 frame.
- **Settle:** before every input step and every assert step, run frames while `not sm:is_idle()`, at most 60. If still not idle, fail with `"fade did not finish"`.
- After every input step, run exactly 1 frame so that the result is drawn.
- A click at (x, y) with button b (1 = left, 2 = right) is: `Stubs.set_mouse(x,y)`, `sm:mouse_moved(x,y)`, `sm:mouse_pressed(x,y,b)`, `sm:mouse_released(x,y,b)`. A move is `Stubs.set_mouse` plus `sm:mouse_moved`. A press is `sm:key_pressed(key)`. The runner never calls scene methods directly, except the read-only `ui_elements`, `ui_matrix` and `ui_tile`.
- A targeted click (`click_button` / `click_cell` / `click_slot`) whose element is missing fails with `"no visible element labelled '<l>'"` (or `id '<id>'`). If the element is disabled, it fails with `"element '<id>' is disabled"`.

**C9. Invariants (Task 1).** `UIRunner.check_invariants(elements)` returns nil or an error string. It runs these checks in this order:
1. Well-formed: non-empty string `id` and `label`, a `kind` from C1, `rect.w > 0`, `rect.h > 0`, unique ids.
2. On screen: `0 <= x`, `x+w <= 1280`, `0 <= y`, `y+h <= 720`.
3. No overlap: no pair satisfies `UI.overlaps` (enabled or disabled).

Error format: `"invariant: '<idA>' overlaps '<idB>'"`, `"invariant: '<id>' off screen"`, `"invariant: duplicate id '<id>'"`, `"invariant: malformed element <n>: <why>"`. The spec runner appends `" at frame <n>"`.

**C10. Report format (Task 1).** Unit tests keep their existing `PASS  tests/x.lua` / `FAIL  tests/x.lua — err` lines. Each UI spec prints `PASS  tests/ui/x.lua :: <name>` or `FAIL  tests/ui/x.lua :: <name> — step <i> <serialised step> — <reason>`. If a file fails to load, it counts as one failure: `FAIL  tests/ui/x.lua — <err>`. The final line is `<passed>/<total> passed`, where total = unit files + specs. The process exits 1 if anything failed.

---

### Wave 1 (parallel) — `love . --headless` must be green at the end of this wave

- [x] **Task 1 — Headless UI spec runner** — `lua/headless/stubs.lua`, `lua/headless/ui_runner.lua` (new), `lua/headless/runner.lua`, `lua/core/scene_manager.lua`, `lua/core/ui.lua` (new), `tests/test_ui_runner.lua` (new). Depends on: none.
  - `lua/core/ui.lua`: implement C3 exactly.
  - `lua/headless/stubs.lua`: implement C4. Add explicit `graphics_stub.getWidth`/`getHeight` (today the catch-all returns a no-op, so `getWidth()` yields nil). Add `love.mouse`. Replace the `print`/`printf` no-ops with recorders. End the file with `return Stubs`. Keep every existing stub working.
  - `lua/core/scene_manager.lua`: add `SceneManager:is_idle()` (C5) only.
  - `lua/headless/ui_runner.lua`: module `UIRunner` with:
    - `UIRunner.run_spec(spec, opts)` returns `ok, err`. `opts.make_scene(sm)` optionally replaces `StartScene.new(sm)`, which unit tests use to inject fake scenes. Implements C7, C8 and C9. Stops at the first failing step. Wraps the whole spec in `pcall`, so a Lua error becomes a failure reason.
    - `UIRunner.run_file(path)` returns an array of `{ name, ok, err }`. It loads the file with `dofile` (do not use `love.filesystem.read`, which the stubs replace) and accepts a single spec or a list of specs (C7).
    - `UIRunner.check_invariants(elements)` (C9), exported so Task 7's unit test can reuse it.
    - A small `serialise(step)` for failure lines: Lua-literal style, keys sorted.
    - Require `game/progress` and `game/scenes/start_scene` lazily, inside `run_spec`.
  - `lua/headless/runner.lua`: in `runner.run(nil)`, after the `tests/*.lua` loop, discover `tests/ui/*.lua` (sorted, via `love.filesystem.getDirectoryItems("tests/ui")`; a missing or empty directory is fine) and run each through `UIRunner.run_file`. Print the C10 lines and the combined total, and exit with the combined code. In `runner.run(path)`, if `path` starts with `tests/ui/`, run it as a spec file (C10 lines, then `PASS`/`FAIL` exit code). Otherwise behave as today. Do not change `runner.setup`, `runner.tick` or `runner.fast_forward_until`.
  - `tests/test_ui_runner.lua`: unit-test the harness with **fake scenes** passed through `opts.make_scene`. A fake scene is a table with `on_enter`, `update`, `draw` (calling `love.graphics.print("HELLO")`), `mouse_pressed` that records calls, and a `ui_elements` you control. Cover:
    - `click_button` reaches the scene through `sm` at the rounded centre.
    - A disabled target fails.
    - An ambiguous label fails.
    - An unknown step key fails.
    - `assert_text` / `assert_no_text`.
    - `wait_until` timeout message.
    - `check_invariants` detects overlap, off-screen, duplicate id and malformed entries, and accepts edge-sharing rects.
    - The `UI.*` helpers.
    - `run_file` on a temp list-of-specs file is optional; if you do it, write it under `tests/ui_fixtures/`, not `tests/ui/`.
    
    Do not add any `tests/ui/*.lua` spec in this task. Real scenes have no registry yet.

- [x] **Task 2 — Worlds 4/5 and puzzle 21 data** — `game/puzzle_loader.lua`, `data/puzzles/21_fixed_player.lua`, `tests/test_worlds.lua` (new). Depends on: none.
  - `game/puzzle_loader.lua`: delete the second, duplicate `local WORLDS = {...}` block. Append `{ name = "Transforms", puzzles = { 17, 18, 19, 20 } }` and `{ name = "Fixed Pieces", puzzles = { 21, 22, 23 } }`. The design leaves the names open; these are the checklist's choice. No API change. The lock rule in `game/progress.lua` stays unchanged.
  - `data/puzzles/21_fixed_player.lua`: add `ops = {},` so the palette shows only its fixed ops plus tools (same as puzzles 22 and 23).
  - `tests/test_worlds.lua`: assert that every index `1..PuzzleLoader.count()` appears in exactly one world (reachability; this fails on master today). Assert `PuzzleLoader.load(21).ops` is an empty table. Assert that with `Progress.reset()` plus all puzzles in worlds 1-3 solved, world 4 is unlocked and world 5 is not. Reset progress at the end.
  - Do not edit `tests/test_world_select.lua` or `tests/test_progress.lua`. Both must still pass unchanged.

---

### Wave 2 (parallel, after Wave 1) — `love . --headless` must be green at the end of this wave

Each task touches a different scene file, so the four can merge independently. Use `UI.*` from `lua/core/ui.lua` (C3) for hit-testing, and delete each scene's local copy of the hit helper.

- [x] **Task 3 — Start scene registry** — `game/scenes/start_scene.lua`, `tests/test_start_scene.lua` (new), `tests/ui/05_start_screen.lua` (new). Depends on: Task 1.
  - Add `StartScene:ui_elements()` returning `start:play` then `start:unlock_all` (C2 rects; store the play rect in `on_enter` next to `_unlock_rect`).
  - `mouse_pressed`: `local e = UI.element_at(self:ui_elements(), mx, my)`. If `e` is `start:unlock_all`, call `_unlock_all()`. In every other case, including no element (click anywhere to play), call `_advance()`. Keyboard is unchanged.
  - Unit test: elements well-formed (use `require("lua/headless/ui_runner").check_invariants`). A click at Unlock All's centre unlocks everything (check `Progress.is_world_unlocked(2)`, then `Progress.reset()`). A click at (5, 5) advances. Construct with `runner.setup(function(_, sm) return StartScene.new(sm) end)` and read `ctx.sm.current`.
  - Spec `tests/ui/05_start_screen.lua` (list of two specs):
    - (a) `given.solved = {}`: `click_button "Play"`, then `assert_text "SELECT PUZZLE"`.
    - (b) `given.solved = {}`: `click_button "Unlock All"`, `press "right"`, `assert_text "WORLD 2: COMBOS"`.

- [x] **Task 4 — Level select registry, hover fix, specs 02 and 03** — `game/scenes/level_select_scene.lua`, `tests/test_level_select.lua` (new), `tests/ui/02_level_select_keyboard.lua` (new), `tests/ui/03_world_locking.lua` (new). Depends on: Tasks 1, 2.
  - Add `LevelSelectScene:ui_elements()`: `world:prev`, `world:next`, then one `puzzle:<index>` per row, in row order (C2). `selected = (i == self.selected)`.
  - Hover fix (design section 4): delete `_logical_mouse` and the body of `update()`, leaving an empty `update(_dt)`. Add `mouse_moved(x, y)`: if `UI.element_at` returns a `puzzle:*` element, set `self.selected` to that row. Delete local `_row_at` / `_hit` in favour of `UI`.
  - `mouse_pressed` (left button only): look up the element through the registry. For `world:prev` / `world:next`, call `_cycle_world(-1/+1)`. For `puzzle:<i>`, set `selected` to that row and call `_load_selected()`.
  - `draw`: use the registry's `selected` for row highlighting (iterate the elements, or use the same `i == self.selected` expression through a shared helper; either way, there is one source).
  - Unit test:
    - With the virtual cursor parked on row 3 via `require("lua/headless/stubs").set_mouse`, press `down`, then `scene:update(1/60)` 30 times, and selection stays 4.
    - `mouse_moved` onto row 2 selects 2.
    - A click on the row 1 centre switches to a `MatrixScene`.
    - A click on `world:next` with nothing solved stays on world 1.
  - `tests/ui/02_level_select_keyboard.lua`: exactly design section 6(b). Start with `press "return"`, then `hover_button "Sign Change"`, `press "down"`, `assert_button {id="puzzle:4", selected=true}`, `wait = 30`, the same assert, `press "up"` twice, `assert_button {id="puzzle:2", selected=true}`, `press "return"`, `assert_text "Flip It"`. `given.solved = {}`.
  - `tests/ui/03_world_locking.lua`: one file returning a list of two specs, per design section 6(c):
    - (a) `given.solved = {}`: `press "return"`, `press "right"`, `assert_text "WORLD 1: BASICS"`, `assert_no_text "WORLD 2"`.
    - (b) `given.solved = {1,2,3,4,5}`: `press "return"`, `press "right"`, `assert_text "WORLD 2: COMBOS"`, `click_button {id="puzzle:6"}`, `assert_text "Row Swap"`.

- [x] **Task 5 — Solution recap click targets** — `game/scenes/solution_recap_scene.lua`, `tests/test_recap_buttons.lua` (new). Depends on: Task 1.
  - Add `SolutionRecapScene:ui_elements()` with three buttons in the right panel, below the PIECES label:
    - `recap:next` "Next puzzle" `{x=850, y=600, w=150, h=44}`
    - `recap:replay` "Replay" `{x=1015, y=600, w=110, h=44}`
    - `recap:menu` "Menu" `{x=1140, y=600, w=110, h=44}`
    
    All are enabled.
  - Refactor the actions into `_next()`, `_replay()` and `_menu()`. Use them from `key_pressed` (Enter / R / Esc are unchanged) and from `mouse_pressed`. A left click on an element runs its action. **Any other click does nothing** (today any left click advances; the design calls for this change).
  - `draw`: remove **both** "[Enter] Next puzzle   [R] Replay   [Esc] Menu" `printf` calls (in `_draw_stats` and in `draw`). Draw the three buttons from `ui_elements()` (filled rounded rect plus centred label). You may draw a small key hint under each button, e.g. "[Enter]", "[R]", "[Esc]".
  - Unit test: build a recap scene as `tests/test_solution_recap.lua` does, but with a real `SceneManager` (`runner.setup`), so switches can be observed.
    - The elements pass `check_invariants`.
    - A click at the `recap:next` centre switches to a `MatrixScene` for puzzle `index % count + 1`.
    - A click at the `recap:menu` centre switches to `LevelSelectScene`.
    - A click at the `recap:replay` centre resets `_frame_idx` to 1.
    - A click at (400, 300) does not switch scenes.
  - Do not edit `tests/test_solution_recap.lua`.

- [x] **Task 6 — Matrix scene registry, single command-enabled function, registry hit-testing** — `game/scenes/matrix_scene.lua`, `tests/test_matrix_registry.lua` (new). Depends on: Task 1. Do **not** change the palette layout (Task 7 does that). Positions stay as today.
  - **Command state:** add `MatrixScene:_cmd_enabled(id)` with today's button rules:
    - `run`: `not self.running and self.status ~= "running" and self.status ~= "win"`
    - `step`: `not self.running and (status == nil or status == "running" or status == "no_pusher")`
    - `reset`: `self.sim ~= nil or self.status ~= nil`
    - `menu`: `true`
    
    Add `MatrixScene:_cmd_activate(id)`, holding the action bodies currently inline in `mouse_pressed` (around lines 1638-1663), including the `no_pusher` handling. `_draw_cmd_buttons` (around lines 1216-1225) and the click path both call `_cmd_enabled`. `key_pressed`: `r` does `if self:_cmd_enabled("run") then self:_cmd_activate("run") end`, `space` does the same for `step`, `backspace` the same for `reset`. Remove the old separate `r` guard (design section 2).
  - **Palette:** make `self._btn_rects` a dense **array** in layout order. Each entry is `{ id=, x=, y=, w=, h=, btn= }`, with ids from C2 (`palette:pusher`, `palette:<op>`, `palette:fixed:<op>`, `palette:drag`, `palette:erase`). Keep the field name and the `btn` subtable (with `.label`), because `tests/test_pusher_scene.lua` reads `pairs(scene._btn_rects)` and `r.btn.label`. Add `MatrixScene:_palette_is_selected(btn)`, holding the selection logic now inline in `draw_palette`. `draw_palette` uses `ipairs` and that helper.
  - **`MatrixScene:ui_elements()`**: build the list in C2 order:
    - palette entries (`selected` via `_palette_is_selected`, `enabled = true`)
    - commands (`enabled` via `_cmd_enabled`)
    - cells (rect from `cell_top_left(x, y)` with size `CELL_SIZE`, for `x = 1..self.grid.w` and `y = 1..self.grid.h`)
    - only if `self:_timeline_layout()` is non-nil: `tl:scroll_left`, `tl:scroll_right`, `tl:dec`, `tl:inc` (rects from the layout), then the slots from `L.rows[i].slots`, with id `slot:<letter>:<s>`
    
    Enabled rules for the timeline are in C2. Factor out the `can_left` / `can_right` computation from `draw_timeline` so that both draw and registry use it.
  - **`mouse_pressed`** dispatches through `local e = UI.element_at(self:ui_elements(), mx, my)`:
    - `cmd:*`: activate if enabled, then return.
    - `palette:*`: select (same semantics as today), then return.
    - `tl:*`: perform the dec/inc/scroll action if enabled (move the bodies out of `_timeline_click` into small helpers), then return.
    - kind `slot`: cycle the command if enabled (left forward, right back), then return.
    - kind `cell`: continue into the existing grid logic, which includes the `_expand_rects` check first, then right-click clear, drag pickup, param thirds and placement. Its behaviour must stay identical.
    - no element: return.
    
    Remove the `mx >= HUD_X` and `my >= PALETTE_Y` early branches; they become registry lookups. `_timeline_click` may be deleted or reduced to a thin wrapper. `_expand_rects` stays outside the registry (C2 exception).
  - **Query methods (C6):** add `ui_matrix()` (current_matrix if set, else input_matrix, returned as `.values` copied into plain rows) and `ui_tile(x, y)` (resolve a ref cell through `self.grid:is_ref` / `self.grid:get`).
  - Unit test (`runner.setup` with `MatrixScene.new(2)`, a small palette, so there is no overlap yet; do not assert invariants on puzzle 1, which overlaps until Task 7). Call `scene:draw()` once so that `_tl_top` exists. Cover:
    - Ids are unique and the order is stable across two calls.
    - Clicking `palette:pusher` at its `UI.centre` selects the pusher and it then reports `selected=true`.
    - Clicking `cmd:run` with status `"win"` does nothing.
    - `key_pressed("r")` with status `"win"` does nothing (new behaviour from design section 2).
    - `backspace` with `sim == nil and status == nil` changes nothing.
    - The `cmd:reset` element's `enabled` equals `_cmd_enabled("reset")`.
    - Slot elements exist after a pusher is placed, and clicking `slot:A:1` cycles it to `"up"`.
    - `ui_tile` / `ui_matrix` return the expected shapes.
  - All existing tests (`tests/test_pusher_scene.lua`, `tests/test_drag_ops.lua`, `tests/test_row_op_delete_resize.lua`, etc.) must pass **without edits**. They call `mouse_pressed` directly at cell, slot and `inc` coordinates, and that must still work.

---

### Wave 3 (after Wave 2) — `love . --headless` must be green at the end of this wave

- [x] **Task 7 — Bottom-bar layout: fixed zones, shrink, paging, hint move** — `game/scenes/matrix_scene.lua`, `tests/test_palette_layout.lua` (new). Depends on: Task 6 (palette is the ordered `_btn_rects` array with C2 ids; `ui_elements()` exists). Also uses `UIRunner.check_invariants` from Task 1.
  - **Zones** (design section 5). The command zone is unchanged: Run/Step/Reset/Menu at `x = 622 + (i-1)*47`, `w=42`, `h=48`, `y = PALETTE_Y + 6`. The palette zone is `x = 10` to `PALETTE_RIGHT = 610` (command zone left edge 622 minus a 12px gap). Nothing in the bar may cross x=820.
  - **Pinned tools.** `P` sits at the left edge of the palette zone (x=10, w=48). `[X]` sits at the right edge, ending at 610 (x=562), with `Mv` immediately left of it (x=506). All are 48x48. The middle band runs from 78 (`10 + 48 + 20`) to 486 (`506 - 20`). Separators are the 20px margins.
  - **Middle band contents.** Allowed op buttons in `PALETTE_BUTTONS` order, then the fixed `!` buttons in `puzzle.fixed_ops` order.
    - If all of them fit at width 48 with step 56, lay them out from x=78 at that size.
    - Otherwise, shrink evenly: width `w = floor((band - (n-1)*4) / n)` with gap 4, as long as `w >= MIN_BTN_W = 30` (fits the longest 4-character label such as `<>R!` at font size 11).
    - Otherwise, page. Reserve `palette:page_prev` (label `<<`) at the band's left edge and `palette:page_next` (`>>`) at its right edge, each 20x48 with a 4px gap. Fill the remaining width with as many `MIN_BTN_W`-wide buttons (gap 4) as fit per page. Show page `self._palette_page`, which starts at 1, is reset to 1 in `load_puzzle` / `_build_palette`, and is clamped. `page_prev` is enabled only when page > 1, `page_next` only when page < pages.
    - Use constants only, no font metrics (C4).
  - `_btn_rects` contains **only visible** buttons, in left-to-right order. Page 1 shows the first ops in `PALETTE_BUTTONS` order, so `tests/test_pusher_scene.lua`'s "puzzle 1 offers T and -I" check still passes unchanged. Clicking a page arrow changes the page and rebuilds `_btn_rects`. The palette selection is kept even if the selected op is on another page.
  - The `ui_elements()` palette section adds the page arrows in their positional order (`page_prev` before the middle ops, `page_next` after them). `mouse_pressed` handles `palette:page_prev` / `palette:page_next` (if enabled). `draw_palette` draws the arrows (dimmed when disabled).
  - **Hint move.** Remove the "Puzzle %d/%d  [Esc] Menu" `printf` from `draw_palette`. In `MatrixScene:draw()`, after `self.hud:draw(...)`, draw `string.format("Puzzle %d/%d", self.puzzle_index, PuzzleLoader.count())` with `font_key` at `(HUD_X + 8, 12)`, left-aligned. Do not edit `game/hud.lua`.
  - Unit test `tests/test_palette_layout.lua`:
    - For every puzzle `1..PuzzleLoader.count()`: `MatrixScene.new(i)` via `runner.setup`, call `scene:draw()` once, and assert `check_invariants(scene:ui_elements()) == nil`. Also assert every element whose id starts with `palette:` or `cmd:` has `rect.x + rect.w <= 820`, and that `palette:pusher`, `palette:drag`, `palette:erase` are present.
    - For puzzle 1 (all 18 ops): page arrows exist. `page_prev` is disabled on page 1. Clicking the `page_next` centre via `scene:mouse_pressed` shows a different set of `palette:<op>` ids. Taking all pages together, all 18 op ids appear exactly once. A selected op stays selected after paging.
    - For puzzle 21 (after Task 2): no `palette:<op>` buttons, but `palette:fixed:swap_rows` and `palette:fixed:negate` are present.
  - The existing tests must pass without edits.

---

### Wave 4 (parallel, after Wave 3) — `love . --headless` must be green at the end of this wave

- [x] **Task 8 — End-to-end specs 01 and 04** — `tests/ui/01_solve_puzzle_1.lua` (new), `tests/ui/04_sweep_all_puzzles.lua` (new). Depends on: Tasks 1-7. Fix only spec files. If a spec exposes a game bug, **stop and report it** (the fix goes back through Phase 3). Do not work around it in the spec, and do not edit game code or pre-existing tests.
  - `01_solve_puzzle_1.lua`: the design section 1 example exactly. `given.solved = {}`, then:
    1. `press "return"`, `assert_text "WORLD 1: BASICS"`
    2. `click_button "Identity Check"`, `click_button "P"`, `click_cell {1,5}`
    3. `click_slot {pusher=1, slots={1,2,3,4,5,6,7,8}, times=2}`
    4. `click_button "Run"`, `wait_until {text="SOLVED!", max_frames=3000}`
    5. `assert_button {label="Next puzzle", enabled=true}`, `click_button "Next puzzle"`, `assert_text "Flip It"`
    
    Optionally add `assert_tile {x=1, y=5, kind="pusher"}` after placing the pusher.
  - `04_sweep_all_puzzles.lua`: `given.solved = "all"`. Build the steps with loops over `require("game/puzzle_loader")`:
    - At build time, compute the union of `PuzzleLoader.world(w).puzzles` indices over `w = 1..world_count()`. If any index in `1..count()` is missing, `error("unreachable puzzle <i>")`, which fails the file load (design section 6(d), reachability).
    - Steps: `press "return"`. Then for each world w and each puzzle p in it:
      1. Press `"right"` (w-1) times. `Esc` from a puzzle returns to a fresh level select on world 1, so the presses are needed for every puzzle.
      2. `assert_button {id="puzzle:"..p.index, visible=true}`
      3. `click_button {id="puzzle:"..p.index}`
      4. `wait = 5` (draw, timeline and invariants run on that puzzle's palette)
      5. `assert_text p.name`
      6. `press "escape"`
    - Also, once per world (before its first puzzle), `assert_text "WORLD <w>: <NAME upper>"`.

- [x] **Task 9 — Testing guide** — `docs/testing.md` (new). Depends on: Tasks 1-7 (document what was built; read the final `lua/headless/ui_runner.lua` and scenes). Documentation only. Contents:
  - how to run (`love . --headless`, and a single spec with `love . --headless tests/ui/<file>.lua`)
  - spec file format (single spec or list of specs, `given`)
  - the full step vocabulary table (C7)
  - frame loop, settling and input semantics (C8)
  - the element registry contract and the id table (C1/C2), including the `_expand_rects` exception as a known gap against rule 3
  - the three invariants (C9)
  - the failure report format (C10)
  - the **process rule** from design section 7, verbatim
  
  Do not edit `README.md` (verification owns it).

---

### For verification

- Pre-existing test files (`tests/test_*.lua` that existed before this feature) should have **no edits**. No task is authorised to change an existing assertion. Any diff to them is a regression flag under process rule 2.
- Intentional behaviour changes, each with a new test:
  - `r`/`space`/`backspace` follow `_cmd_enabled` (Task 6; e.g. `r` no longer works after win, `backspace` with nothing to reset is a no-op)
  - recap clicks outside its buttons do nothing (Task 5)
  - level-select hover only on mouse movement (Task 4)
  - palette paging on puzzle 1 (Task 7)
  - the "Puzzle N/23" hint moved to the HUD top-left and lost "[Esc] Menu" (Task 7)
  - puzzle 21 offers no editable ops (Task 2)
- Expected README updates:
  - a TESTING section linking `docs/testing.md`
  - the puzzle count as 23 (not "16 puzzles")
  - the five worlds: Basics 1-5, Combos 6-11, Advanced 12-16, Transforms 17-20, Fixed Pieces 21-23
  - the recap uses clickable Next puzzle / Replay / Menu buttons
  - the palette pages with `<<` / `>>` when ops don't fit
  - level-select hover follows mouse movement only
- Known gap to keep listed in `docs/testing.md`: the resize strips (`_expand_rects`) are not registry elements.
