## Two Sources and Matrix Operand Ops Checklist

Design: `docs/archive/design/matrix-operand-ops.md` (owns what and why). This file owns how. Read both, plus `CLAUDE.md` and `docs/testing.md`, before starting. "Section N" below means a section of the design doc.

### Rules for every task agent

- Work only in `/tmp/claude-wt-c87555`. **Do not commit**, stash, switch branches or run other git commands that change state.
- Edit only the files your task lists. All agents share one worktree.
- Waves run in order; tasks inside a wave run in parallel. Start a task only when every earlier wave is complete.
- **Green gate: after each wave** both `love . --headless` and `love . --headless --coverage` exit 0 (100 % of `lua/game/`). Baseline before wave 1: 185/185.
- While siblings are running: iterate with single-file runs (`love . --headless tests/test_x.lua`, `love . --headless tests/ui/NN_x.lua`). Create each new test file in one complete write, only when the code it tests is in place, because the full run picks up every file. Keep every Lua file you edit loadable after each edit. Finish with the full suite and coverage; if a failure is only in files a sibling owns, re-run later and report it, do not fix it. Check that your own files have no uncovered lines (`love . --headless --coverage --verbose-gaps`).
- The coverage run takes several minutes: run it in the background or with a long timeout.
- Never edit an existing test or spec. Add new test files with exactly the names given.
- Every UI spec drives real input. Specs that need a custom puzzle set `make_scene = function(sm) return require("lua/game/scenes/matrix_scene").new_from_def(def, sm) end` on the spec table. Calling private methods does not count as UI coverage.
- Every interactive element appears in `ui_elements()` and clicks hit-test through `UI.element_at`. Lay out with constants, never `font:getWidth`.
- README, `docs/testing.md` and archiving belong to the verification agent.
- When done, change your item to `[x]` (edit only your own line).

### Shared contract

These names are fixed. Later tasks rely on them without reading how earlier tasks implemented them.

**Puzzle def** (all optional, section 1): `source2 = {x,y}`, `input2 = {rows,cols,values}`, ops `"matrix_add"` / `"matrix_mul"`, `params = { facing = "right"|"bottom"|"left"|"top" }`. A locked or placed two-cell tile's `x,y` is the left-operand cell.

**Tile** on a grid: `{ kind="op", op="matrix_add", params={facing="right"}, locked=, fixed= }`. It is stored at the left-operand cell (the anchor); the right-operand cell holds `{ ref=true, ax=, ay= }`, so `grid:get` on either cell returns the tile.

**`Ops` (`lua/game/ops.lua`)**. `Ops.ORDER` stays exactly the ten classic ops (existing tests pin it).

| Member | Contract |
|---|---|
| `Ops.MATRIX_ORDER` | `{ "matrix_add", "matrix_mul" }` |
| `Ops.FACINGS` | `{ "right", "bottom", "left", "top" }` (clockwise) |
| `Ops.OFFSETS` | `right={dx=1,dy=0}`, `bottom={dx=0,dy=1}`, `left={dx=-1,dy=0}`, `top={dx=0,dy=-1}` |
| `Ops.is_op(op)` | true for classic and matrix ops |
| `Ops.is_two_cell(op)` | true only for the two matrix ops |
| `Ops.label(op)` / `Ops.tile_text(op)` | `"M+"`, `"Mx"` |
| `Ops.params(op, overrides)` | matrix ops: `{ facing = overrides.facing or "right" }` |
| `Ops.validate(op, params)` | bad facing: `false, "Invalid facing: <value>"` |
| `Ops.next_facing(f)` | clockwise successor |
| `Ops.partner(x, y, facing)` | `px, py` of the right-operand cell |
| `Ops.tool_label(op, facing)` | label plus `Ops.ARROWS[facing]`, e.g. `"M+>"`, `"Mxv"` |
| `Ops.fixed_label(op, params)` | matrix ops: `"M+>!"` |
| `Ops.click(op, params, part)` | does nothing for matrix ops (turning needs the grid) |
| `Ops.merge_error(op, L, R)` | nil when shapes fit, else exactly `"FAIL — can't multiply 2x3 by 2x2"` or `"FAIL — can't add 2x3 and 2x2"` (left first) |
| `Ops.combine(op, L, R)` | the result `Matrix`; inputs unchanged |

**`Matrix`**: `Matrix:add(other)`, `Matrix:mul(other)` return new matrices.

**`Grid`**:

