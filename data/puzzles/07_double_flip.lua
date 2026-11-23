-- Ordered Ops: scale_row + swap_rows, same Z-route as puzzle 6
-- Only scale_row-first ordering produces the target:
--   scale_row(r=1,s=2) then swap_rows(1,2): {{2,4},{3,4}} → {{3,4},{2,4}} ✓
--   swap_rows(1,2) then scale_row(r=1,s=2): {{3,4},{1,2}} → {{6,8},{1,2}} ✗
-- Wall-A: y=4, x=1–5 (forces matrix right to ax≥6 before descending)
-- Wall-B: y=8, x=6–9 (forces matrix left to ax≤4 before descending past y=7)
-- Same route as puzzle 6: RIGHT×4, DOWN×4, LEFT×2, DOWN×3, RIGHT×4
return {
    name   = "Ordered Ops",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=10 },
    ops    = { "scale_row", "swap_rows" },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {3,4}, {2,4} } },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
        {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
    },
}
