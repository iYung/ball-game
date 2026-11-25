## Folder Worlds Checklist

Design: `docs/design/folder-worlds.md`. Read it, `CLAUDE.md` and `docs/testing.md` first.

### Ground rules for every task agent

- All agents share one working tree (`/tmp/claude-wt-713ab0` or wherever this file lives). Touch only the files your task names. Do not commit, stash, reset or check out anything.
- Waves run in order. Tasks inside one wave touch disjoint files and may run in parallel.
- While other tasks in your wave are still running, run only your own test files (`love . --headless <path>`). The wave ends with one full `love . --headless --coverage` run, which must be green with 100% line coverage of `lua/game/`. The full run takes several minutes, so allow at least a 10 minute timeout or run it in the background.
- The only pre-existing tests that may be edited are `tests/test_def_parser.lua` (A), `tests/test_progress_migration.lua` (B), `tests/test_puzzle_data.lua` and `tests/test_world_select.lua` (D), and the position-pinned tests in Task G, and only as described. Any other old test or spec that fails means the change is wrong: fix the game.
- New tests (B, C, F) find shipped puzzles by id, never by a literal position: loop over `1..count()` comparing `PuzzleLoader.id(n)`. Positions written in the task text below mean "the puzzle at that position today". Tests of the frozen save-conversion tables are the exception: compare the ids they produce.
- A test that stubs `love.filesystem` or reloads a module must restore everything, even on failure (use `pcall`, then `assert(ok, err)`).
- Mark your item `[x]` when done (edit only your own line).

### Interfaces (shared by all tasks)

`PuzzleLoader` (`require("lua/game/puzzle_loader")`). `n` is a puzzle position (1..count, flattened world order), `w` a world number (1..world_count).

| Function | Returns |
|---|---|
| `count()` | integer |
| `load(n)` | the puzzle file's table. Errors as today: `PuzzleLoader.load: index %s out of range (1–%d)` and `PuzzleLoader.load: could not load '%s': %s` |
| `world_count()` | integer |
| `world(w)` | `{ name = string, puzzles = { { index = n, name = string }, ... } }`. Errors as today: `PuzzleLoader.world: index %s out of range (1–%d)` |
| `world_indices(w)` | new. Fresh array `{ n, n+1, ... }` of the world's positions, without loading any puzzle file. Same out-of-range error as `world` |
| `id(n)` | new. Puzzle id string, or `nil` for any value that is not a valid position (0, -1, 99, ...). Never errors |
| `path(n)` | new. e.g. `"data/puzzles/01_basics/01_identity.lua"`, or `nil`. Never errors |
| `world_id(w)` | new. World id string, or `nil` out of range. Never errors |
| `cutscene_path(w)` | new. `0` returns `"data/cutscenes/world_0.lua"`; a valid world with `cutscene.lua` returns `"data/puzzles/<folder>/cutscene.lua"`; everything else `nil`. Never errors |
| `rescan()` | new. Drops the cached scan so the next call reads the folders again (for tests) |

`Progress` keeps its public signatures. `mark_solved(n)` / `is_solved(n)` take positions; `is_cutscene_seen(w)` / `mark_cutscene_seen(w)` take world numbers, `0` for the intro. Ids are only the internal and on-disk form (`lua/headless/ui_runner.lua` and existing tests pass numbers).

### Wave 1

