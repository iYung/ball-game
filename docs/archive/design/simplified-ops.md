# Simplified Ops

## Goal

Every op tile has at most one number. Today the palette has 18 ops, several with row/column pickers, value grids, multi-cell footprints and resize strips. We replace them with two families: an op acts on **the whole matrix** or on **exactly one edge** of it.

Decisions already made by the user (final):

- Row and column pickers are removed. An edge op acts on one edge. It defaults to the **top** edge and can be rotated to top, right, bottom or left (right and left are columns).
- Final op set: whole-matrix scale, add, subtract; edge scale, add, subtract; `rotate_90`, `flip_h`, `flip_v`, `transpose`.
- Removed: `negate` (use scale by -1), `abs`, `swap_rows`, `swap_cols`, `add_rows`, `add_cols`, `set_row`, `set_col`, `mul_matrix`, grid-valued `add_matrix` / `sub_matrix`, indexed `scale_row` / `scale_col`.
- `+k` and `-k` are separate tiles, k from 0 to 9. They add or subtract the single number k to every element of the matrix or the edge.
- Clicking the middle third of a placed edge tile turns it clockwise. Left and right thirds change k. An edge tile is 1x1 and shows an arrow. Fixed and locked tiles cannot be turned.
- Puzzles that map onto the new ops are converted. Puzzles that cannot be made to work are deleted and worlds renumbered.

## Affected files

| File | Why |
|---|---|
| `lua/game/ops.lua` (new, suggested) | One definition of op ids, labels, default params and k ranges. Today `OP_SYMBOLS`, `OP_SIZES` and `DEFAULT_PARAMS` are copied in three scenes and have drifted (the recap shows `?` for several ops) |
| `lua/game/matrix_math.lua` | New add/subtract and edge operations; removed ops deleted; no `-0` |
| `lua/game/pusher_sim.lua` | `apply_op` handles only the final op set |
| `lua/game/scenes/matrix_scene.lua` | Palette, placement, tile drawing, click editing, fixed-op presets; remove multi-cell op code and resize strips |
| `lua/game/scenes/editor_scene.lua` | Palette, allowlist, click editing, drawing, serialize, paste validation |
| `lua/game/scenes/solution_recap_scene.lua` | Draws the new tiles with k and direction |
| `lua/game/param_popup.lua` | Deleted |
| `lua/game/puzzle_loader.lua` | 21 puzzles, new world lists |
| `lua/game/progress.lua` | Migrate saved solved indices |
| `lua/headless/ui_runner.lua` | `assert_tile` can compare `edge` and `scalar` |
| `data/puzzles/*.lua` | Convert, delete, renumber |
| `tests/`, `tests/ui/` | See "Tests" |
| `README.md`, `docs/testing.md` | Tile list, puzzle and world counts, element ids, resize-strip gap section (verification phase) |

No change needed: `grid.lua`, `timeline.lua`, `hud.lua` (unless `-0` is fixed there instead), `palette.lua` (it already copies every selection key), `level_select_scene.lua`, cutscene data, `docs/pusher-physics.md`.

## What changes

### 1. Op set

All op tiles are **1x1**.

| Op id | Label | Params | Default | Effect (k = `scalar`) |
|---|---|---|---|---|
| `scalar_mul` | `xk` | `scalar` -9..9 | 2 | every element times k |
| `scalar_add` | `+k` | `scalar` 0..9 | 1 | every element plus k |
| `scalar_sub` | `-k` | `scalar` 0..9 | 1 | every element minus k |
| `edge_scale` | `xk^` | `scalar` -9..9, `edge` | 2, `"top"` | edge elements times k |
| `edge_add` | `+k^` | `scalar` 0..9, `edge` | 1, `"top"` | edge elements plus k |
| `edge_sub` | `-k^` | `scalar` 0..9, `edge` | 1, `"top"` | edge elements minus k |
| `transpose` | `T` | none | | unchanged |
| `rotate_90` | `R90` | none | | unchanged |
| `flip_h` | `FLh` | none | | unchanged |
| `flip_v` | `FLv` | none | | unchanged |

