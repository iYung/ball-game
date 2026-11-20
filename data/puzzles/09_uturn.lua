-- "Arch": source top-left, sink bottom-left.
-- Matrix goes RIGHT across top, DOWN on right side, LEFT across bottom.
-- Wall-A (y=3–4, x=1–8) forces matrix to x≥9 before descending.
-- Wall-B (y=6–7, x=1–8) forces matrix to stay at x=9 before returning left.
return {
    name   = "Arch",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=1, y=9 },
    ops    = { "negate", "swap_rows" },
    input  = { rows=2, cols=2, values={ {1,2},{3,4} } },
    target = { rows=2, cols=2, values={ {-3,-4},{-1,-2} } },
    gaps = {
        -- Wall-A: y=3–4, x=1–8 (open only x=9–10 for descent on right)
        {x=1,y=3},{x=4,y=3},{x=5,y=3},{x=6,y=3},{x=7,y=3},{x=8,y=3},
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},{x=6,y=4},{x=7,y=4},{x=8,y=4},
        -- Wall-B: y=6–7, x=1–8 (open only x=9–10 for return leg)
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},{x=7,y=6},{x=8,y=6},
        {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},{x=7,y=7},{x=8,y=7},
    },
}
