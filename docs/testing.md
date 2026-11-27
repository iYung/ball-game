# Testing guide

This project has two kinds of tests. Both run headlessly in one process with one command.

| Kind | Location | What it does |
|---|---|---|
| Unit tests | `tests/*.lua` | Plain Lua scripts that `assert`. They often call scene internals directly through `runner.setup` / `runner.tick` / `HeadlessInput` (`lua/headless/runner.lua`). |
| UI specs | `tests/ui/*.lua` | Declarative tables that drive the **real game like a player does**: key presses and clicks at on-screen positions, sent through `SceneManager`, with `update` and `draw` on every frame. Layout invariants are checked on every frame automatically. |

**Why UI specs exist.** Regressions kept shipping while every unit test passed. Unit tests skipped the input and layout layer: they called private methods such as `scene:_place_tile_at`, never sent clicks, never hit-tested, and never called `draw()`. Real bugs lived in exactly that layer. For example, hovering on level select overrode the keyboard, and on puzzle 1 the palette ran under the Run/Step/Reset/Menu buttons, so those palette buttons did nothing. Each feature passed its own tests, and nobody played the game end to end. UI specs close that gap. Read the process rules below before you ship anything.

There is no third-party test framework (no busted, no luaunit). Both kinds run on the project's own harness in `lua/headless/`: `runner.lua` runs every `tests/test_*.lua`, then every spec in `tests/ui/`, and prints a single total.

### Which kind to write

| You are testing… | Write |
|---|---|
| Anything the player can click or press: a new button, key, screen or flow | A UI spec (required, see rule 1) |
| Pure logic: matrix math, the pusher sim, op semantics, progress, puzzle data | A unit test |
| Logic with many edge cases behind a UI feature | Both: a spec for the path the player takes, unit tests for the edge cases |
| A specific layout bug you just fixed | A unit test that pins the exact rects, if you want a sharper failure message than the spec's invariant error |

### What these tests cannot catch

Both kinds run against stubbed LÖVE (`lua/headless/stubs.lua`), so neither one sees:

- **Real rendering.** Nothing is drawn. The font stub reports every string as 120px wide, so text that overflows its box, wrong colors and missing sprites all pass. Lay out with constants, not `font:getWidth`, and check visual changes by running the game.
- **Saves.** The `love.filesystem` stubs don't write anything, so the save file is never read or written.
- **The web build.** `web.yml` builds the web version and deploys a PR preview but never loads or plays it. Open the preview link on the PR.

For those, run the game (`love .`) or open the PR preview.

---

## Process rules (mandatory)

> **Testing rules for every feature**
> 1. Every new feature adds or extends a `tests/ui/` spec that drives the feature through real input (keys and clicks via the registry). Calling private scene methods does not count as UI coverage.
> 2. In the verification phase, **any edit to a pre-existing test or spec is flagged as a potential regression**, not accepted silently. The verifier must state why the old expectation was wrong. If the game broke the test, the fix goes back to Phase 3 against the game, not the test.
> 3. Every interactive element must appear in its scene's `ui_elements()`, and hit-testing must go through the registry. Elements that are not in the registry cannot be tested and count as a bug.
> 4. Specs assert what the player sees (drawn text, buttons, board state). They do not assert incidental facts such as exact puzzle counts or cell coordinates of internal state, unless that fact is the feature.