- `scalar_mul` keeps its existing id and param name, so existing correct behaviour and tests of it survive. All six k ops use `scalar`.
- `edge` is one of `"top"`, `"right"`, `"bottom"`, `"left"`: first row, last column, last row, first column of the matrix **as it is when the tile fires** (board orientation, after earlier transforms). On a one-row matrix, top and bottom both mean that row; columns likewise. Corners belong to two edges but each tile touches only its own.
- Scale keeps -9..9 because scale by -1 replaces negate. Add and subtract k is 0..9; k = 0 is allowed and does nothing.
- Results may be negative or exceed 9. Only k is clamped.
- Results must never display as `-0`. Scaling a zero by -1 yields `-0` today (confirmed in a headless run: `{-2,-0,-0}`), and that will now be common.
- Firing rules do not change. Because every op tile is one cell, it fires when the matrix newly covers that cell and re-arms when the matrix leaves it.

### 2. Placed-tile interaction (game scene)

Thirds are the same hit areas as today (`click_cell` with `part = "left" | "centre" | "right"`).

| Tile | Left third | Middle third | Right third |
|---|---|---|---|
| Edge op | k - 1 | turn clockwise: top, right, bottom, left, top | k + 1 |
| Whole k op | k - 1 | nothing | k + 1 |
| No-param op | nothing | nothing | nothing |
| Any fixed or locked tile | nothing | nothing | nothing |

- k clamps at its limits (no wrap). Direction wraps.
- Middle does nothing on whole tiles: there is no second thing to change, and one meaning per zone is predictable.
- Unchanged behaviour: the eraser removes an unlocked tile (including fixed ones) from any third; right-click erases; **[Mv]** moves a tile and keeps `scalar` and `edge`; with a different palette tool selected, clicking an existing op tile edits it rather than replacing it; edits are not blocked during a run.
- A new tile starts with the default k and `edge = "top"`.

### 3. Appearance and palette

- Every k tile shows its operation and value in the middle (`x2`, `+1`, `-3`, `x-1`) and, when editable, the dim `-` / `+` marks at the bottom, as param cells do today. Immutable tiles use the existing dimmer value colour and no marks.
- Edge tiles add two cues that whole tiles never have: a direction arrow (ASCII `^ > v <`, like the timeline chips) and a thick solid bar along the targeted side of the cell. The arrow and bar must not collide with the lock marker or the fixed `=` marker in the top-right corner. Solid colours only.
- Palette order: pusher; separator; `xk`, `xk^`, `+k`, `+k^`, `-k`, `-k^`; separator; `T`, `R90`, `FLh`, `FLv`; separator; `Mv`, `[X]`. In the two-wide column the full set puts whole ops on the left and edge ops on the right. A puzzle's subset packs in the same order.
- The `^` in an edge label is static; it marks "edge op", not the current direction of any tile.
- The full unrestricted palette (13 buttons) fits without scrolling (last button ends at y = 454, limit 512). Keep the scroll code: a definition with no `ops` list plus several `fixed_ops` can still overflow. No shipped puzzle does, so it is covered by a unit test with a synthetic definition.
- Drag ghost and solution recap use the same symbols, and the recap shows k and direction for each tile.

### 4. Removed code

Multi-cell op placement and drawing, per-op band/strip/value-cell drawing and click handlers, `PARAM_DEFS` row/column limits that are rewritten on each puzzle load, tile `values` / `tile_rows` / `tile_cols` / `matrix_rows`, and the resize strips (`_expand_rects`, `_resize_tile`). The resize strips were the one documented exception to "every clickable thing is in `ui_elements()`"; that exception disappears. `Grid` multi-cell support stays because the source tile uses it. Locked op entries are always 1x1; any `width`, `height`, `tile_rows` or `tile_cols` on them is ignored. CI requires 100% line coverage of `lua/game/`, so leftover dead branches will fail the build.

### 5. Fixed-op presets

Puzzle 21 (new 19) offered a fixed `negate`. A fixed scale tile gets default params (k = 2) and cannot be edited, so `fixed_ops` entries must be able to carry params. An entry is either a string (defaults) or a table:

```lua
fixed_ops = { "flip_v", { op = "scalar_mul", params = { scalar = -1 } } }
```

The preset is applied to every tile placed from that button. The palette label shows the preset (`x-1!`; edge presets include the direction), because the player cannot edit it after placing. Button ids stay `palette:fixed:<op>`, so a puzzle may list each op at most once in `fixed_ops`.

