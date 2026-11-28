## Puzzle Trim and Ramp Checklist

Design: `docs/design/puzzle-trim-and-ramp.md` (approved). Read it, `CLAUDE.md` and `docs/testing.md` first.

### Rules for every task agent

- All tasks share one working tree (`/tmp/claude-wt-be6463`). Edit only the files your task names. Never commit, stash, revert, `git checkout`/`git restore` or "clean up" anything, including files you did not expect to see changed.
- **The full suite is only green once every task is done.** Verify your own files one at a time with `love . --headless <file>` (exit code 0). Do not fix failures in files you do not own; mention them in your report. (An `XDG_RUNTIME_DIR` message in the output is harmless.)
- No changes under `lua/`. If a test can only pass by changing game code, stop and report it. Do not edit `lua/game/progress.lua` conversion tables.
- Never weaken a test just to make it pass. Every edit to an existing test changes an expectation because the lineup changed on purpose (`CLAUDE.md` rule 2): record one line per edited file saying why, as an indented `Reason (<file>): ...` bullet under your item here and in your final report. These go into the verification report and PR.
- Where a cut puzzle carried behaviour no other test covers, keep that coverage on another puzzle or a test-local definition.
- Keep tests finding puzzles and worlds by id (`tests/support/shipped.lua`), not by hard-coded position.
- Mark your item `[x]` with a targeted edit of your own lines only (other agents edit this file too).
- READMEs and archiving docs belong to the verification agent only.
- Do not run `love . --headless --coverage`; see Verification notes.

### Wave 1 (parallel; must finish before Wave 2)

- [x] **Task A: puzzle data** — `data/puzzles/**` except `02_combos/cutscene.lua` — Produce the folder layout in the design. Use plain `mv`/`rm` (no index operations needed). Contents of moved files must stay byte-identical, including old comments.
  - Move: `02_combos/11_rotate_gap` -> `02_combos/01_rotate_gap`; `02_combos/10_set_row` -> `02_combos/02_set_row`; `03_advanced/13_flip_scale` -> `03_advanced/01_flip_scale`; `05_fixed_pieces/21_locked_scale` -> `03_advanced/02_locked_scale`; `04_transforms/18_double_negative` -> `03_advanced/03_double_negative`; `05_fixed_pieces/22_rotato` -> `03_advanced/05_rotato`; `06_two_sources/22_first_sum` -> `04_two_sources/01_first_sum`; `06_two_sources/26_take_away` -> `04_two_sources/02_take_away`; `06_two_sources/23_turned_sum` -> `04_two_sources/03_turned_sum`; `06_two_sources/24_operand_order` -> `04_two_sources/04_operand_order`; `06_two_sources/28_two_preps` -> `04_two_sources/05_two_preps`; `06_two_sources/25_merge_maze` -> `04_two_sources/06_merge_maze` (all `.lua`). `01_identity`, `02_flip` and both `cutscene.lua` files stay put.
  - Delete the 10 cut puzzles (`swap`, `scale`, `row_swap`, `uturn`, `negate_swap`, `elimination`, `col_ops`, `flips`, `fixed_puzzle`, `stand_to_add`) and the 5 replaced ones (`negate`, `combo`, `double_flip`, `triple`, `fixed_player`).
  - Create, copying each Lua block from the design verbatim (including header comments): `01_basics/03_scale_shift.lua`, `02_combos/03_corner_case.lua`, `02_combos/04_top_only.lua`, `02_combos/05_fold_through.lua`, `03_advanced/04_add_only.lua`.
  - Remove the empty `04_transforms`, `05_fixed_pieces`, `06_two_sources` folders.
  - Check: exactly 19 puzzles plus 2 cutscenes remain, and `tests/test_shipped_puzzles.lua`, `tests/test_puzzle_data.lua`, `tests/test_folder_loader.lua` and `tests/ui/04_sweep_all_puzzles.lua` pass.

- [x] **Task B: cutscene line** — `data/puzzles/02_combos/cutscene.lua` — In the first beat only, replace `Single operations are no longer sufficient. The patterns here demand more.` with `Warm-up complete. The patterns here will not yield to a straight push.` Nothing else changes.

### Wave 2 (parallel with each other; all depend on Task A, Task F also on Task B)