- [x] Task A: loader, file move and cutscene lookup (one atomic change) — `data/puzzles/**`, `data/cutscenes/world_{2,3}.lua`, `lua/game/puzzle_loader.lua`, `lua/game/scenes/cutscene_scene.lua`, `lua/game/scenes/level_select_scene.lua`, `tests/test_def_parser.lua`, new `tests/test_folder_loader.lua`
  1. `git mv` without changing file contents: puzzles 01-05 to `data/puzzles/01_basics/`, 06-11 to `data/puzzles/02_combos/`, 12-15 to `data/puzzles/03_advanced/`, 16-18 to `data/puzzles/04_transforms/`, 19-21 to `data/puzzles/05_fixed_pieces/`; `data/cutscenes/world_2.lua` to `data/puzzles/02_combos/cutscene.lua`; `world_3.lua` to `data/puzzles/03_advanced/cutscene.lua`. `world_0.lua` stays. (`git mv` stages the rename; that is fine, do not commit.)
  2. `puzzle_loader.lua`: delete `PUZZLES` and `WORLDS`. Scan lazily on first use with `love.filesystem.getDirectoryItems`, cache the result, and implement the interface table above. Assign the cache only after a scan finishes, so a duplicate error is raised again on the next call.
     - Detect worlds with `getDirectoryItems` only, **not** `getInfo`: the headless `getInfo` stub reports directories as files, and some tests stub it to return nil. For each entry of `data/puzzles`, list `data/puzzles/<entry>`; the puzzle files are the names ending `.lua` other than `cutscene.lua`. No puzzle files means no world (this covers empty folders, plain files and loose puzzles). The cutscene exists if `cutscene.lua` is in that listing.
     - The scan must never call `love.filesystem.load` (existing tests stub it and expect `load(1)` to report `could not load`).
     - Ordering, for folders and files: strip `.lua` from files, then match `^(%d+)_(.+)$`. Prefixed entries come first, by `tonumber(prefix)`, ties by the stripped name and then the raw entry name. Unprefixed entries follow, alphabetically. Never rely on the order `getDirectoryItems` returns.
     - Id = stripped name without prefix (the whole stripped name if unprefixed). World name = world id with `_` replaced by space and the first letter of each word upper-cased.
     - Puzzle ids must be unique across all worlds, world ids across all worlds (separate namespaces). Errors: `PuzzleLoader: duplicate puzzle id '<id>': '<path1>' and '<path2>'` and the same with `duplicate world id` and the two folder paths.
     - `world(w)` keeps the `"Puzzle " .. n` fallback for a puzzle with no `name`.
  3. `cutscene_scene.lua` `on_enter`: take the path from `PuzzleLoader.cutscene_path(self._world_num)`; use `local chunk, err = nil, nil` plus a call only when the path is non-nil (or `path and love.filesystem.load(path)`), so a nil path falls into the existing "switch to next_scene" branch. `CutsceneScene.new(world_num, next_scene, scene_manager)` is unchanged and must not scan. `tests/test_cutscene.lua` and `tests/test_cutscene_scene.lua` stay unchanged (they use worlds 99, 1 and 2).
  4. `level_select_scene.lua` `_switch_world`: replace the `cs_path` format and `getInfo` check with `PuzzleLoader.cutscene_path(self._world)` being non-nil. Keep the `self._world ~= 1` condition and everything else.
  5. `tests/test_def_parser.lua`: in the "Every shipped puzzle" block only, drop the flat `getDirectoryItems("data/puzzles")` listing and filename-number matching; use `local path = PuzzleLoader.path(i)`. Keep the assertions.
  6. `tests/test_folder_loader.lua`: stub `love.filesystem.getDirectoryItems` and `love.filesystem.load` with an in-memory tree, call `PuzzleLoader.rescan()` before, and restore plus `rescan()` after. Cover: numeric order (`2_` before `10_`), gaps in numbering, unprefixed entries last and alphabetical, equal numbers by name, world naming (`05_fixed_pieces` is "Fixed Pieces"), empty folder / plain file / loose puzzle ignored, non-`.lua` files ignored, `cutscene.lua` not a puzzle, a folder holding only `cutscene.lua` is no world, `id`/`path`/`world_id`/`cutscene_path`/`world_indices` including `0` and out of range, missing name fallback, both duplicate errors name both paths.

### Wave 2 (needs Task A)

