# Matrix Constant Ops: sub_matrix (−M) and mul_matrix (×M)

## Goal

Add two new op tiles that use the same 2D inline grid visual as `add_matrix`:

- **`sub_matrix` (−M)** — subtracts a constant matrix element-wise from the travelling matrix.
- **`mul_matrix` (×M)** — multiplies the travelling matrix element-wise by a constant matrix.

Both share identical visual mechanics to `add_matrix`: a 2D expandable grid of board cells (1×1 up to 4×4) where each cell shows one element of the operand, edited by left/right click. This design doc covers both together because the implementation delta over `add_matrix` is small.

**Dependency:** Requires the 2D footprint grid changes from `docs/design/visual-matrix-add-tile.md` (the `set_multi_2d`, `in_bounds_multi_2d`, 2D `clear`, expand controls framework).

---

## Affected files

| File | Why touched |
|------|-------------|
| `game/matrix_math.lua` | Add `Matrix:sub_matrix(other)` and `Matrix:mul_matrix(other)` |
| `game/cursor.lua` | Handle `sub_matrix` and `mul_matrix` ops in `apply_op` |
| `game/scenes/matrix_scene.lua` | Add both ops to palette, `OP_SIZES`, `OP_SYMBOLS`; reuse add_matrix drawing and expand paths |

`game/grid.lua` and `game/hud.lua` are **not touched** (2D footprint work already done for `add_matrix`).

---

## What changes

### 1. Op definitions

| Op | Symbol | Default values | Footprint | Operation |
|----|--------|----------------|-----------|-----------|
| `sub_matrix` | `−M` | all 0 | 1×1 → 4×4 | `result[r][c] = current[r][c] − operand[r][c]` |
| `mul_matrix` | `×M` | all 1 | 1×1 → 4×4 | `result[r][c] = current[r][c] × operand[r][c]` |

`mul_matrix` defaults to 1 so a freshly placed tile is a no-op identity (multiplying by 1), not a zero-annihilator.

Tile table structure is identical to `add_matrix`:
```lua
{
  kind = "op",
  op   = "sub_matrix",   -- or "mul_matrix"
  tile_rows = 1,
  tile_cols = 1,
  values = { {0} },      -- {1} for mul_matrix
  locked = false,
  width  = 1,
  height = 1,
}
```

### 2. Matrix math (`matrix_math.lua`)

```lua
function Matrix:sub_matrix(other)
    local m = self:copy()
    for r = 1, math.min(self.rows, other.rows) do
        for c = 1, math.min(self.cols, other.cols) do
            m.values[r][c] = m.values[r][c] - other.values[r][c]
        end
    end
    return m
end

function Matrix:mul_matrix(other)
    local m = self:copy()
    for r = 1, math.min(self.rows, other.rows) do
        for c = 1, math.min(self.cols, other.cols) do
            m.values[r][c] = m.values[r][c] * other.values[r][c]
        end
    end
    return m
end
```

Dimension mismatches clamp to the overlapping region, same as `add_matrix`.

### 3. Cursor (`cursor.lua`)

Add two cases in `apply_op`, parallel to `add_matrix`:

```lua
elseif tile.op == "sub_matrix" then
    local addend = Matrix.new(tile.tile_rows or 1, tile.tile_cols or 1, tile.values)
    return mat:sub_matrix(addend)
elseif tile.op == "mul_matrix" then
    local factor = Matrix.new(tile.tile_rows or 1, tile.tile_cols or 1, tile.values)
    return mat:mul_matrix(factor)
```

### 4. Scene (`matrix_scene.lua`)

**`OP_SIZES`**: add entries `sub_matrix = {1,1}` and `mul_matrix = {1,1}`.

**`OP_SYMBOLS`**: add `sub_matrix = "−M"` and `mul_matrix = "×M"`.

**Palette**: add `{kind="op", op="sub_matrix", label="−M"}` and `{kind="op", op="mul_matrix", label="×M"}` to `PALETTE_BUTTONS`.

**Drawing**: `draw_tile` and `draw_matrix_cell` already handle the `add_matrix` family by switching on `op`. The same `draw_matrix_cell` function is called for all three ops — no new drawing code needed; just add the two new op names to the existing check.

**Placement and expand controls**: `_place_tile_at` already uses `OP_SIZES` to pick width/height and calls `grid:set_multi_2d`. The expand/shrink logic (`_grow_col`, `_grow_row`, `_shrink_col`, `_shrink_row`) operates on the tile stored in the grid — no op-specific code needed. `mul_matrix` expand fills new cells with `1` instead of `0`:

In `_grow_col` and `_grow_row`, after the new column/row is added, check `tile.op == "mul_matrix"` and set new cells to `1`.

**Click editing**: `mouse_pressed` for value cells is already op-agnostic (reads `tile.values[dr+1][dc+1]`). No changes needed.

---

## What stays the same

- All `add_matrix` mechanics — identical code paths used by `sub_matrix` and `mul_matrix`.
- All other ops — unchanged.
- Grid, HUD, palette selector — unchanged.
- Puzzles — no existing puzzles use these new ops; no puzzles need updating.

---

## Open questions

None — design is fully specified.
