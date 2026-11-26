# Two Sources and Matrix Operand Ops

## Goal

Let one matrix be the parameter of an operator on another. Some puzzles get a **second source**, so two matrices are on the board and pushers can shove either one. Two new ops, **matrix add** and **matrix multiply**, take both matrices as inputs and merge them into one. Invalid combinations end the run with a red banner, like a sink mismatch or a blocked matrix.

### Decisions made by the user (final)

- Some puzzles have two sources. Pushers shove either matrix.
- Only the add and multiply ops are two-cell tiles, with a left-operand cell and a right-operand cell. They fire once both cells are covered, each by a different matrix. One matrix waiting on an input just sits there.
- Multiply is always left operand x right operand.
- The run fails with a red banner for: incompatible shapes (the message gives the sizes, e.g. "FAIL — can't multiply 2x3 by 2x2"), one matrix covering both inputs, and two matrices pushed into each other.
- The result takes the left-operand matrix's top-left position and the right one is consumed. If the result does not fit there, the existing "matrix is blocked" failure applies.
- There is still one sink. Any matrix touching it ends the run, so an uncombined one fails.
- Other ops work on either matrix as they do now.
- The editor can place the second source and the new tiles. Copy, Paste and Test work.
- A new world with 3-4 two-source puzzles.
- The tiles can be locked by puzzle authors or placed by the player.
- The tiles can be rotated, with four orientations. The left-operand and right-operand cells keep their identity.

**Interpretation:** "left cell" and "right cell" name the **operand**, not a screen direction. Rotated, the left-operand cell may be above, below or to the right of the right-operand cell. It is still the left operand.

### History

PR #74 (`docs/archive/design/simplified-ops.md`) removed grid-valued matrix ops and multi-cell op tiles so that every tile has at most one number. This feature brings back multi-cell op tiles in a narrower form: the tile stores no values, and its operands are the travelling matrices. The one-number rule still holds. The old `add_matrix` / `mul_matrix` behaviour (stored operand, silent clamping, element-wise multiply) is not revived. `docs/design/multi-cell-op-tiles.md` is stale and unrelated to this design.

## Affected files

| File | Why |
|---|---|
| `lua/game/ops.lua` | The two new ops, their orientation, labels and validation, kept apart from the ten classic ops |
| `lua/game/matrix_math.lua` | Matrix add and matrix multiply |
| `lua/game/pusher_sim.lua` | Movement with two matrices; matrix-to-matrix collision |
| `lua/game/grid.lua` | Two-cell tiles in any orientation: place, find, clear, move |
| `lua/game/op_tile.lua` | Shared two-cell drawing with distinct left and right cells |
| `lua/game/scenes/matrix_scene.lua` | Second source, two travelling matrices, firing and failures, placement, rotation, drag and move, palette, status messages |
| `lua/game/hud.lua` | Show both inputs |
| `lua/game/scenes/editor_scene.lua` | Second source, second input matrix, new tiles, rotation, allowlist, Copy/Paste/Test, layout |
| `lua/game/scenes/solution_recap_scene.lua` | Replay two matrices and the merge |
| `lua/headless/ui_runner.lua` | Assert both matrices and a tile's orientation |
| `data/puzzles/06_two_sources/*.lua` (new) | The new world |
| `tests/`, `tests/ui/` | New tests and specs |
| `README.md`, `docs/testing.md` | Rules, controls, element ids, puzzle and world counts (verification phase) |

No change expected: `puzzle_loader.lua`, `progress.lua`, `level_select_scene.lua`, `def_parser.lua` (it already reads the new fields), `timeline.lua`, `palette.lua`.

## What changes

### 1. Puzzle format

All additions are optional. Existing puzzle files stay valid and unchanged. Progress is saved by puzzle id, so no save migration is needed.