- [x] **Task C: progress tests** — `tests/test_progress.lua`, `tests/test_progress_ids.lua`, `tests/test_progress_migration.lua`
  - Reason (tests/test_progress.lua): the fixtures' old save numbers pointed at puzzles that no longer ship (`negate`, `swap`, `scale`, `row_swap`, `double_flip`), so they now use old numbers of surviving puzzles.
  - Reason (tests/test_progress_ids.lua): cut puzzle ids and the removed `transforms` and `fixed_pieces` worlds were looked up in the live lineup, so surviving ids are used and the `fixed_pieces` live lookup is dropped (the written-data assertion still proves 5 converts to it).
  - Reason (tests/test_progress_migration.lua): loaded saves are read back through puzzle ids and some old puzzles were removed, so the test now supplies the old five-folder listing; expected values and assertions are unchanged.
  - `test_progress.lua`: the four `_load()` blocks use old-format numbers whose ids (`negate`, `swap`, `scale`, `row_swap`, `double_flip`) are gone. Change the fixture numbers to old numbers of surviving puzzles and assert those ids. Old numbers (version 2 and, up to 14, unversioned): identity 1, flip 2, set_row 10, rotate_gap 11, flip_scale 13; version 2 also double_negative 18, locked_scale 21. Keep every case (new format, old plain array, solved and unsolved assertions, cutscene assertions, both `_persist` cases).
  - `test_progress_ids.lua` (stops at the first `position("negate")`; read the whole file): version 3 round trip: replace `negate`/`swap` with surviving ids and keep the expected strings alphabetically sorted. "version 2 cutscenes convert": `world_number("fixed_pieces")` no longer exists; drop that live lookup but keep the written-data assertion that proves 5 converts to `"fixed_pieces"`. The `ALL_PUZZLES`/`ALL_WORLDS` constants and the "ignores non-numbers" expected string describe the unchanged conversion tables: leave them. "Unlock rule": replace `negate_swap` with an Advanced puzzle; the "completing all earlier worlds" case must target a world that is not last (use `advanced`, since the check on `target + 1` is meaningless past the end), replacing `transforms`. "New level does not lock players out": replace `row_swap`/`negate_swap` with one solve in Combos and one in a later world.
  - `test_progress_migration.lua`: it reads loaded saves back through live puzzle ids. Wrap the whole body in a synthetic listing (override `love.filesystem.getDirectoryItems` plus `PuzzleLoader.rescan()`, like `with_listing` in `test_progress_ids.lua`) with the old five folders `01_basics` (V2 ids 1-5), `02_combos` (6-11), `03_advanced` (12-15), `04_transforms` (16-18), `05_fixed_pieces` (19-21), files named `NN_<id>.lua` from the file's `V2_IDS`. The loader must not load any puzzle file. Always restore the real function and rescan, even when an assertion fails (pcall, then assert), so no state leaks into later tests. Expected values and assertions stay unchanged.

