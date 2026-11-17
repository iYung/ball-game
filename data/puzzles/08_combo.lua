-- scale_row(1, -1): row1 = -1 * [2,0,0] = [-2,0,0]
return {
    name   = "Combo",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    sink   = { x=10, y=5 },
    input  = { rows=3, cols=3, values={ {2,0,0}, {0,3,0}, {0,0,1} } },
    target = { rows=3, cols=3, values={ {-2,0,0}, {0,3,0}, {0,0,1} } },
}
