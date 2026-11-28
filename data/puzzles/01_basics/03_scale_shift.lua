-- Every value is tripled and then shifted by 4; the other order cannot reach the target.
-- Reference solution (place xk (k = 3) at (2,5), +k (k = 4) at (5,7)):
--   Pushers: A(2,1), B(1,7), C(9,9).
--   Timeline: t1 A down; t6 A stop, B right; t12 B stop, C up. WIN at t15.
return {
    name   = "Scale and Shift",
    grid_w = 10, grid_h = 10,
    source = { x=2, y=2 },
    sink   = { x=9, y=3 },
    ops    = { "scalar_mul", "scalar_add" },
    input  = { rows=2, cols=2, values={ {0,1}, {2,3} } },
    target = { rows=2, cols=2, values={ {4,7}, {10,13} } },
    gaps   = {
        {x=5,y=1},
        {x=5,y=2},
        {x=5,y=3},
        {x=5,y=4},
        {x=5,y=5},
        {x=5,y=6},
    },
}
