# Multi-Op Puzzles

## Goal

Add 5 new puzzles (12–16) where solving requires placing **two or three different operation tiles** in sequence. The existing puzzles each exercise one op; these introduce the concept that multiple ops compose to reach targets unreachable by any single op.

## Affected files

- `data/puzzles/12_negate_swap.lua` — new
- `data/puzzles/13_flip_scale.lua` — new
- `data/puzzles/14_elimination.lua` — new
- `data/puzzles/15_scale_swap.lua` — new
- `data/puzzles/16_triple.lua` — new
- `game/puzzle_loader.lua` — add the five new paths to `PUZZLES`

## What changes

Five new puzzle files are added in `data/puzzles/`. Each sets `ops` to a list of 2–3 operation names. The player must figure out which ops to place and in what order.

### Puzzle 12 — "Negate & Swap"
- **ops**: `{ "negate", "swap_rows" }`
- **input**: `[[1,2],[3,4]]`
- **target**: `[[-3,-4],[-1,-2]]`
- **path**: negate → `[[-1,-2],[-3,-4]]`, then swap_rows(1,2) → `[[-3,-4],[-1,-2]]`
- Teaches: order matters — swap-then-negate yields the same result here (commutative in this case), but the two ops together are required.

### Puzzle 13 — "Flip & Scale"
- **ops**: `{ "transpose", "scale_row" }`
- **input**: `[[1,2],[3,4]]`
- **target**: `[[1,3],[-2,-4]]`
- **path**: transpose → `[[1,3],[2,4]]`, then scale_row(2, −1) → `[[1,3],[−2,−4]]`
- Teaches: transpose changes shape/indices first; scale acts on the transposed layout.

### Puzzle 14 — "Elimination"
- **ops**: `{ "add_rows", "scale_row" }`
- **input** (3×3): `[[2,0,0],[4,1,0],[0,0,1]]`
- **target**: `[[1,0,0],[0,1,0],[0,0,1]]`
- **path**: scale_row(1, 0.5) → `[[1,0,0],[4,1,0],[0,0,1]]`, add_rows(src=1, dst=2, scalar=−4) → `[[1,0,0],[0,1,0],[0,0,1]]`
- Teaches: Gaussian elimination with two elementary row ops.

### Puzzle 15 — "Scale & Swap"
- **ops**: `{ "scale_row", "swap_rows" }`
- **input** (3×3): `[[1,2,3],[0,0,0],[7,8,9]]`
- **target**: `[[7,8,9],[0,0,0],[-1,-2,-3]]`
- **path**: swap_rows(1,3) → `[[7,8,9],[0,0,0],[1,2,3]]`, scale_row(3, −1) → `[[7,8,9],[0,0,0],[-1,-2,-3]]`
- Teaches: order matters — scaling before swapping gives the same target but requires a different row argument.

### Puzzle 16 — "Triple Threat"
- **ops**: `{ "transpose", "negate", "scale_row" }`
- **input**: `[[1,2],[3,4]]`
- **target**: `[[-2,-6],[-2,-4]]`
- **path**: transpose → `[[1,3],[2,4]]`, negate → `[[-1,-3],[-2,-4]]`, scale_row(1, 2) → `[[-2,-6],[-2,-4]]`
- Teaches: three-op composition; each op is necessary.

## What stays the same

- Puzzle file format is unchanged — the `ops` field already supports a list.
- `param_popup.lua` and `game_scene.lua` already handle multiple op types in a palette; no logic changes needed.
- Puzzles 1–11 are unmodified.
- No new op types are introduced.

## Open questions

None — all ops used (`transpose`, `negate`, `swap_rows`, `scale_row`, `add_rows`) already exist and are supported by `param_popup.lua`'s `FIELD_DEFS`.
