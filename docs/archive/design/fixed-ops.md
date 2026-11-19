# Fixed Ops

## Goal

Introduce a "fixed" variant of op tiles alongside the existing editable ones. Two kinds:

1. **Player-placed fixed ops** — appear in the palette as a separate group; the player places and moves them freely, but their parameters are locked to canonical defaults and cannot be edited. Useful for puzzles that intentionally constrain the player's toolkit.

2. **Puzzle-placed fixed ops** — authored in the puzzle's `locked` array with explicit params, values, and tile size; fully immovable and non-editable, visually distinct from player-placed tiles. The existing `p.locked` loading path supports pusher tiles only; it needs extending to handle multi-cell op tiles with values.

## Affected files

| File | Change |
|------|--------|
| `game/scenes/matrix_scene.lua` | palette rendering for fixed ops; `fixed=true` skips -/+ affordances; `_place_tile_at` sets `fixed` flag; `_resize_tile` and expand/shrink affordances respect `fixed`; locked-op loading supports multi-cell + values |
| `data/puzzles/*.lua` | puzzle files can list `fixed_ops` and use richer `locked` entries |
| `README.md` | document fixed ops concept |
| `tests/test_pusher_scene.lua` or new test file | verify fixed tile can't be param-edited and locked op loads correctly |

## What changes

### 1. Player-placed fixed ops

#### Palette source

Puzzle files gain an optional `fixed_ops` list alongside `ops`:

```lua
ops       = { "transpose", "scale_row" },   -- editable (current behaviour)
fixed_ops = { "add_rows", "swap_rows" },    -- player-placed but params locked
```

When both lists are nil, all ops in `PALETTE_BUTTONS` are available as editable (unchanged). When a puzzle specifies `fixed_ops`, those ops appear in the palette as a separate fixed group, visually separated from the editable group by a separator.

#### Tile flag

`_place_tile_at` accepts a `fixed` field on the spec. Fixed tiles are created with `fixed=true` and `params` pre-filled from `DEFAULT_PARAMS` (the same values used for editable tiles, just frozen).

#### Visual style

- **Editable op**: amber border, -/+ affordances in param cells (current look).
- **Fixed op**: same amber background, but param cells show a small `🔒` text label instead of -/+ affordances, and the param values are rendered dimmed/italic (use a slightly desaturated colour such as `{0.65, 0.65, 0.4, 1}` instead of `{0.95, 0.85, 0.5, 1}`).

#### Interaction guards

In `mouse_pressed`: when `anchor_tile.fixed == true`, skip all param-editing branches (the tile is op-kind but param cells do nothing on click).

In `_resize_tile`: early return if `tile.fixed`.

In `draw_grid` pass 3 (expand/shrink affordances): skip fixed tiles (`not tile2.fixed`).

Erasing and dragging follow `locked` (fixed player-placed tiles are **not** `locked=true`, so the player can move and erase them — only params are immutable).

#### Palette rendering

`_build_palette` is extended to read `puzzle.fixed_ops` and insert a separator then fixed-variant buttons. Each fixed button carries `{kind="op", op=..., fixed=true}`. The `palette:selected()` result carries the `fixed` flag through to `_place_tile_at`.

### 2. Puzzle-placed fixed ops

#### Richer `locked` entries

Extend the loading loop (matrix_scene.lua lines 229–235) to handle op tiles fully:

```lua
if p.locked then
    for _, t in ipairs(p.locked) do
        local w = t.width  or op_width(t.op or "", t)
        local h = t.height or op_height(t.op or "", t)
        local tile = {
            kind=t.kind, dir=t.dir, op=t.op,
            params=t.params or {}, locked=true,
            width=w, height=h,
            tile_rows=t.tile_rows, tile_cols=t.tile_cols,
            values=t.values,
        }
        if w > 1 or h > 1 then
            self.grid:set_multi_2d(t.x, t.y, tile, w, h)
        else
            self.grid:set(t.x, t.y, tile)
        end
    end
end
```

#### Visual style

Puzzle-placed locked ops already show the small lock icon (top-right corner, lines 818–820). No change needed. The lock icon distinguishes them from player-placed ops (which never show the lock icon unless the puzzle also sets `locked=true` on them, which it won't for the player-placed fixed variant).

#### Puzzle authoring example

```lua
locked = {
    { kind="op", op="scale_row", x=5, y=3,
      params={row=2, scalar=-1} },
    { kind="op", op="add_matrix", x=7, y=5,
      tile_rows=2, tile_cols=2,
      values={{1,0},{0,1}} },
}
```

### 3. No change to `Sim.apply_op`

`fixed=true` is a UI-only flag. The simulation reads `tile.op` and `tile.params` as usual; `fixed` is ignored. No changes to `pusher_sim.lua` or `matrix_math.lua`.

### 4. New puzzle(s)

Add at least one puzzle that uses `fixed_ops` and at least one that uses a puzzle-placed locked op, to demonstrate both features.

## What stays the same

- All existing editable op tiles work exactly as before.
- `locked=true` tiles (source, sink, gap) are unaffected.
- The simulation, timeline, win/lose logic, pusher movement, and all matrix math are unchanged.
- Erasing and moving player-placed fixed tiles works the same as editable tiles (only param editing is blocked).

## Open questions

None — scope confirmed by user.
