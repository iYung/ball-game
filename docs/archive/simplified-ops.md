## Simplified Ops Checklist

Design: `docs/archive/design/simplified-ops.md` (approved, including all seven recommended defaults under "Open questions"). Read it before starting any task. Section numbers below refer to it.

### Rules for every task

- Waves run in order. Tasks inside one wave run in parallel and touch disjoint files. All agents share one worktree (`/tmp/claude-wt-3233c0`): touch only your task's files, never `git stash`, `git checkout --`, `git restore` or `git reset`, and do not "fix" failures in files another task owns.
- When done, tick only your own `- [ ]` line (use a targeted edit; others edit this file too).
- CLAUDE.md forbids editing tests just to make them pass. Change only the obsolete expectations named in your task. Where a test's intent survives and it merely used a removed op as a prop, swap in an equivalent (`negate` -> `{op="scalar_mul", params={scalar=-1}}`) and keep the assertions. Anything else that fails is a game bug. Never delete or weaken an assertion that is not named here. In your final report, list every edit to a pre-existing test with its reason (the verifier needs this list).
- `lua/game/` must end at 100% line coverage, so leave no dead branches. Every clickable element stays in `ui_elements()`; clicks hit-test through `UI.element_at`.
- Run one test file with `love . --headless <path>`. Do not edit README.md, `docs/testing.md` or anything under `docs/archive/` (verification phase).

### Test state per wave

| After wave | Full suite |
|---|---|
| 1 | green (all changes are additive) |
| 2 | may be red (removed ops and renumbered puzzles; scenes and old tests not yet updated) |
| 3 | may be red (UI specs and the multi-op test not yet updated) |
| 4 | expected green |
| 5 | **must be green**: `love . --headless` exits 0, and `love . --headless --coverage` too |

### Shared interfaces (all tasks must follow exactly)

**Tile shape.** An op tile is `{ kind="op", op=<id>, params={...}, locked=bool, fixed=bool }`, always 1x1 (`width`/`height` absent or 1). No `values`, `tile_rows`, `tile_cols` or `matrix_rows`. K ops use `params.scalar`; edge ops also use `params.edge`.

**`lua/game/ops.lua`** (`local Ops = require("lua/game/ops")`, no LOVE calls):

```lua
Ops.ORDER  = { "scalar_mul", "edge_scale", "scalar_add", "edge_add", "scalar_sub", "edge_sub",
               "transpose", "rotate_90", "flip_h", "flip_v" }   -- palette and allowlist order; separator after the 6th
Ops.EDGES  = { "top", "right", "bottom", "left" }               -- clockwise
Ops.ARROWS = { top="^", right=">", bottom="v", left="<" }
Ops.is_op(op)              -- boolean
Ops.label(op)              -- "xk" "xk^" "+k" "+k^" "-k" "-k^" "T" "R90" "FLh" "FLv" (order: scalar_mul, edge_scale, scalar_add, edge_add, scalar_sub, edge_sub, transpose, rotate_90, flip_h, flip_v); unknown -> "?"
Ops.has_scalar(op)         -- true for the six k ops
Ops.has_edge(op)           -- true for edge_scale, edge_add, edge_sub
Ops.range(op)              -- min, max of scalar: -9,9 for *_scale / scalar_mul; 0,9 for add and sub; nil for no-param ops
Ops.params(op, overrides)  -- fresh table: the op's defaults overlaid with overrides, keeping only keys the op supports.
                           -- Defaults: scale scalar=2, add/sub scalar=1, edge="top"; no-param and unknown ops -> {}
Ops.validate(op, params)   -- true, or false, message. params may be nil (defaults); missing keys are fine.
                           -- "Unsupported op: <op>" | "Invalid edge: <value>" | "Invalid scalar for <op>: <value>"
                           -- (non-number, non-integer, out of range); non-table params -> "Invalid params for <op>"
Ops.part(rel_x, cell_size) -- "left" if rel_x < cell_size/3, "right" if rel_x >= cell_size*2/3, else "centre"
Ops.click(op, params, part)-- mutates params. left/right: scalar -1/+1, clamped to range (missing scalar = default).
                           -- centre: edge ops turn clockwise (top, right, bottom, left, top). Otherwise nothing.
Ops.tile_text(op, params)  -- k ops: "x2", "x-1", "+1", "-3" (missing scalar = default; scalar_sub 0 is "-0", it names the op);
                           -- other ops: Ops.label(op)
Ops.fixed_label(op, params)-- Ops.tile_text(op, Ops.params(op, params)) .. (edge arrow for edge ops) .. "!"
                           -- e.g. "x-1!", "x3>!", "x2!" (defaults), "FLv!"
```

