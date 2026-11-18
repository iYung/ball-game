-- transpose: 2×3 → 3×2 to fit through the 2-wide corridor at x=5–6
return {
    name   = "Tight Fit",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = { "transpose" },
    sink   = { x=9, y=5 },
    input  = { rows=2, cols=3, values={ {1,2,3}, {4,5,6} } },
    target = { rows=3, cols=2, values={ {1,4}, {2,5}, {3,6} } },
    gaps = {
        {x=5,y=1},{x=5,y=2},{x=5,y=3},{x=5,y=4},
        {x=5,y=7},{x=5,y=8},{x=5,y=9},{x=5,y=10},
        {x=6,y=1},{x=6,y=2},{x=6,y=3},{x=6,y=4},
        {x=6,y=7},{x=6,y=8},{x=6,y=9},{x=6,y=10},
    },
}