### 6. Editor

- Palette and op allowlist list exactly the ten ops. The palette now fits completely (today buttons past x = 810 are silently dropped).
- **`param_popup.lua` is removed.** The editor uses the same thirds interaction as the game. It only existed for typing params, and it can enter values the new ops do not allow. Editor tiles are `locked=true` in the exported data but remain editable inside the editor. Eraser selected: left-click erases (today a param tile opens the popup even with the eraser). Right-click erases.
- Grid tiles show k and direction.
- Copy: `params` string values must be quoted (`edge="left"`). The current serializer writes `tostring(v)`, which would emit `edge=left` and silently lose the direction on paste.
- Paste: reject a definition whose `ops` or `locked` entries name an unsupported op, or whose `edge` / `scalar` is invalid (unknown edge, non-integer or out-of-range k). Show an error naming the problem (for example `Unsupported op: negate`) and leave the editor unchanged. Missing params take defaults. No automatic translation of old ops: most have no equivalent. Unreadable text still shows `Parse error`.
- The editor still does not support `fixed_ops` (unchanged).

### 7. Puzzles

Rule used: keep input, target, route and gaps; convert when the new ops can produce the target in a short chain; otherwise delete.

Unaffected (data unchanged): 2, 5, 11 (`transpose`), 19 (`flip_h`, `flip_v`). Puzzle 1 has no `ops` list, so only its palette changes.

Notation: `x-1 top` means `edge_scale{scalar=-1, edge="top"}`; `x-1` alone is `scalar_mul`.

| Old | New | Name | Action | New `ops` / `fixed_ops` / `locked` | Reference solution (matrix chain) | Fewest tiles |
|---|---|---|---|---|---|---|
| 1 | 1 | Identity Check | keep | all ops | no op | 0 |
| 3 | 3 | Sharp Left | convert | `ops={"scalar_mul"}` | [1 2; 3 4] x-1 → [-1 -2; -3 -4] | 1 |
| 4 | 4 | Drop First | convert | `ops={"flip_v"}` | anti-diagonal FLv → identity | 1 |
| 6 | 6 | Z-Bend | convert | `ops={"scalar_mul","flip_v"}` | [1 2; 3 4] x-1 → [-1 -2; -3 -4] FLv → [-3 -4; -1 -2] | 2 |
| 7 | 7 | Ordered Ops | convert | `ops={"edge_scale","flip_v"}` | [1 2; 3 4] x2 top → [2 4; 3 4] FLv → [3 4; 2 4] | 2 |
| 8 | 8 | Corner Scale | convert | `ops={"edge_scale"}` | diag(2,3,1) x-1 top → diag(-2,3,1) | 1 (x-1 left also works) |
| 9 | 9 | Arch | convert | `ops={"scalar_mul","flip_v"}` | as puzzle 6 | 2 |
| 10 | 10 | Staircase | convert, new chain | `ops={"edge_scale","edge_sub"}` | [1 2; 0 4] x4 bottom → [1 2; 0 16] -8 right → [1 -6; 0 8] | 2 |
| 12 | 12 | Deep Arch | convert | `ops={"scalar_mul","flip_v"}` | as puzzle 6 | 2 |
| 13 | 13 | Flip Scale Arch | convert | `ops={"transpose"}`; locked `edge_scale` (5,3) `{edge="bottom",scalar=3}` | [1 2; 1 4] locked x3 bottom → [1 2; 3 12] T → [1 3; 2 12] | 1 |
| 14 | 14 | Three-Step Elimination | convert, new chain | `ops={"edge_scale","edge_sub"}` | [2 0; 1 3] x4 top → [8 0; 1 3] -4 left → [4 0; -3 3] | 2 |
| 15 | | Scale-Swap Detour | **delete** | | needs the centre of a 3x3 scaled alone | |
| 16 | 15 | Triple Bend | convert | `ops={"transpose","scalar_mul","edge_scale"}` | [1 2; 3 4] x-1 → [-1 -2; -3 -4] x2 top → [-2 -4; -3 -4] T → [-2 -3; -4 -4] | 3 |
| 17 | | Row Reduction Spiral | **delete** | | needs row2 - 3·row1 | |
| 18 | 16 | Column Work Maze | convert | `ops={"flip_h","edge_scale"}` | [1 2; 3 4] FLh → [2 1; 4 3] x2 right → [2 2; 4 6] | 2 |
| 20 | 18 | Absolute Rotation → **Double Negative** | convert, new chain, rename | `ops={"edge_scale"}`; locked `rotate_90` (5,3) unchanged | [-2 1; 3 -4] R90 → [3 -2; -4 1] x-1 right → [3 2; -4 -1] x-1 bottom → [3 2; 4 1] | 2 |
| 21 | 19 | Fixed Tools, Bent Path | convert | `ops={}`; `fixed_ops` as in section 5 | as puzzle 6, with fixed tiles | 2 |
| 22 | 20 | Mandatory Negate, Arch Path | convert | `ops={}`; locked `scalar_mul` (6,6) `{scalar=-1}` | [1 2; 3 4] x-1 → [-1 -2; -3 -4] | 0 |
| 23 | 21 | Locked Scale, Full Maze | convert | `ops={"transpose","scalar_mul"}`; locked `edge_scale` (5,3) `{edge="top",scalar=3}` | [1 2; 0 1] locked x3 top → [3 6; 0 1] T → [3 0; 6 1] x-1 → [-3 0; -6 -1] | 2 |

