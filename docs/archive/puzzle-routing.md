# Puzzle Routing Checklist

Design doc: `docs/design/puzzle-routing.md`

Each task is a self-contained edit to one or a few puzzle files.  
Run `love . --headless` after each task to verify no crashes.  
Then manually launch `love .` and confirm you can solve the puzzle (place pushers + ops and hit "Win").

## Gap-wall shorthand

"Horizontal wall at y=R, x=A–B" expands to `{x=A,y=R}, …, {x=B,y=R}` in the `gaps` table.  
"Vertical wall at x=C, y=A–B" expands to `{x=C,y=A}, …, {x=C,y=B}`.

## Blocking rule for a N×M matrix (N rows, M cols)

The matrix is blocked from entering a row if ANY cell of the new footprint overlaps a gap.  
When anchor moves from (ax, ay) → (ax, ay+1): footprint bottom row is at y=ay+N, x=ax…ax+M-1.  
When anchor moves right (ax, ay) → (ax+1, ay): footprint right column is at x=ax+M, y=ay…ay+N-1.

---

## Task A — Puzzles 3, 4, 5 (World 1: first turns)
**DONE**

**Files**: `data/puzzles/03_negate.lua`, `data/puzzles/04_swap.lua`, `data/puzzles/05_scale.lua`

### Puzzle 3 — "Sharp Left" (2×2 matrix, L-shape right→down)

```
source (1,2)        2×2 matrix occupies x=1–2, y=2–3
sink   (9,8)        any anchor whose footprint covers (9,8)
route  right along y=2 to x≥7, then down to y≥7
```

**Wall** – horizontal at y=6, x=1–6:
```lua
gaps = {
    {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},
}
```
Blocking analysis: 2×2 at anchor (ax,5) going to (ax,6): footprint bottom-row is y=6, x=ax…ax+1.
- ax=5: cells (5,6)(6,6) both gaps → blocked ✓  
- ax=6: cells (6,6)(7,6) — (6,6) gap → blocked ✓  
- ax=7: cells (7,6)(8,6) — no gap → free ✓  
Matrix must reach anchor x≥7 before descending.

**Op offered**: `negate`  
**Input**: `rows=2, cols=2, values={ {1,2}, {3,4} }`  
**Target**: `rows=2, cols=2, values={ {-1,-2}, {-3,-4} }` ✓ (negate once)

---

### Puzzle 4 — "Drop First" (3×3 matrix, inverted-L down→right)

```
source (1,1)        3×3 matrix occupies x=1–3, y=1–3
sink   (8,8)        3×3 at anchor (7,7) covers (7–9, 7–9) → covers (8,8) ✓
route  down y=1→6, then right across y=6
```

**Wall** – vertical at x=6, y=1–5:
```lua
gaps = {
    {x=6,y=1},{x=6,y=2},{x=6,y=3},{x=6,y=4},{x=6,y=5},
}
```
Blocking analysis: 3×3 at anchor (ax, ay) going right to (ax+1, ay): footprint right column is x=ax+3, y=ay…ay+2.
- anchor (3, ay) going right: right col = x=6. If any y in ay…ay+2 has (6,y) in gap (y=1–5): blocked when ay≤3 (covers y=ay, ay+1, ay+2 ≤ ay+2≤5).  
- anchor (3,4) going right: right col x=6, y=4,5,6 — (6,4) and (6,5) are gaps → blocked ✓  
- anchor (3,5) going right: y=5,6,7 — (6,5) gap → blocked ✓  
- anchor (3,6) going right: y=6,7,8 — none gap → free ✓  
Matrix must reach anchor y≥6 before going right past x=3.

**Op offered**: `swap_rows`  
**Input**: `rows=3, cols=3, values={ {0,0,1},{0,1,0},{1,0,0} }`  
**Target**: `rows=3, cols=3, values={ {1,0,0},{0,1,0},{0,0,1} }` ✓ (swap_rows(1,3))

---

### Puzzle 5 — "Squeeze Bend" (2×3 matrix, L-shape right→down)

```
source (1,3)        2×3 matrix occupies x=1–3, y=3–4
sink   (8,8)        3×2 (post-transpose) at anchor (7,7) covers (7–8, 7–9) → (8,8) ✓
route  right along y=3–4 to x≥5, then down to y≥7
```

**Wall** – horizontal at y=5, x=1–4:
```lua
gaps = {
    {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},
}
```
Blocking analysis (pre-transpose, 2×3): anchor (ax,3) going to (ax,4): bottom-row y=5, x=ax…ax+2.
- ax=2: x=2,3,4 — x=2,3,4 all gaps → blocked ✓  
- ax=3: x=3,4,5 — (3,5)(4,5) gaps → blocked ✓  
- ax=5: x=5,6,7 — no gap → free ✓  
Post-transpose (3×2): anchor (ax,3) going to (ax,4): bottom-row y=6, x=ax…ax+1 — no gap at y=6, always free.  
But at anchor (ax,2) going to (ax,3): bottom-row y=5, x=ax…ax+1.  
- ax=4: (4,5)(5,5) — (4,5) gap → blocked ✓  
- ax=5: (5,5)(6,5) — no gap → free ✓  
Either way, matrix must reach x≥5 anchor before descending past y=4.

**Op offered**: `transpose`  
**Input**: `rows=2, cols=3, values={ {1,2,3},{4,5,6} }`  
**Target**: `rows=3, cols=2, values={ {1,4},{2,5},{3,6} }` ✓ (transpose)

---

## Task B — Puzzles 6, 7, 8 (World 2: two ops, Z-shapes) **DONE**