- [x] Task B: saves by id and new unlock rule — `lua/game/progress.lua`, `tests/test_progress_migration.lua`, new `tests/test_progress_ids.lua`
  - State is keyed by id. Puzzle key = `PuzzleLoader.id(n) or n`. World key = `0` if `w == 0`, else `PuzzleLoader.world_id(w) or w`. The numeric fallback keeps `mark_solved(99)` reading back as solved (required by the unchanged `tests/test_progress.lua`) but numeric puzzle keys are **never written** to disk (this includes `0`, which the recap marks after an editor Test win). Numeric cutscene keys other than `0` are never written either.
  - Save format: `SAVE_VERSION = 3`, exactly `return {version=3,solved={"flip","identity"},cutscenes={0,"combos"}}\n`. Ids written with `%q`, solved sorted alphabetically, cutscenes `0` first then ids alphabetically.
  - Load, version 3: keep every string in `solved` (including ids with no matching file, which must survive the next write); in `cutscenes` keep `0` and strings; ignore other types.
  - Load, version 2 and unversioned: only numbers count. Unversioned `solved` goes through `V1_TO_V2` first. Then map through two constant tables that must never change: puzzles 1..21 = `identity, flip, negate, swap, scale, row_swap, double_flip, combo, uturn, set_row, rotate_gap, negate_swap, flip_scale, elimination, triple, col_ops, flips, double_negative, fixed_player, fixed_puzzle, locked_scale`; worlds 1..5 = `basics, combos, advanced, transforms, fixed_pieces`. Cutscene `0` stays `0`. Unmapped numbers are dropped. Conversion must not call the loader. Loading must not write the file. The plain-array format `{1,2,3}` keeps working.
  - `is_world_unlocked(w)`: true if `w == 1`; or every puzzle in worlds `1..w-1` is solved; or any puzzle in worlds `w..world_count()` is solved. Use `PuzzleLoader.world_indices` (not `world`, which loads files and this runs every frame).
  - `unlock_world`, `unlock_all`, `reset` keep their behaviour on the new keys (`unlock_world(w)` still clears the seen flag of world `w + 1`).
  - `tests/test_progress_migration.lua`: change only the "written format" and following round-trip expectations to version 3. For the existing input `{solved={16,23},cutscenes={2}}` plus `mark_solved(3)` the text is `return {version=3,solved={"locked_scale","negate","triple"},cutscenes={"combos"}}\n`. Update the adjacent print/comment wording to match. All other cases (including the `version=2` ones) stay.
  - `tests/test_progress_ids.lua` (fake save file, same `with_save` pattern as the migration test): v3 load and round trip with `0` and ids; unknown ids kept on rewrite; wrong-typed v3 entries ignored; v2 cutscenes `{0,2,5,9}` convert and `9` is dropped; numeric fallback keys not written; a saved id follows the puzzle when its position changes (stub the loader's directory listing, `rescan()`, restore); unlock rule (nothing solved; only puzzle 12 solved opens worlds 2 and 3 but not 4; all earlier solved; a new unsolved puzzle in world 1 does not lock a world with a solve in it or later).
  - `tests/test_progress.lua` stays unchanged and passes.

- [x] Task C: editor keeps `fixed_ops` and an empty `ops` list — `lua/game/scenes/editor_scene.lua`, new `tests/test_editor_fixed_ops.lua`, new `tests/ui/17_editor_fixed_ops.lua`
  - `new` and `_load_def`: hold `self._fixed_ops` (nil or a copied array) and `self._no_ops` (boolean). A new editor has neither.
  - `validate_ops`: if `def.fixed_ops` is present it must be a table, and each entry a string or a table, checked with `Ops.validate(op, params)`. A bad entry rejects the paste with the `Ops.validate` message (e.g. `Unsupported op: abs`); a non-table `fixed_ops` gives `Invalid fixed_ops`. The editor is left unchanged.
  - Normalise on load: a string stays a string; a table becomes `{ op = ... }`, plus `params = Ops.params(op, entry.params)` only when `entry.params` was given and the result is non-empty.
  - `ops = {}` (shipped puzzles 19 and 20 use it, meaning "no editable ops"): set `_no_ops` when `def.ops` is present and empty. Clicking any `editor:allow:<op>` button clears `_no_ops`. Without this, copying those puzzles back drops `ops = {}` and offers every op, so the copied file would not work unchanged.
  - `_build_def` (used by Test) and `_serialize` (used by Copy) must agree: `ops` is the allowlist subset as today, else `{}` when `_no_ops` and nothing is allowed, else omitted. `fixed_ops` is deep-copied / written when non-empty, in order, e.g. `fixed_ops = { "flip_v", { op = "scalar_mul", params = { scalar = -1 } } },` with param keys sorted and strings via `%q`.
  - No new controls and no `ui_elements()` changes.
  - Unit test: drive paste and copy through `ui_elements()` rects and `mouse_pressed`; parse the clipboard with `DefParser.parse`. Cover: shipped puzzles 19 and 20 (read the file text from `PuzzleLoader.path(n)`) keep identical `ops` and `fixed_ops` after Paste then Copy; Test passes both to the matrix scene; string and table entries with and without params (including `edge`); each rejection case; pasting a definition without them afterwards clears both; allow toggle after `ops = {}`.
  - UI spec (real input only): `set_clipboard` a definition with `ops={}` and `fixed_ops={"flip_v",{op="scalar_mul",params={scalar=-1}}}`; click `Editor`, `editor:paste`, `editor:test`; assert `palette:fixed:flip_v` and `palette:fixed:scalar_mul` visible, `assert_text = "x-1!"`, `palette:transpose` with `visible = false`; `cmd:menu`; `editor:copy`; `editor:back`; `Editor`; `editor:paste` (pastes the copied text); `editor:test`; repeat the asserts. Second spec: pasting `fixed_ops={"abs"}` shows `Unsupported op: abs`.

- [x] Task D: shipped-data checks that survive new levels — `tests/test_puzzle_data.lua`, `tests/test_world_select.lua`, new `tests/test_shipped_puzzles.lua`
  - `test_puzzle_data.lua`: keep the ops section. Replace only the "World ranges" section (the `expected` table) with structural checks: at least one world and puzzle; every world has a non-empty name and at least one puzzle; indices run 1..`count()` consecutively across worlds. Update the header comment.
  - `test_world_select.lua`: replace only `assert(PuzzleLoader.count() == 21, ...)` with `count()` equals the total number of puzzles across all worlds.
  - `test_shipped_puzzles.lua`: no `.lua` file directly in `data/puzzles/` (name the file in the message); no world has more than 10 puzzles; every `id(n)` and `world_id(w)` is a string and `path(n)` lies in a subfolder; every puzzle has a non-empty string `name`; every non-nil `cutscene_path(w)` for `w = 0..world_count()` loads to a non-empty table; `data/cutscenes/` contains only `world_0.lua`. Do not pin counts or names.

- [x] Task E: verify the web zip (no file change expected) — `scripts/build_web.sh`
  - Run the script's `zip` command with the output written to your scratchpad directory (do not run `love.js`, do not leave `game.love` in the repo). Confirm with `unzip -l` that `data/puzzles/<world>/*.lua`, both `cutscene.lua` files and `data/cutscenes/world_0.lua` are included and no old flat puzzle paths are. Change the script only if something is missing. Report the result.

### Wave 3 (needs Tasks A and B)

- [x] Task F: player-visible worlds and unlocking — new `tests/ui/18_folder_worlds.lua`
  - Spec 1, `given = { solved = { 12 } }`: `press return`; `assert_text` "Basics", "Combos", "Advanced"; `assert_no_text` "Transforms" and "Fixed Pieces"; `assert_button` `world:3` enabled and `world:4` disabled; click `world:2`, assert `puzzle:6`; click `world:3`, assert `puzzle:12` and click it; `assert_text = "Deep Arch"`.
  - Spec 2, `given = { solved = "all" }`: all five world names drawn; click each `world:<n>` tab and assert its first puzzle's name.
  - Spec 3, `given = { solved = { 1,2,3,4,5,12 }, cutscenes_unseen = { 3 } }`: `press return`; `press right` (world 2); `press right` (world 3, cutscene starts); advance two beats and assert `WORLD 3: ADVANCED` (read from the world folder); advance once more, assert `puzzle:12`; `press left`, `press right`, assert `puzzle:12` again and `assert_no_text = "SYSTEM"` (no replay).
  - Real input only. `given.solved` and `cutscenes_unseen` take positions and world numbers.

### Wave 4 (needs all earlier tasks; approved by the user)

- [x] Task G: old tests find puzzles by filename, so a level can be inserted anywhere — existing files in `tests/` and `tests/ui/`
  - Change only **how** a test locates puzzles, worlds, totals and neighbouring puzzles. What each test checks stays the same; no assertion is removed or weakened.
  - Look puzzles up by id (`PuzzleLoader.id(n)`), worlds by `world_id(w)`, totals by `count()`. This includes `puzzle:N` and `world:N` element ids, `given.solved` lists, left/right key presses between worlds, `Puzzle N/21` text and expected converted positions. A shared helper under `tests/` is fine if the runners do not execute it as a test (`tests/test_*.lua` and `tests/ui/*.lua` are executed).
  - Known candidates: `test_multi_op_puzzles.lua`, `test_worlds.lua`, `test_palette_layout.lua`, `test_progress_migration.lua`, `tests/ui/` 03, 06, 07, 11, 13. Search all tests for others.
  - Prove it: temporarily add a valid puzzle that sorts first in `01_basics` (e.g. `00_zz_probe.lua`), then separately a new world folder that sorts first, run the full suite each time, and delete the probes. Both runs must pass. If a failure comes from the game rather than a test, fix the game and report it.
  - Report every edited file with what changed.

### Notes for the verification agent (not tasks)

- `README.md`: the add-a-level text (currently says to register in `puzzle_loader.lua`), the `data/puzzles/*.lua` mention in the editor section, folder/naming rules, saves by filename, the new unlock rule and its limit, the 10-puzzle and tab-width limits, editor keeping `fixed_ops`, and `Puzzle N/21`.
- `docs/testing.md`: how to add a level; `tests/ui/17` and `18`; `given.solved` / `cutscenes_unseen` are still positions and world numbers; the headless `getInfo` stub reports directories as files, so the loader and its tests rely on `getDirectoryItems`.
- Flag every edit to a pre-existing test (see the ground rules and Task G) with the reason.
- Headless tests cannot see the real save file or web build: run the game with an existing v2 save, and open the PR web preview to confirm worlds, order and cutscenes.
- Confirm that inserting a level before existing ones leaves the suite green (Task G).
