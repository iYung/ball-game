return {
    name   = "Mandatory Negate, Arch Path",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=1 },
    ops    = {},
    locked = {
        { kind="op", op="negate", x=5, y=6 },
    },
    gaps   = {
        {x=1,y=3},{x=4,y=3},
        {x=7,y=3},{x=8,y=3},{x=9,y=3},{x=10,y=3},
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},
        {x=7,y=4},{x=8,y=4},{x=9,y=4},{x=10,y=4},
        {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},
        {x=7,y=7},{x=8,y=7},{x=9,y=7},{x=10,y=7},
        {x=1,y=8},{x=2,y=8},{x=3,y=8},{x=4,y=8},
        {x=7,y=8},{x=8,y=8},{x=9,y=8},{x=10,y=8},
    },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {-1,-2}, {-3,-4} } },
}
