# Puzzle Routing Redesign

## Goal

Every puzzle currently has `source.y == sink.y == 5` and no routing obstacles (except puzzle 11's
narrow corridor). A single rightward pusher solves all of them. This redesign gives each puzzle
(3–23) a non-trivial routing challenge: walls (gaps) force turns, and source/sink are no longer
colinear.

Puzzles 1 and 2 are untouched (they serve as the tutorial-movement introduction).

---

## What changes

- **Source and sink positions**: offset vertically/horizontally so the matrix must turn.
- **Gap walls**: cells the matrix can't enter; used to enforce corridors and block shortcuts.
- **Matrix goals**: free rein — new input/target pairs chosen to match the new puzzle identity.
- **Ops offered / locked**: tuned per puzzle; locking an op at a bend forces op-ordering.

## What stays the same

- 10×10 grid.
- Puzzle count (23) and world groupings.
- All existing mechanics (pusher timeline, op tile placement, params, locked/fixed_ops).
- Puzzles 1 and 2.

---

## Routing archetypes

| Shape | Turns | Worlds used |
|-------|-------|-------------|
| L (right→down or down→right) | 1 | 1 (puzzles 3–5) |
| Z / S (right→down→right) | 2 | 2 (puzzles 6–11) |
| U (right→down→left or mirror) | 2 | 3 (puzzles 12–13) |
| Staircase (right→down×2→right) | 3 | 3–4 (puzzles 14–16, 17–18) |
| Multi-bend maze | 3–4 | 4–5 (puzzles 19–23) |

---

## Gap-wall conventions

Gaps are listed as `{x=N, y=M}` entries in the puzzle's `gaps` table.  
A "horizontal wall at y=R, x=A–B" means every cell `{x=A..B, y=R}` is a gap.  
A "vertical wall at x=C, y=A–B" means every cell `{x=C, y=A..B}` is a gap.

