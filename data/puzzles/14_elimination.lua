-- Chain: {{2,0},{1,3}} → x4 top → {{8,0},{1,3}} → -4 left → {{4,0},{-3,3}}
return {
    name   = "Three-Step Elimination",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=8 },
    ops    = { "edge_scale", "edge_sub" },
    input  = { rows=2, cols=2, values={ {2,0}, {1,3} } },
    target = { rows=2, cols=2, values={ {4,0}, {-3,3} } },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},
        {x=1,y=6},{x=2,y=6},{x=3,y=6},{x=4,y=6},{x=5,y=6},{x=6,y=6},
    },
}
