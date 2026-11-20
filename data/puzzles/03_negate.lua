return {
    name   = "Sharp Left",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=8 },
    ops    = { "negate" },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {-1,-2}, {-3,-4} } },
    gaps   = {
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},
    },
}
