-- "Arch": source top-left, sink bottom-left.
-- Matrix goes RIGHT across y=2, DOWN on right side (x=8–9), LEFT across y=8–9 bottom.
-- Wall-A (y=4, x=1–7) forces matrix to anchor x≥8 before descending.
-- Wall-B (y=6–7, x=1–7) forces matrix to stay at x=8 before returning left.
-- Route: RIGHT×6 (2,2→8,2), DOWN×6 (8,2→8,8), LEFT×7 (8,8→1,8). Win!
-- Pushers: R at (1,3) right×6; D at (9,1) down×6; L at (10,8) left×7.
-- DOWN pusher D at (9,1): y=1 is NOT in footprint [8,9]×[2,3] during RIGHT phase → no conflict.
-- LEFT pusher L at (10,8): x=10 is NOT in footprint [8,9]×[ay,ay+1] during DOWN phase → no conflict.
return {
    name   = "Arch",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=1, y=9 },
    ops    = { "negate", "swap_rows" },
    input  = { rows=2, cols=2, values={ {1,2},{3,4} } },
    target = { rows=2, cols=2, values={ {-3,-4},{-1,-2} } },
    gaps = {
        -- Wall-A: y=4, x=1–7 (open x=8–10; forces descent at x≥8)
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},
        -- Wall-B: y=6–7, x=1–7 (open x=8–10; channels return leg at x≥8)
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},
        {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},
    },
}