Unlisted new numbers: old 19 Mirror Maze is new 17.

Analysis notes:

- **Locked footprints.** The converted locked tiles (13, 21, 22, 23) were already one cell (`tile_rows=1` or a 1x1 op), so they fire at the same moment as before. The only multi-cell locked tiles were in the deleted puzzles 15 and 17. Player-placed tiles shrink to 1x1, which gives the player more placement freedom and blocks no route.
- **Triviality.** For old puzzles 7, 8, 10, 14, 16, 18, 20 and 23, an exhaustive search over the offered ops (all k and edges, ignoring routing) confirms the "Fewest tiles" column; the others are evident from the matrices. Only 22 needs no player tile, as before. Puzzles 3, 4 and 8 stay one-tile puzzles.
- **Puzzle 7** accepts both "x2 top then FLv" and "FLv then x2 bottom". The old puzzle also allowed this (swap, then scale row 2), so its comment claiming a single valid order was already wrong and should be corrected.
- **Puzzles 10, 14, 20** do not map one-to-one (`add_rows`, `abs`); they use a different two-tile chain on the same numbers.
- **Puzzle 15.** The player scaled the middle row. Edge ops never touch the centre of a 3x3, and the search found no chain of up to three tiles of any new op that produces the target.
- **Puzzle 17.** The locked `add_rows` changed one middle element. The search found no chain of up to three tiles (counting any replacement locked tile) of any new op that produces the target.
- The comments in converted puzzle files must describe the new ops.

#### Replay proof

All 16 converted puzzles reached `win` headlessly on the real `MatrixScene` run loop, with the new op semantics added to a throwaway copy of the repo. Tiles were set directly on the grid, so UI input is not yet proven. The new UI specs can use these. Puzzle numbers in this table are the **new** ones. Pushers are placed in letter order. At each listed tick the named command is issued and the previously commanded pusher gets `stop` on the same tick (if it is the same pusher, only the new command).