**`lua/game/op_tile.lua`** (the one op-tile drawing used by game, editor and recap):

```lua
OpTile.draw(tile, sx, sy, cs, fonts, opts)
-- fonts = { cell = <font for value>, ui = <font for marks and arrow> }
-- opts  = { marks = bool,      -- draw the dim "-" / "+" at the bottom (k ops only)
--           immutable = bool }  -- use the existing dimmer value colour {0.65,0.65,0.4}
```

It draws the background and border (current op-tile colours), `Ops.tile_text` centred, the marks, and for edge ops the arrow `Ops.ARROWS[edge]` in the **top-left** corner plus a solid bar 4px thick, inset 3px along the targeted side and spanning only the middle of that side (`18` to `cs-18`), so it never reaches the top-right lock / `=` markers or the bottom marks. Solid colours only (alpha 1). It must tolerate an unknown op (draws "?") and nil `params`. It does **not** draw the lock or `=` markers; scenes keep drawing those.

**Matrix methods** (all return a new Matrix, never mutate): `scalar_mul(k)`, `scalar_add(k)`, `scalar_sub(k)`, `edge_scale(edge, k)`, `edge_add(edge, k)`, `edge_sub(edge, k)`, `transpose()`, `rotate_90()`, `flip_h()`, `flip_v()`. No result element may be `-0`.

**`ui_tile(x, y)`** in MatrixScene and EditorScene returns `{ kind, op, dir, edge, scalar }` (`edge`/`scalar` from `tile.params`, nil when absent; EditorScene has no `dir` to report, so it may be nil).

**`fixed_ops` entry:** `"flip_v"` or `{ op = "scalar_mul", params = { scalar = -1 } }`. Button id stays `palette:fixed:<op>`.

---

### Wave 1

- [x] Task 1 — `lua/game/ops.lua` (new), `lua/game/op_tile.lua` (new), `tests/test_ops.lua` (new) — Implement the two modules exactly as in "Shared interfaces" (design sections 1, 2, 3, 6). The test covers every Ops function (all ten ops, clamping at both limits, edge wrap, every validate message, fixed labels) and calls `OpTile.draw` for a whole op, each of the four edges, an unknown op and nil params, with marks on and off, checking drawn text via `lua/headless/stubs` (`Stubs.clear_text` / `Stubs.drawn_text`). Cover every line. Dependencies: none.

- [x] Task 2 — `lua/game/progress.lua`, `tests/test_progress_migration.lua` (new) — Save migration (design section 8). `_persist` writes `return {version=2,solved={...},cutscenes={...}}`. In `_load`, a table without `version` (both the `{solved=,cutscenes=}` format and the old plain array) has its solved indices remapped: 1-14 unchanged; 15 and 17 dropped; 16->15; 18->16; 19->17; 20->18; 21->19; 22->20; 23->21; anything else dropped. A table with `version` is loaded unchanged. Cutscene flags are copied as they are. Do not write the file during load. Tests: both old formats (including every remapped and dropped index), a versioned save left untouched, the written string containing `version=2`, and that a player with all of old worlds 1..N solved still has world N+1 unlocked in the new numbering (assert on indices, so it does not depend on Task 5). Follow the stub-`love.filesystem` / re-require pattern in `tests/test_progress.lua` and restore the original module afterwards. Do not edit `tests/test_progress.lua`. Dependencies: none.