| Method | Contract |
|---|---|
| `Grid:fits(x, y, tile)` | true when every cell the tile would occupy (one, or two by `tile.params.facing`) is in bounds and empty |
| `Grid:put(x, y, tile)` | writes a one- or two-cell tile at anchor `x,y` (anchor and partner must be in bounds; callers check `fits`) |
| `Grid:rotate(x, y)` | given either cell of a two-cell tile, turns it to the next clockwise facing whose partner cell is in bounds and empty; returns true if turned, else false and no change. Ignores locked/fixed (the caller checks) |
| `Grid:two_cell_tiles()` | array of `{ x, y, rx, ry, tile }` in reading order of the left-operand cell (y, then x) |
| `Grid:clear(x, y)` | on either cell removes both; locked tiles stay |

**`TwoCell` (new `lua/game/two_cell.lua`, pure)**. A body is any table `{ x, y, matrix }`. `tiles` is the `two_cell_tiles()` list. `disarmed` is a set keyed `"x,y"` of the left-operand cell.

- `TwoCell.covers(body, cx, cy)` → boolean.
- `TwoCell.judge(tiles, a, b, disarmed)` (`b` and `disarmed` may be nil) → nil, or `{ status="both_inputs" }`, or `{ status="bad_shape", message=<merge_error> }`, or `{ entry=<tile entry>, left=<a or b>, right=<a or b>, matrix=<result> }`. Disarmed tiles are ignored. All armed tiles are checked for one body covering both cells before any shape check or merge; then the first tile in list order with each cell under a different body decides.
- `TwoCell.disarm(disarmed, tiles, body)` adds every tile with either cell under `body`.
- `TwoCell.rearm(disarmed, tiles, body)` removes every key whose tile has neither cell under `body`, and keys with no tile.

**`Sim.advance(st, commands)`**: optional `st.second = { x, y, rows, cols }`; returns `moved, blocked, collided`. `collided` implies `blocked`.

**`MatrixScene` run state**: the primary matrix stays in the existing fields (`sim.x`, `sim.y`, `current_matrix`, `occupied_ops`, `_last_fp`, `_anim_display_matrix`, `anim_from_*`, `anim_to_*`); it is source 1's matrix, and after a merge the result. The other one: `sim.second = {x,y}` (nil when single or merged), `second_matrix`, `second_fired`, `_second_fp`. Also `input2_matrix` (nil in single-source), `_tag` (1 or 2, colour of the primary), `disarmed`, `status_message` (banner text overriding the status label).

**Status keys and banners** (all red): `collided` "FAIL — matrices collided"; `both_inputs` "FAIL — one matrix on both inputs"; `bad_shape` (text from `status_message`); `uncombined` "FAIL — matrices not combined". `blocked`, `fail`, `win`, `stuck` unchanged.

**Scene queries**: `scene:ui_matrices()` → array of `{ x, y, values }` for the matrices shown now (primary first, then second); `x,y` is the logical grid cell of the top-left. `scene:ui_tile(x, y)` also returns `facing` and `index` (source tiles: 1 or 2 when there are two sources, else nil).

**Run frame** (`_run_frames[i]`, read by the recap): existing `from_x, from_y, to_x, to_y, matrix, pushers_from, pushers_to` describe the primary (pre-op values, pixel coordinates). New: `tag` (1|2); `second = { from_x, from_y, to_x, to_y, matrix, tag }` on every tick that starts with two matrices (including the merge tick); `merged = { x, y, matrix, tag }` (pixels) only on the merge tick, the result that replaces both on arrival. On the merge tick the primary fields are source 1's pre-op motion even if source 2 is the left operand. Frames after the merge have neither `second` nor `merged`, and `tag` is the left operand's.

**Matrix border colours**: `MatrixScene.GEOM.MATRIX_BORDER = { [1] = {0.91,0.73,0.15}, [2] = {0.25,0.80,0.90} }`.

**New element ids**: `palette:matrix_add`, `palette:matrix_mul`, `palette:fixed:matrix_add`, `palette:fixed:matrix_mul`; `editor:pal:source2` (label `SRC2`), `editor:pal:matrix_add`, `editor:pal:matrix_mul`; `editor:input_sel:1`, `editor:input_sel:2` (labels `#1`, `#2`); `editor:allow_matrix:matrix_add`, `editor:allow_matrix:matrix_mul`. The matrix toggles must **not** use the `editor:allow:` prefix: `tests/test_editor_ops_label.lua` asserts exactly ten of those.

---

### Wave 1 (parallel)