| Puzzle (new) | Pushers A.. | Commands `pusher direction@tick` | Player tiles (cell) | Ticks |
|---|---|---|---|---|
| 3 | (1,2) (9,1) | A right@1, B down@7 | x-1 (5,2) | 11 |
| 4 | (2,1) (1,6) | A down@1, B right@5 | FLv (3,6) | 8 |
| 6 | (1,2) (7,1) (8,6) (5,5) (3,9) | A right@1, B down@5, C left@9, D down@11, E right@14 | x-1 (5,2), FLv (6,5) | 17 |
| 7 | as 6 | as 6 | x2 top (5,2), FLv (6,5) | 17 |
| 8 | (1,2) (7,1) | A right@1, B down@5 | x-1 top (6,2) | 8 |
| 9, 12 | (1,3) (9,1) (10,8) | A right@1, B down@7, C left@13 | x-1 (5,2), FLv (9,5) | 19 |
| 10 | (1,2) (9,1) | A right@1, B down@7 | x4 bottom (5,2), -8 right (7,2) | 11 |
| 13 | (1,3) (7,1) (8,8) | A right@1, B down@5, C left@11 | T (7,5) | 15 |
| 14 | (1,2) (9,1) | A right@1, B down@7 | x4 top (5,2), -4 left (7,2) | 11 |
| 15 | (1,2) (5,1) (6,5) (2,9) | A right@1, B down@3, C left@6, B left@7, B down@8, D right@12 | x-1 (4,2), x2 top (5,3), T (3,7) | 16 |
| 16 | (1,2) (9,1) | A right@1, B down@7 | FLh (5,2), x2 right (7,2) | 11 |
| 18 | (1,2) (7,1) (8,8) | A right@1, B down@5, C left@11 | x-1 right (7,4), x-1 bottom (7,6) | 15 |
| 19 | (1,2) (9,1) | A right@1, B down@7 | fixed x-1 (5,2), fixed FLv (7,2) | 12 |
| 20 | (1,2) (7,1) (8,8) | A right@1, B down@5, C left@11 | none | 15 |
| 21 | (1,2) (7,1) (8,8) | A right@1, B down@5, C left@11 | T (7,4), x-1 (7,6) | 15 |

### 8. Worlds, files and saved progress

| World | Name | Old puzzles | New puzzles |
|---|---|---|---|
| 1 | Basics | 1-5 | 1-5 |
| 2 | Combos | 6-11 | 6-11 |
| 3 | Advanced | 12-16 | 12-15 |
| 4 | Transforms | 17-20 | 16-18 |
| 5 | Fixed Pieces | 21-23 | 19-21 |

- Delete `15_scale_swap.lua` and `17_add_rows.lua`. Rename later files so the numeric prefix equals the new index.
- Five worlds remain, so unlocking logic, world tabs, cutscene files (`world_0/2/3`), their text and the seen flags are unchanged.
- The recap's "Next puzzle", the `Puzzle N/M` hint and level select all derive from the loader, so they need no change.
- **Save migration.** `progress.lua` stores puzzle indices, so renumbering would credit the wrong puzzles. Write a version marker (`version=2`). A save without it (either existing format) is remapped once on load: 1-14 unchanged; 15 and 17 dropped; 16→15; 18→16; 19→17; 20→18; 21→19; 22→20; 23→21. A versioned save is not remapped. Cutscene flags are copied as they are. A player who had unlocked a world keeps it, because deleted puzzles also leave the requirement.

### 9. Tests

CLAUDE.md forbids editing tests just to make them pass. Only the expectations below are obsolete, each because the user removed the feature or the puzzle it describes. The verifier must list every edit with that reason. Where a test's intent survives and it merely used a removed op as a prop, swap in an equivalent (`negate` → `scalar_mul` with `scalar=-1`) and keep the assertions. Anything not listed that fails is a game bug.

| File | Obsolete part | Reason |
|---|---|---|
| `test_param_popup.lua` | whole file | module removed |
| `test_matrix_math.lua` | `scale_row`, `add_rows`, `swap_rows`, `negate`, `add_matrix`, `sub_matrix`, `mul_matrix`, `set_row`, `scale_col`, `swap_cols`, `add_cols`, `set_col`, `abs` sections | methods removed |
| `test_multi_op_puzzles.lua` | whole file | uses removed methods, and its numbers already differ from the shipped puzzle data; replace with chains from the real puzzle files |
| `test_pushers.lua` | `apply_op` blocks and assertions for removed ops (including the row-clamp and same-row no-op lines in the first block) | ops removed. `scalar_mul`, `transpose`, flips, rotate and unknown-op blocks stay |
| `test_pusher_scene.lua` | `-I` and `<>R` palette labels; fixed `swap_rows` param test; `load(23)` / `scale_row` locked tests (now puzzle 21, `edge_scale`); `negate` props in two movement tests | ops removed, puzzle renumbered |
| `test_solution_recap.lua` | `negate` prop; "multi-cell scale_row" wording | op removed, no multi-cell ops |
| `test_matrix_coverage.lua` | `mul_matrix` placement and both `set_row` click sections | ops removed |
| `test_matrix_draw.lua` | `add_matrix` ghost prop; resize-strip section | resize removed |
| `test_row_op_delete_resize.lua` | ref-cell erase, resize and row-clamp cases | no multi-cell or resizable ops. Keep the erase and "param click without eraser" intent on new ops |
| `test_drag_ops.lua` | multi-cell drag case | no multi-cell placeable tile |
| `test_palette_layout.lua` | puzzle 1 overflow block; puzzle 21 fixed-only block (now 19) | palette fits; renumbered. Cover scrolling with a synthetic definition |
| `test_world_select.lua` | `count() == 23` | now 21 |
| `test_worlds.lua` | puzzle 21 has empty ops | now puzzle 19 |
| `ui/04_sweep_all_puzzles.lua` | puzzle 1 scroll assertions | palette fits |
| `ui/06_solve_routed_puzzle.lua` | clicking `-I` | place `xk`, lower k to -1 |
| `ui/08_matrix_scene_ops.lua` | all specs | every spec targets removed ops or ref cells; rewrite for new tiles |
| `ui/12_editor.lua` | two popup specs; paste round-trip input containing `scale_row` | popup and op removed |
| `ui/12_puzzle_bar_dnd.lua` | the three `palette:scroll_down` clicks | no scroll arrows now; the rest of that spec stays |