```lua
source  = { x=2, y=2 },   input  = { rows=2, cols=2, values={...} },
source2 = { x=2, y=7 },   input2 = { rows=2, cols=2, values={...} },
ops     = { "matrix_mul", "transpose" },
locked  = { { kind="op", op="matrix_add", x=6, y=5, params={ facing="bottom" } } },
fixed_ops = { { op="matrix_mul", params={ facing="right" } } },
```

- `source2` and `input2` come together. A puzzle has at most two sources. An additive pair of fields is used instead of a list so old files and the editor's old output need no conversion.
- Both source footprints must be on the grid and must not overlap each other, gaps, the sink or locked tiles. Shipped puzzles are tested for this.
- New op ids are `matrix_add` and `matrix_mul`. For these tiles `x, y` is the **left-operand cell**. `params.facing` is the side of that cell on which the right-operand cell sits: `right` (default), `bottom`, `left` or `top`. Both cells must be on the grid and free.
- Locked entries must still not set `width`, `height`, `tile_rows` or `tile_cols`. The footprint follows from the op and `facing`.
- **A puzzle with no `ops` list keeps offering exactly the ten classic ops.** The new ops appear only when listed in `ops`, `fixed_ops` or `locked`. Existing puzzles, their palettes and the tests that pin the ten-op set stay as they are.

### 2. The two-cell tile

| Op id | Label | Valid when (L = left operand, R = right operand, rows x cols) | Result |
|---|---|---|---|
| `matrix_add` | `M+` | L and R have the same rows and cols | element-wise L + R |
| `matrix_mul` | `Mx` | cols of L = rows of R | matrix product L x R, size rows(L) x cols(R) |

- One tile over two orthogonally adjacent cells, drawn as one joined shape with a shared outer border.
- The two cells must be tellable apart at a glance in every orientation: each shows a large **L** or **R** and its own shade; the operator symbol is on both. Text stays upright.
- A matrix hides the tile under it, so a covered input cell keeps a small L or R badge drawn on top of the matrix. Otherwise the player cannot see which operand a waiting matrix is.
- The tile counts as one piece. Pushers walk over it like any op tile. Locked and fixed markers appear once per tile.

### 3. Placing, rotating, moving, erasing (game and editor)

The existing rotation convention is the edge op: clicking a placed tile turns it clockwise. Pushers are not rotated, and there is no keyboard rotation today.

| Action | Result |
|---|---|
| Click or drop a new tile on a cell | The left-operand cell goes there; the right-operand cell follows the tool's current orientation. Both must be on the grid and empty, otherwise nothing is placed. Nothing is overwritten |
| Click either cell of a placed, editable tile | Turns clockwise (`right`, `bottom`, `left`, `top`) around the left-operand cell, skipping orientations whose cell is off the grid or occupied. If none is free, nothing happens. Any third of the cell does the same |
| Click the already selected `M+` / `Mx` palette button again | Turns the tool's orientation clockwise before placing. A drag that starts on the button does not turn it. The button label shows the arrow |
| Press `T` | Turns, in this order of priority: the tile being dragged; else the placed editable tile under the cursor; else the selected two-cell tool |
| Eraser click or right-click on either cell | Removes the whole tile |
| **[Mv]** drag from either cell (game) | The whole tile moves and keeps its orientation. The grabbed cell stays under the cursor. Release on an invalid spot, or right-click, restores the original position and orientation |
| Any other tool clicked on either cell | Turns the tile; an op tile is never replaced |

- Drag previews (from the palette and in **[Mv]**) show both cells, green when the drop is valid and red when not.
- Locked tiles cannot be turned, moved or erased in the game. Fixed (`!`) tiles can be placed, moved and erased but not turned, matching the existing fixed rule. Their preset orientation is shown on the palette button.
- Each new tile tool starts at `right`; loading a puzzle resets it.
- Rotation adds no new buttons, so the element registry gains only the new palette entries and every grid cell is already registered. `T` does nothing to classic ops, and types normally while the editor name field is focused.
- As today, grid edits are allowed during a run (except **[Mv]**). The simulation uses the board as it is on each tick.

### 4. Movement with two matrices

Each tick keeps today's structure, applied per matrix.

