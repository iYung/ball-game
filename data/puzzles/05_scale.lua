return {
    name   = "Scale Up",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = { "scale_row" },  -- op tiles offered in the palette
    sink   = { x=10, y=5 },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {2,4}, {3,4} } },
}
