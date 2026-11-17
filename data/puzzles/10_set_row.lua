-- set_row(row=2, values={4,5,6}): replace the middle row to complete the sequential matrix
return {
    name   = "Set Row",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = { "set_row" },
    sink   = { x=10, y=5 },
    input  = { rows=3, cols=3, values={ {1,2,3}, {9,9,9}, {7,8,9} } },
    target = { rows=3, cols=3, values={ {1,2,3}, {4,5,6}, {7,8,9} } },
}