- Pushers are classified from start-of-tick positions. A pusher stepping into a matrix cell pushes that matrix only.
- Forces are combined per matrix: same direction counts once, perpendicular makes a diagonal move, opposing is "blocked". Both matrices move at the same time, judged on final positions.
- There is **no chain pushing**: a matrix never shoves another.
- The run fails with **"FAIL — matrices collided"** if the two would overlap after the move, or would exchange places (each moving into cells the other started in). The diagonal corner cells of a moving matrix must also be clear of the other matrix.
- Following is allowed: one matrix may move into cells the other leaves on the same tick, just as a pusher may step out of the way. Matrices may touch edge to edge.
- Wall, gap, edge and pusher problems keep "matrix is blocked", and take precedence over a collision. No pusher may end a tick inside a matrix it was not pushing, and no two pushers may land on one cell.
- Any failed move rolls back the whole tick for both matrices and all pushers.

### 5. Firing order and failures

After movement, each tick resolves in this order. The first failure ends the run and nothing later may overwrite it.

1. **Single-cell ops.** Each matrix fires the ops it newly covers, independently of the other, top-left first. Fired and re-arm state is per matrix: a tile fired by one matrix fires again for the other. After each op the changed matrix must still fit ("blocked") and must not overlap the other matrix ("matrices collided").
2. **Two-cell ops**, judged on the footprints after step 1, in reading order of their left-operand cell:
   - one matrix covers both cells: **"FAIL — one matrix on both inputs"**;
   - each cell is covered by a different matrix: check shapes, else **"FAIL — can't multiply 2x3 by 2x2"** or **"FAIL — can't add 2x3 and 2x2"** (left operand first);
   - one or no cell covered: nothing. A matrix may wait indefinitely.

   All "both inputs" violations are checked before any merge happens.
3. **Merge.** The right-operand matrix is removed. The result takes the left-operand matrix's top-left position. It must fit there (grid, gaps, pushers), else "matrix is blocked". The consumed matrix's cells count as free.
4. **Sink**, judged on the footprints after steps 1-3. If any matrix touches it the run ends: with two matrices left, **"FAIL — matrices not combined"** (even if one equals the target); with one, win or "matrix mismatch" as today.
5. **Stuck**, as today.

Further rules:

- Two-cell ops react to coverage, not to entry, so the order in which the matrices arrive does not matter.
- After a merge, every two-cell tile the result covers is disarmed until the result no longer covers either of its cells. Without this, a product that spills onto the second cell of its own tile would fail immediately.
- Single-cell tiles the result newly covers because of its shape do not fire until it leaves and re-enters, matching how rotation and transpose behave today. Tiles the left matrix already covered stay fired.
- Ops under the starting footprints are evaluated when the run starts, including two-cell ops. As today, the sink is not checked at that moment.
- After a merge the game behaves exactly like a single-source puzzle.
- In a single-source puzzle a two-cell tile can never merge anything: a matrix may sit on one input, and covering both fails.

**Bug fixed on the way:** today, if an op leaves the matrix blocked on a tick where it also touches the sink, the sink check overwrites "blocked" with a win or mismatch (`matrix_scene.lua`, `do_step`). With the ordering above, an op failure is final. This applies to single-source puzzles too and needs its own test.

### 6. What the player sees

- Two-source puzzles label the sources `SRC 1` and `SRC 2` (letters are taken by pushers) and preview both input matrices while idle. The second matrix has a different border colour; a result keeps the left operand's colour.
- The side panel shows `INPUT 1` and `INPUT 2` side by side, then `TARGET`. Three stacked matrices do not fit. Single-source puzzles look as they do now.
- As today, matrices slide in with their old values and results appear on arrival. For a merge, both slide in, then the result replaces them. On a failure that happens at the op step, both stay visible where they stopped.
- All new banners are red and shown in the existing banner area. Their text must fit it.
- A failed move (blocked or collided) leaves everything at the previous position, as today.

### 7. Solution recap

