-- Ordered Ops: edge_scale + flip_v, same Z-route as puzzle 6
-- The scaled edge depends on the order; both of these produce the target:
--   x2 top then FLv:    {{1,2},{3,4}} → {{2,4},{3,4}} → {{3,4},{2,4}} ✓
--   FLv then x2 bottom: {{1,2},{3,4}} → {{3,4},{1,2}} → {{3,4},{2,4}} ✓
-- Wall-A: y=4, x=1–5 (forces matrix right to ax≥6 before descending)
-- Wall-B: y=8, x=6–9 (forces matrix left to ax≤4 before descending past y=7)
-- Same route as puzzle 6: RIGHT×4, DOWN×4, LEFT×2, DOWN×3, RIGHT×4
return {
    name   = "Ordered Ops",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=10 },
    ops    = { "edge_scale", "flip_v" },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {3,4}, {2,4} } },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
        {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
    },
}
