-- "Deep Arch": taller dead zone than puzzle 09 — wall-B spans 3 rows (y=5–7) instead of 2.
-- Wall-A (y=4, x=1–7) forces matrix right to ax≥8 before descending.
-- Wall-B (y=5–7, x=1–7) forces matrix to stay at ax≥8 for a longer stretch.
-- Route: RIGHT×6 (2,2→8,2), DOWN×6 (8,2→8,8), LEFT×7 (8,8→1,8). Win!
-- Pushers: R at (1,3) right×6; D at (9,1) down×6; L at (10,8) left×7.
-- Sink (1,9): 2×2 at anchor (1,8) covers (1–2, 8–9) → (1,9) ✓
-- Ops: scalar_mul (x-1) + flip_v (either order gives {{-3,-4},{-1,-2}}).
return {
    name   = "Deep Arch",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=1, y=9 },
    ops    = { "scalar_mul", "flip_v" },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {-3,-4}, {-1,-2} } },
    gaps   = {
        -- Wall-A: y=4, x=1–7 (open x=8–10)
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},
        -- Wall-B: y=5–7, x=1–7 (open x=8–10; one extra row vs. puzzle 09)
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},{x=6,y=5},{x=7,y=5},
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},
        {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},
    },
}