- [x] Task 3 — `lua/headless/ui_runner.lua`, `tests/test_ui_runner.lua` — Make `assert_tile` also compare `edge` and `scalar` (add them to the compared field list; `scalar = 0` and negative values must work). Add (do not change existing) cases to `test_ui_runner.lua` with a fake scene: match and mismatch for both fields. Dependencies: none.

### Wave 2

- [x] Task 4 — `lua/game/matrix_math.lua`, `lua/game/pusher_sim.lua`, `tests/test_matrix_math.lua`, `tests/test_pushers.lua` — Matrix: add `scalar_add`, `scalar_sub`, `edge_scale`, `edge_add`, `edge_sub`; delete `scale_row`, `add_rows`, `swap_rows`, `negate`, `add_matrix`, `sub_matrix`, `mul_matrix`, `set_row`, `scale_col`, `swap_cols`, `add_cols`, `set_col`, `abs`. Edge = first row / last column / last row / first column of the matrix as it is now; on a one-row matrix top and bottom are that row (columns likewise); each element is changed once. Normalise zeros so no result is `-0` (e.g. `if v == 0 then v = 0 end`; this includes `scalar_mul`). `Sim.apply_op` handles only the ten ops, reading `local p = Ops.params(tile.op, tile.params)`; non-op tiles and unknown ops return the same matrix object. Remove the stale "row params are clamped" comment. Tests, obsolete because the user removed these ops: in `test_matrix_math.lua` delete the sections for the removed methods; in `test_pushers.lua` delete the `apply_op` blocks and assertions for removed ops (including the row-clamp and same-row no-op lines in the first block). Keep the `scalar_mul`, `transpose`, flip, rotate and unknown-op blocks. Add: each new op, all four edges, non-square, one-row and one-column matrices, k = 0, negative results, results above 9, source matrix not mutated, no `-0` (check with `1 / v ~= -math.huge`), and `apply_op` with missing params using defaults. Dependencies: Task 1.