New coverage needed:

- **Unit:** each op, all four edges, non-square and one-row/one-column matrices, k = 0, negative results, no `-0`; progress migration (both old formats, versioned save untouched); every shipped puzzle uses only supported ops and params; recap draws edge tiles.
- **UI specs (real input only):**
  1. Place each k tile; left/right thirds change k and clamp at both limits; middle does nothing on a whole tile.
  2. Middle third cycles an edge tile top → right → bottom → left → top; k is kept.
  3. A rotated edge tile changes exactly that edge during a run (`assert_matrix`).
  4. Fixed tile (puzzle 19) and locked tile (puzzle 21, cell 5,3) ignore all three thirds.
  5. Move with `Mv` keeps k and edge; eraser removes a tile from the middle third.
  6. Win each converted puzzle with the replay table through palette, cell, drag and Run input (include the fixed palette buttons).
  7. Editor: edit k and direction by thirds, eraser on a k tile, Copy then Paste preserving edge and k, and rejection of an old-op definition.

`assert_tile` today compares only `kind`, `op` and `dir`. Extend it and both scenes' `ui_tile` with `edge` and `scalar` so specs can check state, and also assert drawn text for what the player sees.

## What stays the same

- Pushers, timeline, pusher physics, run/step/reset, win/fail/blocked/stuck rules, op firing order and re-arm logic.
- `transpose`, `rotate_90`, `flip_h`, `flip_v` behaviour and labels, including the footprint check after a shape change.
- Source, sink, gap and puzzle routes; grid size; scene layout; ops-column geometry.
- `ops` list semantics (nil means all, empty means none), `locked` entry shape (`kind`, `op`, `x`, `y`, `params`).
- World count, names, unlock rule, cutscenes, level select, settings, music.
- Recap flow and stats.

## Open questions

Each has a recommended default; the doc is written assuming it.

1. **Delete puzzles 15 and 17, or rewrite their numbers?** Recommended: delete, as instructed. A rewrite would need new matrices (for 15, for example, scaling the bottom row instead of the middle one), which makes a different puzzle.
2. **Puzzles 10, 14 and 20 only work through a different chain.** Recommended: convert (same numbers, still two tiles, verified), and rename 20 to "Double Negative". Delete them instead if "map directly" was meant strictly; that leaves world 4 with two puzzles and shifts the numbering and save map again.
3. **Puzzle 19's fixed negate.** Recommended: `fixed_ops` entries with preset params. Alternative: default `xk` to -1 everywhere and keep string entries.
4. **Default k.** Recommended: scale 2 (current behaviour), add 1, subtract 1.
5. **Migrate saved progress?** Recommended: yes (section 8). Skipping it is simpler but credits wrong puzzles to existing players.
6. **Editor popup and old definitions.** Recommended: delete the popup, reject pasted definitions that use removed ops.
7. **Palette labels.** Recommended: `xk^` / `+k^` / `-k^` for edge ops. Any distinct short text works.
