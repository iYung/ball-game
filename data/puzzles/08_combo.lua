-- Corner Scale: edge_scale on 3×3 matrix, L-route
-- Solution: x-1 on the top edge (the left edge also works)
-- Source (2,2): 3×3 occupies x=2–4, y=2–4; wall starts at y=5 to avoid overlap
-- Wall: y=5, x=1–5 (forces 3×3 right to ax≥6 before descending)
-- Sink (8,8): 3×3 at anchor (6,6) covers (6–8, 6–8) → (8,8) ✓
return {
    name   = "Corner Scale",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=8, y=8 },
    ops    = { "edge_scale" },
    input  = { rows=3, cols=3, values={ {2,0,0}, {0,3,0}, {0,0,1} } },
    target = { rows=3, cols=3, values={ {-2,0,0}, {0,3,0}, {0,0,1} } },
    gaps   = {
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},
    },
}