**Files**: `data/puzzles/06_row_swap.lua`, `data/puzzles/07_double_flip.lua`, `data/puzzles/08_combo.lua`

### Puzzle 6 — "Z-Bend" (2×2 matrix, Z-shape right→down→right)

```
source (1,1)        2×2 matrix occupies x=1–2, y=1–2
sink   (9,10)       2×2 at anchor (8,9) covers (8–9, 9–10) → (9,10) ✓
route  right to x≥6, then down through x=6–10 zone (y=3–6),
       blocked from descending past y=7 on x≥6, so must cross left to x≤5 and
       descend to y=9+, then... actually use simpler Z with two walls below.
```

**Revised layout** — two horizontal half-walls create a Z-channel:
```
# # # # # . . . . .    y=3   wall-A x=1–5
# # # # # . . . . .    y=4   wall-A x=1–5
                              (open y=5–6 everywhere)
. . . . . # # # # .    y=7   wall-B x=6–9
. . . . . # # # # .    y=8   wall-B x=6–9
```

**Wall** – Wall-A: y=3–4, x=1–5; Wall-B: y=7–8, x=6–9:
```lua
gaps = {
    {x=1,y=3},{x=2,y=3},{x=3,y=3},{x=4,y=3},{x=5,y=3},
    {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
    {x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},
    {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
}
```

Routing: source (1,1). Matrix goes RIGHT at y=1–2 to x≥6 (past wall-A). Then goes DOWN at x=6–9 from y=2 to y=5–6 (wall-A ends at y=4; at x=6 no wall-A conflict). Then at y=6, going down to y=7: anchor (5,6)→(5,7): bottom-row y=8, x=5–6. x=6, y=8 IS wall-B → blocked if ax=5. At ax=4: x=4–5, no wall-B → free. So matrix must shift left to x≤4 before descending past y=7. From x=4–5, y=8–9 it can go right to sink (9,10).

Sink: (9,10). 2×2 at anchor (8,9): covers x=8–9, y=9–10 → (9,10) ✓.

**Ops offered**: `negate`, `swap_rows`  
**Input**: `rows=2, cols=2, values={ {1,2},{3,4} }`  
**Target**: `rows=2, cols=2, values={ {-3,-4},{-1,-2} }` ✓ (negate+swap_rows or swap_rows+negate — both reach same result, two valid solutions)

Verify: swap_rows then negate: `{{3,4},{1,2}}` → `{{-3,-4},{-1,-2}}` ✓  
        negate then swap_rows: `{{-1,-2},{-3,-4}}` → `{{-3,-4},{-1,-2}}` ✓

---

### Puzzle 7 — "Ordered Ops" (2×2 matrix, Z-shape, ordering matters)

Same Z-shape as puzzle 6 (identical wall layout). Two ops, but only one op ordering produces the target.

**Wall**: same as puzzle 6.  
**Source** (1,1), **Sink** (9,10).

**Ops offered**: `scale_row`, `swap_rows`  
**Input**: `rows=2, cols=2, values={ {1,2},{3,4} }`  

Op ordering analysis:
- scale_row(r=1, s=2) then swap_rows(1,2): `{{2,4},{3,4}}` → `{{3,4},{2,4}}`  
- swap_rows(1,2) then scale_row(r=1, s=2): `{{3,4},{1,2}}` → `{{6,8},{1,2}}`  
Only one ordering reaches `{{3,4},{2,4}}`.

**Target**: `rows=2, cols=2, values={ {3,4},{2,4} }` (requires scale_row first, then swap_rows)

**Note for implementer**: scale_row default params are `{row=1, scalar=2}`. Because the Z-route has a natural left→right arm ordering (player places ops on left vs right arm of the Z), the puzzle teaches that op ORDER matters.

---

### Puzzle 8 — "Tight Z" (2×2 matrix, Z with extra horizontal step)

```
source (1,1)
sink   (9,10)
```

Same Z-shape as puzzle 6/7 but with scale_row (3 params) needing to negate one specific row.

**Wall**: same as puzzle 6.  
**Ops offered**: `scale_row`  
**Input**: `rows=3, cols=3, values={ {2,0,0},{0,3,0},{0,0,1} }`  
**Target**: `rows=3, cols=3, values={ {-2,0,0},{0,3,0},{0,0,1} }` ✓ (scale_row(r=1, s=-1))

> Source/sink for a 3×3 matrix: source (1,1) occupies x=1–3, y=1–3. Sink (8,8): 3×3 at anchor (7,7) covers (7–9, 7–9) → (8,8) ✓.  
> Adjust source, sink, and wall coords to fit 3×3 matrix size — wall-A must start at y=4 to avoid overlapping source tile (which occupies y=1–3).

**Updated layout for 3×3 matrix**:
```
source (1,1)        3×3 occupies x=1–3, y=1–3
sink   (8,8)
wall-A y=4–5, x=1–5
wall-B y=7–8, x=6–9
```
```lua
gaps = {
    {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
    {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},
    {x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},
    {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
}
```

---

## Task C — Puzzles 9, 10, 11 (World 2: U-shapes, staircase) ✓

**Files**: `data/puzzles/09_uturn.lua`, `data/puzzles/10_set_row.lua`, `data/puzzles/11_rotate_gap.lua`

### Puzzle 9 — "Arch" (2×2 matrix, U-arch: right→down→left)

```
source (1,2)        sink (1,8)   same column, top–bottom
```

Arch: matrix goes RIGHT across top, comes DOWN on right side, goes LEFT across bottom.

