return {
    name   = "Drop First",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=8, y=8 },
    ops    = { "swap_rows" },
    input  = { rows=3, cols=3, values={ {0,0,1},{0,1,0},{1,0,0} } },
    target = { rows=3, cols=3, values={ {1,0,0},{0,1,0},{0,0,1} } },
    gaps   = {
        {x=6,y=1},{x=6,y=2},{x=6,y=3},{x=6,y=4},{x=6,y=5},
    },
}
