return {
    name   = "Locked Scale Row",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = {},
    locked = {
        { kind="op", op="scale_row", x=5, y=3, params={row=1, scalar=3}, tile_rows=4 },
    },
    sink   = { x=10, y=5 },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {3,6}, {3,4} } },
}
