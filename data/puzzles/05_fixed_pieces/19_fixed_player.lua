-- Fixed tools only: FLv and a preset x-1.
-- Chain: {{1,2},{3,4}} → x-1 → {{-1,-2},{-3,-4}} → FLv → {{-3,-4},{-1,-2}}
return {
    name      = "Fixed Tools, Bent Path",
    grid_w    = 10, grid_h = 10,
    source    = { x=2, y=2 },
    sink      = { x=9, y=9 },
    ops       = {},
    fixed_ops = { "flip_v", { op = "scalar_mul", params = { scalar = -1 } } },
    gaps      = {
        {x=1,y=4},{x=2,y=4},{x=3,y=4},
        {x=1,y=7},{x=2,y=7},{x=3,y=7},{x=4,y=7},{x=5,y=7},{x=6,y=7},
    },
    input  = { rows=2, cols=2, values={ {1,2}, {3,4} } },
    target = { rows=2, cols=2, values={ {-3,-4}, {-1,-2} } },
}
