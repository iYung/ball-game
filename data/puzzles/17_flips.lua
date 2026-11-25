return {
    name   = "Mirror Maze",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=2 },
    ops    = { "flip_h", "flip_v" },
    input  = { rows=2, cols=3, values={ {1,2,3},{4,5,6} } },
    target = { rows=2, cols=3, values={ {6,5,4},{3,2,1} } },
    gaps   = {
        -- wall-A: y=4-5, open only x=5-7
        {x=1,y=4},{x=2,y=4},{x=3,y=4},{x=4,y=4},
        {x=8,y=4},{x=9,y=4},{x=10,y=4},
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},
        {x=8,y=5},{x=9,y=5},{x=10,y=5},
        -- wall-B: y=7-8, open only x=5-7
        {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},
        {x=8,y=7},{x=9,y=7},{x=10,y=7},
        {x=1,y=8},{x=2,y=8},{x=3,y=8},{x=4,y=8},
        {x=8,y=8},{x=9,y=8},{x=10,y=8},
    },
}
