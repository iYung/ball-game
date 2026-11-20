# UI Tests: Headless Player-Level Specs

## Goal

**Why.** We keep shipping regressions even though 13 unit test files pass in CI (`love . --headless`, `.github/workflows/ci.yml`). A review of the git history found four causes:

1. **Tests skip the input and layout layer.** Tests call private scene internals directly (`scene:_place_tile_at` 26 times, `scene._drag_tile`, `scene:_resize_tile`, `scene._run_frames`, and others). They never send key presses or mouse clicks, never hit-test, and never call `draw()`, which is where layout state such as `_tl_top` gets set. Two regressions live on master today, both in this untested layer:
   - **Level select hover overrides the keyboard.** `LevelSelectScene:update()` (`game/scenes/level_select_scene.lua:96-102`) sets `self.selected` to whichever row is under the mouse on every frame. Up/Down moves the selection for one frame and then the stationary cursor takes it back. That code also calls `love.graphics.getWidth()` and `love.mouse.getX()`, which crash under the headless stubs (`getWidth` returns nil and `love.mouse` does not exist). That crash is why no test drives start → level select → puzzle.
   - **The bottom bar overlaps on puzzle 1.** Puzzle 1 has no `ops` field, so `_build_palette` shows every op. The palette then has P + 18 ops + Mv + [X], laid out at a 56px step from x=10, so it runs to about x=1218. That covers the Run/Step/Reset/Menu buttons at x=622-810, crosses the HUD boundary at x=820, and crosses the "Puzzle 1/23 [Esc] Menu" hint text. Command buttons are hit-tested first, so the palette buttons under them do nothing. Palette buttons past x=820 also do nothing, because `mouse_pressed` sends every click with `mx >= HUD_X` to the timeline. Three features caused this together: all ops on puzzle 1, the 9 new ops from #22, and the command buttons from #28. Each one passed its own tests.
2. **Fixes go into the tests instead of the game.** b46a1b3 (puzzle count 16 → 23) and 925c1db (pusher cell 2,6 → 1,6) changed only tests. Tests that encode incidental facts break on every feature, get edited until they pass, and the same habit lets real regressions through.
3. **Tests check the author's intent, not what the player sees.** The agent that builds a feature writes its tests in a fresh context. Verification only requires green tests. Nobody plays the game end to end, so collisions between features go unnoticed.
4. (Minor) CI does not exercise the web build. Two fixes (e3e902b, cd26c04) were for files missing from the web zip.

**What.** Add a headless **UI spec runner**. Specs are declarative Lua tables in `tests/ui/*.lua`. Each one drives the real game the way a player does: key presses, and clicks at on-screen positions sent through `SceneManager`. Every frame runs `update` and then `draw`. Specs can assert on what was drawn (text), which buttons are visible or enabled, and the matrix and grid state. On every frame the runner also checks **global layout invariants** automatically, with no per-feature test needed. Every scene publishes a **UI element registry** (`scene:ui_elements()`), and the scene's own hit-testing and enabled-state logic read from that same registry, so the tests and the game cannot disagree about where a button is or whether it works. This feature also fixes the regressions above so the new specs start green, and adds a documented process rule so that later features are covered by real-input specs.

## Affected files

