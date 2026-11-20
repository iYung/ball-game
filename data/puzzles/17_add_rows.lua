-- Row Reduction: add_rows then scale on 3×3 matrix, L-route
-- Source (2,2): 3×3 occupies x=2–4, y=2–4; wall starts at y=5 to avoid overlap
-- Wall: y=5, x=1–5 (forces 3×3 right to ax≥6 before descending)
-- Locked add_rows(1→2,-3) at (5,3): fires during rightward phase (matrix at ax=3–5, ay=2 covers (5,3))
-- Sink (8,9): 3×3 at anchor (6,7) covers (6–8, 7–9) → (8,9) ✓
-- Solution: locked add fires → {{1,0,0},{0,1,0},{0,0,2}}; player scale_row(3,2) → target ✓
return {
    name   = "Row Reduction Spiral",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=8, y=9 },
    ops    = { "scale_row" },
    input  = { rows=3, cols=3, values={ {1,0,0},{3,1,0},{0,0,2} } },
    target = { rows=3, cols=3, values={ {1,0,0},{0,1,0},{0,0,4} } },
    gaps   = {
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},
    },
    locked = {
        { kind="op", op="add_rows", x=5, y=3, params={src=1, dst=2, scalar=-3} },
    },
}
