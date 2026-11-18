return {
    name   = "Scale & Swap",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = { "scale_row", "swap_rows" },
    sink   = { x=10, y=5 },
    input  = { rows=3, cols=3, values={ {1,2,3}, {0,0,0}, {7,8,9} } },
    target = { rows=3, cols=3, values={ {7,8,9}, {0,0,0}, {-1,-2,-3} } },
}
