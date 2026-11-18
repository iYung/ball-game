return {
    name   = "Elimination",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = { "add_rows", "scale_row" },
    sink   = { x=10, y=5 },
    input  = { rows=3, cols=3, values={ {2,0,0}, {4,1,0}, {0,0,1} } },
    target = { rows=3, cols=3, values={ {1,0,0}, {0,1,0}, {0,0,1} } },
}
