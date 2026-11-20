-- "Staircase": two-step staircase route, source top-left, sink bottom-right.
-- Wall-A (y=3, x=1–3): matrix must reach anchor x≥4 to descend past y=2.
-- Wall-B (y=6, x=1–6): matrix must reach anchor x≥7 to descend past y=5.
-- Op ordering matters: scale_row(r=2,s=2) first, then add_rows(src=2,dst=1,scalar=-1).
return {
    name   = "Staircase",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=8 },
    ops    = { "scale_row", "add_rows" },
    input  = { rows=2, cols=2, values={ {1,2},{0,4} } },
    target = { rows=2, cols=2, values={ {1,-6},{0,8} } },
    gaps = {
        -- Wall-A: y=3, x=1–3 (open x=4–10 for step-1 descent)
        {x=1,y=4},{x=2,y=4},{x=3,y=4},
        -- Wall-B: y=6, x=1–6 (open x=7–10 for step-2 descent)
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},
    },
}