The replay animates both matrices and the pushers together, shows the merge at the tick it happened, and shows only the result afterwards. If the merge happens on the final tick, the end-of-loop hold shows the result, so the replay never ends without it. The new tiles are drawn in their orientation. Single-source recaps are unchanged.

### 8. Palette space

- **Game:** `M+` and `Mx` join the shape-op group with no new separator. All twelve ops plus tools then end at y = 510 (limit 512). A separate group would overflow. Fixed ops can still overflow into the existing scrolling.
- **Editor:** the bar needs three new buttons (`SRC2`, `M+`, `Mx`) but has room for one. Move **Back / Test / Copy / Paste** to the right end of the bar and keep button sizes. Element ids do not change.

### 9. Editor

- `SRC2` places the second source and behaves like `SRC`. The puzzle has two sources only while `SRC2` is on the grid; without it, Copy and Test produce a single-source definition.
- Two selector buttons on the `INPUT` heading row switch the matrix section between input 1 and input 2 (both always selectable). This adds no height; there is no room for a third matrix section.
- Resizing an input refits its source as today. If it no longer fits, or would overlap, that source is removed.
- The two new tiles are placed and rotated as in section 3, exported as locked and stay editable in the editor. Erasing any cell removes the whole tile.
- The allowlist gains toggles for the two ops. `ops` is omitted only when the selection means "the ten classic ops" (nothing toggled, or exactly those ten). Any other selection, including one with a matrix op, is written out in full.
- Copy writes `source2`, `input2` and `facing`. Paste restores them, defaults a missing `facing` to `right`, and rejects with a message, leaving the editor unchanged: only one of `source2` / `input2`, a malformed `input2`, or an unknown `facing`. A tile that overlaps another or leaves the grid is skipped whole, matching how Paste treats overlaps today.
- `fixed_ops` is still preserved but not editable in the editor.

### 10. New world

`data/puzzles/06_two_sources/` (tab "Two Sources"), puzzles numbered from 22, in rising difficulty:

1. First sum: `M+` locked on the board, teaching the two inputs.
2. Player-placed `M+`, needing rotation.
3. Multiply with non-square inputs, where the operand order matters.
4. A merge combined with classic ops and gaps.

Each has a documented reference solution that a test runs. At the end of the list, the world opens once all earlier puzzles are solved, so existing saves behave correctly.

### 11. Testing

- Unit tests: add and multiply, shape rules and messages; two-matrix movement (independent, following, head-on, exchange, diagonal, rollback); firing order, per-matrix re-arm, merge fit, every failure, sink cases and the bug fix; format validation and editor round trip.
- UI specs through real input: win a two-source puzzle through to the recap; place, rotate (click, palette button, `T`), move and erase the new tiles; a shape-mismatch banner; editor build, Copy, Paste and Test.
- The runner needs a way to assert each matrix on the board and a tile's `facing`. Existing step forms keep their meaning.
- Every frame's layout invariants cover the new buttons. Coverage of `lua/game/` stays at 100%.
- Rendering (L/R distinction, badges, colours, text fit, narrower side panel) must be checked by running the game, since headless tests cannot see it.

## What stays the same

- Single-source puzzles: files, palettes, movement, firing, visuals and saved progress. The only behaviour change is the blocked-overwritten bug fix.
- Existing tests and specs pass **without edits**. Several use the scene and sim state of a one-matrix run directly, so that must remain valid.
- The ten classic ops, including edge rotation and click-in-thirds editing.
- One sink, one target, the timeline, pushers (up to 8) and the gap rules.
- `R`, `Backspace`, `Enter` and `Esc` keys.
- Locked world and unlock rules.

## Open questions

None. The user approved these recommendations:

1. **Crossing a two-cell tile:** the "one matrix on both inputs" rule is strict. Any matrix covering both cells fails, including one that is only passing over.
2. **Fixed (`!`) two-cell tiles** cannot be turned.
3. **Rotation key** is `T`.
4. **New world** ships without a cutscene.
