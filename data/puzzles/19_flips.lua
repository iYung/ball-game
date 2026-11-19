return {
    name   = "Mirror Mirror",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=4 },
    ops    = { "flip_h", "flip_v" },
    sink   = { x=10, y=4 },
    input  = { rows=2, cols=3, values={ {1,2,3}, {4,5,6} } },
    target = { rows=2, cols=3, values={ {6,5,4}, {3,2,1} } },
}
