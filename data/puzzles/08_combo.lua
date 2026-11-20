-- Tight Z: scale_row on 3×3 matrix, Z-route with walls adjusted for larger source
-- Source (1,1): 3×3 occupies x=1–3, y=1–3; wall-A starts at y=4 to avoid overlap
-- Wall-A: y=4–5, x=1–5 (forces 3×3 right to ax≥6 before descending)
-- Wall-B: y=7–8, x=6–9 (forces 3×3 left to ax≤2 before descending past y=6)
-- Sink (8,8): 3×3 at anchor (6,6) covers (6–8, 6–8) → (8,8) ✓
return {
    name   = "Tight Z",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=8, y=8 },
    ops    = { "scale_row" },
    input  = { rows=3, cols=3, values={ {2,0,0}, {0,3,0}, {0,0,1} } },
    target = { rows=3, cols=3, values={ {-2,0,0}, {0,3,0}, {0,0,1} } },
    gaps   = {
        {x=1,y=4},{x=5,y=4},
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},
        {x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},
        {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
    },
}
