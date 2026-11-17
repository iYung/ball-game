-- add_rows: row2 = row2 + (-2)*row1 = [2,1,0]+(-2)*[1,0,0] = [0,1,0]
return {
    name   = "Row Combine",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=5 },
    ops    = { "add_rows" },  -- op tiles offered in the palette
    sink   = { x=10, y=5 },
    input  = { rows=3, cols=3, values={ {1,0,0}, {2,1,0}, {0,0,1} } },
    target = { rows=3, cols=3, values={ {1,0,0}, {0,1,0}, {0,0,1} } },
}
