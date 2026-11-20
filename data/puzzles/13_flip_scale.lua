return {
    name   = "Flip Scale Maze",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=10 },
    ops    = { "transpose" },
    input  = { rows=2, cols=2, values={ {1,2}, {1,4} } },
    target = { rows=2, cols=2, values={ {1,3}, {2,12} } },
    gaps   = {
        {x=1,y=3},{x=4,y=3},{x=5,y=3},
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=5,y=4},
        {x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},
        {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
    },
    locked = {
        { kind="op", op="scale_row", x=5, y=5, params={row=2, scalar=3}, tile_rows=2 },
    },
}
