# NxM Matrix Support + Gap Cells

## Goal

1. Allow puzzles to use non-square matrices (e.g. 2×3, 3×2) — the math already works; the display and op-tile sizing need to follow the actual matrix dimensions.
2. Add "gap" cells — impassable grid cells that neither pushers nor any part of the matrix footprint can enter. This enables rotation puzzles where the player transposes the matrix to change its shape and fit through a narrow corridor.

## Affected files

- `game/pusher_sim.lua` — gap awareness in `Sim.advance` and `Sim.blocked`
- `game/scenes/matrix_scene.lua` — dynamic `scale_row` tile height, gap cell rendering, param max clamped to matrix size, sim state passes gaps
- `data/puzzles/11_rotate_gap.lua` — new demo puzzle (2×3 matrix, gap corridor, transpose to fit)
- `game/matrix_math.lua` — no changes (already handles nxm)
- `game/grid.lua` — no changes
- `game/puzzle_loader.lua` — no changes (data-driven)

## What changes

### `game/pusher_sim.lua`

- `Sim.blocked` gains a `gaps` table (`gaps[y][x] = true`) and returns true if any cell of the proposed new matrix position overlaps a gap.
- `Sim.advance` receives `gaps` in its state table, passes it to `Sim.blocked`, and also blocks pushers from stepping onto gap cells.

### `game/scenes/matrix_scene.lua`

**Dynamic op-tile sizing:**
- `OP_SIZES.scale_row` is currently `{1, 4}` (hardcoded). Change to a function or compute it at placement/draw time from `self.input_matrix.rows`. The placed tile should span exactly `matrix.rows` board cells vertically.
- `draw_tile` for `scale_row`: `for band = 1, 4` → `for band = 1, tile.matrix_rows` (stored on the tile at placement time).
- `PARAM_DEFS.scale_row.row.max` and `swap_rows.row_a/b.max` updated from `self.puzzle.input.rows` at load time.

**Gap cells:**
- `load_puzzle`: iterate `p.gaps` (array of `{x, y}`) and call `self.grid:set(x, y, {kind="gap", locked=true})` for each.
- `draw_grid` (passes 1 & 2): render gap cells with a dark fill and an "×" label so they are visually distinct from empty cells.
- `do_step`: include `gaps` in the sim state passed to `Sim.advance` (a `{[y]={[x]=true}}` lookup built once in `start_run`).
- `get_footprint`: gap cells are passable by footprint queries (gaps only block *movement into* them, not reading the occupied set — the blocked check handles that).

### `data/puzzles/11_rotate_gap.lua`

```lua
return {
    name   = "Tight Fit",
    grid_w = 10, grid_h = 10,
    source = { x=1, y=4 },
    ops    = { "transpose" },
    sink   = { x=10, y=4 },
    -- 2×3 input; transpose → 3×2 output
    input  = { rows=2, cols=3, values={ {1,2,3}, {4,5,6} } },
    target = { rows=3, cols=2, values={ {1,4}, {2,5}, {3,6} } },
    -- Vertical gap corridor at x=5..6, rows y=1..3 and y=6..10,
    -- leaving only a 3-row-tall gap (y=4..6) for the 3×2 footprint to pass.
    gaps = {
        {x=5,y=1},{x=5,y=2},{x=5,y=3},
        {x=5,y=7},{x=5,y=8},{x=5,y=9},{x=5,y=10},
        {x=6,y=1},{x=6,y=2},{x=6,y=3},
        {x=6,y=7},{x=6,y=8},{x=6,y=9},{x=6,y=10},
    },
}
```

(Exact gap layout may be tweaked during implementation — the shape just needs to pass a 3×2 but block a 2×3.)

## What stays the same

- All existing puzzles (backward compatible — `gaps` defaults to empty).
- Matrix math (transpose, scale, etc.) unchanged.
- Grid, scene layout, timeline panel, palette.
- Pusher and op-tile logic outside of blocked/gap checks.

## Open questions

None — straight implementation once design is approved.
