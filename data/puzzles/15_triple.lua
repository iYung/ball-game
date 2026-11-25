-- Chain: {{1,2},{3,4}} → x-1 → {{-1,-2},{-3,-4}} → x2 top → {{-2,-4},{-3,-4}}
--        → T → {{-2,-3},{-4,-4}}
return {
    name   = "Triple Bend",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=10 },
    ops    = { "transpose", "scalar_mul", "edge_scale" },
    input  = { rows=2, cols=2, values={ {1,2},{3,4} } },
    target = { rows=2, cols=2, values={ {-2,-3},{-4,-4} } },
    gaps   = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},
        {x=5,y=7},{x=6,y=7},{x=7,y=7},{x=8,y=7},{x=9,y=7},{x=10,y=7},
    },
}