**Wall** – two horizontal half-walls create an arch channel:
```
wall-A y=3–4, x=1–8   (open only x=9–10 on the right)
wall-B y=6–7, x=1–8   (open only x=9–10 on the right)
```

```lua
gaps = {
    {x=1,y=3},{x=2,y=3},{x=3,y=3},{x=4,y=3},{x=5,y=3},{x=6,y=3},{x=7,y=3},{x=8,y=3},
    {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},{x=8,y=4},
    {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},{x=8,y=6},
    {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},{x=8,y=7},
}
```

Path: source (1,2), go RIGHT to x=8 (anchor; matrix occupies x=8–9 → right edge at x=9 clear of wall-A). Descend past wall-A (at x=8–9: wall-A is x=1–8, so x=9 free; anchor x=8: rightmost col at x=9, not in wall ✓). Descend to y=5. Go LEFT to reach sink (1,8): pass wall-B opening at x=9–10, then descend to y=8, then go left.

Blocking: 2×2 at anchor (ax, 2) going to (ax, 3): bottom-row y=3, x=ax,ax+1.  
- ax=7: x=7,8 — both in wall-A (x=1–8) → blocked ✓  
- ax=8: x=8,9 — x=8 in wall, x=9 not → blocked ✓  
- ax=9: x=9,10 — neither in wall → free ✓  

So matrix must reach anchor x≥9 before crossing y=2→3.  
Sink (1,8): 2×2 at anchor (1,7) covers x=1–2, y=7–8 → (1,8) ✓. At anchor (1,7): going left from (2,7): blocked? Actually sink detection fires when matrix covers (1,8). The matrix approaching from (2,7) going left to (1,7): covers (1–2, 7–8) → (1,8) covered ✓.

**Ops offered**: `negate`, `transpose`  
**Input**: `rows=2, cols=2, values={ {1,0},{2,3} }`  

Ordering matters (negate and transpose do NOT commute for this matrix):
- negate then transpose: `{{-1,0},{-2,-3}}` → `{{-1,-2},{0,-3}}`  
- transpose then negate: `{{1,2},{0,3}}` → `{{-1,-2},{0,-3}}`  
Both give same result! Pick a matrix where they don't commute.

Try `{{1,2},{0,3}}`:
- negate then transpose: `{{-1,-2},{0,-3}}` → `{{-1,0},{-2,-3}}`  
- transpose then negate: `{{1,0},{2,3}}` → `{{-1,0},{-2,-3}}`  
Same again (negate and transpose commute for all matrices — both mean "apply elementwise negation; for transpose, the sign doesn't matter for commutativity").

**Use ops that don't commute**: `negate` + `swap_rows`  
- negate then swap_rows(1,2) on `{{1,2},{3,4}}`: `{{-1,-2},{-3,-4}}` → `{{-3,-4},{-1,-2}}`  
- swap_rows then negate: `{{3,4},{1,2}}` → `{{-3,-4},{-1,-2}}`  
Same again! These commute for 2×2 too.

