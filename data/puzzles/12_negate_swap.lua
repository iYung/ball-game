return {
    name   = "Negate & Swap",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = { "negate", "swap_rows" },
    sink   = { x=10, y=5 },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {-3,-4}, {-1,-2} } },
}