- [x] Task 1: rules foundation — `lua/game/ops.lua`, `lua/game/matrix_math.lua`, `lua/game/grid.lua`, `lua/game/op_tile.lua`, new `lua/game/two_cell.lua`, new `tests/test_matrix_ops.lua`
  - Implement the `Ops`, `Matrix`, `Grid` and `TwoCell` contracts above (sections 2, 3, 5). `ops.lua` stays free of LOVE calls. Do not change anything about the ten classic ops, `Grid:set`, `set_multi`, `set_multi_2d` or source clearing.
  - `Grid:clear` currently finds ref cells by scanning right; two-cell tiles facing left, bottom or top must clear both cells too.
  - `OpTile.draw(tile, sx, sy, cs, fonts, opts)`: same signature; for a two-cell tile `sx,sy` is the left-operand cell's top-left and it draws both cells (partner at `Ops.OFFSETS`): two distinct shades, one shared outer border around the pair, a large upright `L` / `R` and the op label in each cell. Create and cache the large font inside `op_tile.lua` so callers pass nothing new. `opts.marks` adds nothing for these tiles. Add `OpTile.draw_badge(role, sx, sy, cs, font)` (`role` = `"L"`|`"R"`): a small badge in a cell corner, drawn on top of a matrix.
  - Tests: add and multiply (including non-square, negative, `-0`), shape messages, every `Ops` row, all four facings for `fits`/`put`/`rotate` (edge and occupied skipping, none free)/`clear`/`two_cell_tiles`, every `TwoCell` outcome including the ordering rules, and the texts drawn for a pair and a badge.