Use `add_rows` + `scale_row` (these generally don't commute):  
Input `{{1,2},{0,4}}`:
- scale_row(r=2, s=2) then add_rows(src=2, dst=1, s=-1): `{{1,2},{0,8}}` → `{{1,-6},{0,8}}`  
- add_rows(src=2, dst=1) then scale_row(r=2, s=2): `{{1,6},{0,4}}` → `{{1,6},{0,8}}`  
Different! ✓

Target: `{{1,-6},{0,8}}` requires scale_row(r=2,s=2) THEN add_rows(src=2,dst=1,scalar=-1).

> This may be complex for a World 2 puzzle. Simpler alternative: just use negate + swap_rows with the two valid solutions (arch teaches routing, not ordering). Keep it educational.

**Final choice for puzzle 9** (two valid solutions, arch for routing):  
**Ops offered**: `negate`, `swap_rows`  
**Input**: `rows=2, cols=2, values={ {1,2},{3,4} }`  
**Target**: `rows=2, cols=2, values={ {-3,-4},{-1,-2} }` (matches puzzle 6 goal, that's fine — routing is the novelty)

---

### Puzzle 10 — "Staircase" (3×3 matrix, 3-turn staircase)

```
source (1,1)        sink (8,9)
route  right → down → right → down  (3 turns)
```

Two half-walls form staircase steps:
```
wall-A y=4, x=1–5    (step 1: must reach x≥6 to descend)
wall-B y=7, x=5–10   (step 2: must be at x≤4 to descend past y=7)
```

```lua
gaps = {
    {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
    {x=5,y=7},{x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},{x=10,y=7},
}
```

Path for 3×3 matrix:
- Source (1,1). Go RIGHT to anchor x≥4 (footprint right-col x=6, not in wall-A for y=1–3). Then at y=1, right col at x=6 at y=4: wall-A(x=1–5) — x=6 not in wall → can descend if at x=4+.
  Wait: anchor (3,1) going right to (4,1): footprint right-col x=6, y=1–3. wall-A at y=4 only → no block ✓. So can go right at y=1 past x=3 freely!  
  
  Let me re-check: anchor (3,1) going DOWN to (3,2): footprint bottom-row y=4, x=3–5. x=3,4,5 at y=4 — x=3,4,5 ≤5 → wall-A: (3,4),(4,4),(5,4) gaps → BLOCKED ✓.  
  Anchor (4,1) going DOWN to (4,2): bottom-row y=4, x=4–6. x=4,5 in wall (x=1–5) → BLOCKED ✓.  
  Anchor (5,1) going DOWN to (5,2): bottom-row y=4, x=5–7. x=5 in wall → BLOCKED ✓.  
  Anchor (6,1) going DOWN to (6,2): bottom-row y=4, x=6–8. None in wall → FREE ✓.  
  
- Go RIGHT to anchor x=6, then DOWN to y=4 (anchor y=1→2→3→4).
- From (6,4): 3×3 covers x=6–8, y=4–6. Go DOWN to (6,5): bottom-row y=7, x=6–8. wall-B at y=7, x=5–10: x=6–8 in wall → BLOCKED ✓.  
  Must go LEFT to anchor x=3: bottom-row y=7, x=3–5. x=5 in wall-B → BLOCKED.  
  Anchor x=2: bottom-row y=7, x=2–4. None in wall-B (x=5–10) → FREE ✓.  
  
  Hmm: so must go LEFT to x=2 before descending? But source was at (1,1) and we went RIGHT. This is a U-shape, not a staircase.

**Revised staircase** — fix wall-B so that the right opening and left opening are on the same side as the natural path:

Wall-A: y=4, x=1–5 (forces right before descending at step 1)  
Wall-B: y=7, x=6–10 (forces... wait let me reconsider)

For a "staircase right→down→right→down":
- Step 1: go right, then first descent (right half open)
- Step 2: go right again, then second descent (even-more-right area open)

Wall-A: y=4, x=1–4 (open x=5–10 → matrix must be at x≥3 to descend [anchor x=3 gives right-col x=5, not in wall])
Wall-B: y=7, x=1–7 (open x=8–10 → matrix must be at x≥6 to descend [anchor x=6 gives right-col x=8, not in wall-B])

```lua
gaps = {
    {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},
    {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},
}
```

Path for 3×3:  
- Anchor (1,1). Go right to anchor x=3 (right-col x=5, not in wall-A). But at anchor x=2: right-col x=4 → (4,4) gap → blocked (can't descend) ✓.  
  Actually wall-A is y=4, x=1–4. Anchor (2,1) going down to (2,2): bottom-row y=4, x=2–4. x=2,3,4 all gaps → BLOCKED ✓.  
  Anchor (3,1) going down to (3,2): bottom-row y=4, x=3–5. x=3,4 gaps → BLOCKED ✓.  
  Anchor (4,1) going down to (4,2): bottom-row y=4, x=4–6. x=4 gap → BLOCKED ✓.  
  Anchor (5,1) going down to (5,2): bottom-row y=4, x=5–7. No gaps → FREE ✓.  

- Must reach anchor x=5 to descend step 1. Go RIGHT to x=5, DOWN to y=4 (anchor y=1→2→3→4).  
- From anchor (5,4): go RIGHT to anchor x=6? Then DOWN: bottom-row y=7, x=6–8. wall-B(x=1–7): x=6,7 in wall → BLOCKED ✓.  
  Anchor (6,4), DOWN: bottom y=7, x=6–8 → x=6,7 in wall → BLOCKED ✓.  
  Anchor (7,4), DOWN: bottom y=7, x=7–9 → x=7 in wall → BLOCKED ✓.  
  Anchor (8,4), DOWN: bottom y=7, x=8–10 → no gaps → FREE ✓.  

- Must reach anchor x=8 at step 2. Go RIGHT from (5,4) to (8,4), then DOWN to y=7–8.
- Sink at (8,8): 3×3 at anchor (7,7) covers (7–9, 7–9) → (8,8) ✓. But anchor (8,7) is last step of descent.

This creates a true staircase: start (1,1) → right to x=5 → down to y=4 → right to x=8 → down to y=7 → WIN.

**Source** (1,1), **Sink** (8,8)  
**Ops offered**: `add_rows`, `scale_row`  
**Input**: `rows=3, cols=3, values={ {4,0,0},{2,1,0},{0,0,1} }`  
**Target**: `rows=3, cols=3, values={ {1,0,0},{0,1,0},{0,0,1} }` (row-reduce to identity)

Verify: scale_row(r=1, s=¼)? Must use integer scalars. Use different input:  
Input `{{2,0,0},{4,1,0},{0,0,1}}`:
- scale_row(r=1, s=1)? No. scale_row(r=2, s=1)?  
- add_rows(src=1, dst=2, scalar=-2): row2 = row2 + (-2)*row1 = {4,1,0}+(-2)*{2,0,0} = {0,1,0} ✓  
- Then scale_row(r=1, s=... ½) — not integer.  

Use input `{{1,0,0},{4,1,0},{0,0,1}}`:
- add_rows(src=1, dst=2, scalar=-4): row2 = {4,1,0}+(-4)*{1,0,0} = {0,1,0} ✓  
- Identity reached in ONE op. Too easy.

Use `{{2,4,0},{1,2,1},{0,0,1}}` → target identity:
- scale_row(r=1, s=... ½)? Not integer.

Use `{{3,0,0},{6,1,0},{0,0,1}}`:
- scale_row(r=1, s=... ⅓)? Not integer.

**Use non-identity target**: Input `{{1,2},{3,4}}` target after two steps.

Actually, for World 2 "Combos", the matrix goal doesn't need to be row-reduction. Keep it simple:

**Input**: `rows=2, cols=2, values={ {1,2},{0,4} }`  
Step 1: scale_row(r=2, s=2): `{{1,2},{0,8}}`  
Step 2: add_rows(src=2, dst=1, scalar=-1): `{{1,-6},{0,8}}`  
**Target**: `rows=2, cols=2, values={ {1,-6},{0,8} }` ✓  

Order matters: doing add_rows first → `{{1,6},{0,4}}` then scale_row → `{{1,6},{0,8}}` ≠ target.  
So scale_row on the FIRST step (placed on the first part of the staircase), add_rows on the second.

Updated source/sink for 2×2: source (1,1), sink (9,9). But with 2×2 matrix, recalculate walls:
- For 2×2 at anchor (ax,1) going down to (ax,2): bottom-row y=3, x=ax,ax+1. Wall-A at y=4 → no block at y=3. WRONG placement.

**Use y=3 for wall-A, y=6 for wall-B** for a 2×2 matrix staircase:
```lua
-- wall-A: y=3, x=1–3; wall-B: y=6, x=1–6
gaps = {
    {x=1,y=3},{x=2,y=3},{x=3,y=3},
    {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},
}
```
2×2: anchor (ax,2) going down to (ax,3): bottom-row y=3, x=ax,ax+1.
- ax=1: (1,3)(2,3) gaps → blocked ✓; ax=3: (3,3)(4,3) — x=3 gap → blocked ✓; ax=4: (4,3)(5,3) — no gap → free ✓.  
Anchor (ax,5) going down to (ax,6): bottom-row y=6, x=ax,ax+1.
- ax=5: (5,6)(6,6) gaps → blocked ✓; ax=7: (7,6)(8,6) — no gap → free ✓.

Path: source (1,1), right to x=4, down to y=3 (at anchor (4,2)→(4,3)). Right to x=7, down to y=6 (at anchor (7,5)→(7,6)). Reach sink (9,8): 2×2 at (8,7) covers (8–9, 7–8) → (9,8) ✓.

**Final puzzle 10**:  
Source (1,1), Sink (9,8), 2×2 matrix  
Wall-A: y=3, x=1–3; Wall-B: y=6, x=1–6  
**Ops offered**: `scale_row`, `add_rows`  
**Input**: `rows=2, cols=2, values={ {1,2},{0,4} }`  
**Target**: `rows=2, cols=2, values={ {1,-6},{0,8} }`  

---

### Puzzle 11 — "Corridor Cross" (2×3 matrix, Z-shape + size-fit corridor)

Keeps the original "size-fit" corridor concept (narrow passage forces transpose) but adds a vertical leg.

```
source (1,3)        sink (9,8)
route  right along y=3→4, narrow corridor at x=5–6 (only 2 rows wide),
       transit forces transpose (2×3 → 3×2), then continue right, then down to sink
```

Corridor: wall at x=5, y=1–2 and x=5, y=6–10; x=6, y=1–2 and x=6, y=6–10.  
(Same as original puzzle 11 corridor, but with source higher and sink lower to add a turn.)

Actually: keep the corridor exactly as original puzzle 11 (x=5–6 narrow at y=3–7, open y=5–6 for 2 rows). After passing, matrix is 3×2. Then add a wall forcing a downward leg:

Corridor gaps (original style):
```lua
{x=5,y=1},{x=5,y=2},{x=5,y=3},{x=5,y=4},  -- left wall of corridor
{x=5,y=7},{x=5,y=8},{x=5,y=9},{x=5,y=10},
{x=6,y=1},{x=6,y=2},{x=6,y=3},{x=6,y=4},
{x=6,y=7},{x=6,y=8},{x=6,y=9},{x=6,y=10},
```
Plus a wall forcing downward leg after the corridor:
```lua
{x=7,y=1},{x=8,y=1},{x=9,y=1},{x=10,y=1},  -- horizontal wall after corridor
{x=7,y=2},{x=8,y=2},{x=9,y=2},{x=10,y=2},
```

**Source** (1,5) [2×3: occupies x=1–3, y=5–6, corridor open at y=5–6 ✓]  
**Sink** (9,8) [3×2 post-transpose at anchor (8,7): covers x=8–9, y=7–8 → (9,8) ✓]

> Implementer: verify the corridor gap placement doesn't overlap source tile (source at y=5–6, corridor open at y=5–6 ✓). Check that after transpose the 3×2 matrix can exit the corridor and reach sink. The wall at x=7–10, y=1–2 forces the matrix down after exiting the corridor.

**Ops offered**: `transpose`  
**Input**: `rows=2, cols=3, values={ {1,2,3},{4,5,6} }`  
**Target**: `rows=3, cols=2, values={ {1,4},{2,5},{3,6} }`  

---

## Task D — Puzzles 12, 13, 14 (World 3: 3-turn routes, locked ops) [x]

**Files**: `data/puzzles/12_negate_swap.lua`, `data/puzzles/13_flip_scale.lua`, `data/puzzles/14_elimination.lua`

### Puzzle 12 — "Negate-Swap Arch" (2×2, full arch 3 turns: right→down→left→down)

```
source (1,2)        sink (1,9)
route  right to x=9, down to y=5–6, left to x=1, down to y=9
```

Half-arch walls:
```lua
-- wall-A: y=3–4, x=1–8 (open x=9–10 for descent on right)
-- wall-B: y=7–8, x=1–8 (open x=9–10 for return)
```

**Ops offered**: `negate`, `swap_rows`  
**Input**: `rows=2, cols=2, values={ {1,2},{3,4} }`  
**Target**: `rows=2, cols=2, values={ {-3,-4},{-1,-2} }`  

Implementer: same gap table as puzzle 9 (arch). Verify sink (1,9): 2×2 at anchor (1,8) covers (1–2, 8–9) → (1,9) ✓. Source (1,2): occupies y=2–3; wall-A at y=3–4 — overlap! **Fix: source (1,1)**, wall-A at y=3–4 (source occupies y=1–2, no overlap ✓).

**Updated**: source (1,1), sink (1,9)

---

### Puzzle 13 — "Flip Scale Maze" (2×2, Z-shape with locked op at bend)

```
source (1,1)        sink (9,10)
route  Z-shape (same as puzzle 6/7 walls)
locked scale_row (r=2, s=3) at (5,5) — fires when matrix passes through mid-grid
```

**Wall**: same Z as puzzle 6 (wall-A y=3–4 x=1–5; wall-B y=7–8 x=6–9).  
**Locked op**:
```lua
locked = { { kind="op", op="scale_row", x=5, y=5, params={row=2, scalar=3}, tile_rows=2 } },
```

**Ops offered**: `transpose`  
**Input**: `rows=2, cols=2, values={ {1,2},{1,4} }`  

Locked scale_row(r=2, s=3) fires when matrix passes (5,5). After: `{{1,2},{3,12}}`.  
Then player-placed transpose: `{{1,3},{2,12}}`.  
**Target**: `rows=2, cols=2, values={ {1,3},{2,12} }`  

Verify order: transpose then locked scale_row: `{{1,1},{2,4}}` → scale_row(2,3) = `{{1,1},{6,12}}` ≠ target.  
Only locked-then-transpose (which is enforced by route: locked is at x=5 on the left arm, player places transpose on right arm) gives target. ✓

---

### Puzzle 14 — "Three-Step Elimination" (3×3, staircase 3 turns)

```
source (1,1)        sink (8,9)
route  right→down→right→down  (staircase, same approach as puzzle 10)
wall-A y=4, x=1–4; wall-B y=7, x=1–7
```

**Wall** (same staircase as puzzle 10 but for 3×3):  
```lua
gaps = {
    {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},
    {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},
}
```
(Same analysis as puzzle 10 World-2 staircase, but with 3×3: anchor must reach x=5 for step1, x=8 for step2 — verify OP_SIZES.)

**Ops offered**: `add_rows`, `scale_row`  
**Input**: `rows=3, cols=3, values={ {2,1,0},{4,3,1},{0,0,1} }`  

Need 3 ops → target reachable in 3 steps. But only 2 op types. Matrix visits ops placed on staircase in order.  
Use: scale_row(r=1, s=2): `{{4,2,0},{4,3,1},{0,0,1}}`. Then add_rows(src=1, dst=2, s=-1): `{{4,2,0},{0,1,1},{0,0,1}}`. Then add_rows(src=... ` — this gets complex.

Simpler: **Input**: `{{1,2},{3,4}}` (2×2) with 3 ops visited but only 2 unique. OR just 2 ops and use the staircase routing without requiring 3 distinct op steps.

**Keep as 2 ops, 2×2** (the staircase provides the routing challenge; 2 ops is enough):
Source (1,1), sink (9,8)  
Wall-A y=3, x=1–3; Wall-B y=6, x=1–6 (same as puzzle 10).  
**Ops offered**: `add_rows`, `scale_row`  
**Input**: `rows=2, cols=2, values={ {2,0},{1,3} }`  
Step 1 (early staircase): scale_row(r=1, s=2): `{{4,0},{1,3}}`  
Step 2 (late staircase): add_rows(src=1, dst=2, s=-1): row2 = {1,3}+(-1)*{4,0}={-3,3}: `{{4,0},{-3,3}}`  
**Target**: `rows=2, cols=2, values={ {4,0},{-3,3} }`  
Verify reverse: add_rows first → `{{2,0},{-1,3}}`, then scale_row(r=1,s=2) → `{{4,0},{-1,3}}` ≠ target. ✓ (order matters)

---

## Task E — Puzzles 15, 16 (World 3: more advanced) [x]

**Files**: `data/puzzles/15_scale_swap.lua`, `data/puzzles/16_triple.lua`

### Puzzle 15 — "Scale-Swap Detour" (3×3, Z-shape with locked op)

```
source (1,1)        sink (8,9)
route  Z-shape (walls adjusted for 3×3: wall-A y=4–5 x=1–5; wall-B y=7–8 x=6–9)
locked swap_rows(1,3) at corner of Z-route
```

**Locked op**: `{ kind="op", op="swap_rows", x=4, y=6, params={row_a=1, row_b=3}, tile_rows=2 }`  
(Fires mid-route; implementer places it at a cell the matrix must traverse)

**Ops offered**: `scale_row`  
**Input**: `rows=3, cols=3, values={ {1,0,0},{0,2,0},{3,0,0} }`  
Target after locked swap_rows(1,3): `{{3,0,0},{0,2,0},{1,0,0}}`. Then scale_row(r=2, s=3): `{{3,0,0},{0,6,0},{1,0,0}}`.  
**Target**: `rows=3, cols=3, values={ {3,0,0},{0,6,0},{1,0,0} }`

---

### Puzzle 16 — "Triple Bend" (2×2, S-shape: 3 turns)

```
source (1,1)        sink (9,10)
route  right→down→right→down (S-shaped staircase, two walls)
wall-A y=3, x=1–3; wall-B y=7, x=5–10
```

**Ops offered**: `transpose`, `negate`, `scale_row`  
**Input**: `rows=2, cols=2, values={ {1,2},{3,4} }`  
3-op path:
- scale_row(r=1, s=2): `{{2,4},{3,4}}`  
- transpose: `{{2,3},{4,4}}`  
- negate: `{{-2,-3},{-4,-4}}`  
**Target**: `rows=2, cols=2, values={ {-2,-3},{-4,-4} }` ✓  
(Different orderings give different results — player figures out order via staircase arm layout)

---

## Task F — Puzzles 17, 18, 19, 20 (World 4: transforms) [x]

**Files**: `data/puzzles/17_add_rows.lua`, `data/puzzles/18_col_ops.lua`, `data/puzzles/19_flips.lua`, `data/puzzles/20_abs_rotate.lua`

### Puzzle 17 — "Row Reduction Spiral" (3×3, Z-shape with locked add_rows at bend)

Source (1,1), Sink (8,9)  
Wall: Z-walls adjusted for 3×3 (wall-A y=4–5 x=1–5; wall-B y=7–8 x=6–9)  
Locked op: `add_rows` at (5,6): `{ kind="op", op="add_rows", x=5, y=6, params={src=1, dst=2, scalar=-2} }`  
**Ops offered**: `scale_row`  
**Input**: `rows=3, cols=3, values={ {1,0,0},{2,1,0},{0,0,1} }`  
Locked add_rows(src=1,dst=2,s=-2): row2={2,1,0}+(-2)*{1,0,0}={0,1,0}: `{{1,0,0},{0,1,0},{0,0,1}}`.  
Then scale_row? Identity — no need. So either: (a) locked fires, done; or (b) add more ops.

Use non-identity target:  
**Input**: `rows=3, cols=3, values={ {2,0,0},{4,1,0},{0,0,3} }`  
Locked add_rows(src=1,dst=2,s=-2): row2={4,1,0}+(-2)*{2,0,0}={0,1,0}: `{{2,0,0},{0,1,0},{0,0,3}}`.  
Player places scale_row(r=1,s=... ½)? Not integer.  
Player places scale_row(r=3,s=... ⅓)? Not integer.

**Use easier input**:  
**Input**: `rows=3, cols=3, values={ {1,0,0},{3,1,0},{0,0,2} }`  
Locked add_rows(src=1,dst=2,s=-3): row2={3,1,0}+(-3)*{1,0,0}={0,1,0}: `{{1,0,0},{0,1,0},{0,0,2}}`.  
Player places scale_row(r=3, s=2): `{{1,0,0},{0,1,0},{0,0,4}}`.  
**Target**: `rows=3, cols=3, values={ {1,0,0},{0,1,0},{0,0,4} }` ✓

---

### Puzzle 18 — "Column Work Maze" (2×2, staircase with col ops)

Source (1,1), Sink (9,8)  
Wall: staircase (wall-A y=3 x=1–3; wall-B y=6 x=1–6)  
**Ops offered**: `swap_cols`, `scale_col`  
**Input**: `rows=2, cols=2, values={ {3,1},{6,2} }`  
Step 1: scale_col(c=1, s=... ⅓)? Not integer. Use `{{1,2},{3,4}}`:  
swap_cols(1,2): `{{2,1},{4,3}}`; scale_col(c=2, s=2): `{{2,2},{4,6}}`.  
**Target**: `rows=2, cols=2, values={ {2,2},{4,6} }` ✓  
**Input**: `rows=2, cols=2, values={ {1,2},{3,4} }`  

---

### Puzzle 19 — "Mirror Maze" (2×3, U-arch)

Source (1,2), Sink (9,2) [same row — arch means going down and coming back]  
Wall: arch walls (wall-A y=3–4 x=1–10 except x=4–7 for 4-wide descent corridor; wall-B y=7–8 same)  
> Implementer: design gaps so a 2×3 matrix can descend through the x=4–6 corridor and return.

**Ops offered**: `flip_h`, `flip_v`  
**Input**: `rows=2, cols=3, values={ {1,2,3},{4,5,6} }`  
flip_h then flip_v: `{{3,2,1},{6,5,4}}` → `{{6,5,4},{3,2,1}}`.  
flip_v then flip_h: `{{4,5,6},{1,2,3}}` → `{{6,5,4},{3,2,1}}`. Same! (flip_h and flip_v commute.)  
**Target**: `rows=2, cols=3, values={ {6,5,4},{3,2,1} }` ✓ (both orderings valid)

---

### Puzzle 20 — "Absolute Rotation" (2×2, Z-shape with locked rotate_90 at bend)

Source (1,1), Sink (9,10)  
Wall: Z-shape (wall-A y=3–4 x=1–5; wall-B y=7–8 x=6–9)  
Locked rotate_90 at (5,5): `{ kind="op", op="rotate_90", x=5, y=5 }`  
**Ops offered**: `abs`  
**Input**: `rows=2, cols=2, values={ {-1,2},{-3,4} }`  
Player applies abs first (anywhere before locked rotate): `{{1,2},{3,4}}`.  
Locked rotate_90: `{{3,1},{4,2}}`.  
**Target**: `rows=2, cols=2, values={ {3,1},{4,2} }` ✓  

Verify: rotate first (locked) then abs: `{{-3,-1},{4,2}}` → `{{3,1},{4,2}}` same! Commute for this input.  
So choose different input: `{{-1,2},{3,-4}}`.  
abs: `{{1,2},{3,4}}` → rotate: `{{3,1},{4,2}}`.  
rotate first: `{{3,-1},{-4,2}}` → abs: `{{3,1},{4,2}}`. Same again.  
abs and rotate_90 always commute (abs is elementwise, rotate is positional).  

**Keep two valid solutions** — puzzle interest is the routing + identifying both abs and rotate_90 contribute.

---

## Task G — Puzzles 21, 22, 23 (World 5: fixed/locked pieces, 3–4 turns) [x]

**Files**: `data/puzzles/21_fixed_player.lua`, `data/puzzles/22_fixed_puzzle.lua`, `data/puzzles/23_locked_scale.lua`

### Puzzle 21 — "Fixed Tools, Bent Path" (2×2, staircase with fixed_ops)

Source (1,1), Sink (9,9)  
Wall: S-staircase (wall-A y=3 x=1–3; wall-B y=6 x=1–6; wall-C y=9? — optional 3rd step)  

Actually 3 turns: wall-A y=3 x=1–3; wall-B y=6 x=4–9 (forces LEFT step).

```lua
gaps = {
    {x=1,y=3},{x=2,y=3},{x=3,y=3},          -- wall-A: open x=4+
    {x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},{x=8,y=6},{x=9,y=6},{x=10,y=6}, -- wall-B: open x=1–3
}
```

Path for 2×2: right to x=4, down to y=3, LEFT? No — left would go backwards. 

**Revised**: use two staircase walls that BOTH have right-opening:  
wall-A y=3 x=1–3 (right-open), wall-B y=7 x=1–6 (right-open).  
Path: right to x=4, down to y=3, right to x=7, down to y=7, right to x=9 → sink.

```lua
gaps = {
    {x=1,y=3},{x=2,y=3},{x=3,y=3},
    {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},
}
```

**fixed_ops**: `swap_rows`, `negate` (player can place them anywhere but can't erase them once placed)  
**ops**: `{}` (no palette ops — player must use only fixed_ops)  
**Input**: `rows=2, cols=2, values={ {1,2},{3,4} }`  
**Target**: `rows=2, cols=2, values={ {-3,-4},{-1,-2} }` (negate+swap or swap+negate)  

---

### Puzzle 22 — "Mandatory Negate, Arch Path" (2×2, arch 3 turns)

Source (1,1), Sink (9,1) [same row, top — arch dips down]  
Wall: arch walls (wall-A y=3–4 x=1–10 except x=5–6; wall-B y=7–8 x=1–10 except x=5–6)  
Locked negate at arch bottom: `{ kind="op", op="negate", x=5, y=6 }` (fires at bottom of arch)  
**ops**: `{}`  
**Input**: `rows=2, cols=2, values={ {1,2},{3,4} }`  
**Target**: `rows=2, cols=2, values={ {-1,-2},{-3,-4} }` (negate only)

Verify source/sink: source (1,1) occupies y=1–2. Wall-A at y=3–4: no overlap ✓.  
Sink (9,1): 2×2 at anchor (8,1) covers (8–9, 1–2) → (9,1) ✓.

---

### Puzzle 23 — "Locked Scale, Full Maze" (2×2, 4-turn snake)

Source (1,1), Sink (9,10)  
4 walls create a snake-channel (right→down→left→down→right):
```
wall-A y=3, x=1–6     (step 1 open right)
wall-B y=6, x=4–10    (step 2 open left)
wall-C y=9, x=1–6     (step 3 open right)
```

```lua
gaps = {
    {x=1,y=3},{x=2,y=3},{x=3,y=3},{x=4,y=3},{x=5,y=3},{x=6,y=3},
    {x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},{x=8,y=6},{x=9,y=6},{x=10,y=6},
    {x=1,y=9},{x=2,y=9},{x=3,y=9},{x=4,y=9},{x=5,y=9},{x=6,y=9},
}
```

Locked scale_row at (5,5): `{ kind="op", op="scale_row", x=5, y=4, params={row=1, scalar=3}, tile_rows=2 }`  
**Ops offered**: `transpose`, `negate`  
**Input**: `rows=2, cols=2, values={ {1,2},{0,1} }`  

Path fires: locked scale_row(r=1,s=3) → `{{3,6},{0,1}}`. Then player places transpose: `{{3,0},{6,1}}`. Then negate: `{{-3,0},{-6,-1}}`.  
**Target**: `rows=2, cols=2, values={ {-3,0},{-6,-1} }` ✓

> Implementer: verify the 4-turn path works with a 2×2 matrix footprint at each wall:
> - wall-A: anchor must reach x≥7 to descend (wall x=1–6, 2×2 right-col x+1 must not be in 1–6 → ax≥7) wait: ax right-col = ax+1; gap at x=1–6: blocked if ax+1 ≤ 6 i.e. ax ≤ 5. FREE when ax ≥ 6 (ax+1=7 not in 1–6) ✓.
> - wall-B (open left, x=1–3): blocked if ax+1 in 4–10 i.e. ax ≥ 3. FREE when ax ≤ 2.
> - wall-C: same as wall-A, must reach ax ≥ 6 again.
> Path: (1,1)→right to x=6→down to y=3→left to x=2→down to y=6→right to x=6→down to y=9→right to x=8 → sink (9,10) covered by 2×2 at (8,9) ✓.

---

## Task H — New UI spec: solve a routed puzzle end-to-end [x]

**File**: `tests/ui/06_solve_routed_puzzle.lua` (05 was already taken by start_screen spec)

Write a UI spec that:
1. Opens puzzle 3 ("Sharp Left") from level select.
2. Places a pusher, sets its timeline to go right several slots then down.
3. Places a negate op somewhere on the route.
4. Runs and asserts `win`.

This confirms that a one-turn puzzle can actually be solved via real input, exercising the new routing. Use `click_cell`, `click_slot`, `click_button` as in `tests/ui/01_solve_puzzle_1.lua`.

Exact timeline depends on the final grid layout — derive the step count from source (1,2) to sink (9,8) after implementing puzzle 3. Assert `wait_until = { text = "SOLVED!", max_frames = 3000 }`.

---

## Verification steps (all tasks)

After completing all tasks:
1. `love . --headless` — all tests green (no crashes, all puzzles load).
2. Manual play: open each redesigned puzzle and confirm a valid solution exists.
3. Check `tests/ui/04_sweep_all_puzzles.lua` still passes (puzzle names update automatically).