For a **2×2 matrix** to be blocked from crossing into y=R+1, the wall must span enough columns
that no anchor position fits (anchor fits at x if x+1 ≤ 10 and gaps don't cover [x,x+1]).

---

## Puzzle-by-puzzle designs

### World 1 — Basics (unchanged puzzles 1–2, redesign 3–5)

---

#### Puzzle 3 — "Sharp Left"
**Route**: right → down (single L-turn)  
**Source**: (1, 2)   **Sink**: (9, 9)

```
S . . . . . . . .   y=2   ← matrix starts here, goes right
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .
# # # # # # . . .   y=6   ← wall (x=1–6), forces matrix right before descent
. . . . . . . . .
. . . . . . . . .
. . . . . . . . K   y=9   ← sink
```

**Wall**: gaps at y=6, x=1–6  
**Op offered**: `negate`  
**Input**: `[[1,2],[3,4]]`  **Target**: `[[-1,-2],[-3,-4]]`  
**Key insight**: player places negate somewhere on the top segment (y=2), then routes down. The wall
at y=6 means the matrix anchor must reach x≥7 before descending.

---

#### Puzzle 4 — "Drop First"
**Route**: down → right (inverted L)  
**Source**: (1, 1)   **Sink**: (9, 9)

```
S . . . . # . . .   y=1   ← source; wall at x=6 blocks early rightward crossing
. . . . . # . . .   y=2
. . . . . # . . .
. . . . . # . . .
. . . . . # . . .   y=5   ← wall ends here (x=6, y=1–5)
. . . . . . . . .   y=6   ← matrix can pass right past x=6 from here
. . . . . . . . .
. . . . . . . . K   y=9
```

**Wall**: gaps at x=6, y=1–5  
**Op offered**: `swap_rows`  
**Input**: `[[0,0,1],[0,1,0],[1,0,0]]`  **Target**: `[[1,0,0],[0,1,0],[0,0,1]]`  
**Key insight**: matrix must go down to y≥6 (3×3 matrix anchor at y=6 → occupies y=6–8) before
going right; swap_rows placed somewhere on the vertical segment.

---

#### Puzzle 5 — "Squeeze Bend"
**Route**: right → down (L), with a narrow horizontal corridor forcing transpose mid-turn  
**Source**: (1, 3)   **Sink**: (9, 8)

```
. . . . . . . . .
. . . . . . . . .
S . . . . . . . .   y=3
# # # # . . . . .   y=4   ← only columns 5–10 open
# # # # # # # # #   y=5   ← full wall
# # # # . . . . .   y=6   ← only columns 5–10 open
. . . . . . . . .   y=7
. . . . . . . . K   y=8
```

**Wall**: full wall at y=5 (x=1–10), partial walls at y=4 (x=1–4) and y=6 (x=1–4)  
**Op offered**: `transpose`  
**Input (2×3)**: `[[1,2,3],[4,5,6]]` (wider than tall)  **Target (3×2)**: `[[1,4],[2,5],[3,6]]`  
**Key insight**: the 4-column-wide opening at y=4 is too narrow for the 3-col input unless transposed
(after transpose: 2 cols fits through 4-gap opening). Like puzzle 11 but with a vertical leg added.

---

### World 2 — Combos (redesign 6–11)

---

#### Puzzle 6 — "Z-Bend"
**Route**: right → down → right (Z-shape)  
**Source**: (1, 2)   **Sink**: (9, 8)

```
S . . . . . . . .   y=2
# # # # # . . . .   y=3   ← left wall, opens at x=6+
# # # # # . . . .   y=4
. . . . . . . . .   y=5   ← middle corridor
. . . . . # # # #   y=6   ← right wall, opens at x=1–5
. . . . . # # # #   y=7
. . . . . . . . K   y=8
```

**Walls**: y=3–4 at x=1–5; y=6–7 at x=6–10  
**Op offered**: `negate`, `swap_rows`  
**Input**: `[[1,2],[3,4]]`  **Target**: `[[-3,-4],[-1,-2]]`  
**Key insight**: two ops, one per horizontal arm. Must negate AND swap_rows; ordering is free — either
arm can hold either op, two valid solutions.

---

#### Puzzle 7 — "Three-Op Z"
**Route**: right → down → right  
**Source**: (1, 2)   **Sink**: (9, 8)

Same Z-wall layout as puzzle 6 but with three ops and a 3×3 matrix where only one ordering works.

**Walls**: same as puzzle 6  
**Ops offered**: `transpose`, `scale_row`, `negate`  
**Input**: `[[1,2,3],[4,5,6],[7,8,9]]`  **Target**: `[[-7,-14,-21],[-4,-10,-16],[-1,-4,-9]]`  
(= scale_row(3,3) → transpose → negate, **or** negate → transpose → scale_row(3,3)? verify.)  
> Note for implementer: pick input→target such that only one of the two orderings produces the target.
> A clean choice: negate first → `[[-1,-2,-3],...]`, then transpose → `[[-1,-4,-7],...]`, then
> scale_row(1,3) → `[[-3,-12,-21],[-4,-5,-6],[-7,-8,-9]]`. Design a solvable but constrained
> ordering during implementation; adjust values accordingly.

---

#### Puzzle 8 — "Tight Z"
**Route**: right → down → right, with a narrow vertical corridor mid-descent  
**Source**: (1, 2)   **Sink**: (9, 9)

```
S . . . . . . . .   y=2
# # # # # . . . .   y=3   ← left wall
# # # # # . # # #   y=4   ← only column 6 open vertically
# # # # # . # # #   y=5   ← (narrow descent corridor at x=6)
# # # # # . . . .   y=6
. . . . . . . . .
. . . . . . . . .
. . . . . . . . K   y=9
```

**Walls**: y=3–6 at x=1–5; y=4–5 at x=7–10  
**Op offered**: `transpose`, `swap_rows`  
**Input (2×3)**: `[[1,2,3],[4,5,6]]`  **Target (2×3)**: `[[4,5,6],[1,2,3]]`  
**Key insight**: 2-wide descent corridor at x=6–7 (after transpose: 3 rows fit in 4 vertical open
cells)… actually this is about routing around walls, not size-fitting. Simplify: standard Z with a
narrow horizontal corridor at the bend requiring transpose to fit width.

---

#### Puzzle 9 — "U-Turn Left"
**Route**: right → down → left (U-shape)  
**Source**: (1, 2)   **Sink**: (1, 9)

```
S . . . . . . . .   y=2
# # # # # # # # .   y=3   ← wall x=1–8, open at x=9–10
# # # # # # # # .   y=4
. . . . . . . . .   y=5   ← bottom corridor
. . . . . . . . .
. . . . . . . . .
# # # # # # # # .   y=8   ← wall x=1–8, open at x=9–10
# # # # # # # # .   y=9
K . . . . . . . .   y=10  ← sink (bottom-left)
```

Actually let me simplify this. A U-shape:
- Source top-left, sink bottom-left
- Matrix goes right across the top, turns down on the right side, comes back left across the bottom
- Walls block the middle of the vertical segments so the only path is around the right edge

**Wall**: horizontal walls at y=3–4 for x=1–7 and y=7–8 for x=1–7  
**Source**: (1,2), **Sink**: (1,9) (or (2,9) to avoid edge)  
**Ops offered**: `negate`, `transpose`  
**Input**: `[[1,2],[3,4]]`  **Target**: `[[-1,-3],[-2,-4]]`  
(= transpose then negate; or negate then transpose → `[[-1,-3],[-2,-4]]` same result since both
 commute for 2×2 antisymmetric. Pick a non-commuting goal.)  
**Input**: `[[1,0],[2,3]]`  **Target**: `[[0,-2],[-1,-3]]` (negate then transpose ≠ transpose then negate)

---

#### Puzzle 10 — "Staircase"
**Route**: right → down → right → down (two-step staircase, 3 turns)  
**Source**: (1, 1)   **Sink**: (9, 9)

```
S . . . . . . . .   y=1
. . . . . . . . .
# # # # # . . . .   y=3   ← step 1 wall (opens x=6–10)
. . . . . . . . .   y=4   ← middle-left corridor
. . . . . . . . .
. . . . . # # # #   y=6   ← step 2 wall (opens x=1–5)
. . . . . . . . .
. . . . . . . . .
. . . . . . . . K   y=9
```

**Walls**: y=3 at x=1–5; y=6 at x=6–10  
**Ops offered**: `add_rows`, `scale_row`  
**Input**: `[[2,0,0],[1,1,0],[0,0,1]]`  **Target**: `[[1,0,0],[0,1,0],[0,0,1]]`  
(Row-reduce to identity: add_rows(2→1, scalar=-0.5)... use integer scalars. 
 Better: input `[[2,0,0],[4,1,0],[0,0,1]]`, target `[[1,0,0],[0,1,0],[0,0,1]]` via scale_row(1,½)
 then add_rows(src=1,dst=2,scalar=-4). Use scalar=-2 and scale differently. 
> Implementer: pick integers that work in two steps with available ops.)

---

#### Puzzle 11 — "Corridor Cross"
**Route**: down → right → up (inverted U / C-shape, 2 turns)  
**Source**: (5, 1)   **Sink**: (5, 10) (top-center to bottom-center)

Walls create two vertical side walls forcing the matrix to go around the bottom edge.

**Wall**: vertical walls at x=1–3 and x=7–10 for y=2–8 (open only x=4–6 corridor top/bottom,
and open bottom corridor y=9–10 for full width to allow traversal)  
> Simplify: source top-middle, sink bottom-middle, walls block direct descent, path goes around.  
**Wall**: x=1–3, y=3–7 and x=7–10, y=3–7 (block centre columns 4–6 from going straight down)  
> This is getting complex; instead: **source (2,1), sink (9,1)** (same row, top) but the path must
> dip down to y=7+ and come back up — an arch. Actually arching up/down is equivalent to Z/U.

**Final design for Puzzle 11**: 
**Route**: right → down → right (Z), with size-change corridor (like original puzzle 11 theme)  
**Source**: (1, 3)   **Sink**: (9, 8)  
**Wall**: horizontal wall at y=5–6, x=1–4 and y=5–6, x=8–10 (open only x=5–7 in the descent zone)  
**Ops offered**: `transpose`, `negate`  
**Input (3×2)**: `[[1,4],[2,5],[3,6]]`  **Target (2×3)**: `[[-1,-2,-3],[-4,-5,-6]]`  
(= transpose then negate; 3×2 → 2×3 fits through a 2-row-wide corridor after transpose)

---

### World 3 — Advanced (redesign 12–16)

---

#### Puzzle 12 — "Negate-Swap Arch"
**Route**: right → down → left → up (full U-arch, 3 turns)  
**Source**: (1, 1)   **Sink**: (1, 10) (same column, top → bottom)

**Wall**: creates a central blocked zone, forcing traversal around the right side  
Walls: y=2–9 at x=1–1? No, that blocks source column.  
Better: source (2,1), sink (2,10). Wall: x=2 blocked for y=3–8 → forces matrix right then back.  

Actually, let's make it a right arch:
**Source**: (1,2), **Sink**: (1,8)  
**Wall**: x=1–6 for y=4–6 (horizontal block in the left-center, matrix must go right, then descend past the wall, then come back left)  
**Ops offered**: `negate`, `swap_rows`  
**Input**: `[[1,2],[3,4]]`  **Target**: `[[-3,-4],[-1,-2]]`  

---

#### Puzzle 13 — "Flip Scale Maze"
**Route**: Z-shape with an op locked at the bend  
**Source**: (1, 2)   **Sink**: (9, 9)  
**Wall**: Z-walls (similar to puzzle 6)  
**Locked op**: `scale_row` locked at (5,5) (the corner/bend of the Z)  
**Ops offered**: `transpose`  
**Input**: `[[1,2],[3,4]]`  **Target**: `[[1,3],[4,8]]`  
(transpose → [[1,3],[2,4]]; then scale_row(2,2) → [[1,3],[4,8]])

---

#### Puzzle 14 — "Three-Step Elimination"
**Route**: staircase (3 turns: right→down→right→down)  
**Source**: (1,1), **Sink**: (9,9)  
**Wall**: two step walls (like puzzle 10 but tighter)  
**Ops offered**: `add_rows`, `scale_row`  
**Input**: `[[2,4,0],[1,2,1],[0,0,3]]`  **Target**: `[[1,0,0],[0,1,0],[0,0,1]]`  (row reduce to identity via 3 ops)

---

#### Puzzle 15 — "Scale-Swap Detour"
**Route**: right → down → right (Z)  
**Source**: (1,1), **Sink**: (9,9)  
**Wall**: Z-walls with the descent corridor only 1 cell wide (forces a narrow-passage nav)  
**Ops offered**: `scale_row`, `swap_rows`  
**Input**: `[[0,0,-1],[0,2,0],[3,0,0]]`  **Target**: `[[1,0,0],[0,1,0],[0,0,1]]`

---

#### Puzzle 16 — "Triple Bend"
**Route**: right → down → left → down (3 turns)  
**Source**: (1,2), **Sink**: (9,9)  
**Wall**: walls create an S-channel — right arm top-half, left arm mid, right arm bottom  
**Ops offered**: `transpose`, `negate`, `scale_row`  
**Input**: `[[1,2],[3,4]]`  **Target**: `[[-2,-6],[−2,-4]]` (matches original puzzle 16 goal: scale_row + transpose + negate)

---

### World 4 — Transforms (redesign 17–20)

---

#### Puzzle 17 — "Row Reduction Spiral"
**Route**: Z-shape (2 turns)  
**Source**: (1,2), **Sink**: (9,8)  
**Locked op**: `add_rows` locked at the top-right bend  
**Ops offered**: `scale_row`  
**Input**: `[[6,0,0],[3,1,0],[0,0,2]]`  **Target**: `[[1,0,0],[0,1,0],[0,0,1]]`

---

#### Puzzle 18 — "Column Work Maze"
**Route**: staircase (3 turns)  
**Source**: (1,1), **Sink**: (9,9)  
**Ops offered**: `swap_cols`, `scale_col`  
**Input**: `[[3,1],[6,2]]`  **Target**: `[[1,3],[2,6]]` (swap_cols then scale_col(1,3)? verify)

---

#### Puzzle 19 — "Mirror Maze"
**Route**: U-arch (source top-left, sink top-right)  
**Source**: (1,2), **Sink**: (9,2)  
**Wall**: horizontal wall at y=3–4, x=1–10 except x=4–6 (narrow descent corridor center)  
Then wall at y=7–8, x=1–10 except x=4–6 (narrow ascent corridor center)  
**Ops offered**: `flip_h`, `flip_v`  
**Input (2×3)**: `[[1,2,3],[4,5,6]]`  **Target (2×3)**: `[[6,5,4],[3,2,1]]` (flip_h then flip_v)

---

#### Puzzle 20 — "Absolute Rotation Detour"
**Route**: Z-shape, locked rotate_90 at the bend  
**Source**: (1,2), **Sink**: (9,9)  
**Locked op**: `rotate_90` at (5,5)  
**Ops offered**: `abs`  
**Input**: `[[-1,2],[-3,4]]`  **Target**: `[[3,1],[4,2]]` (abs → `[[1,2],[3,4]]`, rotate_90 → `[[3,1],[4,2]]`)

---

### World 5 — Fixed Pieces (redesign 21–23)

---

#### Puzzle 21 — "Fixed Tools, Bent Path"
**Route**: staircase (3 turns)  
**Source**: (1,1), **Sink**: (9,9)  
**Wall**: two-step staircase walls  
**fixed_ops** (player can place but can't remove): `swap_rows`, `negate` pre-placed on the grid  
**Ops offered**: none (empty palette — player must route through fixed ops in correct order)  
**Input**: `[[1,2],[3,4]]`  **Target**: `[[-3,-4],[-1,-2]]`

---

#### Puzzle 22 — "Mandatory Negate, Curved Path"
**Route**: U-arch (3 turns)  
**Source**: (1,2), **Sink**: (9,2)  
**Wall**: arch-down walls (force dip to y=8+ and come back up)  
**Locked op**: `negate` locked at the bottom of the arch (y=8)  
**Ops offered**: none  
**Input**: `[[1,2],[3,4]]`  **Target**: `[[-1,-2],[-3,-4]]`

---

#### Puzzle 23 — "Locked Scale, Full Maze"
**Route**: 4 turns (right → down → left → down → right)  
**Source**: (1,1), **Sink**: (9,9)  
**Wall**: complex maze walls creating a snake-channel  
**Locked op**: `scale_row` locked mid-route with params  
**Ops offered**: `transpose`, `negate`  
**Input**: `[[1,0],[0,2]]`  **Target**: `[[0,-2],[-3,0]]`  
(scale_row(2,3): → `[[1,0],[0,6]]`, transpose: → `[[1,0],[0,6]]`... pick values that require all three)

---

## Open questions

- Puzzle 7 (three-op ordering): implementer must verify exactly which op ordering produces the
  target and choose input/target values accordingly.
- Puzzle 10 (Staircase elimination): scalars must be integers; implementer picks row-reduction
  that works in two integer steps.
- Puzzle 23 (Full maze): exact gap coordinates for the 4-turn snake require careful layout to
  ensure the matrix footprint fits at each corridor; verify during implementation.

---

## Affected files

- `data/puzzles/03_negate.lua` through `data/puzzles/23_locked_scale.lua` (21 files)
- `lua/game/puzzle_loader.lua` — no structural changes needed
- `tests/ui/01_solve_puzzle_1.lua` — untouched (puzzle 1 unchanged)
- `tests/ui/04_sweep_all_puzzles.lua` — no changes needed (checks names; names will update)
- Possibly new `tests/ui/` specs if routing-specific assertions are added