In practice:
- **Feature authors (Phase 3):** add a spec or extend one in `tests/ui/`. A new clickable thing also needs a `ui_elements()` entry (see [Adding `ui_elements()` to a scene](#adding-ui_elements-to-a-scene)).
- **Verifiers (Phase 4):** run `git diff master -- tests/` and look for changed lines in files that already existed, especially changed assertions. List each one in the verification report with the reason the old expectation was wrong. If the test was right and the game broke it, send the fix back to Phase 3.

---

## Running tests

```sh
love . --headless                                      # all unit tests, then all UI specs
love . --headless tests/ui/02_level_select_keyboard.lua  # one UI spec file (every spec in it)
love . --headless tests/test_ui_runner.lua             # one unit test file
love . --headless --coverage                           # all tests + per-file coverage report for lua/game/
```

- Any path that starts with `tests/ui/` runs as a spec file. Any other path runs as a unit test.
- You cannot run a single spec out of a multi-spec file by name. Put the spec in its own file temporarily, or comment out its siblings while you iterate (do not commit that).
- The exit code is 0 when everything passes and 1 otherwise. CI (`.github/workflows/ci.yml`) runs `love . --headless --coverage`, so a drop below 100 % line coverage of `lua/game/` blocks the build.
- On a machine without a display you may see `error: XDG_RUNTIME_DIR is invalid...`. It is harmless.
- `love . --visual <unit test>` is unchanged and applies to unit tests only.

### Output

```
PASS  tests/test_basics.lua
FAIL  tests/test_foo.lua — tests/test_foo.lua:12: assertion failed!
PASS  tests/ui/03_world_locking.lua :: locked worlds are skipped
FAIL  tests/ui/01_solve_puzzle_1.lua :: solve puzzle 1 from title — step 7 {click_button = "Run"} — element 'cmd:run' is disabled
FAIL  tests/ui/99_broken.lua — tests/ui/99_broken.lua:3: '}' expected near 'steps'
41/43 passed
```

- Each unit file and each **spec** counts once toward the total. A spec file that fails to load counts as one failure.
- A single-file run prints the per-spec lines and then a bare `PASS` or `FAIL`.

### Measuring coverage

`love . --headless --coverage` runs the full suite and then prints a per-file line-coverage report for `lua/game/`. Each row shows the number of lines the hook observed executing versus the estimated executable-line count (non-blank, non-comment, non-structural-keyword lines). Files at 0 % were never `require`d during the run.

`lua/core/` is excluded intentionally — its files are mostly rendering infrastructure (`shader.lua`, `sprite.lua`, `spriteset.lua`, `fonts.lua`) stubbed out in headless mode and cannot be meaningfully measured.

The tool uses `debug.sethook` from the standard Lua `debug` library — no third-party tools required. CI enforces 100 % line coverage: `love . --headless --coverage` exits 1 if any file in `lua/game/` drops below 100 %, blocking the build.

---

## Spec file format

A spec file returns **one spec** or a **list of specs**:

```lua
-- one spec
return { name = "...", given = { solved = {} }, steps = { ... } }

-- several specs; each gets its own Progress reset, given and fresh SceneManager
return {
  { name = "locked worlds are skipped",   given = { solved = {} },              steps = { ... } },
  { name = "world 2 unlocks after world 1", given = { solved = {1,2,3,4,5} }, steps = { ... } },
}
```

| Field | Meaning |
|---|---|
| `name` | Shown in the report. Defaults to `spec <n>`. |
| `given.solved` | `{1, 2, 3}` marks the puzzles at those positions (not ids) solved before the spec starts. `"all"` calls `Progress.unlock_all()`. Omit it or use `{}` to start with nothing solved. |
| `given.cutscenes_unseen` | By default **all** cutscenes are marked as already seen so that navigating between worlds does not unexpectedly trigger cutscenes in unrelated specs. Pass `{2}` (or any list of world numbers) to leave those worlds' cutscenes unseen, allowing them to trigger. Only needed in specs that explicitly test cutscene flow (see `tests/ui/06_cutscene.lua`). |
| `steps` | An array of steps. Each step is a table with **exactly one** key from the vocabulary below. |

A spec is Lua, so you may build `steps` with loops (for example a sweep over every puzzle). The file must still evaluate to plain data.

**Every spec starts the same way:** `Progress.reset()`, then `given` is applied, then a new `SceneManager` (1280x720) is switched to `StartScene`, the virtual cursor goes to (0, 0), and one frame runs. Specs never depend on run order.

### Annotated example

```lua
-- tests/ui/02_level_select_keyboard.lua
-- Regression: a cursor resting over a row must not override Up/Down.
return {
    name  = "level select keyboard nav with cursor parked on a row",
    given = { solved = {} },                              -- fresh progress: only World 1 unlocked
    steps = {
        { press = "return" },                             -- title screen -> level select
        { hover_button = "Sharp Left" },                  -- park the cursor on row 3 (fires mouse_moved)
        { press = "down" },                               -- keyboard moves the highlight to row 4
        { assert_button = { id = "puzzle:4", selected = true } },  -- assert by id
        { wait = 30 },                                    -- 30 frames with a stationary cursor...
        { assert_button = { id = "puzzle:4", selected = true } },  -- ...must not steal the highlight back
        { press = "up" },
        { press = "up" },
        { assert_button = { id = "puzzle:2", selected = true } },
        { press = "return" },                             -- open puzzle 2
        { assert_text = "Flip It" },                      -- its name is drawn in the HUD
    },
}
```

A full play-through looks like this (puzzle 1: a pusher at (1,5) given one "right" command at tick 1 solves it):

```lua
{ click_button = { id = "puzzle:1" } },
{ click_button = "P" },                                             -- palette: pusher tool
{ click_cell = {1, 5} },                                            -- place it
{ drag = { from = { id = "chip:right" }, to = { slot = {1, 1} } } },    -- "right" chip at tick 1; commands persist
{ click_button = "Run" },
{ wait_until = { text = "WIN!", max_frames = 3000 } },
{ click_button = "Continue" },                                      -- recap scene
{ assert_text = "SOLVED!" },
{ click_button = "Next puzzle" },
{ assert_text = "Flip It" },
```

See the files in `tests/ui/` for more: `01_solve_puzzle_1.lua`, `02_level_select_keyboard.lua`, `03_world_locking.lua`, `04_sweep_all_puzzles.lua` (generated steps, every puzzle), `05_start_screen.lua`, `06_cutscene.lua` (CutsceneScene end-to-end), `07_drag_drop.lua` (Mv drag tool), and `08_matrix_scene_ops.lua` (op tiles: editing by thirds, fixed and locked tiles, moving and erasing). `13_solve_converted.lua` wins puzzles through real input and `14_editor_ops.lua` covers op tiles in the editor. `11_anim_timing.lua` checks the matrix shows pre-op values while sliding into an op (`assert_matrix` mid-run). `17_editor_fixed_ops.lua` covers `fixed_ops` and `ops = {}` through the editor's Paste, Test and Copy, and `18_folder_worlds.lua` covers world tabs, unlocking and cutscenes read from the world folders. For two sources and matrix ops, see `19_two_sources_run.lua` (merge and failure banners), `20_two_cell_tiles.lua` (placing, turning with `t`, moving and erasing, with `mouse_down` / `mouse_up`), `21_recap_merge.lua`, `22_editor_two_sources.lua` `23_two_source_world.lua` (solves every puzzle of that world) and `24_two_source_fixes.lua` (palette drags onto a two-cell tile; a lone **SRC2** through Copy, Paste and Test). `26_mv_fixes.lua` covers moving a pusher with **Mv** and using **Mv** around a run.

---

## Finding shipped puzzles

A level can be added anywhere (see [Adding a level](#adding-a-level)), which shifts the positions of everything after it. Tests and specs must not hardcode the position of a shipped puzzle, a world number or the puzzle count. `given.solved`, `given.cutscenes_unseen`, `puzzle:<n>` and `world:<n>` still take positions and world numbers, so look them up by id with `require("tests/support/shipped")`:

| Helper | Returns |
|---|---|
| `S.puzzle("flip")` / `S.world("combos")` | position of a puzzle id / number of a world id |
| `S.row("flip")` / `S.tab("combos")` | level select selectors (`puzzle:<n>`, `world:<n>`) |
| `S.name_after("flip", 1)` | name of the puzzle that many places after it |
| `S.before("combos")` | positions of all puzzles in earlier worlds, for `given.solved` |
| `S.arrows("combos")` | the Right presses from the first world to that one (every world on the way must be unlocked) |
| `S.steps({ ... })` | the step list with nested step lists (such as `S.arrows`) spliced in |

The short examples in this guide use literal positions for readability.

---

## Adding a level

Put one file in a world folder, `data/puzzles/<NN>_<world>/<NN>_<id>.lua`; the editor's Copy output works unchanged. The folder and naming rules are in the [README](../README.md#adding-levels). No test needs editing. `tests/test_shipped_puzzles.lua` fails on a puzzle outside a world folder, a puzzle without a name, more than 10 puzzles in a world, a cutscene that does not load, or any file in `data/cutscenes/` other than `world_0.lua`; `tests/test_puzzle_data.lua` rejects unsupported ops.

---

## Step vocabulary

A step has exactly one of these keys. Any other key fails with `unknown step key '<k>'`, and a step with two keys fails with `step must have exactly one key`.

A **selector** is either a label string (`"Run"`) or a table `{ id = "cmd:run" }`. `assert_button` also accepts `{ label = "Run", ... }`. A label matches any element kind. If a label matches more than one element, the step fails with `ambiguous label '<l>' (<n> matches)`. Use `id` in that case.

| Step | Meaning |
|---|---|
| `press = "<key>"` | `sm:key_pressed(key)`. Uses LÖVE key names: `"return"`, `"escape"`, `"space"`, `"backspace"`, `"up"`, `"down"`, `"left"`, `"right"`, `"r"`, ... |
| `click = {x, y}` / `right_click = {x, y}` | A raw click at logical coordinates. This is the escape hatch, for example to check that clicking a disabled button does nothing, or to click empty space. |
| `click_button = sel` / `right_click_button = sel` | Click the centre of the matching element. It fails if the element is missing or disabled. |
| `click_cell = {x, y [, part = "left" \| "centre" \| "right"]}` / `right_click_cell` | Click grid cell `cell:<x>,<y>`. `part` picks the -1 third (`x + w/6`), the centre (the default; turns an edge tile) or the +1 third (`x + 5w/6`) of an op tile. |
| `drag = { from = <selector>, to = <selector> }` | Press at the centre of `from`, move to `to`, release there (frames in between). Selectors may also be `{ cell = {x, y} }` or `{ slot = {lane, tick} }`. Use it to drag ops onto cells and chips onto timeline slots; the runner **never auto-scrolls** the timeline: click `tl:scroll_right` yourself. |
| `move_mouse = {x, y}` | Move the virtual cursor and fire `sm:mouse_moved`. |
| `hover_button = sel` | Move to the element's centre. Disabled elements are allowed. |
| `mouse_down = sel` / `mouse_up = sel` | Move to the element's centre and press (or release) button 1, then run one frame. Other steps, such as `press` or `right_click_cell`, can run while the button is held. Both fail on a missing or disabled element. |
| `wait = n` | Run n frames. |
| `wait_until = { text = "...", matrix = {{...}}, matrices = {...}, max_frames = n }` | Run frames until all given conditions hold. `max_frames` defaults to 600. On timeout: `wait_until exceeded <n> frames`. It does **not** settle a fade first. |
| `assert_text = "..."` / `assert_no_text = "..."` | A plain substring match against every string drawn by `print`/`printf` in the most recent frame. |
| `assert_button = { <selector fields>, visible = bool, enabled = bool, selected = bool }` | `visible = false` asserts that the element is absent from the registry. Fields you leave out are not checked. A nil `selected` counts as false. |
| `assert_matrix = {{...}}` | The matrix the puzzle scene shows now: the travelling matrix during or after a run, otherwise the input matrix. Rows of numbers, compared exactly. With two matrices this is the primary one (source 1's, or the merge result). |
| `assert_matrices = { { x = , y = , values = {{...}} }, ... }` | Every matrix the puzzle scene shows, primary first, compared by count and order. `values` is required; `x` / `y` (grid cell of the top-left) are compared only when given. Idle, these are the inputs at their sources. |
| `assert_tile = { x, y, kind = ..., op = ..., dir = ..., edge = ..., scalar = ..., facing = ..., index = ... }` | The tile at a grid cell. A ref cell of a multi-cell tile reports its anchor tile. Leaving out `kind` asserts that the cell is **empty**. Only the fields you give are compared. `facing` is a two-cell op's orientation; `index` is 1 or 2 on a source tile when there are two sources. |
| `assert_slot = { lane = n, tick = n, pusher = n, cmd = "..." }` | The command in a timeline slot (`pusher` 1 = A). `empty = true` asserts that the slot is empty. |
| `set_clipboard = "..."` | Put text on the stubbed clipboard (for the editor's Paste). |
| `text_input = "..."` | `sm:text_input(ch)`, for typing into a text field. |

`assert_matrix` and `wait_until.matrix` need a scene that has `ui_matrix()` (`MatrixScene`), `assert_matrices` and `wait_until.matrices` need `ui_matrices()` (`MatrixScene`), `assert_slot` needs `ui_slot()` (`MatrixScene`), and `assert_tile` needs `ui_tile()` (`MatrixScene` and `EditorScene`). Otherwise they fail, for example with `scene has no matrix` or `scene has no tiles`.

There are deliberately no assertions on scene names or internal status. Assert what the player can see.

---

## Frame loop, settling and input semantics

- **One frame** is `sm:update(1/60)`, then the text log is cleared, then `sm:draw()`, then the invariants are checked on `sm.current:ui_elements()`. Because `draw()` runs every frame, layout state that is set during draw (such as the level select's tab rects) exists exactly as it does in the real game.
- **Settle.** Before every input step and every assert step (but not `wait` or `wait_until`), the runner runs frames until the `SceneManager` fade is idle, for at most 60 frames. Otherwise the step fails with `fade did not finish`. A player waits out the fade, and so does the runner. Without the settle you would click on the scene being drawn while input already goes to the new scene.
- **After every input step**, exactly one frame runs so that the result is drawn before the next assert.
- **A click** at (x, y) with button b (1 = left, 2 = right) is `Stubs.set_mouse(x, y)`, `sm:mouse_moved(x, y)`, `sm:mouse_pressed(x, y, b)`, `sm:mouse_released(x, y, b)`. This is what LÖVE does. A move is `set_mouse` plus `mouse_moved`.
- Element centres are rounded to whole pixels (`UI.centre`).
- The runner never calls a scene handler or private method directly. Its only scene calls are the read-only `ui_elements()`, `ui_matrix()`, `ui_matrices()`, `ui_tile()` and `ui_slot()`. Everything else goes through `SceneManager`.
- Headless stubs (`lua/headless/stubs.lua`): `love.graphics.getWidth/getHeight` return 1280/720. `love.mouse.getX/getY/getPosition` return the virtual cursor, and `isDown` returns false. `love.filesystem.getInfo` reports anything `io.open` can open as a file, directories included, so `PuzzleLoader` (and tests that fake the folder layout) rely on `getDirectoryItems` only; call `PuzzleLoader.rescan()` after stubbing it and again after restoring it. Fonts are stubs that report a width of 120 for any text, so **never use `font:getWidth()` for layout**. Use constants.

---

## The UI element registry

Every scene that has clickable things implements `scene:ui_elements()`. The scene's own `mouse_pressed` dispatches through it (`UI.element_at(self:ui_elements(), mx, my)`), and draw uses its `enabled`/`selected` for styling. Specs, the game and the invariants therefore all read the same rects, so they cannot disagree about where a button is or whether it works.

### Entry shape

```lua
{ id = "cmd:run", label = "Run", kind = "button",
  rect = { x = 1120, y = 624, w = 72, h = 40 }, enabled = true, selected = false }
```

- `kind` is `"button"`, `"cell"` or `"slot"`.
- `enabled` is always a boolean. Include `selected` only when the element has a highlight state.
- Coordinates are logical 1280x720. Rects are half-open: `x <= px < x+w`, `y <= py < y+h`.
- Return a **fresh, deterministically ordered** array each call. Build it with `ipairs` over arrays, never with `pairs`. The call must have no side effects.
- A scene without `ui_elements` counts as having no elements.

Helpers in `lua/core/ui.lua` (this module requires no game modules):

```lua
local UI = require("lua/core/ui")
UI.hit(rect, x, y)            -- half-open point test
UI.element_at(elements, x, y) -- first element (list order) containing the point, or nil
UI.find(elements, id)         -- element by id, or nil
UI.centre(rect)               -- x, y rounded to whole pixels
UI.overlaps(a, b)             -- positive-area intersection (shared edges do not count)
```

### Element ids by scene (as built)

| Scene | id | label | kind | notes |
|---|---|---|---|---|
| Start | `start:play` | `Play` | button | rect around the "[Enter] or click to play" prompt. A click anywhere outside the other buttons also plays. |
| Start | `start:unlock_all` | `Unlock All` | button | |
| Start | `start:editor` | `Editor` | button | |
| Level select | `world:<n>` | world name, or `[?]` when locked | button | one tab per world; locked tabs are disabled. `selected` marks the current world. Rects are computed in `draw`. Listed first. |
| Level select | `puzzle:<index>` | puzzle name | button | one per row of the current world. `selected` marks the highlighted row. Hover changes the selection only on mouse **movement**. |
| Matrix | `palette:pusher` | `P` | button | `selected` when this tool is active |
| Matrix | `palette:<op>` | `xk` `xk^` `+k` `+k^` `-k` `-k^` `T` `R90` `FLh` `FLv`; `M+` / `Mx` plus the tool's arrow (e.g. `M+>`, `Mxv`) | button | `<op>` is the op **name** from `lua/game/ops.lua`, e.g. `palette:edge_add`, `palette:matrix_mul`. A matrix op's label changes when the tool turns, so click it by id; clicking it while selected turns it |
| Matrix | `palette:fixed:<op>` | preset + `!` (e.g. `x-1!`, `x3>!`, `FLv!`, `M+>!`) | button | |
| Matrix | `palette:scroll_up` / `palette:scroll_down` | `^` / `v` | button | only when the ops column overflows (no shipped puzzle does). Each click scrolls one row; `enabled` is false at either end. Only on-screen palette buttons are in the registry. |
| Matrix | `palette:drag` / `palette:erase` | `Mv` / `[X]` | button | erase is `selected` when nothing is selected |
| Matrix | `cmd:run` `cmd:reset` `cmd:menu` `cmd:continue` | `Run` `Reset` `Menu` `Continue` | button | `enabled` comes from `MatrixScene:_cmd_enabled(id)`, the same function the `r` / `backspace` / `return` keys use |
| Matrix | `cell:<x>,<y>` | same as id | cell | every grid cell, `x = 1..grid.w`, `y = 1..grid.h` |
| Matrix | `psel:<L>` | `A`, `B`, ... | button | one per placed pusher |
| Matrix | `chip:<cmd>` | `^` `v` `<` `>` `.` `CLR` | button | `cmd` is `up`, `down`, `left`, `right`, `stop` or `clear` |
| Matrix | `tl:scroll_left` `tl:scroll_right` | `<` `>` | button | enabled when the timeline can scroll that way. The `<` / `>` chips share these labels, so click by id. |
| Matrix | `slot:<lane>:<tick>` | same as id | slot | lane 1-4, tick is the real tick number. Only slots in the visible window are listed. `enabled = not running`. |
| Editor | `editor:pal:<tool>` | `SRC` `SRC2` `SNK` `GAP` `P`, op labels (matrix ops with arrow), `Erase` | button | `<tool>` is `source`, `source2`, `sink`, `gap`, `pusher`, an op name or `erase` |
| Editor | `editor:back` `editor:test` `editor:copy` `editor:paste` | `Back` `Test` `Copy` `Paste` | button | |
| Editor | `editor:name`, `editor:allow:<op>` | name text / op label | button | the ten one-cell ops |
| Editor | `editor:allow_matrix:<op>` | `M+` `Mx` | button | `matrix_add`, `matrix_mul` |
| Editor | `editor:input_sel:<n>` | `#1` `#2` | button | which input the spinners and `editor:input_cell:*` edit; `selected` marks it |
| Editor | `editor:input_rows_dec` etc. | `-` `+` | button | also `_rows_inc`, `_cols_dec`, `_cols_inc`, and the same for `target` |
| Editor | `editor:input_cell:<r>,<c>`, `editor:target_cell:<r>,<c>` | value | cell | |
| Editor | `cell:<x>,<y>` | same as id | cell | every grid cell |
| Recap | `recap:next` `recap:replay` `recap:menu` | `Next puzzle` `Replay` `Menu` | button | always enabled. Clicks outside them do nothing. Enter / R / Esc still work. |

Matrix order: palette (`scroll_up`, the visible items out of P, ops, Mv, [X], fixed ops as laid out, then `scroll_down`), then commands, then cells (y-major), then the bottom bar (`psel:`, `chip:`, timeline arrows, slots). An open settings overlay replaces all of these with its own `settings:*` elements.

**Ambiguous labels to watch for:** `<`, `>` and `v` appear on more than one element, so click those by id. Use ids for cells and slots anyway, since their label equals their id.

---

## Invariants (checked every frame, cannot be disabled)

`UIRunner.check_invariants(elements)` runs these checks in order and reports the first violation:

1. **Well-formed:** a non-empty string `id` and `label`, `kind` in `button`/`cell`/`slot`, a numeric `rect` with `w > 0` and `h > 0`, and unique ids.
2. **On screen:** `0 <= x`, `x + w <= 1280`, `0 <= y`, `y + h <= 720`.
3. **No overlap:** no two rects intersect with positive area, whether enabled or disabled. Shared edges are fine.

Messages (the runner appends ` at frame <n>`):

```
invariant: malformed element <n>: <why>
invariant: duplicate id '<id>'
invariant: '<id>' off screen
invariant: '<idA>' overlaps '<idB>'
```

These checks run on every frame of every spec. A layout collision between two features therefore fails some spec without anyone writing a test for it. `04_sweep_all_puzzles.lua` opens every puzzle so that every palette layout gets checked.

---

## Reading failures

```
FAIL  tests/ui/<file>.lua :: <spec name> — step <i> <step serialised as Lua> — <reason>
```

- `<i>` is the 1-based index into `steps`. The step is printed with sorted keys, e.g. `{click_cell = {1, 5}}`.
- The spec stops at its first failure. Other specs still run.
- `setup — <reason>` means the failure happened before step 1 (bad `given`, crash on the first frame, an invariant on the start screen).
- A Lua error inside the game shows up as the reason, with its file and line.

| Reason | Usual cause |
|---|---|
| `no visible element labelled 'X'` / `no visible element id 'X'` | Wrong scene (check the previous step), the element is not registered, a typo, or a slot outside the visible timeline window. |
| `element '<id>' is disabled` | The game state does not allow it yet (e.g. Run after a win). Use `click` if you are testing that a disabled button does nothing. |
| `ambiguous label 'X' (n matches)` | Switch to `{ id = ... }`. |
| `text 'X' not drawn` / `text 'X' was drawn` | Text is matched per frame. A typo, or the text is drawn on a different frame or scene. |
| `wait_until exceeded N frames` | The condition never became true. Raise `max_frames` only if the run is genuinely long. |
| `fade did not finish` | A scene transition is stuck, or something keeps switching scenes. |
| `matrix is {...}, expected {...}` | Board logic or wrong setup steps. |
| `tile at x,y ...` | Placement failed (wrong tool selected, locked cell, cell occupied). |
| `invariant: ... at frame N` | A real layout bug. Fix the layout, not the spec. |
| `scene has no matrix` / `scene has no tiles` | Matrix assert used outside the puzzle scene. |

---

## Adding `ui_elements()` to a scene

1. **Keep layout rects in one place.** Compute them in `new`/`load` (or in `draw` if they depend on drawn state) and store them on `self`. Use constants, not font metrics.
2. **Implement the registry** with a fresh, ordered array:

   ```lua
   local UI = require("lua/core/ui")

   function MyScene:ui_elements()
       local out = {}
       for _, b in ipairs(self._buttons) do          -- ipairs, never pairs
           out[#out + 1] = {
               id = "my:" .. b.key, label = b.label, kind = "button",
               rect = { x = b.x, y = b.y, w = b.w, h = b.h },   -- copy, do not share
               enabled = self:_can(b.key),                       -- one function shared with draw and keys
               selected = (b.key == self._current) or nil,       -- include only if it has a highlight state
           }
       end
       return out
   end
   ```

3. **Route input through it:**

   ```lua
   function MyScene:mouse_pressed(mx, my, btn)
       local e = UI.element_at(self:ui_elements(), mx, my)
       if not (e and e.enabled) then return end
       if e.id == "my:ok" then self:_ok() end
   end
   ```

4. **Draw from the same state.** Style each button from its element's `enabled`/`selected`. Keyboard shortcuts should check the same enabled function the registry uses.
5. **Pick ids** as `<scene>:<thing>` and keep them stable. Specs depend on them. Labels are the text the player sees.
6. **Write a spec** in `tests/ui/NN_<feature>.lua` that reaches the scene through real input from the title screen and clicks the new elements. Run `love . --headless tests/ui/NN_<feature>.lua`, then the full suite.
7. If the scene shows a board, `ui_matrix()` / `ui_matrices()` / `ui_tile(x, y)` (read-only) enable the matrix and tile asserts. See `MatrixScene`.

## Writing a unit test

A unit test is a plain Lua script in `tests/test_<thing>.lua`. Any uncaught error fails the file. That includes a failed `assert`, so give every `assert` a message. Printing `PASS: <case>` lines is a convention, not a requirement.

```lua
local Progress = require("lua/game/progress")
Progress.reset()                          -- module state is shared across files; reset it
Progress.mark_solved(1)
assert(Progress.is_solved(1), "puzzle 1 solved after mark_solved")
print("PASS: mark_solved")
```

To test a scene, build it through the runner so it gets a real `SceneManager` and `HeadlessInput`:

```lua
local runner = require("lua/headless/runner")
local ctx = runner.setup(function(input, sm) return require("lua/game/scenes/matrix_scene").new(1, sm) end)
runner.tick(ctx.input, ctx.sm, 10)        -- 10 frames of update (dt 1/60)
local scene = ctx.sm.current
```

- `HeadlessInput` (`lua/headless/input.lua`) scripts actions: `press(action)` fires for one frame, and `hold`/`release` keep an action down.
- `runner.fast_forward_until(ctx, condition_fn, elapsed, cap)` ticks until the condition holds.
- Prefer the scene's public input methods (`key_pressed`, `mouse_pressed`, `mouse_moved`) and `ui_elements()` over private `_methods`. Calling private methods is fine for logic, but it does not count as UI coverage.
- `love . --visual tests/test_<thing>.lua` runs the same test in a real window and renders every frame, so you can watch what it does. It is a debugging aid only; CI never uses it, and it does not work for UI specs (pass a `tests/ui/` path and you get an error message instead of a hang).

## Unit-testing the runner itself

`tests/test_ui_runner.lua` tests the runner with fake scenes through `UIRunner.run_spec(spec, { make_scene = function(sm) return scene end })`. Use the same hook if you need to test a scene in isolation. Prefer real specs from the title screen for feature coverage.