- [x] Task 5 — `data/puzzles/*.lua`, `lua/game/puzzle_loader.lua`, `tests/test_worlds.lua`, `tests/test_world_select.lua`, `tests/test_puzzle_data.lua` (new) — Apply the table in design section 7 and the worlds in section 8. Delete `15_scale_swap.lua` and `17_add_rows.lua`. `git mv`: `16_triple`->`15_triple`, `18_col_ops`->`16_col_ops`, `19_flips`->`17_flips`, `20_abs_rotate`->`18_double_negative` (name "Double Negative"), `21_fixed_player`->`19_fixed_player`, `22_fixed_puzzle`->`20_fixed_puzzle`, `23_locked_scale`->`21_locked_scale`. Other file names stay. Set each converted puzzle's `ops` / `fixed_ops` / `locked` exactly as in the table; input, target, route, source, sink and gaps do not change. New 19 has `ops = {}` and `fixed_ops = { "flip_v", { op = "scalar_mul", params = { scalar = -1 } } }`. New 20 locks `scalar_mul` `params={scalar=-1}` at (6,6). Locked entries carry no `tile_rows`. Rewrite comments in converted files to describe the new ops and reference chain, keeping route notes; correct puzzle 7's false "only one order works" comment (design section 7, analysis notes). Puzzles 1, 2, 5, 11 and old 19 keep their data. Loader: 21 paths; worlds Basics 1-5, Combos 6-11, Advanced 12-15, Transforms 16-18, Fixed Pieces 19-21. Tests: in `test_world_select.lua` `count() == 23` becomes 21 (two puzzles deleted by the user's decision); in `test_worlds.lua` the empty-ops check moves from `load(21)` to `load(19)` including messages and header comment (puzzle renumbered). New `test_puzzle_data.lua`: for every shipped puzzle, each `ops`, `fixed_ops` (string or table) and op `locked` entry passes `Ops.validate`; no op appears twice in `fixed_ops`; locked entries have no `width`/`height`/`tile_rows`/`tile_cols`; the five world ranges are as above. Dependencies: Task 1.

### Wave 3

- [x] Task 6 — `lua/game/scenes/matrix_scene.lua`, `tests/test_pusher_scene.lua`, `tests/test_matrix_coverage.lua`, `tests/test_matrix_draw.lua`, `tests/test_row_op_delete_resize.lua`, `tests/test_drag_ops.lua`, `tests/test_palette_layout.lua` — Design sections 2-5. Dependencies: Tasks 1, 4, 5.
  - Remove `PARAM_DEFS` (and its per-puzzle rewrite), `DEFAULT_PARAMS`, `OP_SYMBOLS`, `OP_SIZES`, `op_width`/`op_height`, all `draw_ref_cell` op branches (source ref cells stay), every `draw_*` band/strip/value/param cell function, resize strips (`_expand_rects`, `_resize_tile`, draw pass 3) and all op-specific click handlers. `Grid` multi-cell support stays for the source. Simplify multi-cell handling that only op tiles needed (placement, drag pickup/drop/ghost, `_clear_drag`, `_process_footprint`) without changing firing order or re-arm rules.
  - Palette: pusher; sep; the six k ops; sep; T, R90, FLh, FLv (all from `Ops.ORDER` / `Ops.label`); sep; Mv; [X]. Consecutive separators with an empty group between them still give a single gap (current `pending` behaviour). Full palette ends at y=454, no scroll arrows. Keep the scroll code.
  - Locked puzzle entries: always 1x1, ignore `width`, `height`, `tile_rows`, `tile_cols`; `params = Ops.params(t.op, t.params)` for ops (fresh copy).
  - `fixed_ops`: accept string or `{op=, params=}`; skip entries failing `Ops.is_op`; button label `Ops.fixed_label`; the button's preset goes into the palette selection (`params`) and from there into every placed tile. Placement uses `params = Ops.params(spec.op, spec.params)`; new tiles default to `edge="top"`.
  - Click on a cell holding an op tile (left button, after the existing drag-tool branch): eraser removes it if unlocked (any third, fixed included); else fixed or locked -> nothing; else `Ops.click(tile.op, tile.params, Ops.part(mx - cell_left_x, CELL_SIZE))`, whatever tool is selected; never replaced. Right-click erase, Mv (keeps `params`) and edits during a run are unchanged.
  - Draw op tiles with `OpTile.draw` (`marks = immutable == false`, `immutable = tile.fixed or tile.locked`), then the existing lock and `=` markers. Drag ghost on the board shows `Ops.tile_text(tile.op, tile.params)` for ops; the palette drag ghost keeps the button label. `ui_tile` per "Shared interfaces".
  - Test edits, each obsolete because the user removed the feature or puzzle: `test_pusher_scene.lua`: `-I` and `<>R` palette labels (use new labels; puzzle 4 now offers `FLv`) and the `xR`/`R+R` negative checks (check new labels); fixed `swap_rows` param test (re-express on a fixed `edge_scale` tile: neither `scalar` nor `edge` changes on any third); `load(23)`/`scale_row` locked tests (now `load(21)`, `edge_scale` top scalar 3, same resulting matrix); `negate` props in the movement tests. `test_matrix_coverage.lua`: delete the `mul_matrix` placement section and both `set_row` click sections; swap `negate` props. `test_matrix_draw.lua`: swap the `add_matrix` ghost prop; delete the resize-strip section only. `test_row_op_delete_resize.lua`: delete ref-cell erase, resize and row-clamp cases; keep "eraser removes a placed op" (add middle third) and "param click without eraser edits the tile" on new ops. `test_drag_ops.lua`: delete the multi-cell case; swap `negate` props.
  - `test_palette_layout.lua`: replace the puzzle-1 overflow block with the same scroll assertions on a synthetic definition (`MatrixScene.new_from_def`, no `ops` list, several `fixed_ops`, including one table preset) that overflows, with item counts to match; assert puzzle 1 has no arrows and its last button ends at y=454; the puzzle-21 fixed-only block becomes puzzle 19 with `palette:fixed:flip_v` and `palette:fixed:scalar_mul`.
  - Add unit assertions for: fixed preset applied and label drawn (`x-1!`), unsupported `fixed_ops` entry skipped, locked entry with `width=2` placed 1x1, `ui_tile` fields, op ghost drawing.

- [x] Task 7 — `lua/game/scenes/editor_scene.lua`, delete `lua/game/param_popup.lua` and `tests/test_param_popup.lua`, `tests/ui/12_editor.lua`, `tests/ui/14_editor_ops.lua` (new) — Design section 6. Dependencies: Task 1 (the Test button opens MatrixScene, so re-run your specs once Task 6 is ticked).
  - Remove `OP_SYMBOLS`, `OP_NAMES`, `OP_LABELS`, `OP_SIZES`, `DEFAULT_PARAMS` and all popup code. Palette: SRC, SNK, GAP; sep; P; sep; the ten ops in `Ops.ORDER`; sep; [X] (all 15 must fit). Allowlist: the same ten ops; `ops` is exported only for a proper non-empty subset (unchanged rule).
  - Op tiles are 1x1, placed with `params = Ops.params(op)`, `locked=true`. Left-click on a k-op tile with any tool but the eraser (including none selected) edits by thirds via `Ops.click`; with the eraser, left-click erases; right-click erases; other cases behave as today.
  - Draw with `OpTile.draw(..., { marks = true, immutable = false })` plus the existing lock marker. `ui_tile` per "Shared interfaces".
  - `_build_def` / `_load_def` / `_serialize`: locked entries are `kind, x, y, op, params` (op entries always 1x1; ignore `width`, `height`, `tile_rows`, `tile_cols` on load and never write them); string params are quoted (`edge="left"`, use `%q`); loaded op params go through `Ops.params`.
  - Paste: before loading, run `Ops.validate` on every `ops` entry and every op `locked` entry; on failure show the returned message (e.g. `Unsupported op: negate`) in the existing error flash and leave the editor unchanged. Unreadable text still shows `Parse error`.
  - Test edits: delete `test_param_popup.lua` (module removed). In `12_editor.lua` delete the two popup specs (popup removed) and replace `scale_row` in the paste round-trip input with a supported op such as `edge_scale` (op removed; leave the ignored `width`/`tile_rows` fields in as coverage that they are ignored); update comments that cite removed behaviour.
  - New `14_editor_ops.lua` (real input only): place k tiles and change k and direction by thirds, with `assert_tile` and `assert_text`; eraser on a k tile erases it; right-click erases; Copy then Paste preserves `edge` and `scalar` (Copy, erase the tile, Paste: the runner's clipboard stub keeps the copied text); pasting a definition with `negate`, a bad edge and an out-of-range scalar shows the error and leaves the board unchanged; a copied edge tile works after Test.

- [x] Task 8 — `lua/game/scenes/solution_recap_scene.lua`, `tests/test_solution_recap.lua` — Remove `OP_SYMBOLS`; draw op tiles with `OpTile.draw(tile, sx, sy, CELL_SIZE, {cell=self._font_cell, ui=self._font_ui}, { marks = false, immutable = tile.locked or tile.fixed })`, so k and direction show; op tiles are 1x1. Test edits: swap the `negate` props (op removed), and replace the "multi-cell scale_row counts as 1 piece" prop and wording with an `edge_scale` tile (no multi-cell ops; keep the count assertion); in the draw test use `edge_scale` instead of `scale_row`. Add: recap draw of edge tiles on all four sides asserts the drawn value and arrow text. Dependencies: Task 1 (the `_count_pieces` test uses MatrixScene, so re-run once Task 6 is ticked).

### Wave 4

UI specs use real input only (`press`, `click_button`, `click_cell`, `drag`, ...). Use `given = { solved = "all" }` for later worlds and `press = "right"` to change world. Assert state with `assert_tile` (`edge`, `scalar`) and what the player sees with `assert_text` / `assert_matrix`. If a spec exposes a game bug, fix the game (report it), not the spec.

- [x] Task 9 — `tests/ui/08_matrix_scene_ops.lua` (rewrite), `tests/ui/04_sweep_all_puzzles.lua`, `tests/ui/06_solve_routed_puzzle.lua`, `tests/ui/12_puzzle_bar_dnd.lua` — Dependencies: Wave 3.
  - Rewrite `08` (every old spec targets removed ops or ref cells) with design section 9 UI specs 1-5: (1) place each of the six k tiles; left/right thirds change k and clamp at both limits; middle does nothing on a whole tile; (2) middle third cycles an edge tile top -> right -> bottom -> left -> top with k kept; (3) a rotated edge tile changes exactly that edge during a run (`assert_matrix`, e.g. puzzle 1 with `+k^` turned right); (4) a fixed tile placed in puzzle 19 and the locked tile at (5,3) in puzzle 21 ignore all three thirds, with a non-eraser tool and the eraser (the eraser still removes the unlocked fixed tile, so check that last); (5) Mv keeps k and edge; eraser removes a tile from the middle third.
  - `04`: remove only the puzzle-1 scroll steps (palette now fits); asserting `palette:scroll_down` is not visible there is fine. `06`: replace the `-I` click with placing `palette:scalar_mul` at (5,2) and three left-third clicks (k 2 -> -1), assert `scalar = -1`; update comments (op removed). `12_puzzle_bar_dnd`: remove only the three `palette:scroll_down` clicks (no arrows); everything else stays.

- [x] Task 10 — `tests/ui/13_solve_converted.lua` (new), `tests/test_multi_op_puzzles.lua` (rewrite) — Design section 9 UI spec 6: one spec per row of the replay table in design section 7 (all 16 converted puzzles; the "9, 12" row is two specs), winning through palette, cell, drag and Run input, ending at `WIN!`. Place pushers in letter order; at each listed tick write the command for that pusher (select with `psel:<L>`, drag the chip to a slot) and `stop` for the previously commanded pusher on the same tick (not if it is the same pusher); the two commands use different lanes. Set player tiles by placing then clicking thirds (and the middle third to turn edges); puzzle 19 must use the `palette:fixed:...` buttons. A small Lua helper that builds `steps` is fine. Rewrite `test_multi_op_puzzles.lua` (it used removed methods and numbers that differ from the shipped data): for each converted puzzle load it with `PuzzleLoader`, apply the reference chain from the design table (locked tiles taken from the puzzle file) through `Sim.apply_op`, and assert the result equals the file's target. Dependencies: Wave 3.

### Wave 5

- [x] Task 11 — whole worktree — Run `love . --headless` and then `love . --headless --coverage` (the coverage run takes many minutes: run it in the background; add `--verbose-gaps` to list uncovered lines). Both must exit 0 with 100% coverage of `lua/game/`. Close gaps by deleting dead code or adding tests for real behaviour; fix game bugs in the game. Grep `lua/`, `data/` and `tests/` for leftovers of removed ops, `param_popup`, `_expand_rects`, `_resize_tile`, `tile_rows`, `tile_cols`, `OP_SYMBOLS`, `OP_SIZES`, `DEFAULT_PARAMS`, `PARAM_DEFS`; remove stale code (harmless test props outside the design's obsolete list, e.g. in `test_basics.lua`, and the ignored-field coverage in `12_editor.lua` stay). Check `git diff master -- tests/` against the design section 9 table and report any edit not covered by it, with its reason. Dependencies: all previous tasks.
