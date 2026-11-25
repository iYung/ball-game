return {
    name   = "Identity Check",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    sink   = { x=10, y=5 },
    input  = { rows=2, cols=2, values={ {1,0}, {0,1} } },
    target = { rows=2, cols=2, values={ {1,0}, {0,1} } },
}
