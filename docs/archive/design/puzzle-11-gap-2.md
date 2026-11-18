# Puzzle 11 — Shrink Corridor Gap from 3 to 2

## Goal
Tighten the corridor in puzzle 11 ("Tight Fit") from a 3-row opening to a 2-row opening. This makes the puzzle harder because the transposed 3×2 matrix no longer fits through the gap — requiring a different solution strategy.

## Affected files
- `data/puzzles/11_rotate_gap.lua`

## What changes
The gap walls at x=5 and x=6 currently leave y=4,5,6 open (3 rows). The new layout blocks y=4 as well, leaving only y=5 and y=6 open (2 rows).

**Current blocked cells:**
- x=5: y=1,2,3 (top) and y=7,8,9,10 (bottom) → open: y=4,5,6
- x=6: y=1,2,3 (top) and y=7,8,9,10 (bottom) → open: y=4,5,6

**New blocked cells:**
- x=5: y=1,2,3,4 (top) and y=7,8,9,10 (bottom) → open: y=5,6
- x=6: y=1,2,3,4 (top) and y=7,8,9,10 (bottom) → open: y=5,6

This is a one-cell addition per column (`{x=5,y=4}` and `{x=6,y=4}`).

## What stays the same
- Grid dimensions (10×10)
- Source position (x=2, y=5)
- Sink position (x=9, y=5)
- Op list (`{ "transpose" }`)
- Input matrix (2×3) and target matrix (3×2) — untouched for now

## Open questions
- **Solvability:** With a 2-row gap, the transposed 3×2 matrix (rows y=5–7) is blocked. The untransposed 2×3 input (rows y=5–6) fits through but doesn't match the target. The puzzle as changed will be unsolvable until the input/target/ops are redesigned. The user has explicitly deferred that redesign to a later phase.
