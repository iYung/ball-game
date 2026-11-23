-- Z-Bend: negate + swap_rows, Z-route with two half-walls
-- Wall-A: y=4, x=1–5 (forces matrix right to ax≥6 before descending)
-- Wall-B: y=8, x=6–9 (forces matrix left to ax≤4 before descending past y=7)
-- Sink (9,10): 2×2 at anchor (8,9) covers (8–9, 9–10) → (9,10) ✓
-- Route: RIGHT×4 (2,2)→(6,2), DOWN×4 (6,2)→(6,6), LEFT×2 (6,6)→(4,6),
--        DOWN×3 (4,6)→(4,9), RIGHT×4 (4,9)→(8,9)
-- Pushers: (1,2)→R×4, (7,1)→D×4, (8,6)→L×2, (5,5)→D×3, (3,9)→R×4
return {
    name   = "Z-Bend",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=10 },
    ops    = { "negate", "swap_rows" },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {-3,-4}, {-1,-2} } },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
        {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
    },
}