Runner / harness
- `lua/headless/runner.lua`: discover and run `tests/ui/*.lua` after `tests/*.lua` in the same process, with the same PASS/FAIL lines and a combined total and exit code. A single-file run (`love . --headless tests/ui/foo.lua`) is treated as a spec.
- `lua/headless/ui_runner.lua` (new): loads a spec, resets progress, builds a fresh `SceneManager` with `StartScene`, runs the steps, checks invariants, and reports failures.
- `lua/headless/stubs.lua`: add `love.graphics.getWidth/getHeight` (1280/720), `love.mouse.getX/getY/getPosition` (the runner's virtual cursor) and `love.mouse.isDown` (false). Make the `print`/`printf` stubs record their string argument into a per-frame text log that the UI runner can read and clear.

Scenes (registry + hit-testing through it)
- `game/scenes/start_scene.lua`
- `game/scenes/level_select_scene.lua` (also the hover fix)
- `game/scenes/matrix_scene.lua` (also the bottom-bar layout fix, and a single shared function for command-button enabled state)
- `game/scenes/solution_recap_scene.lua` (Next puzzle / Replay / Menu become real elements)
- `game/hud.lua`: only if the "Puzzle N/23" hint moves into the HUD (see What changes)

Possibly a shared helper
- `lua/core/ui.lua` (new, optional): `hit(rect, x, y)`, `element_at(elements, x, y)`, `centre(rect)`. These hit-test helpers are currently copied in three scenes. The checklist agent decides whether it is worth adding.

Specs (new)
- `tests/ui/01_solve_puzzle_1.lua`
- `tests/ui/02_level_select_keyboard.lua`
- `tests/ui/03_world_locking.lua`
- `tests/ui/04_sweep_all_puzzles.lua`

Data
- `game/puzzle_loader.lua`: add World 4 (puzzles 17-20) and World 5 (21-23), and remove the duplicate `WORLDS` table.
- `data/puzzles/21_fixed_player.lua`: add `ops = {}`.

Docs
- `docs/testing.md` (new): how to write UI specs, the full step vocabulary, the invariants, and the process rule.
- `README.md` (expected update, done by the verification phase, not a checklist task): a TESTING pointer to `docs/testing.md`; the puzzle count (23, not "16 puzzles") and the five-world list; the recap now uses click targets; the palette pages; level-select hover follows mouse movement only.

## What changes

### 1. Spec format (`tests/ui/*.lua`)

Each file returns one table. Because a spec is Lua, a file may build its `steps` with loops (the sweep spec does). It must still evaluate to plain data before the runner starts.

```lua
return {
  name  = "solve puzzle 1 from title",
  given = { solved = {} },          -- puzzle indices marked solved before the spec starts
  steps = {
    { press = "return" },
    { assert_text = "WORLD 1: BASICS" },
    { click_button = "Identity Check" },      -- level-select row, matched by label
    { click_button = "P" },                   -- palette: pusher
    { click_cell = {1, 5} },                  -- grid cell x=1, y=5
    { click_slot = { pusher = 1, slots = {1,2,3,4,5,6,7,8}, times = 2 } },  -- ". -> ^ -> >"
    { click_button = "Run" },
    { wait_until = { text = "SOLVED!", max_frames = 3000 } },
    { assert_button = { label = "Next puzzle", enabled = true } },
    { click_button = "Next puzzle" },
    { assert_text = "Flip It" },
  },
}
```

I checked this example against the code. Puzzle 1 has its source at (2,5), a 2x2 matrix, and the sink at (10,5). A pusher at (1,5) that pushes right 7 times moves the matrix to x=9..10, which touches the sink, and input equals target. The default timeline length is 8, so all 8 slots get `>`, the same as the existing tests. Left-clicking a slot cycles `. ^ > v <`, so 2 clicks give `>`. "SOLVED!" is drawn by the recap scene. The HUD's win label is "WIN!".

**Step vocabulary.** These are the only keys a step may have. An unknown key fails the spec.

| Step | Meaning |
|---|---|
| `press = "<key>"` | `SceneManager:key_pressed(key)`, using the same key names as `love.keypressed`. |
| `click = {x, y}` / `right_click = {x, y}` | Escape hatch: a raw click at logical coordinates. |
| `click_button = "<label>"` or `{id = "<id>"}` / `right_click_button` | Click the centre of the matching visible element. Matching on a label fails if the label is ambiguous (puzzles 4 and 6 are both called "Row Swap"), so use `id` in that case. |
| `click_cell = {x, y [, part = "left"/"centre"/"right"]}` / `right_click_cell` | Click a grid cell. `part` targets the -1 and +1 thirds of a parameter cell. |
| `click_slot = {pusher = n or "A", slots = {...}, times = k}` / `right_click_slot` | Click each listed timeline slot `k` times (default 1). |
| `move_mouse = {x, y}` or `hover_button = "<label>"` | Move the virtual cursor and fire `SceneManager:mouse_moved`. Needed for the hover regression spec. |
| `wait = n` | Advance n frames. |
| `wait_until = { text = "...", matrix = {{...}}, max_frames = n }` | Advance frames until the condition holds. Fail if it still does not hold after `max_frames`. |
| `assert_text = "..."` / `assert_no_text = "..."` | Checks the strings drawn in the most recent frame, as a plain substring match. |
| `assert_button = { label or id, visible = bool, enabled = bool, selected = bool }` | `visible = false` means the element is not in the registry. Fields you leave out are not checked. |
| `assert_matrix = {{...}}` | The matrix values the puzzle scene shows now: the travelling matrix if a run exists, otherwise the input matrix at the source. |
| `assert_tile = { x, y, kind = "...", op = "...", dir = "..." }` | The tile at a grid cell. `kind = nil` asserts that the cell is empty. |

There are no assertions on scene names or statuses. This was a deliberate decision: assert what the player can see.

**Input semantics.** Every click does what LÖVE does: move the cursor to the point and fire `mouse_moved`, then fire `mouse_pressed` and `mouse_released` at the same point, all through `SceneManager`. The runner never calls a scene handler or a private method directly. Element centres are rounded to whole pixels. A click whose target is missing or disabled fails the step. To test that a disabled button does nothing, use the `click = {x,y}` escape hatch.

**Frame loop and settling.** Each frame runs `sm:update(1/60)`, then clears the text log, then `sm:draw()`. Before each input step and each assert step, the runner advances frames until the `SceneManager` fade is idle (bounded, about 60 frames). This means clicks and asserts target the scene that is on screen. During a fade, `draw()` shows the old scene while input already goes to the new one. A player waits out the fade, and so does the runner.

**`given`.** `given.solved = {1,2,3,4,5}` resets `Progress` and then marks each listed puzzle solved before the spec starts. `given.solved = "all"` means unlock all. Every spec starts with `Progress.reset()` and a fresh `SceneManager` on `StartScene`, so specs do not depend on run order. The `Progress` module is a singleton, so this reset is required.

**Failure report.** One line per failing spec: the file, the spec `name`, the 1-based step index, the step serialised as Lua, and the reason. Examples of reasons: "no visible element labelled 'Run'", "wait_until exceeded 3000 frames", "invariant: 'Run' overlaps palette 'xC' at frame 412". The spec stops at its first failure, and the remaining specs still run.

### 2. UI element registry: `scene:ui_elements()`

Each scene returns an ordered list. All coordinates are in logical 1280x720 space.

```lua
{ id = "cmd:run", label = "Run", kind = "button", rect = {x=, y=, w=, h=}, enabled = true, selected = false }
```

`kind` is one of `"button"`, `"cell"` or `"slot"`. The `kind` field and the optional `selected` flag extend the agreed shape. `selected` is how `assert_button { selected = true }` checks the keyboard highlight on level select without reading scene internals.

| Scene | Elements (id → label) |
|---|---|
| Start | `start:play` → "Play" (a new rect around the "[Enter] or click to play" prompt; the start screen has no Play button today), `start:unlock_all` → "Unlock All" (the current `_unlock_rect`). The start screen keeps click-anywhere-to-play: a click outside Unlock All still advances. |
| Level select | `puzzle:<index>` → puzzle name (one per row; `selected` marks the highlighted row), `world:prev` → "<", `world:next` → ">" |
| Puzzle (matrix) | Palette: `palette:pusher` "P", `palette:<op>` (op label, e.g. "xR"), `palette:fixed:<op>` ("xR!"), `palette:drag` "Mv", `palette:erase` "[X]", and page arrows if paging is used. Commands: `cmd:run` "Run", `cmd:step` "Step", `cmd:reset` "Reset", `cmd:menu` "Menu". Grid: `cell:<x>,<y>` (kind `cell`). Timeline: `slot:<A>:<s>` (kind `slot`, visible window only), `tl:dec` "-", `tl:inc` "+", `tl:scroll_left` "<", `tl:scroll_right` ">" |
| Solution recap | `recap:next` "Next puzzle", `recap:replay` "Replay", `recap:menu` "Menu". The current "[Enter] Next puzzle   [R] Replay   [Esc] Menu" hint text, which is drawn twice today, is replaced by these clickable elements. The keyboard shortcuts stay. A click outside these buttons does nothing (today any left click advances). |

**One source of truth.** In each scene:
- `mouse_pressed` dispatches button clicks by looking up the element under the cursor in `ui_elements()`.
- Cell and slot elements come from the same layout helpers the scene's hit-testing already uses (`cell_top_left`/`screen_to_cell`, `_timeline_layout`), so their rects cannot drift.
- `draw` uses each element's `enabled` and `selected` values for its styling.
- In `matrix_scene.lua`, the command-button enabled logic, which is currently written out twice (in `_draw_cmd_buttons` around lines 1216-1225 and in `mouse_pressed` around 1613-1625), becomes one function. Draw, click and the registry all use it. The keyboard shortcuts read that same state: `r` acts only when Run is enabled, `space` only when Step is enabled, and `backspace` only when Reset is enabled. Today `r` has its own guard, which allows a run after fail, stuck, timeout or no_pusher, while the button allows any status except running or win. After this change the two cannot differ.

The palette's `_btn_rects` is currently a mixed table (integer keys plus `"fixed_<op>"` string keys) that is walked with `pairs`, so its order is not deterministic. The registry must have a stable order.

Timeline elements exist only after the HUD has drawn once, because `_tl_top` is set during `draw()`. The runner draws every frame, so this matches the real game.

### 3. Global layout invariants (checked automatically every frame)

After every frame's `draw`, the runner checks the current scene's `ui_elements()`:
1. **No overlap.** No two elements' rects intersect with positive area, whether they are enabled or disabled. A disabled button that overlaps another still looks broken. Rects that only share an edge are fine.
2. **On screen.** Every element is fully inside `0 ≤ x, x+w ≤ 1280, 0 ≤ y, y+h ≤ 720`.
3. **Well-formed.** Every element has a non-empty `id` and a non-empty `label` (cells and slots may use their id as the label), `w > 0`, `h > 0`, and ids are unique within a frame.

The first violation fails the spec with both element ids and the frame number. Specs cannot turn these checks off. They would have caught the puzzle-1 palette overlap with no test written for that feature.

### 4. Fix: level select hover vs keyboard

- Hover changes `selected` only when the mouse actually moves, in `LevelSelectScene:mouse_moved(x, y)`, which `SceneManager` and `main.lua` already forward. If a move lands on a row, that row becomes selected. A stationary cursor never overrides Up/Down.
- `update()` no longer polls `love.mouse` or `love.graphics.getWidth`, and the `_logical_mouse` helper goes away. This also removes the headless crash, which happens because the graphics stub's catch-all makes `getWidth` return nil and because `love.mouse` does not exist. The stubs still gain `getWidth`/`getHeight`/`love.mouse` so that any other code that polls them works headlessly.
- Clicking a row behaves as before: it selects the row and opens the puzzle.

### 5. Fix: bottom bar layout in the puzzle scene

Confirmed direction:
- **Fixed zones.** The bottom bar (y=660-720, x=0-820) gets a fixed **command zone** at its right end for Run/Step/Reset/Menu, where they sit today. The **palette zone** gets the remaining band from x=10 to the command zone's left edge minus a gap. Nothing in the bar may cross x=820 (HUD_X).
- **Pinned tools.** P, Mv and [X] are always visible at the edges of the palette zone. Op buttons, including fixed `!` variants, fill the middle.
- **Fit, then page.** When the op buttons do not fit at the normal size (48px wide, 56px step), they shrink evenly down to a minimum width that still fits the longest label (about 30px). If they still do not fit, the middle shows one page of op buttons with `palette:page_prev` / `palette:page_next` arrow elements. Once puzzle 21 gets `ops = {}` (section 8), the worst case is puzzle 1, with 18 ops plus the 3 tools.
- **Hint text moves.** The "Puzzle N/23 [Esc] Menu" text, which is drawn on top of the command zone today, moves out of the bar, for example into the HUD under the puzzle name, or is dropped because the Menu button now exists. The layout invariant does not check drawn text, so this one is a judgement call rather than something a spec catches.
- The result must pass invariant #1 and #2 on all 23 puzzles, which the sweep spec checks.

### 6. Starter specs

- **(a) `01_solve_puzzle_1.lua`**: title → Enter → level select ("WORLD 1: BASICS") → click "Identity Check" → P → cell (1,5) → 8 slots set to `>` → Run → `wait_until` "SOLVED!" → assert "Next puzzle" is enabled → click it → assert "Flip It" (puzzle 2's name in the HUD).
- **(b) `02_level_select_keyboard.lua`**: the regression spec for the hover bug. Enter → `hover_button` "Sign Change" (row 3, so the cursor is parked on a row) → press Down → assert `puzzle:4` is `selected` → wait 30 frames → assert it is still selected → Up, Up → assert `puzzle:2` is selected → Enter → assert "Flip It". This uses ids because of the duplicate "Row Swap" name.
- **(c) `03_world_locking.lua`**: two specs or two phases, each with its own `given` reset. With `given.solved = {}`: Enter → Right → assert "WORLD 1: BASICS" and `assert_no_text` "WORLD 2", so locked worlds are skipped. With `given.solved = {1,2,3,4,5}`: Enter → Right → assert "WORLD 2: COMBOS" → click `puzzle:6` → assert its name is drawn. If a file returns a list of specs, that is how one file holds both. The checklist agent may instead use two files.
- **(d) `04_sweep_all_puzzles.lua`**: `given.solved = "all"`. For every world and every row: click the row, wait a few frames so that draw, timeline and invariants run on that puzzle's palette, assert the puzzle name is drawn, press Esc back to level select, and move to the next world with ">". Its steps are generated with a loop. It also checks **reachability**: every index `1..PuzzleLoader.count()` must appear as a `puzzle:<i>` element in some world. This fails on master today, because `WORLDS` only lists puzzles 1-16, so puzzles 17-23 cannot be reached from level select. That is a third live regression: #22 and #27 added puzzles without adding them to worlds. Section 8 fixes it, and the sweep then covers all 23 puzzles.

### 8. Fix: worlds and puzzle 21 data

- `PuzzleLoader` gets **World 4 (puzzles 17-20)** and **World 5 (puzzles 21-23)**. The existing lock rule applies unchanged: a world unlocks once every puzzle in all earlier worlds is solved. The duplicate `WORLDS` table is removed. The level-select dots and arrow cycling already handle any number of worlds.
- **Puzzle 21** (`21_fixed_player.lua`) gets `ops = {}`, so its palette shows only its fixed ops plus the tools, the same as puzzles 22 and 23. Before this, it offered all 18 editable ops by accident.
- The README's puzzle count and world list are updated by the verification phase, as listed under Affected files.

### 7. Process rule (documentation only, in `docs/testing.md`)

> **Testing rules for every feature**
> 1. Every new feature adds or extends a `tests/ui/` spec that drives the feature through real input (keys and clicks via the registry). Calling private scene methods does not count as UI coverage.
> 2. In the verification phase, **any edit to a pre-existing test or spec is flagged as a potential regression**, not accepted silently. The verifier must state why the old expectation was wrong. If the game broke the test, the fix goes back to Phase 3 against the game, not the test.
> 3. Every interactive element must appear in its scene's `ui_elements()`, and hit-testing must go through the registry. Elements that are not in the registry cannot be tested and count as a bug.
> 4. Specs assert what the player sees (drawn text, buttons, board state). They do not assert incidental facts such as exact puzzle counts or cell coordinates of internal state, unless that fact is the feature.

The README gets a short TESTING section that links to this file. Under the NFF rules, the verification agent adds it.

## What stays the same

- The existing unit tests in `tests/*.lua` and their helpers (`runner.setup`, `runner.tick`, `runner.fast_forward_until`, `HeadlessInput`) stay unchanged. They keep passing and run first. Migrating them to specs is out of scope.
- CI is unchanged: it still runs one `love . --headless` command, which now also runs the specs. There is no windowed mode, no screenshots, and no new dependencies.
- Controls stay the same: every keyboard shortcut and every mouse action works as it does now, with these exceptions: hover selection, recap clicks (they must land on a recap button), palette paging, and `r`/`space` now following the button enabled state. The start screen keeps click-anywhere-to-play.
- Game rules, the pusher simulation, matrix math, puzzle data (except the new worlds and `ops = {}` on puzzle 21), progress persistence, the lock rule, and the web build script stay the same. CI gets no web-build step in this feature.
- `main.lua`'s screen-to-logical coordinate mapping is unchanged. The runner works in logical coordinates and calls `SceneManager` directly, the same layer `main.lua` calls.
- The `--visual` mode stays as it is.

## Open questions

1. **Web build smoke test in CI** (motivation item 4). This is out of scope for this feature and stays open as a follow-up. A possible approach: a CI job runs `scripts/build_web.sh`'s zip step, then checks that every `require`d module and every loaded data file is inside `game.love`. Running `love game.love --headless` would not work, because `tests/` is not in the zip.
2. **Global CLAUDE.md.** This design keeps the process rule in `docs/testing.md` and does not edit `~/.claude/CLAUDE.md`. The user may want to copy rule 1 (a UI spec for every feature) and rule 2 (flag edits to existing tests) into the Phase 3 and Phase 4 text there.

**Follow-ups (out of scope):**
- `solution_recap_scene.lua`'s `OP_SYMBOLS` covers only the original 9 ops, so the recap draws "?" for flip, rotate, abs and the column ops.
- The README says `← →` switches to the previous/next puzzle in-game, but `MatrixScene:key_pressed` has no left/right handling.
- Puzzles 4 and 6 are both named "Row Swap". Specs avoid the problem by clicking by `id`. Renaming one is a content decision.
