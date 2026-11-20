return {
    name   = "Scale-Swap Detour",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=8, y=9 },
    ops    = { "scale_row" },
    input  = { rows=3, cols=3, values={ {1,0,0},{0,2,0},{3,0,0} } },
    target = { rows=3, cols=3, values={ {3,0,0},{0,6,0},{1,0,0} } },
    gaps   = {
        {x=1,y=4},{x=5,y=4},
        {x=1,y=5},{x=2,y=5},{x=3,y=5},{x=4,y=5},{x=5,y=5},
        {x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},
        {x=6,y=8},{x=7,y=8},{x=8,y=8},{x=9,y=8},
    },
    locked = {
        { kind="op", op="swap_rows", x=5, y=6, params={row_a=1, row_b=3}, tile_rows=2 },
    },
}
