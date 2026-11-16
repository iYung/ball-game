-- add_rows(src=1, dst=2, s=-3): row2 = [3,8,1]+(-3)*[1,2,1] = [0,2,-2]
return {
    name   = "Elimination",
    grid_w = 10, grid_h = 10,
    source = { x=1, y=5 },
    sink   = { x=10, y=5 },
    input  = { rows=3, cols=3, values={ {1,2,1}, {3,8,1}, {0,4,1} } },
    target = { rows=3, cols=3, values={ {1,2,1}, {0,2,-2}, {0,4,1} } },
}
