-- Push the matrix across two Transpose tiles; two transposes cancel out → identity
return {
    name   = "Double Flip",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    sink   = { x=10, y=5 },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {1,2}, {3,4} } },
}
