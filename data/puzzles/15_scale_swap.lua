-- Scale-Swap Detour: swap then scale on 3×3 matrix, L-route
-- Source (2,2): 3×3 occupies x=2–4, y=2–4; wall starts at y=5 to avoid overlap
-- Wall: y=5, x=1–5 (forces 3×3 right to ax≥6 before descending)
-- Locked swap_rows(1,3) at (5,3): fires during rightward phase (matrix at ax=3–5, ay=2 covers (5,3))
-- Sink (8,9): 3×3 at anchor (6,7) covers (6–8, 7–9) → (8,9) ✓
-- Solution: locked swap fires first → {{3,0,0},{0,2,0},{1,0,0}}; player scale_row(2,3) → target ✓
return {
    name   = "Scale-Swap Detour",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=8, y=9 },
    ops    = { "scale_row" },
    input  = { rows=3, cols=3, values={ {1,0,0},{0,2,0},{3,0,0} } },
    target = { rows=3, cols=3, values={ {3,0,0},{0,6,0},{1,0,0} } },
    gaps   = {
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},
    },
    locked = {
        { kind="op", op="swap_rows", x=5, y=3, params={row_a=1, row_b=3}, tile_rows=2 },
    },
}
