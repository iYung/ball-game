return {
    name   = "Squeeze Bend",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=3 },
    sink   = { x=8, y=8 },
    ops    = { "transpose" },
    input  = { rows=2, cols=3, values={ {1,2,3},{4,5,6} } },
    target = { rows=3, cols=2, values={ {1,4},{2,5},{3,6} } },
    gaps   = {
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},
    },
}
