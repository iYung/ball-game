return {
    name   = "Locked Scale, Full Maze",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=10 },
    ops    = { "transpose", "negate" },
    locked = {
        { kind="op", op="scale_row", x=5, y=3, params={row=1, scalar=3} },
    },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},{x=6,y=4},
        {x=4,y=6},{x=6,y=6},{x=7,y=6},{x=8,y=6},{x=9,y=6},{x=10,y=6},
        {x=1,y=9},{x=2,y=9},{x=3,y=9},{x=4,y=9},{x=5,y=9},{x=6,y=9},
    },
    input  = { rows=2, cols=2, values={ {1,2}, {0,1} } },
    target = { rows=2, cols=2, values={ {-3,0}, {-6,-1} } },
}