- [x] **Task D: puzzle data tests** — `tests/test_multi_op_puzzles.lua`, `tests/test_two_source_data.lua`, `tests/test_two_source_prep_data.lua`, `tests/test_worlds.lua`, new `tests/test_ramp_data.lua`
  - `test_multi_op_puzzles.lua`: remove chains for cut and replaced puzzles; keep `set_row`, `flip_scale`, `double_negative`, `locked_scale`; add (fixed entries via `fixed(op)`):
    - `scale_shift` "Scale and Shift": `scalar_mul` 3, `scalar_add` 4.
    - `corner_case` "Corner Case": `edge_add` top 3, `edge_scale` left 2, `edge_add` bottom 1.
    - `top_only` "Top Only": fixed `edge_add`, fixed `edge_scale`, player `flip_v`, fixed `edge_scale`.
    - `fold_through` "Fold Through": `scalar_sub` 3, `edge_scale` left -2, `scalar_sub` 1, `transpose`.
    - `add_only` "Add Only": fixed `rotate_90`, `scalar_mul`, `edge_add`, `scalar_mul`, `rotate_90`, `rotate_90`, `rotate_90`.
    Drop helpers that become unused (such as `neg` only if nothing uses it).
  - `test_two_source_data.lua`: `IDS` becomes the new order `first_sum`, `take_away`, `turned_sum`, `operand_order`, `two_preps`, `merge_maze` (all six, so order, reference-solution header and paste-parse checks cover the whole world); update the "four introductory puzzles" wording. All per-puzzle idea checks stay.
  - `test_two_source_prep_data.lua`: delete the `stand_to_add` block and adjust the header. Its idea (transpose before a merge) is already pinned by the `merge_maze` checks in `test_two_source_data.lua`; confirm and say so in the reason line.
  - `test_worlds.lua`: `fixed_player` -> `add_only` (empty `ops`); "at least 5 worlds" -> 4; the unlock case uses `advanced` (open once all earlier worlds are solved) and `two_sources` (still locked) instead of `transforms`/`fixed_pieces`. Update comments and messages.
  - `test_ramp_data.lua` (new; worthwhile because nothing else pins the lineup or the difficulty claim): 
    - For each of `basics`, `combos`, `advanced`, `two_sources`: the design's ids are all in that world in the design's relative order, and the four worlds appear in that order. Check relative order only, so later insertions do not break it (the intent of `tests/support/shipped.lua`).
    - None of the 15 removed ids is shipped.
    - Minimal chains: for the five new puzzles, search every chain over the puzzle's own palette (each `ops` entry with every legal k and edge, per `lua/game/ops.lua`; `fixed_ops` entries with their preset params; apply with `Sim.apply_op`, dedupe visited matrices, skip ops that are invalid for the current matrix) and assert no chain shorter than 2 / 3 / 4 / 4 / 7 (Scale and Shift, Corner Case, Top Only, Fold Through, Add Only) reaches the target (values and shape), and that one of exactly that length does if cheap (Task D's chains above already prove reachability, so only the lower bound is required). Also assert that for no k does "add then multiply" solve Scale and Shift.
    - Time the file. Under the coverage hook it runs many times slower, so keep a normal run to a few seconds (Fold Through's last level is the expensive one: compare results without storing them).
    - Do not modify `test_shipped_puzzles.lua`.
  - Reason (tests/test_multi_op_puzzles.lua): chains and pinned names belonged to cut or replaced puzzles; the five redesigns have new chains.
  - Reason (tests/test_two_source_data.lua): Two Sources was reordered on purpose, so all six ids are now pinned in the new order.
  - Reason (tests/test_two_source_prep_data.lua): `stand_to_add` was cut; its transpose-before-merge idea is still pinned by the `merge_maze` checks in `test_two_source_data.lua` (confirmed; with M x rather than M+).
  - Reason (tests/test_worlds.lua): `fixed_player` was replaced by `add_only`, there are now four worlds, and `transforms`/`fixed_pieces` were removed.


- [x] **Task E: scene unit tests** — `tests/test_level_select.lua`, `tests/test_palette_layout.lua`, `tests/test_pusher_scene.lua`, `tests/test_editor_fixed_ops.lua`
  - `test_level_select.lua`: `setup_basics` needs at least four rows (hovers row 3, then Down to 4) and Basics now has three. Use `combos` (5 rows); rename the helper and comments. The other blocks are unchanged.
  - `test_palette_layout.lua`: the "Puzzle 19" fixed-only block uses `add_only` and expects fixed `rotate_90`, `edge_add`, `scalar_mul` (and no editable op); reword the messages. The "hint in HUD" block uses `scale_shift` instead of `negate`. Check the all-puzzles invariant loop and later blocks still pass.
  - `test_pusher_scene.lua`: in "per-puzzle palette", replace `swap` with `top_only` (offers FLv and no transpose, so the "hidden selection is cleared" assertion still means something); update the "puzzle 4" message. The `locked_scale` blocks are unaffected. Check everything after the first failure.
  - `test_editor_fixed_ops.lua`: the round-trip loop over `fixed_player`, `fixed_puzzle` becomes `add_only` (`ops = {}`) and `top_only` (`ops = { "flip_v" }`). Replace the "expected to ship ops = {}" assertion with a per-id expected `ops` list so both are still pinned; keep all round-trip and Test-button assertions.
  - Reason (tests/test_level_select.lua): Basics now has three puzzles and the hover test needs four rows, so it runs on Combos.
  - Reason (tests/test_palette_layout.lua): `fixed_player` and `negate` no longer ship; `add_only` (with its three fixed ops) and `scale_shift` replace them.
  - Reason (tests/test_pusher_scene.lua): `swap` was cut; `top_only` also offers FLv and no transpose.
  - Reason (tests/test_editor_fixed_ops.lua): `fixed_player` and `fixed_puzzle` no longer ship; `add_only` and `top_only` replace them, and `top_only` ships `ops = { "flip_v" }`, so each expected `ops` list is pinned per id (the "editable op" message now says "unlisted op" to match).

- [x] **Task F: navigation UI specs** — `tests/ui/02_level_select_keyboard.lua`, `tests/ui/03_world_locking.lua`, `tests/ui/06_cutscene.lua`, `tests/ui/18_folder_worlds.lua` (depends on A and B)
  - Reason (tests/ui/02_level_select_keyboard.lua): "Sharp Left" (`negate`) was replaced and Basics now has too few rows, so the cursor-parked keyboard spec runs on `corner_case` in Combos.
  - Reason (tests/ui/03_world_locking.lua): "Z-Bend" (`row_swap`) was cut, so the unlocked-world click uses `rotate_gap` ("Corridor Cross").
  - Reason (tests/ui/06_cutscene.lua): "Ordered Ops" (`double_flip`) was replaced, so Combos is identified by "Top Only"; the first spec also asserts the new first-beat line.
  - Reason (tests/ui/18_folder_worlds.lua): the lineup went from five worlds to four and `row_swap`, `negate_swap`, `col_ops` and `fixed_player` were removed, so only Two Sources remains locked after an Advanced solve.
  - `02`: first spec needs a row with a row above and below. Use Combos: `given = { solved = S.before("combos") }`, arrows to `combos`, hover `corner_case`, then the same down/up/up/return sequence with `S.name_after("corner_case", -1)`. Other specs unchanged.
  - `03`: replace `row_swap` / "Z-Bend" with `rotate_gap` / "Corridor Cross".
  - `06_cutscene`: replace "Ordered Ops" and its comments with "Top Only" (unique to Combos) in all four specs. Also assert the new first-beat line in the first spec if `assert_text` can match it as drawn.
  - `18`: `WORLDS` becomes four entries (Basics/`identity`; Combos/`top_only`/"Top Only"; Advanced/`double_negative`/"Double Negative"; Two Sources/`two_sources` with `merge_maze`/"Merge Maze"). Replace `negate_swap`/"Deep Arch" with `double_negative`/"Double Negative" in `partly_open` and `cutscene`. In `partly_open` the locked-world assertions become: no "Two Sources" text and `world:<two_sources>` disabled.

- [x] **Task G: solve UI specs** — `tests/ui/13_solve_converted.lua`, `tests/ui/06_solve_routed_puzzle.lua`, `tests/ui/25_rotato.lua`, `tests/ui/27_two_source_prep.lua`
  - `13` (CLAUDE.md rule 1: all five new puzzles won by real input, using the existing helpers): remove specs for cut and replaced puzzles and unused routes/shorthands; keep `set_row`, `flip_scale`, `double_negative` (world -> `advanced`), `locked_scale` (world -> `advanced`). Update the header comment. After WIN for each new puzzle, also click Continue and assert "SOLVED!" and the tick count shown on the recap. Pushers are listed A, B, C; commands are `{who, dir, tick}` (the helper adds the `stop`s).
    - `scale_shift` (basics): pushers (2,1),(1,7),(9,9); A down 1, B right 6, C up 12; `scalar_mul` k3 (2,5), `scalar_add` k4 (5,7); ticks 15.
    - `corner_case` (combos): (1,3),(8,1),(10,7); A right 1, B down 6, C left 10; `edge_add` 3 top (5,2), `edge_scale` 2 left (6,3), `edge_add` 1 bottom (8,6); ticks 13.
    - `top_only` (combos): (9,2),(2,1),(1,6); A left 1, B down 6, C right 10; fixed `edge_add` 3 top (5,2), fixed `edge_scale` 2 top (4,2), `flip_v` (2,5), fixed `edge_scale` 2 top (5,7); ticks 15.
    - `fold_through` (combos): (1,2),(8,1),(10,8); A right 1, B down 7, C left 12; `scalar_sub` 3 (5,2), `edge_scale` -2 left (6,3), `scalar_sub` 1 (7,2), `transpose` (10,3); ticks 16.
    - `add_only` (advanced): (1,2),(8,1),(10,9); A right 1, B down 7, C left 13; fixed `rotate_90` (4,2), fixed `scalar_mul` -1 (5,2), fixed `edge_add` 3 top (6,2), fixed `scalar_mul` -1 (7,2), fixed `rotate_90` (8,2), (9,2), (8,4); ticks 17.
  - `06_solve_routed_puzzle`: it solves the removed "Sharp Left". Rewrite it to solve Scale and Shift end to end with the solution above, keeping what the spec exercises: button-label navigation, `assert_tile` on pushers and edited tiles, chip drags into two lanes, Run, WIN, Continue, "SOLVED!". Update the header comment.
  - `25_rotato`: `S.arrows("fixed_pieces")` -> `S.arrows("advanced")`. Nothing else.
  - `27_two_source_prep`: remove the `stand_to_add` solve and adjust the header. Its path (transpose before a merge, won by real input) is covered by the Merge Maze solve in `tests/ui/23_two_source_world.lua`; confirm, and confirm turning a two-cell tile is still covered, then say so in the reason line.
  - Reason (tests/ui/13_solve_converted.lua): the solves for cut and replaced puzzles named ids that no longer ship, `double_negative` and `locked_scale` moved to `advanced`, and the five new puzzles are now won by real input with their recap ticks checked.
  - Reason (tests/ui/06_solve_routed_puzzle.lua): "Sharp Left" was replaced by Scale and Shift, so the same end-to-end flow now solves that puzzle with its reference solution.
  - Reason (tests/ui/25_rotato.lua): Rotato moved from the removed `fixed_pieces` world to `advanced`.
  - Reason (tests/ui/27_two_source_prep.lua): `stand_to_add` was cut; transpose before a merge is still won by real input in the Merge Maze solve (`23_two_source_world.lua`), and turning a two-cell tile is still covered by Two Preps here, Turned Sum and Operand Order in `23`, and `20_two_cell_tiles.lua`.

- [x] **Task H: scene behaviour UI specs** — `tests/ui/08_matrix_scene_ops.lua`, `tests/ui/11_transpose_refire.lua`
  - `08`: `open_fixed_pieces` now opens the `advanced` world (rename it and its comment). The fixed-tiles spec uses `add_only` / "Add Only": replace `fixed:flip_v` with `fixed:rotate_90` or `fixed:edge_add` (preset `+3` top; prefer covering `edge_add` as well, since a fixed edge tile must ignore the centre third), keeping every assertion for each third, each non-eraser tool and the eraser. The `locked_scale` spec only changes world. Update the header comment's "puzzle 19" / "puzzle 21".
  - `11`: keeps the transpose re-arm regression, now on Fold Through (verified to work in a scratch copy): `given = { solved = S.before("combos") }`, arrows to `combos`, open `fold_through`, place `transpose` at (9,2) (a nearer cell makes the transposed matrix hit the gap at (6,4)), pusher at (1,2), one `right` chip at lane 1 tick 1, Run, wait for `{{1,4},{2,5},{3,6}}`, then for `{{1,2,3},{4,5,6}}`. Rewrite the header comment (shape, path and why the second fire matters) to match.
  - Reason (tests/ui/08_matrix_scene_ops.lua): `fixed_player` was replaced by `add_only` (no fixed `flip_v`; `rotate_90`, `edge_add` and `scalar_mul` are tested instead) and the `fixed_pieces` world was removed, with `locked_scale` now in `advanced`.
  - Reason (tests/ui/11_transpose_refire.lua): Squeeze Bend (`scale`) and the old solved ids `negate`/`swap` are no longer shipped, so the transpose re-arm regression now runs on Fold Through (confirmed to fail in a scratch copy with the post-op re-arm removed).

### Verification notes (verification agent, after all tasks)

- `love . --headless` must exit 0; this is the first point where the whole suite is expected to pass. Also grep tests for the 15 removed ids and the old world ids: remaining hits should only be the old-save conversion data and synthetic fixtures.
- The project enforces 100% coverage of `lua/game/`. Check with `love . --headless --coverage`: slow (about 30 minutes), single core, never run two at once.
- Headless tests cannot see real rendering, the save file or the web build (CLAUDE.md rule 4): check the web preview or run the game, including the new cutscene line.
- Collect the `Reason (...)` lines for the PR. Update `README.md` as listed in the design, then archive this checklist and the design doc.
