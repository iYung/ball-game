-- swap_rows(row_a=1, row_b=3): exchange rows 1 and 3 to turn the reverse-identity into the identity matrix
return {
    name   = "Row Swap",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = { "swap_rows" },
    sink   = { x=10, y=5 },
    input  = { rows=3, cols=3, values={ {0,0,1}, {0,1,0}, {1,0,0} } },
    target = { rows=3, cols=3, values={ {1,0,0}, {0,1,0}, {0,0,1} } },
}
