-- swap_rows(1, 3): rows 1 and 3 exchange
return {
    name   = "U-Turn",
    grid_w = 10, grid_h = 10,
    source = { x=1, y=5, dir="right" },
    sink   = { x=10, y=5 },
    input  = { rows=3, cols=3, values={ {1,2,3}, {4,5,6}, {7,8,9} } },
    target = { rows=3, cols=3, values={ {7,8,9}, {4,5,6}, {1,2,3} } },
}