- [x] Task 2: two-matrix movement — `lua/game/pusher_sim.lua`, new `tests/test_two_matrix_sim.lua`
  - Implement section 4 in `Sim.advance` when `st.second` is set; mutate `st.second.x/y`. Without `st.second`, behaviour is exactly as today (including which pushers stay moved on a blocked tick with no push).
  - Classify pushers from start positions; a contact pushes only the matrix whose start footprint it steps into. Combine forces per matrix (dedupe, opposing = blocked, perpendicular = diagonal). Contact pushers of both matrices must land on distinct cells. Move both, then judge non-contact pushers against both final footprints.
  - Pusher-inside rule: for each matrix **that moved**, no pusher other than that matrix's contacts may be inside its final footprint.
  - Collision: final footprints overlap; or exchange (both moved, each final footprint overlaps the other's start footprint); or a diagonally moving matrix's corner cells (same two cells as the existing corner check) lie inside the other's **final** footprint.
  - Precedence: wall, gap, edge, opposing and pusher problems give `blocked, collided=false`. One exception: when there is a collision, a contact pusher of one matrix lying inside the other does not count as a pusher problem (otherwise a head-on exchange could never report "collided").
  - With `st.second`, any blocked or collided tick restores both matrices and all pushers and returns `moved=false` (pusher `dir`s and `tick` advance as today).
  - Do not `require` anything new; no dependency on Task 1.
  - Tests: independent moves, diagonal, following into vacated cells, touching edge to edge, head-on, shove into a stationary matrix (no chain push), exchange, diagonal corner, pusher precedence, shared landing cell, rollback of a successful move on the other matrix.

- [x] Task 3: runner steps — `lua/headless/ui_runner.lua`, new `tests/test_ui_runner_matrices.lua`
  - New step `assert_matrices = { { x=, y=, values={{...}} }, ... }`: compares `scene:ui_matrices()` by count and order; `values` required, `x`/`y` compared only when given. Errors: `scene has no matrices`, `matrices are <serialised>, expected <serialised>`.
  - `wait_until` also accepts `matrices = ...` with the same matching.
  - `assert_tile` also compares `facing` and `index` when given.
  - New steps `mouse_down = <selector>` and `mouse_up = <selector>`: settle, move to the element centre, press (or release) button 1, run one frame. They allow a key press or right-click while a drag is held.
  - Existing steps keep their meaning. Test with fake scenes through `UIRunner.run_spec(spec, { make_scene = ... })` as `tests/test_ui_runner.lua` does.

- [x] Task 4: two inputs in the side panel — `lua/game/hud.lua`, new `tests/test_hud_two_inputs.lua`
  - `HUD:draw(input_mat, target_mat, puzzle_name, input2_mat)`. With `input2_mat`: `INPUT 1` and `INPUT 2` side by side (each centred in half of the panel width), then the arrow and `TARGET` below the taller of the two. Without it: output identical to today. Still returns the y below the divider. A 4x4 pair must fit the 610 px panel and end above y 540.

### Wave 2

- [x] Task 5: two-source runs — `lua/game/scenes/matrix_scene.lua`, new `tests/test_two_source_run.lua`, new `tests/ui/19_two_sources_run.lua`
  - Scope: loading, running, failures, drawing and queries (sections 1, 5, 6). Palette, placement, rotation and dragging are Task 6; do not add them.
  - `load_puzzle`: build `input2_matrix`; place the second source; source tiles get `index = 1|2` only when `source2` exists and are labelled `SRC 1` / `SRC 2` (else `SRC`). Place locked two-cell entries after sources, sink and gaps with `grid:put`, skipping any that fails `grid:fits`. Draw: `draw_ref_cell` is only for source refs (today every ref cell is painted as source). Clear all new state in `load_puzzle`, `do_reset` and `start_run`.
  - `start_run`: set up both bodies; if the two source footprints overlap, end with `collided`; otherwise evaluate ops under the starting footprints, single-cell then two-cell. No sink check.
  - `do_step`: pass `st.second` to `Sim.advance`; on `blocked` set `collided` or `blocked` and leave everything where it was. Then, in order, stopping at the first failure: (1) single-cell ops, source 1's matrix fully then source 2's, top-left first within each, with per-matrix fired/re-arm state; two-cell tiles are never applied here; after each op check `Sim.footprint_clear` (`blocked`), then overlap with the other matrix (`collided`). (2) `TwoCell.rearm`, then `TwoCell.judge`. (3) Merge: the result takes the left operand's top-left; if `footprint_clear` fails, `blocked` and both stay uncommitted; otherwise the result becomes the primary, `sim.second` is cleared, `_tag` = left's tag, fired set = left's (limited to cells the result covers), `_last_fp` = the result's footprint (so newly covered single tiles wait for re-entry), and `TwoCell.disarm` for the result. (4) Sink: any matrix cell on it ends the run: two matrices → `uncombined`; one → `win`/`fail`. (5) Stuck.
  - Bug fix (section 5): once a step has a failure status, the sink and stuck checks must not overwrite it. Covers single-source too.
  - Keep `_process_footprint(old_fp)` and `get_footprint()` working for the primary with a minimal `sim = {x,y,pushers,gaps}` (existing tests use them that way).
  - Animation: while `anim_t < 1` show pre-op values for every matrix that started the tick, each sliding along its own path; on a merge tick both slide in, then the result appears. Failures at the op step leave both visible where they stopped. Idle: preview both inputs at their sources. Second matrix uses the second border colour; a result keeps the left operand's. After matrices, call `OpTile.draw_badge` for every two-cell tile cell covered by a matrix.
  - Banners, `MATRIX_BORDER`, `ui_matrices()` (idle: both inputs at their sources; `ui_matrix()` still returns the primary), `ui_tile` `facing`/`index`, pass `input2_matrix` to `HUD:draw`, record frames per the contract.
  - Unit tests: both-source loading, per-matrix re-arm, ops that block or collide, start-of-run two-cell evaluation, waiting matrix, arrival order independence, each failure with its banner text, merge into either operand position, merge that does not fit, disarm and re-arm after merge (a product spilling onto its own second cell survives), single-source tile (one input waits, both fails), every sink case, the blocked-overwritten bug in a single-source puzzle, frame fields on and after the merge tick.
  - UI spec (inline defs, locked tiles, pushers placed and chips dragged by real input): win a two-source puzzle, assert matrices before, during and after the merge, click Continue and assert `SOLVED!`; a shape-mismatch run showing the exact banner; reset restores both previews.

### Wave 3

- [x] Task 6: placing and turning two-cell tiles in the game — `lua/game/scenes/matrix_scene.lua`, new `tests/test_two_cell_editing.lua`, new `tests/ui/20_two_cell_tiles.lua`
  - Implement sections 3 and 8 (game).
  - Palette: `M+`, `Mx` follow `flip_v` in the shape group with no new separator, offered only when listed in `ops` (a puzzle with no `ops` list still offers exactly ten); fixed entries come from `fixed_ops` as today. All twelve plus tools must end at y = 510 without scroll arrows. Switching puzzles must drop a selected matrix tool that the new puzzle does not offer, including when it has no `ops` list.
  - `_tool_facing` per matrix op, reset to `right` in `load_puzzle`. The editable button label is `Ops.tool_label(op, facing)` (do not mutate the shared `PALETTE_BUTTONS` tables).
  - Clicking the already selected editable button turns the tool: turn on release over the same button only if the pointer never left it during the press (a drag from the button never turns it); while running, where there is no drag, turn on press. The first click only selects. Fixed buttons never turn.
  - Placement: only when `grid:fits`; never overwrites anything. Clicking either cell of an editable placed two-cell tile with any tool except eraser and `Mv` calls `grid:rotate`; locked and fixed are unchanged. Eraser and right-click remove the whole tile.
  - `Mv`: pick up from either cell; keep which cell was grabbed so it stays under the cursor (ghost remains the mouse cell; anchor = ghost minus the grabbed cell's offset; a nil grab means the anchor, as existing tests assume). Invalid release, release off the grid or right-click restores original position **and** facing.
  - Previews: palette drag and `Mv` drag of a two-cell tile show both cells, green when valid, red when not.
  - Key `t`, ignored while the settings overlay is open. Priority: (1) a drag in progress: a lifted two-cell tile turns freely (editable only; no occupancy check, preview shows validity), a palette drag of an editable matrix tool turns that tool; any other dragged thing: nothing. (2) The editable two-cell tile under the cursor (remember logical coordinates from `mouse_moved`/`mouse_pressed`; do not use `love.mouse.getPosition`): `grid:rotate`, and stop even if it could not turn. (3) The selected editable matrix tool. Classic, locked and fixed tiles under the cursor are not "editable", so fall through to (3). Allowed during a run.
  - UI spec: place by click and by drag; turn by clicking either cell and any third; turn the tool with the button and with `t`; drag from the button does not turn; `t` over a tile and while holding a drag (`mouse_down`/`mouse_up`); invalid placement; `Mv` from the right-operand cell and its cancel; erase from either cell; locked and fixed behaviour; all-twelve palette layout; one run that merges using a player-placed turned tile.

### Wave 4 (parallel)

- [x] Task 7: recap replay — `lua/game/scenes/solution_recap_scene.lua`, new `tests/test_recap_two_matrices.lua`, new `tests/ui/21_recap_merge.lua`
  - Section 7, consuming the run frame contract: draw the primary and `frame.second`, each in `MATRIX_BORDER[tag]` (tag defaults to 1); when `anim_t >= 1` and `frame.merged` exists, draw only the merged result (so the end hold shows it when the merge is the last tick). Source tiles with `index` are labelled `SRC 1` / `SRC 2`. Two-cell tiles already draw through `OpTile.draw`; verify all facings and that ref cells are not drawn over them. Single-source recaps unchanged.
  - Do not edit `matrix_scene.lua`. Unit test with hand-built frames (mid-slide, merge arrival, final-tick hold, loop, replay). UI spec (inline def): win with a merge before the last tick and with a merge on the last tick, Continue, assert `SOLVED!`, click `Replay`.

- [x] Task 8: editor — `lua/game/scenes/editor_scene.lua`, new `tests/test_editor_two_sources.lua`, new `tests/ui/22_editor_two_sources.lua`
  - Sections 3, 8 and 9. Keep `_input` as input 1's table (existing tests set it directly); add `_input2` (default 2x2 identity), `_input_sel` (1|2), `_source2`.
  - Palette: `SRC2` after `SRC`; `M+`, `Mx` after `FLv`, no new separator. Move Back/Test/Copy/Paste to the right end of the bar (first button x = 1280 - 10 - (3*62 + 56) = 1028); sizes and ids unchanged.
  - Selector buttons `#1` `#2` on the `INPUT` heading row (x from the HUD left padding, above the spinner row, no added height), always enabled, `selected` marks the current one, drawn with that highlight. Heading reads `INPUT 1` / `INPUT 2`. Spinners and `editor:input_cell:*` act on the selected input; ids unchanged.
  - Sources: `SRC2` places and refits like `SRC` using input 2; resizing refits only that input's source and removes it if it no longer fits. Erase works from any cell. With `source2` on the grid the tiles get `index` 1/2 (source 1 drawn `SRC 1` only then, else `SRC`); `ui_tile` returns `facing` and `index`.
  - Two-cell tiles: per-op tool facing (reset on load), button label `Ops.tool_label`; clicking the selected button turns it; place only if `grid:fits`; clicking either cell with any non-erase tool, or none, calls `grid:rotate`; erase and right-click remove both cells (editor tiles are `locked`, so `Grid:clear` will not do it). Key `t` (never while the name field is focused): the placed two-cell tile under the cursor (track `mouse_moved`/`mouse_pressed`), else the selected matrix tool.
  - Allowlist: ten classic `editor:allow:<op>` followed by the two `editor:allow_matrix:<op>` in the same grid. `_def_ops`: no matrix op toggled → as today (nil for none or all ten; `{}` for the preserved empty list); any matrix op toggled → the full selection written out, classic in `Ops.ORDER` then matrix in `Ops.MATRIX_ORDER`.
  - `_build_def` and `_serialize` include `source2`/`input2` only while `source2` is on the grid; locked entries carry `facing`. Defaults for a missing source stay as today.
  - Paste: reject before changing anything with exactly `source2 and input2 come together`, `Invalid input2` (not a table, rows/cols not integers 1..4, values not a table of row tables, or a non-number entry) or `Invalid source2` (not a table with integer x and y); unknown facing is rejected by `Ops.validate` (`Invalid facing: ...`) in locked and fixed entries. Missing facing becomes `right`. Load locked entries first (two-cell via `fits`/`put`, skipped whole), then source, source2 (skipped if off grid or overlapping), sink, gaps. A paste without `source2` resets `_input2`, `_source2` and `_input_sel`.
  - Unit tests: round trip (copy, paste, copy gives identical text), every rejection leaves the editor unchanged, `ops` omission rules, resize removal, skipped tiles. UI spec: build a two-source puzzle with a turned tile, Copy, erase, Paste, `assert_tile` both; Test it, add what is needed by real input, run to a merge, return with Menu. Do not click Continue (Task 7 is editing the recap).

### Wave 5

- [x] Task 9: the Two Sources world — new `data/puzzles/06_two_sources/22_*.lua` to `25_*.lua`, new `tests/test_two_source_data.lua`, new `tests/ui/23_two_source_world.lua`
  - Four puzzles per section 10, in this order, with ids that are unique (suggested `22_first_sum`, `23_turned_sum`, `24_operand_order`, `25_merge_maze`), each with a non-empty `name`, an explicit `ops` list (`{}` if the player places nothing), `source2`/`input2`, one sink, and rising difficulty: (1) locked `M+`; (2) player-placed `M+` that cannot be solved with the default `right` facing because of the layout; (3) `Mx` with non-square inputs where swapping operands misses the target; (4) a merge plus classic ops and gaps. No cutscene. The file must parse with `DefParser` (comments are fine).
  - Each file starts with a comment documenting its reference solution (tiles with facing, pusher cells, timeline commands, expected merge), like the shipped puzzles.
  - `tests/test_two_source_data.lua`: for every shipped puzzle with `source2` or a two-cell entry: `source2` and `input2` together; both source footprints on the grid, not overlapping each other, gaps, the sink or locked tiles (both cells of two-cell entries); two-cell entries on grid, free, valid facing. Check the files against each other directly from the defs, since the scene silently overwrites. Also: the world `two_sources` has these four puzzles and is locked until all earlier worlds are solved.
  - `tests/ui/23_two_source_world.lua`: from the title screen, use `tests/support/shipped` helpers (no hardcoded positions) to open each puzzle through level select, enter its reference solution by real input, Run and wait for `WIN!`; for the first also Continue to `SOLVED!`.
  - Do not edit game code. If a puzzle exposes a game bug, report it instead.

## Verification fixes

- [x] Fix 1: `lua/game/scenes/matrix_scene.lua` — with two sources, draw a small `SRC n` tag on top of each idle input preview without hiding its values; single-source visuals unchanged.
- [x] Fix 2: `lua/game/scenes/solution_recap_scene.lua`, `matrix_scene.lua`, `op_tile.lua` — recap draws L/R badges on covered input cells; in game and recap a badge appears only once the sliding matrix is actually over the cell.
- [x] Fix 3: `lua/game/scenes/matrix_scene.lua` — dragging a palette tool (not the eraser) onto a two-cell tile does nothing; clicking still turns it. Check the editor for the same drag path.
- [x] Fix 4: `lua/game/scenes/editor_scene.lua` — with SRC2 placed and no SRC, Copy and Test choose a default source that does not overlap source 2; output without SRC2 unchanged.
- [x] Fix 5: `data/puzzles/06_two_sources/25_merge_maze.lua`, data test, ui spec 23 — sink and winning position out of row 10 (hidden by the status banner).
- [x] Fix 6: `lua/game/scenes/matrix_scene.lua` — after Reset puts back a pusher held by Mv, resync the pushers and selection.
